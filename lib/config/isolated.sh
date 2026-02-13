#!/bin/bash

#######################################
# Config Isolated Module
# Description: Isolated configuration setup for project-local Claude Code config
#######################################

#######################################
# Setup isolated configuration directory
# Creates .claude-isolated directory and exports CLAUDE_CONFIG_DIR
# Returns:
#   0 - success
# Example:
#   setup_isolated_config || return 1
#######################################
setup_isolated_config() {
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
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        return 0
    fi

    # Source the credentials file to get Claude Code variables
    source "$CREDENTIALS_FILE"

    # Export Claude Code configuration variables if set
    [[ -n "${CLAUDE_CODE_MAX_OUTPUT_TOKENS:-}" ]] && export CLAUDE_CODE_MAX_OUTPUT_TOKENS
    [[ -n "${CLAUDE_CODE_ENABLE_TASKS:-}" ]] && export CLAUDE_CODE_ENABLE_TASKS
    [[ -n "${CLAUDE_CODE_NO_CHROME:-}" ]] && export CLAUDE_CODE_NO_CHROME
    [[ -n "${CLAUDE_CODE_MODEL:-}" ]] && export CLAUDE_CODE_MODEL
    [[ -n "${CLAUDE_CODE_SESSION_TIMEOUT:-}" ]] && export CLAUDE_CODE_SESSION_TIMEOUT
    [[ -n "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" ]] && export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

    return 0
}
