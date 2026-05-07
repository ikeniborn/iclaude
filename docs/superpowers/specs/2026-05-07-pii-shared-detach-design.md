# PII Shared Proxy: Detach From Master Process Group

**Date:** 2026-05-07
**Status:** Approved
**Related:** `2026-05-07-pii-shared-server-design.md` (reference-counting layer)

## Problem

Shared PII proxy reference-counting (consumers registry + flock) works correctly, but the proxy still dies when the master iclaude session that started it exits via SIGHUP (terminal close) or SIGINT (Ctrl-C). Other consumer sessions then lose their `ANTHROPIC_BASE_URL` channel and Claude requests fail.

## Root Cause

`lib/launcher/launch.sh:967` starts `server.py` via bash `&` plus `disown`. `disown` removes the job from bash job-control but does not place the process in a new session or process group. The Python server inherits:

- Master's process group (PG)
- Master's session ID
- Master's controlling tty

`server.py:1042-1043` registers SIGINT and SIGTERM as graceful shutdown. When the master's terminal closes, the kernel delivers SIGHUP to every process in the foreground PG; when the user hits Ctrl-C, SIGINT goes to the same PG. The shared proxy receives the signal and exits, despite consumer count > 1.

## Goal

Detach the shared proxy from master's session/PG so it survives master signal events. Reference-counting (existing) remains the sole shutdown trigger.

## Scope

- **In scope:** shared proxy start path (`OWNED=shared`, `lib/launcher/launch.sh` lines 964-970).
- **Out of scope:** per-session CCR proxy, per-session non-shared paths, microVM, CCR server.

## Change

File: `lib/launcher/launch.sh`, shared-start branch.

```bash
# Before
ANTHROPIC_UPSTREAM_URL="$_upstream" \
ICLAUDE_SESSION_ID="shared" \
PII_PROXY_LOG_LEVEL="${PII_PROXY_LOG_LEVEL:-info}" \
    "$python_bin" "$PII_PROXY_SERVER_SCRIPT" \
    --port "$PII_PROXY_PORT" \
    --log-dir "$PII_PROXY_LOG_DIR" \
    >/dev/null 2>&1 9>&- &

# After
ANTHROPIC_UPSTREAM_URL="$_upstream" \
ICLAUDE_SESSION_ID="shared" \
PII_PROXY_LOG_LEVEL="${PII_PROXY_LOG_LEVEL:-info}" \
    setsid "$python_bin" "$PII_PROXY_SERVER_SCRIPT" \
    --port "$PII_PROXY_PORT" \
    --log-dir "$PII_PROXY_LOG_DIR" \
    </dev/null >/dev/null 2>&1 9>&- &
```

Three additions:
1. `setsid` prefix → new session + new PG for the server.
2. `</dev/null` redirect → detach stdin from tty.
3. Existing `disown "$_proxy_pid"` (line 973) preserved.

Per-session CCR start path (lines 1088-1094) untouched.

## Validation

- `setsid` requirement: util-linux, present on every supported Linux distro. Project is linux-only (CLAUDE.md). No fallback.
- PID capture: `setsid cmd &` → `$!` returns the PID of the original process. After `execve`, that PID becomes the python process. The existing identity check `ps -p <pid> -o cmd= | grep 'pii-proxy-server.py'` (line 948) catches mismatches.

## Edge Cases

| Scenario | Behavior |
|---|---|
| Master exits cleanly (trap EXIT) | `stop_pii_proxy_server` runs, flock, decrement consumers, kill proxy if count==0. Unchanged. |
| Master closed via terminal (SIGHUP) | Master dies; trap may or may not fire; proxy survives (new session). Consumer file may remain stale; next session start sweep removes it. |
| Master Ctrl-C (SIGINT) | Trap EXIT fires (bash invokes traps on SIGINT before exit). Reference-counting handles. Proxy survives signal regardless. |
| Master SIGKILL | No trap. Consumer file stale. Next session start: sweep removes stale; attach to live proxy. |
| Last consumer exits | flock, count==0 → SIGTERM proxy. Same-uid SIGTERM works regardless of session detach. |
| Two consumers exit concurrently | flock serializes; only one observes count==0 and kills. Unchanged. |

## Files Changed

| File | Change |
|---|---|
| `lib/launcher/launch.sh` | shared-start branch: add `setsid` prefix and `</dev/null` redirect (1 effective line) |

## What Does Not Change

- `server.py` — no Python changes.
- `stop_pii_proxy_server()` — reference-counting flow unchanged.
- Consumer registry, flock semantics, sweep helper.
- CCR per-session proxy lifecycle.
- `status.sh`, install, detect, update.

## Success Criteria

1. Term1 starts shared proxy, term2 attaches; closing term1 window (SIGHUP) leaves proxy alive and term2 functional.
2. Same as 1 but term1 exits via Ctrl-C — proxy alive, term2 functional.
3. Same as 1 but term1 exits via `exit` — proxy alive (consumer count > 0), term2 functional; on term2 exit, proxy terminates.
4. SIGKILL of term1 master → proxy alive; term3 start invokes sweep, attaches to live proxy.
5. `--pii-proxy --router` (CCR mode) unaffected: dedicated proxy, killed on session end.

## Risk

Minimal. Single-line bash addition. `setsid` is a well-defined POSIX-extension command. Reverting is a 1-line revert. No data migration, no protocol change, no on-disk format change.
