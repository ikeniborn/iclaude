---
review:
  plan_hash: 692e951ceecc1011
  spec_hash: c2466758ed7d2e86
  last_run: 2026-06-21
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - id: F-001
      phase: coverage
      severity: WARNING
      section: "Task 1: Emitter — parse request & response"
      section_hash: 455244d4efc69390
      text: >-
        Spec R2b (§4) requires "thinking deltas (thinking_delta) captured
        separately into metadata, not the main output." The plan's _parse_sse
        (Task 1 Step 3) handles only delta.type == "text_delta" and silently
        drops content_block_delta events of type thinking_delta — they are
        neither in output nor in any metadata field. R2b's thinking-capture
        clause is therefore uncovered. Either add a thinking_delta branch that
        accumulates into resp["thinking"]/metadata, or amend the spec to drop
        the clause.
      verdict: fixed
    - id: F-002
      phase: verifiability
      severity: WARNING
      section: "Task 5: Launcher activation"
      section_hash: 0e030c63166b71f3
      text: >-
        Task 5 Step 3b adds `export PII_PROXY_MASKING_LEVEL=off` for capture-only
        sessions (R6: "capture-only MASKING_LEVEL=off"), but no automated check
        asserts it. The bash unit test (Step 4) only exercises _should_start_proxy
        and _init_project_id; the e2e (Task 4) sets PII_PROXY_MASKING_LEVEL=off
        directly in the subprocess env, bypassing the launcher default entirely.
        The capture-only masking-default branch has no DoD verification command.
        Add an assertion (e.g. extend the bash unit test to source the guard or a
        grep-based check) or note it as manually verified.
      verdict: fixed
    - id: F-003
      phase: consistency
      severity: WARNING
      section: "Task 4: Wire the emitter into the PII proxy"
      section_hash: 37ff64c8dc9f0f8a
      text: >-
        Task 4 Step 3b instructs placing the capture call "at the very end of the
        with ... block ... outside the with". In the live _forward (lines
        1009-1076) the `with` is nested inside a `try` whose only handlers are two
        `except` clauses that emit a 502. Placing the `if _do_capture` block
        between the with body and the except (try-body level) is syntactically
        valid, but any exception it raised would be caught by `except Exception`
        and attempt send_response(502) on an already-completed client response.
        capture() is non-raising by design (daemon thread, returns immediately),
        so this is theoretical — but the prose "outside the with" is ambiguous
        about indentation level. Clarify that the block sits at the try-body
        indentation (8 spaces) before the `except`, and rely on capture()'s
        no-raise contract.
      verdict: fixed
result_check:
  verdict: OK
  plan_hash: 692e951ceecc1011
  last_run: 2026-06-21
chain:
  intent: null
  spec: docs/superpowers/specs/2026-06-21-langfuse-nonrouter-capture-design.md
---

# Langfuse Non-Router Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In the non-router path, capture each Claude Code `/v1/messages` call (full prompt + completion) and emit it to self-hosted Langfuse as a `project:<repo>`-tagged trace, with both request and completion always secrets-scrubbed.

**Architecture:** A new Python module `langfuse_emitter.py` (a "Langfuse observer") is invoked from the existing PII-proxy MITM (`pii-proxy-server.py`) after each `/v1/messages` response is relayed. The proxy tees the response bytes, then a daemon thread parses request+response, secrets-scrubs both copies, and POSTs a `trace-create`+`generation-create` batch to Langfuse `/api/public/ingestion`. The launcher starts the proxy whenever capture OR masking is requested, and reuses `ICLAUDE_PROJECT_ID` for the project tag.

**Tech Stack:** Python 3 stdlib (`http.server`, `json`, `uuid`, `datetime`, `threading`) + the `requests` library already vendored in the PII-proxy venv (no new dependency). Bash launcher (`lib/launcher/launch.sh`). Tests in pytest (matching `tests/test_pii_*.py`).

---

## Background — verified facts (do not re-investigate)

Verified against the installed tree:

- **PII proxy** = `.nvm-isolated/.claude-isolated/pii-proxy-server.py` (`PIIProxyHandler`, 1250 lines). It is an HTTP MITM: claude → `ANTHROPIC_BASE_URL=http://127.0.0.1:PORT` (plaintext) → proxy → TLS → upstream.
- **Request path:** `_proxy_messages()` (line 928) reads the body, masks it if `MASKING_LEVEL != 'off'`, and calls `self._forward(out_body)` (`out_body` = masked-or-raw bytes actually sent upstream).
- **`_forward(body)`** (line 998) sends with `stream=True`. SSE responses (`text/event-stream`) are streamed chunk-by-chunk via `resp.iter_content(4096)` straight to the client (lines 1036-1042, **no buffering**). Non-SSE responses are buffered as `resp.content` (line 1051).
- **`regex_mask(text) -> tuple[str, list[str]]`** (line 425) applies the secrets `REDACT_PATTERNS` (`sk-…`, `Bearer …`, `ghp_`/`github_pat_`, `AKIA…`, JWT, `scheme://creds@host`, env-var lines, PEM). `regex_mask(t)[0]` is the masked string. This is the scrub the emitter reuses (injected by the proxy).
- **Proxy config is read from env at startup** (module level, lines 68-231): e.g. `PII_PROXY_MASKING_LEVEL` (default `standard`), `ICLAUDE_SESSION_ID`. The proxy is forked from the launcher shell (`setsid "$python_bin" "$PII_PROXY_SERVER_SCRIPT" … &`, line 1122), so exported launcher env (incl. `.claude_config` values like `LANGFUSE_*`) is inherited.
- **`ICLAUDE_SESSION_ID`** is validated to 12-hex / `shared` / else `default` (line 1124) — use the same rule for the Langfuse `sessionId`.
- **`_init_project_id()`** in `lib/launcher/launch.sh` (line 87) currently exports `ICLAUDE_PROJECT_ID` only in router mode; it is called as `_init_project_id "$use_router"` (line 119). `_derive_project_id()` (line 60) produces the tag-safe slug.
- **PII proxy activation** is gated on `USE_PII_PROXY_FLAG` (launch.sh line 157). `.claude_config` is sourced into the launcher shell, so a new `USE_LANGFUSE_CAPTURE` env is directly readable there.

---

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `.nvm-isolated/.claude-isolated/langfuse_emitter.py` | The Langfuse observer: parse Anthropic request + response (SSE/JSON), secrets-scrub both copies, build the `/api/public/ingestion` batch, POST it fail-soft in a daemon thread. Pure, dependency-injected (`scrub`), unit-testable. | Create |
| `.nvm-isolated/.claude-isolated/pii-proxy-server.py` | Read Langfuse config at startup; tee response bytes in `_forward`; call `langfuse_emitter.capture(...)` after relaying a `/v1/messages` response when capture is enabled. | Modify |
| `lib/launcher/launch.sh` | Detect `USE_LANGFUSE_CAPTURE`; start the proxy when capture OR pii-proxy is requested (capture-only → `MASKING_LEVEL=off`); skip in router mode; widen `_init_project_id` activation to `use_router || use_langfuse_capture`. | Modify |
| `tests/test_langfuse_emitter.py` | pytest unit tests for the emitter (parsing, scrub-both, payload shape, fail-soft). | Create |
| `tests/test_langfuse_capture_e2e.py` | pytest skip-aware e2e: real proxy subprocess + mock upstream (SSE) + mock Langfuse; assert forwarded trace/generation + scrubbing + fail-soft. | Create |
| `.claude_config.example` | Document `USE_LANGFUSE_CAPTURE` + `LANGFUSE_HOST`/`LANGFUSE_PUBLIC_KEY`/`LANGFUSE_SECRET_KEY`. | Modify |
| `docs/wiki/` (via iwiki-ingest) | New/updated wiki page for the capture feature. | Regenerate |

The emitter is a standalone module (not folded into the 1250-line proxy) so it can be unit-tested in isolation and the proxy file stays focused. The proxy↔emitter interface is a single function `capture(...)` plus injected `scrub`.

---

## Task 1: Emitter — parse request & response

**Files:**
- Create: `.nvm-isolated/.claude-isolated/langfuse_emitter.py`
- Test: `tests/test_langfuse_emitter.py`

- [ ] **Step 1: Write the failing test**

Create `tests/test_langfuse_emitter.py`:

```python
import sys
from pathlib import Path

# Import the emitter from the isolated config dir.
EMITTER_DIR = Path(__file__).resolve().parents[1] / ".nvm-isolated" / ".claude-isolated"
sys.path.insert(0, str(EMITTER_DIR))

import langfuse_emitter as le  # noqa: E402


def test_parse_request_extracts_model_messages_system():
    raw = (
        b'{"model":"claude-sonnet-4-6","system":"be brief",'
        b'"messages":[{"role":"user","content":"hi"}],"max_tokens":16}'
    )
    req = le.parse_request(raw)
    assert req["model"] == "claude-sonnet-4-6"
    assert req["system"] == "be brief"
    assert req["messages"] == [{"role": "user", "content": "hi"}]


def test_parse_sse_response_extracts_text_usage_model_stop():
    sse = (
        b'event: message_start\n'
        b'data: {"type":"message_start","message":{"model":"claude-sonnet-4-6",'
        b'"usage":{"input_tokens":11,"cache_creation_input_tokens":2,"cache_read_input_tokens":3}}}\n\n'
        b'event: content_block_delta\n'
        b'data: {"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"hmm "}}\n\n'
        b'event: content_block_delta\n'
        b'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hel"}}\n\n'
        b'event: content_block_delta\n'
        b'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"lo"}}\n\n'
        b'event: message_delta\n'
        b'data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":7}}\n\n'
    )
    resp = le.parse_response(sse, is_streaming=True)
    assert resp["output"] == "Hello"           # only text_delta → main output
    assert resp["thinking"] == "hmm "          # thinking_delta → captured separately
    assert resp["model"] == "claude-sonnet-4-6"
    assert resp["input_tokens"] == 11
    assert resp["output_tokens"] == 7
    assert resp["stop_reason"] == "end_turn"
    assert resp["cache_creation_input_tokens"] == 2
    assert resp["cache_read_input_tokens"] == 3
    assert resp["truncated"] is False


def test_parse_json_response_non_streaming():
    body = (
        b'{"model":"claude-sonnet-4-6","stop_reason":"end_turn",'
        b'"content":[{"type":"text","text":"Hi there"}],'
        b'"usage":{"input_tokens":5,"output_tokens":2}}'
    )
    resp = le.parse_response(body, is_streaming=False)
    assert resp["output"] == "Hi there"
    assert resp["model"] == "claude-sonnet-4-6"
    assert resp["input_tokens"] == 5
    assert resp["output_tokens"] == 2
    assert resp["stop_reason"] == "end_turn"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_langfuse_emitter.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'langfuse_emitter'` (file not created yet).

- [ ] **Step 3: Write the parsing implementation**

Create `.nvm-isolated/.claude-isolated/langfuse_emitter.py`:

```python
"""Langfuse observer for the PII proxy.

Parses Anthropic /v1/messages request + response, secrets-scrubs both copies,
and POSTs a trace-create + generation-create batch to Langfuse /api/public/ingestion.
Pure helpers (parse_request/parse_response/build_payload) are dependency-free;
emission (post_batch/capture) uses `requests` and runs fail-soft in a daemon thread.
"""
from __future__ import annotations

import json
import logging

log = logging.getLogger("pii-proxy.langfuse")

# Cap accumulated response bytes so a runaway stream can't exhaust memory.
MAX_CAPTURE_BYTES = 10_000_000


def parse_request(body: bytes) -> dict:
    """Extract model / system / messages / sampling from an Anthropic request body."""
    try:
        d = json.loads(body)
    except (json.JSONDecodeError, ValueError, TypeError):
        return {"model": None, "system": None, "messages": []}
    return {
        "model": d.get("model"),
        "system": d.get("system"),
        "messages": d.get("messages", []),
        "max_tokens": d.get("max_tokens"),
    }


def _parse_sse(raw: bytes) -> dict:
    text_parts: list[str] = []
    thinking_parts: list[str] = []
    model = None
    input_tokens = output_tokens = 0
    cache_creation = cache_read = 0
    stop_reason = None
    for line in raw.split(b"\n"):
        if not line.startswith(b"data:"):
            continue
        payload = line[len(b"data:"):].strip()
        if not payload or payload == b"[DONE]":
            continue
        try:
            evt = json.loads(payload)
        except (json.JSONDecodeError, ValueError):
            continue
        etype = evt.get("type")
        if etype == "message_start":
            msg = evt.get("message", {})
            model = msg.get("model", model)
            usage = msg.get("usage", {})
            input_tokens = usage.get("input_tokens", input_tokens)
            cache_creation = usage.get("cache_creation_input_tokens", cache_creation)
            cache_read = usage.get("cache_read_input_tokens", cache_read)
        elif etype == "content_block_delta":
            delta = evt.get("delta", {})
            if delta.get("type") == "text_delta":
                text_parts.append(delta.get("text", ""))
            elif delta.get("type") == "thinking_delta":
                thinking_parts.append(delta.get("thinking", ""))
        elif etype == "message_delta":
            output_tokens = evt.get("usage", {}).get("output_tokens", output_tokens)
            stop_reason = evt.get("delta", {}).get("stop_reason", stop_reason)
    return {
        "output": "".join(text_parts),
        "thinking": "".join(thinking_parts),
        "model": model,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cache_creation_input_tokens": cache_creation,
        "cache_read_input_tokens": cache_read,
        "stop_reason": stop_reason,
    }


def _parse_json(raw: bytes) -> dict:
    try:
        d = json.loads(raw)
    except (json.JSONDecodeError, ValueError, TypeError):
        return {
            "output": "", "model": None, "input_tokens": 0, "output_tokens": 0,
            "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0, "stop_reason": None,
        }
    text = "".join(
        b.get("text", "") for b in d.get("content", []) if b.get("type") == "text"
    )
    thinking = "".join(
        b.get("thinking", "") for b in d.get("content", []) if b.get("type") == "thinking"
    )
    usage = d.get("usage", {})
    return {
        "output": text,
        "thinking": thinking,
        "model": d.get("model"),
        "input_tokens": usage.get("input_tokens", 0),
        "output_tokens": usage.get("output_tokens", 0),
        "cache_creation_input_tokens": usage.get("cache_creation_input_tokens", 0),
        "cache_read_input_tokens": usage.get("cache_read_input_tokens", 0),
        "stop_reason": d.get("stop_reason"),
    }


def parse_response(raw: bytes, is_streaming: bool) -> dict:
    """Parse an Anthropic response (SSE or JSON) into a flat dict. Marks `truncated`."""
    truncated = len(raw) > MAX_CAPTURE_BYTES
    if truncated:
        raw = raw[:MAX_CAPTURE_BYTES]
    parsed = _parse_sse(raw) if is_streaming else _parse_json(raw)
    parsed["truncated"] = truncated
    return parsed
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_langfuse_emitter.py -q`
Expected: PASS — 3 passed.

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/langfuse_emitter.py tests/test_langfuse_emitter.py
git commit -m "feat(langfuse): emitter request/response parsing (SSE + JSON)"
```

---

## Task 2: Emitter — scrub-both + payload build

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/langfuse_emitter.py`
- Test: `tests/test_langfuse_emitter.py`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_langfuse_emitter.py`:

```python
def _fake_scrub(text):
    # Stand-in for regex_mask(t)[0]: replace a fake secret marker.
    return text.replace("SECRET123", "[REDACTED]")


def test_build_payload_scrubs_both_input_and_output():
    req = {"model": "m", "system": "sys SECRET123",
           "messages": [{"role": "user", "content": "key=SECRET123"}], "max_tokens": 8}
    resp = {"output": "leaked SECRET123 here", "thinking": "private SECRET123 note", "model": "m",
            "input_tokens": 4, "output_tokens": 6,
            "cache_creation_input_tokens": 1, "cache_read_input_tokens": 2,
            "stop_reason": "end_turn", "truncated": False}
    meta = {"session_id": "abcdef012345", "project": "myrepo", "pwd": "/x",
            "upstream_masking_level": "off"}
    payload = le.build_payload(req, resp, meta, scrub=_fake_scrub,
                               start_iso="2026-06-21T00:00:00Z", end_iso="2026-06-21T00:00:01Z")
    blob = json.dumps(payload)
    assert "SECRET123" not in blob          # input + output + thinking all scrubbed
    assert "[REDACTED]" in blob

    batch = payload["batch"]
    assert [e["type"] for e in batch] == ["trace-create", "generation-create"]
    trace = batch[0]["body"]
    gen = batch[1]["body"]
    assert trace["sessionId"] == "abcdef012345"
    assert trace["tags"] == ["project:myrepo"]
    assert gen["traceId"] == trace["id"]
    assert gen["usage"] == {"input": 4, "output": 6, "total": 10}
    assert gen["metadata"]["stop_reason"] == "end_turn"
    assert gen["metadata"]["cache_creation_input_tokens"] == 1
    assert gen["metadata"]["thinking"] == "private [REDACTED] note"   # thinking scrubbed → metadata
    assert gen["model"] == "m"


def test_build_payload_handles_missing_session_and_project():
    req = {"model": "m", "system": None, "messages": [], "max_tokens": None}
    resp = {"output": "ok", "model": "m", "input_tokens": 1, "output_tokens": 1,
            "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0,
            "stop_reason": "end_turn", "truncated": False}
    meta = {"session_id": "default", "project": "unknown", "pwd": "/x",
            "upstream_masking_level": "standard"}
    payload = le.build_payload(req, resp, meta, scrub=lambda t: t,
                               start_iso="2026-06-21T00:00:00Z", end_iso="2026-06-21T00:00:01Z")
    assert payload["batch"][0]["body"]["tags"] == ["project:unknown"]
    assert payload["batch"][0]["body"]["sessionId"] == "default"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_langfuse_emitter.py -q -k build_payload`
Expected: FAIL — `AttributeError: module 'langfuse_emitter' has no attribute 'build_payload'`.

- [ ] **Step 3: Add `build_payload` + scrub helper**

Append to `.nvm-isolated/.claude-isolated/langfuse_emitter.py`:

```python
import uuid


def _scrub_messages(messages, scrub):
    """Secrets-scrub the string content of each message (preserve structure)."""
    out = []
    for m in messages:
        c = m.get("content")
        if isinstance(c, str):
            out.append({**m, "content": scrub(c)})
        elif isinstance(c, list):
            blocks = []
            for b in c:
                if isinstance(b, dict) and isinstance(b.get("text"), str):
                    blocks.append({**b, "text": scrub(b["text"])})
                else:
                    blocks.append(b)
            out.append({**m, "content": blocks})
        else:
            out.append(m)
    return out


def build_payload(req: dict, resp: dict, meta: dict, scrub, start_iso: str, end_iso: str) -> dict:
    """Build the Langfuse /api/public/ingestion batch (trace-create + generation-create).

    `scrub` is a callable str->str (the proxy passes regex_mask(t)[0]); it is applied to
    BOTH the request (system + messages) and the completion output — always, regardless of
    upstream masking — so Langfuse never stores credential patterns.
    """
    trace_id = str(uuid.uuid4())
    gen_id = str(uuid.uuid4())
    system = req.get("system")
    scrubbed_system = scrub(system) if isinstance(system, str) else system
    scrubbed_messages = _scrub_messages(req.get("messages", []), scrub)
    scrubbed_output = scrub(resp.get("output", "") or "")
    scrubbed_thinking = scrub(resp.get("thinking", "") or "")
    in_tok = resp.get("input_tokens", 0) or 0
    out_tok = resp.get("output_tokens", 0) or 0
    return {
        "batch": [
            {
                "id": str(uuid.uuid4()),
                "type": "trace-create",
                "timestamp": start_iso,
                "body": {
                    "id": trace_id,
                    "name": "claude-code",
                    "sessionId": meta.get("session_id", "default"),
                    "tags": [f"project:{meta.get('project', 'unknown')}"],
                    "metadata": {
                        "pwd": meta.get("pwd"),
                        "upstream_masking_level": meta.get("upstream_masking_level"),
                        "langfuse_scrubbed": True,
                    },
                },
            },
            {
                "id": str(uuid.uuid4()),
                "type": "generation-create",
                "timestamp": end_iso,
                "body": {
                    "id": gen_id,
                    "traceId": trace_id,
                    "name": "messages",
                    "model": resp.get("model") or req.get("model"),
                    "input": {"system": scrubbed_system, "messages": scrubbed_messages},
                    "output": scrubbed_output,
                    "usage": {"input": in_tok, "output": out_tok, "total": in_tok + out_tok},
                    "startTime": start_iso,
                    "endTime": end_iso,
                    "metadata": {
                        "stop_reason": resp.get("stop_reason"),
                        "thinking": scrubbed_thinking,
                        "cache_creation_input_tokens": resp.get("cache_creation_input_tokens", 0),
                        "cache_read_input_tokens": resp.get("cache_read_input_tokens", 0),
                        "truncated": resp.get("truncated", False),
                    },
                },
            },
        ]
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_langfuse_emitter.py -q`
Expected: PASS — 5 passed.

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/langfuse_emitter.py tests/test_langfuse_emitter.py
git commit -m "feat(langfuse): build ingestion batch + always-scrub request/completion"
```

---

## Task 3: Emitter — async POST + `capture()` entry, fail-soft

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/langfuse_emitter.py`
- Test: `tests/test_langfuse_emitter.py`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_langfuse_emitter.py`:

```python
def test_post_batch_sends_basic_auth_and_body(monkeypatch):
    captured = {}

    class _Resp:
        status_code = 207

        def __init__(self):
            self.text = "ok"

    def fake_post(url, data=None, headers=None, timeout=None):
        captured["url"] = url
        captured["headers"] = headers
        captured["data"] = data
        return _Resp()

    monkeypatch.setattr(le._requests, "post", fake_post)
    ok = le.post_batch({"batch": []}, host="https://lf.example",
                       public_key="pk", secret_key="sk")
    assert ok is True
    assert captured["url"] == "https://lf.example/api/public/ingestion"
    # base64("pk:sk") == "cGs6c2s="
    assert captured["headers"]["Authorization"] == "Basic cGs6c2s="
    assert captured["headers"]["Content-Type"] == "application/json"


def test_post_batch_failsoft_on_error(monkeypatch):
    def boom(*a, **k):
        raise RuntimeError("langfuse down")

    monkeypatch.setattr(le._requests, "post", boom)
    # Must NOT raise — returns False.
    assert le.post_batch({"batch": []}, host="https://lf.example",
                         public_key="pk", secret_key="sk") is False


def test_capture_is_nonblocking_and_swallows_errors(monkeypatch):
    def boom(*a, **k):
        raise RuntimeError("boom")

    monkeypatch.setattr(le._requests, "post", boom)
    req_bytes = b'{"model":"m","messages":[{"role":"user","content":"hi"}]}'
    resp_bytes = (b'event: message_delta\n'
                  b'data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},'
                  b'"usage":{"output_tokens":1}}\n\n')
    # Should return immediately and never raise even though POST raises in the thread.
    t = le.capture(req_bytes, resp_bytes, is_streaming=True,
                   meta={"session_id": "default", "project": "p", "pwd": "/x",
                         "upstream_masking_level": "off"},
                   scrub=lambda s: s,
                   config={"host": "https://lf.example", "public_key": "pk", "secret_key": "sk"})
    t.join(timeout=5)
    assert not t.is_alive()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_langfuse_emitter.py -q -k "post_batch or capture"`
Expected: FAIL — `AttributeError: module 'langfuse_emitter' has no attribute 'post_batch'` (and `_requests` not defined).

- [ ] **Step 3: Add `post_batch` + `capture`**

Append to `.nvm-isolated/.claude-isolated/langfuse_emitter.py`:

```python
import base64
import threading
from datetime import datetime, timezone

import requests as _requests

POST_TIMEOUT = (5, 5)  # (connect, read) seconds — bounded, no retry storm


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def post_batch(payload: dict, host: str, public_key: str, secret_key: str) -> bool:
    """POST the ingestion batch. Returns True on 2xx/207, False on any error. Never raises."""
    try:
        token = base64.b64encode(f"{public_key}:{secret_key}".encode()).decode()
        resp = _requests.post(
            host.rstrip("/") + "/api/public/ingestion",
            data=json.dumps(payload).encode(),
            headers={"Authorization": f"Basic {token}", "Content-Type": "application/json"},
            timeout=POST_TIMEOUT,
        )
        if 200 <= resp.status_code < 300:
            return True
        log.warning("Langfuse ingestion non-2xx: %s", resp.status_code)
        return False
    except Exception as exc:  # noqa: BLE001 — fail-soft by design
        log.warning("Langfuse ingestion failed: %s", exc)
        return False


def _emit(req_bytes, resp_bytes, is_streaming, meta, scrub, config, start_iso):
    try:
        req = parse_request(req_bytes)
        resp = parse_response(resp_bytes, is_streaming)
        payload = build_payload(req, resp, meta, scrub, start_iso, _now_iso())
        post_batch(payload, config["host"], config["public_key"], config["secret_key"])
    except Exception as exc:  # noqa: BLE001 — capture must never break the proxy
        log.warning("Langfuse capture error: %s", exc)


def capture(req_bytes, resp_bytes, is_streaming, meta, scrub, config) -> threading.Thread:
    """Spawn a daemon thread to parse, scrub, build and POST. Returns the thread (for tests).

    Non-blocking and fail-soft: any error is swallowed; the proxied request is never affected.
    """
    start_iso = _now_iso()
    t = threading.Thread(
        target=_emit,
        args=(req_bytes, resp_bytes, is_streaming, meta, scrub, config, start_iso),
        daemon=True,
    )
    t.start()
    return t
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_langfuse_emitter.py -q`
Expected: PASS — 8 passed.

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/langfuse_emitter.py tests/test_langfuse_emitter.py
git commit -m "feat(langfuse): async fail-soft post_batch + capture entry point"
```

---

## Task 4: Wire the emitter into the PII proxy

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/pii-proxy-server.py`
- Test: `tests/test_langfuse_capture_e2e.py`

- [ ] **Step 1: Write the failing e2e test**

Create `tests/test_langfuse_capture_e2e.py`:

```python
import json
import os
import socket
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
PROXY = ROOT / ".nvm-isolated" / ".claude-isolated" / "pii-proxy-server.py"


def _free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


class _Upstream(BaseHTTPRequestHandler):
    """Mock Anthropic: returns a fixed SSE stream containing a secret in the completion."""
    def do_POST(self):
        self.rfile.read(int(self.headers.get("content-length", 0) or 0))
        sse = (
            b'event: message_start\n'
            b'data: {"type":"message_start","message":{"model":"claude-sonnet-4-6",'
            b'"usage":{"input_tokens":3}}}\n\n'
            b'event: content_block_delta\n'
            b'data: {"type":"content_block_delta","delta":{"type":"text_delta",'
            b'"text":"token sk-ant-SECRETLEAK done"}}\n\n'
            b'event: message_delta\n'
            b'data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},'
            b'"usage":{"output_tokens":5}}\n\n'
        )
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        self.wfile.write(sse)

    def log_message(self, *a):
        pass


class _Langfuse(BaseHTTPRequestHandler):
    received = []

    def do_POST(self):
        n = int(self.headers.get("content-length", 0) or 0)
        body = self.rfile.read(n)
        _Langfuse.received.append((self.headers.get("Authorization"), body))
        self.send_response(207)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"successes":[],"errors":[]}')

    def log_message(self, *a):
        pass


def _serve(handler):
    port = _free_port()
    srv = ThreadingHTTPServer(("127.0.0.1", port), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv, port


@pytest.mark.skipif(not PROXY.exists(), reason="pii-proxy-server.py missing")
def test_capture_forwards_scrubbed_trace_to_langfuse():
    _Langfuse.received.clear()
    up_srv, up_port = _serve(_Upstream)
    lf_srv, lf_port = _serve(_Langfuse)
    proxy_port = _free_port()

    env = dict(os.environ)
    env.update({
        "ANTHROPIC_UPSTREAM_URL": f"http://127.0.0.1:{up_port}",
        "PII_PROXY_PORT": str(proxy_port),
        "PII_PROXY_MASKING_LEVEL": "off",
        "PII_PROXY_SUPERVISE": "false",
        "PII_PROXY_LOG_DIR": "/tmp/lf-e2e-logs",
        "USE_LANGFUSE_CAPTURE": "true",
        "LANGFUSE_HOST": f"http://127.0.0.1:{lf_port}",
        "LANGFUSE_PUBLIC_KEY": "pk-test",
        "LANGFUSE_SECRET_KEY": "sk-test",
        "ICLAUDE_PROJECT_ID": "myrepo",
        "ICLAUDE_SESSION_ID": "abcdef012345",
    })
    proc = subprocess.Popen([sys.executable, str(PROXY)], env=env,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        # Wait for the proxy port to accept connections.
        for _ in range(50):
            try:
                socket.create_connection(("127.0.0.1", proxy_port), timeout=0.2).close()
                break
            except OSError:
                time.sleep(0.2)
        else:
            pytest.fail("proxy did not start")

        import urllib.request
        req = urllib.request.Request(
            f"http://127.0.0.1:{proxy_port}/v1/messages",
            data=b'{"model":"claude-sonnet-4-6","max_tokens":16,'
                 b'"messages":[{"role":"user","content":"hi"}]}',
            headers={"Content-Type": "application/json", "x-api-key": "test"},
        )
        resp_body = urllib.request.urlopen(req, timeout=10).read()
        # Client still receives the raw completion (capture never alters the client stream).
        assert b"sk-ant-SECRETLEAK" in resp_body

        # Langfuse should have received exactly one batch within a short window.
        for _ in range(25):
            if _Langfuse.received:
                break
            time.sleep(0.2)
        assert _Langfuse.received, "Langfuse received no ingestion POST"
        auth, body = _Langfuse.received[0]
        assert auth == "Basic " + __import__("base64").b64encode(b"pk-test:sk-test").decode()
        payload = json.loads(body)
        types = [e["type"] for e in payload["batch"]]
        assert types == ["trace-create", "generation-create"]
        assert payload["batch"][0]["body"]["tags"] == ["project:myrepo"]
        # The secret must be scrubbed out of the Langfuse copy of the completion.
        assert "sk-ant-SECRETLEAK" not in body.decode()
    finally:
        proc.terminate()
        proc.wait(timeout=5)
        up_srv.shutdown()
        lf_srv.shutdown()


@pytest.mark.skipif(not PROXY.exists(), reason="pii-proxy-server.py missing")
def test_capture_failsoft_when_langfuse_down():
    up_srv, up_port = _serve(_Upstream)
    proxy_port = _free_port()
    dead_port = _free_port()  # nothing listens here

    env = dict(os.environ)
    env.update({
        "ANTHROPIC_UPSTREAM_URL": f"http://127.0.0.1:{up_port}",
        "PII_PROXY_PORT": str(proxy_port),
        "PII_PROXY_MASKING_LEVEL": "off",
        "PII_PROXY_SUPERVISE": "false",
        "PII_PROXY_LOG_DIR": "/tmp/lf-e2e-logs",
        "USE_LANGFUSE_CAPTURE": "true",
        "LANGFUSE_HOST": f"http://127.0.0.1:{dead_port}",
        "LANGFUSE_PUBLIC_KEY": "pk-test",
        "LANGFUSE_SECRET_KEY": "sk-test",
        "ICLAUDE_PROJECT_ID": "myrepo",
        "ICLAUDE_SESSION_ID": "abcdef012345",
    })
    proc = subprocess.Popen([sys.executable, str(PROXY)], env=env,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(50):
            try:
                socket.create_connection(("127.0.0.1", proxy_port), timeout=0.2).close()
                break
            except OSError:
                time.sleep(0.2)
        else:
            pytest.fail("proxy did not start")
        import urllib.request
        req = urllib.request.Request(
            f"http://127.0.0.1:{proxy_port}/v1/messages",
            data=b'{"model":"claude-sonnet-4-6","max_tokens":16,'
                 b'"messages":[{"role":"user","content":"hi"}]}',
            headers={"Content-Type": "application/json"},
        )
        # Client request still succeeds even though Langfuse is unreachable.
        body = urllib.request.urlopen(req, timeout=10).read()
        assert b"SECRETLEAK" in body
    finally:
        proc.terminate()
        proc.wait(timeout=5)
        up_srv.shutdown()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_langfuse_capture_e2e.py -q`
Expected: FAIL — the proxy ignores `USE_LANGFUSE_CAPTURE`, so `_Langfuse.received` stays empty and `test_capture_forwards_scrubbed_trace_to_langfuse` fails on `assert _Langfuse.received`.

- [ ] **Step 3a: Add Langfuse config read at proxy startup**

In `.nvm-isolated/.claude-isolated/pii-proxy-server.py`, immediately after the existing config-reading block (just after the `_raw_log_level` line ~231), add:

```python
# --- Langfuse capture (observer) configuration --------------------------------
import langfuse_emitter as _langfuse  # sibling module in the same dir

_LANGFUSE_CAPTURE = os.environ.get('USE_LANGFUSE_CAPTURE', 'false').lower() == 'true'
_LANGFUSE_CONFIG = {
    'host': os.environ.get('LANGFUSE_HOST', ''),
    'public_key': os.environ.get('LANGFUSE_PUBLIC_KEY', ''),
    'secret_key': os.environ.get('LANGFUSE_SECRET_KEY', ''),
}
_LANGFUSE_PROJECT = os.environ.get('ICLAUDE_PROJECT_ID', 'unknown') or 'unknown'
# Disable capture (fail-soft) if enabled but mis-configured.
if _LANGFUSE_CAPTURE and not all(_LANGFUSE_CONFIG.values()):
    log.warning('Langfuse capture enabled but LANGFUSE_HOST/PUBLIC_KEY/SECRET_KEY incomplete — disabling')
    _LANGFUSE_CAPTURE = False
```

> NOTE: the proxy script's directory is already on `sys.path` (it is the script being executed), so `import langfuse_emitter` resolves to the sibling file. `log` is the module logger already defined in the proxy.

- [ ] **Step 3b: Tee the response and call capture in `_forward`**

Replace the body of `_forward` (lines ~998-1058, the `with _get_http_session()...` block) so it accumulates response bytes and, for `/v1/messages` with capture enabled, calls the emitter after relaying. Concretely, modify the streaming and buffered branches to collect bytes into `captured` and add a capture call before the method returns:

At the top of `_forward`, after `headers = self._build_upstream_headers()`, add:

```python
        _do_capture = _LANGFUSE_CAPTURE and '/v1/messages' in self.path and self.command == 'POST'
        captured = bytearray() if _do_capture else None
        _cap_streaming = False
```

In the **SSE branch**, inside `for chunk in resp.iter_content(...)`, after the existing `self.wfile.write(chunk)` / flush, tee the chunk:

```python
                        for chunk in resp.iter_content(chunk_size=4096):
                            if chunk:
                                if captured is not None and len(captured) < _langfuse.MAX_CAPTURE_BYTES:
                                    captured.extend(chunk)
                                try:
                                    self.wfile.write(chunk)
                                    self.wfile.flush()
                                except (BrokenPipeError, ConnectionResetError):
                                    break
```

and set `_cap_streaming = True` where `is_streaming` is detected:

```python
                is_streaming = 'text/event-stream' in resp.headers.get('Content-Type', '')
                _cap_streaming = is_streaming
```

In the **buffered branch**, after `content = resp.content`, tee it:

```python
                    content = resp.content
                    if captured is not None:
                        captured.extend(content[:_langfuse.MAX_CAPTURE_BYTES])
```

Finally, add the capture call **immediately after the `with _get_http_session()... as resp:` block closes** — at the `try`-body indentation level (8 spaces), so it sits between the end of the `with` block and the first `except` clause (the existing `except (_ReqConnError, _ReqTimeout)` at line ~1060). This runs only after the response was fully written to the client. It is safe at this indent because `capture()` is non-raising by contract (it spawns a daemon thread and returns immediately) — so it can never trigger the surrounding `except → 502` on an already-completed response:

```python
        if _do_capture and captured:
            _raw_sid = os.environ.get('ICLAUDE_SESSION_ID', '')
            _sid = _raw_sid if (re.fullmatch(r'[0-9a-f]{12}', _raw_sid) or _raw_sid == 'shared') else 'default'
            _meta = {
                'session_id': _sid,
                'project': _LANGFUSE_PROJECT,
                'pwd': os.getcwd(),
                'upstream_masking_level': MASKING_LEVEL,
            }
            _langfuse.capture(
                bytes(body), bytes(captured), _cap_streaming, _meta,
                scrub=lambda t: regex_mask(t)[0], config=_LANGFUSE_CONFIG,
            )
```

> The capture call is placed so a capture error cannot affect the already-completed client response. `regex_mask(t)[0]` is the secrets scrub (R2a). `body` is the post-PII request bytes passed into `_forward`.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_langfuse_capture_e2e.py -q`
Expected: PASS — 2 passed.

Also re-run the proxy's own suite to confirm no regression:
Run: `python3 -m pytest tests/test_patterns_examples.py -q`
Expected: PASS (unchanged).

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/pii-proxy-server.py tests/test_langfuse_capture_e2e.py
git commit -m "feat(langfuse): wire capture observer into PII proxy _forward (tee + emit)"
```

---

## Task 5: Launcher activation

**Files:**
- Modify: `lib/launcher/launch.sh`
- Test: `tests/test_langfuse_capture_launch_unit.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_langfuse_capture_launch_unit.sh`:

```bash
#!/usr/bin/env bash
# L1 — unit test for the Langfuse-capture launcher helper `_should_start_proxy`
# and the widened `_init_project_id` activation.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

_extract() {
    awk -v fn="$1" '
        $0 ~ "^"fn"\\(\\)" { in_fn=1 }
        in_fn { print }
        in_fn && /^}/ { in_fn=0 }
    ' "$ROOT/lib/launcher/launch.sh"
}
eval "$(_extract _derive_project_id)"
eval "$(_extract _init_project_id)"
eval "$(_extract _should_start_proxy)"
eval "$(_extract _proxy_masking_default)"

PASS=0; FAIL=0
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' want '$2'"; fi; }

# _should_start_proxy <use_pii_proxy> <use_langfuse_capture> -> rc 0 (start) / 1 (no)
_should_start_proxy "true"  "false"; assert_eq "$?" "0" "pii only → start"
_should_start_proxy "false" "true";  assert_eq "$?" "0" "capture only → start"
_should_start_proxy "true"  "true";  assert_eq "$?" "0" "both → start"
_should_start_proxy "false" "false"; assert_eq "$?" "1" "neither → no start"

# _proxy_masking_default <use_pii_proxy> <current_level> -> echoes level to force ('off') or empty
assert_eq "$(_proxy_masking_default "false" "")"        "off" "capture-only → default off"
assert_eq "$(_proxy_masking_default "true"  "")"        ""    "pii-proxy on → no forced level"
assert_eq "$(_proxy_masking_default "false" "secrets")" ""    "explicit level honored"

# _init_project_id widened: capture mode exports the id even when not routing.
EXP=$(_derive_project_id "$ROOT")
out=$( cd "$ROOT" && unset ICLAUDE_PROJECT_ID; _init_project_id "false" "true"; bash -c 'printf "%s" "${ICLAUDE_PROJECT_ID:-}"' )
assert_eq "$out" "$EXP" "init exports id in capture mode (router=false, capture=true)"
out=$( cd "$ROOT" && unset ICLAUDE_PROJECT_ID; _init_project_id "false" "false"; bash -c 'printf "%s" "${ICLAUDE_PROJECT_ID:-}"' )
assert_eq "$out" "" "init no-op when neither router nor capture"

echo "L1 langfuse-launch: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_langfuse_capture_launch_unit.sh`
Expected: FAIL — `_should_start_proxy` is not defined yet, and `_init_project_id` still takes one arg (capture-mode assertions fail).

- [ ] **Step 3a: Add `_should_start_proxy` and widen `_init_project_id`**

In `lib/launcher/launch.sh`, replace the current `_init_project_id` definition (lines ~74-93) with this widened version plus the new helper directly after it:

```bash
#######################################
# Export ICLAUDE_PROJECT_ID for the CCR process and/or the Langfuse capture observer.
# Runs in router mode OR Langfuse-capture mode. The id is the same tag-safe slug both
# the CCR x-project-id transformer and the PII-proxy Langfuse emitter use as project:<id>.
# An explicit value already in the environment is kept. MUST run before the proxy/CCR fork.
# Arguments:
#   $1 - use_router          ("true" activates)
#   $2 - use_langfuse_capture ("true" activates; optional, defaults to "false")
#######################################
_init_project_id() {
    local use_router="${1:-false}" use_capture="${2:-false}"
    [[ "$use_router" == "true" || "$use_capture" == "true" ]] || return 0
    if [[ -z "${ICLAUDE_PROJECT_ID:-}" ]]; then
        ICLAUDE_PROJECT_ID="$(_derive_project_id "$PWD")"
    fi
    export ICLAUDE_PROJECT_ID
}

#######################################
# Decide whether to start the PII proxy: it serves either masking, Langfuse capture, or both.
# Returns 0 (start) if either is requested, 1 otherwise.
# Arguments:
#   $1 - use_pii_proxy        ("true" if masking requested)
#   $2 - use_langfuse_capture ("true" if capture requested)
#######################################
_should_start_proxy() {
    [[ "${1:-false}" == "true" || "${2:-false}" == "true" ]]
}

#######################################
# Resolve the masking level to FORCE for capture-only sessions. When the proxy is started
# only for Langfuse capture (no --pii-proxy) and no explicit PII_PROXY_MASKING_LEVEL is set,
# the proxy runs purely as the auth + capture hop with masking 'off'. Otherwise echo nothing
# (leave PII_PROXY_MASKING_LEVEL untouched — the proxy applies its own 'standard' default).
# Arguments:
#   $1 - use_pii_proxy   ("true" if masking explicitly requested)
#   $2 - current PII_PROXY_MASKING_LEVEL value (may be empty)
# Outputs:
#   "off" to force, or empty string to leave untouched
#######################################
_proxy_masking_default() {
    if [[ "${1:-false}" != "true" && -z "${2:-}" ]]; then
        printf 'off'
    fi
}
```

- [ ] **Step 3b: Detect capture, widen the `_init_project_id` call, and gate proxy startup**

In `launch_claude()`:

1. Replace the call site `_init_project_id "$use_router"` (line ~119) with detection + the widened call. Insert just after the `use_router` block:

```bash
    # Langfuse non-router capture: a config-only toggle (.claude_config). Skipped in
    # router mode (LiteLLM already emits to Langfuse there — avoids double traces).
    local use_langfuse_capture=false
    if [[ "${USE_LANGFUSE_CAPTURE:-false}" == "true" ]] && [[ "$use_router" != "true" ]]; then
        use_langfuse_capture=true
    fi

    # Per-project attribution (router and/or capture): export ICLAUDE_PROJECT_ID before
    # any CCR or PII-proxy fork so both observers can tag traces project:<repo>.
    _init_project_id "$use_router" "$use_langfuse_capture"
```

2. In the PII-proxy activation block (currently `if [[ "${USE_PII_PROXY_FLAG:-false}" == "true" ]]; then`, line ~157), widen the condition so capture-only also starts the proxy, and force `MASKING_LEVEL=off` when only capture was requested. Change the guard to:

```bash
    local use_pii_proxy=false
    if _should_start_proxy "${USE_PII_PROXY_FLAG:-false}" "$use_langfuse_capture"; then
```

and inside that block, before the proxy is started, default the masking level for capture-only sessions:

```bash
        # Capture-only (masking not explicitly requested): run the proxy purely as the
        # auth + Langfuse-capture hop with masking 'off'. Uses the unit-tested helper.
        local _mdef
        _mdef=$(_proxy_masking_default "${USE_PII_PROXY_FLAG:-false}" "${PII_PROXY_MASKING_LEVEL:-}")
        [[ -n "$_mdef" ]] && export PII_PROXY_MASKING_LEVEL="$_mdef"
```

> The `LANGFUSE_*` and `USE_LANGFUSE_CAPTURE` vars come from `.claude_config` (already sourced into the launcher shell), so they are inherited by the forked proxy automatically; only `ICLAUDE_PROJECT_ID` needs the explicit export above.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_langfuse_capture_launch_unit.sh`
Expected: PASS — `L1 langfuse-launch: PASS=9 FAIL=0`.

Confirm nothing else regressed and syntax is clean:
Run: `bash tests/test_project_id_unit.sh && bash -n lib/launcher/launch.sh && echo OK`
Expected: `L1 project_id: PASS=8 FAIL=0` then `OK`.

> NOTE: `tests/test_project_id_unit.sh` calls `_init_project_id "true"` (one arg). The widened signature defaults `$2` to `false`, so the existing one-arg calls still behave identically (router mode exports). No change needed to that test.

- [ ] **Step 5: Commit**

```bash
git add lib/launcher/launch.sh tests/test_langfuse_capture_launch_unit.sh
git commit -m "feat(langfuse): launcher starts proxy for capture, widens _init_project_id"
```

---

## Task 6: Config example + docs

**Files:**
- Modify: `.claude_config.example`
- Regenerate: `docs/wiki/` (via iwiki)

- [ ] **Step 1: Locate the PII/proxy section of the example**

Run: `grep -n "USE_PII_PROXY\|PII_PROXY_MASKING\|^#.*PII\|^#.*Proxy" .claude_config.example`
Expected: prints the existing PII-proxy config block line numbers (the new keys go directly after it).

- [ ] **Step 2: Add the Langfuse capture block to `.claude_config.example`**

Immediately after the existing `USE_PII_PROXY` / `PII_PROXY_*` block in `.claude_config.example`, add:

```bash
# --- Langfuse non-router capture (optional) -----------------------------------
# Capture full prompt+completion of each LLM call (non-router path) into self-hosted
# Langfuse, tagged project:<repo>. Rides the PII proxy: enabling this starts the proxy
# even without USE_PII_PROXY (masking off unless PII_PROXY_MASKING_LEVEL is set).
# Both request and completion sent to Langfuse are ALWAYS secrets-scrubbed.
# Skipped automatically in --router mode (LiteLLM already emits to Langfuse there).
# export USE_LANGFUSE_CAPTURE=true
# export LANGFUSE_HOST="https://langfuse.example"
# export LANGFUSE_PUBLIC_KEY="pk-lf-..."
# export LANGFUSE_SECRET_KEY="sk-lf-..."   # secret — keep .claude_config at chmod 600
```

- [ ] **Step 3: Verify the example still parses as shell**

Run: `bash -n .claude_config.example && echo OK`
Expected: `OK` (commented lines are inert; no syntax error).

- [ ] **Step 4: Regenerate + lint the wiki**

Invoke the `iwiki:iwiki-ingest` skill with source `.nvm-isolated/.claude-isolated/langfuse_emitter.py` (and review the diff) to create/update a `docs/wiki/` page documenting the capture observer; then invoke `/iwiki-lint`.
Expected: ingest writes/updates a page (e.g. `docs/wiki/pii-proxy.md` gains a "Langfuse capture" section or a new `docs/wiki/langfuse-capture.md` is created); lint reports no broken `[[refs]]` introduced and no new orphans/stale pages from this change.

- [ ] **Step 5: Commit**

```bash
git add .claude_config.example docs/wiki/
git commit -m "docs(langfuse): document USE_LANGFUSE_CAPTURE config + capture wiki page"
```

---

## Self-Review

**1. Spec coverage**

| Spec requirement | Task |
|------------------|------|
| §3 architecture: observer on existing MITM | Task 4 (wiring), Task 5 (activation) |
| R1 request capture (post-PII `_forward(body)`) | Task 4 Step 3b (`body` teed/passed) |
| R2a always secrets-scrub both request + completion | Task 2 (`build_payload` + `_scrub_messages`), Task 4 (`scrub=lambda t: regex_mask(t)[0]`), unit + e2e assertions |
| R2b response capture (SSE tee + buffered) | Task 1 (`parse_response`), Task 4 Step 3b (tee both branches) |
| R3 REST ingestion, envelope, `usage.total=input+output`, trace+generation, UUID/ISO | Task 2 (`build_payload`), Task 3 (`post_batch`) |
| R4 async + fail-soft + buffer cap | Task 3 (`capture` daemon thread, `post_batch` swallow), `MAX_CAPTURE_BYTES`, e2e fail-soft test |
| R5 per-project tag via `ICLAUDE_PROJECT_ID`, widen `_init_project_id` | Task 5 (`_init_project_id` 2-arg), Task 4 (`_LANGFUSE_PROJECT`) |
| R6 config toggle + launcher activation + capture-only `MASKING_LEVEL=off` + router skip | Task 5, Task 6 (`.claude_config.example`) |
| R7 separate `langfuse_emitter.py` module | Tasks 1-3 |
| §5 testing (unit + skip-aware e2e + fail-soft) | Tasks 1-4 |

No spec requirement is left without a task.

**2. Placeholder scan:** No `TBD`/`add error handling`/"similar to Task N". Every code step shows full code; the `_forward` edit (Task 4 Step 3b) shows each changed fragment with its surrounding lines. Error handling is concrete (`post_batch`/`_emit` swallow with `log.warning`).

**3. Type/name consistency:** `parse_request`, `parse_response`, `build_payload`, `post_batch`, `capture`, `MAX_CAPTURE_BYTES`, `_requests` are used identically across Tasks 1-4. `capture(req_bytes, resp_bytes, is_streaming, meta, scrub, config)` signature matches between Task 3 (definition + tests) and Task 4 (call site). `meta` keys (`session_id`, `project`, `pwd`, `upstream_masking_level`) match between Task 2 (`build_payload`), Task 3 (test), and Task 4 (`_meta`). `_should_start_proxy`/`_init_project_id` 2-arg signatures match between Task 5 definition, its test, and the call sites. `usage` shape `{input, output, total}` is consistent (Task 2 build + test, e2e). `config` dict keys (`host`, `public_key`, `secret_key`) match between Task 3 and Task 4 `_LANGFUSE_CONFIG`.
