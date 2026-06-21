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


def test_parse_request_failsoft_on_malformed():
    r = le.parse_request(b"not json")
    assert r["model"] is None
    assert r["messages"] == []
    assert r["max_tokens"] is None
    # valid JSON but not a dict must also fail-soft (no exception)
    r2 = le.parse_request(b"[]")
    assert r2["model"] is None
    assert r2["messages"] == []


def test_parse_response_json_failsoft_on_malformed():
    r = le.parse_response(b"not json", is_streaming=False)
    assert r["output"] == ""
    assert r["thinking"] == ""
    assert r["model"] is None
    assert r["truncated"] is False
    # valid JSON but not a dict must also fail-soft
    r2 = le.parse_response(b"[]", is_streaming=False)
    assert r2["output"] == ""
    assert r2["thinking"] == ""
