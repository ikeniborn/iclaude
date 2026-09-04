#!/bin/bash
# LSP installation module
# Provides function for installing LSP servers and Claude Code plugins

#######################################
# Install LSP servers and plugins in isolated environment
# Installs LSP server binaries via npm and enables Claude Code plugins
# Arguments:
#   $@ - Language servers to install (typescript, python, go, rust)
#        Default: typescript python
# Returns:
#   0 - success
#   1 - error
#######################################
install_isolated_lsp_servers() {
	local servers=("$@")  # Allow selecting specific servers

	# Default: Install TypeScript + Python (most common)
	if [[ ${#servers[@]} -eq 0 ]]; then
		servers=("typescript" "python")
	fi

	# Setup environment
	setup_isolated_nvm
	source "$NVM_DIR/nvm.sh"

	# Get Claude Code path using existing function
	local claude_path
	claude_path=$(get_nvm_claude_path)

	if [[ -z "$claude_path" ]]; then
		print_error "Claude Code not installed."
		echo ""
		print_info "Run './iclaude.sh --isolated-install' first to install Claude Code."
		return 1
	fi

	echo ""
	print_info "Installing LSP servers and plugins..."
	print_info "Claude Code path: $claude_path"
	echo ""

	for server in "${servers[@]}"; do
		case "$server" in
			typescript|ts)
				# Install server
				print_info "Installing TypeScript LSP server..."
				npm install -g @vtsls/language-server || print_warning "Server install failed (continuing...)"
				echo ""

				# Check if plugin already installed
				local plugins_file=""
				if [[ -d "$ISOLATED_NVM_DIR" ]]; then
					plugins_file="$ISOLATED_CONFIG_DIR/plugins/installed_plugins.json"
				else
					plugins_file="$HOME/.claude/plugins/installed_plugins.json"
				fi

				# Check if plugin exists globally (any project)
				local ts_plugin_exists=false
				local ts_plugin_enabled=false

				# Check installation status via plugin list command
				if [[ "$claude_path" =~ ^node\  ]]; then
					local cli_path="${claude_path#node }"
					local plugin_status
					plugin_status=$(cd "$SCRIPT_DIR" && node "$cli_path" plugin list 2>/dev/null | grep -A 3 "typescript-lsp@claude-plugins-official" | grep "Status:" || true)

					# Check if installed (appears in list)
					if [[ -n "$plugin_status" ]]; then
						ts_plugin_exists=true
						# Check if enabled
						[[ "$plugin_status" =~ "enabled" ]] && ts_plugin_enabled=true
					fi
				else
					local plugin_status
					plugin_status=$(cd "$SCRIPT_DIR" && "$claude_path" plugin list 2>/dev/null | grep -A 3 "typescript-lsp@claude-plugins-official" | grep "Status:" || true)

					# Check if installed (appears in list)
					if [[ -n "$plugin_status" ]]; then
						ts_plugin_exists=true
						# Check if enabled
						[[ "$plugin_status" =~ "enabled" ]] && ts_plugin_enabled=true
					fi
				fi

				if [[ "$ts_plugin_enabled" == true ]]; then
					echo "✓ typescript-lsp plugin already enabled for this project"
				elif [[ "$ts_plugin_exists" == true ]]; then
					print_info "Enabling typescript-lsp plugin for this project..."
					if [[ "$claude_path" =~ ^node\  ]]; then
						local cli_path="${claude_path#node }"
						(cd "$SCRIPT_DIR" && node "$cli_path" plugin enable typescript-lsp@claude-plugins-official -s project) || print_warning "Plugin enable failed"
					else
						(cd "$SCRIPT_DIR" && "$claude_path" plugin enable typescript-lsp@claude-plugins-official -s project) || print_warning "Plugin enable failed"
					fi
				else
					print_info "Installing typescript-lsp plugin..."
					if [[ "$claude_path" =~ ^node\  ]]; then
						local cli_path="${claude_path#node }"
						(cd "$SCRIPT_DIR" && node "$cli_path" plugin install typescript-lsp@claude-plugins-official -s project) || print_warning "Plugin install failed"
					else
						(cd "$SCRIPT_DIR" && "$claude_path" plugin install typescript-lsp@claude-plugins-official -s project) || print_warning "Plugin install failed"
					fi
				fi
				echo ""
				;;
			python|py)
				# Install server
				print_info "Installing Python LSP server..."
				npm install -g pyright || print_warning "Server install failed (continuing...)"
				echo ""

				# Check if plugin already installed
				local plugins_file=""
				if [[ -d "$ISOLATED_NVM_DIR" ]]; then
					plugins_file="$ISOLATED_CONFIG_DIR/plugins/installed_plugins.json"
				else
					plugins_file="$HOME/.claude/plugins/installed_plugins.json"
				fi

				# Check if plugin exists globally (any project)
				local py_plugin_exists=false
				local py_plugin_enabled=false

				# Check installation status via plugin list command
				if [[ "$claude_path" =~ ^node\  ]]; then
					local cli_path="${claude_path#node }"
					local plugin_status
					plugin_status=$(cd "$SCRIPT_DIR" && node "$cli_path" plugin list 2>/dev/null | grep -A 3 "pyright-lsp@claude-plugins-official" | grep "Status:" || true)

					# Check if installed (appears in list)
					if [[ -n "$plugin_status" ]]; then
						py_plugin_exists=true
						# Check if enabled
						[[ "$plugin_status" =~ "enabled" ]] && py_plugin_enabled=true
					fi
				else
					local plugin_status
					plugin_status=$(cd "$SCRIPT_DIR" && "$claude_path" plugin list 2>/dev/null | grep -A 3 "pyright-lsp@claude-plugins-official" | grep "Status:" || true)

					# Check if installed (appears in list)
					if [[ -n "$plugin_status" ]]; then
						py_plugin_exists=true
						# Check if enabled
						[[ "$plugin_status" =~ "enabled" ]] && py_plugin_enabled=true
					fi
				fi

				if [[ "$py_plugin_enabled" == true ]]; then
					echo "✓ pyright-lsp plugin already enabled for this project"
				elif [[ "$py_plugin_exists" == true ]]; then
					print_info "Enabling pyright-lsp plugin for this project..."
					if [[ "$claude_path" =~ ^node\  ]]; then
						local cli_path="${claude_path#node }"
						(cd "$SCRIPT_DIR" && node "$cli_path" plugin enable pyright-lsp@claude-plugins-official -s project) || print_warning "Plugin enable failed"
					else
						(cd "$SCRIPT_DIR" && "$claude_path" plugin enable pyright-lsp@claude-plugins-official -s project) || print_warning "Plugin enable failed"
					fi
				else
					print_info "Installing pyright-lsp plugin..."
					if [[ "$claude_path" =~ ^node\  ]]; then
						local cli_path="${claude_path#node }"
						(cd "$SCRIPT_DIR" && node "$cli_path" plugin install pyright-lsp@claude-plugins-official -s project) || print_warning "Plugin install failed"
					else
						(cd "$SCRIPT_DIR" && "$claude_path" plugin install pyright-lsp@claude-plugins-official -s project) || print_warning "Plugin install failed"
					fi
				fi
				echo ""
				;;
			go)
				# Go requires GOPATH setup, skip npm
				print_warning "Go LSP (gopls): Install via 'go install golang.org/x/tools/gopls@latest'"
				print_info "    Plugin: cd \"$SCRIPT_DIR\" && claude plugin install gopls-lsp@claude-plugins-official -s project"
				echo ""
				;;
			rust)
				print_warning "Rust LSP (rust-analyzer): Install via 'rustup component add rust-analyzer'"
				print_info "    Plugin: cd \"$SCRIPT_DIR\" && claude plugin install rust-analyzer-lsp@claude-plugins-official -s project"
				echo ""
				;;
			# Add other languages as needed
			*)
				print_error "Unknown LSP server: $server"
				echo ""
				;;
		esac
	done

	hash -r  # Clear bash cache
	save_isolated_lockfile  # Update lockfile with LSP versions

	echo ""
	print_success "LSP installation complete. Run './iclaude.sh --check-lsp' to verify."
	echo ""

	return 0
}
