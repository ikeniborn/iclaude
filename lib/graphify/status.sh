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

    # uv binary
    if [[ -x "$GRAPHIFY_UV_BIN" ]]; then
        local uv_ver
        uv_ver=$("$GRAPHIFY_UV_BIN" --version 2>/dev/null || echo "unknown")
        print_success "uv: $GRAPHIFY_UV_BIN ($uv_ver)"
    else
        print_warning "uv: not found at $GRAPHIFY_UV_BIN"
        echo "  Run: ./iclaude.sh --install-graphify"
        echo ""
        return 0
    fi

    # graphify binary
    local graphify_bin="${GRAPHIFY_TOOL_DIR}/bin/graphify"
    if [[ -x "$graphify_bin" ]]; then
        local gfy_ver
        gfy_ver=$("$graphify_bin" --version 2>/dev/null || echo "unknown")
        print_success "graphifyy: $graphify_bin ($gfy_ver)"
    else
        print_warning "graphifyy: not installed"
        echo "  Run: ./iclaude.sh --install-graphify"
    fi

    # Python version (read from installed path — no network, no download)
    local py_bin py_ver
    py_bin=$(find "$GRAPHIFY_PYTHON_DIR" -name "python3.12" -maxdepth 4 -type f 2>/dev/null | head -1 || true)
    if [[ -n "$py_bin" ]]; then
        py_ver=$("$py_bin" --version 2>/dev/null || echo "unknown")
        print_success "Python: $py_ver"
    else
        print_warning "Python 3.12: not yet downloaded (installed on first --install-graphify)"
    fi

    # Disk usage
    if [[ -d "$GRAPHIFY_TOOL_DIR" ]]; then
        local disk_size
        disk_size=$(du -sh "$GRAPHIFY_TOOL_DIR" 2>/dev/null | cut -f1 || echo "unknown")
        print_info "Tool dir: $GRAPHIFY_TOOL_DIR ($disk_size)"
    else
        print_info "Tool dir: $GRAPHIFY_TOOL_DIR (not created yet)"
    fi

    # Output dir
    if [[ -n "$GRAPHIFY_OUTPUT_DIR" ]]; then
        print_info "Output dir: $GRAPHIFY_OUTPUT_DIR (from GRAPHIFY_OUTPUT_DIR)"
    else
        local git_root
        git_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "(not a git repo — will use \$PWD)")
        print_info "Output dir: $git_root (git root, default)"
    fi

    echo ""
    return 0
}
