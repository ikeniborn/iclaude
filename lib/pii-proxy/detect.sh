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

    # PII proxy only supported in isolated environment
    if [[ "$skip_isolated" != "false" ]] || [[ ! -d "${ISOLATED_NVM_DIR:-}" ]]; then
        return 1
    fi

    # Check server script installed
    [[ -f "${PII_PROXY_SERVER_SCRIPT:-}" ]] || return 1

    # Check venv installed (required for Presidio or regex fallback)
    [[ -d "${PII_PROXY_VENV:-}" ]] || return 1

    # Check Python 3.8+ in venv (integer comparison: 308=3.8, 310=3.10)
    local venv_python="${PII_PROXY_VENV}/bin/python3"
    if [[ ! -x "$venv_python" ]]; then
        return 1
    fi
    local py_ver_int
    py_ver_int=$("$venv_python" -c \
        'import sys; print("%d%02d" % sys.version_info[:2])' 2>/dev/null)
    if [[ -z "$py_ver_int" ]] || (( py_ver_int < 308 )); then
        return 1
    fi

    return 0
}

#######################################
# Get PII-proxy Python interpreter path
# Returns venv python path (only venv is supported; system python has no Presidio)
# Arguments:
#   $1 - skip_isolated (unused, reserved for future use)
# Returns:
#   stdout: path to python3 interpreter, empty on failure
#   exit 0 on success, 1 on failure
#######################################
get_pii_proxy_python() {
    local venv_python="${PII_PROXY_VENV:-}/bin/python3"
    if [[ -x "$venv_python" ]]; then
        echo "$venv_python"
        return 0
    fi
    echo ""
    return 1
}
