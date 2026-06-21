import json
import sys
from pathlib import Path

# Import the emitter from its canonical source dir (lib/pii-proxy/), which is where
# the proxy resolves it at runtime (the isolated-dir copy is an install-time symlink).
EMITTER_DIR = Path(__file__).resolve().parents[1] / "lib" / "pii-proxy"
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
    assert gen["metadata"]["max_tokens"] == 8
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


def test_build_payload_deep_scrubs_tool_use_result_and_system_list():
    req = {
        "model": "m",
        "system": [{"type": "text", "text": "sys SECRET123",
                    "cache_control": {"type": "ephemeral"}}],
        "messages": [
            {"role": "assistant", "content": [
                {"type": "tool_use", "id": "t1", "name": "bash",
                 "input": {"command": "echo SECRET123"}},
            ]},
            {"role": "user", "content": [
                {"type": "tool_result", "tool_use_id": "t1",
                 "content": [{"type": "text", "text": "out SECRET123"}]},
            ]},
        ],
        "max_tokens": 8,
    }
    resp = {"output": "ok", "thinking": "", "model": "m",
            "input_tokens": 1, "output_tokens": 1,
            "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0,
            "stop_reason": "end_turn", "truncated": False}
    meta = {"session_id": "default", "project": "p", "pwd": "/x",
            "upstream_masking_level": "off"}
    payload = le.build_payload(req, resp, meta, scrub=_fake_scrub,
                              start_iso="a", end_iso="b")
    blob = json.dumps(payload)
    assert "SECRET123" not in blob   # system-list, tool_use.input, tool_result.content all scrubbed
    # structure + non-string fields preserved
    gen = payload["batch"][1]["body"]
    sys_block = gen["input"]["system"][0]
    assert sys_block["type"] == "text"
    assert sys_block["cache_control"] == {"type": "ephemeral"}
    tu = gen["input"]["messages"][0]["content"][0]
    assert tu["type"] == "tool_use"
    assert tu["name"] == "bash"
    assert tu["input"]["command"] == "echo [REDACTED]"
    tr = gen["input"]["messages"][1]["content"][0]
    assert tr["content"][0]["text"] == "out [REDACTED]"


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


def test_capture_failsoft_when_thread_start_raises(monkeypatch):
    def boom_start(self):
        raise RuntimeError("can't start new thread")

    monkeypatch.setattr(le.threading.Thread, "start", boom_start)
    out = le.capture(b'{"model":"m","messages":[]}', b'', is_streaming=True,
                     meta={"session_id": "default", "project": "p", "pwd": "/x",
                           "upstream_masking_level": "off"},
                     scrub=lambda s: s,
                     config={"host": "h", "public_key": "pk", "secret_key": "sk"})
    # Spawn failure in the caller thread must be swallowed, returning None — never raising.
    assert out is None
