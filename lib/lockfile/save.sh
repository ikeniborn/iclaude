#!/bin/bash

#######################################
# Lockfile Save Module
# Description: Save current installation state to lockfile for reproducibility
#######################################

#######################################
# Save isolated environment versions to lockfile
# Captures: Node.js, Claude Code, Router, GH CLI, LSP servers, LSP plugins, Sandbox, StatusLine, Oh-My-Posh
# Returns:
#   0 - success
#   1 - error
# Example:
#   save_isolated_lockfile || return 1
#######################################
save_isolated_lockfile() {
	# Diagnostic trap: print exact failing line/command when set -e triggers
	trap 'echo "[save_isolated_lockfile ERR] line $LINENO: $BASH_COMMAND (exit $?)" >&2' ERR

	setup_isolated_nvm

	# Source NVM (|| true: nvm_auto can fail with set -e in CI when no .nvmrc / default alias)
	{ [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"; } || true

	# Get versions
	local node_version=$(node --version 2>/dev/null | sed 's/v//')
	local claude_version=""

	# Clear bash command hash cache (ensures fresh command lookup)
	hash -r 2>/dev/null || true

	# Try multiple methods to get Claude version (most reliable first)

	# Method 1: Direct path to cli.js (most reliable - works even with broken symlinks)
	local claude_cli="$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/cli.js"
	if [[ -f "$claude_cli" ]]; then
		claude_version=$(node "$claude_cli" --version 2>/dev/null | head -n 1 | grep -oP '\d+\.\d+\.\d+' || echo "")
	fi

	# Method 2: Fallback to command lookup (requires working symlink)
	if [[ -z "$claude_version" ]] && command -v claude &>/dev/null; then
		claude_version=$(claude --version 2>/dev/null | head -n 1 | grep -oP '\d+\.\d+\.\d+' || echo "")
	fi

	# Method 3: Fallback to package.json (last resort)
	if [[ -z "$claude_version" ]]; then
		local package_json="$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/package.json"
		if [[ -f "$package_json" ]]; then
			claude_version=$(grep -oP '"version":\s*"\K[^"]+' "$package_json" 2>/dev/null || echo "unknown")
		else
			claude_version="unknown"
		fi
	fi

	# Get router version if installed
	local router_version="not installed"
	local ccr_cmd=$(get_router_path "false")
	if [[ -n "$ccr_cmd" ]]; then
		router_version=$("$ccr_cmd" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "unknown")
	fi

	# Detect sandbox availability
	local sandbox_available="false"
	local sandbox_platform=""
	sandbox_platform=$(detect_sandbox_platform)

	if [[ $? -eq 0 ]]; then
		# Platform supported, check dependencies
		if check_sandbox_dependencies &>/dev/null; then
			sandbox_available="true"
		fi
	fi

	# Get dependency versions (Linux/WSL2 only)
	local sandbox_deps_json="{}"
	local sandbox_runtime_version="not installed"

	if [[ "$sandbox_available" == "true" && "$sandbox_platform" != "macos" ]]; then
		local bwrap_version socat_version
		bwrap_version=$(bwrap --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "unknown")
		socat_version=$(socat -V 2>&1 | grep "socat version" | grep -oP '\d+\.\d+\.\d+\.\d+' || echo "unknown")
		sandbox_deps_json="{\"bubblewrap\": \"$bwrap_version\", \"socat\": \"$socat_version\"}"

		# Get sandbox-runtime version
		sandbox_runtime_version=$(get_sandbox_runtime_version)
	fi

	local sandbox_installed_at=""
	if [[ "$sandbox_available" == "true" ]]; then
		sandbox_installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	fi

	# Detect LSP servers
	# Clear bash command cache to find newly installed binaries
	hash -r 2>/dev/null || true

	local lsp_servers_json="{"
	local first=true
	local npm_bin="$NPM_CONFIG_PREFIX/bin"

	for server_cmd in pyright vtsls typescript-language-server; do
		# Check both PATH and direct path in npm-global/bin
		local server_bin=""
		if command -v "$server_cmd" &>/dev/null; then
			server_bin="$server_cmd"
		elif [[ -x "$npm_bin/$server_cmd" ]]; then
			server_bin="$npm_bin/$server_cmd"
		fi

		if [[ -n "$server_bin" ]]; then
			local version
			case "$server_cmd" in
				pyright)
					version=$("$server_bin" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
					;;
				vtsls)
					version=$("$server_bin" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
					;;
				typescript-language-server)
					version=$("$server_bin" --version 2>/dev/null)
					;;
			esac

			if [[ -n "$version" ]]; then
				[[ "$first" == false ]] && lsp_servers_json+=", "
				lsp_servers_json+="\"$server_cmd\": \"$version\""
				first=false
			fi
		fi
	done

	lsp_servers_json+="}"

	# Detect LSP plugins
	local lsp_plugins_json="{"
	first=true

	# Get Claude Code path
	local claude_path
	claude_path=$(get_nvm_claude_path)

	if [[ -n "$claude_path" ]]; then
		# Check installation status via plugin list command
		for plugin in "pyright-lsp@claude-plugins-official" "typescript-lsp@claude-plugins-official" "gopls-lsp@claude-plugins-official" "rust-analyzer-lsp@claude-plugins-official"; do
			local plugin_info

			if [[ "$claude_path" =~ ^node\  ]]; then
				local cli_path="${claude_path#node }"
				plugin_info=$(cd "$SCRIPT_DIR" && node "$cli_path" plugin list 2>/dev/null | grep -A 3 "$plugin" || true)
			else
				plugin_info=$(cd "$SCRIPT_DIR" && "$claude_path" plugin list 2>/dev/null | grep -A 3 "$plugin" || true)
			fi

			# Check if plugin is enabled for this project
			if echo "$plugin_info" | grep -q "enabled"; then
				# Extract version and take only first line to avoid multiline issues
				local plugin_version
				plugin_version=$(echo "$plugin_info" | grep "Version:" | head -1 | awk '{print $2}' | tr -d '\n\r' | xargs)

				if [[ -n "$plugin_version" ]]; then
					[[ "$first" == false ]] && lsp_plugins_json+=", "
					lsp_plugins_json+="\"$plugin\": \"$plugin_version\""
					first=false
				fi
			fi
		done
	fi

	lsp_plugins_json+="}"

	local installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

	# Detect status line configuration
	local statusline_enabled="false"
	local statusline_script="not configured"
	if detect_statusline &>/dev/null; then
		statusline_enabled="true"
		statusline_script="claude-statusline.sh"
	fi

	# Detect Oh My Posh version
	local omp_version="not installed"
	local omp_platform="unknown"
	local omp_installed_at=""
	if detect_ohmyposh &>/dev/null; then
		local posh_path=$(get_ohmyposh_path)
		if [[ -n "$posh_path" ]] && [[ -x "$posh_path" ]]; then
			omp_version=$("$posh_path" --version 2>&1 | head -1 | awk '{print $NF}' || echo "unknown")
			omp_platform=$(detect_ohmyposh_platform 2>/dev/null || echo "unknown")
			omp_installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
		fi
	fi

	# Detect NVM version dynamically
	local nvm_version
	nvm_version=$(nvm --version 2>/dev/null || echo "unknown")

	# Create lockfile using jq for safe JSON generation
	jq -n \
		--arg nodeVer "$node_version" \
		--arg claudeVer "$claude_version" \
		--arg routerVer "$router_version" \
		--argjson lspServers "$lsp_servers_json" \
		--argjson lspPlugins "$lsp_plugins_json" \
		--arg sandboxAvail "$sandbox_available" \
		--arg sandboxPlat "$sandbox_platform" \
		--argjson sandboxDeps "$sandbox_deps_json" \
		--arg sandboxRuntimeVer "$sandbox_runtime_version" \
		--arg sandboxInstAt "$sandbox_installed_at" \
		--arg statusEnabled "$statusline_enabled" \
		--arg statusScript "$statusline_script" \
		--arg ompVer "$omp_version" \
		--arg ompPlat "$omp_platform" \
		--arg ompInstAt "$omp_installed_at" \
		--arg instAt "$installed_at" \
		--arg nvmVer "$nvm_version" \
		'{
			nodeVersion: $nodeVer,
			claudeCodeVersion: $claudeVer,
			routerVersion: $routerVer,
			lspServers: $lspServers,
			lspPlugins: $lspPlugins,
			sandboxAvailable: ($sandboxAvail == "true"),
			sandboxPlatform: $sandboxPlat,
			sandboxDependencies: $sandboxDeps,
			sandboxRuntimeVersion: $sandboxRuntimeVer,
			sandboxInstalledAt: $sandboxInstAt,
			statusLineEnabled: ($statusEnabled == "true"),
			statusLineScript: $statusScript,
			ohMyPoshVersion: $ompVer,
			ohMyPoshPlatform: $ompPlat,
			ohMyPoshInstalledAt: $ompInstAt,
			installedAt: $instAt,
			nvmVersion: "0.39.7"
		}' > "$ISOLATED_LOCKFILE"

	chmod 644 "$ISOLATED_LOCKFILE"

	# Validate lockfile was created successfully
	if [[ ! -f "$ISOLATED_LOCKFILE" ]]; then
		print_error "Failed to create lockfile: $ISOLATED_LOCKFILE"
		return 1
	fi

	print_success "Lockfile saved: $ISOLATED_LOCKFILE"

	# Show lockfile content for verification
	echo ""
	print_info "Lockfile content:"
	cat "$ISOLATED_LOCKFILE" | grep -E "(nodeVersion|claudeCodeVersion|installedAt)" | sed 's/^/  /'
	echo ""

	# Warn if Claude version is unknown
	if [[ "$claude_version" == "unknown" ]]; then
		print_warning "Claude Code version could not be determined"
		echo "  This may indicate Claude Code is not properly installed."
		echo "  Try: ./iclaude.sh --repair-isolated"
		echo ""
	fi

	print_info "Commit this file to git for reproducibility"
	echo ""

	# Update hash after saving lockfile to keep hash in sync
	update_lockfile_hash

	trap - ERR  # Remove diagnostic trap
	return 0
}

#######################################
# Compute SHA-256 hash of the lockfile
# Portable: sha256sum (Linux) → shasum -a 256 (macOS) → md5sum (fallback)
# Returns:
#   Hash string on stdout
#   Exit code: 0 on success, 1 if lockfile missing
# Example:
#   current_hash=$(compute_lockfile_hash) || return 1
#######################################
compute_lockfile_hash() {
	if [[ ! -f "$ISOLATED_LOCKFILE" ]]; then
		return 1
	fi

	local hash=""
	if command -v sha256sum &>/dev/null; then
		hash=$(sha256sum "$ISOLATED_LOCKFILE" | awk '{print $1}')
	elif command -v shasum &>/dev/null; then
		hash=$(shasum -a 256 "$ISOLATED_LOCKFILE" | awk '{print $1}')
	else
		hash=$(md5sum "$ISOLATED_LOCKFILE" 2>/dev/null | awk '{print $1}' || echo "")
	fi

	echo "$hash"
}

#######################################
# Write current lockfile hash to LOCKFILE_HASH_FILE
# Called after install_from_lockfile() and save_isolated_lockfile()
# Returns:
#   0 - hash written successfully
#   1 - failed (lockfile missing or hash empty)
# Example:
#   update_lockfile_hash || print_warning "Could not update lockfile hash"
#######################################
update_lockfile_hash() {
	local hash
	hash=$(compute_lockfile_hash)

	if [[ -z "$hash" ]]; then
		return 1
	fi

	# Ensure parent directory exists
	local hash_dir
	hash_dir=$(dirname "$LOCKFILE_HASH_FILE")
	if [[ ! -d "$hash_dir" ]]; then
		mkdir -p "$hash_dir" 2>/dev/null || return 1
	fi

	echo "$hash" > "$LOCKFILE_HASH_FILE"
	return 0
}

#######################################
# Check if lockfile has changed since last applied hash
# Compares current lockfile hash with stored hash in LOCKFILE_HASH_FILE
# If changed: warns user and offers to run --install-from-lockfile
# If no stored hash: silently initialises hash file (first run)
# If not interactive (CI/CD): prints warning only, does not prompt
# Returns:
#   0 - no change detected or user declined update or first-run init
#   0 - even when changed (non-blocking: launch continues regardless)
# Example:
#   check_lockfile_changes
#######################################
check_lockfile_changes() {
	# Skip if lockfile does not exist (no isolated environment)
	if [[ ! -f "$ISOLATED_LOCKFILE" ]]; then
		return 0
	fi

	local current_hash
	current_hash=$(compute_lockfile_hash)

	if [[ -z "$current_hash" ]]; then
		return 0
	fi

	# First run: hash file does not exist — initialise silently
	if [[ ! -f "$LOCKFILE_HASH_FILE" ]]; then
		update_lockfile_hash
		return 0
	fi

	local stored_hash
	stored_hash=$(cat "$LOCKFILE_HASH_FILE" 2>/dev/null || echo "")

	# No change
	if [[ "$current_hash" == "$stored_hash" ]]; then
		return 0
	fi

	# Lockfile changed — warn user
	echo ""
	print_warning "Lockfile has changed since last environment update"
	print_info "File: $ISOLATED_LOCKFILE"
	echo ""
	echo "  The .nvm-isolated-lockfile.json was updated (e.g. by git pull)."
	echo "  Your isolated environment may be out of sync."
	echo ""

	# Non-interactive mode: warn only, do not block
	if [[ ! -t 0 ]]; then
		print_info "Non-interactive mode: skipping prompt. Run './iclaude.sh --install-from-lockfile' to update."
		echo ""
		return 0
	fi

	read -p "  Run --install-from-lockfile now to update environment? [y/N]: " run_install
	echo ""

	if [[ "$run_install" =~ ^[Yy]$ ]]; then
		print_info "Running: install_from_lockfile..."
		echo ""
		if install_from_lockfile; then
			update_lockfile_hash
			print_success "Environment updated from lockfile"
		else
			print_warning "install_from_lockfile failed — check errors above"
		fi
		echo ""
	else
		print_info "Skipped. Run './iclaude.sh --install-from-lockfile' manually when ready."
		echo ""
	fi

	return 0
}
