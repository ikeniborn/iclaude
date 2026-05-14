#!/bin/bash
# Update module for isolated environment
# Provides function for updating Claude Code in isolated NVM environment

#######################################
# Update Claude Code in isolated environment
# Updates Claude Code via npm and refreshes lockfile
# Returns:
#   0 - success
#   1 - error
#######################################
update_isolated_claude() {
	setup_isolated_nvm

	echo ""
	print_info "Updating Claude Code in isolated environment..."
	echo ""

	# Verify NVM is installed
	if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
		print_error "NVM not found in isolated environment"
		echo ""
		echo "Run: ./iclaude.sh --isolated-install first"
		return 1
	fi

	# Ensure Node.js is available
	# Note: PATH is already configured by setup_isolated_nvm above.
	# Do NOT source nvm.sh here — it triggers nvm_auto which calls
	# `nvm use <current>` and can fail with set -e when NVM_DIR or
	# alias/default is not configured (e.g. in CI environments).
	if ! command -v npm &>/dev/null; then
		print_error "Node.js not found in isolated environment"
		echo ""
		echo "Run: ./iclaude.sh --isolated-install first"
		return 1
	fi

	# Get current version before update
	local current_version=""
	local claude_pkg="$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/package.json"
	if [[ -f "$claude_pkg" ]]; then
		current_version=$(grep -oP '(?<="version":\s")[^"]+' "$claude_pkg" 2>/dev/null || echo "unknown")
		print_info "Current version: $current_version"
		echo ""
	else
		print_warning "Claude Code not found in isolated environment"
		echo ""
		echo "Run: ./iclaude.sh --isolated-install first"
		return 1
	fi

	# Pre-update cleanup: remove existing claude symlink and temp installations
	# This prevents ENOTEMPTY and EEXIST errors during npm install
	local npm_prefix_dir="$ISOLATED_NVM_DIR/npm-global"
	local bin_dir="$npm_prefix_dir/bin"
	local lib_dir="$npm_prefix_dir/lib/node_modules/@anthropic-ai"

	print_info "Pre-update cleanup..."

	# Remove existing claude symlink (to avoid EEXIST)
	rm -f "$bin_dir/claude" "$bin_dir/.claude-"* 2>/dev/null

	# Remove ALL temporary .claude-code-* folders (to avoid ENOTEMPTY)
	if [[ -d "$lib_dir" ]]; then
		local temp_folders
		temp_folders=$(find "$lib_dir" -maxdepth 1 -type d -name ".claude-code-*" 2>/dev/null)
		if [[ -n "$temp_folders" ]]; then
			echo "$temp_folders" | while read -r folder; do
				[[ -z "$folder" ]] && continue
				rm -rf "$folder" 2>/dev/null
				print_info "Removed temp installation: $(basename "$folder")"
			done
		fi
	fi

	echo ""

	# Update Claude Code
	# Use npm install -g @latest instead of npm update -g to ensure latest version is installed.
	# npm update -g does not work reliably with npm 10 (Node v20) for global packages.
	print_info "Running: npm install -g @anthropic-ai/claude-code@latest"
	echo ""

	if npm install -g @anthropic-ai/claude-code@latest; then
		# Clear bash command hash cache
		hash -r 2>/dev/null || true

		# Get new version
		local new_version=""
		if [[ -f "$claude_pkg" ]]; then
			new_version=$(grep -oP '(?<="version":\s")[^"]+' "$claude_pkg" 2>/dev/null || echo "unknown")
		fi

		echo ""
		print_success "Claude Code updated successfully"
		echo ""
		echo "  Previous version: $current_version"
		echo "  New version:      $new_version"
		echo ""

		# Restore execute bit on vendor binaries (git strips +x from rg after update)
		if declare -f repair_vendor_permissions &>/dev/null; then
			repair_vendor_permissions
		fi

		# Update GSD if installed
		if declare -f update_gsd_if_installed &>/dev/null; then
			update_gsd_if_installed
		fi

		# Update lockfile with new version
		print_info "Updating lockfile..."
		save_isolated_lockfile

		if [[ "$current_version" == "$new_version" ]]; then
			print_info "Already on latest version"
		fi

		return 0
	else
		echo ""
		print_error "Failed to update Claude Code"
		echo ""
		echo "Try:"
		echo "  1. Check internet connection"
		echo "  2. Run: ./iclaude.sh --repair-isolated"
		echo "  3. Reinstall: ./iclaude.sh --cleanup-isolated && ./iclaude.sh --isolated-install"
		return 1
	fi
}
