# PII Proxy `/api/meta` Endpoint Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `GET /api/meta` to the PII proxy server and update the bash attach path to display the shared proxy's startup profile (masking level, upstream URL, log level, session ID, PWD) when a new session attaches.

**Architecture:** Python server gains a module-level `_startup_meta` dict populated in `main()` after bind; a new `_meta()` handler serialises it as JSON. The bash attach branch queries this endpoint via `curl`, parses the JSON with `$python_bin`, and appends a suffix to the existing `print_info` message. Failure to query degrades gracefully to the current message.

**Tech Stack:** Python 3.8+ (`http.server`, `json`, `os`), bash, `curl`, `pytest`

---

## File Map

| File | Action | Responsibility |
| ---- | ------ | -------------- |
| `.nvm-isolated/.claude-isolated/pii-proxy-server.py` | Modify | Add `_startup_meta` global, populate in `main()`, add `/api/meta` route + `_meta()` method |
| `tests/test_pii_meta_endpoint.py` | Create | Unit tests for `_meta()` response shape and `do_GET` routing |
| `lib/launcher/launch.sh` | Modify | Attach branch: query `/api/meta`, parse JSON suffix, update `_shared_result` token format and `print_info` line |

---

## Task 1: Write failing tests for `/api/meta`

**Files:**
- Create: `tests/test_pii_meta_endpoint.py`

- [ ] **Step 1: Create test file**

```python
"""Tests for GET /api/meta endpoint in pii-proxy-server.py."""
import io
import json
import sys
import os
import importlib
from unittest.mock import patch, MagicMock

# The server validates ANTHROPIC_UPSTREAM_URL at import time; supply a valid value.
os.environ.setdefault('ANTHROPIC_UPSTREAM_URL', 'https://api.anthropic.com')
os.environ.setdefault('PII_PROXY_LOG_DIR', '/tmp/pii-proxy-test-logs')

# Import server module from its non-package path
import importlib.util
_spec = importlib.util.spec_from_file_location(
    'pii_proxy_server',
    os.path.join(
        os.path.dirname(__file__),
        '../.nvm-isolated/.claude-isolated/pii-proxy-server.py',
    ),
)
pii = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pii)


def _make_handler(path: str) -> pii.PIIProxyHandler:
    """Return a PIIProxyHandler instance wired for testing (no real socket)."""
    handler = pii.PIIProxyHandler.__new__(pii.PIIProxyHandler)
    handler.path = path
    handler.wfile = io.BytesIO()
    handler.rfile = io.BytesIO()
    handler.headers = {}
    handler.requestline = f'GET {path} HTTP/1.1'
    handler.request_version = 'HTTP/1.1'
    handler.command = 'GET'
    # Capture send_response / send_header / end_headers calls
    handler._response_code = None
    handler._response_headers = {}
    def _send_response(code, message=None):
        handler._response_code = code
    def _send_header(key, value):
        handler._response_headers[key] = value
    def _end_headers():
        pass
    handler.send_response = _send_response
    handler.send_header = _send_header
    handler.end_headers = _end_headers
    return handler


class TestMetaEndpoint:
    def test_meta_returns_200(self):
        pii._startup_meta = {
            'session_id': 'shared',
            'pwd': '/home/user/project',
            'upstream_url': 'https://api.anthropic.com',
            'masking_level': 'standard',
            'log_level': 'info',
            'started_at': 1716384000.0,
        }
        handler = _make_handler('/api/meta')
        handler._meta()
        assert handler._response_code == 200

    def test_meta_content_type_json(self):
        pii._startup_meta = {
            'session_id': 'shared',
            'pwd': '/tmp',
            'upstream_url': 'https://api.anthropic.com',
            'masking_level': 'secrets',
            'log_level': 'debug',
            'started_at': 0.0,
        }
        handler = _make_handler('/api/meta')
        handler._meta()
        assert handler._response_headers.get('Content-Type') == 'application/json'

    def test_meta_body_contains_all_fields(self):
        expected = {
            'session_id': 'abc123def456',
            'pwd': '/srv/myapp',
            'upstream_url': 'https://api.anthropic.com',
            'masking_level': 'off',
            'log_level': 'info',
            'started_at': 9999.0,
        }
        pii._startup_meta = expected
        handler = _make_handler('/api/meta')
        handler._meta()
        body = json.loads(handler.wfile.getvalue())
        assert body == expected

    def test_do_get_routes_meta(self):
        """do_GET dispatches /api/meta to _meta()."""
        pii._startup_meta = {
            'session_id': 'shared', 'pwd': '/x',
            'upstream_url': 'https://api.anthropic.com',
            'masking_level': 'standard', 'log_level': 'info',
            'started_at': 0.0,
        }
        handler = _make_handler('/api/meta')
        # Patch _proxy_passthrough to detect if it's called by mistake
        called = []
        handler._proxy_passthrough = lambda: called.append(True)
        handler.do_GET()
        assert handler._response_code == 200
        assert called == [], "_proxy_passthrough must not be called for /api/meta"

    def test_do_get_unknown_path_falls_through(self):
        """Unknown GET path still reaches _proxy_passthrough, not _meta."""
        pii._startup_meta = {}
        handler = _make_handler('/unknown')
        called = []
        handler._proxy_passthrough = lambda: called.append(True)
        handler.do_GET()
        assert called == [True]
```

- [ ] **Step 2: Run tests — expect ImportError or AttributeError (endpoint not yet implemented)**

```bash
cd /home/altuser/Документы/Project/iclaude
python3 -m pytest tests/test_pii_meta_endpoint.py -v 2>&1 | head -40
```

Expected: tests collected but fail with `AttributeError: type object 'PIIProxyHandler' has no attribute '_meta'` or `AttributeError: module has no attribute '_startup_meta'`.

---

## Task 2: Implement `/api/meta` in Python server

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/pii-proxy-server.py`

- [ ] **Step 1: Add `_startup_meta` module global**

Find the block of other module-level globals (after line ~214, near `_server_start_time`):

```python
_server_start_time: float = 0.0  # set in main() after server binds
```

Add immediately after it:

```python
_startup_meta: dict = {}  # set in main() after server binds
```

- [ ] **Step 2: Populate `_startup_meta` in `main()`**

In `main()`, find the line that sets `_server_start_time` (around line 1045-1046):

```python
global _server_start_time
_server_start_time = time.time()
```

Replace with:

```python
global _server_start_time, _startup_meta
_server_start_time = time.time()
_startup_meta = {
    'session_id': session_id,
    'pwd': os.getcwd(),
    'upstream_url': str(UPSTREAM_URL),
    'masking_level': MASKING_LEVEL,
    'log_level': LOG_LEVEL,
    'started_at': _server_start_time,
}
```

- [ ] **Step 3: Add `/api/meta` route to `do_GET`**

Find `do_GET` (around line 718-724):

```python
def do_GET(self) -> None:
    if self.path == '/api/health':
        self._health()
    elif self.path == '/api/metrics':
        self._metrics()
    else:
        self._proxy_passthrough()
```

Replace with:

```python
def do_GET(self) -> None:
    if self.path == '/api/health':
        self._health()
    elif self.path == '/api/metrics':
        self._metrics()
    elif self.path == '/api/meta':
        self._meta()
    else:
        self._proxy_passthrough()
```

- [ ] **Step 4: Add `_meta()` method**

Place it immediately after `_metrics()` (around line 797, after `try:` block closes). Add:

```python
def _meta(self) -> None:
    body = json.dumps(_startup_meta).encode()
    self.send_response(200)
    self.send_header('Content-Type', 'application/json')
    self.send_header('Content-Length', str(len(body)))
    self.end_headers()
    self.wfile.write(body)
```

- [ ] **Step 5: Run tests — expect all pass**

```bash
cd /home/altuser/Документы/Project/iclaude
python3 -m pytest tests/test_pii_meta_endpoint.py -v
```

Expected output:
```
tests/test_pii_meta_endpoint.py::TestMetaEndpoint::test_meta_returns_200 PASSED
tests/test_pii_meta_endpoint.py::TestMetaEndpoint::test_meta_content_type_json PASSED
tests/test_pii_meta_endpoint.py::TestMetaEndpoint::test_meta_body_contains_all_fields PASSED
tests/test_pii_meta_endpoint.py::TestMetaEndpoint::test_do_get_routes_meta PASSED
tests/test_pii_meta_endpoint.py::TestMetaEndpoint::test_do_get_unknown_path_falls_through PASSED
5 passed
```

- [ ] **Step 6: Verify syntax**

```bash
python3 -m py_compile .nvm-isolated/.claude-isolated/pii-proxy-server.py && echo "OK"
```

Expected: `OK`

- [ ] **Step 7: Commit**

```bash
git add .nvm-isolated/.claude-isolated/pii-proxy-server.py tests/test_pii_meta_endpoint.py
git commit -m "feat(pii-proxy): add GET /api/meta endpoint

Exposes startup profile (session_id, pwd, upstream_url,
masking_level, log_level, started_at) so attaching sessions
can display the shared proxy configuration."
```

---

## Task 3: Update bash attach path to display meta

**Files:**
- Modify: `lib/launcher/launch.sh` (attach branch, ~line 971-974 and ~line 1030-1058)

- [ ] **Step 1: Locate the attach branch**

Open `lib/launcher/launch.sh`. Find the flock subshell block. The attach branch writes:

```bash
# Attach to existing shared proxy
_register_pii_consumer
echo "attach:${_sport}" > "$_shared_result"
```

- [ ] **Step 2: Replace attach branch to query `/api/meta`**

Replace those two lines with:

```bash
# Attach to existing shared proxy
_register_pii_consumer
# Query startup profile from running proxy
_attach_meta_json=$(curl -sf --max-time 2 "http://127.0.0.1/${_sport}/api/meta" 2>/dev/null || true)
_attach_meta_suffix=""
if [[ -n "$_attach_meta_json" ]]; then
    _attach_meta_suffix=$(python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(\"[{}] → {} | log: {} | started by: {} from {}\".format(
    d.get('masking_level','?'),
    d.get('upstream_url','?'),
    d.get('log_level','?'),
    d.get('session_id','?'),
    d.get('pwd','?'),
))
" <<< "$_attach_meta_json" 2>/dev/null || true)
fi
echo "attach:${_sport}:${_attach_meta_suffix}" > "$_shared_result"
```

Note: the flock subshell does not have `$python_bin` in scope — it uses the system `python3`. The venv is only needed for Presidio; plain `json` parsing uses stdlib.

- [ ] **Step 3: Update result parsing outside flock subshell**

Find the block that parses `_result` (around line 1030-1038):

```bash
_mode="${_result%%:*}"
_port="${_result#*:}"
```

Replace with:

```bash
_mode="${_result%%:*}"
_rest="${_result#*:}"
_port="${_rest%%:*}"
_meta_suffix="${_rest#*:}"
# _meta_suffix is empty string when result was "attach:PORT:" or start path
```

- [ ] **Step 4: Update `print_info` for attach**

Find (around line 1055-1056):

```bash
if [[ "$_mode" == "attach" ]]; then
    print_info "PII proxy: attached to shared proxy on :$PII_PROXY_ACTIVE_PORT"
```

Replace with:

```bash
if [[ "$_mode" == "attach" ]]; then
    print_info "PII proxy: attached to shared proxy on :$PII_PROXY_ACTIVE_PORT${_meta_suffix:+ $_meta_suffix}"
```

`${_meta_suffix:+ $_meta_suffix}` appends ` <suffix>` when non-empty, nothing when empty — graceful degradation.

- [ ] **Step 5: Verify `start` path still works (port parsing)**

The `start` path writes `start:${_port}` (no third segment). After the new parsing:
- `_mode` = `start`
- `_rest` = `${_port}`
- `_port` = `${_port}` (no colon → `_rest%%:*` == `_rest`)
- `_meta_suffix` = `${_port}` minus `${_port}` prefix = empty string

Confirm by reading: `_rest#*:` where `_rest` has no colon returns empty string in bash. Test:

```bash
_result="start:38593"
_mode="${_result%%:*}"
_rest="${_result#*:}"
_port="${_rest%%:*}"
_meta_suffix="${_rest#*:}"
echo "mode=$_mode port=$_port suffix='$_meta_suffix'"
```

Expected: `mode=start port=38593 suffix=''`

- [ ] **Step 6: Verify bash syntax**

```bash
bash -n lib/launcher/launch.sh && echo "OK"
```

Expected: `OK`

- [ ] **Step 7: Commit**

```bash
git add lib/launcher/launch.sh
git commit -m "feat(pii-proxy): show startup profile when attaching to shared proxy

Queries GET /api/meta from the running shared proxy and appends
masking level, upstream URL, log level, session ID, and PWD to
the attach log line. Degrades gracefully if curl or meta query fails."
```

---

## Task 4: Smoke test end-to-end

**Files:** none

- [ ] **Step 1: Run the full test suite to check for regressions**

```bash
python3 -m pytest tests/test_patterns_examples.py tests/test_pii_meta_endpoint.py -v
```

Expected: all pass.

- [ ] **Step 2: Verify attach message with a live shared proxy**

In one terminal, start iclaude with PII proxy:

```bash
./iclaude.sh --pii-proxy
```

Note the startup line — should show `started by:` form:
```
ℹ PII proxy: shared proxy started on :XXXXX → https://api.anthropic.com [standard]
```

In a second terminal (same project), start iclaude again:

```bash
./iclaude.sh --pii-proxy
```

Expected attach line:
```
ℹ PII proxy: attached to shared proxy on :XXXXX [standard] → https://api.anthropic.com | log: info | started by: shared from /home/user/project
```

- [ ] **Step 3: Verify graceful degradation**

Kill the shared proxy between starting the proxy and attaching (edge case). Confirm the attach path still falls back to the port-only message and does not crash:
```
ℹ PII proxy: attached to shared proxy on :XXXXX
```

This is guaranteed by `curl ... || true` + `_meta_suffix` guard in the `print_info` line.
