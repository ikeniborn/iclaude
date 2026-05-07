# PII Proxy + microVM DNAT Hardening — Design

**Date:** 2026-05-08
**Status:** Draft
**Scope:** `lib/sandbox/microvm.sh` + new tests

## Background

Shared PII proxy binds only to `127.0.0.1` (`lib/pii-proxy/server.py:1007`). microVM guest sits on a TAP network (default host IP `172.16.0.1`, guest IP `172.16.0.2`) and cannot reach host loopback directly. `start_microvm()` therefore installs:

1. `sysctl net.ipv4.conf.<tap>.route_localnet=1`
2. `iptables -t nat -A PREROUTING -i <tap> -d <host_ip> -p tcp --dport <port> -j DNAT --to 127.0.0.1:<port>`
3. `iptables -A INPUT -i <tap> -p tcp --dport <port> -j ACCEPT`

These rules are removed in `stop_microvm()`.

## Problems Addressed

**P1 — Silent failure when passwordless sudo unavailable.**
Current code: `sudo -n true 2>/dev/null` gates the whole DNAT block. If sudo is not available, the block is skipped silently. Guest gets `ANTHROPIC_BASE_URL=http://172.16.0.1:<port>` but cannot reach it. Failure surfaces only as a network error inside Claude Code.

**P2 — Stale iptables rules after crash.**
If `stop_microvm()` does not run (SIGKILL, OOM, host panic), DNAT/INPUT rules persist. Rules accumulate across sessions and cannot be identified without external state.

**P5 — `route_localnet=1` not reset.**
Sysctl persists on the TAP iface. If the iface is statically provisioned (rare but possible), the setting leaks. Low risk; cheap to fix.

Out of scope (deferred): P3 (port mismatch after shared proxy restart), P4 (baked-in upstream at attach time), P8 (guest hot-reload of port).

## Design

### Identification — comment marker

Each DNAT and INPUT rule installed by iclaude is tagged with `-m comment --comment "iclaude-pii-dnat:<tap>"`. The marker is a stable identifier that does not require external state files (no PID, no port). Iptables `comment` module is part of the Linux kernel iptables build and is universally available.

### New functions in `lib/sandbox/microvm.sh`

#### `_pii_dnat_preflight()`

Returns 0 if DNAT can be configured, 1 otherwise. Side effect: prints a warning when DNAT cannot be configured but PII proxy is active (so the user understands why the guest cannot reach the proxy).

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

Returning 0 when PII is inactive is intentional — there is no problem to flag.

The microVM still boots when preflight fails; only the DNAT block is skipped. This preserves microVM functionality for users who do not need PII masking.

#### `_pii_dnat_sweep_stale(tap_iface)`

Removes all PREROUTING and INPUT rules whose comment matches `iclaude-pii-dnat:<tap_iface>`. Idempotent. Safe to call before adding fresh rules.

```bash
_pii_dnat_sweep_stale() {
    local tap="$1"
    [[ -z "$tap" ]] && return 0
    sudo -n true 2>/dev/null || return 0

    local marker="iclaude-pii-dnat:${tap}"
    local _guard

    # Drain PREROUTING
    _guard=0
    while [[ $_guard -lt 20 ]]; do
        local _line
        _line=$(sudo -n iptables -t nat -L PREROUTING --line-numbers -n 2>/dev/null \
                | awk -v m="$marker" '$0 ~ m {print $1; exit}')
        [[ -z "$_line" ]] && break
        sudo -n iptables -t nat -D PREROUTING "$_line" 2>/dev/null || break
        _guard=$((_guard + 1))
    done

    # Drain INPUT
    _guard=0
    while [[ $_guard -lt 20 ]]; do
        local _line
        _line=$(sudo -n iptables -L INPUT --line-numbers -n 2>/dev/null \
                | awk -v m="$marker" '$0 ~ m {print $1; exit}')
        [[ -z "$_line" ]] && break
        sudo -n iptables -D INPUT "$_line" 2>/dev/null || break
        _guard=$((_guard + 1))
    done
}
```

`_guard=20` is a sanity cap. If iptables output is unparseable or `-D` keeps failing, the loop exits without hanging. Twenty is more than the realistic count of stale rules per iface (one per crashed session) and well below the cost of a runaway loop.

### Changes to `start_microvm()`

Replace the existing DNAT precondition (around line 1491):

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

Differences from current code:
- preflight call replaces the inline gate;
- sweep call before any new rule insertion;
- both `iptables -A` invocations carry `-m comment --comment "iclaude-pii-dnat:<tap>"`.

### Changes to `stop_microvm()`

Existing cleanup deletes by exact rule match. Replace with comment-based deletion to align with sweep semantics:

```bash
if [[ -n "${MICRO_VM_PII_DNAT_PORT:-}" ]] && [[ -n "${MICRO_VM_NET_HOST_IP:-}" ]] && \
   [[ -n "${MICRO_VM_NET_TAP_IFACE:-}" ]] && sudo -n true 2>/dev/null; then
    _pii_dnat_sweep_stale "${MICRO_VM_NET_TAP_IFACE}"
    sudo -n sysctl -w "net.ipv4.conf.${MICRO_VM_NET_TAP_IFACE}.route_localnet=0" &>/dev/null || true
    unset MICRO_VM_PII_DNAT_PORT
fi
```

The sweep is idempotent. Calling it from both start and stop is intentional.

## Testing

Three levels, each self-gating. Single runner: `tests/test_pii_dnat.sh`.

### L1 — Mock unit (no sudo, CI-friendly)

`tests/test_pii_dnat_unit.sh`. PATH-mocks for `sudo` and `iptables`. Covers `_pii_dnat_preflight` and `_pii_dnat_sweep_stale` in isolation.

Cases:
1. preflight: sudo unavailable → return 1, warning printed
2. preflight: PII inactive → return 0, no probes
3. preflight: happy path → return 0, no warnings
4. sweep: empty rule list → terminates fast, no infinite loop
5. sweep: 2 stale rules drained correctly
6. sweep: pathological iptables (`-D` reports success but list never empties) → guard cap fires within 20 iterations

### L2 — Real iptables, no microVM (gated by sudo)

`tests/test_pii_dnat_iptables.sh`. Uses a `dummy` interface (kernel module `dummy`, available everywhere). No KVM dependency.

Cases:
1. inject 3 stale rules with marker `iclaude-pii-dnat:iclaudetest0` → sweep removes all 3
2. inject rule with marker for a different iface → sweep does NOT remove it (per-tap scope)
3. multi-slot — inject rules for two dummy ifaces → sweep of one leaves the other intact
4. sysctl reset — set `route_localnet=1`, run cleanup path, verify back to `0`

Skips with `L2: SKIP (passwordless sudo for iptables not available)` when sudo is unavailable.

Cleanup uses targeted deletion (only rules carrying our markers); never `iptables -F`.

### L3 — Full E2E (gated by KVM + sudo + firecracker)

`tests/test_pii_dnat_e2e.sh`. Skips with explicit message when any prerequisite missing.

Requires two new debug flags in `iclaude.sh`:
- `--e2e-exit-after-boot` — clean exit immediately after microVM is up
- `--e2e-kill-after-boot` — `kill -9 $$` after microVM is up (crash simulation)

Both flags are guarded by `ICLAUDE_E2E_HEADLESS=1` env var so they cannot be invoked accidentally.

Cases:
1. clean run → DNAT marker logged during run; no marker rules after exit
2. crash simulation → stale rules remain (verifies the problem reproduces)
3. restart after crash → sweep removes stale rules + adds fresh ones; clean exit removes them

### Runner

```bash
#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
bash "$DIR/test_pii_dnat_unit.sh"      || fail=1
bash "$DIR/test_pii_dnat_iptables.sh"  || fail=1
bash "$DIR/test_pii_dnat_e2e.sh"       || fail=1
exit "$fail"
```

## Files Changed

| File | Type | Approx Lines |
|------|------|--------------|
| `lib/sandbox/microvm.sh` | edit | +60 / -10 |
| `iclaude.sh` | edit | +20 (E2E debug flags, gated) |
| `tests/test_pii_dnat_unit.sh` | new | ~120 |
| `tests/test_pii_dnat_iptables.sh` | new | ~80 |
| `tests/test_pii_dnat_e2e.sh` | new | ~60 |
| `tests/test_pii_dnat.sh` | new | ~10 |

## Non-Goals

- No host-side watcher for shared proxy port changes (P3 deferred)
- No attach-time upstream/masking compatibility check (P4 deferred)
- No guest-side hot-reload of `ANTHROPIC_BASE_URL` (P8 deferred)
- No replacement of `127.0.0.1` bind with a TAP-routable bind (would change PII proxy security model)

## Risks

1. **Comment-based deletion vs exact-match deletion:** moving `stop_microvm` cleanup to comment-based means rules added by future code paths that omit the marker would not be cleaned up. Mitigation: both `-A` sites in this design include the marker; any future rule must follow the same convention.
2. **`iptables --line-numbers` parsing:** awk extracts column 1. If iptables output format changes (different distros, different versions), the regex `$0 ~ m` still finds the row, but `$1` must remain numeric. Tested formats: iptables-legacy, iptables-nft. Both produce the same numeric-first column.
3. **Sysctl reset on iface that has been deleted:** `stop_microvm()` runs sysctl reset before iface deletion is guaranteed. If the iface is already gone, sysctl write fails silently (`|| true`). Acceptable.

## Acceptance Criteria

- L1 passes on any Linux host (no sudo).
- L2 passes when passwordless sudo for iptables is available.
- L3 passes on hosts with KVM + sudo + firecracker; otherwise skips with explicit message.
- After full test run, no `iclaude-pii-dnat:` markers remain in iptables.
- Existing `iclaude --pii-proxy --sandbox-microvm` behavior unchanged on machines with passwordless sudo.
- On machines without passwordless sudo, behavior changes from "silent guest network failure" to "explicit warning, microVM still boots".
