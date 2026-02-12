#!/bin/bash
# GitHub CLI installation module
# Provides function for installing gh CLI into isolated environment

#######################################
# Install gh CLI to isolated environment
# Downloads and installs gh CLI binary from GitHub releases
# Returns:
#   0 - success
#   1 - error
#######################################
install_isolated_gh() {
	setup_isolated_nvm

	# Source NVM
	if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
		print_error "NVM not found in isolated environment"
		echo "Run: ./iclaude.sh --isolated-install first"
		return 1
	fi

	source "$NVM_DIR/nvm.sh"

	# Load proxy credentials if available (for curl downloads)
	if [[ -f "$CREDENTIALS_FILE" ]]; then
		# Source the credentials file directly to get all variables
		source "$CREDENTIALS_FILE"
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

	print_info "Installing gh CLI to isolated environment..."
	echo ""

	# Detect architecture
	local arch
	arch=$(uname -m)
	case "$arch" in
		x86_64) arch="amd64" ;;
		aarch64|arm64) arch="arm64" ;;
		*) print_error "Unsupported architecture: $arch"; return 1 ;;
	esac

	# Download latest gh CLI release
	local gh_version="2.45.0"
	local gh_url="https://github.com/cli/cli/releases/download/v${gh_version}/gh_${gh_version}_linux_${arch}.tar.gz"
	local gh_tmp="/tmp/gh_${gh_version}_linux_${arch}.tar.gz"

	# Build curl options based on proxy configuration
	local curl_opts=(-L)

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
			print_info "Downloading via proxy with -k flag (insecure mode)"
		fi
	fi

	print_info "Downloading gh CLI v${gh_version}..."
	# Unset problematic lowercase proxy variables that may conflict with uppercase versions
	unset no_proxy http_proxy https_proxy
	curl "${curl_opts[@]}" "$gh_url" -o "$gh_tmp"

	if [[ $? -ne 0 ]]; then
		print_error "Failed to download gh CLI"
		return 1
	fi

	# Extract to isolated npm-global/bin
	local gh_bin="${ISOLATED_NVM_DIR}/npm-global/bin"
	mkdir -p "$gh_bin"

	tar -xzf "$gh_tmp" -C /tmp
	cp "/tmp/gh_${gh_version}_linux_${arch}/bin/gh" "$gh_bin/gh"
	chmod +x "$gh_bin/gh"

	# Cleanup
	rm -rf "$gh_tmp" "/tmp/gh_${gh_version}_linux_${arch}"

	# Update lockfile (run in background to avoid blocking)
	(save_isolated_lockfile 2>/dev/null) &

	print_success "gh CLI installed successfully: $("$gh_bin/gh" --version | head -1)"
	echo ""

	return 0
}
