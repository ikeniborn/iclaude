#!/usr/bin/env bash
# tests/test-microvm-dual.sh
#
# Integration test: Two concurrent microVM sessions (full + isolated modes)
#
# Tests:
#   1. Concurrent startup — two VMs on different slots/IPs simultaneously
#   2. Full-mode workspace — host→guest sync, exclusions, guest→host sync-back
#   3. Isolated-mode workspace — no host files, no sync-back
#   4. NVM & claude binary — node + claude accessible in both VMs via env file
#   5. Process termination — FC process dies, slot released, session dir removed
#   6. Isolation of termination — killing VM-A does not affect VM-B
#
# Requirements: /dev/kvm, firecracker, rootfs.ext4, nvm.img, vmlinux, sudo (TAP creation)
# Usage: bash tests/test-microvm-dual.sh [--verbose]

set -uo pipefail

VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

# ── helpers ────────────────────────────────────────────────────────────────────

PASS=0; FAIL=0
_pass()    { echo "  ✓  $1"; PASS=$((PASS+1)); }
_fail()    { echo "  ✗  FAIL: $1"; FAIL=$((FAIL+1)); }
_section() { echo ""; echo "── $1"; }
_vlog()    { [[ "$VERBOSE" == "true" ]] && echo "     [dbg] $*" || true; }
_skip()    { echo "  ·  SKIP: $1"; }

# ── environment bootstrap ──────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_DIR"

# Silence iclaude logging functions (we provide our own output)
print_info()    { _vlog "iclaude: $*"; }
print_success() { _vlog "iclaude: $*"; }
print_warning() { echo "  [warn] $*"; }
print_error()   { echo "  [ERR]  $*"; }

# Bootstrap iclaude environment (same sequence as iclaude.sh)
SCRIPT_DIR="$PROJECT_DIR"   # init_environment uses SCRIPT_DIR to derive ISOLATED_NVM_DIR
source "${PROJECT_DIR}/lib/core/init.sh"
source "${PROJECT_DIR}/lib/core/logging.sh"
source "${PROJECT_DIR}/lib/core/json.sh"
init_environment
# Re-pin paths (init_environment resolves relative to caller's SCRIPT_DIR)
ISOLATED_NVM_DIR="${PROJECT_DIR}/.nvm-isolated"
ISOLATED_CONFIG_DIR="${PROJECT_DIR}/.claude-isolated"
export ISOLATED_NVM_DIR ISOLATED_CONFIG_DIR
# Pick up user overrides (MICRO_VM_NET_SUBNET, etc.) without crashing on unbound vars
set +u
[[ -f "${PROJECT_DIR}/.claude_config" ]] && source "${PROJECT_DIR}/.claude_config" 2>/dev/null || true
set -u
source "${PROJECT_DIR}/lib/sandbox/microvm.sh"
source "${PROJECT_DIR}/lib/core/validation.sh" 2>/dev/null || true

# ── per-test state for two VMs ─────────────────────────────────────────────────

# Each VM gets its own work dir and state variables.
# Global microvm.sh variables are swapped in when operating on a specific VM.

VM_A_WORK=""    # populated after _start_one_vm A
VM_B_WORK=""
VM_A_PID=""
VM_B_PID=""
VM_A_SLOT=""
VM_B_SLOT=""
VM_A_IP=""
VM_B_IP=""
VM_A_HOST_IP=""
VM_B_HOST_IP=""
VM_A_TAP=""
VM_B_TAP=""
VM_A_SOCK=""
VM_B_SOCK=""
VM_A_SESSION=""
VM_B_SESSION=""

SSH_KEY="${ISOLATED_CONFIG_DIR}/ssh/microvm"
HOST_KEY_PUB="${ISOLATED_CONFIG_DIR}/ssh/microvm_host_key.pub"
FC_BIN="${ISOLATED_CONFIG_DIR}/bin/firecracker"
ROOTFS_BASE="${ISOLATED_CONFIG_DIR}/bin/rootfs.ext4"
NVM_IMG="${ISOLATED_CONFIG_DIR}/bin/nvm.img"
VMLINUX="${ISOLATED_CONFIG_DIR}/bin/vmlinux"

# ── global cleanup trap ────────────────────────────────────────────────────────

_cleanup_all() {
    local exit_code=$?
    # Kill both VMs if still running
    for _pid in "$VM_A_PID" "$VM_B_PID"; do
        [[ -z "$_pid" ]] && continue
        kill "$_pid" 2>/dev/null || true
        sleep 0.3
        kill -9 "$_pid" 2>/dev/null || true
    done
    # Remove /32 host routes for guest IPs
    [[ -n "${VM_A_IP:-}" ]] && [[ -n "${VM_A_TAP:-}" ]] && \
        sudo ip route del "${VM_A_IP}/32" dev "$VM_A_TAP" 2>/dev/null || true
    [[ -n "${VM_B_IP:-}" ]] && [[ -n "${VM_B_TAP:-}" ]] && \
        sudo ip route del "${VM_B_IP}/32" dev "$VM_B_TAP" 2>/dev/null || true
    # Release slots
    for _slot in "$VM_A_SLOT" "$VM_B_SLOT"; do
        [[ -z "$_slot" ]] && continue
        MICRO_VM_SLOT="$_slot"
        _free_microvm_slot 2>/dev/null || true
    done
    # Remove work dirs
    [[ -n "$VM_A_WORK" ]] && rm -rf "$VM_A_WORK" 2>/dev/null || true
    [[ -n "$VM_B_WORK" ]] && rm -rf "$VM_B_WORK" 2>/dev/null || true
    # Remove temp test files from project root
    rm -f "${PROJECT_DIR}/.iclaude-test-"* 2>/dev/null || true
    # Remove second TAP if we created it
    if [[ -n "${VM_B_TAP:-}" ]] && [[ "${_test_created_tap_b:-false}" == "true" ]]; then
        sudo ip link del "$VM_B_TAP" 2>/dev/null || true
    fi
    return $exit_code
}
trap _cleanup_all EXIT INT TERM
_test_created_tap_b=false

# ── SSH helper ─────────────────────────────────────────────────────────────────

# ssh_vm <guest_ip> <known_hosts_file|""> <command...>
ssh_vm() {
    local guest_ip="$1"; shift
    local kh_file="$1"; shift
    local kh_opts=("-o" "StrictHostKeyChecking=no" "-o" "UserKnownHostsFile=/dev/null")
    if [[ -n "$kh_file" && -f "$kh_file" ]]; then
        kh_opts=("-o" "StrictHostKeyChecking=yes" "-o" "UserKnownHostsFile=${kh_file}")
    fi
    ssh -T -i "$SSH_KEY" "${kh_opts[@]}" \
        -o ConnectTimeout=5 -o BatchMode=yes -o LogLevel=ERROR \
        "iclaude@${guest_ip}" "$@"
}

# ── VM start helper ────────────────────────────────────────────────────────────

# _start_one_vm <label> <slot>
# Allocates slot, creates workspace.img, starts FC, waits for SSH.
# Sets VM_<label>_* variables.
_start_one_vm() {
    local label="$1"
    local target_slot="${2:-}"

    # Allocate slot (fills MICRO_VM_SLOT, MICRO_VM_NET_* globals)
    # If target_slot set, pre-set it so _alloc can pick it
    if ! _alloc_microvm_slot 2>/dev/null; then
        echo "  [ERR] Cannot allocate slot for VM-${label}"
        return 1
    fi

    local slot="$MICRO_VM_SLOT"
    local guest_ip="$MICRO_VM_NET_GUEST_IP"
    local host_ip="$MICRO_VM_NET_HOST_IP"
    local mask="$MICRO_VM_NET_MASK"
    local tap="$MICRO_VM_NET_TAP_IFACE"

    # Ensure TAP for this slot exists (slot 0 exists; slot 1+ may need creating)
    if ! ip link show "$tap" &>/dev/null; then
        if ! sudo -n true 2>/dev/null; then
            echo "  [ERR] TAP ${tap} missing and sudo unavailable — run --install-microvm first"
            _free_microvm_slot 2>/dev/null
            return 1
        fi
        local prefix="${MICROVM_SUBNET_PREFIX:-26}"
        sudo ip tuntap add dev "$tap" mode tap 2>/dev/null && \
        sudo ip addr add "${host_ip}/${prefix}" dev "$tap" 2>/dev/null && \
        sudo ip link set "$tap" up 2>/dev/null || {
            echo "  [ERR] Failed to create TAP ${tap}"
            _free_microvm_slot 2>/dev/null
            return 1
        }
        _test_created_tap_b=true
        _vlog "TAP ${tap} created for slot ${slot}"
    fi

    # Verify TAP has the expected host IP
    if ! ip addr show "$tap" 2>/dev/null | grep -q "${host_ip}/"; then
        echo "  [ERR] TAP ${tap} exists but missing IP ${host_ip}"
        _free_microvm_slot 2>/dev/null
        return 1
    fi

    # Add /32 host route for guest IP via this TAP.
    # Without this, all slots in the same /26 subnet share one subnet route and
    # Linux picks the first TAP for all guest IPs — packets to VM-B land on VM-A.
    if sudo -n true 2>/dev/null; then
        sudo ip route replace "${guest_ip}/32" dev "$tap" 2>/dev/null || true
        _vlog "Host route added: ${guest_ip}/32 dev ${tap}"
    fi

    # Per-session work directory
    local session_id; session_id=$(od -An -N6 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')
    local work_dir="${ISOLATED_CONFIG_DIR}/microvm-run/${session_id}"
    mkdir -p "$work_dir"
    chmod 700 "$work_dir"

    # Per-session sparse rootfs copy (FC opens it read-write; shared base stays clean)
    local rootfs_session="${work_dir}/rootfs.ext4"
    if ! cp --sparse=always "$ROOTFS_BASE" "$rootfs_session" 2>/dev/null; then
        echo "  [ERR] Failed to copy rootfs for VM-${label}"
        _free_microvm_slot 2>/dev/null; rm -rf "$work_dir"
        return 1
    fi

    # Sparse workspace image
    local ws_img="${work_dir}/workspace.img"
    dd if=/dev/zero of="$ws_img" bs=1M count=0 seek=512 2>/dev/null
    mkfs.ext4 -q -F "$ws_img" 2>/dev/null

    # known_hosts (strict host key pinning)
    local kh_file=""
    if [[ -f "$HOST_KEY_PUB" ]]; then
        kh_file="${work_dir}/known_hosts"
        { printf '%s ' "$guest_ip"; cat "$HOST_KEY_PUB"; } > "$kh_file"
        chmod 600 "$kh_file"
    fi

    # vmconfig.json
    local mac; printf -v mac 'AA:FC:00:00:00:%02X' $((slot + 1))
    local boot_args="console=ttyS0 reboot=k panic=1 pci=off nomodules"
    boot_args="${boot_args} ip=${guest_ip}::${host_ip}:${mask}::eth0:off"
    boot_args="${boot_args} init=/usr/sbin/iclaude-guest-init"

    local sock="/tmp/iclaude-${session_id}-fc.sock"
    local fc_log="${work_dir}/firecracker.log"
    touch "$fc_log"

    cat > "${work_dir}/vmconfig.json" <<VMEOF
{
  "boot-source": {"kernel_image_path": "${VMLINUX}", "boot_args": "${boot_args}"},
  "drives": [
    {"drive_id":"rootfs",    "path_on_host":"${rootfs_session}", "is_root_device":true,  "is_read_only":false},
    {"drive_id":"nvm",       "path_on_host":"${NVM_IMG}",        "is_root_device":false, "is_read_only":true},
    {"drive_id":"workspace", "path_on_host":"${ws_img}",         "is_root_device":false, "is_read_only":false}
  ],
  "machine-config": {"vcpu_count":1, "mem_size_mib":512},
  "network-interfaces": [{"iface_id":"eth0", "guest_mac":"${mac}", "host_dev_name":"${tap}"}]
}
VMEOF

    # Launch Firecracker
    rm -f "$sock" 2>/dev/null || true
    "$FC_BIN" --api-sock "$sock" --config-file "${work_dir}/vmconfig.json" \
        --log-path "$fc_log" --level Warn &>/dev/null &
    local fc_pid=$!

    # Update slot lock with real PID
    local slots_dir="${ISOLATED_CONFIG_DIR}/microvm-slots"
    mkdir -p "$slots_dir"
    echo "$fc_pid" > "${slots_dir}/slot-${slot}.lock"

    # Save state
    eval "VM_${label}_PID=${fc_pid}"
    eval "VM_${label}_SLOT=${slot}"
    eval "VM_${label}_IP=${guest_ip}"
    eval "VM_${label}_HOST_IP=${host_ip}"
    eval "VM_${label}_TAP=${tap}"
    eval "VM_${label}_SOCK=${sock}"
    eval "VM_${label}_WORK=${work_dir}"
    eval "VM_${label}_SESSION=${session_id}"
    eval "VM_${label}_KH=${kh_file}"

    _vlog "VM-${label} FC PID=${fc_pid} slot=${slot} guest=${guest_ip} sock=${sock}"

    # Wait for FC API socket
    local t=0
    while [[ $t -lt 40 ]]; do
        [[ -S "$sock" ]] && break
        if ! kill -0 "$fc_pid" 2>/dev/null; then
            echo "  [ERR] VM-${label} Firecracker exited: $(tail -3 "$fc_log" 2>/dev/null)"
            _free_microvm_slot 2>/dev/null; rm -rf "$work_dir"
            return 1
        fi
        sleep 0.25; t=$((t+1))
    done
    [[ -S "$sock" ]] || { echo "  [ERR] VM-${label} FC socket timeout"; return 1; }

    # Wait for SSH (max 30s)
    local ssh_ok=false
    for t in $(seq 1 60); do
        ssh_vm "$guest_ip" "$kh_file" 'exit 0' 2>/dev/null && ssh_ok=true && break
        kill -0 "$fc_pid" 2>/dev/null || { echo "  [ERR] VM-${label} FC crashed waiting SSH"; return 1; }
        sleep 0.5
    done
    [[ "$ssh_ok" == "true" ]] || { echo "  [ERR] VM-${label} SSH timeout"; return 1; }
    return 0
}

# Stop one VM by label and return its exit artifacts for verification
_stop_one_vm() {
    local label="$1"
    local pid;       eval "pid=\${VM_${label}_PID}"
    local slot;      eval "slot=\${VM_${label}_SLOT}"
    local sock;      eval "sock=\${VM_${label}_SOCK}"
    local work;      eval "work=\${VM_${label}_WORK}"
    local session;   eval "session=\${VM_${label}_SESSION}"
    local guest_ip;  eval "guest_ip=\${VM_${label}_IP:-}"
    local tap;       eval "tap=\${VM_${label}_TAP:-}"

    [[ -z "$pid" ]] && return 0

    kill "$pid" 2>/dev/null || true
    local waited=0
    while kill -0 "$pid" 2>/dev/null && [[ $waited -lt 30 ]]; do
        sleep 0.1; waited=$((waited+1))
    done
    kill -9 "$pid" 2>/dev/null || true

    # Remove /32 host route for this VM's guest IP
    if [[ -n "$guest_ip" ]] && [[ -n "$tap" ]] && sudo -n true 2>/dev/null; then
        sudo ip route del "${guest_ip}/32" dev "$tap" 2>/dev/null || true
    fi

    MICRO_VM_SLOT="$slot"
    _free_microvm_slot 2>/dev/null || true

    rm -rf "$work" 2>/dev/null || true
    rm -f "$sock" 2>/dev/null || true

    eval "VM_${label}_PID=''"
    eval "VM_${label}_SLOT=''"
}

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "  microVM dual-session integration test"
echo "══════════════════════════════════════════════════════"

# ── 1. Pre-flight ──────────────────────────────────────────────────────────────
_section "1. Pre-flight checks"

[[ -r /dev/kvm ]]         && _pass "/dev/kvm accessible"        || { _fail "/dev/kvm not readable"; exit 1; }
[[ -x "$FC_BIN" ]]        && _pass "firecracker binary"         || { _fail "firecracker not found: $FC_BIN"; exit 1; }
[[ -f "$SSH_KEY" ]]       && _pass "SSH private key"            || { _fail "SSH key missing: $SSH_KEY"; exit 1; }
[[ -f "$ROOTFS_BASE" ]]   && _pass "rootfs.ext4"                || { _fail "rootfs missing: $ROOTFS_BASE"; exit 1; }
[[ -f "$NVM_IMG" ]]       && _pass "nvm.img"                    || { _fail "nvm.img missing: $NVM_IMG"; exit 1; }
[[ -f "$VMLINUX" ]]       && _pass "vmlinux"                    || { _fail "vmlinux missing: $VMLINUX"; exit 1; }
_rootfs_state_val=$(cat "${ISOLATED_CONFIG_DIR}/bin/rootfs.state" 2>/dev/null || echo "")
[[ -n "$_rootfs_state_val" ]] \
    && _pass "rootfs state marker (${_rootfs_state_val})"       || { _fail "rootfs state unknown — run --install-microvm"; exit 1; }

# Verify slot-0 TAP exists. MICRO_VM_NET_TAP_IFACE is now a prefix; slot 0 → prefix-1.
SUBNET="${MICRO_VM_NET_SUBNET:-172.16.0.0/26}"
_microvm_parse_subnet "$SUBNET" 2>/dev/null
SLOT0_HOST_IP="$(_microvm_ip_at 1 2>/dev/null)"
_TAP_PREFIX="${MICRO_VM_NET_TAP_IFACE:-tap-iclaude}"
SLOT0_TAP="${_TAP_PREFIX}-1"
ip link show "$SLOT0_TAP" &>/dev/null \
    && _pass "TAP ${SLOT0_TAP} exists" \
    || { _fail "TAP ${SLOT0_TAP} missing — run: ./iclaude.sh --install-microvm"; exit 1; }
ip addr show "$SLOT0_TAP" 2>/dev/null | grep -q "${SLOT0_HOST_IP}/" \
    && _pass "TAP ${SLOT0_TAP} has host IP ${SLOT0_HOST_IP}" \
    || { _fail "TAP ${SLOT0_TAP} missing IP ${SLOT0_HOST_IP}"; exit 1; }

# ── 2. Concurrent startup ──────────────────────────────────────────────────────
_section "2. Concurrent startup — VM-A (full) and VM-B (isolated)"

echo "  Starting VM-A..."
if ! _start_one_vm A; then
    _fail "VM-A failed to start"; exit 1
fi
_pass "VM-A started: slot=${VM_A_SLOT} guest=${VM_A_IP} PID=${VM_A_PID}"

echo "  Starting VM-B..."
if ! _start_one_vm B; then
    _fail "VM-B failed to start (slot allocation or SSH timeout)"
    # Don't exit — still run cleanup and partial results
fi
if [[ -n "$VM_B_PID" ]]; then
    _pass "VM-B started: slot=${VM_B_SLOT} guest=${VM_B_IP} PID=${VM_B_PID}"
fi

# Verify different slots and IPs
if [[ -n "$VM_B_PID" ]]; then
    [[ "$VM_A_SLOT" != "$VM_B_SLOT" ]] \
        && _pass "Different slots: VM-A=${VM_A_SLOT}, VM-B=${VM_B_SLOT}" \
        || _fail "VMs share same slot ${VM_A_SLOT} — concurrent isolation broken"

    [[ "$VM_A_IP" != "$VM_B_IP" ]] \
        && _pass "Different IPs: VM-A=${VM_A_IP}, VM-B=${VM_B_IP}" \
        || _fail "VMs share same guest IP ${VM_A_IP}"

    [[ "$VM_A_TAP" != "$VM_B_TAP" ]] \
        && _pass "Different TAPs: VM-A=${VM_A_TAP}, VM-B=${VM_B_TAP}" \
        || _fail "VMs share same TAP ${VM_A_TAP}"
fi

# Verify slot lock files exist for both
SLOTS_DIR="${ISOLATED_CONFIG_DIR}/microvm-slots"
[[ -f "${SLOTS_DIR}/slot-${VM_A_SLOT}.lock" ]] \
    && _pass "Slot-${VM_A_SLOT} lock file exists" \
    || _fail "Slot-${VM_A_SLOT} lock file missing"
if [[ -n "$VM_B_PID" ]]; then
    [[ -f "${SLOTS_DIR}/slot-${VM_B_SLOT}.lock" ]] \
        && _pass "Slot-${VM_B_SLOT} lock file exists" \
        || _fail "Slot-${VM_B_SLOT} lock file missing"
fi

# Both VMs respond to SSH simultaneously
if [[ -n "$VM_B_PID" ]]; then
    echo "  Concurrent SSH ping (both VMs simultaneously)..."
    _kh_a=""; eval "_kh_a=\${VM_A_KH:-}"
    _kh_b=""; eval "_kh_b=\${VM_B_KH:-}"

    RES_A=$(ssh_vm "$VM_A_IP" "$_kh_a" 'echo "pong-A"' 2>/dev/null) &
    PID_SSH_A=$!
    RES_B=$(ssh_vm "$VM_B_IP" "$_kh_b" 'echo "pong-B"' 2>/dev/null) &
    PID_SSH_B=$!
    wait $PID_SSH_A 2>/dev/null
    wait $PID_SSH_B 2>/dev/null

    # Re-run synchronously to capture output (background can't capture easily)
    RES_A=$(ssh_vm "$VM_A_IP" "$_kh_a" 'echo "pong-A"' 2>/dev/null || echo "")
    RES_B=$(ssh_vm "$VM_B_IP" "$_kh_b" 'echo "pong-B"' 2>/dev/null || echo "")

    [[ "$RES_A" == "pong-A" ]] && _pass "VM-A responds to SSH" || _fail "VM-A SSH no response"
    [[ "$RES_B" == "pong-B" ]] && _pass "VM-B responds to SSH" || _fail "VM-B SSH no response"
fi

# ── 3. Full-mode workspace (VM-A) ──────────────────────────────────────────────
_section "3. Full-mode workspace (VM-A — bidirectional sync)"

_kh_a=""; eval "_kh_a=\${VM_A_KH:-}"

# 3a. host → guest sync
FULL_HOST_MARKER=".iclaude-test-full-$$"
echo "host-file-$$" > "${PROJECT_DIR}/${FULL_HOST_MARKER}"
_vlog "Created host marker: ${PROJECT_DIR}/${FULL_HOST_MARKER}"

SYNC_EXCLUDES=(
    "--exclude=./.nvm-isolated" "--exclude=./.git"
    "--exclude=./.claude_config" "--exclude=./.claude_proxy_credentials"
    "--exclude=./.iclaude-guest-env.sh" "--exclude=./.iclaude-ssh"
)

ssh_vm "$VM_A_IP" "$_kh_a" 'rm -rf /workspace/* /workspace/.[!.]* 2>/dev/null; true' 2>/dev/null || true

tar -czf - -C "$PROJECT_DIR" "${SYNC_EXCLUDES[@]}" . 2>/dev/null \
    | ssh_vm "$VM_A_IP" "$_kh_a" 'tar -xzf - -C /workspace 2>/dev/null' 2>/dev/null \
    && _pass "full: host→guest tar sync completed" \
    || _fail "full: host→guest tar sync failed"

# Verify host marker visible in guest
ssh_vm "$VM_A_IP" "$_kh_a" "test -f /workspace/${FULL_HOST_MARKER}" 2>/dev/null \
    && _pass "full: host file visible in guest (/workspace/${FULL_HOST_MARKER})" \
    || _fail "full: host file NOT visible in guest"

# 3b. Excluded files must NOT be in guest
ssh_vm "$VM_A_IP" "$_kh_a" 'test ! -f /workspace/.claude_config' 2>/dev/null \
    && _pass "full: .claude_config excluded (credentials safe)" \
    || _fail "full: .claude_config LEAKED into guest VM!"

ssh_vm "$VM_A_IP" "$_kh_a" 'test ! -d /workspace/.nvm-isolated' 2>/dev/null \
    && _pass "full: .nvm-isolated excluded (NVM via /dev/vdb only)" \
    || _fail "full: .nvm-isolated LEAKED into guest"

ssh_vm "$VM_A_IP" "$_kh_a" 'test ! -d /workspace/.git' 2>/dev/null \
    && _pass "full: .git excluded (large, not needed)" \
    || _fail "full: .git LEAKED into guest"

# 3c. guest → host sync-back
SYNCBACK_MARKER=".iclaude-test-syncback-$$"
ssh_vm "$VM_A_IP" "$_kh_a" "echo 'created-in-guest-$$' > /workspace/${SYNCBACK_MARKER}" 2>/dev/null \
    && _pass "full: file created in guest" \
    || _fail "full: failed to create file in guest"

SYNCBACK_TMP="/tmp/iclaude-test-syncback-$$"
mkdir -p "$SYNCBACK_TMP"
ssh_vm "$VM_A_IP" "$_kh_a" \
    'tar -czf - -C /workspace --exclude=./lost+found --exclude=./.iclaude-guest-env.sh . 2>/dev/null' 2>/dev/null \
    | tar -xzf - -C "$SYNCBACK_TMP" 2>/dev/null \
    && _pass "full: guest→host tar sync-back completed" \
    || _fail "full: guest→host sync-back failed"

[[ -f "${SYNCBACK_TMP}/${SYNCBACK_MARKER}" ]] \
    && _pass "full: guest-created file synced back to host" \
    || _fail "full: guest-created file NOT found in sync-back"

[[ -f "${SYNCBACK_TMP}/${FULL_HOST_MARKER}" ]] \
    && _pass "full: original host file still present in sync-back" \
    || _fail "full: original host file missing from sync-back"

[[ ! -f "${SYNCBACK_TMP}/.iclaude-guest-env.sh" ]] \
    && _pass "full: .iclaude-guest-env.sh excluded from sync-back" \
    || _fail "full: .iclaude-guest-env.sh leaked into sync-back!"

rm -rf "$SYNCBACK_TMP" "${PROJECT_DIR}/${FULL_HOST_MARKER}" 2>/dev/null || true

# ── 4. Isolated-mode workspace (VM-B) ─────────────────────────────────────────
_section "4. Isolated-mode workspace (VM-B — no sync-back)"

if [[ -z "$VM_B_PID" ]]; then
    _skip "VM-B not running — skipping isolated-mode tests"
else
    _kh_b=""; eval "_kh_b=\${VM_B_KH:-}"

    # 4a. Workspace starts empty (no host→guest sync in isolated mode)
    WS_COUNT=$(ssh_vm "$VM_B_IP" "$_kh_b" \
        'find /workspace -mindepth 1 -maxdepth 1 ! -name lost+found 2>/dev/null | wc -l' 2>/dev/null \
        || echo "ERR")
    [[ "$WS_COUNT" == "0" ]] \
        && _pass "isolated: /workspace empty on boot (no host files)" \
        || _fail "isolated: /workspace has ${WS_COUNT} entries — expected 0"

    # 4b. Writing to /workspace works (disk is writable)
    ISOLATED_GUEST_FILE=".iclaude-test-isolated-$$"
    ssh_vm "$VM_B_IP" "$_kh_b" "echo 'isolated-$$' > /workspace/${ISOLATED_GUEST_FILE}" 2>/dev/null \
        && _pass "isolated: write to /workspace succeeds" \
        || _fail "isolated: write to /workspace failed"

    ssh_vm "$VM_B_IP" "$_kh_b" "test -f /workspace/${ISOLATED_GUEST_FILE}" 2>/dev/null \
        && _pass "isolated: file persists in guest /workspace" \
        || _fail "isolated: file not found after write"

    # 4c. File must NOT appear on host (no sync-back was run)
    [[ ! -f "${PROJECT_DIR}/${ISOLATED_GUEST_FILE}" ]] \
        && _pass "isolated: guest file not on host (sync-back not triggered)" \
        || _fail "isolated: guest file LEAKED to host — isolation broken!"

    # 4d. VM-A workspace unchanged (cross-VM isolation)
    NOT_IN_A=$(ssh_vm "$VM_A_IP" "$_kh_a" \
        "test ! -f /workspace/${ISOLATED_GUEST_FILE} && echo ok" 2>/dev/null || echo "")
    [[ "$NOT_IN_A" == "ok" ]] \
        && _pass "isolated: VM-B file not visible in VM-A (cross-VM isolation)" \
        || _fail "isolated: VM-B file LEAKED into VM-A workspace!"
fi

# ── 5. NVM & claude binary ─────────────────────────────────────────────────────
_section "5. NVM and claude binary availability"

# Build guest env file (same as configure_guest_environment does)
ENV_TMP=$(mktemp)
{
    echo "export NVM_DIR='/mnt/nvm'"
    printf 'export PATH="/mnt/nvm/versions/node/$(ls /mnt/nvm/versions/node 2>/dev/null | head -1)/bin:/workspace/node_modules/.bin:${PATH}"\n'
} > "$ENV_TMP"

for _label in A B; do
    eval "_vm_pid=\${VM_${_label}_PID:-}"
    [[ -z "$_vm_pid" ]] && { _skip "VM-${_label} not running — skipping NVM tests"; continue; }
    eval "_vm_ip=\${VM_${_label}_IP}"
    eval "_kh=\${VM_${_label}_KH:-}"

    # Push env file
    _kh_opts=("-o" "StrictHostKeyChecking=no" "-o" "UserKnownHostsFile=/dev/null")
    [[ -n "$_kh" && -f "$_kh" ]] && _kh_opts=("-o" "StrictHostKeyChecking=yes" "-o" "UserKnownHostsFile=${_kh}")
    scp -i "$SSH_KEY" "${_kh_opts[@]}" -o LogLevel=ERROR \
        "$ENV_TMP" "iclaude@${_vm_ip}:/workspace/.iclaude-guest-env.sh" 2>/dev/null \
        || true

    # /mnt/nvm mounted
    ssh_vm "$_vm_ip" "$_kh" 'test -d /mnt/nvm && ls /mnt/nvm 2>/dev/null | grep -q "."' 2>/dev/null \
        && _pass "VM-${_label}: /mnt/nvm mounted (vdb=nvm.img)" \
        || _fail "VM-${_label}: /mnt/nvm not mounted or empty"

    # node binary exists
    NODE_PATH=$(ssh_vm "$_vm_ip" "$_kh" \
        'ls /mnt/nvm/versions/node/*/bin/node 2>/dev/null | head -1' 2>/dev/null || echo "")
    [[ -n "$NODE_PATH" ]] \
        && _pass "VM-${_label}: node binary found: ${NODE_PATH}" \
        || _fail "VM-${_label}: node binary not found in /mnt/nvm/versions/node/"

    # claude binary exists
    ssh_vm "$_vm_ip" "$_kh" 'test -x /mnt/nvm/npm-global/bin/claude' 2>/dev/null \
        && _pass "VM-${_label}: claude binary at /mnt/nvm/npm-global/bin/claude" \
        || _fail "VM-${_label}: claude binary missing"

    # node in PATH via env file, claude --version works
    CLAUDE_VER=$(ssh_vm "$_vm_ip" "$_kh" \
        '. /workspace/.iclaude-guest-env.sh 2>/dev/null; /mnt/nvm/npm-global/bin/claude --version 2>/dev/null' \
        2>/dev/null || echo "")
    [[ -n "$CLAUDE_VER" && "$CLAUDE_VER" == *"Claude Code"* ]] \
        && _pass "VM-${_label}: claude --version = ${CLAUDE_VER}" \
        || _fail "VM-${_label}: claude --version failed (got: '${CLAUDE_VER}')"
done
rm -f "$ENV_TMP" 2>/dev/null || true

# ── 6. Process termination — VM-A ─────────────────────────────────────────────
_section "6. Process termination — kill VM-A, verify VM-B unaffected"

A_PID="$VM_A_PID"
A_SLOT="$VM_A_SLOT"
A_WORK="$VM_A_WORK"
A_SOCK="$VM_A_SOCK"

echo "  Terminating VM-A (PID=${A_PID}, slot=${A_SLOT})..."
_stop_one_vm A

# FC process dead
if ! kill -0 "$A_PID" 2>/dev/null; then
    _pass "VM-A: FC process (PID=${A_PID}) terminated"
else
    _fail "VM-A: FC process (PID=${A_PID}) still running after stop"
fi

# Slot lock released
[[ ! -f "${SLOTS_DIR}/slot-${A_SLOT}.lock" ]] \
    && _pass "VM-A: slot-${A_SLOT} lock released" \
    || _fail "VM-A: slot-${A_SLOT} lock still exists"

# API socket removed
[[ ! -S "$A_SOCK" ]] \
    && _pass "VM-A: FC socket removed" \
    || _fail "VM-A: FC socket still exists: ${A_SOCK}"

# Session work dir cleaned up
[[ ! -d "$A_WORK" ]] \
    && _pass "VM-A: session work dir removed" \
    || _fail "VM-A: session work dir still exists: ${A_WORK}"

# No orphaned workspace images
ORPHAN_IMG="${A_WORK}/workspace.img"
[[ ! -f "$ORPHAN_IMG" ]] \
    && _pass "VM-A: workspace.img cleaned up" \
    || _fail "VM-A: workspace.img still on disk: ${ORPHAN_IMG}"

# VM-B still running (stopping A must not affect B)
if [[ -n "$VM_B_PID" ]]; then
    _kh_b=""; eval "_kh_b=\${VM_B_KH:-}"
    if kill -0 "$VM_B_PID" 2>/dev/null; then
        _pass "VM-B: FC process still running after VM-A stop (PID=${VM_B_PID})"
    else
        _fail "VM-B: FC process died when VM-A was stopped!"
    fi

    # VM-B SSH still works
    RES=$(ssh_vm "$VM_B_IP" "$_kh_b" 'echo alive' 2>/dev/null || echo "")
    [[ "$RES" == "alive" ]] \
        && _pass "VM-B: SSH still responds after VM-A termination" \
        || _fail "VM-B: SSH stopped responding after VM-A termination"

    # VM-B slot lock still present
    [[ -f "${SLOTS_DIR}/slot-${VM_B_SLOT}.lock" ]] \
        && _pass "VM-B: slot-${VM_B_SLOT} lock intact" \
        || _fail "VM-B: slot-${VM_B_SLOT} lock was removed with VM-A!"
fi

# ── 7. Process termination — VM-B ─────────────────────────────────────────────
_section "7. Process termination — kill VM-B, verify full cleanup"

if [[ -z "$VM_B_PID" ]]; then
    _skip "VM-B not running — skipping VM-B cleanup tests"
else
    B_PID="$VM_B_PID"
    B_SLOT="$VM_B_SLOT"
    B_WORK="$VM_B_WORK"
    B_SOCK="$VM_B_SOCK"

    echo "  Terminating VM-B (PID=${B_PID}, slot=${B_SLOT})..."
    _stop_one_vm B

    ! kill -0 "$B_PID" 2>/dev/null \
        && _pass "VM-B: FC process (PID=${B_PID}) terminated" \
        || _fail "VM-B: FC process still running after stop"

    [[ ! -f "${SLOTS_DIR}/slot-${B_SLOT}.lock" ]] \
        && _pass "VM-B: slot-${B_SLOT} lock released" \
        || _fail "VM-B: slot-${B_SLOT} lock still exists"

    [[ ! -S "$B_SOCK" ]] \
        && _pass "VM-B: FC socket removed" \
        || _fail "VM-B: FC socket still exists"

    [[ ! -d "$B_WORK" ]] \
        && _pass "VM-B: session work dir removed" \
        || _fail "VM-B: session work dir still exists: ${B_WORK}"
fi

# ── 8. Global artifact audit ───────────────────────────────────────────────────
_section "8. Global artifact audit — no orphaned microVM resources"

# No test FC processes still running
ORPHAN_FC=$(pgrep -f "firecracker.*iclaude" 2>/dev/null | grep -v "^$$\$" || echo "")
[[ -z "$ORPHAN_FC" ]] \
    && _pass "No orphaned Firecracker processes" \
    || _fail "Orphaned FC processes found: ${ORPHAN_FC}"

# No stale test sockets
STALE_SOCKS=$(ls /tmp/iclaude-*-fc.sock 2>/dev/null || echo "")
[[ -z "$STALE_SOCKS" ]] \
    && _pass "No stale FC sockets in /tmp" \
    || _fail "Stale FC sockets: ${STALE_SOCKS}"

# No stale slot locks for dead processes
STALE_LOCKS=""
for _lf in "${SLOTS_DIR}"/slot-*.lock; do
    [[ -f "$_lf" ]] || continue
    _lf_pid=$(cat "$_lf" 2>/dev/null || echo "")
    if [[ -n "$_lf_pid" ]] && ! kill -0 "$_lf_pid" 2>/dev/null; then
        STALE_LOCKS="${STALE_LOCKS} ${_lf}(PID=${_lf_pid})"
    fi
done
[[ -z "$STALE_LOCKS" ]] \
    && _pass "No stale slot locks for dead processes" \
    || _fail "Stale slot locks (dead PIDs):${STALE_LOCKS}"

# microvm-run dir: no leftover session dirs from this test
MVM_RUN="${ISOLATED_CONFIG_DIR}/microvm-run"
if [[ -d "$MVM_RUN" ]]; then
    LEFTOVER_DIRS=$(ls -1 "$MVM_RUN" 2>/dev/null | wc -l)
    [[ "$LEFTOVER_DIRS" -eq 0 ]] \
        && _pass "microvm-run/ is empty (all session dirs cleaned up)" \
        || { _fail "microvm-run/ has ${LEFTOVER_DIRS} leftover dirs"; ls "$MVM_RUN" 2>/dev/null || true; }
fi

# Test files cleaned from project root
[[ ! -f "${PROJECT_DIR}/${FULL_HOST_MARKER}" ]] \
    && _pass "Host test marker file removed" \
    || _fail "Host test marker file still present: ${PROJECT_DIR}/${FULL_HOST_MARKER}"

# ── summary ────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
printf "  Results: %d passed  %d failed\n" "$PASS" "$FAIL"
echo "══════════════════════════════════════════════════════"
echo ""

[[ $FAIL -eq 0 ]]
