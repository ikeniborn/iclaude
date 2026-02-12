#!/bin/bash
# Sandbox detection module
# Provides function for detecting sandbox platform support

#######################################
# Detect platform for sandboxing support
# Returns:
#   0 - platform supported (macos, linux, wsl2)
#   1 - platform not supported (wsl1, windows, unknown)
# Output: platform name (macos|linux|wsl2|wsl1|windows|unsupported)
#######################################
detect_sandbox_platform() {
	case $(uname -s) in
		Darwin)
			echo "macos"
			return 0
			;;
		Linux)
			if grep -qE "(Microsoft|WSL)" /proc/version 2>/dev/null; then
				if grep -q "WSL2" /proc/version 2>/dev/null; then
					echo "wsl2"
					return 0
				else
					echo "wsl1"
					return 1
				fi
			fi
			echo "linux"
			return 0
			;;
		MINGW*|MSYS*|CYGWIN*)
			echo "windows"
			return 1
			;;
		*)
			echo "unsupported"
			return 1
			;;
	esac
}
