#!/bin/bash
# PII-Proxy installation module
# Provides function for installing Presidio NLP dependencies

#######################################
# Install PII-proxy to isolated environment
# Idempotent: skips steps that are already up to date.
# Arguments:
#   $1 - "--force" to skip all checks and reinstall from scratch
# Returns:
#   0 - success
#   1 - error
#######################################
install_isolated_pii_proxy() {
    local force=false
    [[ "${1:-}" == "--force" ]] && force=true

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  PII-Proxy: Install Presidio NLP"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    [[ "$force" == true ]] && echo "  Mode: forced reinstall (--force)"
    echo ""

    local steps_skipped=0
    local steps_done=0

    # ── Python version check ────────────────────────────────────────────────
    if ! python3 --version &>/dev/null; then
        print_error "Python 3 not found. Install Python 3.8+ first."
        return 1
    fi
    if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' 2>/dev/null; then
        print_error "Python 3.8+ required for Presidio (found: $(python3 --version 2>&1))"
        return 1
    fi
    print_success "Python $(python3 --version 2>&1 | grep -oE '[0-9][0-9.]*'): OK"

    # ── Isolated environment check ──────────────────────────────────────────
    if [[ ! -d "$ISOLATED_NVM_DIR" ]]; then
        print_error "Isolated environment not found. Run --isolated-install first."
        return 1
    fi

    # ── Step 1: Virtual environment ─────────────────────────────────────────
    local venv_python="$PII_PROXY_VENV/bin/python3"
    local venv_ok=false

    if [[ "$force" == false ]] && [[ -x "$venv_python" ]]; then
        # Verify version inside venv (must be ≥ 3.8)
        if "$venv_python" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' 2>/dev/null; then
            venv_ok=true
            print_success "venv: already exists, skipping creation"
            (( steps_skipped++ )) || true
        fi
    fi

    if [[ "$venv_ok" == false ]]; then
        # --force: remove stale venv first
        if [[ "$force" == true ]] && [[ -n "$PII_PROXY_VENV" ]] && [[ -d "$PII_PROXY_VENV" ]]; then
            print_info "Removing existing venv..."
            rm -rf "$PII_PROXY_VENV"
        fi
        print_info "Creating Python virtual environment..."
        if ! python3 -m venv "$PII_PROXY_VENV"; then
            print_error "Failed to create virtual environment at: $PII_PROXY_VENV"
            return 1
        fi
        print_success "Virtual environment: $PII_PROXY_VENV"
        (( steps_done++ )) || true

        # Upgrade pip only when venv is freshly created (non-fatal)
        print_info "Upgrading pip..."
        if ! "$venv_python" -m pip install --quiet --upgrade pip; then
            print_warning "pip upgrade failed — continuing with existing version"
        fi
    fi

    # ── Step 2: Presidio + spaCy packages ──────────────────────────────────
    local packages_ok=false

    if [[ "$force" == false ]]; then
        if "$venv_python" -m pip show presidio-analyzer presidio-anonymizer spacy &>/dev/null; then
            packages_ok=true
            print_success "Presidio: already installed, skipping pip install"
            (( steps_skipped++ )) || true
        fi
    fi

    if [[ "$packages_ok" == false ]]; then
        print_info "Installing presidio-analyzer + presidio-anonymizer + spacy (~100MB)..."
        if ! "$venv_python" -m pip install \
            presidio-analyzer \
            presidio-anonymizer \
            spacy; then
            print_error "Failed to install Presidio packages"
            return 1
        fi
        print_success "Presidio installed"
        (( steps_done++ )) || true
    fi

    # ── Step 3: spaCy model (CRITICAL — lg=587MB, sm=12MB) ─────────────────
    local model_lg_ok=false
    local model_sm_ok=false

    if [[ "$force" == false ]]; then
        if "$venv_python" -c "import spacy; spacy.load('en_core_web_lg')" 2>/dev/null; then
            model_lg_ok=true
            print_success "spaCy model: en_core_web_lg already installed, skipping download (587MB saved)"
            (( steps_skipped++ )) || true
        elif "$venv_python" -c "import spacy; spacy.load('en_core_web_sm')" 2>/dev/null; then
            model_sm_ok=true
            print_warning "spaCy model: en_core_web_sm already installed (lower accuracy)"
            print_info "  To upgrade: $venv_python -m spacy download en_core_web_lg"
            (( steps_skipped++ )) || true
        fi
    fi

    if [[ "$model_lg_ok" == false ]] && [[ "$model_sm_ok" == false ]]; then
        print_info "Downloading spaCy en_core_web_lg model (~587MB, may take a few minutes)..."
        if "$venv_python" -m spacy download en_core_web_lg; then
            print_success "spaCy model: en_core_web_lg downloaded"
            (( steps_done++ )) || true
        else
            print_warning "Failed to download en_core_web_lg, trying en_core_web_sm (~12MB)..."
            if "$venv_python" -m spacy download en_core_web_sm; then
                print_warning "Using en_core_web_sm (lower accuracy). Upgrade later: $venv_python -m spacy download en_core_web_lg"
                (( steps_done++ )) || true
            else
                print_error "Failed to download spaCy model"
                return 1
            fi
        fi
    fi

    # ── Step 4: Server script ───────────────────────────────────────────────
    local src_script
    src_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/server.py"
    if [[ ! -f "$src_script" ]]; then
        print_error "server.py not found at: $src_script"
        return 1
    fi

    local script_ok=false
    if [[ "$force" == false ]] && [[ -f "$PII_PROXY_SERVER_SCRIPT" ]]; then
        if diff -q "$src_script" "$PII_PROXY_SERVER_SCRIPT" &>/dev/null; then
            script_ok=true
            print_success "Server script: up to date, skipping copy"
            (( steps_skipped++ )) || true
        fi
    fi

    if [[ "$script_ok" == false ]]; then
        print_info "Installing server script..."
        mkdir -p "$(dirname "$PII_PROXY_SERVER_SCRIPT")"
        cp "$src_script" "$PII_PROXY_SERVER_SCRIPT"
        chmod 700 "$PII_PROXY_SERVER_SCRIPT"
        print_success "Server script: $PII_PROXY_SERVER_SCRIPT"
        (( steps_done++ )) || true
    fi

    # ── Log directory ───────────────────────────────────────────────────────
    mkdir -p "$PII_PROXY_LOG_DIR"

    # ── Summary ─────────────────────────────────────────────────────────────
    echo ""
    if (( steps_done == 0 )); then
        print_success "PII-Proxy: already up to date (${steps_skipped} steps skipped)"
        print_info "Use --force to reinstall: ./iclaude.sh --install-pii-proxy --force"
    else
        print_success "PII-Proxy installed successfully! (${steps_done} steps done, ${steps_skipped} skipped)"
    fi
    echo ""
    print_info "Next steps:"
    print_info "  1. Enable: add USE_PII_PROXY=true to .claude_config"
    print_info "  2. Launch: ./iclaude.sh --pii-proxy"
    print_info "  3. Status: ./iclaude.sh --check-pii-proxy"
    echo ""

    return 0
}
