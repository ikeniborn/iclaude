#!/bin/bash
# Statusline status module
# Provides function for checking statusline status and configuration

#######################################
# Check statusline status and configuration
# Shows script installation, settings config, data sources, and capabilities
# Returns:
#   0 - success
#######################################
check_statusline_status() {
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Claude Code Statusline Status"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	# Setup isolated environment to get paths
	setup_isolated_nvm

	# Check if statusline script exists
	local statusline_script="$ISOLATED_CONFIG_DIR/scripts/claude-statusline.sh"

	if [[ ! -f "$statusline_script" ]]; then
		print_warning "Statusline script not found"
		echo "  Expected location: $statusline_script"
		echo ""
		echo "Install with: ./iclaude.sh --install-statusline"
		echo ""
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo ""
		return 0
	fi

	print_success "Statusline script found: $statusline_script"

	# Check if executable
	if [[ -x "$statusline_script" ]]; then
		print_success "Script is executable"
	else
		print_warning "Script is not executable"
		echo "  Run: chmod +x $statusline_script"
	fi
	echo ""

	# Check settings.json configuration
	local settings_file="$ISOLATED_CONFIG_DIR/settings.json"

	print_info "Settings file location:"
	echo "  $settings_file"
	echo ""

	if [[ ! -f "$settings_file" ]]; then
		print_warning "Settings file not found"
		echo ""
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo ""
		return 0
	fi

	print_success "Settings file exists"
	echo ""

	# Check statusLine configuration
	print_info "Statusline configuration:"
	if command -v jq &>/dev/null; then
		local configured=$(jq -r '.statusLine.command // "not configured"' "$settings_file" 2>/dev/null)
		if [[ "$configured" != "not configured" ]]; then
			print_success "  Command: $configured"
			local refresh=$(jq -r '.statusLine.refresh // "not configured"' "$settings_file" 2>/dev/null)
			if [[ "$refresh" != "not configured" ]]; then
				echo "  Refresh: $refresh"
			fi
		else
			print_warning "  Command: not configured"
			echo "  Add to settings.json:"
			echo "    \"statusLine\": {"
			echo "      \"type\": \"command\","
			echo "      \"command\": \"$statusline_script\","
			echo "      \"padding\": 1"
			echo "    }"
		fi
	else
		echo "  (Install jq to check configuration)"
	fi
	echo ""

	# Show data sources
	print_info "Data sources:"
	echo "  - Session info (tokens, model, cost)"
	echo "  - Proxy status (from .claude_config)"
	echo "  - Router status (from router.json)"
	echo "  - Git branch and status"
	echo ""

	# Display capabilities
	print_info "Capabilities:"
	echo "  - Context usage (tokens + percentage)"
	echo "  - Model name"
	echo "  - Session cost (USD)"
	echo "  - Proxy indicator (🌐)"
	echo "  - Router indicator (🔀 provider)"
	echo "  - Git branch + uncommitted changes"
	echo ""

	print_success "Statusline ready to use"
	if [[ "$(jq -r '.statusLine.command // "not configured"' "$settings_file" 2>/dev/null)" == "not configured" ]]; then
		echo "  Add configuration to settings.json to enable"
	fi

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	return 0
}
