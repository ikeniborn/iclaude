#!/bin/bash
# Graphify installation module
# Provides: install_graphify(), _graphify_rebuild_graph(), _graphify_resolve_proxy(), _graphify_resolve_uv()

#######################################
# Resolve proxy URL from environment
# Outputs: proxy URL string (or empty)
#######################################
_graphify_resolve_proxy() {
    echo "${HTTPS_PROXY:-${HTTP_PROXY:-${PROXY_URL:-}}}"
}

#######################################
# Resolve uv binary: prefer isolated path, fall back to system PATH.
# Outputs: path to uv binary, or empty string if not found
#######################################
_graphify_resolve_uv() {
    if [[ -x "$GRAPHIFY_UV_BIN" ]]; then
        echo "$GRAPHIFY_UV_BIN"
    elif command -v uv &>/dev/null; then
        command -v uv
    fi
}

#######################################
# Rebuild knowledge graph for current project.
# Called by --graphify flag before launching claude.
# Returns: 0 on success, 1 on failure
#######################################
_graphify_rebuild_graph() {
    if ! detect_graphify; then
        print_error "graphify not installed. Run: ./iclaude.sh --install-graphify"
        return 1
    fi

    local uv_bin
    uv_bin=$(_graphify_resolve_uv)

    local project_root
    project_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")

    local out_label="${GRAPHIFY_OUT:-graphify-out}"
    print_info "Building knowledge graph → ${project_root}/${out_label}/"

    # Build args: "update <project_root>" [extra_args...]
    local -a graphify_args=("update" "$project_root")
    # Split GRAPHIFY_EXTRA_ARGS on whitespace (intentional word splitting for flag list)
    # shellcheck disable=SC2086
    [[ -n "$GRAPHIFY_EXTRA_ARGS" ]] && read -ra _extra <<< "$GRAPHIFY_EXTRA_ARGS" && graphify_args+=("${_extra[@]}")

    # Build env args for single env(1) call: GRAPHIFY_OUT + proxy vars
    local -a env_args=()
    [[ -n "$GRAPHIFY_OUT" ]] && env_args+=(GRAPHIFY_OUT="$GRAPHIFY_OUT")
    local proxy
    proxy=$(_graphify_resolve_proxy)
    if [[ -n "$proxy" ]]; then
        env_args+=(UV_HTTP_PROXY="$proxy" UV_HTTPS_PROXY="$proxy")
    fi

    UV_TOOL_DIR="$GRAPHIFY_TOOL_DIR" \
        env "${env_args[@]}" \
        "$uv_bin" tool run --from graphifyy graphify "${graphify_args[@]}"
}

#######################################
# Install graphify in isolated environment.
# Installs uv (isolated preferred, system fallback), then graphifyy via uv tool install.
# Args: [--force] — remove existing tool dir before install
# Returns: 0 on success, 1 on failure
#######################################
install_graphify() {
    local force=false
    [[ "${1:-}" == "--force" ]] && force=true

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Graphify: Install Knowledge Graph Tool"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check isolated environment
    if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
        print_error "Isolated environment not found. Run --isolated-install first."
        return 1
    fi

    # Force: remove existing tool dir
    if [[ "$force" == true ]] && [[ -d "$GRAPHIFY_TOOL_DIR" ]]; then
        print_info "Force reinstall: removing $GRAPHIFY_TOOL_DIR"
        rm -rf "$GRAPHIFY_TOOL_DIR"
    fi

    local proxy
    proxy=$(_graphify_resolve_proxy)
    local proxy_env=()
    local curl_proxy_args=()
    if [[ -n "$proxy" ]]; then
        proxy_env=(env HTTP_PROXY="$proxy" HTTPS_PROXY="$proxy")
        curl_proxy_args=(-x "$proxy")
        # When HTTPS_PROXY is set in env and proxy uses EC cert (P-384/E7),
        # OpenSSL 1.1.1 fails to parse the cert without -k even with --proxy-insecure.
        # Both flags are required for the bootstrap curl download.
        if [[ "$proxy" == https://* ]]; then
            curl_proxy_args+=(--proxy-insecure -k)
        fi
    fi

    # Step 1: Find or install uv (isolated preferred, system fallback)
    local uv_bin
    uv_bin=$(_graphify_resolve_uv)
    if [[ -z "$uv_bin" ]]; then
        print_info "Downloading uv binary to ${ISOLATED_NVM_DIR}/bin/ ..."
        local _uv_url="https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-unknown-linux-gnu.tar.gz"
        local _uv_tmp
        _uv_tmp=$(mktemp -d)
        if ! curl -fsSL "${curl_proxy_args[@]}" -o "$_uv_tmp/uv.tar.gz" "$_uv_url"; then
            rm -rf "$_uv_tmp"
            print_error "Failed to download uv binary (check network/TLS/proxy)"
            return 1
        fi
        if ! tar -xzf "$_uv_tmp/uv.tar.gz" -C "$_uv_tmp" --strip-components=1 --wildcards '*/uv' 2>/dev/null; then
            rm -rf "$_uv_tmp"
            print_error "Failed to extract uv binary"
            return 1
        fi
        mkdir -p "${ISOLATED_NVM_DIR}/bin"
        mv "$_uv_tmp/uv" "${ISOLATED_NVM_DIR}/bin/uv"
        chmod +x "${ISOLATED_NVM_DIR}/bin/uv"
        rm -rf "$_uv_tmp"
        uv_bin=$(_graphify_resolve_uv)
        if [[ -z "$uv_bin" ]]; then
            print_error "uv not found after install — TLS or network issue likely. Check proxy settings."
            return 1
        fi
        print_success "uv installed: $uv_bin"
    else
        local uv_ver
        uv_ver=$("$uv_bin" --version 2>/dev/null || echo "unknown")
        print_success "uv found: $uv_bin ($uv_ver)"
    fi

    # Step 2: Install graphifyy via uv tool
    print_info "Installing graphifyy (Python 3.12) ..."
    if ! UV_TOOL_DIR="$GRAPHIFY_TOOL_DIR" \
        UV_PYTHON_INSTALL_DIR="$GRAPHIFY_PYTHON_DIR" \
        "${proxy_env[@]}" \
        "$uv_bin" tool install graphifyy --python 3.12; then
        print_error "Failed to install graphifyy"
        return 1
    fi
    print_success "graphifyy installed"

    # Step 3: graphify install (Claude Code skill setup)
    print_info "Setting up Claude Code skill ..."
    if UV_TOOL_DIR="$GRAPHIFY_TOOL_DIR" \
        CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" \
        "$uv_bin" tool run --from graphifyy graphify install 2>/dev/null; then
        print_success "Claude Code skill configured"
    else
        print_warning "graphify install returned non-zero (skill setup optional — continuing)"
    fi

    echo ""
    print_success "Graphify installed successfully!"
    echo ""
    print_info "Next steps:"
    print_info "  Status:           ./iclaude.sh --check-graphify"
    print_info "  Build graph:      ./iclaude.sh --graphify"
    print_info "  In Claude Code:   /graphify"
    echo ""
    return 0
}
