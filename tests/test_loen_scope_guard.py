#!/usr/bin/env python3
"""Tests for the scope-guard PreToolUse hook."""
import json, os, subprocess, sys, tempfile, pathlib
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOOK = os.path.join(REPO, "plugin", "loen", "hooks", "scope-guard.py")


def run(cwd, path, tool="Write"):
    payload = json.dumps({"tool_name": tool, "tool_input": {"file_path": path}})
    p = subprocess.run([sys.executable, HOOK], input=payload, text=True,
                       capture_output=True, cwd=cwd,
                       env={**os.environ, "LOEN_MODE": "enforce",
                            "LOEN_ARTIFACT_ROOT": "docs/loen"})
    return p.returncode


def setup():
    d = tempfile.mkdtemp(); t = pathlib.Path(d, "docs/loen/t"); t.mkdir(parents=True)
    (t / "loop.yaml").write_text(
        "topic: t\nstatus: active\n"
        "permissions:\n  filesystem: {mutable_scope: [src/**], protected_scope: [migrations/**]}\n")
    (pathlib.Path(d, "docs/loen/current")).write_text("t\n")
    return d


def test_allows_in_scope():
    d = setup(); assert run(d, "src/app.py") == 0


def test_blocks_protected():
    d = setup(); assert run(d, "migrations/001.sql") == 2


def test_blocks_out_of_scope():
    d = setup(); assert run(d, "README.md") == 2


def test_allows_topic_dir():
    d = setup(); assert run(d, "docs/loen/t/4_act.md") == 0


def test_no_loop_allows():
    d = tempfile.mkdtemp(); assert run(d, "anything.py") == 0


def test_finished_loop_does_not_gate_project():
    # A done loop still pointed at by docs/loen/current must NOT block edits
    # anywhere in the project.
    d = tempfile.mkdtemp(); t = pathlib.Path(d, "docs/loen/t"); t.mkdir(parents=True)
    (t / "loop.yaml").write_text(
        "topic: t\nstatus: done\n"
        "permissions:\n  filesystem: {mutable_scope: [src/**], protected_scope: [migrations/**]}\n")
    (pathlib.Path(d, "docs/loen/current")).write_text("t\n")
    assert run(d, "README.md") == 0
    assert run(d, "migrations/001.sql") == 0


if __name__ == "__main__":
    for n, f in sorted(globals().items()):
        if n.startswith("test_") and callable(f): f(); print("ok", n)
    print("PASS test_loen_scope_guard.py")
