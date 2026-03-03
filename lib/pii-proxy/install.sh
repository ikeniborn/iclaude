#!/bin/bash
# PII-Proxy installation module
# Provides function for installing Presidio NLP dependencies

#######################################
# Detect ALT Linux distribution
# Returns: 0 if ALT Linux, 1 otherwise
#######################################
_detect_alt_linux() {
    [[ -f /etc/altlinux-release ]] && return 0
    local id
    id=$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'")
    [[ "$id" == "altlinux" || "$id" == "alt" ]] && return 0
    return 1
}

#######################################
# Level 1: Full Presidio install with current spacy
# Args: $1 - venv path
# Returns: 0 on success, 1 on failure
#######################################
_try_install_presidio_full() {
    local venv="$1"
    CC=gcc "$venv/bin/python3" -m pip install \
        presidio-analyzer presidio-anonymizer spacy \
        --prefer-binary --quiet 2>&1
}

#######################################
# Level 2: Legacy Presidio install with spacy<3.8 (pre-built blis wheels)
# Args: $1 - venv path
# Returns: 0 on success, 1 on failure
#######################################
_try_install_presidio_legacy() {
    local venv="$1"
    CC=gcc "$venv/bin/python3" -m pip install \
        presidio-analyzer presidio-anonymizer "spacy>=3.6,<3.8" \
        --prefer-binary --quiet 2>&1
}

#######################################
# Level 3: Regex-only mode (requests only, no NLP)
# Args: $1 - venv path
# Returns: 0 on success, 1 on failure
#######################################
_install_regex_only_mode() {
    local venv="$1"
    "$venv/bin/python3" -m pip install requests --quiet 2>&1
}

#######################################
# Check Python version, ALT Linux hint, isolated env
# Returns: 0 on success, 1 on failure
#######################################
_pii_proxy_check_prerequisites() {
    if ! python3 --version &>/dev/null; then
        print_error "Python 3 not found. Install Python 3.8+ first."
        return 1
    fi
    if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' 2>/dev/null; then
        print_error "Python 3.8+ required for Presidio (found: $(python3 --version 2>&1))"
        return 1
    fi
    print_success "Python $(python3 --version 2>&1 | grep -oE '[0-9][0-9.]*'): OK"

    if _detect_alt_linux; then
        print_warning "ALT Linux detected: blis C extension may fail to compile."
        echo "  If installation fails, install gcc first:"
        echo "    sudo apt-get install gcc-c++ python3-dev"
        echo "  Then retry: ./iclaude.sh --install-pii-proxy"
        echo ""
    fi

    if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
        print_error "Isolated environment not found. Run --isolated-install first."
        return 1
    fi
}

#######################################
# Create venv and upgrade pip
# Returns: 0 on success, 1 on failure
#######################################
_pii_proxy_setup_venv() {
    print_info "Creating Python virtual environment..."
    if ! python3 -m venv "$PII_PROXY_VENV"; then
        print_error "Failed to create virtual environment at: $PII_PROXY_VENV"
        return 1
    fi
    print_success "Virtual environment: $PII_PROXY_VENV"

    print_info "Upgrading pip..."
    if ! "$PII_PROXY_VENV/bin/python3" -m pip install --quiet --upgrade pip; then
        print_warning "pip upgrade failed — continuing with existing version"
    fi
}

#######################################
# Run cascading install: full → legacy → regex-only.
# Sets $pii_mode in caller's scope via bash dynamic scoping.
# Returns: 0 on success, 1 if even requests fails
#######################################
_pii_proxy_cascade_install() {
    local _output

    # Level 1: Full Presidio with current spacy
    print_info "Installing presidio-analyzer + presidio-anonymizer + spacy (~100MB)..."
    if _output=$(_try_install_presidio_full "$PII_PROXY_VENV"); then
        pii_mode="presidio-full"
        print_success "Presidio installed (full NLP mode)"
    fi

    # Level 2: Legacy Presidio with spacy<3.8 (if level 1 failed)
    if [[ -z "$pii_mode" ]]; then
        print_warning "Full Presidio install failed (blis compilation error)."
        echo "  Trying legacy spacy<3.8 (uses pre-built blis wheels)..."
        echo ""
        print_info "Installing presidio + spacy>=3.6,<3.8 (legacy mode)..."
        if _output=$(_try_install_presidio_legacy "$PII_PROXY_VENV"); then
            pii_mode="presidio-legacy"
            print_success "Presidio installed (legacy spacy<3.8 mode)"
        fi
    fi

    # Level 3: Regex-only mode (if both NLP modes failed)
    if [[ -z "$pii_mode" ]]; then
        print_warning "Legacy Presidio install also failed."
        echo ""
        print_info "Installing requests (regex-only mode)..."
        if _output=$(_install_regex_only_mode "$PII_PROXY_VENV"); then
            pii_mode="regex-only"
            echo ""
            print_warning "Presidio (NLP) could not be installed. PII-Proxy will use regex-only mode."
            echo "  Regex mode covers: API keys, JWT, AWS credentials, GitHub tokens,"
            echo "  passwords, credit cards, PEM keys, URL credentials."
            echo "  For full NLP entity detection (persons, emails, phone numbers),"
            echo "  install gcc and retry: sudo apt-get install gcc-c++ && ./iclaude.sh --install-pii-proxy"
        else
            print_error "Failed to install even requests package: $_output"
            return 1
        fi
    fi
}

#######################################
# Download spaCy model (lg preferred, sm fallback)
# Returns: 0 on success, 1 on failure
#######################################
_pii_proxy_download_model() {
    print_info "Downloading spaCy en_core_web_lg model (~500MB, may take a few minutes)..."
    if ! "$PII_PROXY_VENV/bin/python3" -m spacy download en_core_web_lg; then
        print_warning "Failed to download en_core_web_lg, trying en_core_web_sm (~12MB)..."
        if ! "$PII_PROXY_VENV/bin/python3" -m spacy download en_core_web_sm; then
            print_error "Failed to download spaCy model"
            return 1
        fi
        print_warning "Using en_core_web_sm (lower accuracy). Consider: python3 -m spacy download en_core_web_lg"
    fi
}

#######################################
# Symlink server.py and create log directory
# Returns: 0 on success, 1 on failure
#######################################
_pii_proxy_install_server() {
    local src_script
    src_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/server.py"
    if [[ ! -f "$src_script" ]]; then
        print_error "server.py not found at: $src_script"
        return 1
    fi
    print_info "Installing server script..."
    mkdir -p "$(dirname "$PII_PROXY_SERVER_SCRIPT")"
    ln -sf "$src_script" "$PII_PROXY_SERVER_SCRIPT"
    chmod 700 "$src_script"
    print_success "Server script: $PII_PROXY_SERVER_SCRIPT → $src_script"
}

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

    _pii_proxy_check_prerequisites || return 1
    _pii_proxy_setup_venv || return 1

    local pii_mode=""
    _pii_proxy_cascade_install || return 1
    echo "$pii_mode" > "$PII_PROXY_VENV/pii_proxy_mode"

    [[ "$pii_mode" != "regex-only" ]] && { _pii_proxy_download_model || return 1; }

    _pii_proxy_install_server || return 1
    mkdir -p "$PII_PROXY_LOG_DIR"

    echo ""
    print_success "PII-Proxy installed successfully! Mode: $pii_mode"
    echo ""
    print_info "Next steps:"
    print_info "  1. Enable: add USE_PII_PROXY=true to .claude_config"
    print_info "  2. Launch: ./iclaude.sh --pii-proxy"
    print_info "  3. Status: ./iclaude.sh --check-pii-proxy"
    echo ""

    return 0
}
