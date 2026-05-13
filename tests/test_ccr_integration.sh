#!/usr/bin/env bash
# e2e integration test for Claude Code Router with Ollama cloud models.
# Exit codes: 0=pass, 1=fail, 77=skip (CCR not installed / ollama not signed in)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CCR_PORT=3456
CCR_HOST=127.0.0.1

# ── helpers ──────────────────────────────────────────────────────────────────

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
skip() { echo "SKIP: $*"; exit 77; }

# ── locate ccr binary ─────────────────────────────────────────────────────────

CCR_CMD=""
for _candidate in \
    "$REPO_ROOT/.nvm-isolated/npm-global/bin/ccr" \
    "$(command -v ccr 2>/dev/null || true)"; do
    if [[ -x "$_candidate" ]]; then
        CCR_CMD="$_candidate"
        break
    fi
done
[[ -z "$CCR_CMD" ]] && skip "ccr binary not found (run: ./iclaude.sh --install-router)"

# ── locate router.json ────────────────────────────────────────────────────────

ROUTER_JSON="$REPO_ROOT/.nvm-isolated/.claude-isolated/router.json"
[[ -f "$ROUTER_JSON" ]] || skip "router.json not found at $ROUTER_JSON"

# ── set up CCR_HOME in isolated env ───────────────────────────────────────────

CCR_HOME="$REPO_ROOT/.nvm-isolated/.claude-isolated"
mkdir -p "$CCR_HOME/.claude-code-router"
cp "$ROUTER_JSON" "$CCR_HOME/.claude-code-router/config.json"

# Prepend node v20+ to PATH (CCR requirement)
_node20_bin=$(find "$REPO_ROOT/.nvm-isolated/versions/node" -maxdepth 1 -type d \
    -name "v2[0-9]*" 2>/dev/null | LC_ALL=C sort | tail -1)
if [[ -n "$_node20_bin" && -d "$_node20_bin/bin" ]]; then
    export PATH="$_node20_bin/bin:$PATH"
fi

# ── check CCR not already running (we manage the lifecycle) ──────────────────

_ccr_was_running=false
if (: >/dev/tcp/"$CCR_HOST"/"$CCR_PORT") 2>/dev/null; then
    echo "INFO: CCR already running on :$CCR_PORT — reusing (config may differ from router.json)"
    _ccr_was_running=true
fi

# ── start CCR ────────────────────────────────────────────────────────────────

CCR_PID=""
_cleanup() {
    if [[ "$_ccr_was_running" == "false" && -n "$CCR_PID" ]]; then
        kill "$CCR_PID" 2>/dev/null || true
        # Give CCR up to 2s to shut down before force-kill
        local _w=0
        while kill -0 "$CCR_PID" 2>/dev/null && [[ $_w -lt 20 ]]; do
            sleep 0.1; _w=$((_w+1))
        done
        kill -9 "$CCR_PID" 2>/dev/null || true
    fi
}
trap _cleanup EXIT INT TERM

if [[ "$_ccr_was_running" == "false" ]]; then
    HOME="$CCR_HOME" "$CCR_CMD" start >/tmp/ccr-test-start.log 2>&1 &
    CCR_PID=$!
    echo "INFO: CCR starting (PID $CCR_PID)..."

    # Poll up to 10s (20 × 0.5s)
    _ready=false
    for _i in $(seq 1 20); do
        if ! kill -0 "$CCR_PID" 2>/dev/null; then
            fail "CCR process exited unexpectedly. Log: $(cat /tmp/ccr-test-start.log 2>/dev/null)"
        fi
        if (: >/dev/tcp/"$CCR_HOST"/"$CCR_PORT") 2>/dev/null; then
            _ready=true; break
        fi
        sleep 0.5
    done
    [[ "$_ready" == "true" ]] || fail "CCR not ready after 10s on :$CCR_PORT"
    echo "INFO: CCR ready on :$CCR_PORT"
fi

# ── send test request ─────────────────────────────────────────────────────────
# Model claude-sonnet-4-5 routes to default slot → ollama,kimi-k2.6:cloud

RESPONSE=$(curl -s -w '\n__HTTP_STATUS__%{http_code}' \
    "http://$CCR_HOST:$CCR_PORT/v1/messages" \
    -H "x-api-key: test" \
    -H "anthropic-version: 2023-06-01" \
    -H "Content-Type: application/json" \
    -d '{"model":"claude-sonnet-4-5","max_tokens":50,"messages":[{"role":"user","content":"Say OK"}]}' \
    2>/dev/null) \
    || fail "curl failed to connect to CCR on :$CCR_PORT"

HTTP_BODY="${RESPONSE%$'\n__HTTP_STATUS__'*}"
HTTP_STATUS="${RESPONSE##*__HTTP_STATUS__}"

echo "INFO: HTTP status: $HTTP_STATUS"

# ── assert ────────────────────────────────────────────────────────────────────

# 401 means ollama signin not completed — skip, not fail
if [[ "$HTTP_STATUS" == "401" ]]; then
    skip "CCR returned 401 — run 'ollama signin' first, then re-run this test"
fi

# Response must contain "content" key
if echo "$HTTP_BODY" | grep -q '"content"'; then
    pass "CCR routed request successfully (status $HTTP_STATUS, response contains 'content')"
    # Check that text content is non-empty (reasoning transformer plugin working)
    TEXT=$(echo "$HTTP_BODY" | python3 -c "
import json,sys
r=json.load(sys.stdin)
print(' '.join(b.get('text','') for b in r.get('content',[]) if b.get('type')=='text'))
" 2>/dev/null || true)
    if [[ -n "${TEXT// /}" ]]; then
        pass "Text content non-empty (reasoning→content transform working)"
    else
        echo "WARN: 'content' key present but text blocks empty — plugin may not be active" >&2
    fi
else
    echo "ERROR: Response body: $HTTP_BODY" >&2
    fail "Response does not contain 'content' key (status $HTTP_STATUS)"
fi
