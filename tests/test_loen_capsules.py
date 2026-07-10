#!/usr/bin/env python3
"""Unit test for loen_capsules.render_capsule — bounded context, not chat."""
import importlib.util, os, tempfile, pathlib
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(name):
    p = os.path.join(REPO, "plugin", "loen", "hooks", name + ".py")
    s = importlib.util.spec_from_file_location(name, p)
    m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m


def test_capsule_contains_bounded_fields():
    cap = load("loen_capsules")
    d = tempfile.mkdtemp(); td = pathlib.Path(d, "docs/loen/t"); td.mkdir(parents=True)
    (td / "loop.yaml").write_text(
        "topic: t\nmode: delivery\ncurrent_stage: check\nobjective: ship X\n"
        "mutable_scope:\n  - src/**\nprotected_scope:\n  - migrations/**\n"
        "quality_gates:\n  - pytest\n")
    (td / "2_context.md").write_text("## Facts\n- relevant: src/app.py\n")
    (td / "5_check.md").write_text("## Result\nPASS: 12 tests\n")
    out = cap.render_capsule(str(td), "verifier", "Is iteration 2 safe to keep?")
    for needle in ["t", "ship X", "delivery", "check", "src/**",
                   "migrations/**", "pytest", "verifier",
                   "Is iteration 2 safe to keep?"]:
        assert needle in out, needle


if __name__ == "__main__":
    test_capsule_contains_bounded_fields(); print("PASS test_loen_capsules.py")
