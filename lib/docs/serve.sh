#!/usr/bin/env bash
# lib/docs/serve.sh
# Sphinx Documentation - Live Preview Server
#
# Serves built documentation on localhost

#######################################
# Serve Sphinx documentation with live preview
# Builds if needed, then starts HTTP server
# Arguments:
#   $1 - project path (default: pwd)
#   $2 - port number (default: 8000)
# Returns:
#   0 - Server started (or stopped by user)
#   1 - Build failed or python3 not available
# Example: serve_sphinx_docs /path/to/project 8080
#######################################
if ! declare -F serve_sphinx_docs &>/dev/null; then
serve_sphinx_docs() {
    local project_path
    project_path=$(get_docs_project_dir "${1:-$(pwd)}")
    local port="${2:-8000}"
    local build_dir
    build_dir=$(get_docs_build_dir "$project_path")

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Sphinx Documentation Server"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_info "Project: $project_path"

    # Build if not yet built
    if [[ ! -f "$build_dir/index.html" ]]; then
        print_info "Documentation not built yet. Building..."
        echo ""
        if ! build_sphinx_docs "$project_path"; then
            return 1
        fi
    fi

    if ! command -v python3 &>/dev/null; then
        print_error "python3 not found. Cannot start HTTP server."
        return 1
    fi

    # Find free port if requested port is busy
    local try_port="$port"
    while ! python3 -c "import socket; s=socket.socket(); s.bind(('', ${try_port})); s.close()" 2>/dev/null; do
        try_port=$((try_port + 1))
        if [[ $try_port -gt $((port + 20)) ]]; then
            print_error "No free port found in range ${port}-$((port + 20))"
            return 1
        fi
    done
    if [[ "$try_port" != "$port" ]]; then
        print_info "Port $port busy, using port $try_port"
    fi
    port="$try_port"

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
