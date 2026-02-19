#!/bin/bash

#######################################
# Claude Code Management Module
# Description: Install, update, and cleanup Claude Code
#######################################

#######################################
# Install Claude Code in isolated environment
# Returns:
#   0 - success
#   1 - error
# Note: Now uses install_npm_package_with_lockfile() for consistency
#######################################
install_isolated_claude() {
	# Use the generic npm package installer
	install_npm_package_with_lockfile "@anthropic-ai/claude-code" "claudeCodeVersion"
}

#######################################
# Cleanup old Claude Code installations
# Removes temporary .claude-code-* folders left by npm
# Side effects:
#   - Deletes .claude-code-* directories in node_modules/@anthropic-ai/
#######################################
cleanup_old_claude_installations() {
	local node_modules_dir="$NVM_DIR/versions/node"

	if [[ ! -d "$node_modules_dir" ]]; then
		return 0
	fi

	# Find and remove .claude-code-* temporary folders
	find "$node_modules_dir" -type d -path "*/@anthropic-ai/.claude-code-*" -exec rm -rf {} + 2>/dev/null || true

	# Also cleanup temporary binaries
	find "$NVM_DIR/npm-global/bin" -name ".claude-*" -type f -delete 2>/dev/null || true
}
