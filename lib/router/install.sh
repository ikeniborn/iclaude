#!/bin/bash
# Router installation module
# Provides function for installing Claude Code Router

#######################################
# Install Claude Code Router to isolated environment
# Installs @musistudio/claude-code-router npm package
# Creates router.json from template if missing
# Returns:
#   0 - success
#   1 - error
#######################################
install_isolated_router() {
	setup_isolated_nvm

	# Source NVM
	if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
		print_error "NVM not found in isolated environment"
		echo "Run: ./iclaude.sh --isolated-install first"
		return 1
	fi

	source "$NVM_DIR/nvm.sh"

	print_info "Installing Claude Code Router to isolated environment..."
	echo ""

	# Install router globally (in isolated prefix)
	npm install -g @musistudio/claude-code-router

	if [[ $? -ne 0 ]]; then
		print_error "Failed to install Claude Code Router"
		return 1
	fi

	# Clear bash command hash cache
	hash -r 2>/dev/null || true

	# Check if router.json exists, if not copy from example
	local router_config="${ISOLATED_NVM_DIR}/.claude-isolated/router.json"
	local router_example="${ISOLATED_NVM_DIR}/.claude-isolated/router.json.example"

	if [[ ! -f "$router_config" ]] && [[ -f "$router_example" ]]; then
		print_info "Creating router.json from template..."
		cp "$router_example" "$router_config"
		print_success "Created router.json (configure providers and commit to git)"
		echo ""
	fi

	print_success "Claude Code Router installed successfully"
	echo ""
	print_info "Next steps:"
	print_info "  1. Edit: $router_config"
	print_info "  2. Export API keys: export DEEPSEEK_API_KEY=your-key"
	print_info "  3. Commit router.json to git (with \${VAR} placeholders)"
	print_info "  4. Launch: ./iclaude.sh"
	echo ""

	return 0
}
