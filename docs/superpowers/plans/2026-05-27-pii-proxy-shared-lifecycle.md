---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-05-27-pii-proxy-shared-lifecycle-design.md
review:
  plan_hash: e63d6f8dc31b34c9
  spec_hash: f0b64ad208a63bf2
  last_run: "2026-05-27"
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - id: F-001
      phase: structure
      severity: WARNING
      verdict: accepted
      section: "File Map table / Self-Review table"
      text: "Markdown lint warnings — table pipe spacing and list blank-line gaps (cosmetic, no impact on plan usability)"
    - id: F-002
      phase: coverage
      severity: WARNING
      verdict: accepted
      section: "Failure Modes"
      text: "Spec failure mode table says 'Orphan kill fails → _salive stays true' but spec code sets _salive=false unconditionally. Plan follows the code (correct). Spec table entry is misleading."
    - id: F-003
      phase: coverage
      severity: WARNING
      verdict: accepted
      section: "Task 6: Commit"
      text: "No lat.md update step. CLAUDE.md requires update-docs after non-trivial changes. Out of spec scope but should be added or run manually post-implementation."
---

# PII Proxy Shared Lifecycle: Orphan Detection + Starter Meta Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix two bugs in `lib/launcher/launch.sh`: (A) kill orphan shared proxy when all consumers are gone, (B) record which session started the shared proxy and display it on attach.

**Architecture:** Single file change — `lib/launcher/launch.sh`. Inside the flock subshell of `start_pii_proxy_server`, add orphan kill logic and `shared.starter` read/write. In `stop_pii_proxy_server`, delete `shared.starter` with `shared.pid`. `server.py` is not touched.

**Tech Stack:** bash, flock, curl, Python one-liner (already used inline)

---

## File Map

| File | Action | What changes |
|------|--------|-------------|
| `lib/launcher/launch.sh` | Modify | Orphan kill block (~line 960), starter write (~line 1003), meta block replacement (~line 975-983), starter delete (~line 1337) |
| `tests/test_pii_shared_lifecycle.sh` | Create | Static-analysis + behavioural tests for both fixes |

---

### Task 1: Write the failing test suite

**Files:**
- Create: `tests/test_pii_shared_lifecycle.sh`

- [ ] **Step 1: Create the test file**

```bash
#!/usr/bin/env bash
# Regression tests for PII proxy shared lifecycle fixes:
#   Fix A: orphan detection (kill proxy with 0 consumers)
#   Fix B: shared.starter file (starter SID tracking)
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCH_SH="$REPO_ROOT/lib/launcher/launch.sh"

pass() { echo "PASS[$1]: $2"; }
fail() { echo "FAIL[$1]: $2"; exit 1; }

# ---------------------------------------------------------------------------
# Fix A: orphan detection — static checks
# ---------------------------------------------------------------------------

# A1: orphan block exists (consumer count check before _salive branch)
if grep -qE '_consumer_count.*-eq.*0.*_salive.*false|_salive=false.*_consumer_count.*-eq.*0' "$LAUNCH_SH" ||
   grep -A5 '_consumer_count' "$LAUNCH_SH" 2>/dev/null | grep -q '_salive=false'; then
    pass "A1" "orphan block sets _salive=false"
else
    # Check combined: _consumer_count declared AND used in an orphan guard
    grep -q '_consumer_count' "$LAUNCH_SH" || fail "A1" "_consumer_count not found in launch.sh"
    grep -A10 '_consumer_count' "$LAUNCH_SH" | grep -q 'kill.*_spid\|_salive=false' ||
        fail "A1" "orphan block: _consumer_count found but no kill or _salive=false follows it"
    pass "A1" "orphan block contains _consumer_count check"
fi

# A2: starter deletion present in orphan kill block
grep -A20 '_consumer_count' "$LAUNCH_SH" | grep -q 'shared\.starter' ||
    fail "A2" "orphan block does not delete shared.starter"
pass "A2" "orphan block deletes shared.starter"

# ---------------------------------------------------------------------------
# Fix B: shared.starter — static checks
# ---------------------------------------------------------------------------

# B1: starter written after proxy PID recorded (start branch)
# Must appear after the `echo "$_proxy_pid" > "$_shared_pid_file"` line
python3 - "$LAUNCH_SH" <<'PYCHECK'
import sys, re
text = open(sys.argv[1]).read()
pid_write = text.find('echo "$_proxy_pid" > "$_shared_pid_file"')
starter_write = text.find('shared.starter', pid_write)
assert pid_write != -1, "pid write line not found"
assert starter_write != -1 and starter_write > pid_write, \
    "shared.starter write must appear after pid write"
print("PASS[B1]: shared.starter written after PID recorded")
PYCHECK
[[ $? -eq 0 ]] || fail "B1" "shared.starter not written in start branch after PID"

# B2: _starter_sid used in attach meta block (not d['session_id'])
grep -q '_starter_sid' "$LAUNCH_SH" ||
    fail "B2" "_starter_sid variable not found in launch.sh"
# Old code used d['session_id'] — new code must not
! grep -A5 '_meta_suffix.*python_bin\|python_bin.*meta_suffix' "$LAUNCH_SH" 2>/dev/null |
    grep -q "d\['session_id'\]" ||
    fail "B2" "attach meta block still uses d['session_id'] — not updated"
pass "B2" "_starter_sid replaces d['session_id'] in attach meta"

# B3: _starter_sid passed as sys.argv argument (not interpolated into Python string)
grep -A5 '_starter_sid' "$LAUNCH_SH" | grep -q 'sys\.argv\[1\]\|"\$_starter_sid"' ||
    fail "B3" "_starter_sid not passed via sys.argv or as quoted arg to python"
pass "B3" "_starter_sid passed safely to python (not interpolated)"

# B4: starter deleted on last consumer stop
python3 - "$LAUNCH_SH" <<'PYCHECK'
import sys
text = open(sys.argv[1]).read()
# Find the last-consumer stop block (after _count -eq 0 in stop_pii_proxy_server)
stop_idx = text.find('stop_pii_proxy_server()')
assert stop_idx != -1, "stop_pii_proxy_server not found"
stop_section = text[stop_idx:]
count_zero = stop_section.find('_count -eq 0')
assert count_zero != -1, "_count -eq 0 block not found in stop section"
block = stop_section[count_zero:count_zero+500]
assert 'shared.starter' in block, "shared.starter not deleted in last-consumer stop block"
print("PASS[B4]: shared.starter deleted in last-consumer stop block")
PYCHECK
[[ $? -eq 0 ]] || fail "B4" "shared.starter not deleted in stop_pii_proxy_server last-consumer block"

echo ""
echo "All static checks passed."
```

- [ ] **Step 2: Make the test executable**

```bash
chmod +x tests/test_pii_shared_lifecycle.sh
```

- [ ] **Step 3: Run to confirm all tests fail**

```bash
bash tests/test_pii_shared_lifecycle.sh
```

Expected: multiple `FAIL[A*]`/`FAIL[B*]` lines, exit 1.

---

### Task 2: Fix A — orphan detection

**Files:**
- Modify: `lib/launcher/launch.sh` (~lines 960-970, inside flock subshell of `start_pii_proxy_server`)

The flock subshell currently looks like:

```bash
flock -x 9
_sweep_dead_pii_consumers

# Check if shared proxy is alive
local _spid _sport _salive=false
```

- [ ] **Step 1: Add orphan detection block after `_sweep_dead_pii_consumers`**

Replace this block (lines 960-968 approx):

```bash
            flock -x 9
            _sweep_dead_pii_consumers

            # Check if shared proxy is alive
            local _spid _sport _salive=false
            _spid=$(cat "$_shared_pid_file" 2>/dev/null || true)
            if [[ -n "$_spid" ]] && kill -0 "$_spid" 2>/dev/null && \
               ps -p "$_spid" -o cmd= 2>/dev/null | grep -q 'pii-proxy-server.py'; then
                _sport=$(cat "$_shared_port_file" 2>/dev/null || true)
                [[ "$_sport" =~ ^[0-9]+$ ]] && _salive=true
            fi
```

With:

```bash
            flock -x 9
            _sweep_dead_pii_consumers
            local _consumer_count
            _consumer_count=$(ls "${PII_PROXY_PID_DIR}/consumers/"*.pid 2>/dev/null | wc -l)

            # Check if shared proxy is alive
            local _spid _sport _salive=false
            _spid=$(cat "$_shared_pid_file" 2>/dev/null || true)
            if [[ -n "$_spid" ]] && kill -0 "$_spid" 2>/dev/null && \
               ps -p "$_spid" -o cmd= 2>/dev/null | grep -q 'pii-proxy-server.py'; then
                _sport=$(cat "$_shared_port_file" 2>/dev/null || true)
                [[ "$_sport" =~ ^[0-9]+$ ]] && _salive=true
            fi

            if [[ "$_salive" == "true" && "$_consumer_count" -eq 0 ]]; then
                # Orphan: proxy alive but no registered consumers
                kill "$_spid" 2>/dev/null || true
                rm -f "$_shared_pid_file" \
                      "${PII_PROXY_LOG_DIR}/pii-proxy-shared.port" \
                      "${PII_PROXY_PID_DIR}/shared.starter"
                _salive=false
            fi
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n lib/launcher/launch.sh
```

Expected: no output, exit 0.

- [ ] **Step 3: Run tests — A checks must pass, B checks still fail**

```bash
bash tests/test_pii_shared_lifecycle.sh
```

Expected: `PASS[A1]`, `PASS[A2]`, then `FAIL[B*]`.

---

### Task 3: Fix B1 — write `shared.starter` on proxy start

**Files:**
- Modify: `lib/launcher/launch.sh` (~line 1002, inside flock subshell, "Start new shared proxy" block)

The current code after writing PID:

```bash
                local _proxy_pid=$!
                disown "$_proxy_pid" 2>/dev/null || true
                echo "$_proxy_pid" > "$_shared_pid_file"

                # Poll for port file then HTTP health (max 15s, 0.5s intervals)
```

- [ ] **Step 1: Add starter write after PID write**

Replace:

```bash
                local _proxy_pid=$!
                disown "$_proxy_pid" 2>/dev/null || true
                echo "$_proxy_pid" > "$_shared_pid_file"

                # Poll for port file then HTTP health (max 15s, 0.5s intervals)
```

With:

```bash
                local _proxy_pid=$!
                disown "$_proxy_pid" 2>/dev/null || true
                echo "$_proxy_pid" > "$_shared_pid_file"
                echo "${ICLAUDE_SESSION_ID:-unknown}" > "${PII_PROXY_PID_DIR}/shared.starter"

                # Poll for port file then HTTP health (max 15s, 0.5s intervals)
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n lib/launcher/launch.sh
```

Expected: no output, exit 0.

- [ ] **Step 3: Run tests — B1 check must pass**

```bash
bash tests/test_pii_shared_lifecycle.sh
```

Expected: `PASS[A1]`, `PASS[A2]`, `PASS[B1]`, then `FAIL[B2]` or later.

---

### Task 4: Fix B2 — read `shared.starter` on attach, pass via `sys.argv`

**Files:**
- Modify: `lib/launcher/launch.sh` (~lines 975-983, inside flock subshell, "Attach to existing shared proxy" block)

Current attach meta block:

```bash
            if [[ "$_salive" == "true" ]]; then
                # Attach to existing shared proxy
                _register_pii_consumer
                # Query proxy metadata for display (best-effort; failure degrades gracefully)
                local _meta_json _meta_suffix=""
                _meta_json=$(curl -sf --max-time 2 "http://127.0.0.1:${_sport}/api/meta" 2>/dev/null || true)
                if [[ -n "$_meta_json" ]]; then
                    _meta_suffix=$("$python_bin" -c "
import json, sys
d = json.loads(sys.stdin.read())
print(f\"[{d['masking_level']}] → {d['upstream_url']} | log: {d['log_level']} | started by: {d['session_id']} from {d['pwd']}\")
" <<< "$_meta_json" 2>/dev/null || true)
                fi
                echo "attach:${_sport}:${_meta_suffix}" > "$_shared_result"
```

- [ ] **Step 1: Replace meta block to read `_starter_sid` and pass via `sys.argv[1]`**

Replace the attach block above with:

```bash
            if [[ "$_salive" == "true" ]]; then
                # Attach to existing shared proxy
                _register_pii_consumer
                # Query proxy metadata for display (best-effort; failure degrades gracefully)
                local _starter_sid _meta_json _meta_suffix=""
                _starter_sid=$(cat "${PII_PROXY_PID_DIR}/shared.starter" 2>/dev/null || echo "shared")
                _meta_json=$(curl -sf --max-time 2 "http://127.0.0.1:${_sport}/api/meta" 2>/dev/null || true)
                if [[ -n "$_meta_json" ]]; then
                    _meta_suffix=$("$python_bin" -c "
import json, sys
d = json.loads(sys.stdin.read())
starter = sys.argv[1]
print(f\"[{d['masking_level']}] → {d['upstream_url']} | log: {d['log_level']} | started by: {starter} from {d['pwd']}\")
" "$_starter_sid" <<< "$_meta_json" 2>/dev/null || true)
                fi
                echo "attach:${_sport}:${_meta_suffix}" > "$_shared_result"
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n lib/launcher/launch.sh
```

Expected: no output, exit 0.

- [ ] **Step 3: Run tests — B2 and B3 checks must pass**

```bash
bash tests/test_pii_shared_lifecycle.sh
```

Expected: `PASS[A1]`, `PASS[A2]`, `PASS[B1]`, `PASS[B2]`, `PASS[B3]`, then `FAIL[B4]`.

---

### Task 5: Fix B3 — delete `shared.starter` on last-consumer stop

**Files:**
- Modify: `lib/launcher/launch.sh` (~line 1337, inside `stop_pii_proxy_server`, last-consumer block)

Current last-consumer stop block:

```bash
            if [[ "$_count" -eq 0 ]]; then
                local _spid
                _spid=$(cat "$_shared_pid_file" 2>/dev/null || true)
                if [[ -n "$_spid" ]] && kill -0 "$_spid" 2>/dev/null; then
                    kill "$_spid" 2>/dev/null || true
                    local _waited=0
                    while kill -0 "$_spid" 2>/dev/null && [[ $_waited -lt 10 ]]; do
                        sleep 0.1
                        _waited=$((_waited + 1))
                    done
                    kill -9 "$_spid" 2>/dev/null || true
                fi
                rm -f "$_shared_pid_file"
                rm -f "${PII_PROXY_LOG_DIR}/pii-proxy-shared.port"
```

- [ ] **Step 1: Add `shared.starter` deletion after `rm -f "$_shared_pid_file"`**

Replace:

```bash
                rm -f "$_shared_pid_file"
                rm -f "${PII_PROXY_LOG_DIR}/pii-proxy-shared.port"
```

With:

```bash
                rm -f "$_shared_pid_file"
                rm -f "${PII_PROXY_LOG_DIR}/pii-proxy-shared.port"
                rm -f "${PII_PROXY_PID_DIR}/shared.starter"
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n lib/launcher/launch.sh
```

Expected: no output, exit 0.

- [ ] **Step 3: Run full test suite — all checks must pass**

```bash
bash tests/test_pii_shared_lifecycle.sh
```

Expected: `PASS[A1]` `PASS[A2]` `PASS[B1]` `PASS[B2]` `PASS[B3]` `PASS[B4]`, exit 0, `"All static checks passed."`.

- [ ] **Step 4: Run existing PII proxy regression tests**

```bash
bash tests/test_pii_shared_detach.sh
```

Expected: `PASS[A]`, either `PASS[B]` or `SKIP[B]` (if venv not installed).

---

### Task 6: Commit

**Files:**
- `lib/launcher/launch.sh` (modified)
- `tests/test_pii_shared_lifecycle.sh` (created)

- [ ] **Step 1: Stage and commit**

```bash
git add lib/launcher/launch.sh tests/test_pii_shared_lifecycle.sh
git commit -m "fix(pii-proxy): orphan detection + shared.starter SID tracking

Fix A: inside start_pii_proxy_server flock subshell, after
_sweep_dead_pii_consumers, count remaining consumers. If proxy is
alive but _consumer_count == 0, the previous session died without
cleanup. Kill the orphan and fall through to a fresh start.

Fix B: write ICLAUDE_SESSION_ID to shared.starter on proxy start.
On attach, read it as _starter_sid and pass it as sys.argv[1] to
the Python meta formatter (prevents injection). Delete shared.starter
on last-consumer stop and in the orphan kill path.

Before: attach showed 'started by: shared from /pwd'
After:  attach shows 'started by: abc123def456 from /home/user/proj'"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Covered by |
|-----------------|------------|
| Orphan kill when `_consumer_count == 0` | Task 2 |
| `shared.starter` written on proxy start | Task 3 |
| `_starter_sid` read from file on attach | Task 4 |
| `_starter_sid` passed as `sys.argv[1]` (not interpolated) | Task 4 |
| `shared.starter` deleted on last-consumer stop | Task 5 |
| `shared.starter` deleted in orphan kill path | Task 2 |
| Graceful fallback: missing file → `"shared"` | Task 4 (`|| echo "shared"`) |
| Graceful fallback: curl fail → empty suffix | Task 4 (existing `|| true`) |
| Graceful fallback: Python parse fail → empty suffix | Task 4 (existing `|| true`) |
| `ICLAUDE_SESSION_ID` empty → writes `"unknown"` | Task 3 (`:-unknown`) |

**No placeholders:** all steps contain actual code.

**Type/name consistency:** `_consumer_count`, `_starter_sid`, `_meta_suffix`, `_salive` — used consistently across tasks.
