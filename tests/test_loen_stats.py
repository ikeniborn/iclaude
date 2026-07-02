#!/usr/bin/env python3
"""Unit tests for plugin/loen/scripts/loen_stats.py.

Builds fixture docs/loen/ trees in a tempdir, runs the aggregator via
subprocess, and asserts the JSON summary fields pinned by the spec:
success rate, keep/revert, primary first/last, failure taxonomy from
REJECT REQUIRED FIXES items, protected alerts, foreign entries, and
the valid-empty-summary contract."""
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


def build_fixture(root):
    """Two runs: APPROVE-final delivery + research (keep/revert stream,
    REJECT-final verdict); canon top-level entries; two foreign ones."""
    loen = os.path.join(root, "docs", "loen")

    a = os.path.join(loen, "2026-07-01-alpha")
    write(os.path.join(a, "loop.yaml"),
          "name: 2026-07-01-alpha\nmode: delivery\n")
    write(os.path.join(a, "state.md"),
          "# Loop state\n\n## Baseline\n- Objective: x\n\n## Attempts\n"
          "- iter-01: gates green, verifier APPROVE\n")
    write(os.path.join(a, "iterations", "iter-01", "gates.log"),
          "all gates passed\n")
    write(os.path.join(a, "iterations", "iter-01", "verifier.md"),
          "VERDICT: APPROVE\nEVIDENCE: pytest exit 0\nMISSING: none\n"
          "RISKS: none\nREQUIRED FIXES:\n")

    b = os.path.join(loen, "2026-07-02-beta")
    write(os.path.join(b, "loop.yaml"),
          "name: 2026-07-02-beta\nmode: research\n"
          "metrics:\n  primary:\n    - cer:min\n  secondary: []\n")
    write(os.path.join(b, "state.md"),
          "# Loop state\n\n## Baseline\n- Objective: y\n\n## Attempts\n"
          "- iter-01: keep\n- stop: budget exceeded\n")
    recs = [
        {"type": "baseline", "ts": "t0", "eval_command": "e",
         "metrics": {"cer": 0.19}},
        {"type": "experiment", "ts": "t1", "iter": "iter-01",
         "hypothesis": "h1", "files_changed": ["src/x.py"],
         "eval_command": "e", "metrics_before": {"cer": 0.19},
         "metrics_after": {"cer": 0.16}, "delta": {"cer": -0.03},
         "decision": "keep", "risks": "none", "next_hypothesis": "h2"},
        {"type": "experiment", "ts": "t2", "iter": "iter-02",
         "hypothesis": "h2", "files_changed": ["src/y.py"],
         "eval_command": "e", "metrics_before": {"cer": 0.16},
         "metrics_after": None, "delta": None,
         "decision": "revert", "risks": "eval failed",
         "next_hypothesis": "stop"},
    ]
    write(os.path.join(b, "experiments.jsonl"),
          "".join(json.dumps(r, sort_keys=True) + "\n" for r in recs))
    write(os.path.join(b, "iterations", "iter-01", "gates.log"),
          "gates ok\n")
    write(os.path.join(b, "iterations", "iter-01", "verifier.md"),
          "VERDICT: APPROVE\nREQUIRED FIXES:\n")
    write(os.path.join(b, "iterations", "iter-02", "gates.log"),
          "ERROR: protected path changed: datasets/gt.json"
          " (matches 'datasets/*')\n")
    write(os.path.join(b, "iterations", "iter-02", "verifier.md"),
          "VERDICT: REJECT\nEVIDENCE: eval exit 1\nMISSING: none\n"
          "RISKS: protected dataset touched\nREQUIRED FIXES:\n"
          "1. restore the protected dataset\n2. re-run the eval\n")

    # canon top-level entries: silently accepted, never foreign
    os.symlink("2026-07-01-alpha/", os.path.join(loen, "current"))
    write(os.path.join(loen, "RUNBOOK.md"), "# runbook\n")
    write(os.path.join(loen, "governance.html"), "<html></html>\n")
    # foreign: one stray file and one stray dir
    write(os.path.join(loen, "notes.txt"), "stray\n")
    os.makedirs(os.path.join(loen, "scratch"))
    return loen


def main():
    fails = []

    def check(name, got, want):
        if got != want:
            fails.append(f"{name}: got {got!r}, want {want!r}")

    with tempfile.TemporaryDirectory() as tmp:
        loen = build_fixture(tmp)
        rc, out, err = run_stats(loen)
        check("exit code", rc, 0)
        doc = json.loads(out)
        runs = {r["run_id"]: r for r in doc["runs"]}
        check("run count", len(runs), 2)

        alpha = runs["2026-07-01-alpha"]
        check("alpha mode", alpha["mode"], "delivery")
        check("alpha iterations", alpha["iterations"], 1)
        check("alpha last verdict", alpha["last_verdict"], "APPROVE")
        check("alpha gates.log presence", alpha["gates_log"],
              {"iter-01": True})
        check("alpha research extras", alpha["research"], None)

        beta = runs["2026-07-02-beta"]
        check("beta mode", beta["mode"], "research")
        check("beta last verdict", beta["last_verdict"], "REJECT")
        check("beta experiments", beta["research"]["experiments"], 2)
        check("beta keep", beta["research"]["keep"], 1)
        check("beta revert", beta["research"]["revert"], 1)
        check("beta primary", beta["research"]["primary"], "cer")
        check("beta primary first",
              beta["research"]["primary_first"], 0.19)
        check("beta primary last",
              beta["research"]["primary_last"], 0.16)

        t = doc["totals"]
        check("success rate", t["success_rate"], 0.5)
        check("runs by mode", t["runs_by_mode"],
              {"delivery": 1, "research": 1})
        check("keep total", t["keep"], 1)
        check("revert total", t["revert"], 1)
        check("handoff reasons", t["handoff_reasons"],
              ["budget exceeded"])
        check("failure taxonomy", t["failure_taxonomy"],
              {"restore the protected dataset": 1, "re-run the eval": 1})
        check("protected alerts", t["protected_alerts"], 1)
        check("cost/tokens unavailable", t["cost_tokens"], "unavailable")
        check("latency/VRAM unavailable", t["latency_vram"],
              "unavailable")
        check("foreign entries", doc["foreign"], ["notes.txt", "scratch"])

    with tempfile.TemporaryDirectory() as tmp:
        empty = os.path.join(tmp, "docs", "loen")
        os.makedirs(empty)
        rc, out, err = run_stats(empty)
        check("empty root exit", rc, 0)
        doc = json.loads(out)
        check("empty runs", doc["runs"], [])
        check("empty foreign", doc["foreign"], [])
        check("empty success rate", doc["totals"]["success_rate"], None)

    if fails:
        print("FAIL test_loen_stats.py")
        for f in fails:
            print("  -", f)
        sys.exit(1)
    print("PASS test_loen_stats.py")


if __name__ == "__main__":
    main()
