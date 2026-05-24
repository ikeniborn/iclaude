#!/bin/bash

#######################################
# Lockfile Save Module
# Description: Save current installation state to lockfile for reproducibility
#######################################

#######################################
# Save isolated environment versions to lockfile
# Captures: Node.js, Claude Code, Router, GH CLI, LSP servers, LSP plugins, StatusLine, Oh-My-Posh
# Returns:
#   0 - success
#   1 - error
# Example:
#   save_isolated_lockfile || return 1
#######################################
save_isolated_lockfile() {
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
					# || true: grep exits 1 if no match; with pipefail this kills set -e
					version=$("$server_bin" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || true)
					;;
				vtsls)
					version=$("$server_bin" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || true)
					;;
				typescript-language-server)
					version=$("$server_bin" --version 2>/dev/null || true)
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

	# Detect GSD version from marker file (offline/instant)
	local gsd_version="not installed"
	if declare -f detect_gsd &>/dev/null && detect_gsd &>/dev/null; then
		local gsd_marker="${CLAUDE_CONFIG_DIR}/.gsd-version"
		if [[ -f "$gsd_marker" ]]; then
			gsd_version=$(cat "$gsd_marker" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
		else
			gsd_version=$(npm view get-shit-done-cc version 2>/dev/null | tr -d '[:space:]' || echo "unknown")
		fi
	fi

	# Detect lat.md version from package.json (offline/instant)
	local lat_version="not installed"
	local lat_pkg="${ISOLATED_NVM_DIR}/npm-global/lib/node_modules/lat.md/package.json"
	if [[ -f "$lat_pkg" ]]; then
		lat_version=$(grep -oP '"version":\s*"\K[^"]+' "$lat_pkg" 2>/dev/null || echo "unknown")
	fi

	# Create lockfile using jq for safe JSON generation
	jq -n \
		--arg nodeVer "$node_version" \
		--arg claudeVer "$claude_version" \
		--arg routerVer "$router_version" \
		--argjson lspServers "$lsp_servers_json" \
		--argjson lspPlugins "$lsp_plugins_json" \
		--arg statusEnabled "$statusline_enabled" \
		--arg statusScript "$statusline_script" \
		--arg ompVer "$omp_version" \
		--arg ompPlat "$omp_platform" \
		--arg ompInstAt "$omp_installed_at" \
		--arg instAt "$installed_at" \
		--arg nvmVer "$nvm_version" \
		--arg gsdVer "$gsd_version" \
		--arg latVer "$lat_version" \
		'{
			nodeVersion: $nodeVer,
			claudeCodeVersion: $claudeVer,
			routerVersion: $routerVer,
			lspServers: $lspServers,
			lspPlugins: $lspPlugins,
			statusLineEnabled: ($statusEnabled == "true"),
			statusLineScript: $statusScript,
			ohMyPoshVersion: $ompVer,
			ohMyPoshPlatform: $ompPlat,
			ohMyPoshInstalledAt: $ompInstAt,
			installedAt: $instAt,
			nvmVersion: $nvmVer,
			gsdVersion: $gsdVer,
			latVersion: $latVer
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

	# Hash changed — check if installed version already matches lockfile
	# This handles git pull delivering CI updates: npm packages are updated in git,
	# so the environment is already in sync even though .last-lockfile-hash is stale.
	local lockfile_claude_ver
	lockfile_claude_ver=$(jq -r '.claudeCodeVersion // empty' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "")

	if [[ -n "$lockfile_claude_ver" && "$lockfile_claude_ver" != "unknown" ]]; then
		local package_json="${ISOLATED_NVM_DIR}/npm-global/lib/node_modules/@anthropic-ai/claude-code/package.json"
		local installed_claude_ver=""
		if [[ -f "$package_json" ]]; then
			installed_claude_ver=$(jq -r '.version // empty' "$package_json" 2>/dev/null || \
				grep -oP '"version":\s*"\K[^"]+' "$package_json" 2>/dev/null || echo "")
		fi

		if [[ -n "$installed_claude_ver" && "$installed_claude_ver" == "$lockfile_claude_ver" ]]; then
			# Version matches lockfile — environment is up to date.
			# Binary management is handled by --update / --repair-isolated; launcher
			# falls through to npx if the native binary is absent.
			update_lockfile_hash
			return 0
		fi
	fi

	# Lockfile changed and installed version differs — warn user
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
