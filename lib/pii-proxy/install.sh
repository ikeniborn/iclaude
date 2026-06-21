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
# Resolve proxy URL from environment
# Outputs: proxy URL string (or empty)
#######################################
_resolve_proxy() {
    echo "${HTTPS_PROXY:-${HTTP_PROXY:-${PROXY_URL:-}}}"
}

#######################################
# Build pip --proxy arguments
# Outputs: --proxy <url> (or empty string)
#######################################
_pip_proxy_args() {
    local proxy
    proxy=$(_resolve_proxy)
    if [[ -n "$proxy" ]]; then
        echo "--proxy" "$proxy"
    fi
}

#######################################
# Run a command in background with a progress bar
# based on monitoring venv site-packages size growth.
# Args:
#   $1 - venv path
#   $2 - expected size delta in MB
#   $3 - label text for progress bar
#   $4.. - command and arguments to run
# Returns: exit code of the background command
#######################################
_run_with_progress() {
    local venv="$1" expected_mb="$2" label="$3"
    shift 3

    # Resolve site-packages dir (guard against unmatched glob)
    local site_dir
    for site_dir in "$venv"/lib/python3.*/site-packages; do break; done
    if [[ ! -d "$site_dir" ]]; then
        # Fallback: run command without progress bar
        "$@" 2>&1
        return $?
    fi

    local base_mb
    read -r base_mb _ < <(du -sm "$site_dir" 2>/dev/null)
    base_mb=${base_mb:-0}

    local log_file
    log_file=$(mktemp /tmp/iclaude-pii-install-XXXXXX.log)

    "$@" > "$log_file" 2>&1 &
    local pid=$!

    # Cleanup on interrupt: kill bg process, remove log
    trap 'kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; rm -f "$log_file"; trap - INT TERM; return 130' INT TERM

    local bar_w=40 tick=0 prev_delta=-1
    local cur_mb delta pct filled bar pulse i
    while kill -0 "$pid" 2>/dev/null; do
        read -r cur_mb _ < <(du -sm "$site_dir" 2>/dev/null)
        cur_mb=${cur_mb:-0}
        delta=$((cur_mb - base_mb))
        pct=$((delta * 100 / expected_mb))
        (( pct > 99 )) && pct=99
        (( pct < 0 )) && pct=0

        if (( delta == prev_delta )); then
            # Download/waiting phase: show animated pulse
            pulse=""
            for (( i = 0; i < bar_w; i++ )); do
                case $(( (i + tick) % 4 )) in
                    0) pulse+="\u2591" ;; 1) pulse+="\u2592" ;;
                    2) pulse+="\u2593" ;; 3) pulse+="\u2588" ;;
                esac
            done
            printf "\r  %s [${BLUE}%b${NC}] downloading...  " "$label" "$pulse"
        else
            # Install phase: show progress bar
            filled=$((pct * bar_w / 100))
            bar=""
            for (( i = 0; i < filled; i++ )); do bar+="\u2588"; done
            for (( i = filled; i < bar_w; i++ )); do bar+="\u2591"; done
            printf "\r  %s [${BLUE}%b${NC}] %3d%% (%dMB)   " "$label" "$bar" "$pct" "$delta"
        fi
        prev_delta=$delta
        tick=$((tick + 1))
        sleep 2
    done

    wait "$pid"
    local rc=$?
    trap - INT TERM

    local final_mb
    read -r final_mb _ < <(du -sm "$site_dir" 2>/dev/null)
    final_mb=${final_mb:-0}
    local final_delta=$((final_mb - base_mb))

    if [[ $rc -eq 0 ]]; then
        bar=""
        for (( i = 0; i < bar_w; i++ )); do bar+="\u2588"; done
        printf "\r  %s [${GREEN}%b${NC}] 100%% (%dMB)\n" "$label" "$bar" "$final_delta"
    else
        printf "\n"
        print_warning "Install log (last 5 lines):"
        tail -5 "$log_file" | sed 's/^/  /'
    fi

    rm -f "$log_file"
    return $rc
}

#######################################
# Level 1: Full Presidio install with current spacy
# Args: $1 - venv path
# Returns: 0 on success, 1 on failure
#######################################
_try_install_presidio_full() {
    local venv="$1"
    # shellcheck disable=SC2046
    _run_with_progress "$venv" 450 "Presidio + spacy" \
        env CC=gcc "$venv/bin/python3" -m pip install \
        presidio-analyzer presidio-anonymizer spacy \
        --prefer-binary $(_pip_proxy_args)
}

#######################################
# Level 2: Legacy Presidio install with spacy<3.8 (pre-built blis wheels)
# Args: $1 - venv path
# Returns: 0 on success, 1 on failure
#######################################
_try_install_presidio_legacy() {
    local venv="$1"
    # shellcheck disable=SC2046
    _run_with_progress "$venv" 400 "Presidio + spacy (legacy)" \
        env CC=gcc "$venv/bin/python3" -m pip install \
        presidio-analyzer presidio-anonymizer "spacy>=3.6,<3.8" \
        --prefer-binary $(_pip_proxy_args)
}

#######################################
# Level 3: Regex-only mode (requests only, no NLP)
# Args: $1 - venv path
# Returns: 0 on success, 1 on failure
#######################################
_install_regex_only_mode() {
    local venv="$1"
    # shellcheck disable=SC2046
    _run_with_progress "$venv" 5 "requests" \
        "$venv/bin/python3" -m pip install requests $(_pip_proxy_args)
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
    # shellcheck disable=SC2046
    if ! "$PII_PROXY_VENV/bin/python3" -m pip install --upgrade pip -q $(_pip_proxy_args) 2>/dev/null; then
        print_warning "pip upgrade failed — continuing with existing version"
    fi
}

#######################################
# Run cascading install: full → legacy → regex-only.
# Sets $pii_mode in caller's scope via bash dynamic scoping.
# Returns: 0 on success, 1 if even requests fails
#######################################
_pii_proxy_cascade_install() {
    # Level 1: Full Presidio with current spacy
    print_info "Installing presidio-analyzer + presidio-anonymizer + spacy (~450MB)..."
    if _try_install_presidio_full "$PII_PROXY_VENV"; then
        pii_mode="presidio-full"
        print_success "Presidio installed (full NLP mode)"
    fi

    # Level 2: Legacy Presidio with spacy<3.8 (if level 1 failed)
    if [[ -z "$pii_mode" ]]; then
        print_warning "Full Presidio install failed."
        echo "  Trying legacy spacy<3.8 (uses pre-built blis wheels)..."
        echo ""
        if _try_install_presidio_legacy "$PII_PROXY_VENV"; then
            pii_mode="presidio-legacy"
            print_success "Presidio installed (legacy spacy<3.8 mode)"
        fi
    fi

    # Level 3: Regex-only mode (if both NLP modes failed)
    if [[ -z "$pii_mode" ]]; then
        print_warning "Legacy Presidio install also failed."
        echo ""
        if _install_regex_only_mode "$PII_PROXY_VENV"; then
            pii_mode="regex-only"
            echo ""
            print_warning "Presidio (NLP) could not be installed. PII-Proxy will use regex-only mode."
            echo "  Regex mode covers: API keys, JWT, AWS credentials, GitHub tokens,"
            echo "  passwords, credit cards, PEM keys, URL credentials."
            echo "  For full NLP entity detection (persons, emails, phone numbers),"
            echo "  install gcc and retry: sudo apt-get install gcc-c++ && ./iclaude.sh --install-pii-proxy"
        else
            print_error "Failed to install even requests package."
            return 1
        fi
    fi
}

#######################################
# Download one spaCy model: lg preferred, sm fallback.
# Skips download if lg is already at the latest version.
# Args:
#   $1 - language tag (en | ru)
#   $2 - primary (lg) model name
#   $3 - fallback (sm) model name
#   $4 - primary model size in MB
#   $5 - fallback model size in MB
#   $6 - action verb ("Downloading" | "Updating")
# Reads from caller scope: $PII_PROXY_VENV, $proxy_env[]
# Writes: $PII_PROXY_VENV/spacy_model_$lang
# Returns: 0 on success, 1 on failure
#######################################
_pii_download_spacy_model() {
    local lang="$1" lg_model="$2" sm_model="$3" lg_size="$4" sm_size="$5" action="$6"
    local pkg_lg="${lg_model//_/-}"
    local chosen=""

    # Version check: skip if lg model is already at latest version
    local installed_ver
    installed_ver=$("$PII_PROXY_VENV/bin/python3" -c "
import importlib.metadata
try:
    print(importlib.metadata.version('$pkg_lg'))
except Exception:
    pass" 2>/dev/null)

    if [[ -n "$installed_ver" ]]; then
        # pip --dry-run: "Requirement already satisfied" → no update available
        if "$PII_PROXY_VENV/bin/pip3" install \
            --dry-run --upgrade "$pkg_lg" $(_pip_proxy_args) 2>&1 \
            | grep -q "Requirement already satisfied"; then
            print_success "$lg_model already up to date (v${installed_ver})"
            echo "$lg_model" > "$PII_PROXY_VENV/spacy_model_$lang"
            return 0
        fi
    fi

    # Download / upgrade primary model
    print_info "$action spaCy $lg_model (~${lg_size}MB)..."
    if _run_with_progress "$PII_PROXY_VENV" "$lg_size" "$lg_model" \
        "${proxy_env[@]}" "$PII_PROXY_VENV/bin/python3" -m spacy download "$lg_model" --upgrade; then
        chosen="$lg_model"
    else
        # Fallback to sm — fresh install only, no --upgrade
        print_warning "Failed to download $lg_model, trying $sm_model (~${sm_size}MB)..."
        if _run_with_progress "$PII_PROXY_VENV" "$sm_size" "$sm_model" \
            "${proxy_env[@]}" "$PII_PROXY_VENV/bin/python3" -m spacy download "$sm_model"; then
            chosen="$sm_model"
            print_warning "Using $sm_model (lower accuracy)"
        else
            print_error "Failed to download ${lang^^} spaCy model"
            return 1
        fi
    fi

    echo "$chosen" > "$PII_PROXY_VENV/spacy_model_$lang"
}

#######################################
# Download spaCy models: English + Russian (lg preferred, sm fallback)
# On reinstall: upgrades only if newer version is available on PyPI
# Returns: 0 on success, 1 on failure
#######################################
_pii_proxy_download_model() {
    # spacy download uses pip internally; proxy must be in env vars
    local proxy
    proxy=$(_resolve_proxy)
    local proxy_env=()
    if [[ -n "$proxy" ]]; then
        proxy_env=(env HTTPS_PROXY="$proxy" HTTP_PROXY="$proxy")
    fi

    # Detect reinstall (models already present) for UI messaging
    local action="Downloading"
    [[ -f "$PII_PROXY_VENV/spacy_model_en" ]] && action="Updating"

    _pii_download_spacy_model en en_core_web_lg en_core_web_sm 560 15 "$action" || return 1
    _pii_download_spacy_model ru ru_core_news_lg ru_core_news_sm 500 15 "$action" || return 1
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

    # Symlink the Langfuse emitter alongside the server. server.py imports it as a
    # sibling module at runtime (sys.path[0] resolves to the real lib/pii-proxy dir,
    # since Python resolves the executed script's symlink before setting sys.path).
    local src_emitter dst_emitter
    src_emitter="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/langfuse_emitter.py"
    dst_emitter="$(dirname "$PII_PROXY_SERVER_SCRIPT")/langfuse_emitter.py"
    if [[ -f "$src_emitter" ]]; then
        ln -sf "$src_emitter" "$dst_emitter"
        print_success "Langfuse emitter: $dst_emitter → $src_emitter"
    fi
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
