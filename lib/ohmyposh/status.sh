#!/bin/bash
# Oh-My-Posh status module
# Provides function for checking Oh-My-Posh status and configuration

#######################################
# Check Oh My Posh status and configuration
# Shows installation, version, platform
# Returns:
#   0 - success
#######################################
check_ohmyposh_status() {
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Oh My Posh Status"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	# Setup isolated environment
	setup_isolated_nvm

	local posh_binary="$ISOLATED_NVM_DIR/npm-global/bin/oh-my-posh"

	print_info "Installation Status:"
	if [[ -f "$posh_binary" ]] && [[ -x "$posh_binary" ]]; then
		print_success "Installed"
		echo "  Location: $posh_binary"

		# Get version
		local version=$("$posh_binary" --version 2>&1 | head -1 | awk '{print $NF}')
		echo "  Version: $version"

		# Get platform
		local platform=$(detect_ohmyposh_platform 2>/dev/null || echo "unknown")
		echo "  Platform: $platform"
	else
		print_error "Not installed"
		echo "  Run: ./iclaude.sh --install-posh"
	fi

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	return 0
}
