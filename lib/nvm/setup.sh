#!/bin/bash

#######################################
# NVM Setup Module
# Description: Setup isolated NVM environment and configure PATH
#######################################

#######################################
# Setup isolated NVM environment
# Side effects:
#   - Exports NVM_DIR, NPM_CONFIG_PREFIX, ISOLATED_CONFIG_DIR
#   - Prepends isolated paths to PATH
#   - Exports CLAUDE_CODE_ENABLE_TASKS
#   - Loads additional Claude Code config from credentials
#   - Auto-repairs plugin paths (if repair function exists)
# Returns:
#   0 - success
#######################################
setup_isolated_nvm() {
	# Export isolated environment
	export NVM_DIR="$ISOLATED_NVM_DIR"
	export NPM_CONFIG_PREFIX="$NVM_DIR/npm-global"
	export ISOLATED_CONFIG_DIR="$ISOLATED_NVM_DIR/.claude-isolated"

	# Найти установленную версию Node.js (раскрыть глоб)
	# LC_ALL=C sort ensures v18 < v20 deterministically across all filesystems
	# (find output order is filesystem-dependent — non-deterministic on ext4/CI)
	local node_version_dir=$(find "$NVM_DIR/versions/node" -maxdepth 1 -type d -name "v*" 2>/dev/null | LC_ALL=C sort | tail -1)

	if [[ -n "$node_version_dir" ]] && [[ -d "$node_version_dir/bin" ]]; then
		# Add isolated paths to PATH (prepend to prioritize isolated over system)
		export PATH="$NPM_CONFIG_PREFIX/bin:$node_version_dir/bin:$PATH"
	else
		# Fallback: add npm-global/bin only
		export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
		print_warning "Node.js not found in isolated environment"
	fi

	# Enable Claude Code tasks system (set CLAUDE_CODE_ENABLE_TASKS=false to use old system temporarily)
	export CLAUDE_CODE_ENABLE_TASKS="${CLAUDE_CODE_ENABLE_TASKS:-true}"

	# Load additional Claude Code configuration from credentials file
	# Note: load_claude_config() is defined in lib/config/isolated.sh (loaded before this module)
	if declare -f load_claude_config &>/dev/null; then
		load_claude_config
	fi

	# Auto-repair plugin paths silently (if function is defined)
	if declare -f repair_plugin_paths &>/dev/null; then
		repair_plugin_paths "quiet" 2>/dev/null || true
	fi

	return 0
}
