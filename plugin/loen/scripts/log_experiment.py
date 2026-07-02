#!/usr/bin/env python3
"""loen experiments.jsonl appender + validator (deterministic).

Usage: log_experiment.py <target.jsonl> [json-record]
The record comes from argv[2] or stdin. Validates the required keys for its
"type" (baseline | experiment), then appends exactly one compact JSON line.
Malformed input -> exit 1, nothing written. The worker never hand-edits the
stream; the verifier re-checks it against metrics.jsonl."""
import json
import re
import sys
from typing import NoReturn

REQUIRED = {
    "baseline": ["type", "ts", "eval_command", "metrics"],
    "experiment": ["type", "ts", "iter", "hypothesis", "files_changed",
                   "eval_command", "metrics_before", "metrics_after", "delta",
                   "decision", "risks", "next_hypothesis"],
}
ITER = re.compile(r"^iter-\d{2}$")


def fail(msg) -> NoReturn:
    sys.stderr.write("log_experiment: " + msg + "\n")
    sys.exit(1)


def main():
    if len(sys.argv) < 2:
        fail("usage: log_experiment.py <target.jsonl> [json-record]")
    target = sys.argv[1]
    raw = sys.argv[2] if len(sys.argv) > 2 else sys.stdin.read()
    try:
        rec = json.loads(raw)
    except Exception as e:
        fail(f"malformed JSON: {e}")
    if not isinstance(rec, dict):
        fail("record must be a JSON object")
    rtype = rec.get("type")
    if rtype not in REQUIRED:
        fail(f"unknown type: {rtype!r} (expected baseline | experiment)")
    missing = [k for k in REQUIRED[rtype] if k not in rec]
    if missing:
        fail(f"missing required keys for type={rtype}: {missing}")
    if rtype == "baseline":
        if not isinstance(rec["metrics"], dict):
            fail("metrics must be an object")
    else:
        if not ITER.match(str(rec["iter"])):
            fail(f"bad iter {rec['iter']!r} (expected iter-NN)")
        if rec["decision"] not in ("keep", "revert"):
            fail(f"bad decision {rec['decision']!r} (expected keep | revert)")
        if not isinstance(rec["files_changed"], list):
            fail("files_changed must be a list")
        if not isinstance(rec["metrics_before"], dict):
            fail("metrics_before must be an object")
        # metrics_after / delta may be null on a failed eval
        # (the experiment is recorded, then reverted)
        ma = rec["metrics_after"]
        if ma is not None and not isinstance(ma, dict):
            fail("metrics_after must be an object or null")
    with open(target, "a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
