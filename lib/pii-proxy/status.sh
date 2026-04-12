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

    # Presidio installation — check mode marker file first
    local pii_mode=""
    local mode_file="$PII_PROXY_VENV/pii_proxy_mode"
    if [[ -f "$mode_file" ]]; then
        pii_mode=$(cat "$mode_file" 2>/dev/null | tr -d '[:space:]')
    fi

    if [[ "$pii_mode" == "presidio-full" ]]; then
        print_success "Presidio: installed (full NLP mode)"
    elif [[ "$pii_mode" == "presidio-legacy" ]]; then
        print_success "Presidio: installed (legacy spacy<3.8 mode)"
    elif [[ "$pii_mode" == "regex-only" ]]; then
        print_warning "Presidio: regex-only mode (NLP unavailable)"
        echo "  For full NLP: sudo apt-get install gcc-c++ && ./iclaude.sh --install-pii-proxy"
    else
        # No marker file — fall back to import test
        if "$PII_PROXY_VENV/bin/python3" -c "import presidio_analyzer" 2>/dev/null; then
            print_success "Presidio: installed"
        else
            print_warning "Presidio not installed in venv"
            echo "  Run: ./iclaude.sh --install-pii-proxy"
        fi
    fi

    # spaCy models — skip check in regex-only mode
    if [[ "$pii_mode" != "regex-only" ]]; then
        local en_model_file ru_model_file
        en_model_file=$(cat "$PII_PROXY_VENV/spacy_model_en" 2>/dev/null | tr -d '[:space:]')
        ru_model_file=$(cat "$PII_PROXY_VENV/spacy_model_ru" 2>/dev/null | tr -d '[:space:]')

        # English model
        if [[ -n "$en_model_file" ]] && "$PII_PROXY_VENV/bin/python3" -c "import spacy; spacy.load('$en_model_file')" 2>/dev/null; then
            [[ "$en_model_file" == *"_sm" ]] \
                && print_warning "spaCy model (EN): $en_model_file (reduced accuracy)" \
                || print_success "spaCy model (EN): $en_model_file"
        elif "$PII_PROXY_VENV/bin/python3" -c "import spacy; spacy.load('en_core_web_lg')" 2>/dev/null; then
            print_success "spaCy model (EN): en_core_web_lg"
        elif "$PII_PROXY_VENV/bin/python3" -c "import spacy; spacy.load('en_core_web_sm')" 2>/dev/null; then
            print_warning "spaCy model (EN): en_core_web_sm (reduced accuracy)"
        else
            print_warning "spaCy model (EN): not found"
        fi

        # Russian model
        if [[ -n "$ru_model_file" ]] && "$PII_PROXY_VENV/bin/python3" -c "import spacy; spacy.load('$ru_model_file')" 2>/dev/null; then
            [[ "$ru_model_file" == *"_sm" ]] \
                && print_warning "spaCy model (RU): $ru_model_file (reduced accuracy)" \
                || print_success "spaCy model (RU): $ru_model_file"
        elif "$PII_PROXY_VENV/bin/python3" -c "import spacy; spacy.load('ru_core_news_lg')" 2>/dev/null; then
            print_success "spaCy model (RU): ru_core_news_lg"
        elif "$PII_PROXY_VENV/bin/python3" -c "import spacy; spacy.load('ru_core_news_sm')" 2>/dev/null; then
            print_warning "spaCy model (RU): ru_core_news_sm (reduced accuracy)"
        else
            print_warning "spaCy model (RU): not found"
        fi
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

    # Running processes (per-session: scan PID files in PII_PROXY_PID_DIR).
    # Also sweeps legacy pii-proxy-*.pid files from the root of ISOLATED_CONFIG_DIR
    # so status output reflects both layouts while migration is in flight.
    # SIDs are deduplicated so a session holding both layouts isn't printed twice.
    echo ""
    local found_running=0
    local found_orphaned=0
    local pid_dir="${PII_PROXY_PID_DIR:-${ISOLATED_CONFIG_DIR}/pii-proxy-pid}"
    local pid_file pid bn sid port current_marker alive
    # Per-SID dedup set (space-delimited; used only under bash 3 for portability).
    local seen_sids=" "

    _pii_proxy_status_entry() {
        local pid_file="$1"
        [[ -f "$pid_file" ]] || return 0
        local pid bn sid alive=false port current_marker
        pid=$(cat "$pid_file" 2>/dev/null)
        bn="${pid_file##*/}"
        # Both "<SID>.pid" (new layout) and "pii-proxy-<SID>.pid" (legacy) handled.
        sid="${bn#pii-proxy-}"; sid="${sid%.pid}"
        # Skip if already reported for this SID
        case "$seen_sids" in *" $sid "*) return 0 ;; esac
        seen_sids="${seen_sids}${sid} "
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            if ps -p "$pid" -o cmd= 2>/dev/null | grep -q 'pii-proxy-server.py'; then
                alive=true
            fi
        fi
        if [[ "$alive" == "true" ]]; then
            port=$(cat "${PII_PROXY_LOG_DIR}/pii-proxy-${sid}.port" 2>/dev/null || echo "")
            current_marker=""
            [[ "${ICLAUDE_SESSION_ID:-}" == "$sid" ]] && current_marker=" ← current session"
            if [[ -n "$port" ]]; then
                print_success "Session ${sid}${current_marker}: PID $pid, port $port"
            else
                print_success "Session ${sid}${current_marker}: PID $pid, port unknown"
            fi
            found_running=$((found_running + 1))
        else
            rm -f "$pid_file"
            rm -f "${PII_PROXY_LOG_DIR}/pii-proxy-${sid}.port"
            found_orphaned=$((found_orphaned + 1))
        fi
    }

    # Scan new layout first so legacy duplicates for the same SID are skipped.
    for pid_file in "$pid_dir"/*.pid; do
        _pii_proxy_status_entry "$pid_file"
    done
    for pid_file in "${ISOLATED_CONFIG_DIR}"/pii-proxy-*.pid; do
        _pii_proxy_status_entry "$pid_file"
    done
    unset -f _pii_proxy_status_entry
    if [[ $found_running -eq 0 ]]; then
        print_info "Server not running"
        echo "  (starts automatically when USE_PII_PROXY=true or --pii-proxy)"
        echo "  Use --pii-proxy --router to enable combined PII masking + CCR routing"
    elif [[ $found_running -gt 1 ]]; then
        print_info "  Total: $found_running active sessions (parallel mode)"
    fi
    [[ $found_orphaned -gt 0 ]] && print_info "  Cleaned $found_orphaned orphaned PID file(s)"

    # Config
    echo ""
    print_info "Configuration (.claude_config):"
    echo "  USE_PII_PROXY=${USE_PII_PROXY:-false}"
    echo "  PII_PROXY_MASKING_LEVEL=${PII_PROXY_MASKING_LEVEL:-standard}"
    echo "  PII_PROXY_LOG_LEVEL=${PII_PROXY_LOG_LEVEL:-info}"
    local _port_label
    [[ "${PII_PROXY_PORT:-0}" == "0" ]] \
        && _port_label="auto (range ${PII_PROXY_PORT_MIN:-20000}-${PII_PROXY_PORT_MAX:-40000})" \
        || _port_label="${PII_PROXY_PORT}"
    echo "  PII_PROXY_PORT=${_port_label}"
    echo "  PII_PROXY_ENABLE_FALLBACK=${PII_PROXY_ENABLE_FALLBACK:-true}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    return 0
}
