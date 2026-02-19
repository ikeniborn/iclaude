#!/usr/bin/env bash
# lib/docs/install.sh
# Sphinx Documentation - Python venv Installation
#
# Installs Python virtual environment with Sphinx and related packages
# in .nvm-isolated/.python-docs/ directory

#######################################
# Install Sphinx documentation environment
# Creates Python venv and installs sphinx, myst-parser, furo, and plugins
# Arguments:
#   None
# Returns:
#   0 - Success
#   1 - python3 not found or pip install failed
# Example: install_sphinx_docs
#######################################
if ! declare -F install_sphinx_docs &>/dev/null; then
install_sphinx_docs() {
    local venv_dir="${ISOLATED_NVM_DIR:-.nvm-isolated}/.python-docs"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Installing Sphinx Documentation Environment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check python3 available
    if ! command -v python3 &>/dev/null; then
        print_error "python3 not found. Install Python 3.8+ to use Sphinx docs."
        echo ""
        echo "  Ubuntu/Debian: sudo apt install python3 python3-venv python3-pip"
        echo "  Fedora/RHEL:   sudo dnf install python3 python3-pip"
        echo "  Arch:          sudo pacman -S python python-pip"
        return 1
    fi

    local python_version
    python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
    print_info "Python version: $python_version"

    # Check venv module available
    if ! python3 -m venv --help &>/dev/null; then
        print_error "python3-venv module not found."
        echo ""
        echo "  Ubuntu/Debian: sudo apt install python3-venv"
        return 1
    fi

    # Create venv
    print_info "Creating Python venv: $venv_dir"
    if ! python3 -m venv "$venv_dir"; then
        print_error "Failed to create Python venv at: $venv_dir"
        return 1
    fi

    # Activate venv
    # shellcheck source=/dev/null
    source "$venv_dir/bin/activate"

    # Upgrade pip silently
    print_info "Upgrading pip..."
    python -m pip install --upgrade pip --quiet

    # Install Sphinx packages
    echo ""
    print_info "Installing Sphinx packages..."
    echo ""

    local packages=(
        "sphinx>=8.0"
        "myst-parser"
        "furo"
        "sphinx-copybutton"
        "sphinx-design"
        "sphinxcontrib-mermaid"
    )

    # sphinx-llms-txt is optional (may not be available in all environments)
    if pip install sphinx-llms-txt --quiet 2>/dev/null; then
        print_success "sphinx-llms-txt installed (llms.txt generation enabled)"
    else
        print_warning "sphinx-llms-txt not available - llms.txt generation disabled"
        print_info "  Install manually: pip install sphinx-llms-txt"
    fi

    for pkg in "${packages[@]}"; do
        print_info "Installing $pkg..."
        if ! pip install "$pkg" --quiet; then
            print_warning "Failed to install $pkg (continuing...)"
        fi
    done

    deactivate

    echo ""
    print_success "Sphinx environment installed: $venv_dir"
    echo ""
    echo "  Build docs:  ./iclaude.sh --build-docs"
    echo "  Serve docs:  ./iclaude.sh --serve-docs"
    echo "  Check:       ./iclaude.sh --check-docs"
    echo ""

    return 0
}
fi
