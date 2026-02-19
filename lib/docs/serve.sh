#!/usr/bin/env bash
# lib/docs/serve.sh
# Sphinx Documentation - Live Preview Server
#
# Serves built documentation on localhost:8000

#######################################
# Serve Sphinx documentation with live preview
# Builds if needed, then starts HTTP server on localhost:8000
# Arguments:
#   $1 - port number (default: 8000)
# Returns:
#   0 - Server started (or stopped by user)
#   1 - Build failed or python3 not available
# Example: serve_sphinx_docs 8080
#######################################
if ! declare -F serve_sphinx_docs &>/dev/null; then
serve_sphinx_docs() {
    local port="${1:-8000}"
    local docs_dir="${SCRIPT_DIR}/docs"
    local build_dir="${docs_dir}/_build/html"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Sphinx Documentation Server"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Build if not yet built
    if [[ ! -f "$build_dir/index.html" ]]; then
        print_info "Documentation not built yet. Building..."
        echo ""
        if ! build_sphinx_docs; then
            return 1
        fi
    fi

    if ! command -v python3 &>/dev/null; then
        print_error "python3 not found. Cannot start HTTP server."
        return 1
    fi

    print_success "Documentation available at: http://localhost:$port"
    echo ""
    echo "  Press Ctrl+C to stop"
    echo ""

    # Try to open in browser (non-blocking)
    if command -v xdg-open &>/dev/null; then
        (sleep 1 && xdg-open "http://localhost:$port" 2>/dev/null) &
    fi

    # Start server
    python3 -m http.server "$port" --directory "$build_dir"

    return 0
}
fi
