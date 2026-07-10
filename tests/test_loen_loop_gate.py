#!/usr/bin/env python3
"""Tests for the loop-gate PreToolUse hook (stage ordering + result gate)."""
import json, os, subprocess, sys, tempfile, pathlib
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOOK = os.path.join(REPO, "plugin", "loen", "hooks", "loop-gate.py")


def run(cwd, path, tool="Write"):
    payload = json.dumps({"tool_name": tool, "tool_input": {"file_path": path}})
    p = subprocess.run([sys.executable, HOOK], input=payload, text=True,
                       capture_output=True, cwd=cwd,
                       env={**os.environ, "LOEN_MODE": "enforce",
                            "LOEN_ARTIFACT_ROOT": "docs/loen"})
    return p.returncode


def setup(present, check_body="## Result\nPASS\n"):
    d = tempfile.mkdtemp(); t = pathlib.Path(d, "docs/loen/t"); t.mkdir(parents=True)
    (t / "loop.yaml").write_text("topic: t\nstatus: active\ncurrent_stage: act\n")
    (pathlib.Path(d, "docs/loen/current")).write_text("t\n")
    names = ["1_goal.md", "2_context.md", "3_plan.md", "4_act.md",
             "5_check.md", "6_reflect.md", "7_result.md"]
    for i in present:
        body = check_body if names[i - 1] == "5_check.md" else f"# {names[i-1]}\n"
        (t / names[i - 1]).write_text(body)
    return d


def test_blocks_missing_prev():
    d = setup([1, 2])  # 3_plan missing
    assert run(d, "docs/loen/t/4_act.md") == 2


def test_allows_in_order():
    d = setup([1, 2, 3])
    assert run(d, "docs/loen/t/4_act.md") == 0


def test_result_requires_check_pass_block():
    d = setup([1, 2, 3, 4, 5, 6], check_body="## Result\nFAIL\n")
    assert run(d, "docs/loen/t/7_result.md") == 2


def test_result_allowed_with_pass():
    d = setup([1, 2, 3, 4, 5, 6], check_body="## Result\nPASS\n")
    assert run(d, "docs/loen/t/7_result.md") == 0


def test_no_loop_allows():
    d = tempfile.mkdtemp(); assert run(d, "docs/loen/t/4_act.md") == 0


def test_unfilled_template_blocks_ordering():
    # A scaffolded topic pre-creates all 7 files as templates ({{...}}). Writing
    # 4_act must be blocked while 3_plan is still an unfilled template, then
    # allowed once 1_goal/2_context/3_plan are filled.
    import importlib.util
    ap = os.path.join(REPO, "plugin", "loen", "hooks", "loen_artifacts.py")
    s = importlib.util.spec_from_file_location("loen_artifacts", ap)
    a = importlib.util.module_from_spec(s); s.loader.exec_module(a)
    templates = os.path.join(REPO, "plugin", "loen", "assets", "templates")
    d = tempfile.mkdtemp()
    a.scaffold_topic("t", templates, os.path.join(d, "docs", "loen"))
    assert run(d, "docs/loen/t/4_act.md") == 2
    for f in ("1_goal.md", "2_context.md", "3_plan.md"):
        pathlib.Path(d, "docs/loen/t", f).write_text(f"# filled {f}\n")
    assert run(d, "docs/loen/t/4_act.md") == 0


if __name__ == "__main__":
    for n, f in sorted(globals().items()):
        if n.startswith("test_") and callable(f): f(); print("ok", n)
    print("PASS test_loen_loop_gate.py")
