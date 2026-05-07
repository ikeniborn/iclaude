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
| `tests/test_pii_shared_detach.sh` | New regression test driver | Create — combines static grep of launch.sh AND behavioural verification of setsid idiom on this kernel |

The test has two assertions:
- **Static (A)** — grep `lib/launcher/launch.sh` for the post-fix invocation. Fails until launch.sh is modified. This is the actual regression net for "did the fix get reverted?".
- **Behavioural (B)** — runs the same idiom standalone and delivers SIGHUP to the synthetic master's PG; proxy must survive. Verifies setsid actually achieves detachment on the host kernel.

---

## Task 1: Write the failing regression test

**Files:**
- Create: `tests/test_pii_shared_detach.sh`

- [ ] **Step 1: Write the test driver**

Create `tests/test_pii_shared_detach.sh`:

```bash
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
# Locate the shared-start branch (between line containing 'Start new shared
# proxy' comment and the matching closing-brace block). We grep for the exact
# tokens of the post-fix idiom inside the file.
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

# Synthetic master: a bash subshell in its own session that starts the proxy
# via the exact post-fix idiom from launch.sh:964-970.
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
    sleep 30  # keep master alive so we can signal its PG
}

# `setsid bash -c ...` => master is in its own session, PGID == its PID
setsid bash -c "$(declare -f fake_master); fake_master '$PYTHON_BIN' '$SERVER_SCRIPT' '$LOG_DIR'" &
MASTER_PID=$!

# Wait for proxy to bind and write the port file (server.py writes
# pii-proxy-shared.port after binding)
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

# Sanity: confirm proxy is in a different session from the master.
# `ps -o sid=` prints the session ID. They must differ.
master_sid=$(ps -o sid= -p "$MASTER_PID" 2>/dev/null | tr -d ' ')
proxy_sid=$(ps -o sid= -p "$PROXY_PID" 2>/dev/null | tr -d ' ')
if [[ -z "$master_sid" || -z "$proxy_sid" || "$master_sid" == "$proxy_sid" ]]; then
    echo "FAIL[B]: proxy SID ($proxy_sid) == master SID ($master_sid); setsid did not detach"
    exit 1
fi
echo "INFO: master sid=$master_sid proxy sid=$proxy_sid (distinct)"

# Deliver SIGHUP to the master's whole PG. Negative PID = PG.
kill -HUP -"$MASTER_PID" 2>/dev/null
sleep 1

if kill -0 "$PROXY_PID" 2>/dev/null; then
    echo "PASS[B]: proxy survived SIGHUP to master PG"
    exit 0
else
    echo "FAIL[B]: proxy died with master PG"
    exit 1
fi
```

Make executable:

```bash
chmod +x tests/test_pii_shared_detach.sh
```

- [ ] **Step 2: Run the test — expect FAIL[A]**

```bash
bash tests/test_pii_shared_detach.sh
```

Expected output:

```
FAIL[A]: launch.sh does not contain 'setsid "$python_bin" "$PII_PROXY_SERVER_SCRIPT"' — fix missing or reverted
```

Exit code: 1. This confirms the static assertion correctly detects the un-fixed launch.sh.

- [ ] **Step 3: Commit the test**

```bash
git add tests/test_pii_shared_detach.sh
git commit -m "test(pii-proxy): regression test for shared-proxy PG detach

Two-part driver:
  A) static grep of launch.sh shared-start branch for the post-fix
     idiom (catches future reverts)
  B) behavioural test that spawns a synthetic master in its own
     session, launches the proxy via the same idiom, then sends
     SIGHUP to the master PG and asserts the proxy survives

Currently fails on assertion A because launch.sh is unfixed; will
pass after the next commit."
```

---

## Task 2: Apply the fix to launch.sh

**Files:**
- Modify: `lib/launcher/launch.sh:964-970`

- [ ] **Step 1: Read the current shared-start block**

```bash
sed -n '964,970p' lib/launcher/launch.sh
```

Expected current content (exact whitespace — leading 16 spaces of indentation):

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

Two additions vs. original:
1. Insert `setsid ` immediately before `"$python_bin"` (same indentation level).
2. Insert `</dev/null ` immediately before `>/dev/null 2>&1 9>&- &`.

- [ ] **Step 3: Confirm CCR per-session branch is untouched**

```bash
sed -n '1086,1095p' lib/launcher/launch.sh
```

Expected: still the original CCR per-session invocation, **without** `setsid`. CCR mode is out of scope.

- [ ] **Step 4: Verify `setsid` is available on the host**

```bash
command -v setsid
```

Expected: a path like `/usr/bin/setsid`. Project is linux-only; util-linux ships everywhere.

- [ ] **Step 5: Bash syntax check**

```bash
bash -n lib/launcher/launch.sh
```

Expected: no output, exit 0.

- [ ] **Step 6: Run the regression test — expect full PASS**

```bash
bash tests/test_pii_shared_detach.sh
```

Expected output (when venv is installed):

```
PASS[A]: launch.sh contains the post-fix idiom
INFO: master sid=<N> proxy sid=<M> (distinct)
PASS[B]: proxy survived SIGHUP to master PG
```

Exit code: 0.

If venv is not installed, expected:

```
PASS[A]: launch.sh contains the post-fix idiom
SKIP[B]: pii-proxy venv not installed at ... (run --install-pii-proxy)
```

Exit code: 0. (Skipping B is acceptable; A alone is the regression net.)

- [ ] **Step 7: Commit the fix**

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

Spec: docs/superpowers/specs/2026-05-07-pii-shared-detach-design.md
Test: tests/test_pii_shared_detach.sh"
```

---

## Task 3: Manual end-to-end verification

These cannot be fully automated (require multiple terminals + real Claude API). Run them once before declaring done.

**Files:** none modified.

Throughout this task, the shared-PID file lives at:

```
.nvm-isolated/.claude-isolated/pii-proxy-pid/shared.pid
```

Set a shorthand once:

```bash
export PIDFILE="$PWD/.nvm-isolated/.claude-isolated/pii-proxy-pid/shared.pid"
```

- [ ] **Step 1: Scenario — terminal close (SIGHUP)**

In terminal A:

```bash
./iclaude.sh
```

Wait for `PII proxy: shared proxy started on :PORT`. Note PORT.

In terminal B:

```bash
./iclaude.sh
```

Wait for `PII proxy: attached to shared proxy on :PORT` (same PORT).

In a separate observer terminal C:

```bash
SHARED_PID=$(cat "$PIDFILE")
echo "Shared PID: $SHARED_PID"
ps -o pid,sid,pgid,cmd -p "$SHARED_PID"
```

Expected: `pid` column equals `sid` column (proxy is its own session leader).

Now close terminal A's window via the WM close button (this delivers SIGHUP to A's bash).

In terminal C, after 2 seconds:

```bash
kill -0 "$SHARED_PID" && echo "ALIVE" || echo "DEAD"
```

Expected: `ALIVE`.

In terminal B, send any prompt to Claude. Expected: succeeds.

- [ ] **Step 2: Scenario — Ctrl-C on master**

Restart from a clean state: in terminal C run `pkill -f pii-proxy-server` to clear any leftover proxy, then start fresh terminals A and B as in Step 1.

In terminal A press Ctrl-C until iclaude exits cleanly (one Ctrl-C interrupts Claude; press again or type `exit` to leave iclaude). Expected: A's trap removes A's consumer file; shared proxy alive (consumer count > 0 from B); terminal B keeps working.

Verify in terminal C:

```bash
kill -0 "$(cat "$PIDFILE")" && echo "ALIVE" || echo "DEAD"
ls .nvm-isolated/.claude-isolated/pii-proxy-pid/consumers/
```

Expected: `ALIVE`; consumers dir contains exactly one `.pid` file (B's).

- [ ] **Step 3: Scenario — clean exit of last consumer**

Continuing from Step 2 with terminal B still running: in B run `exit`. Expected: B's trap removes B's consumer file, count becomes 0, shared proxy gets SIGTERM. Verify in terminal C:

```bash
[[ -f "$PIDFILE" ]] && echo "PIDFILE LEAKED" || echo "OK CLEANED"
```

Expected: `OK CLEANED`.

- [ ] **Step 4: Scenario — SIGKILL of master**

Start fresh terminals A and B as in Step 1. In observer terminal C, find the iclaude bash PID for terminal A:

```bash
# Lists every iclaude.sh process; identify A's by its tty
ps -e -o pid,tty,cmd | grep -E 'iclaude\.sh' | grep -v grep
```

Pick the PID whose tty matches terminal A's (run `tty` inside A to confirm). Then from C:

```bash
A_PID=<the-pid-you-picked>
kill -9 "$A_PID"
```

Expected: terminal A vanishes (no trap fires); shared proxy still alive; terminal B keeps working. Verify:

```bash
kill -0 "$(cat "$PIDFILE")" && echo "ALIVE" || echo "DEAD"
```

Expected: `ALIVE`.

Now start a third iclaude in terminal D:

```bash
./iclaude.sh
```

Expected: D's start path runs `_sweep_dead_pii_consumers` under flock, removes A's stale consumer file, and prints `PII proxy: attached to shared proxy on :PORT`. Verify:

```bash
ls .nvm-isolated/.claude-isolated/pii-proxy-pid/consumers/
```

Expected: two `.pid` files (B and D), no stale A entry.

Clean up: exit B and D, verify proxy dies (re-run Step 3's check).

- [ ] **Step 5: Scenario — CCR mode unaffected**

```bash
./iclaude.sh --pii-proxy --router
```

Verify:

```bash
ls .nvm-isolated/.claude-isolated/pii-proxy-pid/
```

Expected: a per-session `pii-proxy-<SID>.pid` file exists, **no** `shared.pid` file. CCR mode uses its own dedicated proxy.

Exit the session, then verify the per-session pid file is gone (cleaned by `OWNED=true` branch).

- [ ] **Step 6: All scenarios pass — done**

No commit needed. Implementation is committed in Task 2; regression test is committed in Task 1.

---

## Self-Review

- **Spec coverage:** all five success criteria from spec map to Task 3 steps 1-5. Edge case "SIGKILL of master then sweep" covered in step 4. Reference-counting unaffected — verified in step 3.
- **Placeholders:** none. Every command, expected output, and code block is concrete.
- **Type consistency:** N/A (bash diff, no type system).
- **TDD ordering:** Task 1's static assertion fails on un-fixed code, passes after Task 2 — correct red-green sequence.
- **Test independence:** assertion A is purely static, robust to host env; assertion B SKIPs cleanly when venv absent, so test is CI-safe.
- **Risk / rollback:** `git revert` of Task 2's commit reverts the fix; the test in Task 1 remains as a regression net and would catch the revert immediately.
