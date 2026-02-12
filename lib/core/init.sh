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
    ISOLATED_LOCKFILE="${SCRIPT_DIR}/.nvm-isolated-lockfile.json"
    USE_ISOLATED_BY_DEFAULT=true  # Use isolated environment by default

    # Token refresh threshold in seconds (7 days = 604800)
    # Token will be refreshed if it expires within this time
    TOKEN_REFRESH_THRESHOLD=604800

    # Export for use in subshells
    export SCRIPT_DIR
    export CREDENTIALS_FILE
    export GIT_BACKUP_FILE
    export ISOLATED_NVM_DIR
    export ISOLATED_LOCKFILE
    export USE_ISOLATED_BY_DEFAULT
    export TOKEN_REFRESH_THRESHOLD

    # Color codes
    export RED GREEN YELLOW BLUE NC
}
