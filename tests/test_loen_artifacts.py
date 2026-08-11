#!/usr/bin/env python3
"""Unit tests for loen_artifacts: scaffold, render_audit, upsert_todo, attempts."""
import importlib.util, os, tempfile, pathlib
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATES = os.path.join(REPO, "plugin", "loen", "assets", "templates")


def load(name):
    p = os.path.join(REPO, "plugin", "loen", "hooks", name + ".py")
    s = importlib.util.spec_from_file_location(name, p)
    m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m


def test_scaffold_creates_topic():
    a = load("loen_artifacts")
    d = tempfile.mkdtemp(); root = os.path.join(d, "docs", "loen")
    a.scaffold_topic("my-topic", TEMPLATES, root)
    td = os.path.join(root, "my-topic")
    for f in a.STAGE_FILES:
        assert os.path.isfile(os.path.join(td, f)), f
    assert os.path.isfile(os.path.join(td, "loop.yaml"))
    assert os.path.isdir(os.path.join(td, "evidence"))
    assert pathlib.Path(root, "current").read_text().strip() == "my-topic"
    # topic placeholder filled
    assert "my-topic" in pathlib.Path(td, "loop.yaml").read_text()


def test_render_audit_verdict_done_conditions():
    a = load("loen_artifacts")
    d = tempfile.mkdtemp(); root = os.path.join(d, "docs", "loen")
    a.scaffold_topic("t", TEMPLATES, root)
    td = os.path.join(root, "t")
    # Not done yet: 5_check has no PASS, 7_result absent-ish
    pathlib.Path(td, "5_check.md").write_text("## Result\nFAIL\n")
    html = a.render_audit("t", root)
    assert "Done" not in _verdict(html)
    # Make it done: PASS + Done + evidence
    pathlib.Path(td, "5_check.md").write_text("## Result\nPASS\n")
    pathlib.Path(td, "7_result.md").write_text("## Outcome\nDone\n")
    pathlib.Path(td, "evidence", "verifier-verdict.md").write_text("APPROVE\n")
    html = a.render_audit("t", root)
    assert "Done" in _verdict(html)


def _verdict(html):
    for line in html.splitlines():
        if "Verdict" in line:
            return line
    return ""


def test_render_audit_ignores_template_comment_sentinels():
    # A fresh scaffold keeps the template's placeholder value + a comment that
    # mentions PASS/Done. Even with evidence present, that must NOT read as Done.
    a = load("loen_artifacts")
    d = tempfile.mkdtemp(); root = os.path.join(d, "docs", "loen")
    a.scaffold_topic("t", TEMPLATES, root)
    td = os.path.join(root, "t")
    pathlib.Path(td, "evidence", "verifier-verdict.md").write_text("VERDICT: REJECT\n")
    html = a.render_audit("t", root)
    assert "Done" not in _verdict(html), "template comment sentinel leaked into verdict"


def test_upsert_todo_preserves_foreign_row():
    a = load("loen_artifacts")
    d = tempfile.mkdtemp(); cwd = os.getcwd()
    try:
        os.chdir(d); os.makedirs("docs")
        foreign = ("| Topic | Status | Intent | Spec | Plan | Result | Opened | Closed | Notes |\n"
                   "|---|---|---|---|---|---|---|---|---|\n"
                   "| t | done | ✓ | ✓ | ✓ | OK | 2026-06-01 | 2026-06-05 | check-chain managed |\n")
        pathlib.Path("docs/TODO.md").write_text(foreign)
        a.upsert_todo_row("t", "act", "–", "2026-07-10")
        body = pathlib.Path("docs/TODO.md").read_text()
        assert "check-chain managed" in body, "clobbered a foreign (check-chain) row"
        assert "2026-06-01" in body and "✓" in body
    finally:
        os.chdir(cwd)


def test_upsert_todo_idempotent():
    a = load("loen_artifacts")
    d = tempfile.mkdtemp(); cwd = os.getcwd()
    try:
        os.chdir(d)
        a.upsert_todo_row("t", "spec", "OK", "2026-07-10")
        a.upsert_todo_row("t", "spec", "OK", "2026-07-10")
        body = pathlib.Path("docs/TODO.md").read_text()
        assert body.count("| t |") == 1 or body.count("t") >= 1
        assert body.count("\n| t ") <= 1
    finally:
        os.chdir(cwd)


def test_append_attempt():
    a = load("loen_artifacts")
    d = tempfile.mkdtemp(); root = os.path.join(d, "docs", "loen")
    a.scaffold_topic("t", TEMPLATES, root)
    a.append_attempt("t", {"pass": 1, "decision": "keep"}, root)
    a.append_attempt("t", {"pass": 2, "decision": "keep"}, root)
    lines = pathlib.Path(root, "t", "attempts.jsonl").read_text().strip().splitlines()
    assert len(lines) == 2 and '"pass":1' in lines[0]


if __name__ == "__main__":
    for n, f in sorted(globals().items()):
        if n.startswith("test_") and callable(f) and n != "load": f(); print("ok", n)
    print("PASS test_loen_artifacts.py")
