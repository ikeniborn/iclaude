#!/bin/bash
# PII-Proxy installation module
# Provides function for installing Presidio NLP dependencies

#######################################
# Install PII-proxy to isolated environment
# Creates venv, installs Presidio + spaCy, copies server script
# Returns:
#   0 - success
#   1 - error
#######################################
install_isolated_pii_proxy() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  PII-Proxy: Install Presidio NLP"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check Python 3.8+
    if ! python3 --version &>/dev/null; then
        print_error "Python 3 not found. Install Python 3.8+ first."
        return 1
    fi
    local py_ver
    py_ver=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null)
    if ! awk "BEGIN{exit ($py_ver >= 3.8) ? 0 : 1}" 2>/dev/null; then
        print_error "Python 3.8+ required for Presidio (found: $(python3 --version 2>&1))"
        return 1
    fi
    print_success "Python $(python3 --version 2>&1 | grep -oP '[\d.]+'): OK"

    # Check isolated environment
    if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
        print_error "Isolated environment not found. Run --isolated-install first."
        return 1
    fi

    # Create venv
    print_info "Creating Python virtual environment..."
    if ! python3 -m venv "$PII_PROXY_VENV"; then
        print_error "Failed to create virtual environment at: $PII_PROXY_VENV"
        return 1
    fi
    print_success "Virtual environment: $PII_PROXY_VENV"

    # Upgrade pip
    print_info "Upgrading pip..."
    "$PII_PROXY_VENV/bin/python3" -m pip install --quiet --upgrade pip

    # Install Presidio
    print_info "Installing presidio-analyzer + presidio-anonymizer (~100MB)..."
    if ! "$PII_PROXY_VENV/bin/python3" -m pip install \
        presidio-analyzer \
        presidio-anonymizer \
        spacy; then
        print_error "Failed to install Presidio packages"
        return 1
    fi
    print_success "Presidio installed"

    # Download spaCy model
    print_info "Downloading spaCy en_core_web_lg model (~500MB, may take a few minutes)..."
    if ! "$PII_PROXY_VENV/bin/python3" -m spacy download en_core_web_lg; then
        print_warning "Failed to download en_core_web_lg, trying en_core_web_sm (~12MB)..."
        if ! "$PII_PROXY_VENV/bin/python3" -m spacy download en_core_web_sm; then
            print_error "Failed to download spaCy model"
            return 1
        fi
        print_warning "Using en_core_web_sm (lower accuracy). Consider: python3 -m spacy download en_core_web_lg"
    fi

    # Copy server script to isolated config dir
    local src_script
    src_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/server.py"
    if [[ ! -f "$src_script" ]]; then
        print_error "server.py not found at: $src_script"
        return 1
    fi
    print_info "Installing server script..."
    cp "$src_script" "$PII_PROXY_SERVER_SCRIPT"
    chmod 700 "$PII_PROXY_SERVER_SCRIPT"
    print_success "Server script: $PII_PROXY_SERVER_SCRIPT"

    # Create log directory
    mkdir -p "$PII_PROXY_LOG_DIR"

    echo ""
    print_success "PII-Proxy installed successfully!"
    echo ""
    print_info "Next steps:"
    print_info "  1. Enable: add USE_PII_PROXY=true to .claude_config"
    print_info "  2. Launch: ./iclaude.sh --pii-proxy"
    print_info "  3. Status: ./iclaude.sh --check-pii-proxy"
    echo ""

    return 0
}
