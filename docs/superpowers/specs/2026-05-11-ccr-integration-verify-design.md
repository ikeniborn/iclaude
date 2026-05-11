# CCR Integration Verification — Design

**Date:** 2026-05-11  
**Status:** Approved  
**Scope:** Bug fixes + e2e integration test for Claude Code Router with Ollama cloud models

---

## Problem Statement

CCR v2.0.0 is installed and `router.json` is configured, but two bugs prevent reliable use:

1. **`lib/router/status.sh`**: version detection calls `ccr --version` — CCR does not support this flag, outputs help text with exit code 1. `iclaude.sh` uses `set -euo pipefail`, so with pipefail active: `ccr --version | head -1` exits 1 → `|| echo "unknown"` fires → `router_version=$'\nunknown'` (leading newline from head + "unknown" from echo) → displays as two broken lines: `  Version: ` then `unknown`. Fix: use `ccr -v` (exits 0, outputs single clean line).

2. **`router.json`**: `think` and `longContext` slots contain `"deepseek-v4-flash:cloud"` without provider prefix. CCR cannot route requests — requires `"ollama,deepseek-v4-flash:cloud"` format.

3. **`lib/launcher/launch.sh`**: wrong shared-proxy guard in `start_pii_proxy_server()` — when `--router --pii-proxy` is used and CCR is **already running** on port 3456 (started by another session), `start_ccr_server()` sets `CCR_SESSION_OWNED=false`. The shared-proxy guard `CCR_SESSION_OWNED != true` then allows attaching to an existing shared proxy whose upstream was baked as `api.anthropic.com` by an earlier `--pii-proxy` session. Result: traffic routes `claude → shared_proxy → api.anthropic.com`, bypassing CCR entirely. Same bug in microVM+CCR+PII path.

   Fix: introduce `CCR_UPSTREAM_ACTIVE=true` exported in both paths of `start_ccr_server()` (fresh start AND reuse). Change shared-proxy guard to check `CCR_UPSTREAM_ACTIVE` instead of `CCR_SESSION_OWNED`.

---

## Architecture

No new modules. Changes touch three existing files + one new test script.

```
lib/router/status.sh          ← fix ccr version flag
lib/launcher/launch.sh        ← fix CCR_UPSTREAM_ACTIVE guard in shared PII proxy logic
.nvm-isolated/.claude-isolated/router.json  ← fix think/longContext slots
tests/test_ccr_integration.sh ← new e2e test (bash)
```

---

## Components

### 1. `lib/router/status.sh` — version fix

**Change:** Line ~34

```bash
# Before
local router_version=$("$ccr_cmd" --version 2>/dev/null | head -1 || echo "unknown")

# After (ccr -v outputs: "claude-code-router version: 2.0.0", exits 0)
local router_version=$("$ccr_cmd" -v 2>/dev/null | head -1 || echo "unknown")
```

`HOME=` is not needed — `ccr -v` does not read HOME (verified: `HOME=/tmp ccr -v` returns correct version).

### 2. `router.json` — slot format fix

**Change:** `think` and `longContext` slots

```json
// Before
"think": "deepseek-v4-flash:cloud",
"longContext": "deepseek-v4-flash:cloud",

// After  
"think": "ollama,deepseek-v4-flash:cloud",
"longContext": "ollama,deepseek-v4-flash:cloud",
```

### 3. `lib/launcher/launch.sh` — shared PII proxy guard fix

**Root cause:** `CCR_SESSION_OWNED` only marks sessions that **started** CCR. When CCR is reused (`CCR_SESSION_OWNED=false`), `start_pii_proxy_server()` falls into shared proxy mode — potentially attaching to a proxy with wrong upstream (`api.anthropic.com` instead of `http://CCR:3456`).

**Change:** `start_ccr_server()` — export `CCR_UPSTREAM_ACTIVE=true` in both paths:

```bash
# Reuse path (was missing CCR_UPSTREAM_ACTIVE):
CCR_SESSION_OWNED=false
CCR_UPSTREAM_ACTIVE=true
export ANTHROPIC_BASE_URL="http://${CCR_HOST}:${CCR_PORT}"
export CCR_UPSTREAM_ACTIVE

# Fresh start path (was missing CCR_UPSTREAM_ACTIVE):
CCR_SESSION_OWNED=true
CCR_UPSTREAM_ACTIVE=true
export CCR_PID CCR_SESSION_OWNED CCR_UPSTREAM_ACTIVE
```

**Change:** `start_pii_proxy_server()` shared-proxy guard:

```bash
# Before
if [[ "${CCR_SESSION_OWNED:-false}" != "true" ]]; then

# After
if [[ "${CCR_UPSTREAM_ACTIVE:-false}" != "true" ]]; then
```

`stop_ccr_server()` remains guarded by `CCR_SESSION_OWNED` (correct — only kill CCR if this session started it).

### 4. `tests/test_ccr_integration.sh` — e2e test

**Flow:**
1. Detect CCR binary and router.json (skip if missing — not an error, just unsupported)
2. Start CCR: `HOME=$CCR_HOME ccr start`
3. Poll `127.0.0.1:3456` until ready (max 10s)
4. Send Anthropic-format request via curl to `http://127.0.0.1:3456/v1/messages`
   ```bash
   curl -s http://127.0.0.1:3456/v1/messages \
     -H "x-api-key: test" \
     -H "anthropic-version: 2023-06-01" \
     -H "Content-Type: application/json" \
     -d '{"model":"claude-sonnet-4-5","max_tokens":50,"messages":[{"role":"user","content":"Say OK"}]}'
   ```
   - Model `claude-sonnet-4-5` → CCR routes to `default` slot → `ollama,kimi-k2.6:cloud`
   - `max_tokens` required by Anthropic API schema
   - `x-api-key: test` — CCR accepts any token in local mode
5. Assert response contains `"content"` key (success) OR print clear error with response body
6. Stop CCR: `ccr stop`

**Exit codes:** 0 = pass, 1 = fail, 77 = skipped (CCR not installed)

---

## Data Flow

```
test_ccr_integration.sh
  ├─ ccr start (daemon)
  ├─ curl POST http://127.0.0.1:3456/v1/messages
  │     headers: x-api-key:test, anthropic-version:2023-06-01
  │     body: { model:"claude-sonnet-4-5", max_tokens:50, messages:[...] }
  ├─ CCR: "claude-sonnet-4-5" → default slot → ollama,kimi-k2.6:cloud
  ├─ Ollama cloud → kimi-k2.6:cloud backend
  ├─ assert response contains "content"
  └─ ccr stop
```

---

## Error Handling

- CCR not installed → skip (exit 77), not fail
- CCR port not ready in 10s → fail with message
- curl non-2xx → print response body, fail
- `ollama signin` not done → request will fail with 401; test prints clear message

---

## Testing Strategy

Run manually before committing:
```bash
bash tests/test_ccr_integration.sh
```

Existing test suite unaffected:
```bash
python3 -m pytest tests/test_patterns_examples.py -v
```

---

## Out of Scope

- Local qwen3.5 models in router.json (separate task)
- microVM + CCR + PII e2e testing (bug fixed in launch.sh, but full microVM test requires running VM)
