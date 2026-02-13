#!/bin/bash
# GitHub CLI status module
# Provides function for checking gh CLI installation status

#######################################
# Check GitHub CLI installation status
# Shows installed version, location, and authentication status
# Returns:
#   0 - success
#######################################
check_gh_status() {
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  GitHub CLI Status"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	setup_isolated_nvm
	source "$NVM_DIR/nvm.sh" 2>/dev/null || true

	# Check isolated gh
	local isolated_gh="$ISOLATED_NVM_DIR/npm-global/bin/gh"
	if [[ -x "$isolated_gh" ]]; then
		print_success "Isolated gh CLI: INSTALLED"
		echo "  Location: $isolated_gh"
		echo "  Version: $($isolated_gh --version | head -1)"

		# Check authentication
		if $isolated_gh auth status &>/dev/null; then
			print_success "  Authentication: OK"
			$isolated_gh auth status 2>&1 | grep "Logged in"
		else
			print_warning "  Authentication: NOT CONFIGURED"
			echo ""
			echo "Run: gh auth login"
		fi
	else
		print_warning "Isolated gh CLI: NOT INSTALLED"
		echo ""
		echo "Run: ./iclaude.sh --install-gh"
	fi

	# Check system gh (for comparison)
	echo ""
	if command -v gh &>/dev/null; then
		echo "System gh CLI: $(gh --version | head -1)"
	else
		echo "System gh CLI: not found"
	fi

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	return 0
}
