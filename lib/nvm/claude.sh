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
# Update Claude Code in isolated environment
# Returns:
#   0 - success
#   1 - error
# Side effects:
#   - Updates Claude Code via npm update -g
#   - Updates lockfile with new version
#   - Recreates symlinks
#   - Cleans up old installations
#######################################
update_isolated_claude() {
	setup_isolated_nvm

	print_info "Updating Claude Code in isolated environment..."
	echo ""

	# Update Claude Code
	npm update -g @anthropic-ai/claude-code

	if [[ $? -ne 0 ]]; then
		print_error "Failed to update Claude Code"
		return 1
	fi

	print_success "Claude Code updated"
	echo ""

	# Get new version and update lockfile
	local new_version=$(npm list -g @anthropic-ai/claude-code --depth=0 --json 2>/dev/null | jq -r '.dependencies."@anthropic-ai/claude-code".version // "unknown"')

	if [[ "$new_version" != "unknown" ]]; then
		print_info "New version: $new_version"
		set_lockfile_field "claudeCodeVersion" "$new_version" 2>/dev/null || true
	fi

	# Cleanup old installations
	cleanup_old_claude_installations

	# Recreate symlinks
	if declare -f create_claude_symlink &>/dev/null; then
		create_claude_symlink
	fi

	return 0
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
