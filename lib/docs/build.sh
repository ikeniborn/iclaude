#!/usr/bin/env bash
# lib/docs/build.sh
# Sphinx Documentation - Build
#
# Builds HTML documentation and generates llms.txt for AI agents

#######################################
# Build Sphinx documentation for a project
# Generates API reference from lib/*.sh (bash projects), then builds HTML site
# Arguments:
#   $1 - project path (default: pwd)
#   $2 - clean build flag (--clean, optional)
# Returns:
#   0 - Success
#   1 - Sphinx not installed, not initialized, or build failed
# Example: build_sphinx_docs /path/to/project --clean
#######################################
if ! declare -F build_sphinx_docs &>/dev/null; then
build_sphinx_docs() {
    local project_path
    project_path=$(get_docs_project_dir "${1:-$(pwd)}")
    local clean_flag="${2:-}"
    local venv_dir
    venv_dir=$(get_docs_venv_dir)
    local sphinx_dir
    sphinx_dir=$(get_docs_sphinx_dir "$project_path")
    local build_dir
    build_dir=$(get_docs_build_dir "$project_path")

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Building Sphinx Documentation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_info "Project: $project_path"

    # Check venv exists
    if [[ ! -f "$venv_dir/bin/sphinx-build" ]]; then
        print_error "Sphinx not installed. Run: ./iclaude.sh --install-docs"
        return 1
    fi

    # Check conf.py exists in sphinx_dir
    if [[ ! -f "${sphinx_dir}/conf.py" ]]; then
        print_error "Not initialized. Run: ./iclaude.sh --init-docs $project_path"
        return 1
    fi

    # Generate API reference for bash projects only
    local src_dir
    src_dir=$(get_docs_src_for_api_ref "$project_path")
    if [[ -n "$src_dir" ]]; then
        local api_ref_dir
        api_ref_dir=$(get_docs_api_ref_dir "$project_path")
        print_info "Generating API reference from lib/*.sh..."
        generate_api_reference "$src_dir" "$api_ref_dir"
        echo ""
    fi

    # Clean build if requested
    if [[ "$clean_flag" == "--clean" ]] && [[ -d "${sphinx_dir}/_build" ]]; then
        print_info "Cleaning previous build..."
        rm -rf "${sphinx_dir}/_build"
    fi

    # Activate venv and build
    # shellcheck source=/dev/null
    source "$venv_dir/bin/activate"

    print_info "Running sphinx-build..."
    echo ""

    # Determine source root: if conf.py sets root_doc (docs outside docs/sphinx/),
    # use docs/ as source root with -c pointing to docs/sphinx/.
    local source_root="$sphinx_dir"
    local confdir_flag=()
    local doctrees_dir="${sphinx_dir}/_build/.doctrees"
    if grep -q "^root_doc" "${sphinx_dir}/conf.py" 2>/dev/null; then
        # docs/ is the source root; conf.py is in docs/sphinx/
        source_root="${project_path}/docs"
        confdir_flag=("-c" "$sphinx_dir")
    fi

    local build_output
    if build_output=$(sphinx-build -b html \
        -d "$doctrees_dir" \
        "${confdir_flag[@]}" \
        "$source_root" "$build_dir" -q 2>&1); then
        deactivate
        echo ""
        print_success "Documentation built successfully"
        echo ""
        echo "  HTML:     $build_dir/index.html"

        # Copy llms.txt / llms-full.txt to docs/ for git tracking
        local docs_dir="${project_path}/docs"
        if [[ -f "$build_dir/llms.txt" ]]; then
            cp "$build_dir/llms.txt" "${docs_dir}/llms.txt"
            print_success "llms.txt → docs/llms.txt (committed to git)"
            echo "  llms.txt: ${docs_dir}/llms.txt"
        fi
        if [[ -f "$build_dir/llms-full.txt" ]]; then
            cp "$build_dir/llms-full.txt" "${docs_dir}/llms-full.txt"
            print_success "llms-full.txt → docs/llms-full.txt (committed to git)"
            echo "  llms-full: ${docs_dir}/llms-full.txt"
        fi

        echo ""
        echo "  View: ./iclaude.sh --serve-docs $project_path"
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
