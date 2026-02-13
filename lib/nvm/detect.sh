#!/bin/bash

#######################################
# NVM Detection Module
# Description: Detect NVM installation and locate Claude Code binary
#######################################

#######################################
# Detect if NVM is available
# Arguments:
#   $1 - skip_isolated (optional): "true" to skip isolated environment check
# Returns:
#   0 - NVM is available
#   1 - NVM not found
# Priority order:
#   1. Isolated environment (.nvm-isolated/)
#   2. System NVM ($NVM_DIR/nvm.sh)
#   3. npm/node in PATH from NVM
#######################################
detect_nvm() {
	local skip_isolated="${1:-false}"

	# Priority 1: Check for isolated environment (if enabled by default and not skipped)
	if [[ "$skip_isolated" != "true" ]] && [[ "$USE_ISOLATED_BY_DEFAULT" == "true" ]] && [[ -d "$ISOLATED_NVM_DIR" ]]; then
		# Isolated environment exists, set it up
		if [[ -s "${ISOLATED_NVM_DIR}/nvm.sh" ]]; then
			setup_isolated_nvm
			return 0
		fi
	fi

	# Priority 2: Check if NVM_DIR is set and nvm.sh exists (system NVM)
	if [[ -n "${NVM_DIR:-}" ]] && [[ -s "${NVM_DIR}/nvm.sh" ]]; then
		return 0
	fi

	# Priority 3: Check if npm/node is from NVM by examining the path
	local npm_path=$(command -v npm 2>/dev/null)
	if [[ -n "$npm_path" ]] && [[ "$npm_path" == *".nvm"* ]]; then
		return 0
	fi

	local node_path=$(command -v node 2>/dev/null)
	if [[ -n "$node_path" ]] && [[ "$node_path" == *".nvm"* ]]; then
		return 0
	fi

	return 1
}

#######################################
# Get Claude Code path from NVM environment
# Returns:
#   Claude Code binary path on stdout
#   Exit code: 0 on success, 1 if not found
# Search order:
#   1. Standard 'claude' binary in NVM bin/
#   2. Temporary '.claude-*' binaries (sorted by mtime, newest first)
#   3. cli.js in standard claude-code/ folder
#   4. cli.js in temporary .claude-code-* folders
#######################################
get_nvm_claude_path() {
	# Try to find claude in active NVM node version
	if [[ -n "${NVM_DIR:-}" ]]; then
		# Get current node version
		local current_node=""
		if command -v nvm &> /dev/null; then
			current_node=$(nvm current 2>/dev/null)
		fi

		# Check if valid version
		if [[ -n "$current_node" ]] && [[ "$current_node" != "none" ]] && [[ "$current_node" != "system" ]]; then
			local nvm_bin="${NVM_DIR}/versions/node/$current_node/bin"
			local nvm_lib="${NVM_DIR}/versions/node/$current_node/lib/node_modules/@anthropic-ai"

			# First try standard 'claude' binary
			if [[ -x "$nvm_bin/claude" ]]; then
				echo "$nvm_bin/claude"
				return 0
			fi

			# Then try temporary .claude-* binaries (sorted by modification time, newest first)
			if ls "$nvm_bin/.claude-"* &>/dev/null; then
				local temp_claude=$(ls -t "$nvm_bin/.claude-"* 2>/dev/null | head -n 1)
				if [[ -x "$temp_claude" ]]; then
					echo "$temp_claude"
					return 0
				fi
			fi

			# If binaries not found, try to find cli.js in node_modules (including temp folders)
			if [[ -d "$nvm_lib" ]]; then
				# Try standard claude-code folder first
				if [[ -f "$nvm_lib/claude-code/cli.js" ]]; then
					echo "node $nvm_lib/claude-code/cli.js"
					return 0
				fi

				# Then try temporary .claude-code-* folders (sorted by modification time, newest first)
				local temp_cli=$(find "$nvm_lib" -maxdepth 2 -name "cli.js" -path "*/.claude-code-*/cli.js" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n 1 | cut -d' ' -f2-)
				if [[ -n "$temp_cli" ]] && [[ -f "$temp_cli" ]]; then
					echo "node $temp_cli"
					return 0
				fi
			fi
		fi
	fi

	# Alternative: use npm prefix to find global bin
	local npm_prefix=$(npm prefix -g 2>/dev/null)
	if [[ -n "$npm_prefix" ]] && [[ "$npm_prefix" == *".nvm"* ]]; then
		# First try standard 'claude' binary
		if [[ -x "$npm_prefix/bin/claude" ]]; then
			echo "$npm_prefix/bin/claude"
			return 0
		fi

		# Then try temporary .claude-* binaries (sorted by modification time, newest first)
		if ls "$npm_prefix/bin/.claude-"* &>/dev/null; then
			local temp_claude=$(ls -t "$npm_prefix/bin/.claude-"* 2>/dev/null | head -n 1)
			if [[ -x "$temp_claude" ]]; then
				echo "$temp_claude"
				return 0
			fi
		fi

		# If binaries not found, try to find cli.js in node_modules
		local npm_lib="$npm_prefix/lib/node_modules/@anthropic-ai"
		if [[ -d "$npm_lib" ]]; then
			# Try standard claude-code folder first
			if [[ -f "$npm_lib/claude-code/cli.js" ]]; then
				echo "node $npm_lib/claude-code/cli.js"
				return 0
			fi

			# Then try temporary .claude-code-* folders (sorted by modification time, newest first)
			local temp_cli=$(find "$npm_lib" -maxdepth 2 -name "cli.js" -path "*/.claude-code-*/cli.js" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n 1 | cut -d' ' -f2-)
			if [[ -n "$temp_cli" ]] && [[ -f "$temp_cli" ]]; then
				echo "node $temp_cli"
				return 0
			fi
		fi
	fi

	return 1
}

#######################################
# Get Claude Code CLI version
# Arguments:
#   $1 - CLI path (e.g., "/path/to/claude" or "node /path/to/cli.js")
# Returns:
#   Version string on stdout (e.g., "2.1.7")
#   Exit code: 0 on success, 1 if version not found
#######################################
get_cli_version() {
	local cli_path=$1

	# If it's a "node /path/to/cli.js" command, extract the cli.js path
	if [[ "$cli_path" == node* ]]; then
		cli_path=$(echo "$cli_path" | awk '{print $2}')
	fi

	# If it's a full path to cli.js, get the directory
	if [[ "$cli_path" == *"cli.js" ]]; then
		cli_path=$(dirname "$cli_path")
	fi

	# Check if package.json exists
	local package_json="$cli_path/package.json"
	if [[ ! -f "$package_json" ]]; then
		echo "unknown"
		return 1
	fi

	# Extract version from package.json
	local version=$(grep -oP '(?<="version":\s")[^"]+' "$package_json" 2>/dev/null)

	if [[ -z "$version" ]]; then
		echo "unknown"
		return 1
	fi

	echo "$version"
	return 0
}
