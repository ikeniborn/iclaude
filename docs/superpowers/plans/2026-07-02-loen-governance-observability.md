---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-02-loen-governance-observability-design.md
review:
  plan_hash: 7d93418989614184
  last_run: 2026-07-02
  runner: "clean-context subagent (check-runner protocol)"
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - { id: F-001, phase: coverage, severity: INFO, verdict: fixed, note: "Task 4 Edit 2 prose insert called itself 'this table' (spec §9 says Artifacts table row; paragraph chosen because the existing table is per-run-dir) → reworded to 'this Artifacts entry'" }
    - { id: F-002, phase: coverage, severity: INFO, verdict: wontfix, note: "Task 1 Step 5 flake8 lint is bound to no spec §7 item — kept as explicitly-labeled repo convention (post-PR #76), non-functional" }
    - { id: F-003, phase: consistency, severity: INFO, verdict: fixed, note: "VERDICT/HANDOFF regex in Task 1 code added \\b + whitespace tolerance vs the Global Constraints pins → pins amended to record the deliberate tolerances (code unchanged)" }
  verdict: OK
result_check:
  verdict: OK
  plan_hash: 7d93418989614184
  last_run: 2026-07-03
  note: "diff base f4e1cb75 (origin/dev)..75936950 (6 commits): 5/5 tasks DONE, 0 PARTIAL/MISSING, 0 unexplained excess (3 chain artifacts + final-review fix 75936950 read_lines UnicodeDecodeError, approved deviation); spec §2-§7,§9 covered 7/7; 9/9 suites + version-sync + JSON-OK smoke re-run green by clean-context runner; iwiki Components/Artifact model/Roadmap verified updated; final whole-branch review (fable): READY TO MERGE Yes"
---
# loen backlog step 4 — governance / observability — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the offline-first cross-run governance view over `docs/loen/`: a deterministic aggregator `loen_stats.py`, a `/loen:governance` skill rendering `docs/loen/governance.html`, and +1 canonical path in the loop-guard hook.

**Architecture:** A stdlib-only, read-only Python script scans every run dir under `docs/loen/` and emits one JSON summary (per-run facts + cross-run totals). A thin skill runs the script and renders the JSON as a self-contained HTML dashboard via the `html-report` skill; the `--triage` variant additionally proposes (never executes) next actions for failing runs. The hook grows exactly one canonical top-level path via an EARLY `path ==` guard (the run-id gate makes `canon_patterns()` unreachable for top-level files).

**Tech Stack:** Python 3 stdlib (no new dependencies), bash test suites already in `tests/`, Claude Code plugin skill (Markdown), `html-report` skill for rendering.

**Branch:** `dev-loen-governance-observability` (per CLAUDE.md naming). Base branch: previous loen increments were PR'd into `dev` — confirm base (`dev` vs `master`) with the user before creating the branch, per CLAUDE.md long-lived-branch rule. Also ask: worktree `wk-dev-loen-governance-observability` or in place.

## Global Constraints

- **Offline-first (spec §5):** no network I/O anywhere; the aggregator is stdlib-only, read-only, never writes into run dirs.
- **Exactly one write in the skill:** `docs/loen/governance.html` (spec §3.4).
- **Fidelity rule (spec §2):** the aggregator only RESTATES artifact evidence; the §10.3 rows loen artifacts cannot back — cost/tokens AND latency/VRAM — are reported/rendered as `unavailable` / "n/a", never fabricated.
- **Format pins:** run-id regex `^\d{4}-\d{2}-\d{2}-[a-z0-9-]+$` (same as hook); verifier verdict line `^VERDICT:\s*(APPROVE|REJECT)` — the ONLY format-pinned verifier.md line (the implementation deliberately adds a word boundary and matches the stripped line, tolerating surrounding whitespace and rejecting e.g. `APPROVED`); protected alert `^ERROR: protected path changed:` (exact `guard_protected.sh` literal); taxonomy source = numbered `REQUIRED FIXES:` items of REJECT verdicts ONLY (`gates.log` is deliberately NOT parsed for taxonomy — spec F-005).
- **Handoff/stop pin (plan decision, spec left the line format open):** inside the `## Attempts` section of `state.md`, lines matching `^\s*(?:[-*]\s*)?(?:handoff|stop)\s*:\s*(.+?)\s*$` case-insensitive; the reason text is restated verbatim (trailing whitespace trimmed). Documented in `docs/functions/LOEN.md` (Task 4) so workers write parseable lines.
- **Known top-level canon set:** `current`, `RUNBOOK.md`, `governance.html` — silently accepted; every OTHER direct child (file or dir) of `docs/loen/` is `foreign`.
- **Empty/missing root:** valid empty summary, exit 0 (governance over zero runs is not an error).
- **Hook change (spec §4):** early `path ==` allow guard is the operative change; `canon_patterns()` entry + block-message line are documentation symmetry. `check_layout.sh` is NOT touched.
- **Version bump:** plugin `0.4.0` → `0.5.0` in BOTH `plugin/loen/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (lockstep, enforced by `scripts/check-plugin-version-sync.sh` and `tests/test_loen_plugin.sh`).
- **Triage proposes, never executes** (spec §3.3): no loop launches, no run edits, no auto-fix; scheduling recipe is one line + session-durability caveat.
- **Docs language:** English everywhere except root `README.md` (existing file is Russian — match it).
- `docs/TODO.md` row `loen-governance-observability` is driven by `/check-chain`, not edited by plan tasks.

---

### Task 1: Deterministic aggregator `loen_stats.py`

**Files:**
- Create: `plugin/loen/scripts/loen_stats.py`
- Test: `tests/test_loen_stats.py`

**Interfaces:**
- Consumes: run artifacts produced by existing skills — `loop.yaml` (`mode:` line; `metrics:`→`primary:` block or inline list `<name>:max|min`), `iterations/iter-NN/{gates.log,verifier.md}`, `state.md` (`## Attempts` section), `experiments.jsonl` (records written by `log_experiment.py`: `type` baseline|experiment, `decision` keep|revert, `metrics`, `metrics_before`, `metrics_after`).
- Produces: CLI `python3 plugin/loen/scripts/loen_stats.py [--root <dir>]` → one JSON document on stdout, exit 0. Schema (consumed by Task 3's skill):
  - `root: str`
  - `runs: [{run_id: str, mode: str|null, iterations: int, last_verdict: "APPROVE"|"REJECT"|null, gates_log: {"iter-NN": bool}, research: null | {experiments: int, keep: int, revert: int, primary: str|null, primary_first: num|null, primary_last: num|null}}]`
  - `foreign: [str]` (sorted names of non-run-id, non-canon direct children — files AND dirs)
  - `totals: {runs_by_mode: {str: int}, success_rate: float|null, keep: int, revert: int, handoff_reasons: [str], failure_taxonomy: {str: int}, protected_alerts: int, cost_tokens: "unavailable", latency_vram: "unavailable"}`
  - `success_rate` = runs whose FINAL (max) iteration's `verifier.md` says `VERDICT: APPROVE`, divided by run count; `null` when zero runs. `last_verdict` = verdict of the latest iteration that HAS a `verifier.md` (triage key).

- [ ] **Step 1: Write the failing test**

Create `tests/test_loen_stats.py` (same style as `tests/test_loen_hook.py`: fixture tempdir, subprocess, `check()` collector):

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
python3 tests/test_loen_stats.py
```
Expected: FAIL — subprocess cannot find `plugin/loen/scripts/loen_stats.py` (traceback or non-zero `rc` checks failing).

- [ ] **Step 3: Write the implementation**

Create `plugin/loen/scripts/loen_stats.py`:

```python
#!/usr/bin/env python3
"""loen governance aggregator (deterministic, offline).

Scans a docs/loen/ tree and emits ONE JSON summary on stdout: per-run
facts plus cross-run totals — loop success rate, keep/revert counts,
handoff/stop reasons, failure taxonomy (REJECT verdicts' numbered
REQUIRED FIXES items; gates.log is free-form and deliberately NOT
parsed), protected-path alerts, foreign (layout-drift) entries.
Restates artifact evidence only; the dashboards loen artifacts cannot
back (cost/tokens, latency/VRAM) are reported as "unavailable".

stdlib only, read-only, no network. Empty or missing root -> valid
empty summary, exit 0 (governance over zero runs is not an error)."""
import argparse
import json
import os
import re

RUN_ID = re.compile(r"^\d{4}-\d{2}-\d{2}-[a-z0-9-]+$")
CANON_TOP = {"current", "RUNBOOK.md", "governance.html"}
ITER_DIR = re.compile(r"^iter-\d{2}$")
VERDICT = re.compile(r"^VERDICT:\s*(APPROVE|REJECT)\b")
FIXES_HEADER = re.compile(r"^REQUIRED FIXES:")
FIX_ITEM = re.compile(r"^\s*(\d+)[.)]\s+(.+?)\s*$")
SECTION = re.compile(r"^[A-Z][A-Z ]+:")
PROTECTED_ALERT = re.compile(r"^ERROR: protected path changed:")
HANDOFF = re.compile(
    r"^\s*(?:[-*]\s*)?(?:handoff|stop)\s*:\s*(.+?)\s*$", re.IGNORECASE)


def read_lines(path):
    """File content as a line list, or None when unreadable."""
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().splitlines()
    except OSError:
        return None


def parse_mode(lines):
    for s in lines or []:
        m = re.match(r"^mode:\s*(\S+)", s)
        if m:
            return m.group(1)
    return None


def parse_primary(lines):
    """Name of the first metrics.primary '<name>:max|min' entry, or
    None. Handles the block-style template layout and inline flow
    lists, like the hook's loop.yaml parsing."""
    in_metrics = in_primary = False
    for s in lines or []:
        if re.match(r"^metrics:\s*$", s):
            in_metrics, in_primary = True, False
            continue
        if in_metrics and re.match(r"^\S", s):
            break
        if not in_metrics:
            continue
        m = re.match(r"^\s+primary:\s*(.*)$", s)
        if m:
            rest = m.group(1).strip()
            fm = re.match(r"^\[([^\]]*)\]$", rest)
            if fm:
                for entry in fm.group(1).split(","):
                    em = re.match(r"^([\w.-]+):(max|min)$",
                                  entry.strip().strip("\"'"))
                    if em:
                        return em.group(1)
                return None
            in_primary = not rest
            continue
        if in_primary:
            im = re.match(r"^\s*-\s*([\w.-]+):(max|min)\s*$", s)
            if im:
                return im.group(1)
            if re.match(r"^\s+[\w-]+:", s):
                in_primary = False
    return None


def parse_verdict(lines):
    for s in lines:
        m = VERDICT.match(s.strip())
        if m:
            return m.group(1)
    return None


def parse_fixes(lines):
    """Numbered items of the REQUIRED FIXES: section."""
    items, in_fixes = [], False
    for s in lines:
        stripped = s.strip()
        if FIXES_HEADER.match(stripped):
            in_fixes = True
            continue
        if not in_fixes:
            continue
        m = FIX_ITEM.match(s)
        if m:
            items.append(m.group(2))
        elif SECTION.match(stripped):
            in_fixes = False
    return items


def parse_handoffs(lines):
    """'handoff:'/'stop:' reasons inside the state.md Attempts
    section, restated verbatim."""
    reasons, in_attempts = [], False
    for s in lines or []:
        if re.match(r"^##\s+Attempts\b", s):
            in_attempts = True
            continue
        if re.match(r"^##\s", s):
            in_attempts = False
            continue
        if in_attempts:
            m = HANDOFF.match(s)
            if m:
                reasons.append(m.group(1))
    return reasons


def research_stats(run_dir, primary):
    """experiments.jsonl extras, or None when the stream is absent."""
    lines = read_lines(os.path.join(run_dir, "experiments.jsonl"))
    if lines is None:
        return None
    experiments = keep = revert = 0
    first = last = None
    for raw in lines:
        raw = raw.strip()
        if not raw:
            continue
        try:
            rec = json.loads(raw)
        except ValueError:
            continue
        vals = None
        rtype = rec.get("type")
        if rtype == "baseline":
            vals = rec.get("metrics")
        elif rtype == "experiment":
            experiments += 1
            if rec.get("decision") == "keep":
                keep += 1
            elif rec.get("decision") == "revert":
                revert += 1
            # a reverted record's metrics_after is null: the last
            # observed value is then its metrics_before (= last kept)
            vals = rec.get("metrics_after") or rec.get("metrics_before")
        if primary and isinstance(vals, dict) and primary in vals:
            if first is None:
                first = vals[primary]
            last = vals[primary]
    return {"experiments": experiments, "keep": keep, "revert": revert,
            "primary": primary, "primary_first": first,
            "primary_last": last}


def scan_run(root, run_id):
    """One run's facts + the pieces totals aggregates over."""
    d = os.path.join(root, run_id)
    loop_lines = read_lines(os.path.join(d, "loop.yaml"))
    iters_dir = os.path.join(d, "iterations")
    iters = sorted(
        e for e in (os.listdir(iters_dir)
                    if os.path.isdir(iters_dir) else [])
        if ITER_DIR.match(e))
    gates_log, verdicts, fixes = {}, {}, []
    alerts = 0
    for it in iters:
        ip = os.path.join(iters_dir, it)
        gates_log[it] = os.path.isfile(os.path.join(ip, "gates.log"))
        if gates_log[it]:
            for s in read_lines(os.path.join(ip, "gates.log")) or []:
                if PROTECTED_ALERT.match(s):
                    alerts += 1
        vlines = read_lines(os.path.join(ip, "verifier.md"))
        if vlines is not None:
            verdicts[it] = parse_verdict(vlines)
            if verdicts[it] == "REJECT":
                fixes.extend(parse_fixes(vlines))
    last_verdict = None
    for it in iters:
        if verdicts.get(it):
            last_verdict = verdicts[it]
    final_verdict = verdicts.get(iters[-1]) if iters else None
    run = {
        "run_id": run_id,
        "mode": parse_mode(loop_lines),
        "iterations": len(iters),
        "last_verdict": last_verdict,
        "gates_log": gates_log,
        "research": research_stats(d, parse_primary(loop_lines)),
    }
    handoffs = parse_handoffs(read_lines(os.path.join(d, "state.md")))
    return run, final_verdict, fixes, alerts, handoffs


def main():
    ap = argparse.ArgumentParser(
        description="loen cross-run governance aggregator")
    ap.add_argument("--root", default=os.path.join("docs", "loen"),
                    help="docs/loen root (default: resolve from CWD)")
    args = ap.parse_args()
    root = args.root

    runs, foreign = [], []
    by_mode, taxonomy = {}, {}
    keep = revert = alerts = approved = 0
    handoff_reasons = []
    entries = sorted(os.listdir(root)) if os.path.isdir(root) else []
    for entry in entries:
        if entry in CANON_TOP:
            continue
        if not RUN_ID.match(entry):
            foreign.append(entry)
            continue
        run, final_verdict, fixes, run_alerts, handoffs = scan_run(
            root, entry)
        runs.append(run)
        mode_key = run["mode"] or "unknown"
        by_mode[mode_key] = by_mode.get(mode_key, 0) + 1
        if final_verdict == "APPROVE":
            approved += 1
        for item in fixes:
            taxonomy[item] = taxonomy.get(item, 0) + 1
        alerts += run_alerts
        handoff_reasons.extend(handoffs)
        if run["research"]:
            keep += run["research"]["keep"]
            revert += run["research"]["revert"]

    summary = {
        "root": root.replace(os.sep, "/"),
        "runs": runs,
        "foreign": foreign,
        "totals": {
            "runs_by_mode": by_mode,
            "success_rate": (approved / len(runs)) if runs else None,
            "keep": keep,
            "revert": revert,
            "handoff_reasons": handoff_reasons,
            "failure_taxonomy": taxonomy,
            "protected_alerts": alerts,
            "cost_tokens": "unavailable",
            "latency_vram": "unavailable",
        },
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2,
                     sort_keys=True))


if __name__ == "__main__":
    main()
```

Make it executable:
```bash
chmod +x plugin/loen/scripts/loen_stats.py
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
python3 tests/test_loen_stats.py
```
Expected: `PASS test_loen_stats.py`

- [ ] **Step 5: Lint (repo convention after PR #76)**

Run:
```bash
python3 -m flake8 plugin/loen/scripts/loen_stats.py tests/test_loen_stats.py --max-line-length 100 || true
```
Expected: no findings (fix any that appear; `|| true` only so a missing flake8 install doesn't hard-fail — if flake8 is absent, note it and move on).

- [ ] **Step 6: Commit**

```bash
git add plugin/loen/scripts/loen_stats.py tests/test_loen_stats.py
git commit -m "feat(loen): loen_stats.py — deterministic cross-run governance aggregator"
```

---

### Task 2: Loop-guard hook — +1 canonical top-level path

**Files:**
- Modify: `plugin/loen/hooks/loop-guard.py:29-39` (canon_patterns), `:119-123` (early guards), `:140-146` (block message)
- Test: `tests/test_loen_hook.py`

**Interfaces:**
- Consumes: existing hook control flow — early `path ==` guards for `docs/loen/current` and `docs/loen/RUNBOOK.md` run BEFORE the run-id segment gate.
- Produces: `docs/loen/governance.html` writes are allowed (exit 0) with or without an active loop — the write path Task 3's skill relies on. `docs/loen/governance.txt` (or any other top-level stray) still blocks (exit 2).

- [ ] **Step 1: Write the failing tests**

In `tests/test_loen_hook.py`, after the `check("bootstrap current allow", ...)` block (line 63-64), add:

```python
        # top-level governance dashboard: allowed like RUNBOOK.md,
        # even with no active loop
        check("governance.html allow (no loop)",
              run(root, os.path.join(root, "docs/loen/governance.html")), 0)
```

After the `check("non-canonical loen", ...)` block (line 87-88), add:

```python
        # governance.html stays allowed with an active loop; only the
        # .html dashboard is canonical at top level
        check("governance.html allow (active loop)",
              run(root, os.path.join(root, "docs/loen/governance.html")), 0)
        check("governance.txt block",
              run(root, os.path.join(root, "docs/loen/governance.txt")), 2)
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
python3 tests/test_loen_hook.py
```
Expected: FAIL with two lines — `governance.html allow (no loop): got exit 2, want 0` and `governance.html allow (active loop): got exit 2, want 0` (the `governance.txt block` case already passes).

- [ ] **Step 3: Implement the hook change**

In `plugin/loen/hooks/loop-guard.py`, three edits.

Edit 1 — the operative early guard (spec §4: `canon_patterns()` is unreachable for top-level paths). Old:

```python
    if path == "docs/loen/RUNBOOK.md":
        sys.exit(0)
```

New:

```python
    if path == "docs/loen/RUNBOOK.md":
        sys.exit(0)
    if path == "docs/loen/governance.html":
        sys.exit(0)
```

Edit 2 — `canon_patterns()` entry for documentation symmetry. Old:

```python
        re.compile(r"^docs/loen/RUNBOOK\.md$"),
```

New:

```python
        re.compile(r"^docs/loen/RUNBOOK\.md$"),
        re.compile(r"^docs/loen/governance\.html$"),
```

Edit 3 — human-facing block-message path listing. Old:

```python
        block(
            f"non-canonical loen artifact path: {path}\n"
            f"  expected: docs/loen/{R}/{{loop.yaml,plan.md,state.md,"
            f"pr-summary.md,report.html,experiments.jsonl}}\n"
            f"  or:       docs/loen/{R}/iterations/iter-NN/"
            f"{{diff.patch,gates.log,verifier.md,metrics.jsonl}}"
        )
```

New:

```python
        block(
            f"non-canonical loen artifact path: {path}\n"
            f"  expected: docs/loen/{R}/{{loop.yaml,plan.md,state.md,"
            f"pr-summary.md,report.html,experiments.jsonl}}\n"
            f"  or:       docs/loen/{R}/iterations/iter-NN/"
            f"{{diff.patch,gates.log,verifier.md,metrics.jsonl}}\n"
            f"  top-level: docs/loen/{{current,RUNBOOK.md,"
            f"governance.html}}"
        )
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
python3 tests/test_loen_hook.py
```
Expected: `PASS test_loen_hook.py`

Regression net (hook is also exercised by the guard suite):
```bash
bash tests/test_loen_guard.sh && bash tests/test_loen_layout.sh
```
Expected: both PASS (`check_layout.sh` untouched by design).

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/hooks/loop-guard.py tests/test_loen_hook.py
git commit -m "feat(loen): allow top-level governance.html in loop-guard (+1 canon path)"
```

---

### Task 3: `/loen:governance` skill + plugin lint + version 0.5.0

**Files:**
- Create: `plugin/loen/skills/governance/SKILL.md`
- Modify: `tests/test_loen_plugin.sh:49` (skill lint list), `plugin/loen/.claude-plugin/plugin.json` (version), `.claude-plugin/marketplace.json` (loen entry version)

**Interfaces:**
- Consumes: Task 1's CLI and JSON schema (`totals.success_rate`, `totals.handoff_reasons`, `totals.failure_taxonomy`, `totals.protected_alerts`, `totals.cost_tokens`/`latency_vram`, `foreign`, per-run `last_verdict`/`iterations`/`research.{primary,primary_first,primary_last,keep,revert}`); Task 2's allowed write path `docs/loen/governance.html`; the `html-report` skill (same flow `loen:audit` uses for `report.html`).
- Produces: user-invocable `/loen:governance [--triage]`; skill frontmatter `name: governance` (lint contract).

- [ ] **Step 1: Extend the lint list (failing test first)**

In `tests/test_loen_plugin.sh` line 49, old:

```bash
for s in loop-delivery audit loop-repair loop-autoresearch loop-goal; do
```

New:

```bash
for s in loop-delivery audit loop-repair loop-autoresearch loop-goal governance; do
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
bash tests/test_loen_plugin.sh
```
Expected: `FAIL: missing skill plugin/loen/skills/governance/SKILL.md`

- [ ] **Step 3: Create the skill**

Create `plugin/loen/skills/governance/SKILL.md`:

````markdown
---
name: governance
description: Cross-run governance over docs/loen/ — run the deterministic loen_stats.py aggregator (offline, stdlib-only, no LLM) and render the docs/loen/governance.html dashboard via the html-report skill. --triage additionally turns failing runs into proposed next actions for the human — proposals only, never launches loops, never edits runs.
---

# loen:governance — cross-run dashboard + triage proposals

Invoke as `/loen:governance [--triage]`. Aggregates the audit trail every loen run
already leaves under `docs/loen/` (`loop.yaml`, `state.md`,
`iterations/iter-NN/{gates.log,verifier.md}`, `experiments.jsonl`) into the ACROSS-runs
view the governance loop calls for. Offline-first: no network, no LLM in the aggregation.

## Steps

1. **Aggregate.** Run `python3 <skill-base>/../../scripts/loen_stats.py` (the skill base
   directory is printed when this skill is invoked; the script resolves `docs/loen/`
   from the CWD, `--root` overrides). Non-zero exit → abort and show the script's stderr
   verbatim. Parse the JSON from stdout; an empty summary (zero runs) is valid — render
   the dashboard anyway.
2. **Render `docs/loen/governance.html`** via the `html-report` skill (same flow
   `loen:audit` uses for `report.html`). Dashboard blocks per the methodology §10.3
   minimal table:
   - **Loop success rate** — `totals.success_rate` plus `totals.runs_by_mode` counts;
   - **Metric delta** (research runs) — per run with `research` extras:
     `research.primary`, `primary_first` → `primary_last`, keep/revert counts;
   - **Handoff reasons** — `totals.handoff_reasons`, verbatim;
   - **Failure taxonomy** — `totals.failure_taxonomy` (REJECT verdicts' numbered
     `REQUIRED FIXES:` items with occurrence counts);
   - **Protected-path alerts** — `totals.protected_alerts`;
   - **Layout drift** — the `foreign` list (direct children of `docs/loen/` that are
     neither run-ids nor the canon top-level set);
   - **Cost/tokens** and **Latency/VRAM** — always rendered as
     "n/a — loen artifacts carry no cost/token or inference-infra data"; never
     fabricate (latency appears only if a research run's eval recorded it as a metric).
   Self-contained single file, dark/light, opens by double-click.
3. **`--triage` variant** — additionally list every run whose `last_verdict` is
   `REJECT`, or `null` while `iterations > 0`. For each, give one line of evidence
   quoted from the artifacts (the REJECT's first `REQUIRED FIXES:` item, or
   "no verifier.md while iterations exist") and the suggested next action:
   - the failure names a failing command/test → propose
     `/loen:loop-repair <failing command>`;
   - anything else → propose "review contract/budget" for that run.
   Proposals ONLY — never launch loops, never edit runs, never auto-fix.

## Scheduling (optional, user-owned)

`/loop 30m /loen:governance --triage` re-runs triage this session; the recurring job is
session-scoped and dies with the session — re-arm it per session or use your own cron.

## Rules

- Read-only everywhere except exactly ONE write: `docs/loen/governance.html` (canonical
  top-level path — the loop-guard hook allows it).
- Restate what `loen_stats.py` reports; add no scores, never fabricate the unavailable
  rows.
````

- [ ] **Step 4: Bump the plugin version (0.4.0 → 0.5.0, lockstep)**

In `plugin/loen/.claude-plugin/plugin.json`, old:
```json
  "version": "0.4.0",
```
New:
```json
  "version": "0.5.0",
```

In `.claude-plugin/marketplace.json` (inside the `"name": "loen"` entry), old:
```json
      "version": "0.4.0",
```
New:
```json
      "version": "0.5.0",
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
bash tests/test_loen_plugin.sh && bash scripts/check-plugin-version-sync.sh && echo VERSION-SYNC-OK
```
Expected: `OK skill governance` among the lint lines, `PASS test_loen_plugin.sh`, then `VERSION-SYNC-OK`.

- [ ] **Step 6: Commit**

```bash
git add plugin/loen/skills/governance/SKILL.md tests/test_loen_plugin.sh plugin/loen/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat(loen): /loen:governance skill + plugin 0.5.0"
```

---

### Task 4: Docs — LOEN.md, plugin README, root README, iwiki

**Files:**
- Modify: `docs/functions/LOEN.md` (Use section, Artifacts section, Scope section)
- Modify: `plugin/loen/README.md`
- Modify: `README.md` (root, Russian — Loop Engineering section, ~lines 320-348)
- Modify: iwiki `iclaude/loen-plugin` (sections `Components`, `Artifact model`, `Roadmap and backlog`) via the iwiki MCP tools

**Interfaces:**
- Consumes: shipped surfaces from Tasks 1-3 (`loen_stats.py` CLI + JSON fields, `/loen:governance [--triage]`, top-level canon `governance.html`, plugin 0.5.0).
- Produces: the docs leg of the canon-set two-way sync (spec §4: hook + docs layout table); the documented handoff/stop line pin workers must follow.

- [ ] **Step 1: `docs/functions/LOEN.md` — three edits**

Edit 1 — Use section, add after the `/loen:loop-goal` bullet:

```markdown
- `/loen:governance [--triage]` — cross-run governance: the deterministic
  `scripts/loen_stats.py` aggregates every run under `docs/loen/` (success rate,
  keep/revert, handoff reasons, failure taxonomy from REJECT verdicts' numbered
  `REQUIRED FIXES:` items, protected-path alerts, layout-drift `foreign` list) and the
  skill renders the `docs/loen/governance.html` dashboard via `html-report`. The §10.3
  rows loen artifacts cannot back — cost/tokens and latency/VRAM — are explicitly n/a,
  never fabricated. `--triage` lists failing runs (last verdict REJECT, or absent while
  iterations exist) with proposed next actions (`/loen:loop-repair <failing command>`
  for repair-shaped failures; "review contract/budget" otherwise) — proposals only, the
  human executes. Offline-first: no network, no LLM in the aggregation.
```

Edit 2 — Artifacts section, add after the paragraph that ends "...It is a no-op in non-loop repos.":

```markdown
Cross-run (top level, outside run dirs): `docs/loen/governance.html` — the governance
dashboard `/loen:governance` renders from `scripts/loen_stats.py` output. It joins
`current` and `RUNBOOK.md` in the hook's top-level canon set (early allow guard +
`canon_patterns()` entry; this Artifacts entry is the second leg of the canon sync —
`check_layout.sh` is unaffected because it validates inside one run dir). The
aggregator picks up handoff/stop reasons from `state.md` `## Attempts` lines of the
form `- handoff: <reason>` / `- stop: <reason>`.
```

Edit 3 — Scope section. Old:

```markdown
Shipped: delivery (`loop-delivery`), repair (`loop-repair`), research
(`loop-autoresearch`), verifier, guard, `/goal`+`/loop` wrapping (`loop-goal` +
`make_goal.py`), opt-in verifier microVM isolation (`verifier_isolation: microvm`).
Governance/observability is a later increment.
```

New:

```markdown
Shipped: delivery (`loop-delivery`), repair (`loop-repair`), research
(`loop-autoresearch`), verifier, guard, `/goal`+`/loop` wrapping (`loop-goal` +
`make_goal.py`), opt-in verifier microVM isolation (`verifier_isolation: microvm`),
governance/observability (`/loen:governance` + `loen_stats.py` →
`docs/loen/governance.html`).
```

- [ ] **Step 2: `plugin/loen/README.md` — one bullet**

Add after the `verifier_isolation: microvm` bullet (before the closing "All results live under..." paragraph):

```markdown
- `/loen:governance [--triage]` — cross-run governance: the deterministic offline
  `scripts/loen_stats.py` aggregation over `docs/loen/` rendered as the
  `docs/loen/governance.html` dashboard (success rate, metric delta, handoff reasons,
  failure taxonomy, protected-path alerts, layout drift; cost/tokens and latency/VRAM
  explicitly n/a). `--triage` proposes next actions for failing runs — proposals only,
  never executes.
```

- [ ] **Step 3: Root `README.md` (Russian) — two edits in the "Loop Engineering (loen)" section**

Edit 1 — add to the command code block after the `/loen:loop-goal` line:

```
/loen:governance [--triage]        # кросс-run дашборд docs/loen/governance.html (offline-агрегатор loen_stats.py); --triage только предлагает действия
```

Edit 2 — add a paragraph after the "**Изоляция верификатора (opt-in):** ..." paragraph and before "Подробнее:":

```markdown
**Governance (кросс-run):** `/loen:governance` строит дашборд
`docs/loen/governance.html` детерминированным офлайн-агрегатором `loen_stats.py`
(success rate, keep/revert, причины остановок, таксономия ошибок из REJECT-вердиктов,
алерты protected-путей, дрейф раскладки; cost/tokens и latency/VRAM — явно n/a, без
выдумывания). Всё локально: без сети и без LLM в агрегации; `--triage` только
предлагает следующие действия — запускает их человек.
```

- [ ] **Step 4: Verify the doc inserts landed**

Run:
```bash
grep -c "loen:governance" docs/functions/LOEN.md plugin/loen/README.md README.md && grep -n "governance.html" docs/functions/LOEN.md | head -5
```
Expected: non-zero counts for all three files; LOEN.md shows the Use bullet + Artifacts paragraph + Scope line.

- [ ] **Step 5: iwiki `iclaude/loen-plugin` — three section updates (MCP tools only)**

First `wiki_read_page(domain="iclaude", slug="loen-plugin")` to get the current body. Then three `wiki_update_page(domain="iclaude", slug="loen-plugin", heading=..., new_body=..., source="plugin/loen/scripts/loen_stats.py")` calls, each preserving the existing section body verbatim and applying only the listed change:

1. `heading="Components"` — append two bullets at the end of the list:

```markdown
- `scripts/loen_stats.py` — deterministic cross-run governance aggregator (new in 0.5.0): scans `docs/loen/` direct children (run-id regex = the hook's; canon top-level set `current`/`RUNBOOK.md`/`governance.html` silently accepted; everything else listed as `foreign` layout drift) and emits ONE JSON summary on stdout — per run: `mode`, iteration count, `last_verdict` (pinned `VERDICT:` line of the latest `verifier.md`), `gates.log` presence, research extras from `experiments.jsonl` (experiment/keep/revert counts, primary-metric first/last); totals: runs-by-mode, loop success rate (final iteration APPROVE), keep/revert, handoff/stop reasons (`- handoff:|stop: <reason>` lines in `state.md` Attempts), failure taxonomy (REJECT verdicts' numbered `REQUIRED FIXES:` items; `gates.log` deliberately not parsed), protected alerts (`^ERROR: protected path changed:` count), and `cost_tokens`/`latency_vram` = `"unavailable"` (never fabricated). stdlib-only, read-only, no network; empty/missing root → valid empty summary, exit 0.
- `skills/governance/SKILL.md` — `/loen:governance [--triage]` (new in 0.5.0): runs `loen_stats.py`, renders the `docs/loen/governance.html` dashboard via the `html-report` skill (§10.3 blocks; cost/tokens + latency/VRAM rendered as n/a); `--triage` lists runs whose last verdict is REJECT or absent-with-iterations, each with one evidence quote and a proposed next action (`/loen:loop-repair <failing command>` or "review contract/budget") — proposals only, never launches loops, never edits runs; scheduling stays user-owned (one-line `/loop` recipe + session-durability caveat). Exactly one write: `docs/loen/governance.html`.
```

2. `heading="Artifact model"` — append one sentence to the paragraph that describes the canonical set / top-level allow-list:

```markdown
0.5.0 grew the canon set by exactly one TOP-LEVEL path: `docs/loen/governance.html` (the governance dashboard), allowed by an EARLY `path ==` guard in the hook (the run-id gate makes `canon_patterns()` unreachable for top-level files) with a `canon_patterns()` entry + block-message line for symmetry; `check_layout.sh` is unaffected (it validates inside one run dir).
```

3. `heading="Roadmap and backlog"` — update backlog table row 4 `Status` from `spec drafted (PR #78, pending review)` to `done (0.5.0, PR pending)` and append one sentence to the prose:

```markdown
Increment 4 (backlog step 4) shipped (plugin 0.5.0): offline-first governance/observability — deterministic `loen_stats.py` aggregator + `/loen:governance` dashboard/triage skill + top-level canonical `governance.html`; Langfuse export explicitly deferred; chain `loen-governance-observability` tracked in `docs/TODO.md`.
```

Then run `wiki_lint` — expect no broken refs / orphans for the domain.

- [ ] **Step 6: Commit**

```bash
git add docs/functions/LOEN.md plugin/loen/README.md README.md
git commit -m "docs(loen): governance/observability — LOEN.md, plugin README, root README"
```

---

### Task 5: Full regression sweep

**Files:**
- No new files; runs every loen suite + the version-sync guard.

**Interfaces:**
- Consumes: everything shipped in Tasks 1-4.
- Produces: green evidence for the PR / `/check-chain result`.

- [ ] **Step 1: Run all loen suites**

Run:
```bash
python3 tests/test_loen_stats.py && python3 tests/test_loen_hook.py && python3 tests/test_loen_experiment.py && python3 tests/test_loen_goal.py && bash tests/test_loen_guard.sh && bash tests/test_loen_layout.sh && bash tests/test_loen_templates.sh && bash tests/test_loen_plugin.sh && bash tests/test_loen_verify_microvm.sh && bash scripts/check-plugin-version-sync.sh && echo ALL-GREEN
```
Expected: every suite prints its PASS line, then `ALL-GREEN`.

- [ ] **Step 2: Smoke the aggregator against the real repo root**

Run:
```bash
python3 plugin/loen/scripts/loen_stats.py | python3 -m json.tool > /dev/null && echo JSON-OK
```
Expected: `JSON-OK` (the repo's `docs/loen/` is currently empty — a valid empty summary must parse; exit 0).

- [ ] **Step 3: Commit (only if fixes were needed)**

If Steps 1-2 required source changes, re-run both steps to green, then:
```bash
git add -A -- plugin/loen tests
git commit -m "fix(loen): governance regression fixes"
```
If nothing changed, no commit — the sweep is evidence, not a diff.

---

## Self-Review

1. **Spec coverage:** §2 aggregator (input/scan/output/fidelity/stdlib) → Task 1; §3 skill (aggregate/render/triage/one-write/scheduling recipe) → Task 3; §4 hook (early guard operative + canon symmetry + block message, `check_layout.sh` untouched) → Task 2; §5 privacy → Global Constraints (no network anywhere, enforced by construction — stdlib file I/O only); §6 delivery (0.5.0 lockstep) → Task 3; §7 testing (stats fixtures incl. success rate 0.5, keep/revert, primary first/last, taxonomy, protected alert 1, foreign dir+file, canon excluded, empty root; hook allow/block cases; plugin lint + version sync) → Tasks 1-3; §9 process obligations (LOEN.md Use+Artifacts, plugin README, root README RU, iwiki Components/Artifact model/Roadmap) → Task 4; `docs/TODO.md` stays `/check-chain`-driven (Global Constraints). No gaps found.
2. **Placeholder scan:** all steps carry complete code/commands; the only intentionally unpinned content is the HTML dashboard markup (produced by the `html-report` skill at runtime — agentic by design, matching how `loen:audit` produces `report.html`) and the iwiki section bodies (read-modify-write with exact insert text given).
3. **Type consistency:** JSON field names used by the skill (Task 3) and docs (Task 4) — `last_verdict`, `gates_log`, `research.{experiments,keep,revert,primary,primary_first,primary_last}`, `totals.{runs_by_mode,success_rate,keep,revert,handoff_reasons,failure_taxonomy,protected_alerts,cost_tokens,latency_vram}`, `foreign` — match Task 1's implementation and test asserts verbatim. Hook guard string `docs/loen/governance.html` matches the test paths and the canon regex `^docs/loen/governance\.html$`.
