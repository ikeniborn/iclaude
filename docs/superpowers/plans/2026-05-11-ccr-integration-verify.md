# CCR Integration Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three CCR bugs (version flag, router.json slot format, PII proxy guard) and add an e2e integration test.

**Architecture:** No new modules — three targeted surgical edits to existing files plus one new bash test script. The launch.sh fix (Bug #3) is already applied as an uncommitted change; this plan verifies it and commits it together with the remaining fixes.

**Tech Stack:** bash, jq (runtime parse), curl (e2e test), CCR v2.0.0

---

## Pre-flight

Before starting, confirm which fixes still need to be applied:

```bash
# Should show --version (still broken):
grep -n -- '--version' lib/router/status.sh

# Should show missing ollama, prefix:
grep -n '"think"\|"longContext"' .nvm-isolated/.claude-isolated/router.json

# Should show CCR_UPSTREAM_ACTIVE in both paths (already fixed):
grep -n 'CCR_UPSTREAM_ACTIVE' lib/launcher/launch.sh
```

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/router/status.sh:34` | Modify | Fix `--version` → `-v` |
| `.nvm-isolated/.claude-isolated/router.json:44-45` | Modify | Add `ollama,` prefix to think/longContext |
| `lib/launcher/launch.sh` | Verify + commit | CCR_UPSTREAM_ACTIVE fix (already applied) |
| `tests/test_ccr_integration.sh` | Create | e2e test: start CCR, POST request, assert response |

---

## Task 1: Fix CCR Version Flag in status.sh

**Files:**
- Modify: `lib/router/status.sh:34`

- [ ] **Step 1: Verify the bug exists**

```bash
grep -n -- '--version' lib/router/status.sh
```

Expected output: `34:	local router_version=$("$ccr_cmd" --version 2>/dev/null | head -1 || echo "unknown")`

- [ ] **Step 2: Apply fix**

In `lib/router/status.sh`, change line 34:

```bash
# Before:
local router_version=$("$ccr_cmd" --version 2>/dev/null | head -1 || echo "unknown")

# After:
local router_version=$("$ccr_cmd" -v 2>/dev/null | head -1 || echo "unknown")
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n lib/router/status.sh
```

Expected: no output (syntax OK).

- [ ] **Step 4: Smoke test (requires CCR installed)**

```bash
# Only run if ccr is available; skip otherwise
ccr_cmd="$(ls .nvm-isolated/npm-global/bin/ccr 2>/dev/null || echo '')"
if [[ -n "$ccr_cmd" ]]; then
    "$ccr_cmd" -v 2>/dev/null | head -1
fi
```

Expected: single line like `claude-code-router version: 2.0.0`, exit 0.

---

## Task 2: Fix router.json Slot Format

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/router.json:44-45`

- [ ] **Step 1: Verify the bug exists**

```bash
jq '.Router | {think, longContext}' .nvm-isolated/.claude-isolated/router.json
```

Expected:
```json
{
  "think": "deepseek-v4-flash:cloud",
  "longContext": "deepseek-v4-flash:cloud"
}
```

(missing `ollama,` prefix — this is the bug)

- [ ] **Step 2: Apply fix**

In `.nvm-isolated/.claude-isolated/router.json`, change lines 44–45:

```json
    "think": "ollama,deepseek-v4-flash:cloud",
    "longContext": "ollama,deepseek-v4-flash:cloud",
```

- [ ] **Step 3: Verify JSON is valid**

```bash
jq . .nvm-isolated/.claude-isolated/router.json > /dev/null && echo "JSON OK"
```

Expected: `JSON OK`

- [ ] **Step 4: Verify the fix**

```bash
jq '.Router | {think, longContext}' .nvm-isolated/.claude-isolated/router.json
```

Expected:
```json
{
  "think": "ollama,deepseek-v4-flash:cloud",
  "longContext": "ollama,deepseek-v4-flash:cloud"
}
```

---

## Task 3: Verify launch.sh Fix (Already Applied)

**Files:**
- Verify: `lib/launcher/launch.sh` (uncommitted changes, +11/-3 vs HEAD)

- [ ] **Step 1: Confirm CCR_UPSTREAM_ACTIVE is set in reuse path**

```bash
grep -A5 'reusing existing instance' lib/launcher/launch.sh
```

Expected output must include:
```
CCR_SESSION_OWNED=false
CCR_UPSTREAM_ACTIVE=true
```
and `export CCR_UPSTREAM_ACTIVE`

- [ ] **Step 2: Confirm CCR_UPSTREAM_ACTIVE is set in fresh-start path**

```bash
grep -A4 'CCR_PID=\$!' lib/launcher/launch.sh
```

Expected output must include:
```
CCR_SESSION_OWNED=true
CCR_UPSTREAM_ACTIVE=true
export CCR_PID CCR_SESSION_OWNED CCR_UPSTREAM_ACTIVE
```

- [ ] **Step 3: Confirm shared-proxy guard uses CCR_UPSTREAM_ACTIVE**

```bash
grep -n 'CCR_UPSTREAM_ACTIVE' lib/launcher/launch.sh
```

Expected: line in `start_pii_proxy_server()` reading:
```bash
if [[ "${CCR_UPSTREAM_ACTIVE:-false}" != "true" ]]; then
```

- [ ] **Step 4: Confirm stop_ccr_server still guards by CCR_SESSION_OWNED (not changed)**

```bash
grep -A2 'stop_ccr_server' lib/launcher/launch.sh | grep 'CCR_SESSION_OWNED'
```

Expected: `if [[ "${CCR_SESSION_OWNED:-false}" != "true" ]]; then`

- [ ] **Step 5: Syntax check**

```bash
bash -n lib/launcher/launch.sh
```

Expected: no output.

> **If any of Steps 1–4 fail** (CCR_UPSTREAM_ACTIVE missing), apply the fix manually:
>
> In `start_ccr_server()` reuse path (after `CCR_SESSION_OWNED=false`):
> ```bash
> CCR_SESSION_OWNED=false
> CCR_UPSTREAM_ACTIVE=true
> export ANTHROPIC_BASE_URL="http://${CCR_HOST}:${CCR_PORT}"
> export CCR_UPSTREAM_ACTIVE
> ```
>
> In `start_ccr_server()` fresh-start path (after `CCR_PID=$!`):
> ```bash
> CCR_SESSION_OWNED=true
> CCR_UPSTREAM_ACTIVE=true
> export CCR_PID CCR_SESSION_OWNED CCR_UPSTREAM_ACTIVE
> ```
>
> In `start_pii_proxy_server()` shared-proxy guard, change:
> ```bash
> # Before:
> if [[ "${CCR_SESSION_OWNED:-false}" != "true" ]]; then
> # After:
> if [[ "${CCR_UPSTREAM_ACTIVE:-false}" != "true" ]]; then
> ```
>
> `stop_ccr_server()` guard stays `CCR_SESSION_OWNED` — do NOT change it.

---

## Task 4: Create e2e Integration Test

**Files:**
- Create: `tests/test_ccr_integration.sh`

- [ ] **Step 1: Create the test file**

```bash
cat > tests/test_ccr_integration.sh << 'TESTEOF'
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
    echo "INFO: CCR already running on :$CCR_PORT — reusing"
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
else
    echo "ERROR: Response body: $HTTP_BODY" >&2
    fail "Response does not contain 'content' key (status $HTTP_STATUS)"
fi
TESTEOF
chmod +x tests/test_ccr_integration.sh
```

- [ ] **Step 2: Verify file was created and is executable**

```bash
ls -l tests/test_ccr_integration.sh
```

Expected: file exists, `-rwxr-xr-x` permissions.

- [ ] **Step 3: Syntax check**

```bash
bash -n tests/test_ccr_integration.sh
```

Expected: no output.

- [ ] **Step 4: Dry-run**

```bash
# Run without set -e so non-zero exits don't terminate the shell:
bash tests/test_ccr_integration.sh; echo "exit code: $?"
```

Expected:
- `exit code: 77` — CCR not installed, or ollama not signed in (skip)
- `exit code: 0` — CCR installed, ollama signed in, request succeeded
- `exit code: 1` — CCR running but request failed (network, model error) — investigate response body printed to stderr

---

## Task 5: Commit All Changes

**Files:** all four touched files above.

- [ ] **Step 1: Check git status**

```bash
git status
```

Expected modified/new files:
- `M lib/launcher/launch.sh`
- `M lib/router/status.sh`
- `M .nvm-isolated/.claude-isolated/router.json`
- `?? tests/test_ccr_integration.sh`

- [ ] **Step 2: Run existing test suite to confirm no regressions**

```bash
python3 -m pytest tests/test_patterns_examples.py -v
```

Expected: all tests pass.

- [ ] **Step 3: Stage files**

```bash
git add lib/router/status.sh \
        lib/launcher/launch.sh \
        .nvm-isolated/.claude-isolated/router.json \
        tests/test_ccr_integration.sh
```

- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
fix(router): fix CCR version flag, router.json slot format, PII proxy guard + e2e test

- lib/router/status.sh: use ccr -v instead of --version (--version exits 1)
- router.json: add ollama, prefix to think/longContext slots (required for CCR routing)
- lib/launcher/launch.sh: export CCR_UPSTREAM_ACTIVE in both start_ccr_server() paths;
  change start_pii_proxy_server() shared-proxy guard to check CCR_UPSTREAM_ACTIVE
  (fixes CCR bypass when reusing existing CCR daemon with --router --pii-proxy)
- tests/test_ccr_integration.sh: e2e test — start CCR, POST to /v1/messages,
  assert response contains content; exit 77 when CCR/ollama not available
EOF
)"
```

- [ ] **Step 5: Verify commit**

```bash
git log --oneline -3
git show --stat HEAD
```

Expected: commit at HEAD touching exactly the four files above.

---

## Self-Review Against Spec

| Spec requirement | Task |
|-----------------|------|
| `status.sh`: `--version` → `-v` | Task 1 |
| `router.json`: add `ollama,` to think/longContext | Task 2 |
| `launch.sh`: `CCR_UPSTREAM_ACTIVE` in both paths, guard change | Task 3 (verify already applied) |
| `tests/test_ccr_integration.sh`: start CCR, POST, assert content | Task 4 |
| Exit 77 on skip, 0 on pass, 1 on fail | Task 4 (implemented) |
| Existing tests unaffected | Task 5, Step 2 |
| `ollama signin` not done → 401 → skip (not fail) | Task 4 (handled) |
