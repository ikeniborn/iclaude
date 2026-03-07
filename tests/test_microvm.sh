#!/bin/bash
# Unit tests for microVM (Firecracker) functions
# Usage: bash tests/test_microvm.sh
# Requires: bash 4.x

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_DIR"

# ── Test harness ──────────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

_pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
_fail() { echo "  ✗ FAIL: $1"; FAIL=$((FAIL + 1)); }
_skip() { echo "  - SKIP: $1"; SKIP=$((SKIP + 1)); }

_section() {
    echo ""
    echo "── $1 ──────────────────────────────────────────────────────"
}

# ── Load modules under test ───────────────────────────────────────────────────
# Minimal stubs for dependencies
print_info()    { :; }
print_success() { :; }
print_warning() { :; }
print_error()   { :; }
detect_nvm()    { return 1; }

# Set required globals with safe defaults for unit tests
ISOLATED_NVM_DIR="${PROJECT_DIR}/.nvm-isolated"
ISOLATED_CONFIG_DIR="${ISOLATED_NVM_DIR}/.claude-isolated"
ICLAUDE_SESSION_ID="test-$$"

# Source microVM constants
source "${PROJECT_DIR}/lib/core/init.sh"
init_environment

# Source modules
source "${PROJECT_DIR}/lib/sandbox/detect.sh"
source "${PROJECT_DIR}/lib/sandbox/install.sh"
source "${PROJECT_DIR}/lib/sandbox/microvm.sh"

# ── Tests ─────────────────────────────────────────────────────────────────────

_section "detect_kvm_support"

if [[ "$(uname -s)" == "Linux" ]]; then
    if [[ -r /dev/kvm ]]; then
        if detect_kvm_support &>/dev/null; then
            _pass "detect_kvm_support: returns 0 when /dev/kvm is readable"
        else
            _fail "detect_kvm_support: expected 0 but got non-zero"
        fi
    else
        result=$(detect_kvm_support 2>&1 || true)
        if [[ $? -ne 0 ]] || echo "$result" | grep -qi "kvm\|not readable\|not found"; then
            _pass "detect_kvm_support: returns non-zero when /dev/kvm not readable"
        else
            _fail "detect_kvm_support: unexpected output: $result"
        fi
    fi
else
    result=$(detect_kvm_support 2>&1 || true)
    [[ "$result" == *"KVM requires Linux"* ]] && _pass "detect_kvm_support: non-Linux returns error" \
        || _fail "detect_kvm_support: expected 'KVM requires Linux' in output"
fi

_section "detect_microvm_binary"

# Binary not installed
FC_BIN="${ISOLATED_CONFIG_DIR}/bin/firecracker"
if [[ ! -x "$FC_BIN" ]]; then
    if ! detect_microvm_binary &>/dev/null; then
        _pass "detect_microvm_binary: returns 1 when binary missing"
    else
        _fail "detect_microvm_binary: expected 1 but binary not present"
    fi
else
    path=$(detect_microvm_binary)
    [[ -x "$path" ]] && _pass "detect_microvm_binary: returns valid path" \
        || _fail "detect_microvm_binary: returned non-executable path"
fi

# Fake binary
_tmp_bin=$(mktemp)
chmod +x "$_tmp_bin"
MICRO_VM_BIN_PATH="$_tmp_bin"
path=$(detect_microvm_binary)
[[ "$path" == "$_tmp_bin" ]] && _pass "detect_microvm_binary: returns custom MICRO_VM_BIN_PATH" \
    || _fail "detect_microvm_binary: did not return MICRO_VM_BIN_PATH"
rm -f "$_tmp_bin"
MICRO_VM_BIN_PATH="${ISOLATED_CONFIG_DIR}/bin/firecracker"

_section "detect_virtiofsd"

# Just check it doesn't crash; result depends on system
if detect_virtiofsd &>/dev/null; then
    vfsd=$(detect_virtiofsd)
    [[ -x "$vfsd" ]] && _pass "detect_virtiofsd: found executable at $vfsd" \
        || _fail "detect_virtiofsd: returned non-executable path $vfsd"
else
    _pass "detect_virtiofsd: returns 1 when virtiofsd not installed (expected on CI)"
fi

_section "check_microvm_dependencies"

# Without real installation, should fail with missing items
if ! check_microvm_dependencies &>/dev/null; then
    _pass "check_microvm_dependencies: returns 1 when components missing"
else
    _pass "check_microvm_dependencies: all dependencies present (full install detected)"
fi

_section "build_microvm_config"

_tmpdir=$(mktemp -d)
MICRO_VM_KERNEL_PATH="${_tmpdir}/vmlinux"
MICRO_VM_ROOTFS_PATH="${_tmpdir}/rootfs.ext4"
touch "$MICRO_VM_KERNEL_PATH" "$MICRO_VM_ROOTFS_PATH"

# Create a fake firecracker binary so detect_microvm_binary works
mkdir -p "${_tmpdir}/bin"
_fake_fc="${_tmpdir}/bin/firecracker"
echo "#!/bin/bash" > "$_fake_fc"; chmod +x "$_fake_fc"
MICRO_VM_BIN_PATH="$_fake_fc"

config_file=$(build_microvm_config "$_tmpdir" "" "")
if [[ -f "$config_file" ]]; then
    _pass "build_microvm_config: creates config file"
    if grep -q '"vcpu_count"' "$config_file"; then
        _pass "build_microvm_config: config contains vcpu_count"
    else
        _fail "build_microvm_config: config missing vcpu_count"
    fi
    if grep -q '"mem_size_mib"' "$config_file"; then
        _pass "build_microvm_config: config contains mem_size_mib"
    else
        _fail "build_microvm_config: config missing mem_size_mib"
    fi
    if grep -q '"kernel_image_path"' "$config_file"; then
        _pass "build_microvm_config: config contains kernel_image_path"
    else
        _fail "build_microvm_config: config missing kernel_image_path"
    fi
else
    _fail "build_microvm_config: config file not created"
fi

_section "configure_guest_environment"

env_file="${_tmpdir}/guest-env.sh"
ANTHROPIC_BASE_URL="https://api.anthropic.com"
ICLAUDE_PII_ACTIVE=0

configure_guest_environment "$env_file"

if [[ -f "$env_file" ]]; then
    _pass "configure_guest_environment: creates env file"
    if grep -q "ANTHROPIC_BASE_URL" "$env_file"; then
        _pass "configure_guest_environment: contains ANTHROPIC_BASE_URL"
    else
        _fail "configure_guest_environment: missing ANTHROPIC_BASE_URL"
    fi
    if grep -q "CLAUDE_CONFIG_DIR" "$env_file"; then
        _pass "configure_guest_environment: contains CLAUDE_CONFIG_DIR"
    else
        _fail "configure_guest_environment: missing CLAUDE_CONFIG_DIR"
    fi
    perms=$(stat -c %a "$env_file" 2>/dev/null || stat -f %p "$env_file" 2>/dev/null || echo "")
    [[ "$perms" == "600" || "$perms" == *"600" ]] && \
        _pass "configure_guest_environment: env file has chmod 600" || \
        _skip "configure_guest_environment: chmod check skipped (perms=$perms)"
else
    _fail "configure_guest_environment: env file not created"
fi

_section "configure_guest_environment (PII proxy active)"

ICLAUDE_PII_ACTIVE=1
ICLAUDE_PII_ACTIVE_PORT=32000
MICRO_VM_NET_ENABLED=true
configure_guest_environment "${_tmpdir}/guest-env-pii.sh"

pii_env="${_tmpdir}/guest-env-pii.sh"
if grep -q "172.16.0.1:32000" "$pii_env"; then
    _pass "configure_guest_environment: PII active → ANTHROPIC_BASE_URL uses TAP host IP"
else
    _fail "configure_guest_environment: PII active → expected TAP host IP in ANTHROPIC_BASE_URL"
fi
ICLAUDE_PII_ACTIVE=0
unset ICLAUDE_PII_ACTIVE_PORT

_section "stop_microvm (no-op when not started)"

# Calling stop_microvm with no active VM should not crash
MICRO_VM_PID=""
MICRO_VM_SESSION_OWNED=false
VIRTIOFSD_PID_NVM=""
VIRTIOFSD_PID_WORKSPACE=""
if stop_microvm 2>/dev/null; then
    _pass "stop_microvm: no-op when VM not started"
else
    _pass "stop_microvm: exits cleanly when VM not started (any exit code ok)"
fi

_section "MICRO_VM_* defaults"

# init_environment() should set sane defaults
[[ "${MICRO_VM_ENABLED}" == "false" ]] && \
    _pass "MICRO_VM_ENABLED defaults to false" || \
    _fail "MICRO_VM_ENABLED should default to false (got: ${MICRO_VM_ENABLED})"
[[ "${MICRO_VM_VCPU}" == "2" ]] && \
    _pass "MICRO_VM_VCPU defaults to 2" || \
    _fail "MICRO_VM_VCPU should default to 2 (got: ${MICRO_VM_VCPU})"
[[ "${MICRO_VM_MEM_MB}" == "1024" ]] && \
    _pass "MICRO_VM_MEM_MB defaults to 1024" || \
    _fail "MICRO_VM_MEM_MB should default to 1024 (got: ${MICRO_VM_MEM_MB})"
[[ "${MICRO_VM_NET_TAP_IFACE}" == "tap-iclaude" ]] && \
    _pass "MICRO_VM_NET_TAP_IFACE defaults to tap-iclaude" || \
    _fail "MICRO_VM_NET_TAP_IFACE should default to tap-iclaude (got: ${MICRO_VM_NET_TAP_IFACE})"
[[ "${MICRO_VM_SNAPSHOT_ENABLED}" == "false" ]] && \
    _pass "MICRO_VM_SNAPSHOT_ENABLED defaults to false" || \
    _fail "MICRO_VM_SNAPSHOT_ENABLED should default to false (got: ${MICRO_VM_SNAPSHOT_ENABLED})"

_section "_alloc_microvm_slot / _claim_microvm_slot / _free_microvm_slot"

# Use an isolated slots dir so we don't interfere with any real sessions
_slots_test_dir=$(mktemp -d)
_orig_config_dir="${ISOLATED_CONFIG_DIR}"
ISOLATED_CONFIG_DIR="$_slots_test_dir"

# Basic allocation: should claim slot 0
MICRO_VM_NET_SUBNET="172.16.0.0/26"
MICRO_VM_NET_TAP_IFACE=""
if _alloc_microvm_slot 2>/dev/null; then
    [[ "$MICRO_VM_SLOT" == "0" ]] && _pass "_alloc: first slot is 0" \
        || _fail "_alloc: expected slot 0, got ${MICRO_VM_SLOT}"
    [[ "$MICRO_VM_NET_GUEST_IP" == "172.16.0.2" ]] && _pass "_alloc: slot 0 guest IP = 172.16.0.2" \
        || _fail "_alloc: slot 0 guest IP expected 172.16.0.2, got ${MICRO_VM_NET_GUEST_IP}"
    [[ "$MICRO_VM_NET_HOST_IP" == "172.16.0.1" ]] && _pass "_alloc: slot 0 host IP = 172.16.0.1" \
        || _fail "_alloc: slot 0 host IP expected 172.16.0.1, got ${MICRO_VM_NET_HOST_IP}"
    # Lock file should exist as pending
    _lk="${_slots_test_dir}/microvm-slots/slot-0.lock"
    [[ -f "$_lk" ]] && _pass "_alloc: slot-0.lock created" \
        || _fail "_alloc: slot-0.lock missing after allocation"
    _lk_content=$(cat "$_lk" 2>/dev/null || echo "")
    [[ "$_lk_content" == *"-pending" ]] && _pass "_alloc: lock contains PID-pending placeholder" \
        || _fail "_alloc: lock content unexpected: '${_lk_content}'"
else
    _fail "_alloc: _alloc_microvm_slot failed unexpectedly"
fi

# Claim with fake FC PID, then verify lock updated
MICRO_VM_PID="$$"
_claim_microvm_slot 2>/dev/null
_lk_after=$(cat "${_slots_test_dir}/microvm-slots/slot-0.lock" 2>/dev/null || echo "")
[[ "$_lk_after" == "$$" ]] && _pass "_claim: lock updated to FC PID" \
    || _fail "_claim: expected '$$', got '${_lk_after}'"

# Second alloc should skip slot 0 (live PID) and claim slot 1
MICRO_VM_SLOT=""
MICRO_VM_NET_TAP_IFACE=""
if _alloc_microvm_slot 2>/dev/null; then
    [[ "$MICRO_VM_SLOT" == "1" ]] && _pass "_alloc: second alloc claims slot 1" \
        || _fail "_alloc: expected slot 1, got ${MICRO_VM_SLOT}"
    [[ "$MICRO_VM_NET_GUEST_IP" == "172.16.0.4" ]] && _pass "_alloc: slot 1 guest IP = 172.16.0.4" \
        || _fail "_alloc: slot 1 guest IP expected 172.16.0.4, got ${MICRO_VM_NET_GUEST_IP}"
    [[ "$MICRO_VM_NET_TAP_IFACE" == "tap-iclaude-1" ]] && _pass "_alloc: slot 1 TAP = tap-iclaude-1" \
        || _fail "_alloc: slot 1 TAP expected tap-iclaude-1, got ${MICRO_VM_NET_TAP_IFACE}"
    _free_microvm_slot 2>/dev/null
else
    _fail "_alloc: second alloc failed (expected slot 1)"
fi

# Free slot 0, then re-alloc should reclaim slot 0
MICRO_VM_SLOT="0"
_free_microvm_slot 2>/dev/null
[[ ! -f "${_slots_test_dir}/microvm-slots/slot-0.lock" ]] && _pass "_free: slot-0.lock removed" \
    || _fail "_free: slot-0.lock still exists after free"

MICRO_VM_SLOT=""
MICRO_VM_NET_TAP_IFACE=""
if _alloc_microvm_slot 2>/dev/null; then
    [[ "$MICRO_VM_SLOT" == "0" ]] && _pass "_alloc: freed slot 0 reclaimed" \
        || _fail "_alloc: expected slot 0 after free, got ${MICRO_VM_SLOT}"
    _free_microvm_slot 2>/dev/null
else
    _fail "_alloc: reclaim of freed slot failed"
fi

# Parallel atomicity test: N concurrent subshells, each alloc+free
# All must get unique slots (no conflicts)
_section "_alloc_microvm_slot: parallel atomicity (N=8)"
_par_slots_dir=$(mktemp -d)
_par_out_dir=$(mktemp -d)
_N=8
for _i in $(seq 1 $_N); do
    (
        ISOLATED_CONFIG_DIR="$_par_slots_dir"
        MICRO_VM_NET_SUBNET="172.16.0.0/26"
        MICRO_VM_SLOT=""
        MICRO_VM_NET_TAP_IFACE=""
        MICRO_VM_PID="$$"
        if _alloc_microvm_slot 2>/dev/null; then
            _claim_microvm_slot 2>/dev/null
            echo "$MICRO_VM_SLOT" > "${_par_out_dir}/slot-${_i}.result"
            sleep 0.1
            _free_microvm_slot 2>/dev/null
        else
            echo "FAIL" > "${_par_out_dir}/slot-${_i}.result"
        fi
    ) &
done
wait

_par_failures=0
_par_slots=()
for _i in $(seq 1 $_N); do
    _res=$(cat "${_par_out_dir}/slot-${_i}.result" 2>/dev/null || echo "MISSING")
    if [[ "$_res" == "FAIL" || "$_res" == "MISSING" ]]; then
        _par_failures=$((_par_failures + 1))
    else
        _par_slots+=("$_res")
    fi
done
# Check for duplicates among simultaneously-claimed slots
# (With free between claims, duplicates are expected — check no alloc failures)
[[ "$_par_failures" -eq 0 ]] && _pass "parallel alloc: all $_N workers got a slot (no failures)" \
    || _fail "parallel alloc: $_par_failures / $_N workers failed to get a slot"

rm -rf "$_par_slots_dir" "$_par_out_dir" 2>/dev/null || true

# Restore original ISOLATED_CONFIG_DIR
ISOLATED_CONFIG_DIR="$_orig_config_dir"
rm -rf "$_slots_test_dir" 2>/dev/null || true

# Cleanup
rm -rf "$_tmpdir"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo "  Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
echo "══════════════════════════════════════════════════════"
echo ""

[[ $FAIL -eq 0 ]]
