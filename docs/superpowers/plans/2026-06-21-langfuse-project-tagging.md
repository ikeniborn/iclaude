---
chain:
  intent: null
  spec: docs/superpowers/specs/langfuse-project-tagging-spec.md
review:
  plan_hash: b4f47f6c0ed54fba
  spec_hash: 25aa75a297009d89
  last_run: 2026-06-21
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - id: F-001
      phase: dependencies
      severity: WARNING
      section: "Task 3"
      text: >-
        Concrete line-number claims for lib/launcher/launch.sh are stale: the
        plan cites launch_claude() at line 49, use_router=true at line 67,
        start_ccr_server at ~155/~592 and exec "$ccr_cmd" code at ~610, but the
        current file has launch_claude() at 95, use_router=true at 113,
        start_ccr_server at 206/643 and exec at 661. Non-blocking: every cite is
        hedged "currently line N" and Task 3 Step 1 locates the insertion point
        via grep, so the steps self-correct. The dependency invariant
        (_init_project_id export precedes all three CCR launch paths) still holds.
      verdict: open
---

# Per-Project Langfuse Tagging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every Claude Code LLM trace in self-hosted Langfuse carry `project:<repo-name>` instead of `project:unknown`, by exporting `ICLAUDE_PROJECT_ID` before CCR launches so CCR forwards it as the `X-Project-Id` header to LiteLLM.

**Architecture:** Two small bash helpers in `lib/launcher/launch.sh` — `_derive_project_id()` (repo/dir name → tag-safe slug) and `_init_project_id()` (guard + export, router-mode only) — export `ICLAUDE_PROJECT_ID` into the shell environment **before** any of the three CCR launch paths (`start_ccr_server` for microVM and combined PII+router modes, `exec ccr code` for solo router mode) forks/execs, so CCR inherits it (R2). A CCR transformer plugin (`x-project-id.js`, registered in `router.json`) then reads `process.env.ICLAUDE_PROJECT_ID` and injects it as the `X-Project-Id` header on the upstream request to LiteLLM (R3). The plugin is necessary because CCR 2.0.0 drops provider-config `headers` at `registerProvider` — a transformer returning `config.headers` is the only header-injection path that reaches the upstream (the mechanism the built-in `gemini` transformer uses). LiteLLM's `project_tagger` turns the header into the Langfuse tag `project:<id>`.

**Tech Stack:** Bash (lib modules sourced by `iclaude.sh`), plain `.sh` unit/integration tests (no bats — the repo uses an awk `_extract` + `assert_eq` harness), Python 3 stdlib `http.server` for the hermetic upstream mock, CCR (`ccr` binary) + curl for forwarding verification.

---

## Background — verified facts (do not re-investigate)

Verified against the **installed** CCR bundle (`.nvm-isolated/npm-global/lib/node_modules/@musistudio/claude-code-router/dist/cli.js`, v2.0.0) **and empirically** via `tests/test_x_project_id_forwarding.sh` (Task 4). **Correction:** an earlier static reading of this plan claimed CCR forwards provider `headers` (R1). That was WRONG — the hermetic test (Task 4) falsified it. The real findings:

1. **CCR deep-interpolates env into the entire config**, including nested `headers` values. The bundled walker is:
   ```js
   Fh = e => {
     if (typeof e === "string")
       return e.replace(/\$\{([^}]+)\}|\$([A-Z_][A-Z0-9_]*)/g, (t, r, n) => process.env[r || n] || t);
     if (Array.isArray(e)) return e.map(Fh);
     if (e !== null && typeof e === "object") { let t = {}; for (let [k, v] of Object.entries(e)) t[k] = Fh(v); return t; }
     return e;
   };
   ```
   → `headers: { "X-Project-Id": "${ICLAUDE_PROJECT_ID}" }` IS interpolated to `process.env.ICLAUDE_PROJECT_ID` — but then discarded (see #2).
2. **Provider-config `headers` are DROPPED, never forwarded (R1 is dead).** `registerProvider({name, baseUrl, apiKey, models, transformer})` does not pass `t.headers`, so the registered provider has no `headers`. The `{ Authorization: \`Bearer ${apiKey}\`, ...t?.headers || {} }` spread that builds the upstream request uses the *request* headers (incoming + transformer-injected), not the provider config. Empirically confirmed: the Task 4 test fails, and its negative control (a literal wrong value) fails identically → the header is dropped entirely.
3. **R3 (transformer plugin) is REQUIRED and is the primary mechanism.** A transformer's `transformRequestIn(request, provider)` may return `{ body, config: { headers: {...} } }`; CCR merges `config.headers` into the upstream request (`h = {...h, ...c.config.headers}; t = {...t, ...c.config, headers: h}`), which is exactly how the built-in `gemini` transformer injects `x-goog-api-key`. This is the ONLY working header-injection path in CCR 2.0.0. R4 (virtual keys) remains an unused last resort.
4. **R2 is still required (and is a prerequisite for R3).** The R3 plugin reads `process.env.ICLAUDE_PROJECT_ID`; `_init_project_id()` (Tasks 1–3) exports it before CCR starts. An unset value would make the plugin emit `"unknown"` (the plugin's own `|| "unknown"` fallback), so R2 is what makes the tag the real repo name.
5. **`router.json` MUST be edited for R3** (Task 5): add `"x-project-id"` to the `homelab` provider's `transformer.use` and register the plugin path in the top-level `transformers` list. The pre-existing R1 `headers` block is inert and may stay. Backup: `router.json.bak-pre-xproject-*`.

---

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `lib/launcher/launch.sh` | Hosts `_derive_project_id()`, `_init_project_id()` (added just before `launch_claude()`), and the one-line wiring call inside `launch_claude()`. | Modify |
| `tests/test_project_id_unit.sh` | L1 unit tests for both new helpers (sanitization, git/non-git derivation, router guard, export-to-child). | Create |
| `tests/test_x_project_id_forwarding.sh` | Hermetic integration test: CCR + a mock upstream that records received headers; asserts `X-Project-Id` forwarding. It falsified R1 (red until R3 lands) and is the acceptance test for R3. Skip-aware (exit 77). | Create (done) |
| `.nvm-isolated/.claude-isolated/.claude-code-router/plugins/x-project-id.js` | **R3** CCR transformer plugin: `transformRequestIn` returns `{ body, config: { headers: { "X-Project-Id": process.env.ICLAUDE_PROJECT_ID \|\| "unknown" } } }`. The only working header-injection path in CCR 2.0.0. | Create |
| `.nvm-isolated/.claude-isolated/router.json` | **R3** registration: add `"x-project-id"` to the `homelab` provider's `transformer.use`, and add the plugin path to the top-level `transformers` list. | Modify |
| `docs/superpowers/specs/langfuse-project-tagging-spec.md` | Status updated: R1 dead, R2 done, R3 primary. | Modify |
| `docs/wiki/` (via iwiki-ingest) | Regenerated router/launcher wiki page documenting `ICLAUDE_PROJECT_ID` + the R3 plugin. | Regenerate |

No change to `lib/sandbox/microvm.sh` or the PII proxy: CCR runs on the **host** in every mode, so the host-side export (verified fact: `start_ccr_server` is always called on the host before the VM boots, and `exec ccr code` runs on the host) is the only injection point required. The guest never runs CCR. This is asserted by Task 4 only indirectly (host CCR); a guest-env change would be dead code (YAGNI).

---

## Task 1: `_derive_project_id()` helper

**Files:**
- Create: `tests/test_project_id_unit.sh`
- Modify: `lib/launcher/launch.sh` (add function immediately before `launch_claude()` at line 49)

- [ ] **Step 1: Write the failing test**

Create `tests/test_project_id_unit.sh`:

```bash
#!/usr/bin/env bash
# L1 — unit tests for _derive_project_id / _init_project_id (lib/launcher/launch.sh).
# No bats: mirrors the awk _extract + assert_eq harness from test_pii_dnat_unit.sh.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Extract a single function from launch.sh without sourcing the whole module
# (avoids pulling in launch_claude's dependencies). Matches "name() {" ... "}" at col 1.
_extract() {
    awk -v fn="$1" '
        $0 ~ "^"fn"\\(\\)" { in_fn=1 }
        in_fn { print }
        in_fn && /^}/ { in_fn=0 }
    ' "$ROOT/lib/launcher/launch.sh"
}
eval "$(_extract _derive_project_id)"

PASS=0; FAIL=0
assert_eq() {
    if [[ "$1" == "$2" ]]; then PASS=$((PASS + 1))
    else FAIL=$((FAIL + 1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi
}

# Non-git dir → basename verbatim
PARENT=$(mktemp -d); mkdir -p "$PARENT/minipc"
assert_eq "$(_derive_project_id "$PARENT/minipc")" "minipc" "non-git basename"
rm -rf "$PARENT"

# Uppercase + spaces → lowercased, spaces collapsed to '-'
PARENT=$(mktemp -d); mkdir -p "$PARENT/My Project"
assert_eq "$(_derive_project_id "$PARENT/My Project")" "my-project" "spaces+case sanitized"
rm -rf "$PARENT"

# Exotic chars collapse to single '-' and trim from both ends
PARENT=$(mktemp -d); mkdir -p "$PARENT/@@@weird@@@"
assert_eq "$(_derive_project_id "$PARENT/@@@weird@@@")" "weird" "exotic collapse+trim"
rm -rf "$PARENT"

# Git repo → toplevel basename even when called from a subdirectory
PARENT=$(mktemp -d); git -C "$PARENT" init -q myrepo >/dev/null 2>&1 || git init -q "$PARENT/myrepo"
mkdir -p "$PARENT/myrepo/sub"
assert_eq "$(_derive_project_id "$PARENT/myrepo/sub")" "myrepo" "git toplevel from subdir"
rm -rf "$PARENT"

# Sanitization yields empty → "unknown"
PARENT=$(mktemp -d); mkdir -p "$PARENT/@@@"
assert_eq "$(_derive_project_id "$PARENT/@@@")" "unknown" "empty-after-sanitize fallback"
rm -rf "$PARENT"

echo "L1 project_id (derive): PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_project_id_unit.sh`
Expected: FAIL — `_extract _derive_project_id` returns nothing, so `eval` defines no function; calling `_derive_project_id` errors with `command not found` and the script exits non-zero (no `PASS`/`FAIL` summary, or all asserts fail).

- [ ] **Step 3: Write the helper**

In `lib/launcher/launch.sh`, immediately **before** `launch_claude() {` (currently line 49), add:

```bash
#######################################
# Derive a Langfuse-safe project id from a directory.
# Uses the git toplevel basename (repo name) when $1 is inside a git work tree;
# otherwise the directory basename. Sanitizes to a tag-safe slug: lowercased,
# every run of chars outside [a-z0-9._-] collapsed to a single '-', leading and
# trailing '-' trimmed. Falls back to "unknown" if the result is empty.
# Arguments:
#   $1 - directory (defaults to $PWD)
# Outputs:
#   slug on stdout
#######################################
_derive_project_id() {
    local dir="${1:-$PWD}" top name
    top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$top" ]]; then
        name=$(basename "$top")
    else
        name=$(basename "$dir")
    fi
    name=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')
    [[ -n "$name" ]] || name="unknown"
    printf '%s' "$name"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_project_id_unit.sh`
Expected: PASS — final line `L1 project_id (derive): PASS=5 FAIL=0`, exit 0.

Also validate module syntax: `bash -n lib/launcher/launch.sh`
Expected: no output, exit 0.

- [ ] **Step 5: Commit**

```bash
git add lib/launcher/launch.sh tests/test_project_id_unit.sh
git commit -m "feat(router): add _derive_project_id for Langfuse per-project tagging"
```

---

## Task 2: `_init_project_id()` guard + export wrapper

**Files:**
- Modify: `lib/launcher/launch.sh` (add function directly after `_derive_project_id()`)
- Modify: `tests/test_project_id_unit.sh` (append `_init_project_id` cases)

- [ ] **Step 1: Write the failing test**

Append to `tests/test_project_id_unit.sh`, **before** the final `echo "L1 ..."` / `[[ "$FAIL" == "0" ]]` lines, this block:

```bash
# ---- _init_project_id ----
eval "$(_extract _init_project_id)"

# use_router != "true" → no-op: variable stays unset
( unset ICLAUDE_PROJECT_ID; _init_project_id "false"; [[ -z "${ICLAUDE_PROJECT_ID:-}" ]] ) \
    && PASS=$((PASS + 1)) || { FAIL=$((FAIL + 1)); echo "FAIL [init: no-op when not router]"; }

# router + unset → derived and EXPORTED (a child process must see it, since CCR is a fork)
EXP=$(_derive_project_id "$ROOT")
out=$( cd "$ROOT" && unset ICLAUDE_PROJECT_ID; _init_project_id "true"; bash -c 'printf "%s" "${ICLAUDE_PROJECT_ID:-}"' )
assert_eq "$out" "$EXP" "init: derives+exports repo id to child"

# router + preset value → preserved (explicit override wins) and exported
out=$( ICLAUDE_PROJECT_ID="fixed-name"; _init_project_id "true"; bash -c 'printf "%s" "${ICLAUDE_PROJECT_ID:-}"' )
assert_eq "$out" "fixed-name" "init: preserves preset value"
```

And update the summary label line to:

```bash
echo "L1 project_id: PASS=$PASS FAIL=$FAIL"
```

(Replace the previous `echo "L1 project_id (derive): ..."` line — the file now covers both helpers.)

- [ ] **Step 2: Run test to verify the new cases fail**

Run: `bash tests/test_project_id_unit.sh`
Expected: FAIL — `_extract _init_project_id` returns nothing (function not yet added), so the three new assertions fail; summary shows `FAIL=3` (the derive cases still pass).

- [ ] **Step 3: Write the helper**

In `lib/launcher/launch.sh`, immediately **after** `_derive_project_id()` (and before `launch_claude()`), add:

```bash
#######################################
# Export ICLAUDE_PROJECT_ID for the CCR process (router mode only).
# CCR (v2.0.0) deep-interpolates ${ICLAUDE_PROJECT_ID} from its process env into
# the homelab provider's "X-Project-Id" header (router.json) and forwards it to
# LiteLLM, whose project_tagger emits the Langfuse tag project:<id>. This MUST run
# before any CCR fork/exec (start_ccr_server or `exec ccr code`). An explicit value
# already present in the environment (e.g. exported from .claude_config) is kept.
# NOTE: an unset value would make CCR send the literal "${ICLAUDE_PROJECT_ID}"
# string as the header (its interpolator falls back to the raw token, not empty),
# so router mode always exports a concrete value here.
# Arguments:
#   $1 - use_router ("true" activates; any other value is a no-op)
#######################################
_init_project_id() {
    [[ "${1:-}" == "true" ]] || return 0
    if [[ -z "${ICLAUDE_PROJECT_ID:-}" ]]; then
        ICLAUDE_PROJECT_ID="$(_derive_project_id "$PWD")"
    fi
    export ICLAUDE_PROJECT_ID
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_project_id_unit.sh`
Expected: PASS — final line `L1 project_id: PASS=8 FAIL=0`, exit 0.

Syntax: `bash -n lib/launcher/launch.sh` → no output, exit 0.

- [ ] **Step 5: Commit**

```bash
git add lib/launcher/launch.sh tests/test_project_id_unit.sh
git commit -m "feat(router): _init_project_id exports ICLAUDE_PROJECT_ID in router mode"
```

---

## Task 3: Wire the call into `launch_claude()`

**Files:**
- Modify: `lib/launcher/launch.sh` (inside `launch_claude()`, right after the `use_router` detection block)

- [ ] **Step 1: Locate the insertion point**

Run: `grep -n 'use_router=true' lib/launcher/launch.sh`
Expected: the line inside the detection block:
```
67:        use_router=true
```
The block is:
```bash
    # NEW: Check if router should be used (only if --router flag is set)
    local use_router=false
    if [[ "$USE_ROUTER_FLAG" == "true" ]] && detect_router "$skip_isolated"; then
        use_router=true
    fi
```

- [ ] **Step 2: Add the wiring call**

In `lib/launcher/launch.sh`, immediately **after** the closing `fi` of that block (currently line 68), insert:

```bash

    # Per-project Langfuse attribution: export ICLAUDE_PROJECT_ID before any CCR
    # fork/exec below (start_ccr_server / `exec ccr code`) so CCR can interpolate it
    # into the homelab provider's X-Project-Id header. No-op when router is inactive.
    _init_project_id "$use_router"
```

- [ ] **Step 3: Verify the export precedes every CCR launch path**

Run:
```bash
grep -n '_init_project_id "\$use_router"\|start_ccr_server\|exec "\$ccr_cmd" code' lib/launcher/launch.sh
```
Expected: the `_init_project_id "$use_router"` line number is **smaller** than every `start_ccr_server` line (~155, ~592) and the `exec "$ccr_cmd" code` line (~610) — i.e. the export happens first in all three paths.

- [ ] **Step 4: Validate syntax**

Run: `bash -n lib/launcher/launch.sh`
Expected: no output, exit 0.

Run the unit suite again to confirm nothing regressed: `bash tests/test_project_id_unit.sh`
Expected: `L1 project_id: PASS=8 FAIL=0`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add lib/launcher/launch.sh
git commit -m "feat(router): wire _init_project_id into launch_claude before CCR start"
```

---

## Task 4: Hermetic `X-Project-Id` forwarding test

Proves at runtime whether CCR forwards `X-Project-Id` to the upstream — without depending on Ollama/LiteLLM. A local mock upstream records the headers it receives **at request time** (before sending any response), so the assertion is on the captured-headers file, not on CCR's HTTP response (which may legitimately error on the mock's minimal body — irrelevant here).

**Outcome (already run):** this test FALSIFIED R1 — with only the provider `headers` block (no plugin) it reports `FAIL` (negative control fails identically → header dropped). That discovery is what added Task 5 (R3). The test file is correct and committed as-is; it stays RED until Task 5 lands the transformer plugin, then turns GREEN. It is the acceptance test for R3.

**Files:**
- Create: `tests/test_x_project_id_forwarding.sh`

- [ ] **Step 1: Write the test**

Create `tests/test_x_project_id_forwarding.sh`:

```bash
#!/usr/bin/env bash
# Hermetic integration test: CCR forwards ICLAUDE_PROJECT_ID as the X-Project-Id
# header to the provider api_base_url. Uses a local Python mock upstream that records
# received headers. No Ollama/LiteLLM needed.
# Exit codes: 0=pass, 1=fail, 77=skip (ccr/node20/python missing or ports busy).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOCK_PORT=18473
CCR_PORT=3458
CCR_HOST=127.0.0.1
PROJECT_ID="ci-test-proj"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
skip() { echo "SKIP: $*"; exit 77; }

command -v python3 >/dev/null 2>&1 || skip "python3 not found"

# Locate ccr binary (isolated env first)
CCR_CMD=""
for c in "$REPO_ROOT/.nvm-isolated/npm-global/bin/ccr" "$(command -v ccr 2>/dev/null || true)"; do
    [[ -x "$c" ]] && { CCR_CMD="$c"; break; }
done
[[ -z "$CCR_CMD" ]] && skip "ccr binary not found (run: ./iclaude.sh --install-router)"

# CCR v2.0.0 needs node v20+; prepend it to PATH like lib/launcher/launch.sh does
_node20=$(find "$REPO_ROOT/.nvm-isolated/versions/node" -maxdepth 1 -type d \
    -name "v2[0-9]*" 2>/dev/null | LC_ALL=C sort | tail -1)
[[ -n "$_node20" && -d "$_node20/bin" ]] && export PATH="$_node20/bin:$PATH"

# Refuse to clobber an already-bound port
for p in "$MOCK_PORT" "$CCR_PORT"; do
    if (: >/dev/tcp/127.0.0.1/"$p") 2>/dev/null; then
        skip "port $p already in use — cannot run hermetic test"
    fi
done

WORK=$(mktemp -d)
HDR_FILE="$WORK/headers.txt"
MOCK_PID=""; CCR_PID=""
cleanup() {
    [[ -n "$CCR_PID" ]]  && { kill "$CCR_PID"  2>/dev/null; wait "$CCR_PID"  2>/dev/null; }
    [[ -n "$MOCK_PID" ]] && { kill "$MOCK_PID" 2>/dev/null; wait "$MOCK_PID" 2>/dev/null; }
    rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

# --- mock upstream: records lowercased "key: value" headers, returns minimal JSON ---
cat > "$WORK/mock_upstream.py" <<'PY'
import http.server, json, sys
HDR_FILE = sys.argv[1]
PORT = int(sys.argv[2])

class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        with open(HDR_FILE, "w") as f:
            for k, v in self.headers.items():
                f.write(f"{k.lower()}: {v}\n")
        try:
            self.rfile.read(int(self.headers.get("content-length", 0) or 0))
        except Exception:
            pass
        body = json.dumps({
            "id": "chatcmpl-mock", "object": "chat.completion", "created": 0, "model": "mock-model",
            "choices": [{"index": 0, "message": {"role": "assistant", "content": "OK"}, "finish_reason": "stop"}],
            "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2},
        }).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass

http.server.HTTPServer(("127.0.0.1", PORT), H).serve_forever()
PY

python3 "$WORK/mock_upstream.py" "$HDR_FILE" "$MOCK_PORT" &
MOCK_PID=$!
# Wait for mock to bind (max 5s)
_ok=false
for _ in $(seq 1 25); do
    (: >/dev/tcp/127.0.0.1/"$MOCK_PORT") 2>/dev/null && { _ok=true; break; }
    sleep 0.2
done
[[ "$_ok" == "true" ]] || fail "mock upstream did not start on :$MOCK_PORT"

# --- purpose-built router.json: single provider → mock, with the X-Project-Id header ---
CCR_HOME="$WORK/ccr-home"
mkdir -p "$CCR_HOME/.claude-code-router"
cat > "$CCR_HOME/.claude-code-router/config.json" <<JSON
{
  "PORT": $CCR_PORT,
  "HOST": "$CCR_HOST",
  "LOG": false,
  "Providers": [
    {
      "name": "mockprov",
      "api_base_url": "http://127.0.0.1:$MOCK_PORT/v1/chat/completions",
      "api_key": "test-key",
      "models": ["mock-model"],
      "headers": { "X-Project-Id": "\${ICLAUDE_PROJECT_ID}" }
    }
  ],
  "Router": { "default": "mockprov,mock-model" }
}
JSON

# --- start CCR with ICLAUDE_PROJECT_ID in its process env ---
HOME="$CCR_HOME" ICLAUDE_PROJECT_ID="$PROJECT_ID" "$CCR_CMD" start >"$WORK/ccr.log" 2>&1 &
CCR_PID=$!
_ready=false
for _ in $(seq 1 20); do
    kill -0 "$CCR_PID" 2>/dev/null || fail "CCR exited early. Log: $(cat "$WORK/ccr.log" 2>/dev/null)"
    (: >/dev/tcp/"$CCR_HOST"/"$CCR_PORT") 2>/dev/null && { _ready=true; break; }
    sleep 0.5
done
[[ "$_ready" == "true" ]] || fail "CCR not ready on :$CCR_PORT after 10s. Log: $(cat "$WORK/ccr.log" 2>/dev/null)"

# --- send one request through CCR; response body is irrelevant (header captured at receipt) ---
curl -s --max-time 10 "http://$CCR_HOST:$CCR_PORT/v1/messages" \
    -H "x-api-key: test" \
    -H "anthropic-version: 2023-06-01" \
    -H "Content-Type: application/json" \
    -d '{"model":"mock-model","max_tokens":16,"messages":[{"role":"user","content":"hi"}]}' \
    >/dev/null 2>&1 || true

# Give the upstream a moment to flush the header file
for _ in $(seq 1 10); do [[ -s "$HDR_FILE" ]] && break; sleep 0.2; done

[[ -s "$HDR_FILE" ]] || fail "mock upstream received no request (header file empty). CCR log: $(cat "$WORK/ccr.log" 2>/dev/null)"

if grep -qi "^x-project-id: ${PROJECT_ID}$" "$HDR_FILE"; then
    pass "CCR forwarded X-Project-Id: ${PROJECT_ID} to upstream"
else
    echo "ERROR: captured headers:" >&2
    cat "$HDR_FILE" >&2
    fail "X-Project-Id not forwarded as '${PROJECT_ID}'"
fi
```

- [ ] **Step 2: Make it executable and run it**

Run:
```bash
chmod +x tests/test_x_project_id_forwarding.sh
bash tests/test_x_project_id_forwarding.sh; echo "exit: $?"
```
Expected with CCR + node20 installed but **before Task 5 (R3)**: `FAIL: X-Project-Id not forwarded as 'ci-test-proj'` then `exit: 1` — this is the empirical falsification of R1, not a test defect. After Task 5 lands the transformer plugin and registers it, re-running yields `PASS: CCR forwarded X-Project-Id: ci-test-proj to upstream`, `exit: 0`.
Acceptable on a machine without the router: `SKIP: ...` then `exit: 77`.

- [ ] **Step 3: Confirm the assertion is meaningful (negative control)**

Confirm the test discriminates: the negative control (header value set to a literal `"wrong-value"` in the test's `config.json`) also reports `FAIL` — proving the header is dropped entirely under R1, not merely mis-valued. This was run during the R1 falsification; no edit needs to persist. The committed file keeps `"\${ICLAUDE_PROJECT_ID}"`.

- [ ] **Step 4: Commit**

```bash
git add tests/test_x_project_id_forwarding.sh
git commit -m "test(router): hermetic X-Project-Id forwarding test (mock upstream)"
```

---

## Task 5: R3 — CCR transformer plugin (X-Project-Id injection)

This is the working forwarding mechanism (R1 is dead — see Background). A CCR transformer plugin
returns `config.headers` from `transformRequestIn`; CCR merges them into the upstream request.
After this task, the Task 4 hermetic test turns GREEN.

**Files:**
- Create: `.nvm-isolated/.claude-isolated/.claude-code-router/plugins/x-project-id.js`
- Modify: `.nvm-isolated/.claude-isolated/router.json` (register the plugin + add to provider `transformer.use`)
- Modify: `tests/test_x_project_id_forwarding.sh` (temp config must load + use the plugin so the test exercises R3)

- [ ] **Step 1: Create the transformer plugin**

Create `.nvm-isolated/.claude-isolated/.claude-code-router/plugins/x-project-id.js`:

```js
// CCR transformer plugin — injects X-Project-Id into the upstream request to the provider.
// CCR 2.0.0 drops provider-config `headers` at registerProvider, so the ONLY way to add an
// outgoing header is a transformer that returns `config.headers` from transformRequestIn —
// the same mechanism the built-in `gemini` transformer uses for `x-goog-api-key`.
// The value comes from process.env.ICLAUDE_PROJECT_ID, which lib/launcher/launch.sh exports
// before CCR starts (R2). LiteLLM's project_tagger turns it into the Langfuse tag project:<id>.
module.exports = class XProjectId {
  name = "x-project-id";

  transformRequestIn(request, provider) {
    return {
      body: request,
      config: {
        headers: { "X-Project-Id": process.env.ICLAUDE_PROJECT_ID || "unknown" },
      },
    };
  }
};
```

- [ ] **Step 2: Register the plugin in `router.json`**

In `.nvm-isolated/.claude-isolated/router.json`:

(a) Add `"x-project-id"` to the `homelab` provider's `transformer.use` array. It currently is:
```json
"use": [
  "reasoning",
  [ "sampling", { "temperature": 0.2, "top_p": 0.9, "top_k": 40 } ],
  "ollama-reasoning"
],
```
Change it to append `"x-project-id"`:
```json
"use": [
  "reasoning",
  [ "sampling", { "temperature": 0.2, "top_p": 0.9, "top_k": 40 } ],
  "ollama-reasoning",
  "x-project-id"
],
```

(b) Add the plugin to the top-level `transformers` list. It currently is:
```json
"transformers": [
  {
    "path": "${CLAUDE_CONFIG_DIR}/.claude-code-router/plugins/ollama-reasoning.js"
  }
]
```
Change it to:
```json
"transformers": [
  {
    "path": "${CLAUDE_CONFIG_DIR}/.claude-code-router/plugins/ollama-reasoning.js"
  },
  {
    "path": "${CLAUDE_CONFIG_DIR}/.claude-code-router/plugins/x-project-id.js"
  }
]
```

Leave the provider-level `headers` block as-is (inert; harmless). Validate JSON: `python3 -m json.tool .nvm-isolated/.claude-isolated/router.json >/dev/null && echo OK`.

- [ ] **Step 3: Point the hermetic test's temp config at the plugin**

The Task 4 test builds its OWN minimal `config.json` (provider → mock). For it to exercise R3, that
config must load the plugin and use it. In `tests/test_x_project_id_forwarding.sh`, replace the
`config.json` heredoc (the block that currently sets a provider `headers` map) with one that
registers the real plugin file and adds it to the provider's `transformer.use`:

```bash
cat > "$CCR_HOME/.claude-code-router/config.json" <<JSON
{
  "PORT": $CCR_PORT,
  "HOST": "$CCR_HOST",
  "LOG": false,
  "transformers": [
    { "path": "$REPO_ROOT/.nvm-isolated/.claude-isolated/.claude-code-router/plugins/x-project-id.js" }
  ],
  "Providers": [
    {
      "name": "mockprov",
      "api_base_url": "http://127.0.0.1:$MOCK_PORT/v1/chat/completions",
      "api_key": "test-key",
      "models": ["mock-model"],
      "transformer": { "use": ["x-project-id"] }
    }
  ],
  "Router": { "default": "mockprov,mock-model" }
}
JSON
```

(The `$REPO_ROOT` shell var is already defined at the top of the test; it expands here because this
heredoc is unquoted — note `JSON`, not `'JSON'`. The plugin reads `process.env.ICLAUDE_PROJECT_ID`,
which the test still sets to `ci-test-proj` on the CCR start line.) Also delete the now-obsolete
inline comment that described the `headers`-based config.

- [ ] **Step 4: Run the hermetic test — now GREEN**

Run:
```bash
bash tests/test_x_project_id_forwarding.sh; echo "exit: $?"
```
Expected (CCR + node20 installed): `PASS: CCR forwarded X-Project-Id: ci-test-proj to upstream`, `exit: 0`.
Acceptable without the router: `SKIP: ...`, `exit: 77`. A `FAIL` means the plugin/registration is wrong — read the printed CCR log + captured headers and fix before committing.

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/.claude-code-router/plugins/x-project-id.js \
        .nvm-isolated/.claude-isolated/router.json \
        tests/test_x_project_id_forwarding.sh
git commit -m "feat(router): X-Project-Id transformer plugin (R3) — forwards project id to LiteLLM"
```

---

## Task 6: Documentation + spec status

**Files:**
- Modify: `docs/superpowers/specs/langfuse-project-tagging-spec.md` (already updated during re-planning — verify it reads: R1 dead, R2 done, R3 primary)
- Regenerate: `docs/wiki/` page covering the launcher/router change (via iwiki)

- [ ] **Step 1: Confirm the spec status reflects reality**

Verify `docs/superpowers/specs/langfuse-project-tagging-spec.md` records: R1 dead in CCR 2.0.0 (provider `headers` dropped at `registerProvider`), R2 implemented in launch.sh, R3 (transformer plugin) is the primary working mechanism with the correct `transformRequestIn → { config: { headers } }` shape. (These edits were applied when the plan was revised; this step is a read-back check, not a re-edit.)

- [ ] **Step 2: Regenerate the wiki page**

Run the iwiki ingest on the changed source so `docs/wiki/` documents `ICLAUDE_PROJECT_ID`:

Invoke the `iwiki:iwiki-ingest` skill with `lib/launcher/launch.sh` as the source. Review the shown diff; accept it. This updates the relevant page (e.g. `docs/wiki/router.md` and/or a launcher page) to describe the per-project tagging variable.

- [ ] **Step 3: Lint the wiki**

Invoke `/iwiki-lint` (or the `iwiki:iwiki-lint` skill).
Expected: no broken `[[refs]]`, no new orphan/stale pages introduced by the ingest.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/langfuse-project-tagging-spec.md docs/wiki/
git commit -m "docs(router): document ICLAUDE_PROJECT_ID per-project Langfuse tagging"
```

---

## Task 7: End-to-end acceptance against live Langfuse (manual)

This is the spec §5 acceptance. It requires a real `--router` launch and access to the minipc ClickHouse host, so it is a **manual** checklist, not an automated test. Run it once after Tasks 1–6 land (R3 plugin is what makes the live tag work).

- [ ] **Step 1: Launch CC in a known repo via router**

```bash
cd ~/Documents/Project/minipc
~/Documents/Project/iclaude/iclaude.sh --router
```
Send one message (any prompt that triggers one LLM call), then exit.

- [ ] **Step 2: Confirm the variable reached CCR (local check)**

While CC is still running, in another terminal confirm CCR's process environment carries the id:
```bash
pgrep -af 'ccr' | head
# then, with the CCR PID:
tr '\0' '\n' < /proc/<CCR_PID>/environ | grep ICLAUDE_PROJECT_ID
```
Expected: `ICLAUDE_PROJECT_ID=minipc`.

- [ ] **Step 3: Verify the trace tag in Langfuse ClickHouse (minipc host)**

```bash
docker exec minipc-traefik-clickhouse-1 sh -c \
  'clickhouse-client --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" -q \
   "SELECT tags FROM traces ORDER BY timestamp DESC LIMIT 1"'
```
**Accept** when the newest trace contains `project:minipc` (not `project:unknown`, and not the literal `project:${ICLAUDE_PROJECT_ID}`).

- [ ] **Step 4: Prove per-project isolation**

Repeat Steps 1 and 3 from a different repo (e.g. `~/Documents/Project/iclaude`). The newest trace tag must reflect that repo's name (`project:iclaude`), confirming the tag tracks the launch directory.

- [ ] **Step 5: Record the result**

Note the observed tags in the spec or a short results file. No commit required unless documenting the outcome.

---

## Rollback (per spec §7)

- `launch.sh`: revert the three commits from Tasks 1–3 (or remove `_derive_project_id`, `_init_project_id`, and the `_init_project_id "$use_router"` call). No behavior change to non-router launches results either way (the helper is a no-op when router is inactive).
- **R3 (Task 5):** remove `x-project-id.js` and revert the two `router.json` edits (drop `"x-project-id"` from the provider `transformer.use` and the plugin entry from the top-level `transformers`). Without the plugin, no `X-Project-Id` is sent → traffic reverts to `project:unknown`. Backup `router.json.bak-pre-xproject-*` predates these edits.
- No LiteLLM / Langfuse-side change was made, so nothing to roll back there.

---

## Self-Review

**Spec coverage:**
- R1 (CCR forwards provider header) — tested and FALSIFIED at runtime (Task 4); dead in CCR 2.0.0 (Background facts #1, #2). ✔
- R2 (per-project `ICLAUDE_PROJECT_ID` at launch, before CCR fork, git-toplevel derivation, sanitization, explicit-override) — Tasks 1–3. ✔
- R3 (CCR transformer plugin — the working mechanism) — Task 5 (plugin + `router.json` registration + test wired to exercise it). ✔
- R4 (virtual keys) — unused last resort; not needed since R3 works. ✔
- §5 acceptance — Task 7 (live) + Task 4 (hermetic, green after Task 5). ✔
- §7 rollback — covered above (incl. R3 plugin). ✔
- §6 hardening (secret in plaintext, prompt privacy, other clients) — explicitly out of scope per the spec; no task. ✔

**Placeholder scan:** No `TBD`/`add error handling`/"similar to Task N" — every code step shows full code and exact commands. ✔

**Type/name consistency:** `_derive_project_id` and `_init_project_id` are used with identical signatures across Tasks 1–3 and the test file; the test's `_extract` helper name and `assert_eq` match the existing harness; the env var name `ICLAUDE_PROJECT_ID` and header `X-Project-Id` match `router.json` and the spec throughout. ✔
