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

# Machine-owned settings.json keys mirrored from the store on every launch (S3).
# Everything else in a home settings.json is user-owned and never touched.
_ICLAUDE_SETTINGS_MANAGED_KEYS='{hooks, enabledPlugins, statusLine, extraKnownMarketplaces}'

#######################################
# Seed a per-project home settings.json from the store — copy-once.
# An existing home file is never re-seeded; a missing store file is skipped.
# Arguments:
#   $1 - home directory
#   $2 - store directory
# Returns:
#   0 - success or skip
#######################################
seed_home_settings() {
	local home_dir="$1" store_dir="$2"
	local src="$store_dir/settings.json" dst="$home_dir/settings.json"
	[[ -f "$dst" ]] && return 0
	if [[ ! -f "$src" ]]; then
		print_warning "No store settings.json to seed into $home_dir"
		return 0
	fi
	cp "$src" "$dst" || return 0
	chmod 600 "$dst"
	print_info "Seeded settings.json into per-project home"
	return 0
}

#######################################
# Mirror the machine-owned settings keys from the store into a home settings.json.
# User-owned keys are preserved byte-for-byte; a managed key changed or deleted in
# the home is restored, one removed from the store disappears. The file is only
# rewritten when content differs; the store is never mutated. Degrades to a
# warning without jq or without files.
# Arguments:
#   $1 - home directory
#   $2 - store directory
# Returns:
#   0 - success or graceful skip
#######################################
sync_home_settings() {
	local home_dir="$1" store_dir="$2"
	local src="$store_dir/settings.json" dst="$home_dir/settings.json" tmp
	[[ -f "$src" && -f "$dst" ]] || return 0
	if ! command -v jq &>/dev/null; then
		print_warning "jq not found; skipping settings managed-key sync"
		return 0
	fi
	tmp="${dst}.tmp.$$"
	if ! jq --slurpfile st "$src" \
		"del(.hooks, .enabledPlugins, .statusLine, .extraKnownMarketplaces)
		 + (\$st[0] | $_ICLAUDE_SETTINGS_MANAGED_KEYS | with_entries(select(.value != null)))" \
		"$dst" > "$tmp" 2>/dev/null; then
		rm -f "$tmp"
		print_warning "Settings managed-key sync failed; home settings left unchanged"
		return 0
	fi
	if cmp -s "$tmp" "$dst"; then
		rm -f "$tmp"
	else
		mv "$tmp" "$dst"
		chmod 600 "$dst"
		print_info "Synced machine-owned settings keys from the store"
	fi
	return 0
}

# jq program that narrows a .claude.json to one project. Takes --arg root.
# .projects keeps only the root's own entry. .githubRepoPaths keeps only the
# repositories with at least one checkout at or under the root, so sibling
# worktrees of this repository survive while other repositories are dropped;
# an absent key stays absent.
CLAUDE_JSON_REDUCE_JQ='
.projects = (if (.projects // {})[$root] then {($root): .projects[$root]} else {} end)
| if has("githubRepoPaths")
  then .githubRepoPaths = (
    .githubRepoPaths
    | with_entries(select(.value | any(. == $root or startswith($root + "/"))))
  )
  else . end
'

#######################################
# One-time copy-based migration of this project's slice of the shared config
# into a fresh per-project home (S5). Keyed on the absence of the home
# .claude.json; the store is never mutated, so rollback = delete the home.
# Migrates: .claude.json (global keys, only this project's .projects entry and
# only the .githubRepoPaths repositories checked out under the project root),
# projects/<mangled-root>/ transcripts, history.jsonl entries for this project.
# Without jq the .claude.json is copied unreduced (warning) and history starts
# fresh.
# Arguments:
#   $1 - home directory
#   $2 - store directory
#   $3 - absolute project root
# Returns:
#   0 - success or graceful skip
#######################################
migrate_home_from_store() {
	local home_dir="$1" store_dir="$2" root="$3"
	local src="$store_dir/.claude.json" dst="$home_dir/.claude.json"
	[[ -f "$dst" ]] && return 0
	[[ -f "$src" ]] || return 0

	if command -v jq &>/dev/null; then
		local tmp="${dst}.tmp.$$"
		if jq --arg root "$root" "$CLAUDE_JSON_REDUCE_JQ" \
			"$src" > "$tmp" 2>/dev/null; then
			mv "$tmp" "$dst" && chmod 600 "$dst"
		else
			rm -f "$tmp"
			print_warning "Failed to reduce .claude.json projects map; copying store file as-is"
			cp "$src" "$dst" && chmod 600 "$dst"
		fi
	else
		print_warning "jq not found; copying .claude.json without .projects reduction"
		cp "$src" "$dst" && chmod 600 "$dst"
	fi

	# This project's transcripts — copy, store untouched.
	local mangled
	mangled=$(printf '%s' "$root" | sed -E 's/[^a-zA-Z0-9]/-/g')
	if [[ -d "$store_dir/projects/$mangled" && ! -e "$home_dir/projects/$mangled" ]]; then
		mkdir -p "$home_dir/projects"
		cp -a "$store_dir/projects/$mangled" "$home_dir/projects/" 2>/dev/null \
			|| print_warning "Transcript migration failed for $mangled"
	fi

	# History entries for this project only; fresh history without jq.
	if command -v jq &>/dev/null \
		&& [[ -f "$store_dir/history.jsonl" && ! -f "$home_dir/history.jsonl" ]]; then
		if jq -c --arg root "$root" 'select(.project == $root)' \
			"$store_dir/history.jsonl" > "$home_dir/history.jsonl" 2>/dev/null; then
			chmod 600 "$home_dir/history.jsonl"
		else
			rm -f "$home_dir/history.jsonl"
		fi
	fi

	print_info "Migrated project state from the shared config into the per-project home"
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
	local root home_id home_dir
	root=$(resolve_project_root) || return 1
	home_id=$(resolve_claude_home_id "$root")
	home_dir="$homes_dir/$home_id"

	if [[ ! -d "$home_dir" ]]; then
		mkdir -p "$home_dir" || return 1
		print_info "Created per-project home: $home_dir"
	fi

	# Populate under a per-home lock (S6); falls back to unlocked when lock.sh
	# is not loaded. Fail-soft either way — the launch continues.
	if declare -f iclaude_with_lock >/dev/null 2>&1; then
		iclaude_with_lock "$home_dir/.iclaude.lock" 30 \
			_populate_claude_home "$home_dir" "$root" || true
	else
		_populate_claude_home "$home_dir" "$root" || true
	fi

	export CLAUDE_CONFIG_DIR="$home_dir"
	return 0
}

#######################################
# Populate a per-project home: marker, shared-asset links, settings seed/sync,
# first-launch migration. Runs under the per-home lock from setup_claude_home.
# Arguments:
#   $1 - home directory
#   $2 - absolute project root
# Returns:
#   0 - success, 1 - marker creation failed
#######################################
_populate_claude_home() {
	local home_dir="$1" root="$2"
	local marker="$home_dir/home.json"

	if [[ ! -f "$marker" ]]; then
		local esc_root="${root//\\/\\\\}"
		esc_root="${esc_root//\"/\\\"}"
		printf '{\n  "project_root": "%s",\n  "created": "%s",\n  "schema": 1\n}\n' \
			"$esc_root" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$marker" || return 1
	fi

	# Fail-soft: a link failure leaves the home usable, launch continues.
	local store_dir="${ISOLATED_CONFIG_DIR:-${ISOLATED_NVM_DIR}/.claude-isolated}"
	link_shared_assets "$home_dir" "$store_dir" \
		|| print_warning "Shared-asset linking failed for $home_dir"
	seed_home_settings "$home_dir" "$store_dir"
	sync_home_settings "$home_dir" "$store_dir"
	migrate_home_from_store "$home_dir" "$store_dir" "$root"
	return 0
}

#######################################
# List per-project homes: id, project root (from home.json, "unknown" when the
# marker is missing/unreadable), size, last-used date, and an "orphan" mark
# when the recorded root no longer exists (S7).
# Returns:
#   0 - always (missing homes dir is a calm no-op)
#######################################
list_claude_homes() {
	local homes_dir="${ISOLATED_HOMES_DIR:-$(dirname "$ISOLATED_NVM_DIR")/.claude-homes}"
	[[ -d "$homes_dir" ]] || { print_info "No per-project homes yet ($homes_dir)"; return 0; }
	local d id root size used mark
	for d in "$homes_dir"/*/; do
		[[ -d "$d" ]] || continue
		id=$(basename "$d")
		root="unknown"
		if [[ -f "$d/home.json" ]] && command -v jq &>/dev/null; then
			root=$(jq -r '.project_root // "unknown"' "$d/home.json" 2>/dev/null || echo "unknown")
		fi
		size=$(du -sh "$d" 2>/dev/null | cut -f1)
		used=$(date -d "@$(stat -c %Y "$d" 2>/dev/null || echo 0)" +%Y-%m-%d 2>/dev/null || echo "?")
		mark=""
		[[ "$root" != "unknown" && ! -d "$root" ]] && mark=" orphan"
		printf '%s\t%s\t%s\t%s%s\n' "$id" "$root" "${size:-?}" "$used" "$mark"
	done
	return 0
}

# Confirmation helper: ICLAUDE_ASSUME_YES=1 bypasses; otherwise interactive y/N.
_confirm_home_deletion() {
	[[ "${ICLAUDE_ASSUME_YES:-}" == "1" ]] && return 0
	local answer
	read -r -p "$1 [y/N] " answer 2>/dev/null || return 1
	[[ "$answer" == "y" || "$answer" == "Y" ]]
}

#######################################
# Remove orphan homes: readable marker whose recorded project root no longer
# exists. Homes without a readable marker are never touched. Confirmation
# required (ICLAUDE_ASSUME_YES=1 for non-interactive use).
# Returns:
#   0 - always
#######################################
clean_claude_homes() {
	local homes_dir="${ISOLATED_HOMES_DIR:-$(dirname "$ISOLATED_NVM_DIR")/.claude-homes}"
	[[ -d "$homes_dir" ]] || return 0
	command -v jq &>/dev/null || { print_warning "jq not found; cannot attribute homes, nothing removed"; return 0; }
	local d root removed=0
	for d in "$homes_dir"/*/; do
		[[ -d "$d" && -f "$d/home.json" ]] || continue
		root=$(jq -r '.project_root // empty' "$d/home.json" 2>/dev/null)
		[[ -n "$root" && ! -d "$root" ]] || continue
		if _confirm_home_deletion "Remove orphan home $(basename "$d") (root gone: $root)?"; then
			rm -rf "$d" && removed=$((removed + 1))
		fi
	done
	print_info "Removed $removed orphan home(s)"
	return 0
}

#######################################
# Remove one home by id after confirmation. Unknown id is an error.
# Arguments:
#   $1 - home id (directory name under the homes dir)
# Returns:
#   0 - removed or declined, 1 - unknown id
#######################################
clean_claude_home() {
	local homes_dir="${ISOLATED_HOMES_DIR:-$(dirname "$ISOLATED_NVM_DIR")/.claude-homes}"
	local id="$1"
	if [[ -z "$id" || ! -d "$homes_dir/$id" ]]; then
		print_error "Unknown home id: ${id:-<empty>}"
		return 1
	fi
	if _confirm_home_deletion "Remove home $id?"; then
		rm -rf "${homes_dir:?}/$id"
		print_info "Removed home $id"
	fi
	return 0
}

#######################################
# Setup isolated configuration directory
# Dispatches on ICLAUDE_HOME_MODE: "per-project" (default since S5) exports
# CLAUDE_CONFIG_DIR to the per-project home; "shared" keeps the single shared
# directory (legacy escape hatch). An unknown mode warns and falls back to
# shared.
# Returns:
#   0 - success
# Example:
#   setup_isolated_config || return 1
#######################################
setup_isolated_config() {
	local mode="${ICLAUDE_HOME_MODE:-per-project}"

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
