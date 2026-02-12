#!/bin/bash
# LSP status module
# Provides function for checking LSP server and plugin status

#######################################
# Check LSP server and plugin status
# Shows installation status, versions, and lockfile tracking
# Returns:
#   0 - success
#######################################
check_lsp_status() {
	# Check jq dependency
	if ! command -v jq &>/dev/null; then
		print_warning "jq not installed - lockfile display unavailable"
		echo "   Install: sudo apt-get install jq (or brew install jq)"
		echo ""
	fi

	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "  LSP Server Status for Isolated Environment"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	# Check TypeScript server
	if command -v vtsls &>/dev/null || command -v typescript-language-server &>/dev/null; then
		local ts_version
		ts_version=$(vtsls --version 2>/dev/null || typescript-language-server --version 2>/dev/null)
		print_success "TypeScript LSP server: $ts_version"
	else
		print_error "TypeScript LSP server: Not installed"
		echo "   Install: ./iclaude.sh --install-lsp typescript"
	fi
	echo ""

	# Check Python server
	if command -v pyright &>/dev/null; then
		local py_version
		py_version=$(pyright --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')
		print_success "Python LSP server: $py_version"
	else
		print_error "Python LSP server: Not installed"
		echo "   Install: ./iclaude.sh --install-lsp python"
	fi
	echo ""

	print_info "LSP Plugins (Claude Code):"
	echo ""

	# Get Claude Code path
	local claude_path
	claude_path=$(get_nvm_claude_path)

	if [[ -z "$claude_path" ]]; then
		print_error "Claude Code not installed - cannot check plugins"
		echo "   Install: ./iclaude.sh --isolated-install"
		echo ""
	else
		# Read plugins from installed_plugins.json file
		local plugins_file=""
		if [[ -d "$ISOLATED_NVM_DIR" ]]; then
			plugins_file="$ISOLATED_NVM_DIR/.claude-isolated/plugins/installed_plugins.json"
		else
			plugins_file="$HOME/.claude/plugins/installed_plugins.json"
		fi

		if [[ ! -f "$plugins_file" ]]; then
			print_warning "Plugin registry not found at: $plugins_file"
			echo "   No plugins installed yet"
			echo ""
		elif ! command -v jq &>/dev/null; then
			print_warning "jq not installed - cannot parse plugin registry"
			echo "   Install jq to view plugin status"
			echo ""
		else
			# Check TypeScript plugin using plugin list command
			if [[ "$claude_path" =~ ^node\  ]]; then
				local cli_path="${claude_path#node }"
				local ts_plugin_status
				ts_plugin_status=$(cd "$SCRIPT_DIR" && node "$cli_path" plugin list 2>/dev/null | grep -A 3 "typescript-lsp@claude-plugins-official" || true)

				if [[ -n "$ts_plugin_status" ]]; then
					local ts_version
					ts_version=$(echo "$ts_plugin_status" | grep "Version:" | awk '{print $2}')
					if echo "$ts_plugin_status" | grep -q "enabled"; then
						print_success "typescript-lsp plugin: $ts_version (enabled)"
					else
						print_warning "typescript-lsp plugin: $ts_version (disabled)"
						echo "   Enable: ./iclaude.sh --install-lsp typescript"
					fi
				else
					print_error "typescript-lsp plugin: Not installed"
					echo "   Install: ./iclaude.sh --install-lsp typescript"
				fi
			else
				local ts_plugin_status
				ts_plugin_status=$(cd "$SCRIPT_DIR" && "$claude_path" plugin list 2>/dev/null | grep -A 3 "typescript-lsp@claude-plugins-official" || true)

				if [[ -n "$ts_plugin_status" ]]; then
					local ts_version
					ts_version=$(echo "$ts_plugin_status" | grep "Version:" | awk '{print $2}')
					if echo "$ts_plugin_status" | grep -q "enabled"; then
						print_success "typescript-lsp plugin: $ts_version (enabled)"
					else
						print_warning "typescript-lsp plugin: $ts_version (disabled)"
						echo "   Enable: ./iclaude.sh --install-lsp typescript"
					fi
				else
					print_error "typescript-lsp plugin: Not installed"
					echo "   Install: ./iclaude.sh --install-lsp typescript"
				fi
			fi
			echo ""

			# Check Python plugin using plugin list command
			if [[ "$claude_path" =~ ^node\  ]]; then
				local cli_path="${claude_path#node }"
				local py_plugin_status
				py_plugin_status=$(cd "$SCRIPT_DIR" && node "$cli_path" plugin list 2>/dev/null | grep -A 3 "pyright-lsp@claude-plugins-official" || true)

				if [[ -n "$py_plugin_status" ]]; then
					local py_version
					py_version=$(echo "$py_plugin_status" | grep "Version:" | awk '{print $2}')
					if echo "$py_plugin_status" | grep -q "enabled"; then
						print_success "pyright-lsp plugin: $py_version (enabled)"
					else
						print_warning "pyright-lsp plugin: $py_version (disabled)"
						echo "   Enable: ./iclaude.sh --install-lsp python"
					fi
				else
					print_error "pyright-lsp plugin: Not installed"
					echo "   Install: ./iclaude.sh --install-lsp python"
				fi
			else
				local py_plugin_status
				py_plugin_status=$(cd "$SCRIPT_DIR" && "$claude_path" plugin list 2>/dev/null | grep -A 3 "pyright-lsp@claude-plugins-official" || true)

				if [[ -n "$py_plugin_status" ]]; then
					local py_version
					py_version=$(echo "$py_plugin_status" | grep "Version:" | awk '{print $2}')
					if echo "$py_plugin_status" | grep -q "enabled"; then
						print_success "pyright-lsp plugin: $py_version (enabled)"
					else
						print_warning "pyright-lsp plugin: $py_version (disabled)"
						echo "   Enable: ./iclaude.sh --install-lsp python"
					fi
				else
					print_error "pyright-lsp plugin: Not installed"
					echo "   Install: ./iclaude.sh --install-lsp python"
				fi
			fi
			echo ""
		fi
	fi

	# Check lockfile tracking
	local lockfile="$SCRIPT_DIR/.nvm-isolated-lockfile.json"
	if [[ -f "$lockfile" ]] && command -v jq &>/dev/null; then
		print_info "Lockfile Tracking:"
		echo "  - LSP Servers:"
		jq -r '.lspServers // {} | to_entries[] | "    \(.key): \(.value)"' "$lockfile" 2>/dev/null || echo "    Not tracked"
		echo "  - LSP Plugins:"
		jq -r '.lspPlugins // {} | to_entries[] | "    \(.key): \(.value)"' "$lockfile" 2>/dev/null || echo "    Not tracked"
		echo ""
	fi

	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""

	return 0
}
