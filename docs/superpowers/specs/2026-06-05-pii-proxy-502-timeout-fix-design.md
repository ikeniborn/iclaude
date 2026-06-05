# PII Proxy 502 "upstream unavailable" — Timeout & Retry Fix

**Date:** 2026-06-05
**Status:** Design approved
**Component:** `lib/pii-proxy/server.py`

## Problem

Running Claude Code sessions frequently fail with:

```
API Error: 502 PII proxy upstream unavailable. This is a server-side issue,
usually temporary — try again in a moment. If it persists, check your
inference gateway (127.0.0.1:32826).
```

`127.0.0.1:32826` is the PII proxy listen port. The `502 PII proxy upstream unavailable`
body is emitted by `_forward()` in `server.py:975`. The "inference gateway" wrapper text
is Claude Code CLI's own rendering of any upstream 502.

## Root cause (from live logs)

`.nvm-isolated/.claude-isolated/pii-proxy-logs/shared.log` — ~40 occurrences on 2026-06-05:

```
ERROR Upstream connection error: HTTPSConnectionPool(host='api.anthropic.com',
      port=443): Read timed out. (read timeout=30)
```

Plus rare:

```
ERROR Proxy error: [Errno 104] Connection reset by peer
```

Upstream is direct `https://api.anthropic.com` (per startup log). Two flaws in `_forward()`:

1. **`timeout=30` hardcoded, single scalar** = both connect and read are 30s.
   Opus + extended thinking + large prompts push time-to-first-byte past 30s →
   `requests` raises `ReadTimeout` → caught at `server.py:970` → `502`. This is ~95%
   of failures. The official Anthropic SDK uses a ~600s read timeout for `/v1/messages`
   for exactly this reason; 30s is far too aggressive.

2. **Bare `requests.Session()`** (`_get_http_session`, `server.py:197`) — no retry
   adapter mounted. A single transient blip (e.g. `Errno 104` from a stale keep-alive
   connection the upstream already closed) becomes an immediate hard 502 with no retry.

A latent third bug compounds this: in the streaming (SSE) branch (`server.py:954`),
`end_headers()` is already called before `iter_content`. If a read timeout fires
mid-stream, the outer `except` tries to `send_response(502)` over an already-started
200 response → garbage/partial output. Only `BrokenPipeError`/`ConnectionResetError`
are currently handled inside the stream loop.

## Decisions (from brainstorming)

- **Fix location:** the PII proxy server itself; robust regardless of upstream type.
- **Retry strategy:** connect-only. POST `/v1/messages` is non-idempotent — retrying
  after bytes are sent risks duplicate generation/billing. Retry only connection
  establishment (before any bytes leave), never read timeouts or status.
- **Timeouts:** split connect/read, env-configurable. Defaults `connect=10s`,
  `read=300s`. Matches the configuration pattern of the rest of the proxy.

## Design

All changes in `lib/pii-proxy/server.py`. The deployed path
`.nvm-isolated/.claude-isolated/pii-proxy-server.py` is a **symlink** to that source
(verified) — no manual copy step, edits take effect automatically.

### 1. Timeout configuration (module level, near `server.py:155`)

```python
def _timeout_env(name, default):
    """Parse a positive-float timeout from env; fall back to default on missing/invalid."""
    try:
        v = float(os.environ.get(name, ''))
        return v if v > 0 else default
    except (ValueError, TypeError):
        return default

CONNECT_TIMEOUT = _timeout_env('PII_PROXY_CONNECT_TIMEOUT', 10.0)
READ_TIMEOUT    = _timeout_env('PII_PROXY_READ_TIMEOUT', 300.0)
```

### 2. Connect-only retry adapter (`_get_http_session`, `server.py:197`)

```python
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

_RETRY = Retry(
    total=None,
    connect=2,            # retry only connection establishment (no bytes sent yet)
    read=0,               # never retry read errors — POST /v1/messages is non-idempotent
    status=0,
    redirect=0,
    backoff_factor=0.5,
    raise_on_status=False,
)
```

Mounted per-thread session for both schemes:

```python
adapter = HTTPAdapter(max_retries=_RETRY)
s.mount('http://', adapter)
s.mount('https://', adapter)
```

Rationale: urllib3 retries `connect` failures independent of HTTP method, because no
request body has been transmitted — safe for POST. `read=0`/`status=0` guarantee no
retry after a partial response, eliminating double-billing risk.

### 3. Split timeout applied

Replace `timeout=30` with `timeout=(CONNECT_TIMEOUT, READ_TIMEOUT)` in both:

- `_forward()` — `server.py:941`
- `_proxy_head()` — `server.py:904`

### 4. Mid-stream timeout guard (SSE loop, `server.py:957`)

Add `_ReqTimeout` (and keep existing `BrokenPipeError`, `ConnectionResetError`) to the
in-loop `except`, breaking gracefully instead of propagating to the outer handler that
would corrupt an already-started 200 response. The client keeps whatever partial stream
it received.

### 5. Observability

- Extend the startup log line (`server.py:1067`) to include the effective timeouts.
- Document `PII_PROXY_CONNECT_TIMEOUT` / `PII_PROXY_READ_TIMEOUT` in the module docstring
  env section and `docs/PII_MASKING.md`.

### Out of scope

- Architecture / data flow — unchanged.
- Router/CCR combined mode — unaffected; the same `_forward` path serves it.
- Masking logic, auth header handling, port selection — untouched.

## Verification

- `python3 -m py_compile lib/pii-proxy/server.py`
- New unit test: env timeout parsing (default / override / invalid → default) and that
  the session adapter carries `Retry(connect=2, read=0)`.
- Regression: `python3 -m pytest tests/test_pii_meta_endpoint.py tests/test_patterns_examples.py -v`
- Manual smoke: start proxy with `PII_PROXY_READ_TIMEOUT=1` against a slow endpoint →
  confirm read timeout is NOT retried; with an unreachable host → confirm connect retried twice.

## Affected files

| File | Change |
|------|--------|
| `lib/pii-proxy/server.py` | timeout config, retry adapter, split timeout, stream guard, startup log |
| `tests/` | new timeout/retry unit test |
| `docs/PII_MASKING.md` | document new env vars |
