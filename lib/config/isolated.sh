#!/bin/bash

#######################################
# Config Isolated Module
# Description: Isolated configuration setup for project-local Claude Code config
#######################################

#######################################
# Resolve the project root for per-project home keying.
# Git toplevel of the given directory when inside a work tree; otherwise the
# physical directory itself (mirrors icodex resolve_project_root).
# Arguments:
#   $1 - directory (defaults to $PWD)
# Outputs:
#   absolute project root on stdout
#######################################
resolve_project_root() {
	local dir="${1:-$PWD}" top
	top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
	if [[ -n "$top" ]]; then
		printf '%s' "$top"
	else
		(cd "$dir" 2>/dev/null && pwd -P)
	fi
}

#######################################
# Derive the stable per-project home id: <sanitized-basename>-<sha256(path)[0:12]>.
# Basename sanitization matches _derive_project_id (lib/launcher/launch.sh):
# lowercased, runs outside [a-z0-9._-] collapsed to '-', edges trimmed.
# Arguments:
#   $1 - absolute project root path
# Outputs:
#   home id on stdout
#######################################
resolve_claude_home_id() {
	local root="$1" name hash
	name=$(basename "$root" | tr '[:upper:]' '[:lower:]' \
		| sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')
	[[ -n "$name" ]] || name="unknown"
	hash=$(printf '%s' "$root" | sha256sum | cut -c1-12)
	printf '%s-%s' "$name" "$hash"
}

# Managed shared-asset entries wired from the store into per-project homes (S2).
# settings.json is deliberately absent (S3: copy-once + managed-region sync);
# session/state entries are never linked — they stay home-local.
_ICLAUDE_SHARED_LINK_ENTRIES=(
	skills hooks commands agents plugins mcp scripts
	CLAUDE.md .credentials.json router.json
)

#######################################
# Wire shared assets from the store into a per-project home as symlinks.
# For each managed entry: a correct link is left untouched; a wrong link or a
# materialized real path is replaced (with a warning — anti-de-share guard); an
# absent store entry is skipped, and a stale link pointing into the store is
# pruned. The store itself is never mutated. Real paths whose store counterpart
# is absent are left alone.
# Arguments:
#   $1 - home directory
#   $2 - store directory
# Returns:
#   0 - success, 1 - invalid arguments or link creation failure
#######################################
link_shared_assets() {
	local home_dir="$1" store_dir="$2" entry store link target
	[[ -d "$home_dir" && -d "$store_dir" ]] || return 1
	for entry in "${_ICLAUDE_SHARED_LINK_ENTRIES[@]}"; do
		store="$store_dir/$entry"
		link="$home_dir/$entry"
		if [[ -e "$store" ]]; then
			if [[ -L "$link" ]]; then
				target=$(readlink "$link")
				[[ "$target" == "$store" ]] && continue
				rm -f "$link"
				print_warning "Repaired shared-asset link '$entry' (was: $target)"
			elif [[ -e "$link" ]]; then
				rm -rf "$link"
				print_warning "Replaced materialized '$entry' in per-project home with a shared-store link"
			fi
			ln -s "$store" "$link" || return 1
		elif [[ -L "$link" && "$(readlink "$link")" == "$store_dir"/* ]]; then
			rm -f "$link"
			print_warning "Pruned stale shared-asset link '$entry'"
		fi
	done
	return 0
}

#######################################
# Create (or reuse) the per-project home and export CLAUDE_CONFIG_DIR to it.
# S1 scope: only the home directory and its home.json marker (project root,
# created timestamp, schema version) — Claude Code populates the rest itself.
# The marker keeps every home attributable to its project for future GC.
# Globals:
#   ISOLATED_HOMES_DIR - homes root (defaults to <repo>/.claude-homes next to
#                        ISOLATED_NVM_DIR)
# Returns:
#   0 - success, 1 - home creation failed
#######################################
setup_claude_home() {
	local homes_dir="${ISOLATED_HOMES_DIR:-$(dirname "$ISOLATED_NVM_DIR")/.claude-homes}"
	local root home_id home_dir marker
	root=$(resolve_project_root) || return 1
	home_id=$(resolve_claude_home_id "$root")
	home_dir="$homes_dir/$home_id"
	marker="$home_dir/home.json"

	if [[ ! -d "$home_dir" ]]; then
		mkdir -p "$home_dir" || return 1
		print_info "Created per-project home: $home_dir"
	fi

	if [[ ! -f "$marker" ]]; then
		local esc_root="${root//\\/\\\\}"
		esc_root="${esc_root//\"/\\\"}"
		printf '{\n  "project_root": "%s",\n  "created": "%s",\n  "schema": 1\n}\n' \
			"$esc_root" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$marker" || return 1
	fi

	# Fail-soft: a link failure leaves the home usable, launch continues.
	link_shared_assets "$home_dir" "${ISOLATED_CONFIG_DIR:-${ISOLATED_NVM_DIR}/.claude-isolated}" \
		|| print_warning "Shared-asset linking failed for $home_dir"

	export CLAUDE_CONFIG_DIR="$home_dir"
	return 0
}

#######################################
# Setup isolated configuration directory
# Dispatches on ICLAUDE_HOME_MODE: "per-project" exports CLAUDE_CONFIG_DIR to
# the per-project home; "shared" (default) keeps the single shared directory.
# An unknown mode warns and falls back to shared.
# Returns:
#   0 - success
# Example:
#   setup_isolated_config || return 1
#######################################
setup_isolated_config() {
	local mode="${ICLAUDE_HOME_MODE:-shared}"

	case "$mode" in
		per-project)
			setup_claude_home && return 0
			print_warning "Per-project home setup failed; falling back to shared config"
			;;
		shared) ;;
		*)
			print_warning "Unknown ICLAUDE_HOME_MODE '$mode'; using shared config"
			;;
	esac

	local isolated_config_dir="${ISOLATED_NVM_DIR}/.claude-isolated"

	# Create isolated config directory if it doesn't exist
	if [[ ! -d "$isolated_config_dir" ]]; then
		mkdir -p "$isolated_config_dir"
		print_info "Created isolated config directory: $isolated_config_dir"
	fi

	# Export CLAUDE_CONFIG_DIR to isolated location
	export CLAUDE_CONFIG_DIR="$isolated_config_dir"

	return 0
}

#######################################
# Disable Claude Code auto-updates
# Prevents Claude Code from automatically updating itself
# Updates are managed via CI/CD (GitHub Actions) instead
# Arguments:
#   $1 - config directory path (optional, defaults to CLAUDE_CONFIG_DIR)
# Returns:
#   0 - success
#   1 - failure (jq not found or file error)
#######################################
disable_auto_updates() {
	local config_dir="${1:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
	local claude_json="$config_dir/.claude.json"

	# Check if jq is available
	if ! command -v jq &>/dev/null; then
		return 0  # Silently skip if jq not available
	fi

	# Check if .claude.json exists
	if [[ ! -f "$claude_json" ]]; then
		return 0  # File doesn't exist yet, will be created on first run
	fi

	# Check current autoUpdates setting
	local current_value=$(jq -r '.autoUpdates // "null"' "$claude_json" 2>/dev/null)

	# Only update if currently enabled
	if [[ "$current_value" == "true" ]]; then
		local tmp_file="${claude_json}.tmp.$$"

		if jq '.autoUpdates = false' "$claude_json" > "$tmp_file" 2>/dev/null; then
			mv "$tmp_file" "$claude_json"
			chmod 600 "$claude_json"
			return 0
		else
			rm -f "$tmp_file"
			return 1
		fi
	fi

	return 0
}

#######################################
# Load Claude Code configuration variables
# Loads CLAUDE_CODE_* environment variables from credentials file
# Returns:
#   0 - success
# Example:
#   load_claude_config || return 1
#######################################
load_claude_config() {
    # Delegates to the env-map chokepoint; the generic loop subsumes the old
    # per-variable export block. Kept as a named wrapper for existing callers
    # (lib/nvm/setup.sh, lib/sandbox/status.sh).
    source_iclaude_config
}
