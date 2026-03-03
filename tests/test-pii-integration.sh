#!/usr/bin/env bash
# Integration test: parallel iclaude PII proxy sessions via actual bash functions
#
# Sources lib/ modules and calls start_pii_proxy_server() / stop_pii_proxy_server()
# exactly as iclaude.sh does — verifying per-session isolation in real conditions.
#
# Tests:
#   1.  Environment bootstrap: all PII_PROXY_* vars exported correctly
#   2.  detect_pii_proxy() returns 0 when venv + server script present
#   3-5. 3 parallel start_pii_proxy_server() calls → each succeeds
#   6.  All 3 sessions get distinct ANTHROPIC_BASE_URL ports
#   7.  Ports are in 20000-40000 range (PII_PROXY_PORT=0 auto-select)
#   8.  Per-session port files pii-proxy-{SID}.port exist while running
#   9.  Per-session PID files pii-proxy-{SID}.pid exist while running
#   10. Health endpoint responds HTTP 200 on all 3 ports
#   11. stop_pii_proxy_server() kills process and removes PID+port files
#   12. cleanup_orphaned_pii_proxies() removes stale PID files for dead processes
#   13. Legacy pii-proxy.pid migration: killed + file removed on next start

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

# ── source lib stack ──────────────────────────────────────────────────────────
# Order mirrors iclaude.sh sourcing sequence
source lib/core/logging.sh
source lib/core/init.sh
source lib/pii-proxy/detect.sh

# Stub out functions not needed for this test but referenced by launch.sh
_stub_unused() { :; }

# Source launch.sh — contains start/stop/cleanup functions
source lib/launcher/launch.sh

# ── bootstrap environment (mirrors iclaude.sh init) ──────────────────────────
export SCRIPT_DIR
ISOLATED_NVM_DIR="${SCRIPT_DIR}/.nvm-isolated"
ISOLATED_CONFIG_DIR="${ISOLATED_NVM_DIR}/.claude-isolated"
init_environment   # sets PII_PROXY_VENV, LOG_DIR, etc.

# ── helpers ───────────────────────────────────────────────────────────────────
PASS=0; FAIL=0
ALL_PIDS=()

ok()   { echo "  ✓  $*"; ((PASS++)); }
fail() { echo "  ✗  $*"; ((FAIL++)); }

cleanup_all() {
    for pid in "${ALL_PIDS[@]:-}"; do
        kill "$pid" 2>/dev/null || true
    done
    # Remove test artefacts
    rm -f "${ISOLATED_CONFIG_DIR}"/pii-proxy-test*.{pid,port} 2>/dev/null
    rm -f "${PII_PROXY_LOG_DIR}"/pii-proxy-test*.port 2>/dev/null
}
trap cleanup_all EXIT

# Serialise results from parallel subshells via temp files
TMPDIR_RESULTS="$(mktemp -d)"

# Run one session in a subshell; writes results to $TMPDIR_RESULTS/session-N
# stdout → result_file (OK/FAIL line), stderr → /dev/null (suppress print_info noise)
run_session() {
    local n="$1"
    local sid="$2"
    local result_file="${TMPDIR_RESULTS}/session-${n}"

    (
        # Each subshell gets its own session-scoped variables
        export ICLAUDE_SESSION_ID="$sid"
        export PII_PROXY_PID_FILE="${ISOLATED_CONFIG_DIR}/pii-proxy-${sid}.pid"
        export ANTHROPIC_BASE_URL="https://api.anthropic.com"
        export PII_PROXY_PORT=0
        export PII_PROXY_ACTIVE_PORT=""

        if start_pii_proxy_server "false" 2>/dev/null; then
            echo "OK port=$PII_PROXY_ACTIVE_PORT"
        else
            echo "FAIL"
        fi
    ) > "$result_file"
}

echo ""
echo "══════════════════════════════════════════════════════"
echo "  iclaude PII proxy — integration test (real bash fns)"
echo "══════════════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Test 1: environment bootstrap
# ─────────────────────────────────────────────────────────────────────────────
echo "▶ Test 1: Environment bootstrap"
if [[ -n "${PII_PROXY_VENV:-}" && -n "${PII_PROXY_LOG_DIR:-}" && \
      -n "${PII_PROXY_SERVER_SCRIPT:-}" && -n "${ICLAUDE_SESSION_ID:-}" ]]; then
    ok "All PII_PROXY_* vars set (VENV=$PII_PROXY_VENV)"
else
    fail "Missing PII_PROXY vars after init_global_vars()"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Test 2: detect_pii_proxy
# ─────────────────────────────────────────────────────────────────────────────
echo "▶ Test 2: detect_pii_proxy()"
if detect_pii_proxy "false"; then
    ok "detect_pii_proxy() → installed (venv + server script present)"
else
    fail "detect_pii_proxy() → not installed (run --install-pii-proxy)"
    echo ""
    echo "  Cannot continue without PII proxy installation."
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Tests 3-5: start 3 sessions in parallel
# ─────────────────────────────────────────────────────────────────────────────
echo "▶ Tests 3-5: start 3 parallel sessions"

# Generate 3 unique 12-hex session IDs (same format as iclaude.sh)
SID1=$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')
SID2=$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')
SID3=$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')
SIDS=("$SID1" "$SID2" "$SID3")

# Start sessions in parallel
run_session 1 "$SID1" &
run_session 2 "$SID2" &
run_session 3 "$SID3" &
wait

# Parse results
declare -A SESSION_PORTS SESSION_PIDS
ALL_OK=true

for n in 1 2 3; do
    result_file="${TMPDIR_RESULTS}/session-${n}"
    sid="${SIDS[$((n-1))]}"
    result=$(cat "$result_file" 2>/dev/null || echo "FAIL no output")

    # print_info writes to stdout, so result_file may contain log lines before "OK ..."
    # Use grep to find the OK line regardless of position
    ok_line=$(grep '^OK' "$result_file" 2>/dev/null || true)
    if [[ -n "$ok_line" ]]; then
        port=$(echo "$ok_line" | grep -oP 'port=\K[0-9]+')
        SESSION_PORTS[$n]="$port"
        pid=$(cat "${ISOLATED_CONFIG_DIR}/pii-proxy-${sid}.pid" 2>/dev/null || echo "")
        SESSION_PIDS[$n]="$pid"
        [[ -n "$pid" ]] && ALL_PIDS+=("$pid")
        ok "Session $n (${sid:0:8}…): started on port $port (PID $pid)"
    else
        fail "Session $n (${sid:0:8}…): failed — $(cat "$result_file" 2>/dev/null | tail -1)"
        ALL_OK=false
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Tests 6-7: port uniqueness + range
# ─────────────────────────────────────────────────────────────────────────────
echo "▶ Tests 6-7: port uniqueness and range"

if [[ "$ALL_OK" == "true" ]]; then
    ports=(${SESSION_PORTS[1]} ${SESSION_PORTS[2]} ${SESSION_PORTS[3]})
    unique=$(printf '%s\n' "${ports[@]}" | sort -u | wc -l)
    if [[ $unique -eq 3 ]]; then
        ok "All 3 ports unique: ${ports[*]}"
    else
        fail "Port collision: ${ports[*]}"
    fi

    in_range=true
    for p in "${ports[@]}"; do
        if (( p < 20000 || p > 40000 )); then
            fail "Port $p outside range 20000-40000"
            in_range=false
        fi
    done
    [[ "$in_range" == "true" ]] && ok "All ports in range 20000-40000"
else
    fail "Skipped port checks (not all sessions started)"
    fail "Skipped port range check"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Tests 8-9: per-session port and PID files
# ─────────────────────────────────────────────────────────────────────────────
echo "▶ Tests 8-9: per-session port and PID files"

for n in 1 2 3; do
    sid="${SIDS[$((n-1))]}"
    port_file="${PII_PROXY_LOG_DIR}/pii-proxy-${sid}.port"
    pid_file="${ISOLATED_CONFIG_DIR}/pii-proxy-${sid}.pid"

    if [[ -f "$port_file" ]]; then
        ok "Session $n: port file $port_file exists"
    else
        fail "Session $n: port file missing: $port_file"
    fi

    if [[ -f "$pid_file" ]]; then
        ok "Session $n: PID file $pid_file exists"
    else
        fail "Session $n: PID file missing: $pid_file"
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Test 10: health check on all 3 ports
# ─────────────────────────────────────────────────────────────────────────────
echo "▶ Test 10: health check on all 3 ports"
PYTHON_BIN="${PII_PROXY_VENV}/bin/python3"

for n in 1 2 3; do
    port="${SESSION_PORTS[$n]:-}"
    [[ -z "$port" ]] && { fail "Session $n: no port"; continue; }
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://127.0.0.1:${port}/api/health" 2>/dev/null || echo "000")
    if [[ "$http_code" == "200" ]]; then
        ok "Session $n port $port: /api/health → HTTP $http_code"
    else
        fail "Session $n port $port: /api/health → HTTP $http_code"
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# Test 11: stop_pii_proxy_server cleans up PID + port files
# ─────────────────────────────────────────────────────────────────────────────
echo "▶ Test 11: stop_pii_proxy_server() cleanup"

# Stop session 1 cleanly
(
    export ICLAUDE_SESSION_ID="$SID1"
    export PII_PROXY_PID_FILE="${ISOLATED_CONFIG_DIR}/pii-proxy-${SID1}.pid"
    stop_pii_proxy_server
) 2>/dev/null

pid_file="${ISOLATED_CONFIG_DIR}/pii-proxy-${SID1}.pid"
port_file="${PII_PROXY_LOG_DIR}/pii-proxy-${SID1}.port"

if [[ ! -f "$pid_file" ]]; then
    ok "Session 1: PID file removed after stop"
else
    fail "Session 1: PID file still exists after stop"
fi
if [[ ! -f "$port_file" ]]; then
    ok "Session 1: port file removed after stop"
else
    fail "Session 1: port file still exists after stop"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Test 12: cleanup_orphaned_pii_proxies removes stale PID files
# ─────────────────────────────────────────────────────────────────────────────
echo "▶ Test 12: cleanup_orphaned_pii_proxies()"

# Create a stale PID file pointing to a non-existent process
stale_sid="ccccdd001122"
stale_pid_file="${ISOLATED_CONFIG_DIR}/pii-proxy-${stale_sid}.pid"
stale_port_file="${PII_PROXY_LOG_DIR}/pii-proxy-${stale_sid}.port"
echo "999999" > "$stale_pid_file"  # PID that doesn't exist
echo "39999"  > "$stale_port_file"

cleanup_orphaned_pii_proxies

if [[ ! -f "$stale_pid_file" ]]; then
    ok "Stale PID file for dead process removed by cleanup_orphaned_pii_proxies()"
else
    fail "Stale PID file NOT removed"
fi
if [[ ! -f "$stale_port_file" ]]; then
    ok "Stale port file removed together with PID file"
else
    fail "Stale port file NOT removed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Test 13: legacy pii-proxy.pid migration
# ─────────────────────────────────────────────────────────────────────────────
echo "▶ Test 13: legacy pii-proxy.pid migration"

legacy_pid_file="${ISOLATED_CONFIG_DIR}/pii-proxy.pid"
# Create a fake legacy PID file pointing to a dead process
echo "888888" > "$legacy_pid_file"

# Start a new session — start_pii_proxy_server should remove the legacy file
sid_new=$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')
(
    export ICLAUDE_SESSION_ID="$sid_new"
    export PII_PROXY_PID_FILE="${ISOLATED_CONFIG_DIR}/pii-proxy-${sid_new}.pid"
    export ANTHROPIC_BASE_URL="https://api.anthropic.com"
    export PII_PROXY_PORT=0
    export PII_PROXY_ACTIVE_PORT=""
    start_pii_proxy_server "false" >/dev/null 2>&1
    stop_pii_proxy_server >/dev/null 2>&1
) 2>/dev/null

if [[ ! -f "$legacy_pid_file" ]]; then
    ok "Legacy pii-proxy.pid removed during new session start"
else
    fail "Legacy pii-proxy.pid still exists"
    rm -f "$legacy_pid_file"
fi

# ── cleanup remaining sessions 2 and 3 ────────────────────────────────────────
for n in 2 3; do
    sid="${SIDS[$((n-1))]}"
    (
        export ICLAUDE_SESSION_ID="$sid"
        export PII_PROXY_PID_FILE="${ISOLATED_CONFIG_DIR}/pii-proxy-${sid}.pid"
        stop_pii_proxy_server
    ) 2>/dev/null
done

rm -rf "$TMPDIR_RESULTS"

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
TOTAL=$((PASS + FAIL))
echo "  Results: ${PASS}/${TOTAL} passed"
if (( FAIL > 0 )); then
    echo "  FAILED: ${FAIL} test(s)"
    echo "══════════════════════════════════════════════════════"
    echo ""
    exit 1
fi
echo "  All tests passed"
echo "══════════════════════════════════════════════════════"
echo ""
