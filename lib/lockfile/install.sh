#!/bin/bash

#######################################
# Lockfile Install Module
# Description: Install all components from lockfile for exact version reproduction
#######################################

#######################################
# Remove stale npm artifacts from interrupted Claude Code installs.
# npm retires global packages into .claude-code-* and .claude-* paths before
# replacing them; leftover paths make the next install fail with ENOTEMPTY/EEXIST.
# Returns:
#   0 - success
#######################################
cleanup_claude_npm_install_artifacts() {
	local npm_prefix_dir="$ISOLATED_NVM_DIR/npm-global"
	local bin_dir="$npm_prefix_dir/bin"
	local lib_dir="$npm_prefix_dir/lib/node_modules/@anthropic-ai"

	if [[ -d "$lib_dir" ]]; then
		find "$lib_dir" -maxdepth 1 -type d -name ".claude-code-*" -exec rm -rf {} + 2>/dev/null || true
	fi

	if [[ -d "$bin_dir" ]]; then
		find "$bin_dir" -maxdepth 1 \( -type f -o -type l \) -name ".claude-*" -delete 2>/dev/null || true
	fi

	return 0
}

#######################################
# Install core isolated environment from lockfile
# Installs only Node.js and Claude Code for startup lockfile sync.
# Returns:
#   0 - success
#   1 - error
#######################################
install_core_from_lockfile() {
	if [[ ! -f "$ISOLATED_LOCKFILE" ]]; then
		print_error "Lockfile not found: $ISOLATED_LOCKFILE"
		echo ""
		echo "Create lockfile first with: iclaude --isolated-install"
		return 1
	fi

	print_info "Installing core isolated environment from lockfile..."
	echo ""

	local node_version
	local claude_version
	node_version=$(grep -oP '"nodeVersion":\s*"\K[^"]+' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "22")
	claude_version=$(grep -oP '"claudeCodeVersion":\s*"\K[^"]+' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "")

	print_info "Node.js version from lockfile: $node_version"
	if [[ -n "$claude_version" ]] && [[ "$claude_version" != "unknown" ]]; then
		print_info "Claude Code version from lockfile: $claude_version"
	fi
	echo ""

	if [[ ! -s "$ISOLATED_NVM_DIR/nvm.sh" ]]; then
		install_isolated_nvm || return 1
	fi

	setup_isolated_nvm
	source "$NVM_DIR/nvm.sh"

	node_version=$(echo "$node_version" | sed 's/^v//')

	if ! nvm install "$node_version" || ! nvm use "$node_version"; then
		print_warning "nvm could not download Node.js; trying the node-TLS fallback..."
		echo ""
		local major="${node_version%%.*}"
		if fetch_node_via_node_tls "$major"; then
			local newdir
			if sort -V </dev/null &>/dev/null; then
				newdir="$(find "$NVM_DIR/versions/node" -maxdepth 1 -type d -name "v${major}.*" 2>/dev/null | sort -V | tail -1)"
			else
				newdir="$(find "$NVM_DIR/versions/node" -maxdepth 1 -type d -name "v${major}.*" 2>/dev/null | LC_ALL=C sort | tail -1)"
			fi
			[[ -n "$newdir" ]] && { nvm use "$(basename "$newdir")" &>/dev/null || export PATH="$newdir/bin:$PATH"; }
		else
			print_error "Failed to install Node.js $node_version"
			return 1
		fi
	fi

	cleanup_claude_npm_install_artifacts

	if [[ -n "$claude_version" ]] && [[ "$claude_version" != "unknown" ]]; then
		if ! run_claude_npm_install_with_progress "@anthropic-ai/claude-code@$claude_version"; then
			print_error "Failed to install Claude Code"
			return 1
		fi
	else
		if ! run_claude_npm_install_with_progress "@anthropic-ai/claude-code"; then
			print_error "Failed to install Claude Code"
			return 1
		fi
	fi

	if declare -F create_claude_symlink &>/dev/null; then
		echo ""
		print_info "Repairing Claude Code symlink after npm install..."
		create_claude_symlink || return 1
	fi

	print_success "Core isolated environment installed from lockfile"
	echo ""
	return 0
}

#######################################
# Install isolated environment from lockfile
# Installs: Node.js, Claude Code, Router, GH CLI, LSP servers, LSP plugins
# Returns:
#   0 - success
#   1 - error
# Example:
#   install_from_lockfile || return 1
#######################################
install_from_lockfile() {
	if [[ ! -f "$ISOLATED_LOCKFILE" ]]; then
		print_error "Lockfile not found: $ISOLATED_LOCKFILE"
		echo ""
		echo "Create lockfile first with: iclaude --isolated-install"
		return 1
	fi

	print_info "Installing from lockfile..."
	echo ""

	# Parse lockfile (using grep for portability)
	local node_version=$(grep -oP '"nodeVersion":\s*"\K[^"]+' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "22")
	local claude_version=$(grep -oP '"claudeCodeVersion":\s*"\K[^"]+' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "")

	print_info "Node.js version from lockfile: $node_version"
	if [[ -n "$claude_version" ]] && [[ "$claude_version" != "unknown" ]]; then
		print_info "Claude Code version from lockfile: $claude_version"
	fi
	echo ""

	# Install NVM if needed
	if [[ ! -s "$ISOLATED_NVM_DIR/nvm.sh" ]]; then
		install_isolated_nvm
		if [[ $? -ne 0 ]]; then
			return 1
		fi
	fi

	# Install Node.js
	setup_isolated_nvm
	source "$NVM_DIR/nvm.sh"

	# Remove 'v' prefix if present
	node_version=$(echo "$node_version" | sed 's/^v//')

	# Install Node.js. If nvm's download fails (system curl/OpenSSL cannot reach
	# the Node mirror on this host), fall back to Node's own TLS stack — same path
	# as install_isolated_nodejs, so lockfile installs self-heal too.
	if ! nvm install "$node_version" || ! nvm use "$node_version"; then
		print_warning "nvm could not download Node.js; trying the node-TLS fallback..."
		echo ""
		local major="${node_version%%.*}"
		if fetch_node_via_node_tls "$major"; then
			local newdir
			if sort -V </dev/null &>/dev/null; then
				newdir="$(find "$NVM_DIR/versions/node" -maxdepth 1 -type d -name "v${major}.*" 2>/dev/null | sort -V | tail -1)"
			else
				newdir="$(find "$NVM_DIR/versions/node" -maxdepth 1 -type d -name "v${major}.*" 2>/dev/null | LC_ALL=C sort | tail -1)"
			fi
			[[ -n "$newdir" ]] && { nvm use "$(basename "$newdir")" &>/dev/null || export PATH="$newdir/bin:$PATH"; }
		else
			print_error "Failed to install Node.js $node_version"
			return 1
		fi
	fi

	cleanup_claude_npm_install_artifacts

	# Install Claude Code with specific version if available
	if [[ -n "$claude_version" ]] && [[ "$claude_version" != "unknown" ]]; then
		run_claude_npm_install_with_progress "@anthropic-ai/claude-code@$claude_version"
	else
		run_claude_npm_install_with_progress "@anthropic-ai/claude-code"
	fi

	if [[ $? -ne 0 ]]; then
		print_error "Failed to install Claude Code"
		return 1
	fi

	if declare -F create_claude_symlink &>/dev/null; then
		echo ""
		print_info "Repairing Claude Code symlink after npm install..."
		create_claude_symlink || return 1
	fi

	# Install router if version specified in lockfile
	local router_version=$(grep -oP '"routerVersion":\s*"\K[^"]+' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "not installed")

	if [[ "$router_version" != "not installed" ]] && [[ "$router_version" != "unknown" ]]; then
		echo ""
		print_info "Installing Claude Code Router version: $router_version"
		echo ""

		npm install -g "@musistudio/claude-code-router@$router_version"

		if [[ $? -eq 0 ]]; then
			print_success "Router installed: $router_version"
			echo ""
		else
			print_warning "Failed to install router (non-critical)"
			echo ""
		fi
	fi

	# Install LSP servers and plugins from lockfile
	# Check jq dependency
	if ! command -v jq &>/dev/null; then
		print_warning "jq not installed - skipping LSP installation from lockfile"
		echo "   Install jq to enable this feature: sudo apt-get install jq"
		echo ""
	else
		# Install LSP servers from lockfile
		local lsp_servers
		lsp_servers=$(jq -r '.lspServers // {} | keys[]' "$ISOLATED_LOCKFILE" 2>/dev/null)

		if [[ -n "$lsp_servers" ]]; then
			echo ""
			print_info "Installing LSP servers from lockfile..."
			echo ""

			while IFS= read -r server; do
				local version
				version=$(jq -r ".lspServers[\"$server\"]" "$ISOLATED_LOCKFILE")

				case "$server" in
					pyright)
						npm install -g "pyright@$version" || print_warning "pyright install failed"
						;;
					vtsls)
						npm install -g "@vtsls/language-server@$version" || print_warning "vtsls install failed"
						;;
					typescript-language-server)
						npm install -g "typescript-language-server@$version" || print_warning "typescript-language-server install failed"
						;;
				esac
			done <<< "$lsp_servers"

			echo ""
		fi

		# Install LSP plugins from lockfile
		local lsp_plugins
		lsp_plugins=$(jq -r '.lspPlugins // {} | keys[]' "$ISOLATED_LOCKFILE" 2>/dev/null)

		if [[ -n "$lsp_plugins" ]]; then
			print_info "Installing LSP plugins from lockfile..."
			echo ""

			# Get Claude Code path
			local claude_path
			claude_path=$(get_nvm_claude_path)

			if [[ -z "$claude_path" ]]; then
				print_warning "Claude Code not found - skipping plugin installation"
				echo "   Install Claude Code first: ./iclaude.sh --isolated-install"
				echo ""
			else
				while IFS= read -r plugin; do
					local version
					version=$(jq -r ".lspPlugins[\"$plugin\"]" "$ISOLATED_LOCKFILE")

					print_info "Installing $plugin@$version..."

					# Handle both binary and cli.js paths
					if [[ "$claude_path" =~ ^node\  ]]; then
						local cli_path="${claude_path#node }"
						(cd "$SCRIPT_DIR" && node "$cli_path" plugin install "$plugin" -s project) || print_warning "Plugin install failed (may already exist)"
					else
						(cd "$SCRIPT_DIR" && "$claude_path" plugin install "$plugin" -s project) || print_warning "Plugin install failed (may already exist)"
					fi
				done <<< "$lsp_plugins"

				echo ""
			fi
		fi
	fi

	print_success "Installation from lockfile complete"
	echo ""

	# Mark lockfile as applied by updating stored hash
	[[ $(type -t update_lockfile_hash) == function ]] && update_lockfile_hash

	return 0
}
