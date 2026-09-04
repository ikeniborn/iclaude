#!/bin/bash
# Router detection module
# Provides functions for detecting Claude Code Router installation
# and parsing CCR configuration for combined PII proxy + router mode

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
		router_config="$ISOLATED_CONFIG_DIR/router.json"
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

#######################################
# Get CCR host and port from router.json
# Parses PORT and HOST fields from the CCR configuration file.
# Used in combined PII proxy + router mode to build ANTHROPIC_UPSTREAM_URL.
# Arguments:
#   $1 - skip_isolated (optional): "true" to skip isolated environment
# Returns:
#   0 - success (CCR_HOST and CCR_PORT globals updated)
#   1 - router config not found (CCR_HOST/CCR_PORT retain defaults 127.0.0.1/3456)
# Globals modified:
#   CCR_HOST - host where CCR listens (default: 127.0.0.1)
#   CCR_PORT - port where CCR listens (default: 3456)
#######################################
get_ccr_port() {
	local skip_isolated="${1:-false}"
	local router_config=""

	# Determine config location (mirrors detect_router() logic)
	if [[ "$skip_isolated" == "false" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
		router_config="$ISOLATED_CONFIG_DIR/router.json"
	else
		router_config="$HOME/.claude/router.json"
	fi

	if [[ ! -f "$router_config" ]]; then
		# Retain defaults (127.0.0.1:3456) if config not found
		return 1
	fi

	# Parse PORT and HOST from router.json
	# Prefer jq for correctness; fall back to grep for minimal-dependency environments
	if command -v jq &>/dev/null; then
		local parsed_port
		local parsed_host
		parsed_port=$(jq -r '.PORT // 3456' "$router_config" 2>/dev/null)
		parsed_host=$(jq -r '.HOST // "127.0.0.1"' "$router_config" 2>/dev/null)
		# Validate port is numeric; reject invalid values
		if [[ "$parsed_port" =~ ^[0-9]+$ ]]; then
			CCR_PORT="$parsed_port"
		fi
		# Validate host is non-empty
		if [[ -n "$parsed_host" && "$parsed_host" != "null" ]]; then
			CCR_HOST="$parsed_host"
		fi
	else
		# Fallback: grep for PORT and HOST values
		local parsed_port
		local parsed_host
		parsed_port=$(grep -o '"PORT"[[:space:]]*:[[:space:]]*[0-9]*' "$router_config" 2>/dev/null \
			| grep -o '[0-9]*$')
		parsed_host=$(grep -o '"HOST"[[:space:]]*:[[:space:]]*"[^"]*"' "$router_config" 2>/dev/null \
			| sed 's/.*"HOST"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
		[[ "$parsed_port" =~ ^[0-9]+$ ]] && CCR_PORT="$parsed_port"
		[[ -n "$parsed_host" ]] && CCR_HOST="$parsed_host"
	fi

	export CCR_HOST CCR_PORT
	return 0
}
