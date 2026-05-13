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
    CLAUDE_CONFIG_DIR="$ISOLATED_CONFIG_DIR"
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
    export CLAUDE_CONFIG_DIR
    export ISOLATED_LOCKFILE
    export LOCKFILE_HASH_FILE
    export USE_ISOLATED_BY_DEFAULT
    export TOKEN_REFRESH_THRESHOLD

    # Color codes
    export RED GREEN YELLOW BLUE NC

    # Per-session isolation: unique ID prevents race conditions in parallel iclaude sessions.
    # Each session gets its own PID and port files so sessions don't interfere with each other.
    # Inherit if already set (e.g. subshells launched by the same session).
    ICLAUDE_SESSION_ID="${ICLAUDE_SESSION_ID:-$(od -An -N6 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' || printf '%012x' $((RANDOM * RANDOM + RANDOM)))}"
    export ICLAUDE_SESSION_ID

    # PII-Proxy configuration
    # PII_PROXY_PORT=0 means "auto-select from range" (default).
    # Set to a specific value in .claude_config to pin a port.
    PII_PROXY_PORT="${PII_PROXY_PORT:-0}"
    PII_PROXY_PORT_MIN="${PII_PROXY_PORT_MIN:-20000}"
    PII_PROXY_PORT_MAX="${PII_PROXY_PORT_MAX:-40000}"
    PII_PROXY_VENV="${ISOLATED_CONFIG_DIR}/pii-proxy-venv"
    PII_PROXY_LOG_DIR="${ISOLATED_CONFIG_DIR}/pii-proxy-logs"
    # Per-session PID files live inside a dedicated directory (not at the root of
    # ISOLATED_CONFIG_DIR) to keep the config root tidy and simplify rotation.
    PII_PROXY_PID_DIR="${ISOLATED_CONFIG_DIR}/pii-proxy-pid"
    PII_PROXY_PID_FILE="${PII_PROXY_PID_DIR}/${ICLAUDE_SESSION_ID}.pid"
    PII_PROXY_SERVER_SCRIPT="${ISOLATED_CONFIG_DIR}/pii-proxy-server.py"

    export PII_PROXY_PORT
    export PII_PROXY_PORT_MIN
    export PII_PROXY_PORT_MAX
    export PII_PROXY_VENV
    export PII_PROXY_LOG_DIR
    export PII_PROXY_PID_DIR
    export PII_PROXY_PID_FILE
    export PII_PROXY_SERVER_SCRIPT

    # Graphify (Knowledge Graph)
    GRAPHIFY_UV_BIN="${ISOLATED_NVM_DIR}/bin/uv"
    GRAPHIFY_TOOL_DIR="${ISOLATED_CONFIG_DIR}/graphify"
    GRAPHIFY_PYTHON_DIR="${ISOLATED_CONFIG_DIR}/graphify/python"
    GRAPHIFY_EXTRA_ARGS="${GRAPHIFY_EXTRA_ARGS:-}"

    export GRAPHIFY_UV_BIN GRAPHIFY_TOOL_DIR GRAPHIFY_PYTHON_DIR
    export GRAPHIFY_EXTRA_ARGS

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

    # microVM (Firecracker) sandbox configuration
    # Binaries stored in ISOLATED_CONFIG_DIR/bin/ — already covered by .gitignore
    MICRO_VM_ENABLED="${MICRO_VM_ENABLED:-false}"
    MICRO_VM_BACKEND="${MICRO_VM_BACKEND:-firecracker}"
    MICRO_VM_VCPU="${MICRO_VM_VCPU:-2}"
    MICRO_VM_MEM_MB="${MICRO_VM_MEM_MB:-1024}"
    MICRO_VM_NET_ENABLED="${MICRO_VM_NET_ENABLED:-true}"
    MICRO_VM_NET_TAP_IFACE="${MICRO_VM_NET_TAP_IFACE:-tap-iclaude}"
    MICRO_VM_NET_HOST_IP="${MICRO_VM_NET_HOST_IP:-172.16.0.1}"
    MICRO_VM_NET_GUEST_IP="${MICRO_VM_NET_GUEST_IP:-172.16.0.2}"
    MICRO_VM_SNAPSHOT_ENABLED="${MICRO_VM_SNAPSHOT_ENABLED:-false}"
    MICRO_VM_SNAPSHOT_DIR="${MICRO_VM_SNAPSHOT_DIR:-${ISOLATED_CONFIG_DIR}/microvm-snapshots}"
    MICRO_VM_ROOTFS_PATH="${MICRO_VM_ROOTFS_PATH:-${ISOLATED_CONFIG_DIR}/bin/rootfs.ext4}"
    MICRO_VM_KERNEL_PATH="${MICRO_VM_KERNEL_PATH:-${ISOLATED_CONFIG_DIR}/bin/vmlinux}"
    MICRO_VM_BIN_PATH="${ISOLATED_CONFIG_DIR}/bin/firecracker"
    MICRO_VM_WORK_DIR="${ISOLATED_CONFIG_DIR}/microvm-run"
    MICRO_VM_LOG_LEVEL="${MICRO_VM_LOG_LEVEL:-warn}"
    MICRO_VM_PROXY_PASS="${MICRO_VM_PROXY_PASS:-true}"
    MICRO_VM_MOUNT_WORKSPACE="${MICRO_VM_MOUNT_WORKSPACE:-true}"

    # Per-session microVM state (managed by lifecycle functions)
    MICRO_VM_PID=""
    MICRO_VM_SOCKET=""
    MICRO_VM_SESSION_OWNED=false
    VIRTIOFSD_PID_NVM=""
    VIRTIOFSD_PID_WORKSPACE=""

    export MICRO_VM_ENABLED
    export MICRO_VM_BACKEND
    export MICRO_VM_VCPU
    export MICRO_VM_MEM_MB
    export MICRO_VM_NET_ENABLED
    export MICRO_VM_NET_TAP_IFACE
    export MICRO_VM_NET_HOST_IP
    export MICRO_VM_NET_GUEST_IP
    export MICRO_VM_SNAPSHOT_ENABLED
    export MICRO_VM_SNAPSHOT_DIR
    export MICRO_VM_ROOTFS_PATH
    export MICRO_VM_KERNEL_PATH
    export MICRO_VM_BIN_PATH
    export MICRO_VM_WORK_DIR
    export MICRO_VM_LOG_LEVEL
    export MICRO_VM_PROXY_PASS
    export MICRO_VM_MOUNT_WORKSPACE
    export MICRO_VM_PID
    export MICRO_VM_SOCKET
    export MICRO_VM_SESSION_OWNED
    export VIRTIOFSD_PID_NVM
    export VIRTIOFSD_PID_WORKSPACE
}
