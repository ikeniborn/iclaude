#!/usr/bin/env bash
# lib/docs/status.sh
# Sphinx Documentation - Status Check
#
# Checks installation status of Sphinx documentation environment

#######################################
# Check Sphinx documentation environment status for a project
# Verifies python3, venv, sphinx installation and build output
# Arguments:
#   $1 - project path (default: pwd)
# Returns:
#   0 - Sphinx fully operational
#   1 - Not installed or partially installed
# Example: check_docs_status /path/to/project
#######################################
if ! declare -F check_docs_status &>/dev/null; then
check_docs_status() {
    local project_path
    project_path=$(get_docs_project_dir "${1:-$(pwd)}")
    local venv_dir
    venv_dir=$(get_docs_venv_dir)
    local sphinx_dir
    sphinx_dir=$(get_docs_sphinx_dir "$project_path")
    local build_dir
    build_dir=$(get_docs_build_dir "$project_path")

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Sphinx Documentation Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  PROJECT: $project_path"
    echo ""

    local status_ok=true

    # ── Section 1: Global (Python, Sphinx venv) ────────────────────────────
    echo "  Global environment:"

    # Check python3
    if command -v python3 &>/dev/null; then
        local python_version
        python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        echo "    Python 3:      ✓ $python_version"
    else
        echo "    Python 3:      ✗ not found"
        status_ok=false
    fi

    # Check venv / sphinx-build
    if [[ -f "$venv_dir/bin/sphinx-build" ]]; then
        local sphinx_version
        sphinx_version=$("$venv_dir/bin/sphinx-build" --version 2>&1 | cut -d' ' -f2)
        echo "    Sphinx:        ✓ $sphinx_version"
        echo "    Venv:          $venv_dir"
    else
        echo "    Sphinx:        ✗ not installed"
        echo "                   Run: ./iclaude.sh --install-docs"
        status_ok=false
    fi

    # Check myst-parser
    if [[ -f "$venv_dir/bin/python" ]] && "$venv_dir/bin/python" -c "import myst_parser" 2>/dev/null; then
        echo "    MyST Parser:   ✓ installed"
    else
        echo "    MyST Parser:   ✗ not installed"
        status_ok=false
    fi

    # Check sphinx-llms-txt
    if [[ -f "$venv_dir/bin/python" ]] && "$venv_dir/bin/python" -c "import sphinx_llms_txt" 2>/dev/null; then
        echo "    sphinx-llms:   ✓ installed (llms.txt enabled)"
    else
        echo "    sphinx-llms:   - not installed (llms.txt disabled)"
    fi

    echo ""

    # ── Section 2: Project-specific ───────────────────────────────────────
    echo "  Project ($project_path):"

    local project_type
    project_type=$(detect_project_type "$project_path")
    echo "    Type:          $project_type"

    # Check conf.py in sphinx_dir
    if [[ -f "${sphinx_dir}/conf.py" ]]; then
        echo "    conf.py:       ✓ ${sphinx_dir}/conf.py"
    else
        echo "    conf.py:       ✗ not found"
        echo "                   Run: ./iclaude.sh --init-docs $project_path"
        status_ok=false
    fi

    # Check index.md
    if [[ -f "${sphinx_dir}/index.md" ]]; then
        echo "    index.md:      ✓ ${sphinx_dir}/index.md"
    else
        echo "    index.md:      ✗ not found"
        status_ok=false
    fi

    # Check built docs
    if [[ -f "$build_dir/index.html" ]]; then
        local build_date
        build_date=$(date -r "$build_dir/index.html" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
        echo "    HTML build:    ✓ built ($build_date)"

        if [[ -f "$build_dir/llms.txt" ]]; then
            echo "    llms.txt:      ✓ $build_dir/llms.txt"
        else
            echo "    llms.txt:      - not generated"
        fi
    else
        echo "    HTML build:    - not built yet"
        echo "                   Run: ./iclaude.sh --build-docs $project_path"
    fi

    echo ""
    if [[ "$status_ok" == true ]]; then
        print_success "Sphinx documentation environment: OK"
    else
        print_warning "Sphinx not fully installed"
        echo ""
        echo "  To install: ./iclaude.sh --install-docs"
        echo "  To init:    ./iclaude.sh --init-docs $project_path"
    fi
    echo ""

    [[ "$status_ok" == true ]]
}
fi
