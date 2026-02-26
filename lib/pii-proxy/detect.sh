#!/bin/bash
# PII-Proxy detection module
# Provides functions for detecting PII-proxy installation

#######################################
# Detect if PII-proxy is available
# Checks Python 3.8+ and server script existence
# Arguments:
#   $1 - skip_isolated (optional): "true" to skip isolated environment
# Returns:
#   0 - PII-proxy available
#   1 - not available
#######################################
detect_pii_proxy() {
    local skip_isolated="${1:-false}"

    # Check Python 3.8+ (bash-only)
    if ! python3 --version &>/dev/null; then
        return 1
    fi
    local py_ver
    py_ver=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null)
    if ! awk "BEGIN{exit ($py_ver >= 3.8) ? 0 : 1}" 2>/dev/null; then
        return 1
    fi

    # Check server script existence
    local server_script=""
    if [[ "$skip_isolated" == "false" ]] && [[ -d "${ISOLATED_NVM_DIR:-}" ]]; then
        server_script="${PII_PROXY_SERVER_SCRIPT:-}"
    else
        server_script="$HOME/.claude/pii-proxy-server.py"
    fi

    [[ -f "$server_script" ]] || return 1

    # Check venv existence
    local venv_dir=""
    if [[ "$skip_isolated" == "false" ]] && [[ -d "${ISOLATED_NVM_DIR:-}" ]]; then
        venv_dir="${PII_PROXY_VENV:-}"
    fi

    [[ -n "$venv_dir" ]] && [[ ! -d "$venv_dir" ]] && return 1

    return 0
}

#######################################
# Get PII-proxy Python interpreter path
# Returns:
#   path to python3 in venv, or empty string
#######################################
get_pii_proxy_python() {
    local venv_python="${PII_PROXY_VENV:-}/bin/python3"
    if [[ -x "$venv_python" ]]; then
        echo "$venv_python"
        return 0
    fi
    # Fallback to system python3
    command -v python3 2>/dev/null && return 0
    echo ""
    return 1
}
