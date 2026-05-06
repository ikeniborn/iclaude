#!/bin/bash
# Graphify installation module
# Provides: install_graphify(), _graphify_rebuild_graph(), _graphify_resolve_proxy(), _graphify_install_command()

#######################################
# Resolve proxy URL from environment
# Outputs: proxy URL string (or empty)
#######################################
_graphify_resolve_proxy() {
    echo "${HTTPS_PROXY:-${HTTP_PROXY:-${PROXY_URL:-}}}"
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

    local project_root
    project_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")

    local output_dir
    if [[ -n "$GRAPHIFY_OUTPUT_DIR" ]]; then
        if [[ "$GRAPHIFY_OUTPUT_DIR" = /* ]]; then
            output_dir="$GRAPHIFY_OUTPUT_DIR"
        else
            output_dir="${project_root}/${GRAPHIFY_OUTPUT_DIR}"
        fi
    else
        output_dir="$project_root"
    fi

    mkdir -p "$output_dir"
    print_info "Building knowledge graph → $output_dir"

    # Build args array to handle extra args safely
    local -a graphify_args=(".")
    [[ -n "$output_dir" ]] && graphify_args+=("--output-dir" "$output_dir")
    # Split GRAPHIFY_EXTRA_ARGS on whitespace (intentional word splitting for flag list)
    # shellcheck disable=SC2086
    [[ -n "$GRAPHIFY_EXTRA_ARGS" ]] && read -ra _extra <<< "$GRAPHIFY_EXTRA_ARGS" && graphify_args+=("${_extra[@]}")

    local proxy
    proxy=$(_graphify_resolve_proxy)
    local proxy_env=()
    if [[ -n "$proxy" ]]; then
        proxy_env=(env UV_HTTP_PROXY="$proxy" UV_HTTPS_PROXY="$proxy")
    fi

    UV_TOOL_DIR="$GRAPHIFY_TOOL_DIR" \
        "${proxy_env[@]}" \
        "$GRAPHIFY_UV_BIN" tool run graphify "${graphify_args[@]}"
}

#######################################
# Install graphify in isolated environment.
# Installs uv, then graphifyy via uv tool install.
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
    if [[ -n "$proxy" ]]; then
        proxy_env=(env UV_HTTP_PROXY="$proxy" UV_HTTPS_PROXY="$proxy")
    fi

    # Step 1: Install uv if missing
    if [[ ! -x "$GRAPHIFY_UV_BIN" ]]; then
        print_info "Installing uv to ${ISOLATED_NVM_DIR}/bin/ ..."
        if ! "${proxy_env[@]}" \
            env INSTALLER_NO_MODIFY_PATH=1 UV_INSTALL_DIR="${ISOLATED_NVM_DIR}/bin" \
            sh -c "$(curl -LsSf https://astral.sh/uv/install.sh)"; then
            print_error "Failed to install uv"
            return 1
        fi
        print_success "uv installed: $GRAPHIFY_UV_BIN"
    else
        local uv_ver
        uv_ver=$("$GRAPHIFY_UV_BIN" --version 2>/dev/null || echo "unknown")
        print_success "uv already present ($uv_ver)"
    fi

    # Step 2: Install graphifyy via uv tool
    print_info "Installing graphifyy (Python 3.12) ..."
    if ! UV_TOOL_DIR="$GRAPHIFY_TOOL_DIR" \
        UV_PYTHON_INSTALL_DIR="$GRAPHIFY_PYTHON_DIR" \
        "${proxy_env[@]}" \
        "$GRAPHIFY_UV_BIN" tool install graphifyy --python 3.12; then
        print_error "Failed to install graphifyy"
        return 1
    fi
    print_success "graphifyy installed"

    # Step 3: graphify install (Claude Code skill setup)
    print_info "Setting up Claude Code skill ..."
    if UV_TOOL_DIR="$GRAPHIFY_TOOL_DIR" \
        "$GRAPHIFY_UV_BIN" tool run graphify install 2>/dev/null; then
        print_success "Claude Code skill configured"
    else
        print_warning "graphify install returned non-zero (skill setup optional — continuing)"
    fi

    # Step 4: Create commands/graphify
    _graphify_install_command || return 1

    echo ""
    print_success "Graphify installed successfully!"
    echo ""
    print_info "Next steps:"
    print_info "  Status:           ./iclaude.sh --check-graphify"
    print_info "  Build graph:      ./iclaude.sh --graphify"
    print_info "  In Claude Code:   /graphify-update (slash command)"
    echo ""
    return 0
}

#######################################
# Create commands/graphify-update.md Claude Code slash command.
# Invoked as /graphify-update inside a Claude Code session.
# Returns: 0 on success, 1 on failure
#######################################
_graphify_install_command() {
    local commands_dir="${ISOLATED_CONFIG_DIR}/commands"
    local cmd_path="${commands_dir}/graphify-update.md"

    mkdir -p "$commands_dir"

    # Write markdown slash command for Claude Code (/graphify-update)
    # Triple backticks inside heredoc are literal — no bash interpretation needed.
    cat > "$cmd_path" << 'GRAPHIFY_MD'
---
description: Rebuild graphify knowledge graph for the current project
---

Rebuild the graphify knowledge graph for the current project. Run the following bash command and report the result:

```bash
_gfy_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
if [[ -n "${GRAPHIFY_OUTPUT_DIR:-}" ]]; then
    if [[ "${GRAPHIFY_OUTPUT_DIR}" = /* ]]; then
        _gfy_out="${GRAPHIFY_OUTPUT_DIR}"
    else
        _gfy_out="${_gfy_root}/${GRAPHIFY_OUTPUT_DIR}"
    fi
else
    _gfy_out="${_gfy_root}"
fi
mkdir -p "$_gfy_out"
UV_TOOL_DIR="${GRAPHIFY_TOOL_DIR}" "${GRAPHIFY_UV_BIN}" tool run graphify . \
    --output-dir "$_gfy_out" ${GRAPHIFY_EXTRA_ARGS:+${GRAPHIFY_EXTRA_ARGS}}
```

After the command completes, report: success or failure, output directory path, and briefly what was analyzed.
GRAPHIFY_MD

    print_success "Slash command created: /graphify-update ($cmd_path)"
}
