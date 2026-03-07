#!/bin/bash
# microVM runtime module (Firecracker)
# Provides lifecycle management for running Claude Code inside a Firecracker microVM.
#
# Architecture:
#   Host: iclaude.sh → virtiofsd (FUSE) → firecracker VMM → Guest VM
#   Guest: claude process → tool calls → /workspace (virtiofs rw) + /mnt/nvm (virtiofs ro)
#
# Env propagation: virtio-serial channel (not kernel cmdline — 2048 byte limit)
# Networking: TAP interface (tap-iclaude) with iptables MASQUERADE NAT
#
# Note: binaries stored in ISOLATED_CONFIG_DIR/bin/ — covered by .gitignore, not in git.

# ── Input validation helpers ───────────────────────────────────────────────────

#######################################
# Escape a string for safe embedding in a JSON double-quoted value.
# Escapes: backslash, double-quote, control chars (CR, LF, TAB).
# Arguments: $1 - raw string
# Output: escaped string (stdout)
#######################################
_json_escape_str() {
    local s="$1"
    s="${s//\\/\\\\}"   # backslash → \\
    s="${s//\"/\\\"}"   # double-quote → \"
    s="${s//$'\n'/\\n}" # newline → \n
    s="${s//$'\r'/\\r}" # carriage return → \r
    s="${s//$'\t'/\\t}" # tab → \t
    printf '%s' "$s"
}

#######################################
# Validate an IPv4 address (digits and dots only, 4 octets).
# Returns 0 if valid, 1 if not.
#######################################
_validate_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # Check each octet ≤ 255
        local IFS='.'; local octets=($ip); unset IFS
        for o in "${octets[@]}"; do
            [[ "$o" -le 255 ]] 2>/dev/null || return 1
        done
        return 0
    fi
    return 1
}

#######################################
# Validate a network interface name (alphanumeric, dash, underscore; max 15 chars).
# Returns 0 if valid, 1 if not.
#######################################
_validate_iface_name() {
    local name="$1"
    [[ "$name" =~ ^[a-zA-Z0-9_-]{1,15}$ ]]
}

#######################################
# Validate an integer in a range.
# Arguments: $1 value  $2 min  $3 max
# Returns 0 if valid.
#######################################
_validate_int_range() {
    local val="$1" min="$2" max="$3"
    [[ "$val" =~ ^[0-9]+$ ]] && [[ "$val" -ge "$min" ]] && [[ "$val" -le "$max" ]]
}

#######################################
# Escape a value for single-quote shell export in env file.
# Wraps in single quotes, escaping embedded single quotes via '\''
# Arguments: $1 - raw value
# Output: single-quote-escaped string (stdout)
#######################################
_sh_escape_val() {
    local val="$1"
    # Replace ' with '\''
    printf '%s' "${val//\'/\'\\\'\'}"
}

#######################################
# Detect if microVM is fully functional (all components present)
# Returns:
#   0 - microVM available (binary + KVM + images)
#   1 - not available
#######################################
detect_microvm() {
    local skip_isolated="${1:-false}"

    # microVM only supported in isolated environment (skip check only when caller passes "true")
    if [[ "$skip_isolated" != "true" ]] && [[ ! -d "${ISOLATED_NVM_DIR:-}" ]]; then
        return 1
    fi

    # KVM required
    detect_kvm_support &>/dev/null || return 1

    # Firecracker binary
    detect_microvm_binary &>/dev/null || return 1

    # Guest images
    local kernel="${MICRO_VM_KERNEL_PATH:-${ISOLATED_CONFIG_DIR}/bin/vmlinux}"
    local rootfs="${MICRO_VM_ROOTFS_PATH:-${ISOLATED_CONFIG_DIR}/bin/rootfs.ext4}"
    [[ -f "$kernel" ]] || return 1
    [[ -f "$rootfs" ]] || return 1

    return 0
}

#######################################
# Build Firecracker VM configuration JSON
# Writes vmconfig.json to MICRO_VM_WORK_DIR/<session>/
# Arguments:
#   $1 - session_dir: working directory for this session
#   $2 - virtiofs_nvm_socket: path to virtiofsd socket for NVM mount (or "")
#   $3 - virtiofs_ws_socket: path to virtiofsd socket for workspace mount (or "")
# Returns:
#   0 - success; outputs path to config file
#   1 - failure
#######################################
build_microvm_config() {
    local session_dir="$1"

    local config_file="${session_dir}/vmconfig.json"
    local kernel="${MICRO_VM_KERNEL_PATH:-${ISOLATED_CONFIG_DIR}/bin/vmlinux}"
    local rootfs="${MICRO_VM_ROOTFS_PATH:-${ISOLATED_CONFIG_DIR}/bin/rootfs.ext4}"
    local vcpu="${MICRO_VM_VCPU:-2}"
    local mem="${MICRO_VM_MEM_MB:-1024}"
    local tap="${MICRO_VM_NET_TAP_IFACE:-tap-iclaude}"
    local guest_ip="${MICRO_VM_NET_GUEST_IP:-172.16.0.2}"
    local host_ip="${MICRO_VM_NET_HOST_IP:-172.16.0.1}"

    # ── Input validation (security: prevent JSON injection) ────────────────────
    if ! _validate_int_range "$vcpu" 1 128; then
        print_error "microVM: invalid MICRO_VM_VCPU=${vcpu} (must be 1–128)"
        return 1
    fi
    if ! _validate_int_range "$mem" 128 65536; then
        print_error "microVM: invalid MICRO_VM_MEM_MB=${mem} (must be 128–65536)"
        return 1
    fi
    if [[ "${MICRO_VM_NET_ENABLED:-true}" == "true" ]]; then
        if ! _validate_iface_name "$tap"; then
            print_error "microVM: invalid MICRO_VM_NET_TAP_IFACE='${tap}' (alphanumeric, dash, underscore, max 15 chars)"
            return 1
        fi
        if ! _validate_ip "$guest_ip"; then
            print_error "microVM: invalid MICRO_VM_NET_GUEST_IP='${guest_ip}'"
            return 1
        fi
        if ! _validate_ip "$host_ip"; then
            print_error "microVM: invalid MICRO_VM_NET_HOST_IP='${host_ip}'"
            return 1
        fi
    fi

    # ── JSON-safe values ───────────────────────────────────────────────────────
    local kernel_j; kernel_j=$(_json_escape_str "$kernel")
    local rootfs_j; rootfs_j=$(_json_escape_str "$rootfs")
    local tap_j; tap_j=$(_json_escape_str "$tap")
    # guest_ip and host_ip are validated to digits+dots only — no escaping needed

    # Kernel boot arguments — IPs validated above (digits/dots only, safe for cmdline)
    local boot_args="console=ttyS0 reboot=k panic=1 pci=off nomodules"
    boot_args="${boot_args} ip=${guest_ip}::${host_ip}:255.255.255.0::eth0:off"
    local boot_args_j; boot_args_j=$(_json_escape_str "$boot_args")

    # ── Build JSON config ──────────────────────────────────────────────────────
    {
        printf '{\n'
        printf '  "boot-source": {\n'
        printf '    "kernel_image_path": "%s",\n' "$kernel_j"
        printf '    "boot_args": "%s"\n' "$boot_args_j"
        printf '  },\n'
        printf '  "drives": [{\n'
        printf '    "drive_id": "rootfs",\n'
        printf '    "path_on_host": "%s",\n' "$rootfs_j"
        printf '    "is_root_device": true,\n'
        printf '    "is_read_only": false\n'
        printf '  }],\n'
        printf '  "machine-config": {\n'
        printf '    "vcpu_count": %d,\n' "$vcpu"
        printf '    "mem_size_mib": %d\n' "$mem"
        printf '  }'

        # Network interface (TAP) — tap_j is validated alphanumeric+dash/underscore
        if [[ "${MICRO_VM_NET_ENABLED:-true}" == "true" ]]; then
            printf ',\n'
            printf '  "network-interfaces": [{\n'
            printf '    "iface_id": "eth0",\n'
            printf '    "guest_mac": "AA:FC:00:00:00:01",\n'
            printf '    "host_dev_name": "%s"\n' "$tap_j"
            printf '  }]'
        fi

        printf '\n}\n'
    } > "$config_file"

    echo "$config_file"
    return 0
}

#######################################
# Write guest environment file for virtio-serial propagation.
# The guest init script reads this file and sources it before launching claude.
# Arguments:
#   $1 - env_file: path to write env file (accessible inside rootfs overlay)
# Returns:
#   0 - success
#######################################
configure_guest_environment() {
    local env_file="$1"
    local host_ip="${MICRO_VM_NET_HOST_IP:-172.16.0.1}"

    # Determine upstream for API (PII proxy or direct Anthropic)
    local api_base="${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"
    # If PII proxy is active and net is enabled, repoint to host TAP IP
    if [[ "${ICLAUDE_PII_ACTIVE:-0}" == "1" ]] && [[ -n "${ICLAUDE_PII_ACTIVE_PORT:-}" ]] && \
       [[ "${MICRO_VM_NET_ENABLED:-true}" == "true" ]]; then
        api_base="http://${host_ip}:${ICLAUDE_PII_ACTIVE_PORT}"
    fi

    # Build env file — escape all user-controlled values with _sh_escape_val()
    # to prevent single-quote injection in 'export VAR=''value''' assignments.
    local api_base_e; api_base_e=$(_sh_escape_val "$api_base")
    {
        echo "# iclaude microVM guest environment — auto-generated, do not edit"
        echo "export ANTHROPIC_BASE_URL='${api_base_e}'"
        echo "export CLAUDE_CONFIG_DIR='/mnt/hooks'"

        # Proxy settings
        if [[ "${MICRO_VM_PROXY_PASS:-true}" == "true" ]] && \
           [[ "${MICRO_VM_NET_ENABLED:-true}" == "true" ]]; then
            if [[ -n "${HTTPS_PROXY:-}" ]]; then
                local https_proxy_e; https_proxy_e=$(_sh_escape_val "$HTTPS_PROXY")
                echo "export HTTPS_PROXY='${https_proxy_e}'"
            fi
            if [[ -n "${HTTP_PROXY:-}" ]]; then
                local http_proxy_e; http_proxy_e=$(_sh_escape_val "$HTTP_PROXY")
                echo "export HTTP_PROXY='${http_proxy_e}'"
            fi
            if [[ -n "${NO_PROXY:-}" ]]; then
                local no_proxy_e; no_proxy_e=$(_sh_escape_val "$NO_PROXY")
                echo "export NO_PROXY='${no_proxy_e}'"
            fi
        fi

        # Router config (if active)
        if [[ "${ICLAUDE_ROUTER_ACTIVE:-0}" == "1" ]]; then
            echo "export ICLAUDE_ROUTER_ACTIVE=1"
        fi

        # Model selection
        if [[ -n "${CLAUDE_CODE_MODEL:-}" ]]; then
            local model_e; model_e=$(_sh_escape_val "$CLAUDE_CODE_MODEL")
            echo "export CLAUDE_CODE_MODEL='${model_e}'"
        fi
        if [[ -n "${ANTHROPIC_MODEL:-}" ]]; then
            local anthropic_model_e; anthropic_model_e=$(_sh_escape_val "$ANTHROPIC_MODEL")
            echo "export ANTHROPIC_MODEL='${anthropic_model_e}'"
        fi

        # Tasks system
        if [[ -n "${CLAUDE_CODE_ENABLE_TASKS:-}" ]]; then
            local tasks_e; tasks_e=$(_sh_escape_val "$CLAUDE_CODE_ENABLE_TASKS")
            echo "export CLAUDE_CODE_ENABLE_TASKS='${tasks_e}'"
        fi

        # PII proxy status vars for statusline
        if [[ "${ICLAUDE_PII_ACTIVE:-0}" == "1" ]]; then
            local pii_level_e; pii_level_e=$(_sh_escape_val "${ICLAUDE_PII_MASKING_LEVEL:-standard}")
            local pii_port_e; pii_port_e=$(_sh_escape_val "${ICLAUDE_PII_ACTIVE_PORT:-}")
            echo "export ICLAUDE_PII_ACTIVE=1"
            echo "export ICLAUDE_PII_MASKING_LEVEL='${pii_level_e}'"
            echo "export ICLAUDE_PII_ACTIVE_PORT='${pii_port_e}'"
        fi

        # NVM path inside guest (virtiofs mount).
        # printf with single-quoted format prevents host expansion; guest sources
        # the double-quoted assignment so $(ls ...) and ${PATH} expand in the guest.
        echo "export NVM_DIR='/mnt/nvm'"
        printf 'export PATH="/mnt/nvm/versions/node/$(ls /mnt/nvm/versions/node 2>/dev/null | head -1)/bin:/workspace/node_modules/.bin:${PATH}"\n'
    } > "$env_file"

    chmod 600 "$env_file"
    return 0
}

#######################################
# Start virtiofsd daemon for a directory mount
# Arguments:
#   $1 - source_dir: host directory to share
#   $2 - socket_path: UNIX socket path for virtiofsd
# Returns:
#   0 - started; outputs PID
#   1 - failure
#######################################
_start_virtiofsd() {
    local source_dir="$1"
    local socket_path="$2"

    local vfsd
    vfsd=$(detect_virtiofsd 2>/dev/null) || {
        print_warning "virtiofsd not found — workspace mount unavailable"
        echo ""
        return 1
    }

    local -a fc_args=(
        --socket-path "$socket_path"
        --shared-dir  "$source_dir"
    )
    # Note: --readonly is not supported in virtiofsd 1.x (libvhost-user implementation).
    # Read-only enforcement for NVM mount is applied in the guest via mount options.
    # --sandbox none: virtiofsd's seccomp/landlock profile conflicts with some filesystem
    # operations on certain kernels. Intentional trade-off: virtiofs functionality over
    # daemon-level sandboxing. virtiofsd still runs as unprivileged user.
    fc_args+=(--sandbox none --cache always --log-level error)

    "$vfsd" "${fc_args[@]}" &>/dev/null &

    local pid=$!
    # Wait briefly for socket to appear
    local ticks=0
    while [[ $ticks -lt 20 ]]; do
        [[ -S "$socket_path" ]] && { echo "$pid"; return 0; }
        sleep 0.1
        ticks=$((ticks + 1))
    done

    kill "$pid" 2>/dev/null || true
    return 1
}

#######################################
# Start Firecracker microVM and prepare guest for claude launch.
# Sets MICRO_VM_PID, MICRO_VM_SOCKET, MICRO_VM_SESSION_OWNED globals.
# v1 architecture: Claude runs on the host with virtiofs workspace isolation.
# Arguments:
#   $1 - skip_isolated: "true" | "false"
# Returns:
#   0 - VM started and ready
#   1 - failure
#######################################
start_microvm() {
    local skip_isolated="${1:-false}"

    local fc_bin
    fc_bin=$(detect_microvm_binary) || {
        print_warning "microVM: firecracker binary not found — run --install-microvm"
        return 1
    }

    # Create per-session working directory (mode 700: no world/group access)
    local session_id="${ICLAUDE_SESSION_ID:-$$}"
    local session_dir="${MICRO_VM_WORK_DIR:-${ISOLATED_CONFIG_DIR}/microvm-run}/${session_id}"
    if ! mkdir -p "$session_dir" || ! chmod 700 "$session_dir"; then
        print_error "microVM: failed to create session directory: ${session_dir}"
        return 1
    fi

    # Unix socket paths have a 108-byte SUN_LEN limit on Linux.
    # session_dir inside ISOLATED_CONFIG_DIR can be ~115 bytes — too long.
    # Use /tmp for sockets (short paths); keep session_dir for config/log files.
    MICRO_VM_SOCKET="/tmp/iclaude-${session_id}-fc.sock"
    local nvm_socket="/tmp/iclaude-${session_id}-nvm.sock"
    local ws_socket="/tmp/iclaude-${session_id}-ws.sock"
    local nvm_pid=""
    local ws_pid=""

    if [[ -d "${ISOLATED_NVM_DIR:-}" ]]; then
        print_info "microVM: starting virtiofsd for NVM dir (read-only)..."
        if nvm_pid=$(_start_virtiofsd "$ISOLATED_NVM_DIR" "$nvm_socket"); then
            VIRTIOFSD_PID_NVM="$nvm_pid"
            print_info "microVM: virtiofsd NVM PID $nvm_pid"
        else
            print_warning "microVM: could not start virtiofsd for NVM — Node.js unavailable in guest"
        fi
    fi

    # Start virtiofsd for workspace (rw: project directory)
    if [[ "${MICRO_VM_MOUNT_WORKSPACE:-true}" == "true" ]] && [[ -d "${PWD}" ]]; then
        print_info "microVM: starting virtiofsd for workspace (read-write)..."
        if ws_pid=$(_start_virtiofsd "$PWD" "$ws_socket"); then
            VIRTIOFSD_PID_WORKSPACE="$ws_pid"
            print_info "microVM: virtiofsd workspace PID $ws_pid"
        else
            print_warning "microVM: could not start virtiofsd for workspace"
        fi
    fi

    # Write guest environment file to session dir
    local env_file="${session_dir}/guest-env.sh"
    configure_guest_environment "$env_file"

    # Build Firecracker config
    local vmconfig
    vmconfig=$(build_microvm_config "$session_dir" "$nvm_socket" "$ws_socket") || {
        print_error "microVM: failed to generate vmconfig.json"
        _cleanup_virtiofsd
        rm -rf "$session_dir" 2>/dev/null || true
        return 1
    }

    print_info "microVM: starting Firecracker VMM..."
    print_info "microVM: vCPU=${MICRO_VM_VCPU:-2} RAM=${MICRO_VM_MEM_MB:-1024}MiB"

    # Firecracker opens (not creates) the log file — must exist before launch.
    local fc_log="${session_dir}/firecracker.log"
    touch "$fc_log"

    # Launch Firecracker in background
    # Firecracker CLI expects capitalised log level (Warn, Info, Debug, Error)
    local fc_log_level="${MICRO_VM_LOG_LEVEL:-warn}"
    fc_log_level="${fc_log_level^}"
    "$fc_bin" \
        --api-sock "$MICRO_VM_SOCKET" \
        --config-file "$vmconfig" \
        --log-path "$fc_log" \
        --level "$fc_log_level" \
        &>/dev/null &

    MICRO_VM_PID=$!
    MICRO_VM_SESSION_OWNED=true
    export MICRO_VM_PID MICRO_VM_SOCKET MICRO_VM_SESSION_OWNED
    export VIRTIOFSD_PID_NVM VIRTIOFSD_PID_WORKSPACE

    # Wait for Firecracker API socket to appear (max 10s)
    local ticks=0
    while [[ $ticks -lt 40 ]]; do
        if ! kill -0 "$MICRO_VM_PID" 2>/dev/null; then
            print_error "microVM: Firecracker process exited unexpectedly"
            print_info "microVM: log: ${session_dir}/firecracker.log"
            _cleanup_virtiofsd
            rm -rf "$session_dir" 2>/dev/null || true
            return 1
        fi
        [[ -S "$MICRO_VM_SOCKET" ]] && break
        sleep 0.25
        ticks=$((ticks + 1))
    done

    if [[ ! -S "$MICRO_VM_SOCKET" ]]; then
        print_error "microVM: Firecracker API socket did not appear within 10s"
        kill "$MICRO_VM_PID" 2>/dev/null || true
        _cleanup_virtiofsd
        rm -rf "$session_dir" 2>/dev/null || true
        return 1
    fi

    # Propagate guest env: copy to workspace root so guest init can source it via virtiofs.
    # Guest init reads /workspace/.iclaude-guest-env.sh (virtiofs rw mount of $PWD).
    # install -m 600 atomically creates the file with restricted permissions.
    # File is deleted by stop_microvm() and is covered by .gitignore.
    if ! install -m 600 "$env_file" "${PWD}/.iclaude-guest-env.sh" 2>/dev/null; then
        print_warning "microVM: could not write guest env to workspace (read-only FS or quota?)"
        print_warning "microVM: guest may start without proxy/API configuration"
    fi

    # Signal to statusline that microVM is active
    export ICLAUDE_MICROVM_ACTIVE=1
    export ICLAUDE_MICROVM_PID="${MICRO_VM_PID}"

    print_success "microVM: Firecracker started (PID ${MICRO_VM_PID}, socket ${MICRO_VM_SOCKET})"
    return 0
}

#######################################
# Stop Firecracker microVM and cleanup all resources.
# Called from trap EXIT/INT/TERM.
#######################################
stop_microvm() {
    # Save snapshot before shutdown if enabled
    if [[ "${MICRO_VM_SNAPSHOT_ENABLED:-false}" == "true" ]] && \
       [[ -n "${MICRO_VM_SOCKET:-}" ]] && [[ -S "${MICRO_VM_SOCKET}" ]]; then
        local snap_dir="${MICRO_VM_SNAPSHOT_DIR:-${ISOLATED_CONFIG_DIR}/microvm-snapshots}"
        local snap_id="${ICLAUDE_SESSION_ID:-$$}"
        mkdir -p "$snap_dir"
        # Pause VM before snapshot via Firecracker API
        curl -s --unix-socket "$MICRO_VM_SOCKET" \
            -X PATCH "http://localhost/vm" \
            -H "Content-Type: application/json" \
            -d '{"state": "Paused"}' &>/dev/null || true
        # Create snapshot — JSON-escape paths to prevent injection
        local snap_path_j; snap_path_j=$(_json_escape_str "${snap_dir}/${snap_id}.snap")
        local mem_path_j; mem_path_j=$(_json_escape_str "${snap_dir}/${snap_id}.mem")
        curl -s --unix-socket "$MICRO_VM_SOCKET" \
            -X PUT "http://localhost/snapshot/create" \
            -H "Content-Type: application/json" \
            -d "{\"snapshot_type\": \"Full\", \"snapshot_path\": \"${snap_path_j}\", \"mem_file_path\": \"${mem_path_j}\"}" \
            &>/dev/null || true
    fi

    # Stop Firecracker VMM
    if [[ "${MICRO_VM_SESSION_OWNED:-false}" == "true" ]] && \
       [[ -n "${MICRO_VM_PID:-}" ]] && kill -0 "${MICRO_VM_PID}" 2>/dev/null; then
        kill "${MICRO_VM_PID}" 2>/dev/null || true
        local waited=0
        while kill -0 "${MICRO_VM_PID}" 2>/dev/null && [[ $waited -lt 30 ]]; do
            sleep 0.1
            waited=$((waited + 1))
        done
        kill -9 "${MICRO_VM_PID}" 2>/dev/null || true
        MICRO_VM_PID=""
        MICRO_VM_SESSION_OWNED=false
    fi

    # Stop virtiofsd daemons
    _cleanup_virtiofsd

    # Remove guest env file from workspace
    rm -f "${PWD}/.iclaude-guest-env.sh" 2>/dev/null || true

    # Remove per-session work dir and /tmp sockets (virtiofsd creates .pid files alongside)
    local session_id="${ICLAUDE_SESSION_ID:-$$}"
    local session_dir="${MICRO_VM_WORK_DIR:-${ISOLATED_CONFIG_DIR}/microvm-run}/${session_id}"
    rm -rf "$session_dir" 2>/dev/null || true
    rm -f "/tmp/iclaude-${session_id}-fc.sock" \
          "/tmp/iclaude-${session_id}-nvm.sock" \
          "/tmp/iclaude-${session_id}-nvm.sock.pid" \
          "/tmp/iclaude-${session_id}-ws.sock" \
          "/tmp/iclaude-${session_id}-ws.sock.pid" 2>/dev/null || true
}

#######################################
# Kill virtiofsd daemon processes owned by this session.
#######################################
_cleanup_virtiofsd() {
    for pid_var in VIRTIOFSD_PID_NVM VIRTIOFSD_PID_WORKSPACE; do
        local pid="${!pid_var:-}"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            local waited=0
            while kill -0 "$pid" 2>/dev/null && [[ $waited -lt 10 ]]; do
                sleep 0.1
                waited=$((waited + 1))
            done
            kill -9 "$pid" 2>/dev/null || true
        fi
        printf -v "${pid_var}" '%s' ''
    done
}

#######################################
# Register signal traps for microVM cleanup.
# Must be called after start_microvm() succeeds.
#######################################
setup_microvm_traps() {
    trap 'stop_microvm' EXIT
    trap 'stop_microvm; exit 130' INT
    trap 'stop_microvm; exit 143' TERM
}
