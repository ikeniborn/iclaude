#!/usr/bin/env bash
# Integration tests for the PII proxy fork-respawn supervisor.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVER="$REPO_ROOT/.claude-isolated/pii-proxy-server.py"

pass() { echo "PASS[$1]: $2"; }
fail() { echo "FAIL[$1]: $2"; cleanup; exit 1; }

PY="$REPO_ROOT/.claude-isolated/pii-proxy-venv/bin/python3"
[[ -x "$PY" ]] || PY="python3"
command -v "$PY" >/dev/null 2>&1 || { echo "SKIP: python3 not found"; exit 0; }
[[ -f "$SERVER" ]] || { echo "SKIP: server script not found"; exit 0; }

TMP="$(mktemp -d)"
SUP_PID=""
cleanup() {
    [[ -n "$SUP_PID" ]] && kill -TERM "$SUP_PID" 2>/dev/null
    sleep 0.3
    [[ -n "$SUP_PID" ]] && kill -9 "$SUP_PID" 2>/dev/null
    rm -rf "$TMP"
}
trap cleanup EXIT

health() { # $1 = port
    "$PY" - "$1" <<'PYEOF' 2>/dev/null
import sys, urllib.request
try:
    urllib.request.urlopen("http://127.0.0.1:"+sys.argv[1]+"/api/health", timeout=2); sys.exit(0)
except Exception:
    sys.exit(1)
PYEOF
}

# Launch supervisor
PII_PROXY_SUPERVISE=true \
ANTHROPIC_UPSTREAM_URL="http://127.0.0.1:9999" \
ICLAUDE_SESSION_ID="shared" \
PII_PROXY_LOG_DIR="$TMP" \
    setsid "$PY" "$SERVER" --port 0 --log-dir "$TMP" </dev/null >/dev/null 2>&1 &
SUP_PID=$!

# Wait for port file + health (max 15s)
PORT=""
for _ in $(seq 1 30); do
    if [[ -f "$TMP/pii-proxy-shared.port" ]]; then
        PORT="$(cat "$TMP/pii-proxy-shared.port" 2>/dev/null)"
        [[ "$PORT" =~ ^[0-9]+$ ]] && health "$PORT" && break
    fi
    sleep 0.5
done
[[ "$PORT" =~ ^[0-9]+$ ]] && health "$PORT" || fail "S1" "supervisor did not become healthy"
pass "S1" "supervisor healthy on :$PORT"

# Identify the worker (child of supervisor) and kill -9 it
WORKER="$(pgrep -P "$SUP_PID" 2>/dev/null | head -1)"
[[ -n "$WORKER" ]] || fail "S2" "no worker child found"
kill -9 "$WORKER" 2>/dev/null
pass "S2" "killed worker $WORKER"

# Respawn: same port healthy again within ~3s, new worker pid
NEWHEALTH=false
for _ in $(seq 1 6); do
    sleep 0.5
    if health "$PORT"; then NEWHEALTH=true; break; fi
done
[[ "$NEWHEALTH" == "true" ]] || fail "S3" "proxy did not respawn on same port :$PORT"
NEWPORT="$(cat "$TMP/pii-proxy-shared.port" 2>/dev/null)"
[[ "$NEWPORT" == "$PORT" ]] || fail "S3" "port changed after respawn ($PORT -> $NEWPORT)"
NEWWORKER="$(pgrep -P "$SUP_PID" 2>/dev/null | head -1)"
[[ -n "$NEWWORKER" && "$NEWWORKER" != "$WORKER" ]] || fail "S3" "no fresh worker after respawn"
pass "S3" "respawned on same port :$PORT (worker $WORKER -> $NEWWORKER)"

# Clean stop: SIGTERM supervisor -> both gone, port file removed, no respawn
kill -TERM "$SUP_PID" 2>/dev/null
STOPPED=false
for _ in $(seq 1 20); do
    sleep 0.2
    kill -0 "$SUP_PID" 2>/dev/null || { STOPPED=true; break; }
done
[[ "$STOPPED" == "true" ]] || fail "S4" "supervisor did not exit on SIGTERM"
sleep 0.5
[[ -z "$(pgrep -P "$SUP_PID" 2>/dev/null)" ]] || fail "S4" "worker still alive after stop"
[[ ! -f "$TMP/pii-proxy-shared.port" ]] || fail "S4" "port file not removed on stop"
SUP_PID=""
pass "S4" "clean stop: supervisor + worker gone, port file removed"

echo "ALL PASS"
