#!/bin/bash
# Router detection module
# Provides functions for detecting Claude Code Router installation

#######################################
# Detect if Claude Code Router is available
# Checks if router.json exists and ccr binary is installed
# Arguments:
#   $1 - skip_isolated (optional): "true" to skip isolated environment
# Returns:
#   0 - Router available (config + binary)
#   1 - Router not available
#######################################
detect_router() {
	local skip_isolated="${1:-false}"
	local router_config=""

	# Determine config location
	if [[ "$skip_isolated" == "false" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
		router_config="$ISOLATED_NVM_DIR/.claude-isolated/router.json"
	else
		router_config="$HOME/.claude/router.json"
	fi

	# Router config must exist
	[[ ! -f "$router_config" ]] && return 1

	# Check ccr binary
	local ccr_cmd=$(get_router_path "$skip_isolated")
	if [[ -z "$ccr_cmd" ]]; then
		print_warning "router.json found but ccr binary not installed"
		print_info "Install with: ./iclaude.sh --install-router"
		return 1
	fi

	return 0  # Router available
}

#######################################
# Get path to ccr binary
# Arguments:
#   $1 - skip_isolated (optional): "true" to skip isolated environment
# Returns:
#   ccr binary path or empty string
#######################################
get_router_path() {
	local skip_isolated="${1:-false}"

	# Check isolated environment first
	if [[ "$skip_isolated" == "false" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
		local npm_global_bin="$ISOLATED_NVM_DIR/npm-global/bin"
		[[ -x "$npm_global_bin/ccr" ]] && echo "$npm_global_bin/ccr" && return 0
	fi

	# Check system PATH
	command -v ccr &> /dev/null && command -v ccr && return 0

	echo ""
	return 1
}
