# CCR Reasoning Transformer Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `ollama-reasoning.js` — a CCR transformer plugin that copies `delta.reasoning` to `delta.content` in Ollama SSE stream so kimi-k2.6:cloud output is visible to Claude Code as text.

**Architecture:** Custom CCR plugin registered in `transformerService` by name, then wired into the `ollama` provider's `transformer.use` chain. The plugin wraps the raw Ollama SSE stream and, for each chunk where `delta.reasoning` is non-empty and `delta.content` is empty, copies reasoning text to content. Placed last in `use` array so it runs first (CCR applies `use` in reverse order). Path stored as absolute in `router.json` (file is gitignored; path is machine-specific).

**Tech Stack:** Node.js CommonJS module (no dependencies), Web Streams API (TransformStream, TextEncoder/TextDecoder — Node 18+), jq, bash

---

## Pre-flight: understand the pipeline

Before writing code, confirm the exact execution order.

CCR applies `transformer.use` transformers **in reverse array order** (from `dD()` in `cli.js`):
```
use: ["reasoning", ["sampling", {...}], "ollama-reasoning"]
         ↑ applied 3rd            ↑ applied 1st (raw Ollama SSE)
```

This means:
1. `ollama-reasoning` sees raw Ollama SSE with `delta.reasoning` → copies to `delta.content`
2. `sampling` runs on the modified stream
3. `reasoning` runs on that, creating Anthropic thinking blocks AND preserving `delta.content`

Result: Claude Code gets both `delta.content` (text) and thinking blocks.

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `.nvm-isolated/.claude-isolated/.claude-code-router/plugins/ollama-reasoning.js` | Create | CCR transformer class |
| `.nvm-isolated/.claude-isolated/router.json` | Modify | Add `transformers` key + wire into `use` arrays |
| `.nvm-isolated/.claude-isolated/.claude-code-router/config.json` | Copied | Copied from `router.json` by `iclaude --router` launcher or manually in Task 3 Step 2 |

---

## Task 1: Create the plugin file

**Files:**
- Create: `.nvm-isolated/.claude-isolated/.claude-code-router/plugins/ollama-reasoning.js`

- [ ] **Step 1: Create plugin directory**

```bash
mkdir -p .nvm-isolated/.claude-isolated/.claude-code-router/plugins/
ls .nvm-isolated/.claude-isolated/.claude-code-router/plugins/
```

Expected: directory exists (may be empty).

- [ ] **Step 2: Create the plugin file**

Write `.nvm-isolated/.claude-isolated/.claude-code-router/plugins/ollama-reasoning.js`:

```js
'use strict';

/**
 * CCR transformer: copies delta.reasoning → delta.content for Ollama reasoning models.
 * Applied before the built-in `reasoning` transformer (place last in `use` array —
 * CCR applies use[] in reverse order).
 */
class OllamaReasoningTransformer {
  constructor(options) {
    this.name = 'ollama-reasoning';
    this.options = options || {};
  }

  _transformSseLine(line) {
    if (!line.startsWith('data: ')) return line;
    const data = line.slice(6);
    if (data === '[DONE]') return line;
    let parsed;
    try {
      parsed = JSON.parse(data);
    } catch {
      return line;
    }
    let modified = false;
    for (const choice of parsed?.choices ?? []) {
      if (choice.delta !== undefined) {
        const r = choice.delta.reasoning || choice.delta.reasoning_content || '';
        if (r && !choice.delta.content) {
          choice.delta.content = r;
          modified = true;
        }
      }
    }
    return modified ? 'data: ' + JSON.stringify(parsed) : line;
  }

  async transformResponseOut(response) {
    const ct = response?.headers?.get?.('Content-Type') || '';

    if (ct.includes('text/event-stream') && response.body) {
      const self = this;
      const dec = new TextDecoder();
      const enc = new TextEncoder();
      let buf = '';

      const xform = new TransformStream({
        transform(chunk, ctrl) {
          buf += dec.decode(chunk, { stream: true });
          const nl = buf.lastIndexOf('\n');
          if (nl >= 0) {
            const complete = buf.slice(0, nl + 1);
            buf = buf.slice(nl + 1);
            const out = complete
              .split('\n')
              .map(line => self._transformSseLine(line))
              .join('\n');
            ctrl.enqueue(enc.encode(out));
          }
        },
        flush(ctrl) {
          if (buf) {
            const out = buf
              .split('\n')
              .map(line => self._transformSseLine(line))
              .join('\n');
            ctrl.enqueue(enc.encode(out));
          }
        }
      });

      return new Response(response.body.pipeThrough(xform), {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers
      });
    }

    if (ct.includes('application/json')) {
      const json = await response.json();
      for (const choice of json?.choices ?? []) {
        if (choice.message !== undefined) {
          const r = choice.message.reasoning || choice.message.reasoning_content || '';
          if (r && !choice.message.content) choice.message.content = r;
        }
      }
      return new Response(JSON.stringify(json), {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers
      });
    }

    return response;
  }
}

module.exports = OllamaReasoningTransformer;
```

- [ ] **Step 3: Syntax check**

```bash
node --check .nvm-isolated/.claude-isolated/.claude-code-router/plugins/ollama-reasoning.js
```

Expected: no output, exit 0.

- [ ] **Step 4: Module load check**

```bash
node -e "const T = require('./.nvm-isolated/.claude-isolated/.claude-code-router/plugins/ollama-reasoning.js'); const t = new T(); console.log('name:', t.name, '| transformResponseOut:', typeof t.transformResponseOut);"
```

Expected:
```
name: ollama-reasoning | transformResponseOut: function
```

---

## Task 2: Register plugin in router.json

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/router.json`

CCR requires TWO changes:
1. `"transformers"` at root — tells CCR to load and register the plugin by name
2. `"ollama-reasoning"` added to the provider-level `transformer.use` — tells CCR to apply it in the pipeline

**Important:** add `"ollama-reasoning"` ONLY to `Providers[0].transformer.use` (provider-level), NOT to the per-model arrays. `dD()` applies BOTH provider-level `use` AND per-model `use` sequentially. Adding to both causes a double-run: first on raw Ollama SSE (correct), second on the already-processed Anthropic format (no-op but wasteful). Provider-level is sufficient — it covers all models.

The path in `"transformers"` must be absolute (CCR's `require.resolve` resolves relative to its own `dist/` directory, not to the config file).

- [ ] **Step 1: Verify current router.json structure**

```bash
jq '.Router, (.Providers[0].transformer.use)' \
  .nvm-isolated/.claude-isolated/router.json
```

Expected: Router object + use array `["reasoning", ["sampling", ...]]`.

- [ ] **Step 2: Compute absolute plugin path**

```bash
PLUGIN_PATH="$(pwd)/.nvm-isolated/.claude-isolated/.claude-code-router/plugins/ollama-reasoning.js"
echo "$PLUGIN_PATH"
```

Expected: absolute path ending in `ollama-reasoning.js`.

- [ ] **Step 3: Verify plugin file exists at that path**

```bash
test -f "$PLUGIN_PATH" && echo "OK" || echo "MISSING"
```

Expected: `OK`

- [ ] **Step 4: Apply both changes atomically with jq**

```bash
PLUGIN_PATH="$(pwd)/.nvm-isolated/.claude-isolated/.claude-code-router/plugins/ollama-reasoning.js"
jq --arg path "$PLUGIN_PATH" '
  # 1. Add transformers registration at root
  . + {"transformers": [{"path": $path}]} |

  # 2. Wire into provider-level transformer.use ONLY (append last = runs first due to reverse order)
  # Do NOT add to per-model arrays — dD() applies both chains; adding to both causes double-run
  .Providers[0].transformer.use += ["ollama-reasoning"]
' .nvm-isolated/.claude-isolated/router.json \
  > /tmp/router-new.json && \
  mv /tmp/router-new.json .nvm-isolated/.claude-isolated/router.json
```

- [ ] **Step 5: Verify JSON valid and changes applied**

```bash
jq '{
  transformers: .transformers,
  provider_use: .Providers[0].transformer.use,
  kimi_use: .Providers[0].transformer["kimi-k2.6:cloud"].use
}' .nvm-isolated/.claude-isolated/router.json
```

Expected — `provider_use` has `"ollama-reasoning"` at end; `kimi_use` does NOT:
```json
{
  "transformers": [{"path": "/abs/path/.../ollama-reasoning.js"}],
  "provider_use": ["reasoning", ["sampling", {...}], "ollama-reasoning"],
  "kimi_use": ["reasoning", ["sampling", {...}]]
}
```

---

## Task 3: Restart CCR and verify plugin loads

- [ ] **Step 1: Stop existing CCR**

```bash
CCR_CMD=".nvm-isolated/npm-global/bin/ccr"
CCR_HOME="$(pwd)/.nvm-isolated/.claude-isolated"
HOME="$CCR_HOME" "$CCR_CMD" stop 2>/dev/null || true
sleep 1
```

Expected: CCR stopped or was not running.

- [ ] **Step 2: Copy updated router.json to config.json**

```bash
CCR_HOME="$(pwd)/.nvm-isolated/.claude-isolated"
cp .nvm-isolated/.claude-isolated/router.json \
   "$CCR_HOME/.claude-code-router/config.json"
```

- [ ] **Step 3: Start CCR and wait for startup**

```bash
CCR_CMD=".nvm-isolated/npm-global/bin/ccr"
CCR_HOME="$(pwd)/.nvm-isolated/.claude-isolated"
HOME="$CCR_HOME" "$CCR_CMD" start > /tmp/ccr-plugin-test.log 2>&1 &
CCR_PID=$!
sleep 3
```

- [ ] **Step 4: Check plugin registration in CCR log file**

CCR logs to `$CCR_HOME/.claude-code-router/logs/app.log`, not to stdout:

```bash
CCR_HOME="$(pwd)/.nvm-isolated/.claude-isolated"
LOG="$CCR_HOME/.claude-code-router/logs/app.log"
echo "=== stdout/stderr ===" && cat /tmp/ccr-plugin-test.log
echo "=== app.log ===" && tail -30 "$LOG" 2>/dev/null || echo "(log not found)"
grep -i 'ollama-reasoning\|load transformer.*error' "$LOG" 2>/dev/null || echo "(no match in log)"
```

Expected: log contains:
```
register transformer: ollama-reasoning
```

Must NOT contain:
```
load transformer (.../ollama-reasoning.js) error:
```

- [ ] **Step 5: Verify CCR is responding**

```bash
(: >/dev/tcp/127.0.0.1/3456) 2>/dev/null && echo "CCR up" || echo "CCR not responding"
```

Expected: `CCR up`

---

## Task 4: Test plugin with kimi-k2.6:cloud

- [ ] **Step 1: Send a test request that requires reasoning**

```bash
RESPONSE=$(curl -s \
  "http://127.0.0.1:3456/v1/messages" \
  -H "x-api-key: test" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-5",
    "max_tokens": 100,
    "messages": [{"role": "user", "content": "What is 17 * 23? Show your calculation."}]
  }' 2>/dev/null)
echo "$RESPONSE"
```

Note: model `claude-sonnet-4-5` routes to `default` slot → `ollama,kimi-k2.6:cloud` (verified in current router.json). kimi is a reasoning model — the plugin is specifically needed here.

- [ ] **Step 2: Assert response has non-empty content**

```bash
echo "$RESPONSE" | python3 -c "
import json, sys
r = json.load(sys.stdin)
if r.get('error'):
    print('ERROR:', r['error'])
    sys.exit(1)
content = r.get('content', [])
text = ' '.join(b.get('text','') for b in content if b.get('type')=='text')
if text.strip():
    print('PASS: content =', repr(text[:100]))
else:
    print('FAIL: content empty. Full response:', json.dumps(r, indent=2)[:500])
    sys.exit(1)
"
```

Expected: `PASS: content = '...391...'` (or any non-empty text with the math answer).

If exit 1: check CCR logs for errors and verify the router slot points to kimi.

- [ ] **Step 3: Check thinking blocks are also present (optional — confirms copy not move)**

```bash
echo "$RESPONSE" | python3 -c "
import json, sys
r = json.load(sys.stdin)
content = r.get('content', [])
thinking = [b for b in content if b.get('type')=='thinking']
text = [b for b in content if b.get('type')=='text']
print('thinking blocks:', len(thinking))
print('text blocks:', len(text))
"
```

Expected: `thinking blocks: 1`, `text blocks: 1` (both present — copy, not move).

---

## Task 5: Update integration test

**Files:**
- Modify: `tests/test_ccr_integration.sh`

The existing test asserts `"content"` key exists in response. Add an assertion that text content is non-empty (stronger signal that the plugin works).

- [ ] **Step 1: Locate the existing assertion**

```bash
grep -n '"content"' tests/test_ccr_integration.sh
```

Expected: line like `if echo "$HTTP_BODY" | grep -q '"content"'; then`

- [ ] **Step 2: Add stronger assertion after the existing one**

After the `pass "CCR routed request successfully..."` line in `tests/test_ccr_integration.sh`, add a secondary check. Locate the exact line and modify the assertion block:

Find this block (exact text to locate):
```bash
if echo "$HTTP_BODY" | grep -q '"content"'; then
    pass "CCR routed request successfully (status $HTTP_STATUS, response contains 'content')"
else
    echo "ERROR: Response body: $HTTP_BODY" >&2
    fail "Response does not contain 'content' key (status $HTTP_STATUS)"
fi
```

Replace with:
```bash
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
```

- [ ] **Step 3: Syntax check**

```bash
bash -n tests/test_ccr_integration.sh
```

Expected: no output.

- [ ] **Step 4: Run integration test**

```bash
bash tests/test_ccr_integration.sh; echo "exit: $?"
```

Expected:
- `PASS: CCR routed request successfully...`
- `PASS: Text content non-empty...` (if ollama signed in and kimi responding)
- OR `exit: 77` (if CCR not available — skip)

---

## Task 6: Commit

- [ ] **Step 1: Check git status**

```bash
git status
```

Expected modified/new files:
- `M tests/test_ccr_integration.sh`
- New: `.nvm-isolated/.claude-isolated/.claude-code-router/plugins/ollama-reasoning.js` (gitignored — will not appear)
- `.nvm-isolated/.claude-isolated/router.json` (gitignored — will not appear)

Note: the plugin and router.json are gitignored. Only `tests/test_ccr_integration.sh` will be in git diff.

- [ ] **Step 2: Run existing test suite**

```bash
python3 -m pytest tests/test_patterns_examples.py -v
```

Expected: all tests pass.

- [ ] **Step 3: Stage and commit**

```bash
git add tests/test_ccr_integration.sh
git commit -m "$(cat <<'EOF'
test(router): strengthen CCR integration test to verify reasoning→content transform

Assert non-empty text content in addition to presence of 'content' key.
This verifies the ollama-reasoning transformer plugin is working end-to-end.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Verify**

```bash
git log --oneline -3
```

Expected: commit at HEAD for `test_ccr_integration.sh`.

---

## Self-Review Against Spec

| Spec requirement | Task |
|-----------------|------|
| Plugin copies `delta.reasoning` → `delta.content` (streaming + non-streaming) | Task 1 |
| Universal for all ollama models (passthrough if no reasoning) | Task 1 (conditional copy only when reasoning non-empty and content empty) |
| Thinking blocks preserved (copy not move) | Task 1 (`delta.reasoning` unchanged) |
| Registered in `router.json` via `transformers` array | Task 2 |
| Wired into `transformer.use` at provider level only (not per-model — avoids double-run) | Task 2 |
| Runs before `reasoning` transformer (raw Ollama format) | Task 2 (placed last in `use` array → runs first due to reverse order) |
| Plugin load verified in CCR startup log | Task 3 |
| End-to-end test with kimi-k2.6:cloud | Task 4 |
| Integration test updated | Task 5 |
| Commit | Task 6 |

---

## Notes for Implementer

**Execution order subtlety:** CCR applies `transformer.use` in **reverse order** (`Array.from(use).reverse()` in `dD()`). Placing `"ollama-reasoning"` **last** in the array means it runs **first** on the raw Ollama SSE stream.

**Double-run avoidance:** `dD()` applies provider-level `transformer.use` AND then per-model `transformer["model"].use` independently. Adding `"ollama-reasoning"` to both would run it twice. Provider-level alone is sufficient and correct.

**Plugin is a class, not a plain object:** The design spec shows a plain object (`module.exports = { name: ..., transformResponseOut() {} }`) — that was written before the CCR bundle was analyzed. CCR does `new T(options)`, so a plain object would throw `TypeError: t is not a constructor`. Use the class as written in the plan.

**Path resolution:** CCR's `registerTransformerFromConfig` calls `require.resolve(e.path)`. Relative paths resolve relative to CCR's `dist/` directory, not the config file location. Use absolute path in `router.json`.

**Plugin is a class:** CCR does `new T(options)`, not `T(options)`. `module.exports` must be the class constructor.

**router.json is gitignored:** Changes to `router.json` and the plugin file are not committed to git. Only `tests/test_ccr_integration.sh` goes into the commit.
