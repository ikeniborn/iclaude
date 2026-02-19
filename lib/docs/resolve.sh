#!/usr/bin/env bash
# lib/docs/resolve.sh
# Sphinx Documentation - Path Resolution
#
# Per-project helper functions: resolve paths, detect project type.
# All functions accept $1=project_path (default: pwd).
# Pattern: path helper module (analogous to other lib/*/init.sh files)

#######################################
# Get absolute project directory
# Arguments:
#   $1 - project path (default: pwd)
# Returns:
#   0 - prints absolute path
# Example: get_docs_project_dir /path/to/project
#######################################
if ! declare -F get_docs_project_dir &>/dev/null; then
get_docs_project_dir() {
    local path="${1:-$(pwd)}"
    if [[ -d "$path" ]]; then
        realpath "$path" 2>/dev/null || readlink -f "$path" 2>/dev/null || echo "$path"
    else
        echo "$path"
    fi
}
fi

#######################################
# Get project name from git remote or directory basename
# Arguments:
#   $1 - project path (default: pwd)
# Returns:
#   0 - prints project name
# Example: get_docs_project_name /path/to/project
#######################################
if ! declare -F get_docs_project_name &>/dev/null; then
get_docs_project_name() {
    local project_path
    project_path=$(get_docs_project_dir "${1:-$(pwd)}")
    local name
    # Try git remote URL basename
    name=$(git -C "$project_path" remote get-url origin 2>/dev/null \
        | sed 's|.*[:/]||' | sed 's|\.git$||')
    if [[ -z "$name" ]]; then
        name=$(basename "$project_path")
    fi
    echo "$name"
}
fi

#######################################
# Get global Sphinx venv directory (shared across all projects)
# Arguments:
#   None
# Returns:
#   0 - prints venv path
# Example: get_docs_venv_dir
#######################################
if ! declare -F get_docs_venv_dir &>/dev/null; then
get_docs_venv_dir() {
    if [[ -n "${ISOLATED_NVM_DIR:-}" ]]; then
        echo "${ISOLATED_NVM_DIR}/.python-docs"
    else
        echo "${HOME}/.local/share/sphinx-docs"
    fi
}
fi

#######################################
# Get project Sphinx source directory (docs/sphinx/)
# Arguments:
#   $1 - project path (default: pwd)
# Returns:
#   0 - prints sphinx dir path
# Example: get_docs_sphinx_dir /path/to/project
#######################################
if ! declare -F get_docs_sphinx_dir &>/dev/null; then
get_docs_sphinx_dir() {
    local project_path
    project_path=$(get_docs_project_dir "${1:-$(pwd)}")
    echo "${project_path}/docs/sphinx"
}
fi

#######################################
# Get Sphinx HTML build output directory
# Arguments:
#   $1 - project path (default: pwd)
# Returns:
#   0 - prints build dir path
# Example: get_docs_build_dir /path/to/project
#######################################
if ! declare -F get_docs_build_dir &>/dev/null; then
get_docs_build_dir() {
    local project_path
    project_path=$(get_docs_project_dir "${1:-$(pwd)}")
    echo "${project_path}/docs/sphinx/_build/html"
}
fi

#######################################
# Get API reference directory inside sphinx source
# Arguments:
#   $1 - project path (default: pwd)
# Returns:
#   0 - prints api-reference dir path
# Example: get_docs_api_ref_dir /path/to/project
#######################################
if ! declare -F get_docs_api_ref_dir &>/dev/null; then
get_docs_api_ref_dir() {
    local project_path
    project_path=$(get_docs_project_dir "${1:-$(pwd)}")
    echo "${project_path}/docs/sphinx/api-reference"
}
fi

#######################################
# Detect project type based on files present
# Arguments:
#   $1 - project path (default: pwd)
# Returns:
#   0 - prints one of: bash|python|node|generic
# Example: detect_project_type /path/to/project
#######################################
if ! declare -F detect_project_type &>/dev/null; then
detect_project_type() {
    local project_path
    project_path=$(get_docs_project_dir "${1:-$(pwd)}")

    # bash: lib/*.sh or *.sh in root
    if [[ -d "${project_path}/lib" ]] && ls "${project_path}/lib"/*.sh "${project_path}/lib"/**/*.sh 2>/dev/null | grep -q '.'; then
        echo "bash"
        return 0
    fi
    if ls "${project_path}"/*.sh 2>/dev/null | grep -q '.'; then
        echo "bash"
        return 0
    fi

    # python
    if [[ -f "${project_path}/pyproject.toml" ]] || [[ -f "${project_path}/setup.py" ]]; then
        echo "python"
        return 0
    fi

    # node
    if [[ -f "${project_path}/package.json" ]]; then
        echo "node"
        return 0
    fi

    echo "generic"
}
fi

#######################################
# Get source directory for API reference generation (bash projects only)
# Arguments:
#   $1 - project path (default: pwd)
# Returns:
#   0 - prints lib/ path for bash projects, empty string otherwise
# Example: get_docs_src_for_api_ref /path/to/project
#######################################
if ! declare -F get_docs_src_for_api_ref &>/dev/null; then
get_docs_src_for_api_ref() {
    local project_path
    project_path=$(get_docs_project_dir "${1:-$(pwd)}")
    local project_type
    project_type=$(detect_project_type "$project_path")

    if [[ "$project_type" == "bash" ]] && [[ -d "${project_path}/lib" ]]; then
        echo "${project_path}/lib"
    else
        echo ""
    fi
}
fi
