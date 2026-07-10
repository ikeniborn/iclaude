#!/usr/bin/env python3
"""Tests for the evidence-gate Stop hook.

Done-signal = loop.yaml status: done. On a done-signal Stop the required
evidence must exist, otherwise the stop is blocked."""
import json, os, subprocess, sys, tempfile, pathlib
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOOK = os.path.join(REPO, "plugin", "loen", "hooks", "evidence-gate.py")


def run(cwd, mode="enforce"):
    payload = json.dumps({"hook_event_name": "Stop", "stop_hook_active": True})
    p = subprocess.run([sys.executable, HOOK], input=payload, text=True,
                       capture_output=True, cwd=cwd,
                       env={**os.environ, "LOEN_MODE": mode,
                            "LOEN_ARTIFACT_ROOT": "docs/loen"})
    return p.returncode


def setup(status="done", files=(), evidence=()):
    d = tempfile.mkdtemp(); t = pathlib.Path(d, "docs/loen/t"); t.mkdir(parents=True)
    (t / "loop.yaml").write_text(f"topic: t\nstatus: {status}\n")
    (pathlib.Path(d, "docs/loen/current")).write_text("t\n")
    (t / "evidence").mkdir()
    for f in files:
        (t / f).write_text("x\n")
    for e in evidence:
        (t / "evidence" / e).write_text("x\n")
    return d


def test_done_missing_evidence_blocks():
    d = setup(status="done", files=("5_check.md",))
    assert run(d) == 2


def test_done_complete_allows():
    d = setup(status="done", files=("5_check.md", "7_result.md"),
              evidence=("verifier-verdict.md",))
    assert run(d) == 0


def test_non_done_allows():
    d = setup(status="active", files=())
    assert run(d) == 0


def test_no_loop_allows():
    d = tempfile.mkdtemp(); assert run(d) == 0


if __name__ == "__main__":
    for n, f in sorted(globals().items()):
        if n.startswith("test_") and callable(f): f(); print("ok", n)
    print("PASS test_loen_evidence_gate.py")
