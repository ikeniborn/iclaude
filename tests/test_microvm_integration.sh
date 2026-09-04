#!/bin/bash
# Integration tests for microVM CLI flags
# Tests that CLI flags parse correctly and check_microvm_status runs without errors.
# Does NOT start a real VM (requires KVM + full installation).
# Usage: bash tests/test_microvm_integration.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_DIR"

PASS=0; FAIL=0; SKIP=0

_pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
_fail() { echo "  ✗ FAIL: $1"; FAIL=$((FAIL + 1)); }
_skip() { echo "  - SKIP: $1"; SKIP=$((SKIP + 1)); }
_section() { echo ""; echo "── $1 ──────────────────────────────────────────────────────"; }

# ── Syntax validation ─────────────────────────────────────────────────────────

_section "Bash syntax"

for f in \
    lib/core/init.sh \
    lib/config/isolated.sh \
    lib/sandbox/detect.sh \
    lib/sandbox/install.sh \
    lib/sandbox/status.sh \
    lib/sandbox/microvm.sh \
    lib/launcher/launch.sh \
    lib/command/usage.sh \
    iclaude.sh
do
    if bash -n "$f" 2>/dev/null; then
        _pass "bash -n $f"
    else
        _fail "bash -n $f: syntax error"
    fi
done

# ── .claude_config.example ────────────────────────────────────────────────────

_section ".claude_config.example"

if grep -q "MICRO_VM_ENABLED" .claude_config.example; then
    _pass ".claude_config.example contains MICRO_VM_ENABLED"
else
    _fail ".claude_config.example missing MICRO_VM_ENABLED"
fi

if grep -q "MICRO-VM SANDBOX" .claude_config.example; then
    _pass ".claude_config.example has microVM section header"
else
    _fail ".claude_config.example missing microVM section header"
fi

# Check all current variables are documented
# Note: MICRO_VM_NET_HOST_IP / MICRO_VM_NET_GUEST_IP replaced by MICRO_VM_NET_SUBNET in v2
# Note: MICRO_VM_MOUNT_WORKSPACE replaced by MICRO_VM_WORKSPACE_MODE in v2
for var in MICRO_VM_ENABLED MICRO_VM_VCPU MICRO_VM_MEM_MB MICRO_VM_NET_ENABLED \
           MICRO_VM_NET_TAP_IFACE MICRO_VM_NET_SUBNET \
           MICRO_VM_SNAPSHOT_ENABLED MICRO_VM_ROOTFS_PATH MICRO_VM_KERNEL_PATH \
           MICRO_VM_LOG_LEVEL MICRO_VM_PROXY_PASS MICRO_VM_WORKSPACE_MODE; do
    if grep -q "^#.*${var}\|^${var}" .claude_config.example; then
        _pass ".claude_config.example documents ${var}"
    else
        _fail ".claude_config.example missing ${var}"
    fi
done

# ── CLI flag help text ─────────────────────────────────────────────────────────

_section "Usage help text"

for flag in "install-microvm" "check-microvm" "sandbox-microvm"; do
    if grep -qF -- "$flag" lib/command/usage.sh; then
        _pass "usage.sh contains --${flag}"
    else
        _fail "usage.sh missing --${flag}"
    fi
done

# ── iclaude.sh flag wiring ────────────────────────────────────────────────────

_section "iclaude.sh flag wiring"

if grep -q "USE_MICRO_VM_FLAG" iclaude.sh; then
    _pass "iclaude.sh defines USE_MICRO_VM_FLAG"
else
    _fail "iclaude.sh missing USE_MICRO_VM_FLAG"
fi

if grep -q "MICRO_VM_ENABLED" iclaude.sh; then
    _pass "iclaude.sh reads MICRO_VM_ENABLED from config"
else
    _fail "iclaude.sh does not read MICRO_VM_ENABLED"
fi

if grep -q '"--install-microvm"' iclaude.sh || grep -q "'--install-microvm'" iclaude.sh || \
   grep -q '            --install-microvm)' iclaude.sh; then
    _pass "iclaude.sh has --install-microvm case"
else
    _fail "iclaude.sh missing --install-microvm case"
fi

if grep -q '"--sandbox-microvm"' iclaude.sh || grep -q "'--sandbox-microvm'" iclaude.sh || \
   grep -q '            --sandbox-microvm)' iclaude.sh; then
    _pass "iclaude.sh has --sandbox-microvm case"
else
    _fail "iclaude.sh missing --sandbox-microvm case"
fi

if grep -q '"--check-microvm"' iclaude.sh || grep -q "'--check-microvm'" iclaude.sh || \
   grep -q '            --check-microvm)' iclaude.sh; then
    _pass "iclaude.sh has --check-microvm case"
else
    _fail "iclaude.sh missing --check-microvm case"
fi

# ── Module loading ─────────────────────────────────────────────────────────────

_section "Module loading"

if grep -q "microvm.sh" iclaude.sh; then
    _pass "iclaude.sh sources lib/sandbox/microvm.sh"
else
    _fail "iclaude.sh does not source lib/sandbox/microvm.sh"
fi

# ── launch.sh integration ─────────────────────────────────────────────────────

_section "launch.sh microVM integration"

if grep -q "use_microvm" lib/launcher/launch.sh; then
    _pass "launch.sh has use_microvm variable"
else
    _fail "launch.sh missing use_microvm"
fi

if grep -q "USE_MICRO_VM_FLAG" lib/launcher/launch.sh; then
    _pass "launch.sh checks USE_MICRO_VM_FLAG"
else
    _fail "launch.sh does not check USE_MICRO_VM_FLAG"
fi

if grep -q "stop_microvm" lib/launcher/launch.sh; then
    _pass "launch.sh calls stop_microvm for cleanup"
else
    _fail "launch.sh missing stop_microvm cleanup call"
fi

if grep -q "ICLAUDE_MICROVM_ACTIVE" lib/launcher/launch.sh; then
    _pass "launch.sh exports ICLAUDE_MICROVM_ACTIVE"
else
    _fail "launch.sh missing ICLAUDE_MICROVM_ACTIVE export"
fi

# ── check_microvm_status dry run ──────────────────────────────────────────────

_section "check_microvm_status (dry run)"

# Load minimal environment to run check_microvm_status
(
    print_info()    { :; }
    print_success() { :; }
    print_warning() { :; }
    print_error()   { :; }
    get_nvm_claude_path() { echo ""; }
    get_cli_version()     { echo "unknown"; }
    get_lockfile_field()  { echo "false"; }
    ISOLATED_NVM_DIR="${PROJECT_DIR}/.nvm-isolated"
    ISOLATED_CONFIG_DIR="${PROJECT_DIR}/.claude-isolated"
    source "${PROJECT_DIR}/lib/core/init.sh"
    init_environment
    source "${PROJECT_DIR}/lib/sandbox/detect.sh"
    source "${PROJECT_DIR}/lib/sandbox/install.sh"
    source "${PROJECT_DIR}/lib/sandbox/status.sh"
    source "${PROJECT_DIR}/lib/sandbox/microvm.sh"
    check_microvm_status &>/dev/null
) && _pass "check_microvm_status: runs without crashing" \
  || _fail "check_microvm_status: crashed with non-zero exit"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "══════════════════════════════════════════════════════"
echo "  Integration results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
echo "══════════════════════════════════════════════════════"
echo ""

[[ $FAIL -eq 0 ]]
