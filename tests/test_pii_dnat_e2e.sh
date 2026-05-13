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
