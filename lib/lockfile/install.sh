#!/bin/bash

#######################################
# Lockfile Install Module
# Description: Install all components from lockfile for exact version reproduction
#######################################

#######################################
# Install isolated environment from lockfile
# Installs: Node.js, Claude Code, Router, GH CLI, LSP servers, LSP plugins, Sandbox dependencies
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
	local node_version=$(grep -oP '"nodeVersion":\s*"\K[^"]+' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "18")
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

	nvm install "$node_version"
	nvm use "$node_version"

	if [[ $? -ne 0 ]]; then
		print_error "Failed to install Node.js $node_version"
		return 1
	fi

	# Install Claude Code with specific version if available
	if [[ -n "$claude_version" ]] && [[ "$claude_version" != "unknown" ]]; then
		npm install -g "@anthropic-ai/claude-code@$claude_version"
	else
		npm install -g "@anthropic-ai/claude-code"
	fi

	if [[ $? -ne 0 ]]; then
		print_error "Failed to install Claude Code"
		return 1
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

	# Restore sandbox dependencies if marked as available
	echo ""
	print_info "Checking sandbox availability from lockfile..."
	local sandbox_available
	# Using core/json.sh get_lockfile_field()
	sandbox_available=$(get_lockfile_field "sandboxAvailable" 2>/dev/null || echo "false")
	[[ "$sandbox_available" == "unknown" ]] && sandbox_available="false"

	if [[ "$sandbox_available" == "true" ]]; then
		print_info "Lockfile indicates sandbox was available"
		echo ""

		# Check if dependencies still need installation
		if ! check_sandbox_dependencies &>/dev/null; then
			print_warning "Sandbox dependencies missing - installing..."
			echo ""

			if install_sandbox_dependencies; then
				print_success "Sandbox dependencies restored from lockfile"
			else
				print_warning "Failed to restore sandbox dependencies"
				echo "  You may need to install manually:"
				echo "  ./iclaude.sh --sandbox-install"
			fi
		else
			print_success "Sandbox dependencies already installed"
		fi
	else
		print_info "Sandbox was not available in original installation"
		echo "  Run ./iclaude.sh --sandbox-install to enable"
	fi
	echo ""

	print_success "Installation from lockfile complete"
	echo ""

	# Mark lockfile as applied by updating stored hash
	[[ $(type -t update_lockfile_hash) == function ]] && update_lockfile_hash

	return 0
}
