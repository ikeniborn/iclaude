#!/usr/bin/env bash
# lib/docs/build.sh
# Sphinx Documentation - Build
#
# Builds HTML documentation and generates llms.txt for AI agents

#######################################
# Build Sphinx documentation
# Generates API reference from lib/*.sh, then builds HTML site
# Arguments:
#   $1 - clean build flag (--clean, optional)
# Returns:
#   0 - Success
#   1 - Sphinx not installed or build failed
# Example: build_sphinx_docs --clean
#######################################
if ! declare -F build_sphinx_docs &>/dev/null; then
build_sphinx_docs() {
    local clean_flag="${1:-}"
    local venv_dir="${ISOLATED_NVM_DIR:-.nvm-isolated}/.python-docs"
    local docs_dir="${SCRIPT_DIR}/docs"
    local build_dir="${docs_dir}/_build/html"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Building Sphinx Documentation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check venv exists
    if [[ ! -f "$venv_dir/bin/sphinx-build" ]]; then
        print_error "Sphinx not installed. Run: ./iclaude.sh --install-docs"
        return 1
    fi

    # Check conf.py exists
    if [[ ! -f "$docs_dir/conf.py" ]]; then
        print_error "docs/conf.py not found. Repository may be incomplete."
        return 1
    fi

    # Generate API reference from bash modules
    print_info "Generating API reference from lib/*.sh..."
    generate_api_reference "${SCRIPT_DIR}/lib" "${docs_dir}/api-reference"
    echo ""

    # Clean build if requested
    if [[ "$clean_flag" == "--clean" ]] && [[ -d "${docs_dir}/_build" ]]; then
        print_info "Cleaning previous build..."
        rm -rf "${docs_dir}/_build"
    fi

    # Activate venv and build
    # shellcheck source=/dev/null
    source "$venv_dir/bin/activate"

    print_info "Running sphinx-build..."
    echo ""

    local build_output
    if build_output=$(sphinx-build -b html "$docs_dir" "$build_dir" -q 2>&1); then
        deactivate
        echo ""
        print_success "Documentation built successfully"
        echo ""
        echo "  HTML:     $build_dir/index.html"

        # Check for llms.txt
        if [[ -f "$build_dir/llms.txt" ]]; then
            print_success "llms.txt generated for AI agents"
            echo "  llms.txt: $build_dir/llms.txt"
        fi

        echo ""
        echo "  View: ./iclaude.sh --serve-docs"
        echo "  Or:   python3 -m http.server 8000 --directory $build_dir"
        echo ""
    else
        deactivate
        echo ""
        print_error "Sphinx build failed:"
        echo "$build_output"
        echo ""
        return 1
    fi

    return 0
}
fi
