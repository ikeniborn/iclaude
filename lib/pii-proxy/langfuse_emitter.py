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
        if not isinstance(d, dict):
            raise ValueError
    except (json.JSONDecodeError, ValueError, TypeError):
        return {"model": None, "system": None, "messages": [], "max_tokens": None}
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
        if not isinstance(d, dict):
            raise ValueError
    except (json.JSONDecodeError, ValueError, TypeError):
        return {
            "output": "", "thinking": "", "model": None, "input_tokens": 0, "output_tokens": 0,
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


import uuid


def _deep_scrub(obj, scrub):
    """Recursively secrets-scrub every string *value* in a nested structure.

    Walks dicts/lists and applies `scrub` to each string; dict keys are left intact
    (they are structural). This guarantees credential patterns never reach Langfuse
    regardless of the Anthropic content shape — string content, text blocks,
    tool_use.input, nested tool_result.content, or system-as-list with cache_control.
    """
    if isinstance(obj, str):
        return scrub(obj)
    if isinstance(obj, list):
        return [_deep_scrub(x, scrub) for x in obj]
    if isinstance(obj, dict):
        return {k: _deep_scrub(v, scrub) for k, v in obj.items()}
    return obj


def build_payload(req: dict, resp: dict, meta: dict, scrub, start_iso: str, end_iso: str) -> dict:
    """Build the Langfuse /api/public/ingestion batch (trace-create + generation-create).

    `scrub` is a callable str->str (the proxy passes regex_mask(t)[0]); it is applied to
    BOTH the request (system + messages) and the completion output — always, regardless of
    upstream masking — so Langfuse never stores credential patterns.
    """
    trace_id = str(uuid.uuid4())
    gen_id = str(uuid.uuid4())
    scrubbed_system = _deep_scrub(req.get("system"), scrub)
    scrubbed_messages = _deep_scrub(req.get("messages", []), scrub)
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
                        "max_tokens": req.get("max_tokens"),
                        "cache_creation_input_tokens": resp.get("cache_creation_input_tokens", 0),
                        "cache_read_input_tokens": resp.get("cache_read_input_tokens", 0),
                        "truncated": resp.get("truncated", False),
                    },
                },
            },
        ]
    }


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


def capture(req_bytes, resp_bytes, is_streaming, meta, scrub, config):
    """Spawn a daemon thread to parse, scrub, build and POST. Returns the thread, or None
    if the thread could not be spawned (e.g. OS thread exhaustion).

    Non-blocking and fail-soft: any error — including spawn failure in the caller thread —
    is swallowed; the proxied request is never affected.
    """
    try:
        start_iso = _now_iso()
        t = threading.Thread(
            target=_emit,
            args=(req_bytes, resp_bytes, is_streaming, meta, scrub, config, start_iso),
            daemon=True,
        )
        t.start()
        return t
    except Exception as exc:  # noqa: BLE001 — fail-soft by design (never break the proxy)
        log.warning("Langfuse capture spawn failed: %s", exc)
        return None
