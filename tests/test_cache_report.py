#!/usr/bin/env python3
"""SessionEnd cache report: aggregation, formatting, and fail-soft behavior."""
import importlib.util
import json
import os

HOOK = os.path.join(
    os.path.dirname(__file__), "..",
    ".nvm-isolated", ".claude-isolated", "hooks", "cache-report.py",
)


def _load():
    spec = importlib.util.spec_from_file_location("cache_report", HOOK)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _write_jsonl(path, rows):
    with open(path, "w", encoding="utf-8") as fh:
        for r in rows:
            fh.write(json.dumps(r) + "\n")


def _assistant(read, creation, inp, out):
    return {"type": "assistant", "message": {"usage": {
        "cache_read_input_tokens": read,
        "cache_creation_input_tokens": creation,
        "input_tokens": inp,
        "output_tokens": out,
    }}}


def test_aggregate_sums_assistant_turns(tmp_path):
    mod = _load()
    p = tmp_path / "t.jsonl"
    _write_jsonl(p, [
        {"type": "user", "message": {"content": "hi"}},      # ignored
        _assistant(500, 100, 25, 200),
        _assistant(500, 100, 25, 250),
    ])
    agg = mod.aggregate(str(p))
    assert agg == {"read": 1000, "creation": 200, "input": 50,
                   "output": 450, "turns": 2}


def test_format_report_has_hitrate_and_split(tmp_path):
    mod = _load()
    # read=1000, creation=200, input=50 -> 1000/1250 = 80%
    agg = {"read": 1000, "creation": 200, "input": 50, "output": 450, "turns": 2}
    report = mod.format_report("sess-1", agg)
    assert "80%" in report
    assert "cache-read   1000" in report
    assert "cache-write  200" in report
    assert "turns        2" in report


def test_aggregate_missing_transcript_is_empty():
    mod = _load()
    agg = mod.aggregate("/no/such/file.jsonl")
    assert agg["turns"] == 0
    assert agg["read"] == 0


def test_main_missing_transcript_exits_zero(monkeypatch, capsys):
    mod = _load()
    monkeypatch.setattr("sys.stdin",
                        __import__("io").StringIO(json.dumps(
                            {"transcript_path": "/no/such/file.jsonl",
                             "session_id": "x"})))
    assert mod.main() == 0
