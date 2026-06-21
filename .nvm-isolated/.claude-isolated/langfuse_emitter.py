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
