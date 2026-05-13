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
