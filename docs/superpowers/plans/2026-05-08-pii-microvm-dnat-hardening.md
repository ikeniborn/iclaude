# PII Proxy + microVM DNAT Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make PII proxy + microVM DNAT integration robust against missing sudo (P1), session crashes (P2), and sysctl leakage (P5).

**Architecture:** Add two helper functions to `lib/sandbox/microvm.sh` — preflight (warns when DNAT cannot be configured) and sweep (idempotent removal of orphaned rules identified by iptables comment marker). Wire them into `start_microvm()` and `stop_microvm()`. Three-level test pyramid: PATH-mock unit tests, real iptables tests on a `dummy` interface, and full E2E gated by KVM+sudo+firecracker.

**Tech Stack:** bash 4+, iptables (legacy or nft, both supported), iproute2, sysctl, awk, Linux `dummy` kernel module (for L2 tests), Firecracker (for L3 tests, optional).

**Spec:** `docs/superpowers/specs/2026-05-08-pii-microvm-dnat-hardening-design.md`

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `lib/sandbox/microvm.sh` | modify | Add `_pii_dnat_preflight`, `_pii_dnat_sweep_stale`; rewire `start_microvm`/`stop_microvm` DNAT blocks |
| `iclaude.sh` | modify | Add `--e2e-exit-after-boot` and `--e2e-kill-after-boot` debug flags (gated by `ICLAUDE_E2E_HEADLESS=1`) |
| `tests/test_pii_dnat_unit.sh` | create | L1: mock-based unit tests for both new functions |
| `tests/test_pii_dnat_iptables.sh` | create | L2: real-iptables tests on `dummy` iface (no KVM) |
| `tests/test_pii_dnat_e2e.sh` | create | L3: full E2E with Firecracker (gated, optional) |
| `tests/test_pii_dnat.sh` | create | Runner that invokes L1/L2/L3 in order |

---

## Task 1: Skeleton — empty helper functions + test runner

**Files:**
- Modify: `lib/sandbox/microvm.sh` (insert before `start_microvm()`)
- Create: `tests/test_pii_dnat.sh`
- Create: `tests/test_pii_dnat_unit.sh` (placeholder structure only)

- [ ] **Step 1: Add empty helpers above `start_microvm()`**

Find anchor: `grep -n "^start_microvm()" lib/sandbox/microvm.sh` — insert directly before that line.

```bash
#######################################
# Preflight check: PII proxy DNAT requires passwordless sudo + iptables nat.
# Returns 0 if DNAT can be configured (or PII not active — nothing to check).
# Returns 1 with explicit warnings if PII is active but prerequisites missing.
#######################################
_pii_dnat_preflight() {
    return 0
}

#######################################
# Idempotent removal of orphaned PII DNAT rules from previous crashed sessions.
# Matches by iptables comment marker "iclaude-pii-dnat:<tap_iface>".
# Args:
#   $1 - tap_iface (required)
#######################################
_pii_dnat_sweep_stale() {
    return 0
}

```

- [ ] **Step 2: Verify bash syntax**

Run: `bash -n lib/sandbox/microvm.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Create test runner**

Write to `tests/test_pii_dnat.sh`:

```bash
#!/usr/bin/env bash
# Test runner for PII proxy + microVM DNAT hardening.
# Invokes three test layers: mock unit (L1), real iptables (L2), full E2E (L3).
# Each layer self-gates and skips when prerequisites are missing.
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
bash "$DIR/test_pii_dnat_unit.sh"      || fail=1
bash "$DIR/test_pii_dnat_iptables.sh"  || fail=1
bash "$DIR/test_pii_dnat_e2e.sh"       || fail=1
exit "$fail"
```

```bash
chmod +x tests/test_pii_dnat.sh
```

- [ ] **Step 4: Create stub L1 file**

Write to `tests/test_pii_dnat_unit.sh`:

```bash
#!/usr/bin/env bash
# L1 — mock unit tests for _pii_dnat_preflight and _pii_dnat_sweep_stale.
# Stub — populated in later tasks.
set -euo pipefail
echo "L1: PASS=0 FAIL=0 (stub)"
```

```bash
chmod +x tests/test_pii_dnat_unit.sh
```

- [ ] **Step 5: Create stub L2 + L3 files so runner does not fail**

Write to `tests/test_pii_dnat_iptables.sh`:

```bash
#!/usr/bin/env bash
echo "L2: SKIP (stub)"
exit 0
```

Write to `tests/test_pii_dnat_e2e.sh`:

```bash
#!/usr/bin/env bash
echo "L3: SKIP (stub)"
exit 0
```

```bash
chmod +x tests/test_pii_dnat_iptables.sh tests/test_pii_dnat_e2e.sh
```

- [ ] **Step 6: Run runner — verify clean baseline**

Run: `bash tests/test_pii_dnat.sh`
Expected output (all three lines):
```
L1: PASS=0 FAIL=0 (stub)
L2: SKIP (stub)
L3: SKIP (stub)
```
Exit code: 0.

- [ ] **Step 7: Commit**

```bash
git add lib/sandbox/microvm.sh tests/test_pii_dnat.sh tests/test_pii_dnat_unit.sh tests/test_pii_dnat_iptables.sh tests/test_pii_dnat_e2e.sh
git commit -m "scaffold(microvm): stub PII DNAT helpers + test runner"
```

---

## Task 2: L1 — preflight tests (failing first)

**Files:**
- Modify: `tests/test_pii_dnat_unit.sh`

- [ ] **Step 1: Replace stub with full L1 test framework + preflight tests**

Write to `tests/test_pii_dnat_unit.sh`:

```bash
#!/usr/bin/env bash
# L1 — mock unit tests for _pii_dnat_preflight and _pii_dnat_sweep_stale.
# Uses PATH-overridden mocks for sudo and iptables; no real privileges required.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Stub print_* functions so sourced helpers don't depend on lib/core/print.sh
print_info()    { echo "INFO: $*"; }
print_warning() { echo "WARN: $*"; }
print_error()   { echo "ERR: $*"; }
print_success() { echo "OK: $*"; }

# Extract the two target functions from microvm.sh without sourcing the whole module.
# Awk picks each function block by its opening "name() {" and matches the closing "}" at column 1.
_extract() {
    awk -v fn="$1" '
        $0 ~ "^"fn"\\(\\)" { in_fn=1 }
        in_fn { print }
        in_fn && /^}/ { in_fn=0 }
    ' "$ROOT/lib/sandbox/microvm.sh"
}
eval "$(_extract _pii_dnat_preflight)"
eval "$(_extract _pii_dnat_sweep_stale)"

PASS=0
FAIL=0
assert_eq() {
    if [[ "$1" == "$2" ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "FAIL [$3]: got '$1' expected '$2'"
    fi
}
assert_contains() {
    if echo "$1" | grep -qF "$2"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "FAIL [$3]: '$2' not found in output"
    fi
}

# Mock builder: writes sudo + iptables stubs into $TD, returns nothing.
# Args:
#   $1 - dir
#   $2 - sudo_ok ("1" = succeeds, "0" = fails)
#   $3 - iptables script body (stdin not used — just the case logic)
make_mocks() {
    local dir="$1" sudo_ok="$2" ipt_body="$3"
    cat > "$dir/sudo" <<EOF
#!/usr/bin/env bash
[[ "$sudo_ok" == "1" ]] || exit 1
[[ "\$1" == "-n" ]] && shift
exec "\$@"
EOF
    cat > "$dir/iptables" <<EOF
#!/usr/bin/env bash
$ipt_body
EOF
    chmod +x "$dir/sudo" "$dir/iptables"
}

# ---- Tests ----

# Test 1: preflight — PII inactive → 0, no probes
unset ICLAUDE_PII_ACTIVE ICLAUDE_PII_ACTIVE_PORT
out=$(_pii_dnat_preflight 2>&1); rc=$?
assert_eq "$rc" "0" "preflight: inactive returns 0"
assert_eq "$out" "" "preflight: inactive prints nothing"

# Test 2: preflight — sudo unavailable → 1 + warning
TD=$(mktemp -d)
make_mocks "$TD" 0 'exit 0'
out=$(
    PATH="$TD:$PATH" \
    ICLAUDE_PII_ACTIVE=1 ICLAUDE_PII_ACTIVE_PORT=12345 \
    MICRO_VM_NET_ENABLED=true MICRO_VM_NET_HOST_IP=172.16.0.1 \
    _pii_dnat_preflight 2>&1
); rc=$?
assert_eq "$rc" "1" "preflight: no-sudo returns 1"
assert_contains "$out" "passwordless sudo unavailable" "preflight: no-sudo warning text"
rm -rf "$TD"

# Test 3: preflight — sudo OK + iptables OK → 0
TD=$(mktemp -d)
make_mocks "$TD" 1 'exit 0'
out=$(
    PATH="$TD:$PATH" \
    ICLAUDE_PII_ACTIVE=1 ICLAUDE_PII_ACTIVE_PORT=12345 \
    MICRO_VM_NET_ENABLED=true MICRO_VM_NET_HOST_IP=172.16.0.1 \
    _pii_dnat_preflight 2>&1
); rc=$?
assert_eq "$rc" "0" "preflight: happy path returns 0"
assert_eq "$out" "" "preflight: happy path prints nothing"
rm -rf "$TD"

# Test 4: preflight — sudo OK but iptables nat fails → 1
TD=$(mktemp -d)
make_mocks "$TD" 1 'case "$*" in *"-t nat"*) exit 1 ;; *) exit 0 ;; esac'
out=$(
    PATH="$TD:$PATH" \
    ICLAUDE_PII_ACTIVE=1 ICLAUDE_PII_ACTIVE_PORT=12345 \
    MICRO_VM_NET_ENABLED=true MICRO_VM_NET_HOST_IP=172.16.0.1 \
    _pii_dnat_preflight 2>&1
); rc=$?
assert_eq "$rc" "1" "preflight: iptables-nat-fail returns 1"
assert_contains "$out" "iptables nat table inaccessible" "preflight: iptables-nat-fail warning"
rm -rf "$TD"

# Test 5: preflight — net disabled → 0 (skip)
out=$(
    ICLAUDE_PII_ACTIVE=1 ICLAUDE_PII_ACTIVE_PORT=12345 \
    MICRO_VM_NET_ENABLED=false \
    _pii_dnat_preflight 2>&1
); rc=$?
assert_eq "$rc" "0" "preflight: net-disabled returns 0"

echo "L1: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
```

- [ ] **Step 2: Run L1 — verify all preflight tests FAIL (helper still empty)**

Run: `bash tests/test_pii_dnat_unit.sh`
Expected: at least Tests 2 and 4 fail (they expect rc=1 and warnings; empty helper returns 0). Tests 1, 3, 5 pass coincidentally because empty helper happens to return 0.
Final line should be `L1: PASS=3 FAIL=2` (or similar — exact pass count depends on coincidental matches). Exit code: 1.

- [ ] **Step 3: Commit**

```bash
git add tests/test_pii_dnat_unit.sh
git commit -m "test(microvm): add L1 preflight unit tests (failing)"
```

---

## Task 3: Implement `_pii_dnat_preflight` — make Task 2 pass

**Files:**
- Modify: `lib/sandbox/microvm.sh` (replace empty `_pii_dnat_preflight`)

- [ ] **Step 1: Replace empty helper body with real implementation**

Locate the function added in Task 1 and replace its body:

```bash
_pii_dnat_preflight() {
    [[ "${ICLAUDE_PII_ACTIVE:-0}" != "1" ]] && return 0
    [[ "${MICRO_VM_NET_ENABLED:-true}" != "true" ]] && return 0
    [[ -z "${ICLAUDE_PII_ACTIVE_PORT:-}" ]] && return 0

    if ! sudo -n true 2>/dev/null; then
        print_warning "microVM: PII proxy active but passwordless sudo unavailable"
        print_warning "microVM: guest cannot reach PII proxy at ${MICRO_VM_NET_HOST_IP}:${ICLAUDE_PII_ACTIVE_PORT}"
        print_info    "microVM: configure NOPASSWD for iptables/sysctl OR launch without --pii-proxy"
        return 1
    fi
    if ! sudo -n iptables -t nat -L PREROUTING -n &>/dev/null; then
        print_warning "microVM: iptables nat table inaccessible — PII proxy DNAT disabled"
        return 1
    fi
    return 0
}
```

- [ ] **Step 2: Verify bash syntax**

Run: `bash -n lib/sandbox/microvm.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Run L1 — verify all preflight tests PASS**

Run: `bash tests/test_pii_dnat_unit.sh`
Expected final line: `L1: PASS=8 FAIL=0` (4 rc-checks + 4 output-checks across 5 tests; Test 1 has rc+empty = 2; Test 2 has rc+contains = 2; etc — count varies). Exit code: 0.

If FAIL > 0: read the FAIL lines, compare expected vs actual, fix the helper body.

- [ ] **Step 4: Commit**

```bash
git add lib/sandbox/microvm.sh
git commit -m "feat(microvm): implement _pii_dnat_preflight"
```

---

## Task 4: L1 — sweep tests (failing first)

**Files:**
- Modify: `tests/test_pii_dnat_unit.sh` (append before final `echo`/exit)

- [ ] **Step 1: Append sweep tests just before the final `echo "L1:"` line**

Insert the following block above the `echo "L1: PASS=$PASS FAIL=$FAIL"` line:

```bash
# Test 6: sweep — empty rule list, terminates fast (no infinite loop)
TD=$(mktemp -d)
make_mocks "$TD" 1 '
case "$*" in
    *"--line-numbers"*)
        echo "Chain PREROUTING (policy ACCEPT)"
        echo "num  target  prot  opt  source  destination"
        ;;
    *"-D "*) exit 0 ;;
esac
exit 0
'
PATH="$TD:$PATH" timeout 5 bash -c "$(declare -f _pii_dnat_sweep_stale make_mocks); _pii_dnat_sweep_stale tap-iclaude-1"
assert_eq "$?" "0" "sweep: empty list terminates"
rm -rf "$TD"

# Test 7: sweep — drains 2 stale rules
TD=$(mktemp -d)
echo "2" > "$TD/state"
cat > "$TD/sudo" <<EOF
#!/usr/bin/env bash
[[ "\$1" == "-n" ]] && shift
exec "\$@"
EOF
cat > "$TD/iptables" <<EOF
#!/usr/bin/env bash
STATE="$TD/state"
N=\$(cat "\$STATE")
case "\$*" in
    *"--line-numbers"*)
        if [[ "\$N" -gt 0 ]]; then
            echo "1  DNAT  tcp  --  0.0.0.0/0  172.16.0.1  /* iclaude-pii-dnat:tap-iclaude-1 */"
        fi
        ;;
    *"-D "*"PREROUTING 1"*|*"-D "*"INPUT 1"*)
        echo \$((N - 1)) > "\$STATE"
        ;;
esac
exit 0
EOF
chmod +x "$TD/sudo" "$TD/iptables"
PATH="$TD:$PATH" timeout 5 _pii_dnat_sweep_stale tap-iclaude-1
remaining=$(cat "$TD/state")
assert_eq "$remaining" "0" "sweep: 2 stale rules drained"
rm -rf "$TD"

# Test 8: sweep — guard cap fires on pathological input (rule never goes away)
TD=$(mktemp -d)
make_mocks "$TD" 1 '
case "$*" in
    *"--line-numbers"*)
        echo "1  DNAT  tcp  --  0  0  /* iclaude-pii-dnat:tap-iclaude-1 */"
        ;;
    *"-D "*) exit 0 ;;
esac
exit 0
'
start_ts=$(date +%s)
PATH="$TD:$PATH" timeout 5 _pii_dnat_sweep_stale tap-iclaude-1
rc=$?
end_ts=$(date +%s)
assert_eq "$rc" "0" "sweep: guard cap returns 0"
[[ $((end_ts - start_ts)) -lt 5 ]] && PASS=$((PASS + 1)) || { FAIL=$((FAIL + 1)); echo "FAIL [sweep guard timing]: took $((end_ts - start_ts))s"; }
rm -rf "$TD"

# Test 9: sweep — empty tap arg returns 0 silently
out=$(_pii_dnat_sweep_stale "" 2>&1); rc=$?
assert_eq "$rc" "0" "sweep: empty tap arg returns 0"
```

- [ ] **Step 2: Run L1 — verify NEW sweep tests fail (helper still empty)**

Run: `bash tests/test_pii_dnat_unit.sh`
Expected: Test 7 fails (empty helper does not drain anything; remaining stays "2"). Test 6, 8, 9 may pass coincidentally (empty helper exits 0 instantly). Exit code: 1.

- [ ] **Step 3: Commit**

```bash
git add tests/test_pii_dnat_unit.sh
git commit -m "test(microvm): add L1 sweep unit tests (failing)"
```

---

## Task 5: Implement `_pii_dnat_sweep_stale` — make Task 4 pass

**Files:**
- Modify: `lib/sandbox/microvm.sh` (replace empty `_pii_dnat_sweep_stale`)

- [ ] **Step 1: Replace the empty body**

```bash
_pii_dnat_sweep_stale() {
    local tap="$1"
    [[ -z "$tap" ]] && return 0
    sudo -n true 2>/dev/null || return 0

    local marker="iclaude-pii-dnat:${tap}"
    local _guard _line

    _guard=0
    while [[ $_guard -lt 20 ]]; do
        _line=$(sudo -n iptables -t nat -L PREROUTING --line-numbers -n 2>/dev/null \
                | awk -v m="$marker" '$0 ~ m {print $1; exit}')
        [[ -z "$_line" ]] && break
        sudo -n iptables -t nat -D PREROUTING "$_line" 2>/dev/null || break
        _guard=$((_guard + 1))
    done

    _guard=0
    while [[ $_guard -lt 20 ]]; do
        _line=$(sudo -n iptables -L INPUT --line-numbers -n 2>/dev/null \
                | awk -v m="$marker" '$0 ~ m {print $1; exit}')
        [[ -z "$_line" ]] && break
        sudo -n iptables -D INPUT "$_line" 2>/dev/null || break
        _guard=$((_guard + 1))
    done
}
```

- [ ] **Step 2: Verify bash syntax**

Run: `bash -n lib/sandbox/microvm.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Run L1 — verify all tests pass**

Run: `bash tests/test_pii_dnat_unit.sh`
Expected: `L1: PASS=N FAIL=0`. Exit code: 0.

If Test 7 (drain) still fails: inspect `$TD/state` write logic in mock and adjust the `-D ... PREROUTING 1` pattern in the case statement.

- [ ] **Step 4: Commit**

```bash
git add lib/sandbox/microvm.sh
git commit -m "feat(microvm): implement _pii_dnat_sweep_stale"
```

---

## Task 6: Wire helpers into `start_microvm()`

**Files:**
- Modify: `lib/sandbox/microvm.sh` (around line 1491 — DNAT block in `start_microvm`)

- [ ] **Step 1: Locate the existing block**

Run: `grep -n 'DNAT.*forward host_ip:PII_PORT' lib/sandbox/microvm.sh`
Note the line number — call it `$ANCHOR`. The existing block runs from `$ANCHOR` (comment line) through approximately `$ANCHOR + 28`.

- [ ] **Step 2: Replace the block**

The existing block (current code):

```bash
    if [[ "${ICLAUDE_PII_ACTIVE:-0}" == "1" ]] && \
       [[ "${ICLAUDE_PII_ACTIVE_PORT:-}" =~ ^[0-9]+$ ]] && \
       [[ "${MICRO_VM_NET_ENABLED:-true}" == "true" ]] && \
       [[ -n "${MICRO_VM_NET_HOST_IP:-}" ]] && [[ -n "${MICRO_VM_NET_TAP_IFACE:-}" ]] && \
       sudo -n true 2>/dev/null; then
        sudo sysctl -w "net.ipv4.conf.${MICRO_VM_NET_TAP_IFACE}.route_localnet=1" &>/dev/null || true
        sudo iptables -t nat -A PREROUTING \
            -i "${MICRO_VM_NET_TAP_IFACE}" \
            -d "${MICRO_VM_NET_HOST_IP}" -p tcp --dport "${ICLAUDE_PII_ACTIVE_PORT}" \
            -j DNAT --to-destination "127.0.0.1:${ICLAUDE_PII_ACTIVE_PORT}" \
            2>/dev/null || true
        sudo iptables -A INPUT \
            -i "${MICRO_VM_NET_TAP_IFACE}" -p tcp --dport "${ICLAUDE_PII_ACTIVE_PORT}" \
            -j ACCEPT 2>/dev/null || true
        export MICRO_VM_PII_DNAT_PORT="${ICLAUDE_PII_ACTIVE_PORT}"
        print_info "microVM: DNAT ${MICRO_VM_NET_HOST_IP}:${ICLAUDE_PII_ACTIVE_PORT} → 127.0.0.1:${ICLAUDE_PII_ACTIVE_PORT} (PII proxy)"
    fi
```

Replace it with:

```bash
    if _pii_dnat_preflight && \
       [[ "${ICLAUDE_PII_ACTIVE_PORT:-}" =~ ^[0-9]+$ ]] && \
       [[ -n "${MICRO_VM_NET_HOST_IP:-}" ]] && [[ -n "${MICRO_VM_NET_TAP_IFACE:-}" ]]; then
        _pii_dnat_sweep_stale "${MICRO_VM_NET_TAP_IFACE}"
        sudo sysctl -w "net.ipv4.conf.${MICRO_VM_NET_TAP_IFACE}.route_localnet=1" &>/dev/null || true
        sudo iptables -t nat -A PREROUTING \
            -i "${MICRO_VM_NET_TAP_IFACE}" \
            -d "${MICRO_VM_NET_HOST_IP}" -p tcp --dport "${ICLAUDE_PII_ACTIVE_PORT}" \
            -m comment --comment "iclaude-pii-dnat:${MICRO_VM_NET_TAP_IFACE}" \
            -j DNAT --to-destination "127.0.0.1:${ICLAUDE_PII_ACTIVE_PORT}" \
            2>/dev/null || true
        sudo iptables -A INPUT \
            -i "${MICRO_VM_NET_TAP_IFACE}" -p tcp --dport "${ICLAUDE_PII_ACTIVE_PORT}" \
            -m comment --comment "iclaude-pii-dnat:${MICRO_VM_NET_TAP_IFACE}" \
            -j ACCEPT 2>/dev/null || true
        export MICRO_VM_PII_DNAT_PORT="${ICLAUDE_PII_ACTIVE_PORT}"
        print_info "microVM: DNAT ${MICRO_VM_NET_HOST_IP}:${ICLAUDE_PII_ACTIVE_PORT} → 127.0.0.1:${ICLAUDE_PII_ACTIVE_PORT} (PII proxy)"
    fi
```

Differences:
- gate `sudo -n true` removed — preflight handles it (and warns explicitly);
- `MICRO_VM_NET_ENABLED` check moved into preflight;
- sweep called before adding fresh rules;
- both `iptables -A` lines carry `-m comment --comment "iclaude-pii-dnat:<tap>"`.

- [ ] **Step 2: Verify bash syntax**

Run: `bash -n lib/sandbox/microvm.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Run L1 — confirm regression-free**

Run: `bash tests/test_pii_dnat_unit.sh`
Expected: `L1: PASS=N FAIL=0`. Exit code: 0.

- [ ] **Step 4: Commit**

```bash
git add lib/sandbox/microvm.sh
git commit -m "refactor(microvm): use preflight + sweep + comment marker in start_microvm"
```

---

## Task 7: Wire sweep into `stop_microvm()`

**Files:**
- Modify: `lib/sandbox/microvm.sh` (around line 1589 — DNAT cleanup block)

- [ ] **Step 1: Locate the existing block**

Run: `grep -n 'Remove DNAT rule and route_localnet for PII' lib/sandbox/microvm.sh`
Note the comment line; the block extends to the closing `fi`.

- [ ] **Step 2: Replace the block**

Existing code:

```bash
    # Remove DNAT rule and route_localnet for PII proxy (added in start_microvm when PII proxy is active).
    if [[ -n "${MICRO_VM_PII_DNAT_PORT:-}" ]] && [[ -n "${MICRO_VM_NET_HOST_IP:-}" ]] && \
       [[ -n "${MICRO_VM_NET_TAP_IFACE:-}" ]] && sudo -n true 2>/dev/null; then
        sudo iptables -t nat -D PREROUTING \
            -i "${MICRO_VM_NET_TAP_IFACE}" \
            -d "${MICRO_VM_NET_HOST_IP}" -p tcp --dport "${MICRO_VM_PII_DNAT_PORT}" \
            -j DNAT --to-destination "127.0.0.1:${MICRO_VM_PII_DNAT_PORT}" \
            2>/dev/null || true
        sudo iptables -D INPUT \
            -i "${MICRO_VM_NET_TAP_IFACE}" -p tcp --dport "${MICRO_VM_PII_DNAT_PORT}" \
            -j ACCEPT 2>/dev/null || true
        sudo sysctl -w "net.ipv4.conf.${MICRO_VM_NET_TAP_IFACE}.route_localnet=0" &>/dev/null || true
        MICRO_VM_PII_DNAT_PORT=""
    fi
```

Replace with:

```bash
    # Remove DNAT rule and route_localnet for PII proxy (added in start_microvm when PII proxy is active).
    # Uses comment-marker sweep so cleanup is robust against port mismatches and partial state.
    if [[ -n "${MICRO_VM_NET_TAP_IFACE:-}" ]] && sudo -n true 2>/dev/null; then
        _pii_dnat_sweep_stale "${MICRO_VM_NET_TAP_IFACE}"
        sudo -n sysctl -w "net.ipv4.conf.${MICRO_VM_NET_TAP_IFACE}.route_localnet=0" &>/dev/null || true
        MICRO_VM_PII_DNAT_PORT=""
    fi
```

Differences:
- removed dependence on `MICRO_VM_PII_DNAT_PORT` and `MICRO_VM_NET_HOST_IP` — sweep finds rules by marker;
- explicit per-rule `-D` calls replaced by single `_pii_dnat_sweep_stale` call;
- sysctl reset retained.

- [ ] **Step 2: Verify bash syntax**

Run: `bash -n lib/sandbox/microvm.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Run L1**

Run: `bash tests/test_pii_dnat_unit.sh`
Expected: `L1: PASS=N FAIL=0`. Exit code: 0.

- [ ] **Step 4: Commit**

```bash
git add lib/sandbox/microvm.sh
git commit -m "refactor(microvm): use sweep in stop_microvm cleanup"
```

---

## Task 8: L2 — real-iptables tests on `dummy` interface

**Files:**
- Modify: `tests/test_pii_dnat_iptables.sh` (replace stub)

- [ ] **Step 1: Replace stub with real test**

Write to `tests/test_pii_dnat_iptables.sh`:

```bash
#!/usr/bin/env bash
# L2 — real-iptables tests for _pii_dnat_sweep_stale.
# Uses a kernel-level "dummy" interface to avoid KVM/Firecracker dependency.
# Self-skips when passwordless sudo for iptables is unavailable.
set -uo pipefail

if ! sudo -n iptables -t nat -L &>/dev/null; then
    echo "L2: SKIP (passwordless sudo for iptables not available)"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

print_info()    { echo "INFO: $*"; }
print_warning() { echo "WARN: $*"; }
print_error()   { echo "ERR: $*"; }
print_success() { echo "OK: $*"; }

# Source only the sweep function from microvm.sh
eval "$(awk '
    /^_pii_dnat_sweep_stale\(\)/ { in_fn=1 }
    in_fn { print }
    in_fn && /^}/ { in_fn=0 }
' "$ROOT/lib/sandbox/microvm.sh")"

DUMMY_A="iclaudetest0"
DUMMY_B="iclaudetest1"
PORT=59999
MARKER_A="iclaude-pii-dnat:${DUMMY_A}"
MARKER_B="iclaude-pii-dnat:${DUMMY_B}"

# Targeted cleanup: remove only rules carrying our test markers.
# NEVER use iptables -F here — that would wipe legitimate rules from the host.
cleanup() {
    for marker in "$MARKER_A" "$MARKER_B"; do
        # PREROUTING (nat)
        local guard=0
        while [[ $guard -lt 50 ]]; do
            local L
            L=$(sudo -n iptables -t nat -L PREROUTING --line-numbers -n 2>/dev/null \
                | awk -v m="$marker" '$0 ~ m {print $1; exit}')
            [[ -z "$L" ]] && break
            sudo -n iptables -t nat -D PREROUTING "$L" 2>/dev/null || break
            guard=$((guard + 1))
        done
        # INPUT
        guard=0
        while [[ $guard -lt 50 ]]; do
            local L
            L=$(sudo -n iptables -L INPUT --line-numbers -n 2>/dev/null \
                | awk -v m="$marker" '$0 ~ m {print $1; exit}')
            [[ -z "$L" ]] && break
            sudo -n iptables -D INPUT "$L" 2>/dev/null || break
            guard=$((guard + 1))
        done
    done
    sudo -n ip link delete "$DUMMY_A" 2>/dev/null || true
    sudo -n ip link delete "$DUMMY_B" 2>/dev/null || true
}
trap cleanup EXIT

PASS=0
FAIL=0
check() {
    if [[ "$1" == "$2" ]]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi
}

# Setup dummy interfaces
sudo -n ip link add "$DUMMY_A" type dummy 2>/dev/null || { echo "L2: cannot create dummy iface — kernel module missing?"; exit 0; }
sudo -n ip link set "$DUMMY_A" up
sudo -n ip link add "$DUMMY_B" type dummy 2>/dev/null
sudo -n ip link set "$DUMMY_B" up

# ---- Test L2.1: drain 3 stale rules ----
for _ in 1 2 3; do
    sudo -n iptables -t nat -A PREROUTING -i "$DUMMY_A" \
        -d 172.16.0.1 -p tcp --dport "$PORT" \
        -m comment --comment "$MARKER_A" \
        -j DNAT --to-destination "127.0.0.1:${PORT}"
done
count=$(sudo -n iptables -t nat -L PREROUTING -n 2>/dev/null | grep -c "$MARKER_A" || true)
check "$count" "3" "L2.1: setup created 3 PREROUTING rules"

_pii_dnat_sweep_stale "$DUMMY_A"

count=$(sudo -n iptables -t nat -L PREROUTING -n 2>/dev/null | grep -c "$MARKER_A" || true)
check "$count" "0" "L2.1: sweep removed all 3 PREROUTING rules"

# ---- Test L2.2: per-tap scoping — sweep of A does NOT touch B ----
sudo -n iptables -t nat -A PREROUTING -i "$DUMMY_B" \
    -d 172.16.0.1 -p tcp --dport "$PORT" \
    -m comment --comment "$MARKER_B" \
    -j DNAT --to-destination "127.0.0.1:${PORT}"
sudo -n iptables -t nat -A PREROUTING -i "$DUMMY_A" \
    -d 172.16.0.1 -p tcp --dport "$PORT" \
    -m comment --comment "$MARKER_A" \
    -j DNAT --to-destination "127.0.0.1:${PORT}"

_pii_dnat_sweep_stale "$DUMMY_A"

count_a=$(sudo -n iptables -t nat -L PREROUTING -n 2>/dev/null | grep -c "$MARKER_A" || true)
count_b=$(sudo -n iptables -t nat -L PREROUTING -n 2>/dev/null | grep -c "$MARKER_B" || true)
check "$count_a" "0" "L2.2: sweep removed rules for tap A"
check "$count_b" "1" "L2.2: sweep preserved rule for tap B"

_pii_dnat_sweep_stale "$DUMMY_B"
count_b=$(sudo -n iptables -t nat -L PREROUTING -n 2>/dev/null | grep -c "$MARKER_B" || true)
check "$count_b" "0" "L2.2: sweep B removed B's rule"

# ---- Test L2.3: INPUT rules also drained ----
sudo -n iptables -A INPUT -i "$DUMMY_A" -p tcp --dport "$PORT" \
    -m comment --comment "$MARKER_A" -j ACCEPT
count=$(sudo -n iptables -L INPUT -n 2>/dev/null | grep -c "$MARKER_A" || true)
check "$count" "1" "L2.3: setup created INPUT rule"

_pii_dnat_sweep_stale "$DUMMY_A"
count=$(sudo -n iptables -L INPUT -n 2>/dev/null | grep -c "$MARKER_A" || true)
check "$count" "0" "L2.3: sweep removed INPUT rule"

# ---- Test L2.4: sysctl set/reset round-trip ----
sudo -n sysctl -w "net.ipv4.conf.${DUMMY_A}.route_localnet=1" &>/dev/null
v=$(cat "/proc/sys/net/ipv4/conf/${DUMMY_A}/route_localnet" 2>/dev/null)
check "$v" "1" "L2.4: route_localnet=1 set"
sudo -n sysctl -w "net.ipv4.conf.${DUMMY_A}.route_localnet=0" &>/dev/null
v=$(cat "/proc/sys/net/ipv4/conf/${DUMMY_A}/route_localnet" 2>/dev/null)
check "$v" "0" "L2.4: route_localnet=0 reset"

echo "L2: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
```

```bash
chmod +x tests/test_pii_dnat_iptables.sh
```

- [ ] **Step 2: Run L2 (or skip)**

Run: `bash tests/test_pii_dnat_iptables.sh`
Expected on dev hosts with passwordless sudo: `L2: PASS=8 FAIL=0`, exit 0.
Expected on hosts without sudo: `L2: SKIP (passwordless sudo for iptables not available)`, exit 0.

- [ ] **Step 3: Run full runner**

Run: `bash tests/test_pii_dnat.sh`
Expected: L1 PASS, L2 PASS or SKIP, L3 SKIP (stub still). Exit 0.

- [ ] **Step 4: Commit**

```bash
git add tests/test_pii_dnat_iptables.sh
git commit -m "test(microvm): add L2 real-iptables sweep tests on dummy iface"
```

---

## Task 9: E2E debug flags in `iclaude.sh` + `lib/launcher/launch.sh`

**Files:**
- Modify: `iclaude.sh` (add two CLI flag cases near line 611, the existing `--sandbox-microvm)` case)
- Modify: `lib/launcher/launch.sh` (add post-boot dispatch after line 167, the closing `fi` of `start_microvm`)

- [ ] **Step 1: Add flag parsing in `iclaude.sh`**

Locate the `--sandbox-microvm)` case (around line 611). Immediately AFTER its closing `;;`, add:

```bash
        --e2e-exit-after-boot)
            if [[ "${ICLAUDE_E2E_HEADLESS:-0}" != "1" ]]; then
                echo "ERROR: --e2e-exit-after-boot requires ICLAUDE_E2E_HEADLESS=1" >&2
                exit 2
            fi
            ICLAUDE_E2E_EXIT_AFTER_BOOT=1
            shift
            ;;
        --e2e-kill-after-boot)
            if [[ "${ICLAUDE_E2E_HEADLESS:-0}" != "1" ]]; then
                echo "ERROR: --e2e-kill-after-boot requires ICLAUDE_E2E_HEADLESS=1" >&2
                exit 2
            fi
            ICLAUDE_E2E_KILL_AFTER_BOOT=1
            shift
            ;;
```

- [ ] **Step 3: Add post-boot dispatch in `lib/launcher/launch.sh`**

Locate the closing `fi` of the `start_microvm` block (line 167 — the `fi` that closes `if ! start_microvm "$skip_isolated"; then ... exit 1; fi`).

Immediately after that `fi` and before the `# SSH ControlMaster socket path` comment, insert:

```bash
        # E2E test hooks — only active when ICLAUDE_E2E_HEADLESS=1 was set at launch
        if [[ "${ICLAUDE_E2E_KILL_AFTER_BOOT:-0}" == "1" ]]; then
            echo "E2E: simulating crash via SIGKILL on self (PID $$)"
            kill -9 $$
        fi
        if [[ "${ICLAUDE_E2E_EXIT_AFTER_BOOT:-0}" == "1" ]]; then
            echo "E2E: clean exit after microVM boot"
            stop_microvm 2>/dev/null || true
            [[ "$use_pii_proxy" == "true" ]] && stop_pii_proxy_server 2>/dev/null || true
            [[ "$use_router" == "true" ]] && stop_ccr_server 2>/dev/null || true
            exit 0
        fi
```

This runs BEFORE the SSH ControlMaster setup and BEFORE the guest-attach / claude-launch step, so neither completes when the E2E flags are active.

- [ ] **Step 4: Verify bash syntax**

Run: `bash -n iclaude.sh && bash -n lib/launcher/launch.sh && echo OK`
Expected: `OK`.

- [ ] **Step 5: Verify gating works without env var**

Run: `./iclaude.sh --e2e-exit-after-boot 2>&1 | head -3 ; echo "exit: $?"`
Expected: error message containing `ICLAUDE_E2E_HEADLESS=1`, exit 2.

- [ ] **Step 6: Commit**

```bash
git add iclaude.sh lib/launcher/launch.sh
git commit -m "feat(iclaude): add gated E2E debug flags for microVM tests"
```

---

## Task 10: L3 — full E2E test (gated)

**Files:**
- Modify: `tests/test_pii_dnat_e2e.sh` (replace stub)

- [ ] **Step 1: Replace stub**

Write to `tests/test_pii_dnat_e2e.sh`:

```bash
#!/usr/bin/env bash
# L3 — full E2E test of PII DNAT lifecycle.
# Self-skips when KVM, passwordless sudo, or firecracker are unavailable.
set -uo pipefail

[[ -e /dev/kvm ]] || { echo "L3: SKIP (no /dev/kvm)"; exit 0; }
sudo -n iptables -L &>/dev/null || { echo "L3: SKIP (no passwordless sudo)"; exit 0; }
command -v firecracker &>/dev/null || { echo "L3: SKIP (no firecracker)"; exit 0; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

PASS=0
FAIL=0
check() {
    if [[ "$1" == "$2" ]]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi
}

count_markers() {
    sudo -n iptables -t nat -L PREROUTING -n 2>/dev/null | grep -c "iclaude-pii-dnat:" || true
}

# ---- L3.1: clean run leaves no rules behind ----
ICLAUDE_E2E_HEADLESS=1 \
    timeout 90 "$ROOT/iclaude.sh" --pii-proxy --sandbox-microvm --e2e-exit-after-boot \
    >"$LOG" 2>&1 || true

grep -q "DNAT 172\.16\." "$LOG" && phase1_dnat_seen=1 || phase1_dnat_seen=0
check "$phase1_dnat_seen" "1" "L3.1: DNAT info line printed during clean run"

remaining=$(count_markers)
check "$remaining" "0" "L3.1: clean run leaves no DNAT markers"

# ---- L3.2: crash simulation leaves stale rules ----
ICLAUDE_E2E_HEADLESS=1 \
    timeout 90 "$ROOT/iclaude.sh" --pii-proxy --sandbox-microvm --e2e-kill-after-boot \
    >"$LOG" 2>&1 || true

stale=$(count_markers)
[[ "$stale" -gt 0 ]] && crash_left_stale=1 || crash_left_stale=0
check "$crash_left_stale" "1" "L3.2: crash simulation leaves stale rules"

# ---- L3.3: restart sweeps stale + clean exit removes new ----
ICLAUDE_E2E_HEADLESS=1 \
    timeout 90 "$ROOT/iclaude.sh" --pii-proxy --sandbox-microvm --e2e-exit-after-boot \
    >"$LOG" 2>&1 || true

final=$(count_markers)
check "$final" "0" "L3.3: restart swept stale + clean exit removed new"

# Final cleanup safety net (in case any test left rules).
# Targeted: only iclaude markers.
guard=0
while [[ $guard -lt 50 ]] && [[ "$(count_markers)" -gt 0 ]]; do
    L=$(sudo -n iptables -t nat -L PREROUTING --line-numbers -n 2>/dev/null \
        | awk '/iclaude-pii-dnat:/ {print $1; exit}')
    [[ -z "$L" ]] && break
    sudo -n iptables -t nat -D PREROUTING "$L" 2>/dev/null || break
    guard=$((guard + 1))
done

echo "L3: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
```

```bash
chmod +x tests/test_pii_dnat_e2e.sh
```

- [ ] **Step 2: Run L3 (will likely SKIP on dev workstation)**

Run: `bash tests/test_pii_dnat_e2e.sh`
Expected on machines without all prereqs: one of the SKIP messages, exit 0.
Expected on a machine with KVM + sudo + firecracker: `L3: PASS=4 FAIL=0`, exit 0.

- [ ] **Step 3: Run full runner**

Run: `bash tests/test_pii_dnat.sh`
Expected: all three layers report PASS or SKIP. Exit 0.

- [ ] **Step 4: Commit**

```bash
git add tests/test_pii_dnat_e2e.sh
git commit -m "test(microvm): add L3 full E2E DNAT lifecycle test"
```

---

## Task 11: Documentation update

**Files:**
- Modify: `docs/functions/MICROVM.md` (add a short troubleshooting section)

- [ ] **Step 1: Append troubleshooting section**

Append to `docs/functions/MICROVM.md`:

```markdown
## Troubleshooting

### Guest cannot reach PII proxy

If the guest's Claude Code calls hang or fail with connection errors after launching with `--pii-proxy --sandbox-microvm`, verify the host installed the DNAT rule:

```bash
sudo iptables -t nat -L PREROUTING -n | grep iclaude-pii-dnat
```

Expected: one rule per active microVM session, e.g.
```
DNAT  tcp  --  0.0.0.0/0  172.16.0.1  tcp dpt:<port> /* iclaude-pii-dnat:tap-iclaude-1 */ to:127.0.0.1:<port>
```

If the rule is missing, the most common cause is missing passwordless sudo. iclaude prints a warning at launch time:

```
WARN: microVM: PII proxy active but passwordless sudo unavailable
WARN: microVM: guest cannot reach PII proxy at 172.16.0.1:<port>
INFO: microVM: configure NOPASSWD for iptables/sysctl OR launch without --pii-proxy
```

Configure NOPASSWD via `visudo`, e.g.:

```
%iclaude ALL=(root) NOPASSWD: /usr/sbin/iptables, /usr/sbin/sysctl, /usr/sbin/ip
```

### Stale iptables rules after crash

If iclaude was killed via `kill -9` or the host crashed, DNAT rules may persist. They are removed automatically the next time iclaude launches with `--pii-proxy --sandbox-microvm` (sweep on start).

To remove them manually:

```bash
while sudo iptables -t nat -L PREROUTING --line-numbers -n | grep -q iclaude-pii-dnat; do
    L=$(sudo iptables -t nat -L PREROUTING --line-numbers -n | awk '/iclaude-pii-dnat/ {print $1; exit}')
    sudo iptables -t nat -D PREROUTING "$L"
done
```
```

- [ ] **Step 2: Commit**

```bash
git add docs/functions/MICROVM.md
git commit -m "docs(microvm): add PII DNAT troubleshooting section"
```

---

## Task 12: Final verification

- [ ] **Step 1: Full runner**

Run: `bash tests/test_pii_dnat.sh`
Expected: L1 PASS, L2 PASS or SKIP, L3 PASS or SKIP. Exit 0.

- [ ] **Step 2: Syntax check both modified files**

Run: `bash -n iclaude.sh && bash -n lib/sandbox/microvm.sh && echo OK`
Expected: `OK`.

- [ ] **Step 3: Smoke test on real machine (manual confirmation)**

If passwordless sudo is available locally:

Run: `./iclaude.sh --pii-proxy --check-isolated`
Expected: completes without errors. (Does not exercise DNAT path — just confirms the script still parses and runs.)

If KVM + firecracker are also available, optionally:

Run: `ICLAUDE_E2E_HEADLESS=1 ./iclaude.sh --pii-proxy --sandbox-microvm --e2e-exit-after-boot`
Expected: prints DNAT info line, then "E2E: clean exit after microVM boot", exit 0. Verify no leftover rules:
```bash
sudo iptables -t nat -L PREROUTING -n | grep iclaude-pii-dnat
```
Expected: empty.

- [ ] **Step 4: Final commit (only if anything new since Task 11)**

If nothing changed beyond Task 11, skip. Otherwise:

```bash
git add -A
git commit -m "chore(microvm): final tidy after PII DNAT hardening"
```

---

## Acceptance Criteria (from spec)

- [x] L1 passes on any Linux host (no sudo) — Task 3, 5
- [x] L2 passes when passwordless sudo for iptables is available — Task 8
- [x] L3 passes on hosts with KVM + sudo + firecracker; otherwise skips with explicit message — Task 10
- [x] After full test run, no `iclaude-pii-dnat:` markers remain in iptables — Task 8 cleanup, Task 10 cleanup
- [x] Existing `iclaude --pii-proxy --sandbox-microvm` behavior unchanged on machines with passwordless sudo — Task 6 preserves rule semantics, only adds marker + sweep
- [x] On machines without passwordless sudo, behavior changes from "silent guest network failure" to "explicit warning, microVM still boots" — Task 3 (preflight implementation), Task 6 (wired in)
