#!/usr/bin/env python3
"""Unit tests for make_goal.py — the deterministic /goal string
generator. Exit 0 = one evidence-first /goal line on stdout;
exit 1 = contract refused, stdout empty."""
import os
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, "plugin", "loen", "scripts", "make_goal.py")

DELIVERY = """\
name: 2026-07-02-demo
mode: delivery              # delivery | repair | research
objective: "green gates"
context_sources: []
mutable_scope:
  - src/**
  - tests/**
protected_scope:
  - docs/**
quality_gates:
  - pytest -q
  - ruff check .
eval_command: ""
metrics:
  primary: []
  secondary: []
budget:
  max_iterations: 3
  max_experiments: 5
  max_wall_time_minutes: 90
  max_cost_usd: 5
stop_conditions:
  - all quality gates pass
handoff_conditions: []
rollback_policy: ""
logging:
  state_file: docs/loen/2026-07-02-demo/state.md
"""

RESEARCH = """\
name: 2026-07-02-acc
mode: research
objective: "raise acc"
context_sources: []
mutable_scope:
  - src/retrieval.py
protected_scope:
  - eval/**
quality_gates:
  - pytest -q
  - bash plugin/loen/scripts/guard_protected.sh
eval_command: make eval
metrics:
  primary:
    - acc:max
  secondary: []
budget:
  max_iterations: 3
  max_experiments: 5
  max_wall_time_minutes: 90
  max_cost_usd: 5
stop_conditions:
  - "target: acc >= 0.9"
handoff_conditions: []
rollback_policy: git apply -R
logging:
  state_file: docs/loen/2026-07-02-acc/state.md
"""

DELIVERY_EXPECTED = (
    "/goal pytest -q exits 0 and ruff check . exits 0 and Claude prints "
    "each command's output summary as evidence; change only src/**, "
    "tests/**; do not modify docs/**; stop after 3 failed attempts and "
    "report the blocker")


def run(argv, cwd=None):
    p = subprocess.run([sys.executable, SCRIPT] + argv,
                       text=True, capture_output=True, cwd=cwd)
    return p.returncode, p.stdout, p.stderr


def write(root, text):
    path = os.path.join(root, "loop.yaml")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return path


def main():
    fails = []

    def check(name, cond):
        if not cond:
            fails.append(name)

    with tempfile.TemporaryDirectory() as root:
        # delivery contract -> exact evidence-first string
        rc, out, _ = run([write(root, DELIVERY)])
        check("delivery exit 0", rc == 0)
        check("delivery exact string", out.strip() == DELIVERY_EXPECTED)

        # repair contract -> same shape (max_iterations clause)
        rc, out, _ = run([write(root, DELIVERY.replace(
            "mode: delivery", "mode: repair", 1))])
        check("repair exit 0", rc == 0)
        check("repair exact string", out.strip() == DELIVERY_EXPECTED)

        # research contract -> target success clause first, gates as
        # invariants, evidence clause, max_experiments budget clause
        rc, out, _ = run([write(root, RESEARCH)])
        check("research exit 0", rc == 0)
        check("research target clause", out.startswith(
            "/goal the printed eval summary shows acc >= 0.9 and "))
        check("research gates stay", "pytest -q exits 0" in out)
        check("research evidence clause",
              "output summary as evidence" in out)
        check("research budget clause",
              "stop after 5 experiments and report the best kept state"
              in out)

        # quality_gates: [] -> exit 1, empty stdout
        rc, out, _ = run([write(root, DELIVERY.replace(
            "quality_gates:\n  - pytest -q\n  - ruff check .",
            "quality_gates: []", 1))])
        check("empty gates exit 1", rc == 1)
        check("empty gates no stdout", out == "")

        # empty mutable_scope -> exit 1, empty stdout
        rc, out, _ = run([write(root, DELIVERY.replace(
            "mutable_scope:\n  - src/**\n  - tests/**",
            "mutable_scope: []", 1))])
        check("empty mutable exit 1", rc == 1)
        check("empty mutable no stdout", out == "")

        # research without a target: line -> exit 1, empty stdout
        rc, out, _ = run([write(root, RESEARCH.replace(
            '  - "target: acc >= 0.9"', "  - never regress", 1))])
        check("no target exit 1", rc == 1)
        check("no target no stdout", out == "")

        # missing file -> exit 1, empty stdout
        rc, out, _ = run([os.path.join(root, "absent.yaml")])
        check("missing file exit 1", rc == 1)
        check("missing file no stdout", out == "")

        # unknown mode -> exit 1, empty stdout
        rc, out, _ = run([write(root, DELIVERY.replace(
            "mode: delivery", "mode: chaos", 1))])
        check("unknown mode exit 1", rc == 1)
        check("unknown mode no stdout", out == "")

        # non-integer mode budget -> exit 1, empty stdout
        rc, out, _ = run([write(root, DELIVERY.replace(
            "max_iterations: 3", "max_iterations: many", 1))])
        check("bad budget exit 1", rc == 1)
        check("bad budget no stdout", out == "")

        # no argv -> default path docs/loen/current/loop.yaml (cwd)
        run_dir = os.path.join(root, "docs", "loen", "2026-07-02-demo")
        os.makedirs(run_dir)
        with open(os.path.join(run_dir, "loop.yaml"), "w",
                  encoding="utf-8") as f:
            f.write(DELIVERY)
        os.symlink("2026-07-02-demo",
                   os.path.join(root, "docs", "loen", "current"))
        rc, out, _ = run([], cwd=root)
        check("default path exit 0", rc == 0)
        check("default path exact string",
              out.strip() == DELIVERY_EXPECTED)

    if fails:
        print("FAIL test_loen_goal.py")
        for f in fails:
            print("  -", f)
        sys.exit(1)
    print("PASS test_loen_goal.py")


if __name__ == "__main__":
    main()
