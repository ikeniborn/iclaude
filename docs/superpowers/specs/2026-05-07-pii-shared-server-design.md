# PII Proxy: Shared Server Design

**Date:** 2026-05-07  
**Status:** Approved  

## Problem

Each iclaude session with `--pii-proxy` starts its own Python process and loads the full Presidio NLP library (~300–500 MB RSS). With N concurrent sessions → N × memory.

## Goal

Share one PII proxy process across all "clean PII" sessions (no CCR). On startup: connect to existing proxy if alive. On shutdown: only kill proxy when last consumer exits.

## Scope

- **In scope:** solo `--pii-proxy` sessions (upstream = `https://api.anthropic.com`)
- **Out of scope:** `--pii-proxy --router` (CCR combined mode) — these always get a dedicated proxy (unchanged behavior)
- **Unchanged:** sub-process reuse within same `ICLAUDE_SESSION_ID` (existing parent-SID guard)

## Architecture

### File Layout

```
$ISOLATED_CONFIG_DIR/
├── pii-proxy-pid/
│   ├── shared.pid          ← PID of shared proxy
│   ├── shared.lock         ← flock mutex for atomic operations
│   ├── consumers/          ← NEW: one file per active consumer session
│   │   ├── <SID1>.pid      ← bash PID of session SID1
│   │   └── <SID2>.pid      ← bash PID of session SID2
│   └── <SID>.pid           ← per-session PID (CCR mode, unchanged)

$PII_PROXY_LOG_DIR/
├── pii-proxy-shared.port   ← port of shared proxy
├── shared.log              ← shared proxy log
└── <SID>.{port,log}        ← per-session files (CCR mode, unchanged)
```

### `PII_PROXY_SESSION_OWNED` Values

| Value | Meaning | Action on stop |
|---|---|---|
| `true` | This session started a per-session proxy (CCR mode) | Kill process |
| `shared` | NEW: This session attached to shared proxy | Deregister; kill proxy if no consumers remain |
| `false` | Sub-process inherited parent SID | Do nothing |

### server.py SID for Shared Proxy

Pass `ICLAUDE_SESSION_ID=shared` when starting shared proxy. One-line change in `server.py`:

```python
# Before:
session_id = _raw_sid if re.fullmatch(r'[0-9a-f]{12}', _raw_sid) else 'default'
# After:
session_id = _raw_sid if (re.fullmatch(r'[0-9a-f]{12}', _raw_sid) or _raw_sid == 'shared') else 'default'
```

Result: port file → `pii-proxy-shared.port`, log → `shared.log`.

## Lifecycle Flows

### Startup: `start_pii_proxy_server()` — new flow for non-CCR mode

```
[existing same-SID parent reuse check — UNCHANGED]
     ↓ (no parent proxy found)
acquire flock(shared.lock, EXCLUSIVE)
  sweep_dead_consumers()
      → scan pii-proxy-pid/consumers/*.pid
      → remove files where kill -0 <pid> fails
  is shared proxy alive?
      → read shared.pid
      → kill -0 <pid> 2>/dev/null
      → ps -p <pid> -o cmd= | grep 'pii-proxy-server.py'
     ↓ ALIVE                        ↓ DEAD / NO FILE
  register_consumer()          start new shared proxy:
  set OWNED=shared               ICLAUDE_SESSION_ID=shared
  export ANTHROPIC_BASE_URL      --port $PII_PROXY_PORT
  return 0                       --log-dir $PII_PROXY_LOG_DIR
                                 poll port file (max 15s)
                                 HTTP health check /api/health
                                 write shared.pid
                                 register_consumer()
                                 set OWNED=shared
                                 export ANTHROPIC_BASE_URL
                                 return 0
release flock
```

`register_consumer()`: creates `pii-proxy-pid/consumers/$ICLAUDE_SESSION_ID.pid` containing `$$` (bash PID of iclaude session).

### Shutdown: `stop_pii_proxy_server()` — new branch for `shared`

```bash
if [[ "$PII_PROXY_SESSION_OWNED" == "shared" ]]; then
    (
        flock 9
        rm -f "$PII_PROXY_PID_DIR/consumers/$ICLAUDE_SESSION_ID.pid"
        sweep_dead_consumers   # remove other dead consumers while holding lock
        count=$(ls "$PII_PROXY_PID_DIR/consumers/"*.pid 2>/dev/null | wc -l)
        if [[ $count -eq 0 ]]; then
            pid=$(cat "$PII_PROXY_PID_DIR/shared.pid" 2>/dev/null)
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null
                waited=0
                while kill -0 "$pid" 2>/dev/null && [[ $waited -lt 10 ]]; do
                    sleep 0.1; waited=$((waited + 1))
                done
                kill -9 "$pid" 2>/dev/null || true
            fi
            rm -f "$PII_PROXY_PID_DIR/shared.pid"
            rm -f "$PII_PROXY_LOG_DIR/pii-proxy-shared.port"
            [[ "${PII_PROXY_LOG_LEVEL:-info}" != "debug" ]] && \
                rm -f "$PII_PROXY_LOG_DIR/shared.log"
        fi
    ) 9>"$PII_PROXY_PID_DIR/shared.lock"
fi
```

### `sweep_dead_consumers()` helper

Called inside an already-held flock. Scans `pii-proxy-pid/consumers/*.pid`, removes any file whose PID is dead (`kill -0` fails). No subprocess spawning needed — bash built-in.

## Race Conditions

| Scenario | Protection |
|---|---|
| Two sessions simultaneously start proxy | flock: only one enters critical section; second finds alive proxy |
| Session killed with SIGKILL (no trap) | Consumer file remains; sweep removes it on next start/stop |
| Two sessions simultaneously stop, both count 0 consumers | flock: serialized — only one counts 0 and kills |
| PID recycled (another process got same PID) | `ps cmd grep 'pii-proxy-server.py'` validates process identity |

## Configuration

Shared proxy starts with the first session's config: `PII_PROXY_MASKING_LEVEL`, `PII_PROXY_LOG_LEVEL`, upstream URL. Subsequent sessions inherit whatever the running proxy was configured with — acceptable because all clean-PII sessions read from the same `.claude_config`.

## Status Display (`status.sh`)

Add shared proxy section:
- Shared proxy: PID, port, uptime
- Active consumers: list of SIDs with their bash PIDs

## Files Changed

| File | Change |
|---|---|
| `lib/launcher/launch.sh` | `start_pii_proxy_server()`: add shared proxy check before starting new; `stop_pii_proxy_server()`: add `shared` branch; new helpers `sweep_dead_consumers`, `register_consumer` |
| `lib/pii-proxy/server.py` | 1 line: add `or _raw_sid == 'shared'` to session_id validation |
| `lib/pii-proxy/status.sh` | Show shared proxy section + consumer list |

## What Does Not Change

- CCR combined mode (`--pii-proxy --router`): `CCR_SESSION_OWNED=true` triggers existing branch, dedicated proxy
- Sub-process reuse (same-SID Bash tool calls): existing parent-SID guard fires before shared logic
- Install, update, check-isolated commands
- Legacy `pii-proxy.pid` migration sweep
- Per-session log behavior in CCR mode

## Success Criteria

1. Two clean-PII sessions → single Python process, single NLP library load
2. Second session connects to first's proxy without restart
3. First session exits, second still running → proxy stays alive
4. Last session exits → proxy terminates cleanly
5. Session killed with SIGKILL → on next session start, sweep cleans stale consumer file, proxy starts fresh
6. CCR sessions unaffected
