# PII Proxy

Python HTTP proxy (Presidio NLP) that intercepts Anthropic API traffic and masks PII/secrets before they leave the machine. Activated via `--pii-proxy` flag or `USE_PII_PROXY=true` in `.claude_config`.

## Architecture

```
Claude Code → PII proxy (127.0.0.1:PORT) → upstream (api.anthropic.com or CCR)
```

The proxy runs as a sidecar process per session. `ANTHROPIC_BASE_URL` is rewritten to `http://127.0.0.1:PORT` before Claude starts.

## Shared vs Per-Session Proxy

| Mode | When | Notes |
|------|------|-------|
| Shared | Standard `--pii-proxy` (no CCR) | One Python/Presidio process shared by all sessions; flock serializes start/stop |
| Per-session | `--pii-proxy --router` (CCR active) | Each session gets own proxy; upstream is CCR port (baked at startup) |
| Inherited | Subprocess launched by Claude's Bash tool | Reuses parent session's proxy; `PII_PROXY_SESSION_OWNED=false` prevents double-kill |

## Session Files

All per-session state lives under `$ISOLATED_CONFIG_DIR/pii-proxy-pid/`:

- `<SID>.pid` — PID of session's proxy process
- `shared.pid` — PID of shared proxy
- `consumers/<SID>.pid` — consumer registration (shared mode reference counting)
- `shared.lock` — flock lock for shared proxy start/stop

Port files live under `$ISOLATED_CONFIG_DIR/pii-proxy-logs/`:

- `pii-proxy-<SID>.port` — port written by Python server after bind
- `pii-proxy-shared.port` — shared proxy port

## Startup Sequence

`[[lib/launcher/launch.sh#start_pii_proxy_server]]`:

1. Detect Python binary in venv (`$ISOLATED_CONFIG_DIR/pii-proxy-venv`)
2. Check for inherited parent proxy (same `ICLAUDE_SESSION_ID`) — reuse if alive
3. Acquire flock on `shared.lock`; attach to or start shared proxy
4. Poll port file → TCP connect → HTTP `/api/health` (max 15s)
5. Export `ANTHROPIC_BASE_URL=http://127.0.0.1:PORT`

## Cleanup

`stop_pii_proxy_server()` on `EXIT/INT/TERM` trap:
- `PII_PROXY_SESSION_OWNED=false` → no-op (parent owns proxy)
- `PII_PROXY_SESSION_OWNED=shared` → deregister consumer; kill proxy only if count reaches 0
- `PII_PROXY_SESSION_OWNED=true` → kill proxy + remove PID/port files + delete session log (unless debug mode)

## Environment Signals

| Variable | Purpose |
|----------|---------|
| `ICLAUDE_PII_ACTIVE=1` | Tells statusline to show PII metrics |
| `ICLAUDE_PII_ACTIVE_PORT` | Port for statusline display |
| `ICLAUDE_PII_MASKING_LEVEL` | `standard` or custom level |
| `ICLAUDE_PII_LOG_PATH` | Path to session log (statusline hyperlink) |
