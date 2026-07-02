#!/usr/bin/env python3
"""Unit tests for log_experiment.py — the deterministic
experiments.jsonl writer. Exit 0 = exactly one line appended;
exit 1 = rejected, target untouched."""
import json
import os
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, "plugin", "loen", "scripts",
                      "log_experiment.py")

BASELINE = {"type": "baseline", "ts": "2026-07-02T10:00:00Z",
            "eval_command": "make eval", "metrics": {"acc": 0.81}}
EXPERIMENT = {"type": "experiment", "ts": "2026-07-02T11:00:00Z",
              "iter": "iter-01",
              "hypothesis": "larger retrieval window improves acc",
              "files_changed": ["src/retrieval.py"],
              "eval_command": "make eval",
              "metrics_before": {"acc": 0.81},
              "metrics_after": {"acc": 0.84},
              "delta": {"acc": 0.03}, "decision": "keep",
              "risks": "none", "next_hypothesis": "tune threshold"}


def run(target, record=None, stdin=None):
    argv = [sys.executable, SCRIPT, target]
    if record is not None:
        argv.append(record)
    p = subprocess.run(argv, input=stdin, text=True, capture_output=True)
    return p.returncode


def lines(target):
    if not os.path.exists(target):
        return []
    with open(target, encoding="utf-8") as f:
        return f.read().splitlines()


def main():
    fails = []

    def check(name, cond):
        if not cond:
            fails.append(name)

    with tempfile.TemporaryDirectory() as root:
        t = os.path.join(root, "experiments.jsonl")

        # valid baseline as argv -> exit 0, one line, round-trips
        check("baseline exit 0", run(t, json.dumps(BASELINE)) == 0)
        check("baseline one line", len(lines(t)) == 1)
        check("baseline round-trip",
              json.loads(lines(t)[0])["type"] == "baseline")

        # valid experiment via stdin -> exit 0, second line
        check("experiment exit 0", run(t, stdin=json.dumps(EXPERIMENT)) == 0)
        check("experiment appended", len(lines(t)) == 2)

        # failed-eval record: metrics_after null + decision revert -> accepted
        failed = dict(EXPERIMENT, iter="iter-02", metrics_after=None,
                      delta=None, decision="revert")
        check("failed-eval record exit 0", run(t, json.dumps(failed)) == 0)
        check("failed-eval appended", len(lines(t)) == 3)

        before = len(lines(t))
        # missing required key -> exit 1, file untouched
        bad = {k: v for k, v in EXPERIMENT.items() if k != "decision"}
        check("missing key exit 1", run(t, json.dumps(bad)) == 1)
        check("missing key untouched", len(lines(t)) == before)

        # malformed JSON -> exit 1, file untouched
        check("malformed exit 1", run(t, "{not json") == 1)
        check("malformed untouched", len(lines(t)) == before)

        # unknown type -> exit 1, file untouched
        check("unknown type exit 1",
              run(t, json.dumps(dict(BASELINE, type="mystery"))) == 1)
        check("unknown type untouched", len(lines(t)) == before)

        # bad iter segment -> exit 1
        check("bad iter exit 1",
              run(t, json.dumps(dict(EXPERIMENT, iter="iter-1"))) == 1)

        # bad decision -> exit 1
        check("bad decision exit 1",
              run(t, json.dumps(dict(EXPERIMENT, decision="maybe"))) == 1)

    if fails:
        print("FAIL test_loen_experiment.py")
        for f in fails:
            print("  -", f)
        sys.exit(1)
    print("PASS test_loen_experiment.py")


if __name__ == "__main__":
    main()
