#!/bin/bash
# PII-Proxy status module
# Provides function for checking PII-proxy status

#######################################
# Check PII-proxy status
# Shows installation, venv, model, server state
# Returns:
#   0 - success
#######################################
check_pii_proxy_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  PII-Proxy Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Python version
    if python3 --version &>/dev/null; then
        print_success "Python: $(python3 --version 2>&1)"
    else
        print_error "Python 3 not found"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 0
    fi

    # Server script
    if [[ -f "$PII_PROXY_SERVER_SCRIPT" ]]; then
        print_success "Server script: $PII_PROXY_SERVER_SCRIPT"
    else
        print_warning "Server script not installed"
        echo "  Run: ./iclaude.sh --install-pii-proxy"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 0
    fi

    # Virtual environment
    if [[ -d "$PII_PROXY_VENV" ]]; then
        print_success "Virtual environment: $PII_PROXY_VENV"
        local venv_size
        venv_size=$(du -sh "$PII_PROXY_VENV" 2>/dev/null | cut -f1 || echo "unknown")
        echo "  Size: $venv_size"
    else
        print_warning "Virtual environment not found: $PII_PROXY_VENV"
        echo "  Run: ./iclaude.sh --install-pii-proxy"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 0
    fi

    # Presidio installation
    if "$PII_PROXY_VENV/bin/python3" -c "import presidio_analyzer" 2>/dev/null; then
        print_success "Presidio: installed"
    else
        print_warning "Presidio not installed in venv"
        echo "  Run: ./iclaude.sh --install-pii-proxy"
    fi

    # spaCy model
    if "$PII_PROXY_VENV/bin/python3" -c "import spacy; spacy.load('en_core_web_lg')" 2>/dev/null; then
        print_success "spaCy model: en_core_web_lg"
    elif "$PII_PROXY_VENV/bin/python3" -c "import spacy; spacy.load('en_core_web_sm')" 2>/dev/null; then
        print_warning "spaCy model: en_core_web_sm (reduced accuracy)"
    else
        print_warning "spaCy model: not found"
    fi

    # Log directory
    echo ""
    print_info "Log directory: $PII_PROXY_LOG_DIR"
    if [[ -d "$PII_PROXY_LOG_DIR" ]]; then
        local log_size
        log_size=$(du -sh "$PII_PROXY_LOG_DIR" 2>/dev/null | cut -f1 || echo "0")
        echo "  Size: $log_size"
        # Show last error if any
        local access_log="$PII_PROXY_LOG_DIR/access.log"
        if [[ -f "$access_log" ]]; then
            local last_error
            last_error=$(grep -i 'error\|ERROR' "$access_log" 2>/dev/null | tail -1)
            [[ -n "$last_error" ]] && echo "  Last error: $last_error"
        fi
    else
        echo "  (not created yet)"
    fi

    # Running process
    echo ""
    if [[ -f "$PII_PROXY_PID_FILE" ]]; then
        local pid
        pid=$(cat "$PII_PROXY_PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            print_success "Server running: PID $pid"
            # Try to get port
            local port
            port=$(ss -tlnp 2>/dev/null | grep "pid=$pid" | grep -oP ':\K\d+' | head -1 || echo "")
            [[ -n "$port" ]] && echo "  Port: $port" || echo "  Port: $PII_PROXY_PORT (default)"
        else
            print_info "Server not running"
            echo "  (starts automatically when USE_PII_PROXY=true or --pii-proxy)"
        fi
    else
        print_info "Server not running"
        echo "  (starts automatically when USE_PII_PROXY=true or --pii-proxy)"
    fi

    # Config
    echo ""
    print_info "Configuration (.claude_config):"
    echo "  USE_PII_PROXY=${USE_PII_PROXY:-false}"
    echo "  PII_PROXY_PORT=${PII_PROXY_PORT:-9000}"
    echo "  PII_PROXY_ENABLE_FALLBACK=${PII_PROXY_ENABLE_FALLBACK:-true}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    return 0
}
