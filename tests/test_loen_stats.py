#!/usr/bin/env python3
"""Unit tests for plugin/loen/scripts/loen_stats.py (topic layout).

Builds fixture docs/loen/ topic trees in a tempdir, runs the aggregator via
subprocess, and asserts the JSON summary fields: success rate, keep/revert,
failure taxonomy from REJECT REQUIRED FIXES items, foreign entries, and the
valid-empty-summary contract."""
import json
import os
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATS = os.path.join(REPO, "plugin", "loen", "scripts", "loen_stats.py")


def run_stats(root):
    p = subprocess.run([sys.executable, STATS, "--root", root],
                       capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def build_fixture(loen):
    # alpha: delivery, done, verifier APPROVE
    a = os.path.join(loen, "alpha")
    write(os.path.join(a, "loop.yaml"), "topic: alpha\nmode: delivery\nstatus: done\n")
    write(os.path.join(a, "evidence", "verifier-verdict.md"),
          "VERDICT: APPROVE\nEVIDENCE: pytest -> 0\n")
    # beta: research, verifier REJECT with fixes, keep/revert stream
    b = os.path.join(loen, "beta")
    write(os.path.join(b, "loop.yaml"), "topic: beta\nmode: research\nstatus: active\n")
    write(os.path.join(b, "evidence", "verifier-verdict.md"),
          "VERDICT: REJECT\nREQUIRED FIXES:\n1. add a regression test\n2. shrink the diff\n")
    write(os.path.join(b, "experiments.jsonl"),
          json.dumps({"type": "experiment", "decision": "keep"}) + "\n"
          + json.dumps({"type": "experiment", "decision": "revert"}) + "\n")
    # canon top + foreign
    write(os.path.join(loen, "current"), "alpha\n")
    write(os.path.join(loen, "governance.html"), "<html></html>\n")
    write(os.path.join(loen, "scratch.txt"), "junk\n")


def test_aggregates_topics():
    d = tempfile.mkdtemp(); loen = os.path.join(d, "docs", "loen")
    build_fixture(loen)
    rc, out, err = run_stats(loen)
    assert rc == 0, err
    s = json.loads(out)
    assert {t["topic"] for t in s["topics"]} == {"alpha", "beta"}
    assert s["totals"]["success_rate"] == 0.5  # alpha done, beta not
    assert s["totals"]["keep"] == 1 and s["totals"]["revert"] == 1
    assert "add a regression test" in s["totals"]["failure_taxonomy"]
    assert "scratch.txt" in s["foreign"]
    assert "current" not in s["foreign"] and "governance.html" not in s["foreign"]


def test_empty_root_is_valid():
    d = tempfile.mkdtemp()
    rc, out, err = run_stats(os.path.join(d, "nope"))
    assert rc == 0, err
    s = json.loads(out)
    assert s["topics"] == [] and s["totals"]["success_rate"] is None


if __name__ == "__main__":
    for n, f in sorted(globals().items()):
        if n.startswith("test_") and callable(f): f(); print("ok", n)
    print("PASS test_loen_stats.py")
