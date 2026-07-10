#!/usr/bin/env python3
"""Tests for the audit-writer PostToolUse hook (regenerate audit.html + TODO)."""
import importlib.util, json, os, subprocess, sys, tempfile, pathlib
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOOK = os.path.join(REPO, "plugin", "loen", "hooks", "audit-writer.py")
TEMPLATES = os.path.join(REPO, "plugin", "loen", "assets", "templates")


def load(name):
    p = os.path.join(REPO, "plugin", "loen", "hooks", name + ".py")
    s = importlib.util.spec_from_file_location(name, p)
    m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m


def run(cwd, path="docs/loen/t/4_act.md"):
    payload = json.dumps({"hook_event_name": "PostToolUse", "tool_name": "Write",
                          "tool_input": {"file_path": path}})
    p = subprocess.run([sys.executable, HOOK], input=payload, text=True,
                       capture_output=True, cwd=cwd,
                       env={**os.environ, "LOEN_MODE": "enforce",
                            "LOEN_ARTIFACT_ROOT": "docs/loen", "LOEN_TODAY": "2026-07-10"})
    return p.returncode


def test_writes_audit_and_todo():
    a = load("loen_artifacts")
    d = tempfile.mkdtemp()
    a.scaffold_topic("t", TEMPLATES, os.path.join(d, "docs", "loen"))
    rc = run(d)
    assert rc == 0, rc
    assert pathlib.Path(d, "docs/loen/t/audit.html").is_file()
    todo = pathlib.Path(d, "docs/TODO.md").read_text()
    assert "| t |" in todo


def test_no_loop_is_noop():
    d = tempfile.mkdtemp()
    assert run(d, path="src/app.py") == 0
    assert not pathlib.Path(d, "docs/TODO.md").exists()


def test_finished_loop_is_noop():
    # Once the loop is done, audit-writer must not churn TODO on unrelated edits.
    a = load("loen_artifacts")
    d = tempfile.mkdtemp()
    a.scaffold_topic("t", TEMPLATES, os.path.join(d, "docs", "loen"))
    lp = pathlib.Path(d, "docs/loen/t/loop.yaml")
    lp.write_text(lp.read_text().replace("status: active", "status: done"))
    assert run(d) == 0
    assert not pathlib.Path(d, "docs/TODO.md").exists()


if __name__ == "__main__":
    for n, f in sorted(globals().items()):
        if n.startswith("test_") and callable(f) and n != "load": f(); print("ok", n)
    print("PASS test_loen_audit_writer.py")
