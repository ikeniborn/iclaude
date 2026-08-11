#!/usr/bin/env python3
"""Tests for the permission-guard PreToolUse hook (shell/network policy)."""
import json, os, subprocess, sys, tempfile, pathlib
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOOK = os.path.join(REPO, "plugin", "loen", "hooks", "permission-guard.py")


def run(cwd, command):
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})
    p = subprocess.run([sys.executable, HOOK], input=payload, text=True,
                       capture_output=True, cwd=cwd,
                       env={**os.environ, "LOEN_MODE": "enforce",
                            "LOEN_ARTIFACT_ROOT": "docs/loen"})
    return p.returncode


def setup(deny="[rm -rf]"):
    d = tempfile.mkdtemp(); t = pathlib.Path(d, "docs/loen/t"); t.mkdir(parents=True)
    (t / "loop.yaml").write_text(
        "topic: t\nstatus: active\n"
        "permissions:\n  network: {mode: off, allowlist: []}\n"
        f"  shell: {{allow: [], deny_patterns: {deny}}}\n")
    (pathlib.Path(d, "docs/loen/current")).write_text("t\n")
    return d


def test_blocks_git_reset_hard():
    d = setup(); assert run(d, "git reset --hard HEAD~1") == 2


def test_blocks_network_off():
    d = setup(); assert run(d, "curl https://example.com") == 2


def test_allows_plain_command():
    d = setup(); assert run(d, "ls -la") == 0


def test_blocks_deny_pattern():
    d = setup(); assert run(d, "rm -rf /etc") == 2


def test_no_loop_allows():
    d = tempfile.mkdtemp(); assert run(d, "curl https://example.com") == 0


def test_finished_loop_does_not_gate_project():
    # A done loop must not block network / git commands project-wide.
    d = tempfile.mkdtemp(); t = pathlib.Path(d, "docs/loen/t"); t.mkdir(parents=True)
    (t / "loop.yaml").write_text(
        "topic: t\nstatus: done\n"
        "permissions:\n  network: {mode: off, allowlist: []}\n"
        "  shell: {allow: [], deny_patterns: []}\n")
    (pathlib.Path(d, "docs/loen/current")).write_text("t\n")
    assert run(d, "curl https://example.com") == 0
    assert run(d, "git reset --hard HEAD~1") == 0


if __name__ == "__main__":
    for n, f in sorted(globals().items()):
        if n.startswith("test_") and callable(f): f(); print("ok", n)
    print("PASS test_loen_permission_guard.py")
