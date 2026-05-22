# PII Proxy `/api/meta` Endpoint

**Date:** 2026-05-22  
**Status:** Approved

## Problem

When a session attaches to an existing shared PII proxy the startup message shows only the port:

```text
ℹ PII proxy: attached to shared proxy on :38593
```

The settings the proxy was started with (masking level, upstream URL, log level, originating session, originating project directory) are invisible to the attaching session.

## Goal

Show full proxy profile on attach:

```text
ℹ PII proxy: attached to shared proxy on :38593 [standard] → https://api.anthropic.com | log: info | started by: a1b2c3d4e5f6 from /home/user/myproject
```

## Solution

Add `GET /api/meta` to the Python server. The bash attach path queries it and includes the result in the log line.

## Python Changes (`pii-proxy-server.py`)

### Module-level global

```python
_startup_meta: dict = {}  # populated in main() after server binds
```

### `main()` — populate after bind, before `serve_forever()`

```python
_startup_meta = {
    'session_id': session_id,
    'pwd': os.getcwd(),
    'upstream_url': str(UPSTREAM_URL),
    'masking_level': MASKING_LEVEL,
    'log_level': LOG_LEVEL,
    'started_at': _server_start_time,
}
```

`os.getcwd()` captures the working directory inherited from the launching bash process. `setsid` does not change CWD, so this reliably reflects the project directory of the session that started the proxy.

### `do_GET` — add route

```python
elif self.path == '/api/meta':
    self._meta()
```

### `_meta()` method

```python
def _meta(self) -> None:
    body = json.dumps(_startup_meta).encode()
    self.send_response(200)
    self.send_header('Content-Type', 'application/json')
    self.send_header('Content-Length', str(len(body)))
    self.end_headers()
    self.wfile.write(body)
```

## Bash Changes (`lib/launcher/launch.sh`)

In the `attach` branch (~line 972), after `_register_pii_consumer` and before writing `_shared_result`:

```bash
# Query shared proxy metadata for display
_meta_json=$(curl -sf --max-time 2 "http://127.0.0.1/${_sport}/api/meta" 2>/dev/null || true)
_meta_suffix=""
if [[ -n "$_meta_json" ]]; then
    _meta_suffix=$("$python_bin" -c "
import json, sys
d = json.loads(sys.stdin.read())
print(f\"[{d['masking_level']}] → {d['upstream_url']} | log: {d['log_level']} | started by: {d['session_id']} from {d['pwd']}\")
" <<< "$_meta_json" 2>/dev/null || true)
fi
echo "attach:${_sport}:${_meta_suffix}" > "$_shared_result"
```

The result token format changes from `attach:PORT` to `attach:PORT:SUFFIX`. The outer shell parses:

```bash
_mode="${_result%%:*}"          # attach
_rest="${_result#*:}"
_port="${_rest%%:*}"            # PORT
_meta_suffix="${_rest#*:}"      # SUFFIX (may be empty)
```

`print_info` line becomes:

```bash
print_info "PII proxy: attached to shared proxy on :$PII_PROXY_ACTIVE_PORT${_meta_suffix:+ $_meta_suffix}"
```

`${_meta_suffix:+ $_meta_suffix}` — appends with leading space only when non-empty, so the message degrades gracefully if the meta query fails.

## Failure Modes

| Failure | Behaviour |
| ------- | --------- |
| curl not available | `_meta_json` empty → `_meta_suffix` empty → original message shown |
| proxy returns non-JSON | python parse fails → `_meta_suffix` empty → original message shown |
| meta query timeout (>2s) | curl exits → `_meta_suffix` empty → original message shown |
| `_shared_result` colon in PWD | PWD passed in suffix string, not in token split position — safe |

## Out of Scope

- `status.sh` enrichment with `/api/meta` data (separate task)
- Passing meta to `start` path (already shows full info at line 1058)
- Authentication on `/api/meta` (server is localhost-only)
