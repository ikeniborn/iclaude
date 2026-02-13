#!/bin/bash
# Oh-My-Posh detection module
# Provides functions for detecting Oh-My-Posh platform and installation

#######################################
# Detect platform for Oh My Posh installation
# Returns platform string and status code
# Returns:
#   0 - platform supported (linux-amd64, linux-arm64, darwin-amd64, darwin-arm64)
#   1 - platform not supported
# Output: platform name or "unsupported"
#######################################
detect_ohmyposh_platform() {
    local os=$(uname -s)
    local arch=$(uname -m)

    case "$os" in
        Linux)
            case "$arch" in
                x86_64) echo "linux-amd64"; return 0 ;;
                aarch64|arm64) echo "linux-arm64"; return 0 ;;
                *) echo "unsupported"; return 1 ;;
            esac
            ;;
        Darwin)
            case "$arch" in
                x86_64) echo "darwin-amd64"; return 0 ;;
                arm64) echo "darwin-arm64"; return 0 ;;
                *) echo "unsupported"; return 1 ;;
            esac
            ;;
        *)
            echo "unsupported"
            return 1
            ;;
    esac
}

#######################################
# Get path to oh-my-posh binary
# Returns:
#   oh-my-posh binary path or empty string
#######################################
get_ohmyposh_path() {
	# Check isolated environment first
	if [[ -d "$ISOLATED_NVM_DIR" ]]; then
		local npm_global_bin="$ISOLATED_NVM_DIR/npm-global/bin"
		[[ -x "$npm_global_bin/oh-my-posh" ]] && echo "$npm_global_bin/oh-my-posh" && return 0
	fi

	# Check system PATH
	command -v oh-my-posh &> /dev/null && command -v oh-my-posh && return 0

	echo ""
	return 1
}

#######################################
# Detect if Oh My Posh is installed
# Returns:
#   0 - Oh My Posh available
#   1 - Oh My Posh not available
#######################################
detect_ohmyposh() {
	local posh_path=$(get_ohmyposh_path)
	[[ -n "$posh_path" ]] && return 0
	return 1
}
