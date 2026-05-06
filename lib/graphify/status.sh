#!/bin/bash
# Graphify status module
# Provides: check_graphify_status()

#######################################
# Display graphify installation status.
# Shows uv, graphifyy version, Python, disk usage, output dir.
# Returns: 0 always
#######################################
check_graphify_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Graphify: Knowledge Graph Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # uv binary (isolated preferred, system fallback)
    local uv_bin
    uv_bin=$(_graphify_resolve_uv)
    if [[ -n "$uv_bin" ]]; then
        local uv_ver
        uv_ver=$("$uv_bin" --version 2>/dev/null || echo "unknown")
        print_success "uv: $uv_bin ($uv_ver)"
    else
        print_warning "uv: not found (isolated: $GRAPHIFY_UV_BIN, system: not in PATH)"
        echo "  Run: ./iclaude.sh --install-graphify"
        echo ""
        return 0
    fi

    # graphify binary
    local graphify_bin="${GRAPHIFY_TOOL_DIR}/graphifyy/bin/graphify"
    if [[ -x "$graphify_bin" ]]; then
        local gfy_ver
        gfy_ver=$("$graphify_bin" --version 2>/dev/null || echo "unknown")
        print_success "graphify: $graphify_bin ($gfy_ver)"
    else
        print_warning "graphify: not installed"
        echo "  Run: ./iclaude.sh --install-graphify"
    fi

    # Python 3.12 — check isolated dir first, then let uv find it (system or managed)
    local py_bin py_ver
    py_bin=$(find "$GRAPHIFY_PYTHON_DIR" -name "python3.12" -maxdepth 4 -type f 2>/dev/null | head -1 || true)
    if [[ -z "$py_bin" ]]; then
        py_bin=$("$uv_bin" python find 3.12 2>/dev/null || true)
    fi
    if [[ -n "$py_bin" ]]; then
        py_ver=$("$py_bin" --version 2>/dev/null || echo "unknown")
        print_success "Python: $py_ver ($py_bin)"
    else
        print_warning "Python 3.12: not found"
    fi

    # Disk usage
    if [[ -d "$GRAPHIFY_TOOL_DIR" ]]; then
        local disk_size
        disk_size=$(du -sh "$GRAPHIFY_TOOL_DIR" 2>/dev/null | cut -f1 || echo "unknown")
        print_info "Tool dir: $GRAPHIFY_TOOL_DIR ($disk_size)"
    else
        print_info "Tool dir: $GRAPHIFY_TOOL_DIR (not created yet)"
    fi

    local git_root
    git_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
    local out_name="${GRAPHIFY_OUT:-graphify-out}"
    print_info "Graph output: ${git_root}/${out_name}/"

    echo ""
    return 0
}
