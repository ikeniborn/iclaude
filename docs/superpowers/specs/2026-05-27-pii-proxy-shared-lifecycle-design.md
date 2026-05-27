# PII Proxy Shared Lifecycle: Orphan Detection + Starter Meta

**Date:** 2026-05-27  
**Status:** Approved

## Problem

Two related bugs in shared PII proxy lifecycle:

1. **Orphan proxy**: when bash exits via SIGKILL or crash, EXIT trap skips. Consumer file stays, shared proxy keeps running. Next session sees live proxy with 0 real consumers and attaches instead of restarting.

2. **No useful meta on attach**: `/api/meta` always returns `session_id: "shared"` — useless. Attach message shows "started by: shared from /pwd", which doesn't identify which user session started the proxy.

Both bugs surface as: user closes all sessions, restarts iclaude, sees "attached to shared proxy on :XXXXX" with no meta explaining when/who.

## Goal

After fix:
```
ℹ PII proxy: attached to shared proxy on :27225 [standard] → https://api.anthropic.com | log: info | started by: abc123def456 from /home/user/project
```

And: fresh launch after all sessions die never attaches to an orphan.

## Scope

One file changes: `lib/launcher/launch.sh`. `server.py` unchanged.

## Data Model

New state file: `$PII_PROXY_PID_DIR/shared.starter`  
Content: `ICLAUDE_SESSION_ID` of the session that launched the shared proxy (12-char hex).

```
pii-proxy-pid/
  shared.pid       (existing) — PID of proxy process
  shared.lock      (existing) — flock serializer
  shared.starter   (NEW)      — SID of launching session
  consumers/
    <SID>.pid      (existing) — bash PID of each consumer session
```

Lifecycle of `shared.starter`:
- Written on proxy start (inside flock)
- Read on attach (inside flock)
- Deleted on last-consumer stop (inside flock, alongside `shared.pid`)
- Deleted on orphan kill (inside flock)

## Fix A: Orphan Detection

Location: flock subshell in `start_pii_proxy_server`, after `_sweep_dead_pii_consumers`.

```bash
_sweep_dead_pii_consumers
local _consumer_count
_consumer_count=$(ls "${PII_PROXY_PID_DIR}/consumers/"*.pid 2>/dev/null | wc -l)

# [existing alive check — sets _spid, _sport, _salive]

if [[ "$_salive" == "true" && "$_consumer_count" -eq 0 ]]; then
    # Orphan: proxy alive but no registered consumers (previous session died without cleanup)
    kill "$_spid" 2>/dev/null || true
    rm -f "$_shared_pid_file" \
          "${PII_PROXY_LOG_DIR}/pii-proxy-shared.port" \
          "${PII_PROXY_PID_DIR}/shared.starter"
    _salive=false
fi
```

Result: orphan proxy is killed, code falls through to "Start new shared proxy".

## Fix B: shared.starter File

### On proxy start

After `echo "$_proxy_pid" > "$_shared_pid_file"` (inside flock, "Start new shared proxy" block):

```bash
echo "${ICLAUDE_SESSION_ID:-unknown}" > "${PII_PROXY_PID_DIR}/shared.starter"
```

### On attach

Replace current meta fetch block (inside flock, "Attach" block, after `_register_pii_consumer`):

```bash
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
```

`_starter_sid` is passed as `sys.argv[1]` (not interpolated into the Python string) to prevent injection via malformed SID content.

### On stop (last consumer)

In `stop_pii_proxy_server`, shared branch, inside the `_count -eq 0` block, after `rm -f "$_shared_pid_file"`:

```bash
rm -f "${PII_PROXY_PID_DIR}/shared.starter"
```

## Failure Modes

| Failure | Behaviour |
|---------|-----------|
| `shared.starter` missing on attach | `_starter_sid` defaults to `"shared"` — same as before |
| curl not available / timeout | `_meta_json` empty → `_meta_suffix` empty → port-only message |
| `/api/meta` returns non-JSON | Python parse fails silently → `_meta_suffix` empty |
| `ICLAUDE_SESSION_ID` empty | writes `"unknown"` to `shared.starter` |
| Orphan kill fails (`kill` error) | `_salive` stays true, code attaches (safe degradation) |

## Out of Scope

- `status.sh` enrichment with `shared.starter`
- Showing consumer list in attach message
- Heartbeat-based consumer liveness (overkill)
