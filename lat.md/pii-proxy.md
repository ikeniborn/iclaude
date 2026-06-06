# PII Proxy

Python HTTP proxy (Presidio NLP) that intercepts Anthropic API traffic and masks PII/secrets before they leave the machine. Activated via `--pii-proxy` flag or `USE_PII_PROXY=true` in `.claude_config`.

## Architecture

```
Claude Code → PII proxy (127.0.0.1:PORT) → upstream (api.anthropic.com or CCR)
```

The proxy runs as a sidecar process per session. `ANTHROPIC_BASE_URL` is rewritten to `http://127.0.0.1:PORT` before Claude starts.

By default (`PII_PROXY_SUPERVISE=true`) the sidecar is a supervisor that binds the listening socket once and re-forks the request-serving worker if it dies — see [[pii-proxy#Respawn Supervisor]].

## Shared vs Per-Session Proxy

Three ownership modes determine lifecycle and cleanup behavior.

| Mode | When | Notes |
|------|------|-------|
| Shared | Standard `--pii-proxy` (no CCR) | One Python/Presidio process shared by all sessions; flock serializes start/stop |
| Per-session | `--pii-proxy --router` (CCR active) | Each session gets own proxy; upstream is CCR port (baked at startup) |
| Inherited | Subprocess launched by Claude's Bash tool | Reuses parent session's proxy; `PII_PROXY_SESSION_OWNED=false` prevents double-kill |

## Session Files

All per-session state lives under `$ISOLATED_CONFIG_DIR/pii-proxy-pid/`:

- `<SID>.pid` — PID of session's proxy process
- `shared.pid` — PID of shared proxy
- `shared.starter` — `ICLAUDE_SESSION_ID` (12-char hex) of the session that launched the shared proxy; written on start, deleted on last-consumer stop or orphan kill
- `consumers/<PID>.pid` — consumer registration (shared mode reference counting), keyed by process PID so same-`ICLAUDE_SESSION_ID` processes (a session and its Bash-tool sub-invocations) cannot cross-delete each other's entry
- `shared.lock` — flock lock for shared proxy start/stop

Port files live under `$ISOLATED_CONFIG_DIR/pii-proxy-logs/`:

- `pii-proxy-<SID>.port` — port written by Python server after bind
- `pii-proxy-shared.port` — shared proxy port

## Startup Sequence

`[[lib/launcher/launch.sh#start_pii_proxy_server]]`:

1. Detect Python binary in venv (`$ISOLATED_CONFIG_DIR/pii-proxy-venv`)
2. Inherited-env reuse guard: if the parent already exported `ICLAUDE_PII_ACTIVE=1` + `ANTHROPIC_BASE_URL` (non-CCR), inherit it and return early (`PII_PROXY_SESSION_OWNED=false`) before any consumer accounting — a sub-invocation can never deregister/kill the live session's proxy
3. Check for inherited parent proxy (same `ICLAUDE_SESSION_ID`) — reuse if alive
4. Acquire flock on `shared.lock`; sweep dead consumer PIDs; count live consumers
5. Orphan check: if proxy alive but `_consumer_count == 0` → kill orphan, delete `shared.pid` + port file + `shared.starter`, fall through to start
6. Attach to existing proxy (register consumer, read `shared.starter` → display "started by: &lt;SID&gt;") or start new proxy (write `shared.starter`)
7. Poll port file → TCP connect → HTTP `/api/health` (max 15s)
8. Export `ANTHROPIC_BASE_URL=http://127.0.0.1:PORT`

## Respawn Supervisor

`[[lib/pii-proxy/server.py#_supervise]]`. A session bakes `ANTHROPIC_BASE_URL` once at launch; if the proxy vanishes mid-session (OOM, crash, kill) the baked port dies and calls fail with `ConnectionRefused`. The supervisor keeps the proxy alive on a stable port.

When `PII_PROXY_SUPERVISE=true` (default), `server.py` binds the listening socket once in `[[lib/pii-proxy/server.py#_build_server]]`, writes the port file, then forks a worker (`[[lib/pii-proxy/server.py#_run_worker]]`) that serves on the **inherited** socket — so the port is stable across respawns. The supervisor `waitpid`s the worker and re-forks it on unexpected death. A restart-storm cap (`>5` restarts in `10s`) makes the supervisor log an error and exit instead of busy-looping. On `SIGTERM`/`SIGINT` the supervisor forwards the signal to the current worker and exits **without** respawning, so `shared.pid` (the supervisor PID) teardown is clean. Set `PII_PROXY_SUPERVISE=false` to fall back to the legacy single-process serve.

## Cleanup

`stop_pii_proxy_server()` on `EXIT/INT/TERM` trap:
- `PII_PROXY_SESSION_OWNED=false` → no-op (parent owns proxy)
- `PII_PROXY_SESSION_OWNED=shared` → deregister consumer; if count reaches 0: delete `shared.pid` + port file + `shared.starter`, then kill proxy
- `PII_PROXY_SESSION_OWNED=true` → kill proxy + remove PID/port files + delete session log (unless debug mode)

Killing a supervised proxy sends `SIGTERM` to the supervisor (the recorded `shared.pid`/PID), which forwards it to the live worker and exits without respawning — see [[pii-proxy#Respawn Supervisor]].

## Environment Signals

Exported before Claude starts to signal proxy state to statusline and hooks.

| Variable | Purpose |
|----------|---------|
| `ICLAUDE_PII_ACTIVE=1` | Tells statusline to show PII metrics |
| `ICLAUDE_PII_ACTIVE_PORT` | Port for statusline display |
| `ICLAUDE_PII_MASKING_LEVEL` | `standard` or custom level |
| `ICLAUDE_PII_LOG_PATH` | Path to session log (statusline hyperlink) |
