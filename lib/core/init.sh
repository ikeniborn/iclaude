#!/bin/bash

#######################################
# Core Initialization Module
# Description: Constants, environment variables, and initialization logic
#######################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Resolve script directory (follows symlinks)
resolve_script_directory() {
    local script_path="${BASH_SOURCE[1]}"  # Get caller's path
    while [ -L "$script_path" ]; do
        local script_dir="$(cd "$(dirname "$script_path")" && pwd)"
        script_path="$(readlink "$script_path")"
        [[ $script_path != /* ]] && script_path="$script_dir/$script_path"
    done
    echo "$(cd "$(dirname "$script_path")" && pwd)"
}

# Initialize environment variables
init_environment() {
    # Determine script directory
    SCRIPT_DIR="${SCRIPT_DIR:-$(resolve_script_directory)}"

    # Constants
    CONFIG_FILE="${SCRIPT_DIR}/.claude_config"
    LEGACY_CREDENTIALS_FILE="${SCRIPT_DIR}/.claude_proxy_credentials"

    # Backward compatibility: auto-migrate old filename to new
    if [[ -f "$LEGACY_CREDENTIALS_FILE" ]] && [[ ! -f "$CONFIG_FILE" ]]; then
        mv "$LEGACY_CREDENTIALS_FILE" "$CONFIG_FILE"
        echo -e "${BLUE}ℹ${NC} Config file migrated: .claude_proxy_credentials → .claude_config" >&2
    fi

    # Use new config file path
    CREDENTIALS_FILE="$CONFIG_FILE"
    GIT_BACKUP_FILE="${SCRIPT_DIR}/.claude_git_proxy_backup"
    ISOLATED_NVM_DIR="${SCRIPT_DIR}/.nvm-isolated"
    ISOLATED_CONFIG_DIR="${ISOLATED_NVM_DIR}/.claude-isolated"
    ISOLATED_LOCKFILE="${SCRIPT_DIR}/.nvm-isolated-lockfile.json"
    LOCKFILE_HASH_FILE="${SCRIPT_DIR}/.nvm-isolated/.claude-isolated/.last-lockfile-hash"
    USE_ISOLATED_BY_DEFAULT=true  # Use isolated environment by default

    # Token refresh threshold in seconds (7 days = 604800)
    # Token will be refreshed if it expires within this time
    TOKEN_REFRESH_THRESHOLD=604800

    # Export for use in subshells
    export SCRIPT_DIR
    export CREDENTIALS_FILE
    export GIT_BACKUP_FILE
    export ISOLATED_NVM_DIR
    export ISOLATED_CONFIG_DIR
    export ISOLATED_LOCKFILE
    export LOCKFILE_HASH_FILE
    export USE_ISOLATED_BY_DEFAULT
    export TOKEN_REFRESH_THRESHOLD

    # Color codes
    export RED GREEN YELLOW BLUE NC

    # PII-Proxy configuration
    PII_PROXY_PORT="${PII_PROXY_PORT:-9000}"
    PII_PROXY_VENV="${ISOLATED_CONFIG_DIR}/pii-proxy-venv"
    PII_PROXY_LOG_DIR="${ISOLATED_CONFIG_DIR}/pii-proxy-logs"
    PII_PROXY_PID_FILE="${ISOLATED_CONFIG_DIR}/pii-proxy.pid"
    PII_PROXY_SERVER_SCRIPT="${ISOLATED_CONFIG_DIR}/pii-proxy-server.py"

    export PII_PROXY_PORT
    export PII_PROXY_VENV
    export PII_PROXY_LOG_DIR
    export PII_PROXY_PID_FILE
    export PII_PROXY_SERVER_SCRIPT

    # CCR (Claude Code Router) daemon configuration — used in combined PII proxy + router mode
    # CCR_PID: PID of background CCR daemon started by start_ccr_server()
    # CCR_SESSION_OWNED: true if this session started CCR (stop_ccr_server should kill it)
    CCR_PID=""
    CCR_SESSION_OWNED=false
    # CCR_HOST/CCR_PORT: parsed from router.json; fallback to defaults
    CCR_HOST="127.0.0.1"
    CCR_PORT=3456

    export CCR_PID
    export CCR_SESSION_OWNED
    export CCR_HOST
    export CCR_PORT
}
