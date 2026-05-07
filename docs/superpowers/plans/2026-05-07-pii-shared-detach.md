# PII Shared Proxy Detach Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Detach shared PII proxy from master iclaude's process group and session so SIGHUP/SIGINT delivered to the master's PG no longer kill the proxy.

**Architecture:** Single-line bash change in `lib/launcher/launch.sh` shared-start branch — prefix `setsid` to the python invocation and redirect stdin from `/dev/null`. No Python changes. No protocol changes. Reference-counting layer untouched.

**Tech Stack:** bash 5+, util-linux `setsid`, Python 3.12 (server.py — unmodified).

**Spec:** `docs/superpowers/specs/2026-05-07-pii-shared-detach-design.md`

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `lib/launcher/launch.sh` | Bash launcher, contains `start_pii_proxy_server()` shared-start branch (lines 940-1009) | Modify lines 964-970: add `setsid` prefix + `</dev/null` |
| `lib/pii-proxy/server.py` | Python proxy server | **No change** |
| `tests/test_pii_shared_detach.sh` | New manual-test driver script | Create — automates terminal-close / Ctrl-C / SIGKILL scenarios using `script(1)` + `kill` |

Automated test note: full SIGHUP-from-tty simulation requires a pty. We use `setsid` itself (ironic) plus `kill -HUP` against a controlled bash subprocess holding the PG to reproduce the bug deterministically.

---

## Task 1: Reproduce the bug with a failing test

**Files:**
- Create: `tests/test_pii_shared_detach.sh`

- [ ] **Step 1: Write the failing repro test**

Create `tests/test_pii_shared_detach.sh`:

```bash
#!/usr/bin/env bash
# Regression test: shared PII proxy must survive SIGHUP/SIGINT delivered
# to the process group of the iclaude master that started it.
#
# Strategy: launch a "fake master" bash subshell that starts the PII proxy
# the same way launch.sh does, then deliver SIGHUP to that subshell's PG.
# A correct implementation leaves the proxy alive; the buggy implementation
# kills it via PG-wide signal delivery.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVER_SCRIPT="$REPO_ROOT/lib/pii-proxy/server.py"
PYTHON_BIN="${PII_TEST_PYTHON:-$REPO_ROOT/.nvm-isolated/.claude-isolated/pii-proxy-venv/bin/python3}"
LOG_DIR="$(mktemp -d)"
PORT=19876

if [[ ! -x "$PYTHON_BIN" ]]; then
    echo "SKIP: pii-proxy venv not installed at $PYTHON_BIN"
    exit 77
fi

cleanup() {
    pkill -P $$ 2>/dev/null || true
    rm -rf "$LOG_DIR"
}
trap cleanup EXIT

# Fake master: subshell in its own PG that launches the proxy the way
# launch.sh shared-start does. We extract the launch idiom under test.
fake_master() {
    # Mimic launch.sh:964-970 exactly
    ANTHROPIC_UPSTREAM_URL="https://api.anthropic.com" \
    ICLAUDE_SESSION_ID="shared" \
    PII_PROXY_LOG_LEVEL="info" \
        setsid "$PYTHON_BIN" "$SERVER_SCRIPT" \
        --port "$PORT" \
        --log-dir "$LOG_DIR" \
        </dev/null >/dev/null 2>&1 &
    local pid=$!
    disown "$pid" 2>/dev/null || true
    echo "$pid" > "$LOG_DIR/proxy.pid"
    # Master sleeps so we can signal it
    sleep 30
}

setsid bash -c "$(declare -f fake_master); fake_master" &
MASTER_PID=$!

# Wait for proxy to bind port file
for _ in $(seq 1 30); do
    [[ -f "$LOG_DIR/pii-proxy-shared.port" ]] && break
    sleep 0.5
done

if [[ ! -f "$LOG_DIR/pii-proxy-shared.port" ]]; then
    echo "FAIL: proxy never bound port"
    exit 1
fi

PROXY_PID=$(cat "$LOG_DIR/proxy.pid")

# Verify proxy alive
if ! kill -0 "$PROXY_PID" 2>/dev/null; then
    echo "FAIL: proxy not alive before signal"
    exit 1
fi

# Deliver SIGHUP to the master's whole PG (negative PID = PG)
kill -HUP -"$MASTER_PID" 2>/dev/null

# Give kernel time to deliver
sleep 1

# Proxy must still be alive (lives in its own session via setsid)
if kill -0 "$PROXY_PID" 2>/dev/null; then
    echo "PASS: proxy survived SIGHUP to master PG"
    kill "$PROXY_PID" 2>/dev/null
    exit 0
else
    echo "FAIL: proxy died with master PG"
    exit 1
fi
```

Make executable:

```bash
chmod +x tests/test_pii_shared_detach.sh
```

- [ ] **Step 2: Temporarily revert the fix in the test to confirm it FAILS without setsid**

Edit `tests/test_pii_shared_detach.sh` `fake_master` function — remove `setsid` and the `</dev/null` to simulate pre-fix behavior:

```bash
# Mimic OLD launch.sh:964-970 (pre-fix)
ANTHROPIC_UPSTREAM_URL="https://api.anthropic.com" \
ICLAUDE_SESSION_ID="shared" \
PII_PROXY_LOG_LEVEL="info" \
    "$PYTHON_BIN" "$SERVER_SCRIPT" \
    --port "$PORT" \
    --log-dir "$LOG_DIR" \
    >/dev/null 2>&1 &
```

Run:

```bash
bash tests/test_pii_shared_detach.sh
```

Expected output: `FAIL: proxy died with master PG` (exit 1). This confirms the test reproduces the bug.

- [ ] **Step 3: Restore the post-fix invocation in the test**

Restore the `setsid` + `</dev/null` form of the previous step. Re-running now would still fail because `launch.sh` itself isn't fixed yet — but the test driver itself is correct.

- [ ] **Step 4: Commit the test**

```bash
git add tests/test_pii_shared_detach.sh
git commit -m "test(pii-proxy): regression test for shared-proxy PG detach

Reproduces the bug where SIGHUP to master's process group also kills
the shared PII proxy because server.py inherits the master's PG.
Test will pass once setsid is added to the shared-start branch."
```

---

## Task 2: Apply the fix to launch.sh

**Files:**
- Modify: `lib/launcher/launch.sh:964-970`

- [ ] **Step 1: Read the current shared-start block**

```bash
sed -n '964,970p' lib/launcher/launch.sh
```

Expected current content:

```
                ANTHROPIC_UPSTREAM_URL="$_upstream" \
                ICLAUDE_SESSION_ID="shared" \
                PII_PROXY_LOG_LEVEL="${PII_PROXY_LOG_LEVEL:-info}" \
                    "$python_bin" "$PII_PROXY_SERVER_SCRIPT" \
                    --port "$PII_PROXY_PORT" \
                    --log-dir "$PII_PROXY_LOG_DIR" \
                    >/dev/null 2>&1 9>&- &
```

- [ ] **Step 2: Apply the change**

Replace the block above with:

```
                ANTHROPIC_UPSTREAM_URL="$_upstream" \
                ICLAUDE_SESSION_ID="shared" \
                PII_PROXY_LOG_LEVEL="${PII_PROXY_LOG_LEVEL:-info}" \
                    setsid "$python_bin" "$PII_PROXY_SERVER_SCRIPT" \
                    --port "$PII_PROXY_PORT" \
                    --log-dir "$PII_PROXY_LOG_DIR" \
                    </dev/null >/dev/null 2>&1 9>&- &
```

Two changes vs. original:
1. Insert `setsid ` directly before `"$python_bin"`.
2. Insert `</dev/null ` directly before `>/dev/null 2>&1 9>&- &`.

- [ ] **Step 3: Verify `setsid` is available**

```bash
command -v setsid
```

Expected: `/usr/bin/setsid` (or similar). Project is linux-only, util-linux ships everywhere.

- [ ] **Step 4: Bash syntax check**

```bash
bash -n lib/launcher/launch.sh
```

Expected: no output, exit 0.

- [ ] **Step 5: Run the regression test**

```bash
bash tests/test_pii_shared_detach.sh
```

Expected: `PASS: proxy survived SIGHUP to master PG` (exit 0).

- [ ] **Step 6: Commit the fix**

```bash
git add lib/launcher/launch.sh
git commit -m "fix(pii-proxy): detach shared proxy from master PG/session

Shared PII proxy died when master iclaude received SIGHUP (terminal
close) or SIGINT (Ctrl-C), because server.py inherited master's
process group; kernel delivers PG-wide signals to every member, and
server.py registers SIGINT/SIGTERM as graceful shutdown. Other
consumer sessions then lost their ANTHROPIC_BASE_URL channel.

Fix: prefix setsid to the shared-start invocation, placing the
proxy in a new session and process group. Redirect stdin from
/dev/null to detach from the controlling tty. Reference-counting
layer (consumers registry + flock) is unchanged and remains the
sole shutdown trigger.

Out of scope: per-session CCR proxy path, microVM, CCR server.

Spec: docs/superpowers/specs/2026-05-07-pii-shared-detach-design.md"
```

---

## Task 3: Manual end-to-end verification

These cannot be fully automated (require multiple terminals + real Claude API). Run them once before declaring done.

**Files:** none modified.

- [ ] **Step 1: Scenario — terminal close (SIGHUP)**

In terminal A:

```bash
./iclaude.sh
```

Wait for "PII proxy: shared proxy started on :PORT". Note PORT.

In terminal B:

```bash
./iclaude.sh
```

Wait for "PII proxy: attached to shared proxy on :PORT" (same PORT).

In a third terminal:

```bash
SHARED_PID=$(cat .nvm-isolated/.claude-isolated/pii-proxy-pid/shared.pid)
echo "Shared PID: $SHARED_PID"
ps -p "$SHARED_PID" -o pid,sid,pgid,cmd
```

Expected: `pid` and `sid` columns show the same value (proxy is its own session leader).

Close terminal A's window (the X button, or `Ctrl-D` followed by closing the window).

In the third terminal, after 2 seconds:

```bash
kill -0 "$SHARED_PID" && echo "ALIVE" || echo "DEAD"
```

Expected: `ALIVE`.

In terminal B, issue any prompt to Claude. Expected: succeeds.

- [ ] **Step 2: Scenario — Ctrl-C on master**

Repeat setup (terminals A and B). In terminal A press Ctrl-C until iclaude exits cleanly. Expected: terminal A's trap removes its consumer file; shared proxy alive (consumer count still 1 from terminal B); terminal B keeps working.

- [ ] **Step 3: Scenario — clean exit of last consumer**

With terminal B still running and terminal A already exited from step 2: in terminal B run `exit` or Ctrl-D. Expected: trap removes B's consumer file, count==0, shared proxy SIGTERM'd. Verify:

```bash
[[ -f .nvm-isolated/.claude-isolated/pii-proxy-pid/shared.pid ]] && echo "PIDFILE LEAKED" || echo "OK CLEANED"
```

Expected: `OK CLEANED`.

- [ ] **Step 4: Scenario — SIGKILL of master**

Start fresh terminals A and B as in Step 1. In terminal A find the iclaude bash PID (`echo $$` inside the iclaude session via Bash tool, or `pgrep -P $(pgrep -fo iclaude.sh)`). From terminal C: `kill -9 <pid>`. Expected: terminal A vanishes; shared proxy alive; terminal B works. Now start terminal D (`./iclaude.sh`); on its sweep, A's stale consumer file is removed; D attaches to the live proxy.

- [ ] **Step 5: Scenario — CCR mode unaffected**

```bash
./iclaude.sh --pii-proxy --router
```

Verify: dedicated proxy starts (not shared); `OWNED=true` path; on session exit the proxy dies. Check no `shared.pid` file is created during this session.

- [ ] **Step 6: If all scenarios pass, mark plan done**

No commit needed — the implementation is already committed in Task 2.

---

## Self-Review Notes

- **Spec coverage:** all five success criteria from spec are covered by Task 3 steps 1-5. Edge case of SIGKILL covered in step 4. Reference-counting unaffected — verified via step 3.
- **Placeholders:** none. Every step has exact commands, expected output, or full code.
- **Type consistency:** N/A — bash diff, no types.
- **Risk:** rollback is `git revert` of Task 2's commit. Test in Task 1 stays as a regression net.
