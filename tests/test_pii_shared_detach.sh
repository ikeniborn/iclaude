#!/usr/bin/env bash
# Regression test: shared PII proxy must survive SIGHUP/SIGINT delivered
# to the process group of the iclaude master that started it.
#
# Two assertions:
#   A) STATIC: launch.sh shared-start branch contains `setsid "$python_bin"`
#      and `</dev/null`. Catches accidental revert.
#   B) BEHAVIOURAL: spawn a synthetic master in its own session that starts
#      the proxy via the same idiom (setsid + </dev/null), then deliver
#      SIGHUP to the master's PG. Proxy must remain alive.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCH_SH="$REPO_ROOT/lib/launcher/launch.sh"
SERVER_SCRIPT="$REPO_ROOT/lib/pii-proxy/server.py"
PYTHON_BIN="${PII_TEST_PYTHON:-$REPO_ROOT/.nvm-isolated/.claude-isolated/pii-proxy-venv/bin/python3}"

# ---------------------------------------------------------------------------
# Assertion A — static
# ---------------------------------------------------------------------------
if ! grep -qE 'setsid[[:space:]]+"\$python_bin"[[:space:]]+"\$PII_PROXY_SERVER_SCRIPT"' "$LAUNCH_SH"; then
    echo "FAIL[A]: launch.sh does not contain 'setsid \"\$python_bin\" \"\$PII_PROXY_SERVER_SCRIPT\"' — fix missing or reverted"
    exit 1
fi
if ! grep -qE '</dev/null[[:space:]]+>/dev/null[[:space:]]+2>&1[[:space:]]+9>&-' "$LAUNCH_SH"; then
    echo "FAIL[A]: launch.sh shared-start branch does not redirect stdin from /dev/null"
    exit 1
fi
echo "PASS[A]: launch.sh contains the post-fix idiom"

# ---------------------------------------------------------------------------
# Assertion B — behavioural (skip if pii-proxy venv not installed)
# ---------------------------------------------------------------------------
if [[ ! -x "$PYTHON_BIN" ]]; then
    echo "SKIP[B]: pii-proxy venv not installed at $PYTHON_BIN (run --install-pii-proxy)"
    exit 0
fi

LOG_DIR="$(mktemp -d)"
MASTER_PID=""
PROXY_PID=""

cleanup() {
    [[ -n "$PROXY_PID" ]] && kill "$PROXY_PID" 2>/dev/null
    [[ -n "$MASTER_PID" ]] && kill -TERM "$MASTER_PID" 2>/dev/null
    sleep 0.3
    [[ -n "$PROXY_PID" ]] && kill -9 "$PROXY_PID" 2>/dev/null
    [[ -n "$MASTER_PID" ]] && kill -9 "$MASTER_PID" 2>/dev/null
    rm -rf "$LOG_DIR"
}
trap cleanup EXIT

fake_master() {
    ANTHROPIC_UPSTREAM_URL="https://api.anthropic.com" \
    ICLAUDE_SESSION_ID="shared" \
    PII_PROXY_LOG_LEVEL="info" \
        setsid "$1" "$2" \
        --port 0 \
        --log-dir "$3" \
        </dev/null >/dev/null 2>&1 &
    local pid=$!
    disown "$pid" 2>/dev/null || true
    echo "$pid" > "$3/proxy.pid"
    sleep 30
}

setsid bash -c "$(declare -f fake_master); fake_master '$PYTHON_BIN' '$SERVER_SCRIPT' '$LOG_DIR'" &
MASTER_PID=$!

for _ in $(seq 1 40); do
    [[ -f "$LOG_DIR/pii-proxy-shared.port" ]] && break
    sleep 0.25
done

if [[ ! -f "$LOG_DIR/pii-proxy-shared.port" ]]; then
    echo "FAIL[B]: proxy never bound a port within 10s"
    exit 1
fi

PROXY_PID=$(cat "$LOG_DIR/proxy.pid")

if ! kill -0 "$PROXY_PID" 2>/dev/null; then
    echo "FAIL[B]: proxy died before signal delivery"
    exit 1
fi

master_sid=$(ps -o sid= -p "$MASTER_PID" 2>/dev/null | tr -d ' ')
proxy_sid=$(ps -o sid= -p "$PROXY_PID" 2>/dev/null | tr -d ' ')
if [[ -z "$master_sid" || -z "$proxy_sid" || "$master_sid" == "$proxy_sid" ]]; then
    echo "FAIL[B]: proxy SID ($proxy_sid) == master SID ($master_sid); setsid did not detach"
    exit 1
fi
echo "INFO: master sid=$master_sid proxy sid=$proxy_sid (distinct)"

kill -HUP -"$MASTER_PID" 2>/dev/null
sleep 1

if kill -0 "$PROXY_PID" 2>/dev/null; then
    echo "PASS[B]: proxy survived SIGHUP to master PG"
    exit 0
else
    echo "FAIL[B]: proxy died with master PG"
    exit 1
fi
