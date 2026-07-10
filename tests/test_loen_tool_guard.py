#!/usr/bin/env python3
"""Tests for the tool-guard PreToolUse hook (tools.allowed + stage roles)."""
import json, os, subprocess, sys, tempfile, pathlib
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOOK = os.path.join(REPO, "plugin", "loen", "hooks", "tool-guard.py")


def run(cwd, tool, role="worker", path="src/app.py"):
    env = {**os.environ, "LOEN_MODE": "enforce", "LOEN_ARTIFACT_ROOT": "docs/loen"}
    if role is not None:
        env["LOEN_ROLE"] = role
    else:
        env.pop("LOEN_ROLE", None)
    payload = json.dumps({"tool_name": tool, "tool_input": {"file_path": path}})
    p = subprocess.run([sys.executable, HOOK], input=payload, text=True,
                       capture_output=True, cwd=cwd, env=env)
    return p.returncode


def setup_stage(stage):
    d = tempfile.mkdtemp(); t = pathlib.Path(d, "docs/loen/t"); t.mkdir(parents=True)
    (t / "loop.yaml").write_text(
        f"topic: t\nstatus: active\ncurrent_stage: {stage}\n"
        "tools: {allowed: [Read, Grep, Glob, Write, Edit, MultiEdit, Bash], denied: []}\n"
        "stages:\n  act: {roles: [worker]}\n  check: {roles: [verifier]}\n")
    (pathlib.Path(d, "docs/loen/current")).write_text("t\n")
    return d


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


def test_orchestrator_no_role_allowed_on_check_stage():
    # The main-session worker (no LOEN_ROLE) must NOT be blocked while the
    # loop is in the check stage (roles=[verifier]) — it orchestrates.
    d = setup_stage("check")
    assert run(d, "Bash", role=None) == 0
    assert run(d, "Read", role=None) == 0
    assert run(d, "Write", role=None) == 0


def test_subagent_role_still_constrained_on_check_stage():
    # A dispatched reviewer during the check stage IS blocked (role asserted).
    d = setup_stage("check")
    assert run(d, "Write", role="reviewer") == 2
    assert run(d, "Bash", role="verifier") == 0


if __name__ == "__main__":
    for n, f in sorted(globals().items()):
        if n.startswith("test_") and callable(f): f(); print("ok", n)
    print("PASS test_loen_tool_guard.py")
