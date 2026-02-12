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

	# Source NVM
	if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
		print_error "NVM not found in isolated environment"
		echo ""
		echo "Run: ./iclaude.sh --isolated-install first"
		return 1
	fi

	source "$NVM_DIR/nvm.sh"

	# Ensure Node.js is available
	if ! command -v npm &>/dev/null; then
		print_error "Node.js not found in isolated environment"
		echo ""
		echo "Run: ./iclaude.sh --isolated-install first"
		return 1
	fi

	# Get current version before update
	local current_version=""
	local claude_cli="$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
	if [[ -f "$claude_cli" ]]; then
		current_version=$(node "$claude_cli" --version 2>/dev/null | head -n 1 | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
		print_info "Current version: $current_version"
		echo ""
	else
		print_warning "Claude Code not found in isolated environment"
		echo ""
		echo "Run: ./iclaude.sh --isolated-install first"
		return 1
	fi

	# Update Claude Code
	print_info "Running: npm update -g @anthropic-ai/claude-code"
	echo ""

	if npm update -g @anthropic-ai/claude-code; then
		# Clear bash command hash cache
		hash -r 2>/dev/null || true

		# Get new version
		local new_version=""
		if [[ -f "$claude_cli" ]]; then
			new_version=$(node "$claude_cli" --version 2>/dev/null | head -n 1 | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
		fi

		echo ""
		print_success "Claude Code updated successfully"
		echo ""
		echo "  Previous version: $current_version"
		echo "  New version:      $new_version"
		echo ""

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
