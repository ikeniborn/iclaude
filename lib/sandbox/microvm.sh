#!/bin/bash
# microVM runtime module (Firecracker)
# Provides lifecycle management for running Claude Code inside a Firecracker microVM.
#
# Architecture:
#   Host: iclaude.sh → firecracker VMM (KVM) → Guest VM (virtio-blk)
#   Drives: vda=rootfs (per-session copy, rw), vdb=nvm.img (ro), vdc=workspace.img (rw)
#   Guest: claude process → tool calls → /workspace (vdc ext4) + /mnt/nvm (vdb ext4 ro)
#   Connectivity: SSH exec over TAP/NAT; workspace sync via tar-over-SSH
#
# Env propagation: SCP of guest-env.sh → /workspace/.iclaude-guest-env.sh before SSH exec
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

# ── Subnet allocation helpers ──────────────────────────────────────────────────
# Support multiple concurrent microVM sessions by allocating unique IP pairs
# from a configurable subnet (MICRO_VM_NET_SUBNET, default 172.16.0.0/26).
#
# Slot model (no per-slot broadcast waste):
#   Slot N → host IP = base+2N+1, guest IP = base+2N+2, TAP = {prefix}-{N+1}
#   MICRO_VM_NET_TAP_IFACE is the prefix (default: tap-iclaude); actual name = prefix + "-" + slot_number(1-indexed).
# Example with 172.16.0.0/26 (62 usable hosts → 31 slots):
#   Slot 0: host=172.16.0.1  guest=172.16.0.2  tap=tap-iclaude-1
#   Slot 1: host=172.16.0.3  guest=172.16.0.4  tap=tap-iclaude-2
#   Slot 2: host=172.16.0.5  guest=172.16.0.6  tap=tap-iclaude-3

# Parse "base/prefix" CIDR into MICROVM_SUBNET_INT and MICROVM_SUBNET_PREFIX.
_microvm_parse_subnet() {
    local subnet="$1"
    MICROVM_SUBNET_PREFIX="${subnet#*/}"
    local base="${subnet%/*}"
    if ! [[ "$MICROVM_SUBNET_PREFIX" =~ ^[0-9]+$ ]] || \
       (( MICROVM_SUBNET_PREFIX < 1 || MICROVM_SUBNET_PREFIX > 30 )); then
        return 1
    fi
    if ! _validate_ip "$base"; then return 1; fi
    local o1 o2 o3 o4
    IFS='.' read -r o1 o2 o3 o4 <<< "$base"
    MICROVM_SUBNET_INT=$(( o1*16777216 + o2*65536 + o3*256 + o4 ))
}

# Get dotted-decimal IP at offset N from parsed subnet base.
_microvm_ip_at() {
    local n=$(( MICROVM_SUBNET_INT + $1 ))
    printf '%d.%d.%d.%d' $(( (n>>24)&255 )) $(( (n>>16)&255 )) $(( (n>>8)&255 )) $(( n&255 ))
}

# Convert prefix length to dotted-decimal netmask (e.g., 26 → 255.255.255.192).
_microvm_prefix_to_mask() {
    local prefix="$1"
    local m=$(( (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF ))
    printf '%d.%d.%d.%d' $(( (m>>24)&255 )) $(( (m>>16)&255 )) $(( (m>>8)&255 )) $(( m&255 ))
}

#######################################
# Allocate a free network slot from MICRO_VM_NET_SUBNET.
# Exports MICRO_VM_SLOT, MICRO_VM_NET_TAP_IFACE, MICRO_VM_NET_HOST_IP,
#         MICRO_VM_NET_GUEST_IP, MICRO_VM_NET_MASK.
# Legacy mode: if MICRO_VM_NET_GUEST_IP is set without MICRO_VM_NET_SUBNET,
#              uses those values directly (slot 0, mask /24).
# Returns 0 on success, 1 if all slots occupied.
#######################################
_alloc_microvm_slot() {
    # Legacy mode: explicit GUEST/HOST IP without subnet config
    if [[ -n "${MICRO_VM_NET_GUEST_IP:-}" ]] && [[ -z "${MICRO_VM_NET_SUBNET:-}" ]]; then
        MICRO_VM_SLOT=0
        MICRO_VM_NET_TAP_IFACE="${MICRO_VM_NET_TAP_IFACE:-tap-iclaude}"
        MICRO_VM_NET_HOST_IP="${MICRO_VM_NET_HOST_IP:-172.16.0.1}"
        MICRO_VM_NET_MASK="255.255.255.0"
        MICROVM_SUBNET_PREFIX=24
        export MICRO_VM_SLOT MICRO_VM_NET_TAP_IFACE MICRO_VM_NET_HOST_IP \
               MICRO_VM_NET_GUEST_IP MICRO_VM_NET_MASK
        return 0
    fi

    local subnet="${MICRO_VM_NET_SUBNET:-172.16.0.0/26}"
    if ! _microvm_parse_subnet "$subnet"; then
        print_error "microVM: invalid MICRO_VM_NET_SUBNET='${subnet}' (use CIDR, e.g. 172.16.0.0/26)"
        return 1
    fi

    local size=$(( 1 << (32 - MICROVM_SUBNET_PREFIX) ))
    local max_slots=$(( (size - 2) / 2 ))
    if (( max_slots < 1 )); then
        print_error "microVM: subnet ${subnet} too small (need at least /30 for one slot)"
        return 1
    fi

    local slots_dir="${ISOLATED_CONFIG_DIR}/microvm-slots"
    mkdir -p "$slots_dir"

    local slot
    for slot in $(seq 0 $((max_slots - 1))); do
        local lock="${slots_dir}/slot-${slot}.lock"
        # Check if slot is held by a live process
        if [[ -f "$lock" ]]; then
            local lock_content; lock_content=$(cat "$lock" 2>/dev/null || echo "")
            # Handle both "PID" and "PID-pending" formats
            local lock_pid="${lock_content%%-*}"
            if [[ "$lock_pid" =~ ^[0-9]+$ ]] && kill -0 "$lock_pid" 2>/dev/null; then
                continue
            fi
            # Stale lock — remove before atomic claim attempt
            rm -f "$lock" 2>/dev/null || true
        fi

        # Atomically claim the slot via noclobber (set -C).
        # If another process writes the file first, this fails and we try the next slot.
        if ! (set -C; echo "$$-pending" > "$lock") 2>/dev/null; then
            continue
        fi

        # Slot claimed — populate variables
        MICRO_VM_SLOT="$slot"
        MICRO_VM_NET_HOST_IP="$(_microvm_ip_at $((2*slot + 1)))"
        MICRO_VM_NET_GUEST_IP="$(_microvm_ip_at $((2*slot + 2)))"
        MICRO_VM_NET_MASK="$(_microvm_prefix_to_mask "$MICROVM_SUBNET_PREFIX")"
        # MICRO_VM_NET_TAP_IFACE is a prefix; actual name = prefix + "-" + (slot+1) (1-indexed).
        # This ensures consistent naming (no bare "tap-iclaude") and allows concurrent VMs to use
        # predictable, unique interface names without manual per-slot configuration.
        local _tap_prefix="${MICRO_VM_NET_TAP_IFACE:-tap-iclaude}"
        MICRO_VM_NET_TAP_IFACE="${_tap_prefix}-$((slot + 1))"
        export MICRO_VM_SLOT MICRO_VM_NET_TAP_IFACE MICRO_VM_NET_HOST_IP \
               MICRO_VM_NET_GUEST_IP MICRO_VM_NET_MASK
        return 0
    done

    print_error "microVM: all ${max_slots} slots in ${subnet} occupied (too many concurrent sessions)"
    return 1
}

# Overwrite the pending placeholder with the real Firecracker PID.
# Called after FC process starts — replaces "$$-pending" written by _alloc_microvm_slot.
_claim_microvm_slot() {
    [[ -z "${MICRO_VM_SLOT:-}" ]] && return 0
    local slots_dir="${ISOLATED_CONFIG_DIR}/microvm-slots"
    mkdir -p "$slots_dir"
    echo "$MICRO_VM_PID" > "${slots_dir}/slot-${MICRO_VM_SLOT}.lock"
}

# Release slot lockfile when VM stops.
_free_microvm_slot() {
    [[ -z "${MICRO_VM_SLOT:-}" ]] && return 0
    rm -f "${ISOLATED_CONFIG_DIR}/microvm-slots/slot-${MICRO_VM_SLOT}.lock" 2>/dev/null || true
}

#######################################
# Ensure TAP interface for the current slot exists with the correct host IP.
# Creates TAP via sudo if missing; updates IP if mismatched.
# Requires MICRO_VM_NET_TAP_IFACE, MICRO_VM_NET_HOST_IP, MICROVM_SUBNET_PREFIX.
#######################################
_ensure_slot_tap() {
    [[ "${MICRO_VM_NET_ENABLED:-true}" != "true" ]] && return 0
    local tap="${MICRO_VM_NET_TAP_IFACE}"
    local host_ip="${MICRO_VM_NET_HOST_IP}"
    local prefix="${MICROVM_SUBNET_PREFIX:-24}"

    if ! ip link show "$tap" &>/dev/null; then
        # TAP doesn't exist — try to create via sudo
        if ! sudo -n true 2>/dev/null; then
            print_error "microVM: TAP ${tap} not found (sudo unavailable to create it)"
            print_info "  Run: sudo ip tuntap add dev ${tap} mode tap"
            print_info "  Run: sudo ip addr add ${host_ip}/${prefix} dev ${tap}"
            print_info "  Run: sudo ip link set ${tap} up"
            return 1
        fi
        if sudo ip tuntap add dev "$tap" mode tap 2>/dev/null && \
           sudo ip addr add "${host_ip}/${prefix}" dev "$tap" 2>/dev/null && \
           sudo ip link set "$tap" up 2>/dev/null; then
            # Add FORWARD rules for new TAP
            local out_iface; out_iface=$(ip route 2>/dev/null | awk '/^default/ {print $5; exit}')
            if [[ -n "$out_iface" ]] && [[ "$out_iface" =~ ^[a-zA-Z0-9_-]{1,15}$ ]]; then
                sudo iptables -A FORWARD -i "$tap" -o "$out_iface" -j ACCEPT 2>/dev/null || true
                sudo iptables -A FORWARD -i "$out_iface" -o "$tap" \
                    -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
            fi
            print_info "microVM: TAP ${tap} created (${host_ip}/${prefix})"
        else
            print_error "microVM: failed to create TAP ${tap} — re-run --install-microvm"
            return 1
        fi
        return 0
    fi

    # TAP exists — verify host IP matches; update if not.
    # Capture full CIDR (e.g. "172.32.0.1/26") so deletion uses the original prefix,
    # not the new one — mismatched prefix causes ip addr del to fail and leaves a
    # stale kernel route for the old subnet.
    local tap_cidr tap_ip
    tap_cidr=$(ip addr show "$tap" 2>/dev/null | awk '/inet / {print $2; exit}')
    tap_ip="${tap_cidr%%/*}"
    if [[ "$tap_ip" == "$host_ip" ]]; then
        # Correct IP already assigned; ensure UP
        ip link show "$tap" 2>/dev/null | grep -q "UP" || \
            sudo ip link set "$tap" up 2>/dev/null || true
        return 0
    fi

    print_warning "microVM: TAP ${tap} has IP ${tap_ip:-none}, expected ${host_ip}/${prefix} — updating"
    if sudo -n true 2>/dev/null; then
        # Delete using the exact CIDR from the interface (preserves original prefix length)
        [[ -n "$tap_cidr" ]] && sudo ip addr del "$tap_cidr" dev "$tap" 2>/dev/null || true
        sudo ip addr add "${host_ip}/${prefix}" dev "$tap" 2>/dev/null && \
        sudo ip link set "$tap" up 2>/dev/null && \
        print_info "microVM: TAP ${tap} IP updated → ${host_ip}/${prefix}" || \
        print_warning "microVM: failed to update TAP IP — routing may fail"
    else
        print_error "microVM: TAP IP mismatch, sudo unavailable to fix it"
        print_info "  Expected: ${host_ip}/${prefix} on ${tap}"
        print_info "  Fix: sudo ip addr add ${host_ip}/${prefix} dev ${tap}"
        print_info "  Or: re-run ./iclaude.sh --install-microvm with updated config"
        return 1
    fi
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
#   $2 - nvm_img: path to pre-built ext4 block image for /mnt/nvm (or "")
#   $3 - workspace_img: path to ext4 block image for /workspace (or "")
# Block device layout in guest:
#   /dev/vda — rootfs (drive_id: rootfs, is_root_device: true)
#   /dev/vdb — nvm image (drive_id: nvm, read-only, contains .nvm-isolated)
#   /dev/vdc — workspace image (drive_id: workspace, read-write)
# Returns:
#   0 - success; outputs path to config file
#   1 - failure
#######################################
build_microvm_config() {
    local session_dir="$1"
    local nvm_img="${2:-}"         # path to pre-built NVM ext4 block image (or "" if not available)
    local workspace_img="${3:-}"   # path to workspace ext4 block image (or "" if not available)

    local config_file="${session_dir}/vmconfig.json"
    local kernel="${MICRO_VM_KERNEL_PATH:-${ISOLATED_CONFIG_DIR}/bin/vmlinux}"
    local rootfs="${MICRO_VM_ROOTFS_PATH:-${ISOLATED_CONFIG_DIR}/bin/rootfs.ext4}"
    local vcpu="${MICRO_VM_VCPU:-2}"
    local mem="${MICRO_VM_MEM_MB:-1024}"
    local tap="${MICRO_VM_NET_TAP_IFACE:-tap-iclaude}"
    local guest_ip="${MICRO_VM_NET_GUEST_IP:-172.16.0.2}"
    local host_ip="${MICRO_VM_NET_HOST_IP:-172.16.0.1}"
    local mask="${MICRO_VM_NET_MASK:-255.255.255.0}"
    # Per-slot MAC: AA:FC:00:00:00:<slot+1 hex> — unique per concurrent VM
    local slot_hex; printf -v slot_hex '%02X' $(( ${MICRO_VM_SLOT:-0} + 1 ))
    local guest_mac="AA:FC:00:00:00:${slot_hex}"

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
    boot_args="${boot_args} ip=${guest_ip}::${host_ip}:${mask}::eth0:off"

    # v2: guest init replaces systemd (fast boot, block devices + SSH control)
    # Use /usr/sbin/ — Ubuntu 22.04 rootfs has /sbin as symlink; kernel init= resolves
    # paths in the rootfs before symlinks are set up, so use the canonical path.
    # NOTE: rootfs may be a per-session sparse copy; the v2-ready marker lives next to
    # the original base image (MICRO_VM_ROOTFS_PATH before session override, or the
    # default base path). Check the base marker explicitly.
    local rootfs_base_marker="${ISOLATED_CONFIG_DIR}/bin/rootfs.v2-ready"
    if [[ -f "$rootfs_base_marker" ]]; then
        boot_args="${boot_args} init=/usr/sbin/iclaude-guest-init"
    fi

    local boot_args_j; boot_args_j=$(_json_escape_str "$boot_args")

    # ── Build JSON config ──────────────────────────────────────────────────────
    {
        printf '{\n'
        printf '  "boot-source": {\n'
        printf '    "kernel_image_path": "%s",\n' "$kernel_j"
        printf '    "boot_args": "%s"\n' "$boot_args_j"
        printf '  },\n'

        # Drives: rootfs (vda) + optional nvm block image (vdb) + workspace block image (vdc)
        printf '  "drives": [\n'
        printf '    {\n'
        printf '      "drive_id": "rootfs",\n'
        printf '      "path_on_host": "%s",\n' "$rootfs_j"
        printf '      "is_root_device": true,\n'
        printf '      "is_read_only": false\n'
        printf '    }'
        if [[ -n "$nvm_img" && -f "$nvm_img" ]]; then
            local nvm_img_j; nvm_img_j=$(_json_escape_str "$nvm_img")
            printf ',\n    {\n'
            printf '      "drive_id": "nvm",\n'
            printf '      "path_on_host": "%s",\n' "$nvm_img_j"
            printf '      "is_root_device": false,\n'
            printf '      "is_read_only": true\n'
            printf '    }'
        fi
        if [[ -n "$workspace_img" && -f "$workspace_img" ]]; then
            local ws_img_j; ws_img_j=$(_json_escape_str "$workspace_img")
            printf ',\n    {\n'
            printf '      "drive_id": "workspace",\n'
            printf '      "path_on_host": "%s",\n' "$ws_img_j"
            printf '      "is_root_device": false,\n'
            printf '      "is_read_only": false\n'
            printf '    }'
        fi
        printf '\n  ],\n'

        printf '  "machine-config": {\n'
        printf '    "vcpu_count": %d,\n' "$vcpu"
        printf '    "mem_size_mib": %d\n' "$mem"
        printf '  }'

        # Network interface (TAP) — tap_j is validated alphanumeric+dash/underscore
        if [[ "${MICRO_VM_NET_ENABLED:-true}" == "true" ]]; then
            printf ',\n'
            printf '  "network-interfaces": [{\n'
            printf '    "iface_id": "eth0",\n'
            printf '    "guest_mac": "%s",\n' "$guest_mac"
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
        # CLAUDE_CONFIG_DIR: create writable guest config at /workspace/.claude-guest.
        # Symlinks most subdirs from the RO nvm image; COPIES files that claude writes
        # during a session (.claude.json, .credentials.json, history.jsonl) so that
        # write attempts don't fail with EPERM on the read-only /dev/vdb mount.
        # Writes a patched settings.json without skipDangerousModePermissionPrompt.
        # shellcheck disable=SC2016
        echo 'python3 -c '"'"'import json,pathlib,shutil; src=pathlib.Path("/mnt/nvm/.claude-isolated"); dst=pathlib.Path("/workspace/.claude-guest"); dst.mkdir(exist_ok=True); copy_set={".claude.json",".credentials.json","history.jsonl","stats-cache.json"}; skip_set={"projects","settings.json"}; [(shutil.copy2(i,dst/i.name) if i.name in copy_set and not (dst/i.name).exists() else ((dst/i.name).symlink_to(i) if not (dst/i.name).exists() and i.name not in skip_set else None)) for i in src.iterdir()]; s=src/"settings.json"; d=json.loads(s.read_text()) if s.exists() else {}; d.pop("skipDangerousModePermissionPrompt",None); (dst/"settings.json").write_text(json.dumps(d,indent=2))'"'"' 2>/dev/null || true'
        echo "export CLAUDE_CONFIG_DIR='/workspace/.claude-guest'"

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
            # Always add host TAP IP to NO_PROXY so that the PII proxy (http://host_ip:port)
            # is reached directly without routing through external HTTPS proxy.
            # Without this undici routes http://172.16.0.1:PORT through HTTP_PROXY →
            # external proxy cannot reach private TAP address → UND_ERR_SOCKET.
            local _no_proxy_base="${NO_PROXY:-}"
            local _no_proxy_guest="${_no_proxy_base:+${_no_proxy_base},}${host_ip}"
            local no_proxy_e; no_proxy_e=$(_sh_escape_val "$_no_proxy_guest")
            echo "export NO_PROXY='${no_proxy_e}'"
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

        # NVM path inside guest (/dev/vdb mounted at /mnt/nvm by guest-init).
        # printf with single-quoted format prevents host expansion; guest sources
        # the double-quoted assignment so $(ls ...) and ${PATH} expand in the guest.
        # npm-global/bin must be first so 'claude', 'ccr', and other global tools are found.
        echo "export NVM_DIR='/mnt/nvm'"
        printf 'export PATH="/mnt/nvm/npm-global/bin:/mnt/nvm/versions/node/$(ls /mnt/nvm/versions/node 2>/dev/null | head -1)/bin:/workspace/node_modules/.bin:${PATH}"\n'
    } > "$env_file"

    chmod 600 "$env_file"
    return 0
}


#######################################
# Validate session_id and create the per-session working directory.
# Sets MICRO_VM_SOCKET global.
# Arguments:
#   $1 - session_id: session identifier
#   $2 - work_dir: base working directory
# Outputs (stdout):
#   Full path to created session_dir
# Returns:
#   0 - success
#   1 - failure (invalid id or mkdir failed)
#######################################
_setup_microvm_session_dir() {
    local session_id="$1"
    local work_dir="$2"

    # Validate session_id: only alphanumeric, dash, underscore allowed.
    # Prevents path traversal if ICLAUDE_SESSION_ID is set to a malicious value (e.g. "../../../etc").
    if ! [[ "$session_id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "microVM: invalid session_id '${session_id}' — must contain only [a-zA-Z0-9_-]"
        return 1
    fi

    local session_dir="${work_dir}/${session_id}"
    if ! mkdir -p "$session_dir" || ! chmod 700 "$session_dir"; then
        print_error "microVM: failed to create session directory: ${session_dir}"
        return 1
    fi

    # Unix socket path (108-byte SUN_LEN limit on Linux — use /tmp, not session_dir)
    MICRO_VM_SOCKET="/tmp/iclaude-${session_id}-fc.sock"

    echo "$session_dir"
}

#######################################
# Create a sparse ext4 workspace image for the guest.
# Arguments:
#   $1 - ws_img: path for the workspace image file
#   $2 - ws_size_mb: size in MiB
#   $3 - session_dir: session directory (for cleanup on failure)
# Returns:
#   0 - success
#   1 - failure
#######################################
_create_workspace_image() {
    local ws_img="$1"
    local ws_size_mb="${2:-2048}"
    local session_dir="$3"

    if ! [[ "$ws_size_mb" =~ ^[0-9]+$ ]] || (( ws_size_mb < 1 || ws_size_mb > 65536 )); then
        print_error "microVM: MICRO_VM_WORKSPACE_SIZE_MB must be an integer 1–65536, got: ${ws_size_mb}"
        rm -rf "$session_dir" 2>/dev/null; return 1
    fi
    print_info "microVM: creating workspace image (${ws_size_mb}MiB sparse)..."
    if ! dd if=/dev/zero of="$ws_img" bs=1M count=0 seek="$ws_size_mb" 2>/dev/null; then
        print_error "microVM: failed to create workspace image at ${ws_img}"
        rm -rf "$session_dir" 2>/dev/null; return 1
    fi
    if ! mkfs.ext4 -F -q "$ws_img" 2>/dev/null; then
        print_error "microVM: failed to format workspace image (mkfs.ext4)"
        rm -rf "$session_dir" 2>/dev/null; return 1
    fi
    return 0
}

#######################################
# Wait for the Firecracker API socket to appear after launch.
# Arguments:
#   $1 - pid: Firecracker process PID
#   $2 - socket: path to the API socket
#   $3 - session_dir: session directory (for log path and cleanup on failure)
# Returns:
#   0 - socket appeared
#   1 - timeout or process died
#######################################
_wait_firecracker_socket() {
    local pid="$1"
    local socket="$2"
    local session_dir="$3"

    local ticks=0
    while [[ $ticks -lt 40 ]]; do
        if ! kill -0 "$pid" 2>/dev/null; then
            print_error "microVM: Firecracker process exited unexpectedly"
            print_info "microVM: log: ${session_dir}/firecracker.log"
            rm -rf "$session_dir" 2>/dev/null || true
            return 1
        fi
        [[ -S "$socket" ]] && return 0
        sleep 0.25
        ticks=$((ticks + 1))
    done

    print_error "microVM: Firecracker API socket did not appear within 10s"
    kill "$pid" 2>/dev/null || true
    rm -rf "$session_dir" 2>/dev/null || true
    return 1
}

#######################################
# Poll guest SSH until it becomes ready.
# Arguments:
#   $1 - guest_ip: IP address of the guest
#   $2 - ssh_key: path to the SSH private key
#   $3 - fc_pid: Firecracker PID (checked to detect early exit)
#   $4 - session_dir: session directory (for log path and cleanup on failure)
#   Remaining args: SSH known-hosts options array (passed as individual args)
# Returns:
#   0 - SSH ready; outputs tick count on stdout
#   1 - timeout or Firecracker died
#######################################
_poll_guest_ssh() {
    local guest_ip="$1"
    local ssh_key="$2"
    local fc_pid="$3"
    local session_dir="$4"
    shift 4
    local -a kh_opts=("$@")

    print_info "microVM: waiting for guest SSH (${guest_ip})..."
    local ticks=0
    while [[ $ticks -lt 60 ]]; do   # 60 × 0.5s = 30s
        if ! kill -0 "$fc_pid" 2>/dev/null; then
            print_error "microVM: Firecracker exited before guest SSH was ready"
            print_info "microVM: log: ${session_dir}/firecracker.log"
            rm -rf "$session_dir" 2>/dev/null; return 1
        fi
        if ssh \
            -i "$ssh_key" \
            "${kh_opts[@]}" \
            -o ConnectTimeout=1 \
            -o BatchMode=yes \
            -o LogLevel=ERROR \
            "iclaude@${guest_ip}" \
            'exit 0' </dev/null 2>/dev/null; then
            echo "$ticks"
            return 0
        fi
        sleep 0.5
        ticks=$((ticks + 1))
    done

    print_error "microVM: guest SSH did not become ready within 30s"
    print_info "microVM: log: ${session_dir}/firecracker.log"
    kill "$fc_pid" 2>/dev/null || true
    rm -rf "$session_dir" 2>/dev/null; return 1
}

#######################################
# Start Firecracker microVM and prepare guest for claude launch.
# Sets MICRO_VM_PID, MICRO_VM_SOCKET, MICRO_VM_SESSION_OWNED globals.
# v2 architecture: Claude runs INSIDE guest VM via SSH; block devices for storage.
# Block device layout:
#   /dev/vda — rootfs (is_root_device: true)
#   /dev/vdb — nvm.img (pre-built at install, read-only, contains .nvm-isolated)
#   /dev/vdc — workspace.img (per-session sparse ext4, populated via SSH rsync)
# Arguments:
#   $1 - skip_isolated: "true" | "false"
# Returns:
#   0 - VM started and SSH ready
#   1 - failure
#######################################
start_microvm() {
    local skip_isolated="${1:-false}"

    local fc_bin
    fc_bin=$(detect_microvm_binary) || {
        print_warning "microVM: firecracker binary not found — run --install-microvm"
        return 1
    }

    # Allocate a free network slot (unique guest/host IP pair within subnet pool).
    # Exports MICRO_VM_SLOT, MICRO_VM_NET_TAP_IFACE, MICRO_VM_NET_HOST_IP,
    #         MICRO_VM_NET_GUEST_IP, MICRO_VM_NET_MASK.
    _alloc_microvm_slot || return 1

    # Ensure the allocated TAP interface exists with the correct host IP.
    if [[ "${MICRO_VM_NET_ENABLED:-true}" == "true" ]]; then
        _ensure_slot_tap || return 1
        # Add a /32 host route for the guest IP via this slot's TAP.
        # Without this, all slots in the same /26 subnet share one subnet route
        # (e.g. 172.16.0.0/26), and Linux picks arbitrarily between TAPs when
        # multiple VMs run concurrently — packets to slot-N's guest may arrive at
        # slot-0's TAP instead. A specific /32 route takes precedence.
        if [[ -n "${MICRO_VM_NET_GUEST_IP:-}" ]] && sudo -n true 2>/dev/null; then
            sudo ip route replace "${MICRO_VM_NET_GUEST_IP}/32" dev "${MICRO_VM_NET_TAP_IFACE}" 2>/dev/null || true
        fi
    fi

    # Create per-session working directory (mode 700: no world/group access)
    local session_id="${ICLAUDE_SESSION_ID:-$$}"
    local work_dir="${MICRO_VM_WORK_DIR:-${ISOLATED_CONFIG_DIR}/microvm-run}"
    local session_dir
    session_dir=$(_setup_microvm_session_dir "$session_id" "$work_dir") || return 1
    # _setup_microvm_session_dir sets MICRO_VM_SOCKET inside a subshell ($() substitution),
    # so the global assignment is discarded. Reconstruct the socket path here in parent shell.
    # Must match the formula in _setup_microvm_session_dir (Unix SUN_LEN limit → use /tmp).
    MICRO_VM_SOCKET="/tmp/iclaude-${session_id}-fc.sock"
    export MICRO_VM_SOCKET

    # ── Block device images ────────────────────────────────────────────────────

    # Rootfs: per-session sparse copy of the shared base image.
    # Firecracker opens it read-write (vda); sharing one rw file across concurrent VMs
    # would corrupt ext4. Sparse copy (~90ms for 300MB on ext4) is negligible overhead.
    local rootfs_base="${MICRO_VM_ROOTFS_PATH:-${ISOLATED_CONFIG_DIR}/bin/rootfs.ext4}"
    local rootfs_session="${session_dir}/rootfs.ext4"
    # Save original before overriding, so it can be restored after vmconfig is written.
    local _rootfs_path_orig="${MICRO_VM_ROOTFS_PATH:-}"
    if ! cp --sparse=always "$rootfs_base" "$rootfs_session" 2>/dev/null; then
        print_error "microVM: failed to create per-session rootfs copy at ${rootfs_session}"
        rm -rf "$session_dir" 2>/dev/null; return 1
    fi
    # Override so build_microvm_config picks up the per-session copy.
    MICRO_VM_ROOTFS_PATH="$rootfs_session"

    # NVM image: pre-built at --install-microvm time, mounted read-only as /dev/vdb → /mnt/nvm
    local nvm_img="${MICRO_VM_NVM_IMG:-${ISOLATED_CONFIG_DIR}/bin/nvm.img}"
    if [[ ! -f "$nvm_img" ]]; then
        print_warning "microVM: NVM block image not found: ${nvm_img}"
        print_warning "microVM: Node.js and claude binary unavailable in guest — run --install-microvm"
        nvm_img=""
    fi

    # Workspace image: per-session sparse ext4, populated via SSH rsync after boot
    local ws_img="${session_dir}/workspace.img"
    MICRO_VM_WORKSPACE_IMG="$ws_img"
    export MICRO_VM_WORKSPACE_IMG

    # ── Resolve workspace mode ─────────────────────────────────────────────────
    #   full     (default) — sync MICRO_VM_WORKSPACE_PATH (or $PWD) to guest /workspace rw;
    #                        sync back on exit. MICRO_VM_WORKSPACE_PATH overrides $PWD as source.
    #   isolated           — guest /workspace starts empty; no sync; files on host untouched.
    local workspace_mode="${MICRO_VM_WORKSPACE_MODE:-full}"
    MICRO_VM_ISOLATED_TMPDIR=""   # reset before case (avoid stale value from previous run)
    case "$workspace_mode" in
        full)
            # MICRO_VM_WORKSPACE_PATH overrides $PWD as workspace source when set.
            MICRO_VM_WORKSPACE_HOSTDIR="${MICRO_VM_WORKSPACE_PATH:-$PWD}"
            if [[ -n "${MICRO_VM_WORKSPACE_PATH:-}" && ! -d "$MICRO_VM_WORKSPACE_PATH" ]]; then
                print_error "microVM: MICRO_VM_WORKSPACE_PATH does not exist: ${MICRO_VM_WORKSPACE_PATH}"
                rm -rf "$session_dir" 2>/dev/null; return 1
            fi
            ;;
        path)
            # Deprecated: 'path' mode was removed. Treating as 'full' with MICRO_VM_WORKSPACE_PATH.
            print_warning "microVM: MICRO_VM_WORKSPACE_MODE='path' is deprecated — use 'full' with MICRO_VM_WORKSPACE_PATH"
            workspace_mode="full"
            MICRO_VM_WORKSPACE_HOSTDIR="${MICRO_VM_WORKSPACE_PATH:-$PWD}"
            if [[ -n "${MICRO_VM_WORKSPACE_PATH:-}" && ! -d "$MICRO_VM_WORKSPACE_PATH" ]]; then
                print_error "microVM: MICRO_VM_WORKSPACE_PATH does not exist: ${MICRO_VM_WORKSPACE_PATH}"
                rm -rf "$session_dir" 2>/dev/null; return 1
            fi
            ;;
        isolated)
            # One-way copy: host→guest at startup; no sync-back. Host files remain unchanged.
            MICRO_VM_WORKSPACE_HOSTDIR="${MICRO_VM_WORKSPACE_PATH:-$PWD}"
            if [[ -n "${MICRO_VM_WORKSPACE_PATH:-}" && ! -d "$MICRO_VM_WORKSPACE_PATH" ]]; then
                print_error "microVM: MICRO_VM_WORKSPACE_PATH does not exist: ${MICRO_VM_WORKSPACE_PATH}"
                rm -rf "$session_dir" 2>/dev/null; return 1
            fi
            ;;
        *)
            print_warning "microVM: unknown MICRO_VM_WORKSPACE_MODE='$workspace_mode' — using 'full'"
            workspace_mode="full"
            MICRO_VM_WORKSPACE_HOSTDIR="${MICRO_VM_WORKSPACE_PATH:-$PWD}"
            ;;
    esac
    export MICRO_VM_WORKSPACE_HOSTDIR MICRO_VM_ISOLATED_TMPDIR

    # ── Create sparse workspace ext4 image ────────────────────────────────────
    # Content populated via SSH rsync after boot; sparse → minimal host disk usage.
    local ws_size_mb="${MICRO_VM_WORKSPACE_SIZE_MB:-2048}"
    _create_workspace_image "$ws_img" "$ws_size_mb" "$session_dir" || {
        MICRO_VM_ROOTFS_PATH="$_rootfs_path_orig"
        return 1
    }

    # Write guest environment file (pushed to guest via SCP after SSH is ready)
    local env_file="${session_dir}/guest-env.sh"
    configure_guest_environment "$env_file"

    # Build Firecracker config with block device images
    local vmconfig
    vmconfig=$(build_microvm_config "$session_dir" "$nvm_img" "$ws_img") || {
        print_error "microVM: failed to generate vmconfig.json"
        rm -rf "$session_dir" 2>/dev/null || true
        MICRO_VM_ROOTFS_PATH="$_rootfs_path_orig"
        return 1
    }
    # Restore original MICRO_VM_ROOTFS_PATH (per-session copy is baked into vmconfig.json)
    MICRO_VM_ROOTFS_PATH="$_rootfs_path_orig"

    print_info "microVM: starting Firecracker VMM..."
    print_info "microVM: vCPU=${MICRO_VM_VCPU:-2} RAM=${MICRO_VM_MEM_MB:-1024}MiB"

    # Remove stale API socket if left over from a previous crashed run
    rm -f "$MICRO_VM_SOCKET" 2>/dev/null || true

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
    _claim_microvm_slot   # write slot-N.lock with FC PID

    _wait_firecracker_socket "$MICRO_VM_PID" "$MICRO_VM_SOCKET" "$session_dir" || return 1

    # ── Poll SSH connectivity ──────────────────────────────────────────────────
    # authorized_keys is baked into rootfs at install time (no per-session injection).
    # Guest init boots fast (~1s), mounts block devices, starts sshd.
    local guest_ip="${MICRO_VM_NET_GUEST_IP:-172.16.0.2}"
    local ssh_key="${ISOLATED_CONFIG_DIR}/ssh/microvm"

    if [[ ! -f "$ssh_key" ]]; then
        print_error "microVM: SSH private key not found: ${ssh_key}"
        print_info "Run: ./iclaude.sh --install-microvm  (generates and bakes the key)"
        kill "$MICRO_VM_PID" 2>/dev/null || true
        rm -rf "$session_dir" 2>/dev/null; return 1
    fi

    # Build per-session known_hosts BEFORE the readiness poll so that host key
    # verification is active from the very first SSH connection (no TOFU window).
    # Host pubkey is extracted from rootfs at install time by _inject_rootfs_guest_init().
    local host_key_pub="${ISOLATED_CONFIG_DIR}/ssh/microvm_host_key.pub"
    local known_hosts_file="${session_dir}/known_hosts"
    local _ssh_kh_opts=("-o" "StrictHostKeyChecking=no" "-o" "UserKnownHostsFile=/dev/null")
    if [[ -f "$host_key_pub" ]]; then
        { printf '%s ' "$guest_ip"; cat "$host_key_pub"; } > "$known_hosts_file"
        chmod 600 "$known_hosts_file"
        export MICRO_VM_KNOWN_HOSTS="$known_hosts_file"
        _ssh_kh_opts=("-o" "StrictHostKeyChecking=yes" "-o" "UserKnownHostsFile=${known_hosts_file}")
        print_info "microVM: SSH host key pinned (${known_hosts_file})"
    else
        print_warning "microVM: host key not found (${host_key_pub}) — falling back to StrictHostKeyChecking=no (TOFU). Run --install-microvm to pin the host key."
    fi

    local ssh_ticks
    ssh_ticks=$(_poll_guest_ssh "$guest_ip" "$ssh_key" "$MICRO_VM_PID" "$session_dir" "${_ssh_kh_opts[@]}") || return 1
    print_info "microVM: guest SSH ready (${ssh_ticks}× 0.5s)"

    # Push guest environment file to /workspace via SCP (iclaude user, workspace is chowned to it).
    # -q: suppress progress output — SCP progress manipulates the terminal and can corrupt stty
    # settings before the subsequent interactive SSH session (causing Enter to stop working).
    # </dev/null: prevent SCP from reading stdin and consuming terminal keystrokes.
    scp -q \
        -i "$ssh_key" \
        "${_ssh_kh_opts[@]}" \
        -o LogLevel=ERROR \
        "$env_file" "iclaude@${guest_ip}:/workspace/.iclaude-guest-env.sh" \
        </dev/null 2>/dev/null || \
        print_warning "microVM: could not push guest env — guest may start without proxy/API config"

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

    # Graceful guest filesystem sync before FC process termination.
    # SSH into guest: sync flushes kernel I/O buffers; remount,ro marks ext4 superblock
    # clean (clears the "needs journal recovery" flag); kill -TERM 1 triggers the guest
    # init's SIGTERM handler which performs a final sync and exits PID 1 cleanly.
    # This prevents rootfs dirty-state corruption on the next debugfs -w injection.
    # Failures are non-fatal — SIGTERM/SIGKILL to FC below remains the fallback.
    if [[ "${MICRO_VM_SESSION_OWNED:-false}" == "true" ]] && \
       [[ -n "${MICRO_VM_PID:-}" ]] && kill -0 "${MICRO_VM_PID}" 2>/dev/null && \
       [[ -n "${MICRO_VM_NET_GUEST_IP:-}" ]] && [[ -n "${ISOLATED_CONFIG_DIR:-}" ]]; then
        local _stop_ssh_key="${ISOLATED_CONFIG_DIR}/ssh/microvm"
        if [[ -f "$_stop_ssh_key" ]]; then
            ssh -o BatchMode=yes -o ConnectTimeout=2 -o StrictHostKeyChecking=no \
                -o IdentityFile="$_stop_ssh_key" -o IdentitiesOnly=yes \
                iclaude@"${MICRO_VM_NET_GUEST_IP}" \
                'sync && mount -o remount,ro / 2>/dev/null; sudo kill -TERM 1 2>/dev/null' \
                &>/dev/null 2>&1 || true
            # Wait for FC to exit after guest PID 1 terminates (kernel panic → FC exits)
            local _grace=0
            while kill -0 "${MICRO_VM_PID}" 2>/dev/null && [[ $_grace -lt 30 ]]; do
                sleep 0.1
                _grace=$((_grace + 1))
            done
        fi
    fi

    # Stop Firecracker VMM (fallback if graceful shutdown above did not terminate FC)
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

    # Remove per-session work dir (contains workspace.img, guest-env.sh, vmconfig.json, fc log)
    local session_id="${ICLAUDE_SESSION_ID:-$$}"
    local session_dir="${MICRO_VM_WORK_DIR:-${ISOLATED_CONFIG_DIR}/microvm-run}/${session_id}"
    rm -rf "$session_dir" 2>/dev/null || true
    MICRO_VM_WORKSPACE_IMG=""

    # Remove Firecracker API socket (in /tmp for short path)
    rm -f "/tmp/iclaude-${session_id}-fc.sock" 2>/dev/null || true

    # Remove /32 host route for the guest IP (added at slot allocation for multi-VM routing).
    if [[ -n "${MICRO_VM_NET_GUEST_IP:-}" ]] && [[ -n "${MICRO_VM_NET_TAP_IFACE:-}" ]] && \
       sudo -n true 2>/dev/null; then
        sudo ip route del "${MICRO_VM_NET_GUEST_IP}/32" dev "${MICRO_VM_NET_TAP_IFACE}" 2>/dev/null || true
    fi

    # Release network slot so it can be reused by another session
    _free_microvm_slot
    MICRO_VM_SLOT=""

    # Clear workspace tracking vars
    MICRO_VM_WORKSPACE_HOSTDIR=""
    MICRO_VM_ISOLATED_TMPDIR=""
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

#######################################
# Clean up orphaned microVM artifacts from sessions that exited without cleanup
# (e.g. SIGKILL, host reboot). Removes stale FC sockets and session directories.
# Safe to call at launch time — only removes artifacts with no live owner process.
#######################################
cleanup_orphaned_microvm_sessions() {
    local cleaned=0

    # Remove stale Firecracker API sockets in /tmp.
    # Requires fuser (psmisc). Skip socket cleanup if unavailable — better to leave
    # stale sockets than to delete sockets of live processes.
    local sock session_id
    if command -v fuser &>/dev/null; then
        for sock in /tmp/iclaude-*-fc.sock; do
            [[ -S "$sock" ]] || continue
            # fuser returns non-zero when no process holds the socket
            if ! fuser "$sock" &>/dev/null 2>&1; then
                rm -f "$sock" 2>/dev/null || true
                cleaned=$((cleaned + 1))
            fi
        done
    fi

    # Remove stale session directories in microvm-run/
    local run_dir="${ISOLATED_CONFIG_DIR}/microvm-run"
    if [[ -d "$run_dir" ]]; then
        local dir slot_lock
        for dir in "$run_dir"/*/; do
            [[ -d "$dir" ]] || continue
            session_id="${dir%/}"; session_id="${session_id##*/}"
            # Check matching slot lock — if the lock file references a dead PID, it's orphaned.
            # Use --fixed-strings to prevent session_id from being interpreted as a regex pattern.
            slot_lock=$(grep -rlF "$session_id" "${ISOLATED_CONFIG_DIR}/microvm-slots/" 2>/dev/null | head -1 || true)
            # Session is orphaned if: no FC socket exists for it AND no slot lock references it
            if [[ ! -S "/tmp/iclaude-${session_id}-fc.sock" ]] && [[ -z "$slot_lock" ]]; then
                rm -rf "$dir" 2>/dev/null || true
                cleaned=$((cleaned + 1))
            fi
        done
    fi

    if [[ $cleaned -gt 0 ]]; then
        print_info "microVM: cleaned ${cleaned} orphaned session artifact(s)"
    fi
    return 0
}
