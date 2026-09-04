#!/bin/bash
# Router status module
# Provides function for checking Claude Code Router status

#######################################
# Check Claude Code Router status
# Shows installation status, version, config location, providers, and activation status
# Returns:
#   0 - success
#######################################
check_router_status() {
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  Claude Code Router Status"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	# Check if router binary exists
	local ccr_cmd=$(get_router_path "false")

	if [[ -z "$ccr_cmd" ]]; then
		print_warning "Router not installed"
		echo ""
		echo "Install with: ./iclaude.sh --install-router"
		echo ""
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo ""
		return 0
	fi

	print_success "Router installed: $ccr_cmd"

	# Show version
	local router_version=$("$ccr_cmd" -v 2>/dev/null | head -1 || echo "unknown")
	if [[ "$router_version" != "unknown" ]]; then
		echo "  Version: $router_version"
	fi
	echo ""

	# Check router config
	local router_config=""
	if [[ -d "$ISOLATED_NVM_DIR" ]]; then
		router_config="$ISOLATED_CONFIG_DIR/router.json"
	else
		router_config="$HOME/.claude/router.json"
	fi

	print_info "Router config location:"
	echo "  $router_config"
	echo ""

	if [[ ! -f "$router_config" ]]; then
		print_warning "Router config not found"
		echo ""
		echo "Create config file at: $router_config"
		echo "Or use template: ${router_config}.example"
		echo ""
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo ""
		return 0
	fi

	print_success "Router config exists"

	# Show config size
	local size=$(du -sh "$router_config" 2>/dev/null | cut -f1 || echo "unknown")
	echo "  Size: $size"
	echo ""

	# Parse config and show summary
	print_info "Configuration summary:"

	# Show provider names and router slots (CCR v2.0.0 schema)
	if command -v jq &> /dev/null; then
		local providers=$(jq -r '.Providers[].name' "$router_config" 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
		if [[ -n "$providers" ]]; then
			echo "  Providers: $providers"
		fi

		local default_model=$(jq -r '.Router.default // "not set"' "$router_config" 2>/dev/null)
		echo "  Default model: $default_model"

		local background_model=$(jq -r '.Router.background // ""' "$router_config" 2>/dev/null)
		[[ -n "$background_model" ]] && echo "  Background model: $background_model"

		local think_model=$(jq -r '.Router.think // ""' "$router_config" 2>/dev/null)
		[[ -n "$think_model" ]] && echo "  Think model: $think_model"

		local long_model=$(jq -r '.Router.longContext // ""' "$router_config" 2>/dev/null)
		[[ -n "$long_model" ]] && echo "  Long context model: $long_model"
	else
		echo "  (Install jq for detailed config summary)"
	fi

	echo ""

	# Check if router is configured
	if detect_router "false"; then
		print_success "Router configured and ready"
		echo "  (router.json exists and ccr binary found)"
		echo "  Use --router flag to launch via router"
		echo "  Can be combined with --pii-proxy for PII masking of CCR traffic"
		echo "  Combined mode: claude → PII proxy(:9000) → CCR(:3456) → providers"
	else
		print_info "Router not fully configured"
		echo "  Run --install-router to set up router"
	fi

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	return 0
}
