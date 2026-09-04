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
#   $1 - Node.js version (default: 22)
# Returns:
#   0 - success
#   1 - error
#######################################
install_isolated_nodejs() {
	local node_version=${1:-22}

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

	# Install and use Node.js. If nvm's download fails (system curl/OpenSSL cannot
	# reach the Node mirror on this host), fall back to Node's own TLS stack.
	# `nvm install` already activates the version, so the defensive `nvm use` runs
	# with --silent — otherwise "Now using node ..." is printed twice.
	if ! nvm install "$node_version" || ! nvm use --silent "$node_version"; then
		print_warning "nvm could not download Node.js; trying the node-TLS fallback..."
		echo ""
		local major="${node_version%%.*}"
		if fetch_node_via_node_tls "$major"; then
			local newdir
			newdir="$(find "$NVM_DIR/versions/node" -maxdepth 1 -type d -name "v${major}.*" 2>/dev/null | LC_ALL=C sort | tail -1)"
			[[ -n "$newdir" ]] && { nvm use "$(basename "$newdir")" &>/dev/null || export PATH="$newdir/bin:$PATH"; }
		else
			print_error "Failed to install Node.js"
			return 1
		fi
	fi

	print_success "Node.js $node_version installed"
	node --version
	npm --version
	echo ""

	return 0
}

#######################################
# Fallback Node.js installer using Node's own TLS stack.
# Downloads the latest release for a given major from nodejs.org into the
# isolated nvm versions dir, bypassing system curl/nvm — whose OpenSSL cannot
# complete a TLS handshake to nodejs.org on some hosts (e.g. AltLinux's
# GOST-patched OpenSSL, or a TLS-intercepting proxy), while Node's own OpenSSL
# can. Integrity is verified against SHASUMS256.txt (the TLS certs go unverified,
# so this checksum is what guards the download). The heavy lifting is in
# scripts/fetch-node.js.
# Arguments:
#   $1 - Node.js major version (e.g. "22")
# Returns:
#   0 - a Node.js <major>.x was downloaded, verified and extracted
#   1 - failure
#######################################
fetch_node_via_node_tls() {
	local major="$1"
	local fetch_js="$SCRIPT_DIR/scripts/fetch-node.js"

	if [[ ! -f "$fetch_js" ]]; then
		print_error "Fetcher not found: $fetch_js"
		return 1
	fi

	# Any working node can run the fetcher: prefer the highest isolated one, fall
	# back to a system node (needed on a first, node-less install).
	local runner
	runner="$(find "$NVM_DIR/versions/node" -maxdepth 1 -type d -name "v*" 2>/dev/null | LC_ALL=C sort | tail -1)/bin/node"
	[[ -x "$runner" ]] || runner="$(command -v node 2>/dev/null)"
	if [[ -z "$runner" ]] || [[ ! -x "$runner" ]]; then
		# Bootstrap chicken-and-egg: the fetcher is a Node script, so it needs an
		# existing Node to run. nvm cannot help here — it downloads Node with the
		# same broken curl. The user must provide a Node to bootstrap from.
		print_error "No Node.js available to run the TLS fetcher"
		echo ""
		echo "The node-TLS installer needs an existing Node.js to bootstrap from, but"
		echo "none was found (no isolated Node, no system 'node' on PATH), and nvm"
		echo "cannot download one on this host (system curl/OpenSSL cannot reach the"
		echo "Node mirror)."
		echo ""
		echo "Provide a Node.js to bootstrap from, then re-run, e.g.:"
		echo "  • install a system Node:    sudo apt install nodejs   (or dnf/pacman)"
		echo "  • or drop a Node build in:  $NVM_DIR/versions/node/v$major.<minor>.<patch>/"
		echo "  • or set a reachable mirror: export NVM_NODEJS_ORG_MIRROR=<mirror>"
		return 1
	fi

	# Make the proxy visible to the fetcher (isolated config holds ICLAUDE_PROXY_URL).
	if [[ -z "${ICLAUDE_PROXY_URL:-}" ]] && declare -f source_iclaude_config &>/dev/null; then
		source_iclaude_config 2>/dev/null || true
	fi

	# Arch tag used by nodejs.org tarball names.
	local arch
	case "$(uname -m)" in
		x86_64) arch="x64" ;;
		aarch64 | arm64) arch="arm64" ;;
		armv7l) arch="armv7l" ;;
		ppc64le) arch="ppc64le" ;;
		s390x) arch="s390x" ;;
		*) print_error "Unsupported architecture: $(uname -m)"; return 1 ;;
	esac

	local tmpd
	tmpd="$(mktemp -d)"

	print_info "Resolving latest Node.js $major (node-TLS; system curl cannot reach the mirror)..."
	if ! "$runner" "$fetch_js" "https://nodejs.org/dist/index.json" "$tmpd/index.json"; then
		print_error "Failed to fetch the Node.js release index"
		rm -rf "$tmpd"
		return 1
	fi

	# index.json is newest-first; take the first entry for this major.
	local ver
	ver="$("$runner" -e '
		const fs = require("fs");
		const list = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
		const hit = list.find(r => r.version.startsWith("v" + process.argv[2] + "."));
		process.stdout.write(hit ? hit.version : "");
	' "$tmpd/index.json" "$major")"

	if [[ -z "$ver" ]]; then
		print_error "No Node.js $major release found in the index"
		rm -rf "$tmpd"
		return 1
	fi

	local tarball="node-${ver}-linux-${arch}.tar.xz"
	print_info "Downloading $tarball ..."
	if ! "$runner" "$fetch_js" "https://nodejs.org/dist/${ver}/${tarball}" "$tmpd/$tarball"; then
		print_error "Failed to download $tarball"
		rm -rf "$tmpd"
		return 1
	fi
	if ! "$runner" "$fetch_js" "https://nodejs.org/dist/${ver}/SHASUMS256.txt" "$tmpd/SHASUMS256.txt"; then
		print_error "Failed to download SHASUMS256.txt"
		rm -rf "$tmpd"
		return 1
	fi

	# Verify integrity — the TLS certs are unverified, so this checksum matters.
	local expected actual
	expected="$(grep "  ${tarball}\$" "$tmpd/SHASUMS256.txt" | awk '{print $1}')"
	actual="$(sha256sum "$tmpd/$tarball" | awk '{print $1}')"
	if [[ -z "$expected" ]] || [[ "$expected" != "$actual" ]]; then
		print_error "SHA256 mismatch for $tarball (expected: ${expected:-none}, got: $actual)"
		rm -rf "$tmpd"
		return 1
	fi
	print_success "SHA256 verified"

	# Extract into the nvm versions layout so nvm and the launcher pick it up.
	local dest="$NVM_DIR/versions/node/${ver}"
	mkdir -p "$dest"
	if ! tar -xJf "$tmpd/$tarball" -C "$dest" --strip-components=1; then
		print_error "Failed to extract $tarball"
		rm -rf "$tmpd" "$dest"
		return 1
	fi
	rm -rf "$tmpd"

	if [[ ! -x "$dest/bin/node" ]]; then
		print_error "Node binary missing after extraction"
		return 1
	fi

	print_success "Node.js $("$dest/bin/node" --version) installed to isolated env (node-TLS)"
	return 0
}

#######################################
# Ensure the active isolated Node.js satisfies a package's engines.node.
# When the active Node is too old, offer to install the required major into the
# isolated nvm and switch to it, so npm never emits EBADENGINE for the package.
# Global packages live in the shared npm-global prefix (NPM_CONFIG_PREFIX) and
# survive the Node switch, so no per-version package migration is performed.
# Requires nvm.sh to be already sourced by the caller.
# Arguments:
#   $1 - package spec to query (default: @anthropic-ai/claude-code@latest)
# Returns:
#   0 - Node satisfies the requirement (was fine, or upgraded successfully)
#   1 - Node is still too old (user declined, or the install failed)
#######################################
ensure_isolated_node_engine() {
	local pkg="${1:-@anthropic-ai/claude-code@latest}"

	# nvm must be available to install/switch versions; otherwise skip silently.
	command -v nvm &>/dev/null || return 0

	# Minimum required major from engines.node (e.g. ">=22.0.0" -> 22).
	local engine_range required_major
	engine_range=$(npm view "$pkg" engines.node 2>/dev/null)
	required_major=$(echo "$engine_range" | grep -oE '[0-9]+' | head -1)
	[[ -z "$required_major" ]] && return 0  # unknown requirement -> nothing to enforce

	# Current active Node major.
	local current_major
	current_major=$(node --version 2>/dev/null | grep -oE '[0-9]+' | head -1)
	[[ -z "$current_major" ]] && return 0

	# Already new enough.
	(( current_major >= required_major )) && return 0

	print_warning "Node.js v$current_major is too old for $pkg (requires >= v$required_major)"
	echo ""

	# Offer before touching the environment; default yes (empty answer accepts).
	local answer
	read -r -p "Install Node.js $required_major into the isolated environment now? (Y/n): " answer
	if [[ "$answer" =~ ^[Nn]$ ]]; then
		print_info "Skipped Node.js upgrade — Claude Code $required_major+ may warn or fail on Node.js v$current_major"
		echo ""
		return 1
	fi

	print_info "Installing Node.js $required_major via the isolated nvm..."
	echo ""

	# Globals stay in npm-global (NPM_CONFIG_PREFIX), so a plain install + use is
	# enough; the launcher (setup_isolated_nvm) then picks the highest version.
	# `nvm install` already activates the version, so the defensive `nvm use` runs
	# with --silent — otherwise "Now using node ..." is printed twice.
	if nvm install "$required_major" && nvm use --silent "$required_major"; then
		print_success "Node.js upgraded to $(node --version) (isolated)"
		echo ""
		return 0
	fi

	# nvm's download failed — commonly the system curl/OpenSSL cannot reach the
	# Node mirror on this host (e.g. 'TLS unsupported algorithm'), while Node's own
	# TLS can. Fall back to the node-TLS fetcher before giving up.
	echo ""
	print_warning "nvm could not download Node.js; trying the node-TLS fallback..."
	echo ""
	if fetch_node_via_node_tls "$required_major"; then
		# Activate the freshly extracted version for the rest of this process.
		local newdir
		newdir="$(find "$NVM_DIR/versions/node" -maxdepth 1 -type d -name "v${required_major}.*" 2>/dev/null | LC_ALL=C sort | tail -1)"
		if [[ -n "$newdir" ]]; then
			nvm use "$(basename "$newdir")" &>/dev/null || export PATH="$newdir/bin:$PATH"
		fi
		print_success "Node.js upgraded to $(node --version) (isolated, node-TLS)"
		echo ""
		return 0
	fi

	# Both paths failed — actionable guidance.
	echo ""
	print_error "Failed to install Node.js $required_major in the isolated environment"
	echo ""
	echo "Neither nvm (system curl) nor the node-TLS fallback could fetch Node.js."
	echo "Check network/proxy reachability to nodejs.org, or:"
	echo "  • point nvm at a reachable mirror: export NVM_NODEJS_ORG_MIRROR=<mirror>"
	echo "  • or drop a Node.js $required_major build under:"
	echo "      $NVM_DIR/versions/node/v$required_major.<minor>.<patch>/"
	echo "  then re-run: iclaude --update"
	return 1
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
	# Store-level lock, long timeout for npm work (S6); falls back to unlocked
	# when lock.sh is not loaded.
	if declare -f iclaude_with_lock >/dev/null 2>&1; then
		iclaude_with_lock "${ISOLATED_NVM_DIR}/.iclaude-store.lock" 600 _install_npm_package_with_lockfile_unlocked "$@"
	else
		_install_npm_package_with_lockfile_unlocked "$@"
	fi
}

_install_npm_package_with_lockfile_unlocked() {
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
		# S8: pin the installed Claude native binary by sha256 (claude only).
		if [[ "$package_name" == "@anthropic-ai/claude-code" ]] \
			&& declare -f record_claude_binary_hash &>/dev/null; then
			record_claude_binary_hash
		fi
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
