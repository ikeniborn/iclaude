#!/usr/bin/env python3
"""Tests for the tool-guard PreToolUse hook (tools.allowed + stage roles)."""
import json, os, subprocess, sys, tempfile, pathlib
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOOK = os.path.join(REPO, "plugin", "loen", "hooks", "tool-guard.py")


def run(cwd, tool, role="worker", path="src/app.py"):
    payload = json.dumps({"tool_name": tool, "tool_input": {"file_path": path}})
    p = subprocess.run([sys.executable, HOOK], input=payload, text=True,
                       capture_output=True, cwd=cwd,
                       env={**os.environ, "LOEN_MODE": "enforce",
                            "LOEN_ARTIFACT_ROOT": "docs/loen", "LOEN_ROLE": role})
    return p.returncode


def setup():
    d = tempfile.mkdtemp(); t = pathlib.Path(d, "docs/loen/t"); t.mkdir(parents=True)
    (t / "loop.yaml").write_text(
        "topic: t\nstatus: active\ncurrent_stage: act\n"
        "tools: {allowed: [Read, Grep, Glob, Write, Edit, MultiEdit], denied: []}\n"
        "stages:\n  act: {roles: [worker]}\n")
    (pathlib.Path(d, "docs/loen/current")).write_text("t\n")
    return d


def test_blocks_disallowed_tool():
    d = setup(); assert run(d, "Bash", role="worker") == 2


def test_allows_allowed_tool_permitted_role():
    d = setup(); assert run(d, "Write", role="worker") == 0


def test_blocks_role_not_in_stage():
    d = setup(); assert run(d, "Write", role="reviewer") == 2


def test_no_loop_allows():
    d = tempfile.mkdtemp(); assert run(d, "Bash", role="worker", path="x.py") == 0


if __name__ == "__main__":
    for n, f in sorted(globals().items()):
        if n.startswith("test_") and callable(f): f(); print("ok", n)
    print("PASS test_loen_tool_guard.py")
