#!/bin/bash

#######################################
# NVM Installation Module
# Description: Install NVM, Node.js, and npm packages with lockfile integration
#######################################

#######################################
# Install NVM to isolated directory
# Returns:
#   0 - success
#   1 - error
# Side effects:
#   - Creates ISOLATED_NVM_DIR
#   - Downloads and installs NVM v0.39.7
#   - Uses proxy if configured
#######################################
install_isolated_nvm() {
	setup_isolated_nvm

	# Create isolated NVM directory
	mkdir -p "$NVM_DIR"

	# Check if NVM already installed
	if [[ -s "$NVM_DIR/nvm.sh" ]]; then
		print_info "NVM already installed in isolated environment"
		return 0
	fi

	# Load proxy credentials if available (for curl downloads)
	if [[ -f "$CREDENTIALS_FILE" ]]; then
		# Source the credentials file directly to get all variables
		source_iclaude_config
		# Export proxy variables for curl
		if [[ -n "${PROXY_URL:-}" ]]; then
			export HTTPS_PROXY="$PROXY_URL"
			export HTTP_PROXY="$PROXY_URL"
		fi
		if [[ -z "${NO_PROXY:-}" ]]; then
			export NO_PROXY="localhost,127.0.0.1,github.com,githubusercontent.com,gitlab.com,bitbucket.org"
		else
			export NO_PROXY
		fi
		# Export PROXY_CA and PROXY_INSECURE for curl option logic
		[[ -n "${PROXY_CA:-}" ]] && export PROXY_CA
		[[ -n "${PROXY_INSECURE:-}" ]] && export PROXY_INSECURE
	fi

	print_info "Installing NVM to isolated directory..."
	print_info "Location: $NVM_DIR"
	echo ""

	# Build curl options based on proxy configuration
	local curl_opts=(-o-)

	# Add TLS/proxy options if proxy is configured
	if [[ -n "${HTTPS_PROXY:-}" ]] || [[ -n "${HTTP_PROXY:-}" ]]; then
		if [[ -n "${PROXY_CA:-}" ]] && [[ -f "$PROXY_CA" ]]; then
			# Use provided CA certificate (secure mode)
			curl_opts+=(--cacert "$PROXY_CA")
			print_info "Using proxy CA certificate: $PROXY_CA"
		else
			# Disable all TLS verification (insecure mode)
			# Required for proxies with outdated cryptographic algorithms
			# Note: --proxy-insecure is insufficient for algorithm validation errors
			curl_opts+=(-k)
			print_info "Downloading NVM installer via proxy with -k flag (insecure mode)"
		fi
	fi

	# Download and install NVM
	# Unset problematic lowercase proxy variables that may conflict with uppercase versions
	unset no_proxy http_proxy https_proxy
	curl "${curl_opts[@]}" https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | \
		NVM_DIR="$NVM_DIR" bash

	if [[ $? -ne 0 ]]; then
		print_error "Failed to install NVM"
		return 1
	fi

	print_success "NVM installed to isolated environment"
	return 0
}

#######################################
# Install Node.js in isolated NVM
# Arguments:
#   $1 - Node.js version (default: 18)
# Returns:
#   0 - success
#   1 - error
#######################################
install_isolated_nodejs() {
	local node_version=${1:-20}

	setup_isolated_nvm

	# Source NVM
	if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
		print_error "NVM not found in isolated environment"
		echo "Run: iclaude --isolated-install first"
		return 1
	fi

	source "$NVM_DIR/nvm.sh"

	# Check if Node.js already installed
	if nvm ls "$node_version" &>/dev/null; then
		print_info "Node.js $node_version already installed"
		nvm use "$node_version"
		return 0
	fi

	print_info "Installing Node.js $node_version to isolated environment..."
	echo ""

	# Install and use Node.js
	nvm install "$node_version"
	nvm use "$node_version"

	if [[ $? -ne 0 ]]; then
		print_error "Failed to install Node.js"
		return 1
	fi

	print_success "Node.js $node_version installed"
	node --version
	npm --version
	echo ""

	return 0
}

#######################################
# Install npm package with automatic lockfile update
# This function eliminates 6+ duplications across iclaude.sh:
#   - install_isolated_claude()
#   - install_isolated_router()
#   - install_isolated_lsp_servers() (multiple packages)
#   - etc.
#
# Arguments:
#   $1 - npm package name (e.g., "@anthropic-ai/claude-code")
#   $2 - lockfile field name (e.g., "claudeCodeVersion")
#   $3 - optional version specifier (e.g., "2.1.7" or "latest", default: latest)
# Returns:
#   0 - success
#   1 - error
# Side effects:
#   - Installs package globally via npm install -g
#   - Updates lockfile with installed version
# Example:
#   install_npm_package_with_lockfile "@anthropic-ai/claude-code" "claudeCodeVersion"
#   install_npm_package_with_lockfile "@musistudio/claude-code-router" "routerVersion"
#   install_npm_package_with_lockfile "pyright" "lspServers.pyright" "1.1.347"
#######################################
install_npm_package_with_lockfile() {
	local package_name="$1"
	local lockfile_field="$2"
	local version_spec="${3:-latest}"

	# Validate arguments
	if [[ -z "$package_name" ]] || [[ -z "$lockfile_field" ]]; then
		print_error "Usage: install_npm_package_with_lockfile <package_name> <lockfile_field> [version]"
		return 1
	fi

	# Setup isolated NVM environment
	setup_isolated_nvm

	# Ensure npm is available
	if ! command -v npm &>/dev/null; then
		print_error "npm not found in isolated environment"
		echo "Run: iclaude --isolated-install first"
		return 1
	fi

	# Install package
	print_info "Installing $package_name@$version_spec..."
	echo ""

	if [[ "$version_spec" == "latest" ]]; then
		npm install -g "$package_name"
	else
		npm install -g "$package_name@$version_spec"
	fi

	if [[ $? -ne 0 ]]; then
		print_error "Failed to install $package_name"
		return 1
	fi

	# Get installed version
	local installed_version=$(npm list -g "$package_name" --depth=0 --json 2>/dev/null | jq -r ".dependencies.\"$package_name\".version // \"unknown\"")

	if [[ "$installed_version" == "unknown" ]] || [[ -z "$installed_version" ]]; then
		print_warning "Could not determine installed version of $package_name"
		installed_version="unknown"
	fi

	print_success "$package_name@$installed_version installed"
	echo ""

	# Update lockfile (using core/json.sh set_lockfile_field)
	if declare -f set_lockfile_field &>/dev/null; then
		set_lockfile_field "$lockfile_field" "$installed_version" || {
			print_warning "Failed to update lockfile field: $lockfile_field"
		}
	else
		# Fallback: manual jq update (if core/json.sh not loaded)
		if command -v jq &>/dev/null && [[ -f "$ISOLATED_LOCKFILE" ]]; then
			local temp_file=$(mktemp)
			jq ".$lockfile_field = \"$installed_version\"" "$ISOLATED_LOCKFILE" > "$temp_file" 2>/dev/null && \
				mv "$temp_file" "$ISOLATED_LOCKFILE" || \
				rm -f "$temp_file"
		fi
	fi

	return 0
}
