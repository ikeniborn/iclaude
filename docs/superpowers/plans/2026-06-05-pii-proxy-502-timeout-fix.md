# PII Proxy 502 Timeout & Retry Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop frequent `502 PII proxy upstream unavailable` by replacing the hardcoded 30s timeout with env-configurable split connect/read timeouts and a connect-only retry adapter, plus a mid-stream timeout guard.

**Architecture:** Single-file change in `lib/pii-proxy/server.py` (the deployed `.nvm-isolated/.claude-isolated/pii-proxy-server.py` is a symlink to it). Add module-level timeout constants parsed from env, mount a `urllib3` `Retry(connect=2, read=0)` adapter on the per-thread `requests.Session`, pass `(CONNECT_TIMEOUT, READ_TIMEOUT)` to every upstream call, and break gracefully on read timeout mid-SSE-stream.

**Tech Stack:** Python 3.12, `requests` / `urllib3`, `pytest`, stdlib `http.server`.

**Spec:** `docs/superpowers/specs/2026-06-05-pii-proxy-502-timeout-fix-design.md`

---

## File Structure

| File | Responsibility | Change |
|------|----------------|--------|
| `lib/pii-proxy/server.py` | Proxy server | timeout config, retry adapter, split timeout, stream guard, startup log, docstring |
| `tests/test_pii_timeout_retry.py` | Unit tests for the fix | Create |
| `docs/PII_MASKING.md` | User docs | Document two new env vars |

All tests import the server module the same way the existing suite does
(`tests/test_pii_meta_endpoint.py`): via `importlib.util.spec_from_file_location` from the
symlinked `../.nvm-isolated/.claude-isolated/pii-proxy-server.py`, after setting
`ANTHROPIC_UPSTREAM_URL=http://127.0.0.1:9999` and `PII_PROXY_LOG_DIR=/tmp/pii-proxy-test-logs`.

---

## Task 1: Timeout configuration helper + constants

**Files:**
- Modify: `lib/pii-proxy/server.py` (insert after `MASK_TOKEN`, near line 165)
- Test: `tests/test_pii_timeout_retry.py` (create)

- [ ] **Step 1: Write the failing test**

Create `tests/test_pii_timeout_retry.py`:

```python
"""Tests for split connect/read timeouts and connect-only retry in pii-proxy-server.py."""
import io
import os
import importlib.util

import pytest

# Supply valid env vars before importing the server module.
# Use localhost URL — real upstream URLs can trigger the project's redact-secrets hook.
os.environ['ANTHROPIC_UPSTREAM_URL'] = 'http://127.0.0.1:9999'
os.environ['PII_PROXY_LOG_DIR'] = '/tmp/pii-proxy-test-logs'

_spec = importlib.util.spec_from_file_location(
    'pii_proxy_server',
    os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        '../.nvm-isolated/.claude-isolated/pii-proxy-server.py',
    ),
)
pii = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pii)


class TestTimeoutEnv:
    def test_default_when_unset(self):
        assert pii._timeout_env('PII_PROXY_NOPE_X', 10.0) == 10.0

    def test_override_from_env(self):
        os.environ['PII_PROXY_TEST_TO'] = '42'
        try:
            assert pii._timeout_env('PII_PROXY_TEST_TO', 10.0) == 42.0
        finally:
            del os.environ['PII_PROXY_TEST_TO']

    def test_invalid_falls_back(self):
        os.environ['PII_PROXY_TEST_TO'] = 'abc'
        try:
            assert pii._timeout_env('PII_PROXY_TEST_TO', 7.0) == 7.0
        finally:
            del os.environ['PII_PROXY_TEST_TO']

    def test_non_positive_falls_back(self):
        os.environ['PII_PROXY_TEST_TO'] = '0'
        try:
            assert pii._timeout_env('PII_PROXY_TEST_TO', 5.0) == 5.0
        finally:
            del os.environ['PII_PROXY_TEST_TO']

    def test_default_constants(self):
        assert pii.CONNECT_TIMEOUT == 10.0
        assert pii.READ_TIMEOUT == 300.0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/ikeniborn/Documents/Project/iclaude && python3 -m pytest tests/test_pii_timeout_retry.py::TestTimeoutEnv -v`
Expected: FAIL — `AttributeError: module 'pii_proxy_server' has no attribute '_timeout_env'`

- [ ] **Step 3: Write minimal implementation**

In `lib/pii-proxy/server.py`, after the `MASK_TOKEN` line (~165), add:

```python
# ---------------------------------------------------------------------------
# Upstream timeouts (split connect/read; env-configurable).
# A single 30s scalar previously tripped ReadTimeout on slow time-to-first-byte
# (Opus + extended thinking + large prompts) → 502. The Anthropic SDK uses ~600s
# read for /v1/messages; 300s is a safe default that still fails fast on a dead host.
# ---------------------------------------------------------------------------
def _timeout_env(name: str, default: float) -> float:
    """Parse a positive-float timeout from env; fall back to default on missing/invalid."""
    try:
        v = float(os.environ.get(name, ''))
        return v if v > 0 else default
    except (ValueError, TypeError):
        return default


CONNECT_TIMEOUT: float = _timeout_env('PII_PROXY_CONNECT_TIMEOUT', 10.0)
READ_TIMEOUT: float = _timeout_env('PII_PROXY_READ_TIMEOUT', 300.0)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/ikeniborn/Documents/Project/iclaude && python3 -m pytest tests/test_pii_timeout_retry.py::TestTimeoutEnv -v`
Expected: PASS (5 passed)

- [ ] **Step 5: Commit**

```bash
cd /home/ikeniborn/Documents/Project/iclaude
git add lib/pii-proxy/server.py tests/test_pii_timeout_retry.py
git commit -m "feat(pii-proxy): add env-configurable split connect/read timeouts

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Connect-only retry adapter on the session

**Files:**
- Modify: `lib/pii-proxy/server.py` — imports (~line 45) and `_get_http_session` (~line 197)
- Test: `tests/test_pii_timeout_retry.py`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_pii_timeout_retry.py`:

```python
class TestRetryAdapter:
    def test_session_has_connect_only_retry(self):
        s = pii._get_http_session()
        adapter = s.get_adapter('https://api.anthropic.com')
        retries = adapter.max_retries
        assert retries.connect == 2
        assert retries.read == 0
        assert retries.status == 0

    def test_both_schemes_mounted(self):
        s = pii._get_http_session()
        https = s.get_adapter('https://x')
        http = s.get_adapter('http://x')
        assert https.max_retries.connect == 2
        assert http.max_retries.connect == 2
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/ikeniborn/Documents/Project/iclaude && python3 -m pytest tests/test_pii_timeout_retry.py::TestRetryAdapter -v`
Expected: FAIL — default adapter `max_retries` is `Retry(total=0)` so `.connect` is `0`, assertion fails.

- [ ] **Step 3: Write minimal implementation**

In `lib/pii-proxy/server.py`, extend the requests import block (~line 45):

```python
import requests as _requests
from requests.adapters import HTTPAdapter
from requests.exceptions import ConnectionError as _ReqConnError, Timeout as _ReqTimeout
from urllib3.util.retry import Retry
```

Add a module-level retry policy near the session helper (~line 195, just before `_thread_local`):

```python
# Connect-only retry: retries connection ESTABLISHMENT (no bytes sent yet) — safe for
# the non-idempotent POST /v1/messages. read=0/status=0 → never retry after a partial
# response, so no duplicate generation or double billing.
_RETRY = Retry(
    total=None,
    connect=2,
    read=0,
    status=0,
    redirect=0,
    backoff_factor=0.5,
    raise_on_status=False,
)
```

Replace `_get_http_session` (~line 197):

```python
def _get_http_session() -> _requests.Session:
    """Return this thread's requests.Session, creating it on first access."""
    if not hasattr(_thread_local, 'session'):
        s = _requests.Session()
        s.trust_env = True  # respect HTTPS_PROXY / HTTP_PROXY env vars
        adapter = HTTPAdapter(max_retries=_RETRY)
        s.mount('http://', adapter)
        s.mount('https://', adapter)
        _thread_local.session = s
    return _thread_local.session
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/ikeniborn/Documents/Project/iclaude && python3 -m pytest tests/test_pii_timeout_retry.py::TestRetryAdapter -v`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
cd /home/ikeniborn/Documents/Project/iclaude
git add lib/pii-proxy/server.py tests/test_pii_timeout_retry.py
git commit -m "feat(pii-proxy): mount connect-only retry adapter on session

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Apply split timeout to upstream calls

**Files:**
- Modify: `lib/pii-proxy/server.py` — `_forward` (~line 941), `_proxy_head` (~line 904)
- Test: `tests/test_pii_timeout_retry.py`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_pii_timeout_retry.py`. The fakes below are also reused by Task 4.

```python
class _FakeResp:
    """Minimal stand-in for a requests streaming Response context manager."""
    def __init__(self, status=200, headers=None, content=b'', chunks=None, raise_iter=None):
        self.status_code = status
        self.headers = headers or {'Content-Type': 'application/json'}
        self._content = content
        self._chunks = chunks or []
        self._raise_iter = raise_iter

    @property
    def content(self):
        return self._content

    def iter_content(self, chunk_size=4096):
        for c in self._chunks:
            yield c
        if self._raise_iter:
            raise self._raise_iter

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


class _FakeSession:
    def __init__(self, resp):
        self.resp = resp
        self.calls = []

    def request(self, **kw):
        self.calls.append(kw)
        return self.resp


def _make_forward_handler(command='POST', path='/v1/messages'):
    """A PIIProxyHandler wired for _forward without a real socket."""
    h = pii.PIIProxyHandler.__new__(pii.PIIProxyHandler)
    h.path = path
    h.command = command
    h.headers = {}
    h.wfile = io.BytesIO()
    h._codes = []
    h.send_response = lambda code, msg=None: h._codes.append(code)
    h.send_header = lambda k, v: None
    h.end_headers = lambda: None
    return h


class TestSplitTimeout:
    def test_forward_passes_timeout_tuple(self, monkeypatch):
        resp = _FakeResp(status=200, headers={'Content-Type': 'application/json'}, content=b'{}')
        sess = _FakeSession(resp)
        monkeypatch.setattr(pii, '_get_http_session', lambda: sess)
        h = _make_forward_handler()
        h._forward(b'{}')
        assert sess.calls[0]['timeout'] == (pii.CONNECT_TIMEOUT, pii.READ_TIMEOUT)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/ikeniborn/Documents/Project/iclaude && python3 -m pytest tests/test_pii_timeout_retry.py::TestSplitTimeout -v`
Expected: FAIL — captured `timeout` is `30`, not the tuple.

- [ ] **Step 3: Write minimal implementation**

In `_forward` (`lib/pii-proxy/server.py` ~line 941), change:

```python
                timeout=30,
```

to:

```python
                timeout=(CONNECT_TIMEOUT, READ_TIMEOUT),
```

In `_proxy_head` (~line 904), change:

```python
                timeout=30,
```

to:

```python
                timeout=(CONNECT_TIMEOUT, READ_TIMEOUT),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/ikeniborn/Documents/Project/iclaude && python3 -m pytest tests/test_pii_timeout_retry.py::TestSplitTimeout -v`
Expected: PASS (1 passed)

- [ ] **Step 5: Commit**

```bash
cd /home/ikeniborn/Documents/Project/iclaude
git add lib/pii-proxy/server.py tests/test_pii_timeout_retry.py
git commit -m "fix(pii-proxy): use split connect/read timeout on upstream calls

Replaces hardcoded timeout=30 in _forward and _proxy_head.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Mid-stream read-timeout guard

**Files:**
- Modify: `lib/pii-proxy/server.py` — SSE loop in `_forward` (~line 957-963)
- Test: `tests/test_pii_timeout_retry.py`

**Why:** In the streaming branch, `end_headers()` is already sent before `iter_content`. If a
read timeout fires mid-stream, the outer `except` would call `send_response(502)` over an
already-started 200 response, corrupting output. Break gracefully instead — the client keeps
the partial stream it already received.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_pii_timeout_retry.py` (reuses `_FakeResp`, `_FakeSession`,
`_make_forward_handler` from Task 3):

```python
class TestStreamGuard:
    def test_read_timeout_midstream_does_not_double_send(self, monkeypatch):
        resp = _FakeResp(
            status=200,
            headers={'Content-Type': 'text/event-stream'},
            chunks=[b'data: hello\n\n'],
            raise_iter=pii._ReqTimeout('read timed out'),
        )
        sess = _FakeSession(resp)
        monkeypatch.setattr(pii, '_get_http_session', lambda: sess)
        h = _make_forward_handler()
        # Must not raise; must not emit a 502 over the already-started 200.
        h._forward(b'{}')
        assert h._codes == [200]
        assert b'hello' in h.wfile.getvalue()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/ikeniborn/Documents/Project/iclaude && python3 -m pytest tests/test_pii_timeout_retry.py::TestStreamGuard -v`
Expected: FAIL — `_ReqTimeout` propagates from the loop to the outer `except`, which appends a
second code `502`, so `h._codes == [200, 502]` (assertion fails).

- [ ] **Step 3: Write minimal implementation**

In `lib/pii-proxy/server.py`, the SSE loop (~line 957) currently reads:

```python
                    for chunk in resp.iter_content(chunk_size=4096):
                        if chunk:
                            try:
                                self.wfile.write(chunk)
                                self.wfile.flush()
                            except (BrokenPipeError, ConnectionResetError):
                                break  # client disconnected mid-stream
```

Wrap the iteration so a mid-stream read timeout ends the stream cleanly instead of
propagating to the 502 handler:

```python
                    try:
                        for chunk in resp.iter_content(chunk_size=4096):
                            if chunk:
                                try:
                                    self.wfile.write(chunk)
                                    self.wfile.flush()
                                except (BrokenPipeError, ConnectionResetError):
                                    break  # client disconnected mid-stream
                    except _ReqTimeout:
                        # Read timeout AFTER the 200 + headers were sent: we cannot
                        # switch to 502 now. End the stream; client keeps partial output.
                        log.warning('Read timeout mid-stream; ending partial response')
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/ikeniborn/Documents/Project/iclaude && python3 -m pytest tests/test_pii_timeout_retry.py::TestStreamGuard -v`
Expected: PASS (1 passed)

- [ ] **Step 5: Commit**

```bash
cd /home/ikeniborn/Documents/Project/iclaude
git add lib/pii-proxy/server.py tests/test_pii_timeout_retry.py
git commit -m "fix(pii-proxy): guard mid-stream read timeout from corrupting SSE response

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: Observability — startup log + docstring + docs

**Files:**
- Modify: `lib/pii-proxy/server.py` — startup log (~line 1067), module docstring env section (~line 12)
- Modify: `docs/PII_MASKING.md`

- [ ] **Step 1: Update the startup log line**

In `main()` (~line 1067), change:

```python
    log.info('PII-proxy listening on 127.0.0.1:%d -> %s (masking_level=%s)', port, UPSTREAM_URL, MASKING_LEVEL)
```

to:

```python
    log.info(
        'PII-proxy listening on 127.0.0.1:%d -> %s (masking_level=%s, connect_timeout=%.0fs, read_timeout=%.0fs)',
        port, UPSTREAM_URL, MASKING_LEVEL, CONNECT_TIMEOUT, READ_TIMEOUT,
    )
```

- [ ] **Step 2: Document the env vars in the module docstring**

In the `Environment:` block of the docstring (~line 21, after `PII_PROXY_LOG_LEVEL`), add:

```python
    PII_PROXY_CONNECT_TIMEOUT - upstream TCP connect timeout, seconds (default: 10)
    PII_PROXY_READ_TIMEOUT    - upstream read timeout, seconds (default: 300; raise for
                                long extended-thinking responses)
```

- [ ] **Step 3: Document in docs/PII_MASKING.md**

Add a row/entry for each new env var to the configuration/environment section of
`docs/PII_MASKING.md` (match the existing table or list format in that file):

```markdown
| `PII_PROXY_CONNECT_TIMEOUT` | Upstream TCP connect timeout (seconds) | `10` |
| `PII_PROXY_READ_TIMEOUT`    | Upstream read timeout (seconds); raise for long extended-thinking responses | `300` |
```

- [ ] **Step 4: Verify the module still imports and full suite passes**

Run:
```bash
cd /home/ikeniborn/Documents/Project/iclaude
python3 -m py_compile lib/pii-proxy/server.py
python3 -m pytest tests/test_pii_timeout_retry.py tests/test_pii_meta_endpoint.py tests/test_patterns_examples.py -v
```
Expected: compile clean; all tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /home/ikeniborn/Documents/Project/iclaude
git add lib/pii-proxy/server.py docs/PII_MASKING.md
git commit -m "docs(pii-proxy): surface timeout config in startup log + docs

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Final verification

- [ ] Full suite green: `python3 -m pytest tests/test_pii_timeout_retry.py tests/test_pii_meta_endpoint.py tests/test_patterns_examples.py -v`
- [ ] `python3 -m py_compile lib/pii-proxy/server.py`
- [ ] Manual smoke (optional): `PII_PROXY_READ_TIMEOUT=1 PII_PROXY_CONNECT_TIMEOUT=1` against a slow/unreachable upstream — confirm connect retried twice, read NOT retried.
- [ ] Run `update-docs` per CLAUDE.md maintenance rule (non-trivial change to a `lib/` module).
