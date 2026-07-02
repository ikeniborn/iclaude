---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-02-loen-repair-autoresearch-design.md
review:
  plan_hash: 7b470086758ff5dd
  last_run: 2026-07-02
  runner: "clean-context subagent (check-runner protocol)"
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings: []
  verdict: OK
---
# loen spec 2 — loop-repair + loop-autoresearch — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two loop specializations (`loop-repair`, `loop-autoresearch`) to the shipped `loen` plugin as pure specializations over the existing MVP loop machinery, plus a deterministic `experiments.jsonl` writer, one new canonical path, mode-aware audit checks, and the confirmed subagent model roster.

**Architecture:** Both skills reuse the MVP run layout `docs/loen/<run-id>/`, the `loop.yaml` contract, `loen:audit` stage gates, the `planner`/`explorer`/`verifier` subagents, `loop-guard.py`, `guard_protected.sh`, and `check_layout.sh`. Each skill adds only its own cycle and rules via its SKILL.md (mode-specific behavior rides dispatch prompts, never agent-body edits). Research metrics travel as JSONL event streams: `iterations/iter-NN/metrics.jsonl` (eval output via `$LOEN_METRICS_PATH`) and `experiments.jsonl` (run stream, appended only by `log_experiment.py`).

**Tech Stack:** Bash + Python 3 (stdlib only), Claude Code plugin format (SKILL.md / agents frontmatter / hooks), flat `tests/` shell+python suites (each test is a standalone executable script).

**Spec:** `docs/superpowers/specs/2026-07-02-loen-repair-autoresearch-design.md`

**Branch:** `dev-loen-repair-autoresearch`. The repo has a long-lived `dev` branch besides `master` — per CLAUDE.md, confirm with the user at execution start which branch to base off and where the PR targets (MVP shipped via PR #72; recent `dev-*` PRs merged to `master`). Also ask whether to create worktree `wk-dev-loen-repair-autoresearch` (mandatory question per CLAUDE.md).

## Global Constraints

- Plugin version **0.1.0 → 0.2.0** in BOTH `plugin/loen/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (enforced by `scripts/check-plugin-version-sync.sh` and `tests/test_loen_plugin.sh`).
- **Zero new hard dependencies; zero new subagents.** Publishable posture unchanged.
- Canonical path set grows by **exactly one**: `docs/loen/<R>/iterations/iter-NN/metrics.jsonl`, synced **three-way**: `loop-guard.py` `canon_patterns()` + its human-facing block message, `scripts/check_layout.sh` case list, layout table in `docs/functions/LOEN.md`.
- New optional `loop.yaml` keys: `eval_command: ""` and `budget.max_experiments: 5` — present in the template with trailing comments, NOT commented out (template must still parse; `tests/test_loen_templates.sh` guards this).
- Shared assets: new skills resolve templates via `<skill-base>/../loop-delivery/assets/` — **no copies**. Bootstrap contract is REFERENCED from `loop-delivery/SKILL.md` steps 1–3, not re-authored.
- Subagent roster (user-confirmed): planner=`fable`, verifier=`opus`, explorer=`haiku` (unchanged). Only frontmatter `model:` lines change; agent bodies stay mode-blind.
- `state.template.md` is deliberately **unchanged**.
- Planner dispatch prompts MUST demand block-style YAML scope lists (`guard_protected.sh` parses block-style only).
- Docs and code comments in English; root `README.md` section stays Russian (repo README is RU).
- Commit convention: conventional commits (`feat(loen): …`, `test(loen): …`, `docs(loen): …`, `chore(loen): …`).
- Tests run standalone: `python3 tests/test_X.py`, `bash tests/test_X.sh` from repo root.

---

### Task 1: `log_experiment.py` — deterministic experiments.jsonl writer

**Files:**
- Create: `plugin/loen/scripts/log_experiment.py`
- Test: `tests/test_loen_experiment.py`

**Interfaces:**
- Consumes: nothing (stdlib only).
- Produces CLI used by `loop-autoresearch/SKILL.md` (Task 6) and referenced by `audit/SKILL.md` (Task 7):
  - `python3 plugin/loen/scripts/log_experiment.py <target.jsonl> '<json-record>'` — record as argv[2], OR
  - `echo '<json-record>' | python3 plugin/loen/scripts/log_experiment.py <target.jsonl>` — record on stdin.
  - Exit 0: exactly one compact JSON line appended to `<target.jsonl>`. Exit 1: rejected, target untouched, reason on stderr.
  - Required keys by `type`: `baseline` → `type, ts, eval_command, metrics`; `experiment` → `type, ts, iter, hypothesis, files_changed, eval_command, metrics_before, metrics_after, delta, decision, risks, next_hypothesis`. `decision` ∈ `keep|revert`; `iter` matches `^iter-\d{2}$`; `metrics_after` may be `null` (failed-eval record, spec §8); extra keys (e.g. `predicted`) are allowed.

- [ ] **Step 1: Write the failing test**

Create `tests/test_loen_experiment.py`:

```python
#!/usr/bin/env python3
"""Unit tests for log_experiment.py — the deterministic experiments.jsonl writer.
Exit 0 = exactly one line appended; exit 1 = rejected, target untouched."""
import json, os, subprocess, sys, tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, "plugin", "loen", "scripts", "log_experiment.py")

BASELINE = {"type": "baseline", "ts": "2026-07-02T10:00:00Z",
            "eval_command": "make eval", "metrics": {"acc": 0.81}}
EXPERIMENT = {"type": "experiment", "ts": "2026-07-02T11:00:00Z", "iter": "iter-01",
              "hypothesis": "larger retrieval window improves acc",
              "files_changed": ["src/retrieval.py"], "eval_command": "make eval",
              "metrics_before": {"acc": 0.81}, "metrics_after": {"acc": 0.84},
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
python3 tests/test_loen_experiment.py
```

Expected: FAIL (every case fails — `log_experiment.py` does not exist, subprocess returncode is 2 from Python "can't open file").

- [ ] **Step 3: Write the implementation**

Create `plugin/loen/scripts/log_experiment.py`:

```python
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

REQUIRED = {
    "baseline": ["type", "ts", "eval_command", "metrics"],
    "experiment": ["type", "ts", "iter", "hypothesis", "files_changed",
                   "eval_command", "metrics_before", "metrics_after", "delta",
                   "decision", "risks", "next_hypothesis"],
}
ITER = re.compile(r"^iter-\d{2}$")


def fail(msg):
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
        # metrics_after / delta may be null on a failed eval (recorded, reverted)
        if rec["metrics_after"] is not None and not isinstance(rec["metrics_after"], dict):
            fail("metrics_after must be an object or null")
    with open(target, "a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run test to verify it passes**

```bash
python3 tests/test_loen_experiment.py
```

Expected: `PASS test_loen_experiment.py`

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/scripts/log_experiment.py tests/test_loen_experiment.py
git commit -m "feat(loen): add log_experiment.py deterministic experiments.jsonl writer"
```

---

### Task 2: Hook — `metrics.jsonl` becomes canonical (`loop-guard.py`)

**Files:**
- Modify: `plugin/loen/hooks/loop-guard.py:32` (canon_patterns) and `plugin/loen/hooks/loop-guard.py:121-125` (block message)
- Test: `tests/test_loen_hook.py`

**Interfaces:**
- Consumes: existing hook contract (stdin JSON `tool_input.file_path`; exit 0 allow / 2 block).
- Produces: `docs/loen/<R>/iterations/iter-NN/metrics.jsonl` allowed by the PreToolUse guard; block message lists it. Tasks 3, 6, 9 rely on this path being canonical.

- [ ] **Step 1: Add the failing test cases**

In `tests/test_loen_hook.py`, after the existing "bad iter name" check (line ~62), insert:

```python
        # research mode: canonical per-iteration metrics stream -> allow
        check("canonical iter metrics.jsonl",
              run(root, os.path.join(base, "iterations/iter-03/metrics.jsonl")), 0)
        # malformed iter segment with metrics.jsonl -> block
        check("bad iter metrics.jsonl",
              run(root, os.path.join(base, "iterations/iter-3/metrics.jsonl")), 2)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
python3 tests/test_loen_hook.py
```

Expected: `FAIL test_loen_hook.py` with `canonical iter metrics.jsonl: got exit 2, want 0` (the "bad iter" case already blocks — only the allow case fails).

- [ ] **Step 3: Extend the canonical set + block message**

In `plugin/loen/hooks/loop-guard.py` replace the iter-file pattern (line 32):

```python
        re.compile(rf"^docs/loen/{Rq}/iterations/iter-\d{{2}}/(diff\.patch|gates\.log|verifier\.md|metrics\.jsonl)$"),
```

And the block message (lines 121–125):

```python
        block(
            f"non-canonical loen artifact path: {path}\n"
            f"  expected: docs/loen/{R}/{{loop.yaml,plan.md,state.md,pr-summary.md,report.html,experiments.jsonl}}\n"
            f"  or:       docs/loen/{R}/iterations/iter-NN/{{diff.patch,gates.log,verifier.md,metrics.jsonl}}"
        )
```

- [ ] **Step 4: Run test to verify it passes**

```bash
python3 tests/test_loen_hook.py
```

Expected: `PASS test_loen_hook.py`

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/hooks/loop-guard.py tests/test_loen_hook.py
git commit -m "feat(loen): allow canonical iterations/iter-NN/metrics.jsonl in loop-guard"
```

---

### Task 3: Layout validator — `metrics.jsonl` case (`check_layout.sh`)

**Files:**
- Modify: `plugin/loen/scripts/check_layout.sh:16-22` (case list)
- Test: `tests/test_loen_layout.sh`

**Interfaces:**
- Consumes: existing CLI `check_layout.sh [run-dir]`, exit 0 OK / 1 non-canonical.
- Produces: canonical acceptance of `iterations/iter-NN/metrics.jsonl`; stray `metrics.json` still rejected. Second leg of the three-way sync (hook = Task 2, docs = Task 9).

- [ ] **Step 1: Add the failing test cases**

In `tests/test_loen_layout.sh`, after the first canonical acceptance check (line 12) and BEFORE the `scratch.txt` case, insert:

```bash
: > "$run/iterations/iter-01/metrics.jsonl"   # research metrics stream (canonical)
bash "$chk" "$run" || { echo "FAIL: rejected canonical metrics.jsonl" >&2; exit 1; }
: > "$run/iterations/iter-01/metrics.json"    # wrong extension (non-canonical)
if bash "$chk" "$run"; then echo "FAIL: accepted non-canonical metrics.json" >&2; exit 1; fi
rm "$run/iterations/iter-01/metrics.json"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_loen_layout.sh
```

Expected: `FAIL: rejected canonical metrics.jsonl` (exit 1).

- [ ] **Step 3: Add the canonical case**

In `plugin/loen/scripts/check_layout.sh`, in the `case "$rel" in` block, after the `verifier.md` line add:

```bash
    iterations/iter-[0-9][0-9]/metrics.jsonl) ;;
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_loen_layout.sh
```

Expected: `PASS test_loen_layout.sh`

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/scripts/check_layout.sh tests/test_loen_layout.sh
git commit -m "feat(loen): accept iterations/iter-NN/metrics.jsonl in check_layout.sh"
```

---

### Task 4: Contract template — `eval_command` + `budget.max_experiments`

**Files:**
- Modify: `plugin/loen/skills/loop-delivery/assets/loop.template.yaml`
- Test: `tests/test_loen_templates.sh`

**Interfaces:**
- Consumes: existing template schema (Task list in `tests/test_loen_templates.sh` `required`).
- Produces: `eval_command` (top-level string) and `budget.max_experiments` (int, default 5) — keys present with trailing comments, NOT commented out; template still parses. Planner dispatch prompts in Tasks 5–6 and audit checks in Task 7 reference these exact key names.

- [ ] **Step 1: Add the failing assertions**

In `tests/test_loen_templates.sh`, inside the embedded Python block after the existing `budget` assertion, add:

```python
assert "eval_command" in d, "loop.template.yaml missing eval_command"
assert "max_experiments" in d["budget"], "budget missing max_experiments"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_loen_templates.sh
```

Expected: FAIL with `AssertionError: loop.template.yaml missing eval_command`.

- [ ] **Step 3: Add the keys to the template**

In `plugin/loen/skills/loop-delivery/assets/loop.template.yaml`:

After the `quality_gates` line add:

```yaml
eval_command: ""            # research mode: fixed eval; appends JSONL to $LOEN_METRICS_PATH (empty in delivery/repair)
```

In the `budget:` block, after `max_iterations: 3` add:

```yaml
  max_experiments: 5        # research mode budget (governs instead of max_iterations there)
```

Resulting fragment:

```yaml
quality_gates: []           # commands that must exit 0 (verifiers)
eval_command: ""            # research mode: fixed eval; appends JSONL to $LOEN_METRICS_PATH (empty in delivery/repair)
metrics:
  primary: []
  secondary: []
budget:
  max_iterations: 3
  max_experiments: 5        # research mode budget (governs instead of max_iterations there)
  max_wall_time_minutes: 90
  max_cost_usd: 5
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_loen_templates.sh
```

Expected: `PASS test_loen_templates.sh`

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/skills/loop-delivery/assets/loop.template.yaml tests/test_loen_templates.sh
git commit -m "feat(loen): add eval_command and budget.max_experiments to loop.yaml template"
```

---

### Task 5: `loop-repair` skill

**Files:**
- Create: `plugin/loen/skills/loop-repair/SKILL.md`
- Modify: `tests/test_loen_plugin.sh:49` (skill lint list)

**Interfaces:**
- Consumes: `loop-delivery/SKILL.md` steps 1–3 (bootstrap contract, referenced not copied); shared assets at `<skill-base>/../loop-delivery/assets/`; `loen:audit` stages.
- Produces: skill `loop-repair` (frontmatter `name: loop-repair`), invoked as `/loen:loop-repair <failure description>`. Task 7's repair-mode audit checks assume: failing command recorded in `state.md` Baseline at bootstrap; inversion evidence format in `gates.log`.

- [ ] **Step 1: Extend the skill lint (failing test)**

In `tests/test_loen_plugin.sh` change the skill loop list:

```bash
for s in loop-delivery audit loop-repair; do
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_loen_plugin.sh
```

Expected: `FAIL: missing skill plugin/loen/skills/loop-repair/SKILL.md` (exit 1).

- [ ] **Step 3: Write the skill**

Create `plugin/loen/skills/loop-repair/SKILL.md`:

```markdown
---
name: loop-repair
description: Fix one failing test / CI job / regression as a controlled loop — reproduce first, isolate, minimal fix, regression test — reusing the loen loop machinery; artifacts under docs/loen/<run-id>/.
---

# Loop Repair (mode: repair)

Fix ONE failing test / CI / regression through the cycle
`failure → reproduce → isolate → minimal fix → regression test`. You are the **worker**
and the **only writer**. This skill is a specialization of `loop-delivery`: same run
layout, contract, audit gates, subagents, and hook. Shared templates live at
`<skill-base>/../loop-delivery/assets/` (single source — never copy them).

## Steps

1. **Bootstrap** — identical to `loop-delivery` steps 1–3, with these deltas:
   - `mode: repair` in `loop.yaml`.
   - **Record the failing command** (from the user's invocation — the source of truth) in
     the Baseline section of `docs/loen/<run-id>/state.md` BEFORE `loen:audit plan`; the
     plan stage deterministically checks that this recorded command appears among
     `quality_gates`.
   - The `planner` dispatch prompt MUST instruct: `mode: repair`; a NARROW `mutable_scope`
     (the failing area + its tests); the recorded failing command among `quality_gates`;
     block-style YAML scope lists (`guard_protected.sh` parses block-style only); leave
     `eval_command` empty.
2. **Human approval gate**, then **`loen:audit plan`** — must return `OK` before any edit.
3. **Reproduce first (iter-01).** BEFORE any edit, run the failing command; capture output
   + exit code into `docs/loen/<run-id>/iterations/iter-01/gates.log`. For a suspected
   flaky failure run the command up to 3 times (attempts recorded in `state.md`); any
   failing run counts as reproduced. **No reproduction → stop and report** — never "fix"
   what cannot be reproduced.
4. **Isolate + minimal fix.** The smallest diff that makes the failing command pass. Save
   `iterations/iter-NN/diff.patch` (`git diff > …`, `iter-NN` zero-padded). Every non-test
   hunk must be required for the failing command to pass; tests change only by ADDING the
   regression test. Use `explorer` for code evidence without loading files here.
5. **Regression coverage.** Either (a) a new/extended test in the diff, or (b) the
   originally-failing test IS the regression test. For case (a) YOU (the worker — the
   verifier stays read-only) produce inversion evidence into `gates.log`:
   `git stash push -- <fix files>` → run the regression test (must FAIL) →
   `git stash pop` → run it again (must PASS).
6. **Check.** Run the `quality_gates` into `iterations/iter-NN/gates.log`, then run
   **`loen:audit check`** — it dispatches the `verifier` and writes
   `iterations/iter-NN/verifier.md`.
7. **Fix.** Address only verifier-confirmed issues. Repeat Act→Check within
   `budget.max_iterations` (default 3 — the methodology default for repair).
8. **Report.** On green gates + verifier APPROVE run **`loen:audit result`**.
   `pr-summary.md` MUST state the root cause and a rollback note.

## Done condition (gated by `loen:audit result`)

1. The originally-failing command exits 0 (evidence in the final `gates.log`).
2. Regression coverage evidenced — case (a) new/extended test with logged inversion
   evidence, or case (b) the originally-failing test itself; the verifier states which
   case applies.
3. The diff is minimal — no test changes except the added regression test; every non-test
   hunk required for the originally-failing command to pass.
4. Verifier `APPROVE`.

## Stop conditions

- The failure does not reproduce → stop BEFORE any edit, report.
- `budget.max_iterations` exhausted → stop; report root-cause analysis, best attempt, and
  the blocker.
- Any `handoff_conditions` trigger → hard stop, ask the human. Never auto-merge.

No new artifacts: `iterations/iter-NN/{diff.patch,gates.log,verifier.md}` suffice. The
research streams (`metrics.jsonl`, `experiments.jsonl`) are simply absent in repair — the
hook allows them, no audit stage requires or reads them.
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_loen_plugin.sh
```

Expected: `OK skill loop-repair` … `PASS test_loen_plugin.sh`

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/skills/loop-repair/SKILL.md tests/test_loen_plugin.sh
git commit -m "feat(loen): add loop-repair skill (mode: repair)"
```

---

### Task 6: `loop-autoresearch` skill

**Files:**
- Create: `plugin/loen/skills/loop-autoresearch/SKILL.md`
- Modify: `tests/test_loen_plugin.sh:49` (skill lint list)

**Interfaces:**
- Consumes: `loop-delivery/SKILL.md` steps 1–3 (referenced); assets at `<skill-base>/../loop-delivery/assets/`; `log_experiment.py` CLI (Task 1); canonical `metrics.jsonl` path (Tasks 2–3); template keys `eval_command` / `budget.max_experiments` (Task 4).
- Produces: skill `loop-autoresearch` (frontmatter `name: loop-autoresearch`), invoked as `/loen:loop-autoresearch <metric goal>`. Task 7's research-mode audit checks assume the record shapes and the `LOEN_METRICS_PATH` mechanism exactly as written here.

- [ ] **Step 1: Extend the skill lint (failing test)**

In `tests/test_loen_plugin.sh` change the skill loop list:

```bash
for s in loop-delivery audit loop-repair loop-autoresearch; do
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_loen_plugin.sh
```

Expected: `FAIL: missing skill plugin/loen/skills/loop-autoresearch/SKILL.md` (exit 1).

- [ ] **Step 3: Write the skill**

Create `plugin/loen/skills/loop-autoresearch/SKILL.md`:

```markdown
---
name: loop-autoresearch
description: Improve one numeric metric as a controlled research loop — baseline, hypothesis, one bounded change, fixed eval, compare, keep/revert — logging every experiment as JSONL events; reuses the loen loop machinery.
---

# Loop AutoResearch (mode: research)

Improve ONE numeric metric through the cycle
`baseline → hypothesis → one bounded change → fixed eval → compare → keep/revert`.
You are the **worker** and the **only writer**. This skill is a specialization of
`loop-delivery`: same run layout, contract, audit gates, subagents, and hook. Shared
templates live at `<skill-base>/../loop-delivery/assets/` (single source — never copy).

## Bootstrap + contract

1. **Bootstrap** — identical to `loop-delivery` steps 1–3, with these deltas:
   - `mode: research` in `loop.yaml`.
   - The loop starts from a **clean committed tree** — uncommitted user changes → stop
     and ask (as MVP).
   - The `planner` dispatch prompt MUST instruct: fill `eval_command` (the fixed eval
     command that appends JSONL to `$LOEN_METRICS_PATH`); exactly ONE `metrics.primary`
     entry of the form `<name>:max` or `<name>:min`; a direction (`<name>:max|min`) on
     every `metrics.secondary` entry; one `target: <primary-name> <op> <number>` line
     (`<op>` ∈ `>=`/`<=` matching the direction) and `tolerance: <name> regression <=
     <number>[%]` lines in `stop_conditions`; the eval assets (eval script, datasets,
     ground truth) into `protected_scope`; `budget.max_experiments`; block-style YAML
     scope lists (`guard_protected.sh` parses block-style only).
2. **Eval-contract compliance is a pre-loop responsibility.** `eval_command` MUST append
   JSON Lines to `$LOEN_METRICS_PATH`: free typed events plus exactly one authoritative
   line `{"type": "summary", "metrics": {"<name>": <number>, ...}}`. Adapting an existing
   eval happens BEFORE contract approval — the sanctioned adapter is a thin wrapper
   command living OUTSIDE `protected_scope`; the real eval script and data stay protected.
3. **Human approval gate**, then **`loen:audit plan`** — must return `OK` (research plan
   checks: see Hard rules).

## Cycle (one experiment = one `iter-NN`; `max_iterations` is ignored in research mode)

4. **Baseline (`iter-00` — reserved; experiments start at `iter-01`).** BEFORE any change:
   `export LOEN_METRICS_PATH=docs/loen/<run-id>/iterations/iter-00/metrics.jsonl`, run
   `eval_command` once. It MUST exit 0 and yield exactly one `summary` line — this run IS
   the eval-contract compliance check; otherwise STOP and report (broken/non-compliant
   eval; zero experiments run). Log it as the first `experiments.jsonl` record via
   `log_experiment.py` (`type: baseline`). No separate baseline file — the baseline is an
   event in the stream.
5. **Hypothesis.** ONE hypothesis with a predicted metric movement and risk; record it in
   `state.md` (optionally as the record's `predicted` field).
6. **One bounded change.** The smallest diff testing that hypothesis — one main variable
   per experiment. Capture the diff BEFORE the keep/revert decision executes:
   `git diff HEAD -- . ':(exclude)docs/loen' > docs/loen/<run-id>/iterations/iter-NN/diff.patch`
   (HEAD always equals the last kept state; run artifacts are excluded, so streams and
   logs survive reverts).
7. **Fixed eval + gates.** Run the contract's `quality_gates` (including
   `guard_protected.sh`) into `iterations/iter-NN/gates.log` — correctness and the
   protected-data guard fire on EVERY experiment. Then
   `export LOEN_METRICS_PATH=docs/loen/<run-id>/iterations/iter-NN/metrics.jsonl` and run
   `eval_command` (fixed command, dataset, seed, and model version; any deviation from
   the fixed setup MUST be logged in the experiment record).
8. **Compare + decide.** `metrics_before` = the metrics of the last KEPT state (the
   baseline while nothing is kept). KEEP iff gates are green AND the single primary
   metric improves in its declared direction AND no secondary regresses beyond its
   declared tolerance (a secondary WITHOUT a tolerance line = no regression allowed).
   A tie on the primary is NOT an improvement → revert.
   - **KEEP** → commit the kept change so HEAD equals the last kept state:
     `git add <files_changed> && git commit -m "loen(research): keep iter-NN — <short hypothesis>"`.
   - **REVERT** → `git apply -R docs/loen/<run-id>/iterations/iter-NN/diff.patch` — the
     deterministic inverse of exactly this experiment's change. The reverted experiment's
     `diff.patch` is never deleted (evidence). Failed experiments are logged, never
     silently discarded — they are useful data.
9. **Audit + log.** Run **`loen:audit check`** (for `keep` decisions the verifier re-runs
   `eval_command` against a throwaway `LOEN_METRICS_PATH`). Append the experiment record
   via `log_experiment.py` — NEVER hand-edit the stream — update `state.md`, then next
   hypothesis or stop.
10. **Report.** On success or budget exhaustion run **`loen:audit result`** — kept changes
    must be metric-backed; `report.html` gains the experiments table.

## Record shapes (`experiments.jsonl`, run root)

- `{"type": "baseline", "ts": ..., "eval_command": ..., "metrics": {...}}`
- `{"type": "experiment", "ts": ..., "iter": "iter-NN", "hypothesis": ...,
   "files_changed": [...], "eval_command": ..., "metrics_before": {...},
   "metrics_after": {...}, "delta": {...}, "decision": "keep"|"revert",
   "risks": ..., "next_hypothesis": ...}` — plus optional `predicted`
   (`{"<name>": <number>}`, the hypothesis' predicted movement).

## Hard rules (checked at `loen:audit plan` / by the verifier)

- One main variable per experiment.
- EXACTLY ONE `metrics.primary` entry `<name>:max|min` (`<name>` matches a key in the
  eval `summary.metrics`). Multi-objective research is out of scope — a composite metric
  computed by the eval script is the supported form.
- `stop_conditions` MUST contain one `target: <primary-name> <op> <number>` line;
  reaching it stops the run successfully BEFORE `max_experiments`.
- Secondary tolerances are `tolerance: <name> regression <= <number>[%]` lines — relative
  to `metrics_before`, direction from `<name>:max|min` in `metrics.secondary`.
- Eval data, ground truth, and the eval script are `protected_scope`; `loen:audit plan`
  FAILS a research contract whose `protected_scope` does not cover them.
- Never improve metrics by weakening validation, eval data, or the eval script (unless
  the task IS eval design — then it must be the explicit objective).
- Keep seed, model version, eval command, and dataset fixed when possible.
- **Budget:** `budget.max_experiments` (default 5) counts experiments; exhausted → stop,
  report the best kept state and the full experiment log.

## Error handling

- `eval_command` fails in an experiment (non-zero exit / no `summary` line) → record it
  as failed (`decision: revert`, `metrics_after: null`), revert the change; never counted
  as a keep. TWO consecutive eval failures → stop, report (broken eval ≠ research).
- `log_experiment.py` rejects a record → fix the record, never hand-append.
- Any `handoff_conditions` trigger → hard stop, ask the human. Never auto-merge.
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_loen_plugin.sh
```

Expected: `OK skill loop-autoresearch` … `PASS test_loen_plugin.sh`

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/skills/loop-autoresearch/SKILL.md tests/test_loen_plugin.sh
git commit -m "feat(loen): add loop-autoresearch skill (mode: research)"
```

---

### Task 7: `loen:audit` — mode-aware stage checks + verifier dispatch checklists

**Files:**
- Modify: `plugin/loen/skills/audit/SKILL.md` (full-body rewrite; frontmatter `name: audit` stays)

**Interfaces:**
- Consumes: `mode` from the active `loop.yaml`; `state.md` Baseline failing command (Task 5); `metrics.jsonl` / `experiments.jsonl` / record shapes / `LOEN_METRICS_PATH` (Tasks 1, 2, 6); `target:`/`tolerance:` grammar (Task 6).
- Produces: mode-aware `plan|act|check|result` gates; the per-mode verifier dispatch checklist (mode-specific behavior rides DISPATCH PROMPTS — agent bodies stay mode-blind); `report.html` experiments table in research mode.

- [ ] **Step 1: Rewrite the skill**

Replace the full contents of `plugin/loen/skills/audit/SKILL.md` with:

```markdown
---
name: audit
description: Validate a loen loop stage (plan|act|check|result), gate progression, and regenerate the human-readable docs/loen/<run-id>/report.html via the html-report skill. Mode-aware — extra checks for repair and research contracts. Mirrors check-chain for the execution loop.
---

# loen:audit — loop stage validator + live report

Invoke as `loen:audit <stage>` where `stage ∈ plan | act | check | result`. Read the active
run from `docs/loen/current` and `mode` from its `loop.yaml`
(`delivery | repair | research`). Every stage returns a verdict `OK` / `needs_work`, gates
the next stage, and **regenerates `docs/loen/<run-id>/report.html`** (via the `html-report`
skill) plus appends to `state.md`.

## Stage checks (all modes)

- **plan** — `loop.yaml` parses; `objective` measurable; `mutable_scope`/`protected_scope`
  non-empty and disjoint; `quality_gates` non-empty; `budget` present; human approval
  recorded. `needs_work` blocks Act.
- **act** — the latest `iterations/iter-NN/diff.patch` exists and touches only
  `mutable_scope`; no `protected_scope` path present (cross-check with this plugin's
  `scripts/guard_protected.sh` via the run's loop.yaml, resolved from the skill base dir);
  and the run dir passes this plugin's `scripts/check_layout.sh` — the deterministic net
  that catches any Bash-written non-canonical artifact that bypassed the PreToolUse hook.
- **check** — dispatch the `verifier` subagent (isolated); write its verdict to
  `iterations/iter-NN/verifier.md`; confirm `gates.log` shows the gates ran. `OK` iff the
  verdict is APPROVE and gates are green.
- **result** — every plan step is done, gates green, verifier APPROVE across the final
  iteration. On `OK`: finalize `report.html`, ensure `pr-summary.md` exists, and mark the
  `docs/TODO.md` row (`Result: OK`, `Status: done`, `Closed: <today>`) keyed by `<topic>`.

## Mode: repair — additional checks

- **plan** — `quality_gates` include the failing command recorded in the Baseline section
  of `state.md` at bootstrap.
- **check** — when the diff claims a NEW/extended regression test, `gates.log` carries the
  worker's logged inversion evidence (stash the fix → the regression test FAILS → pop →
  it PASSES).
- **result** — regression coverage evidenced in the final diff: case (a) a new/extended
  test, or case (b) the originally-failing test itself — the verifier states which case
  applies; the originally-failing command exits 0; the diff is minimal (every non-test
  hunk required for that command to pass).
- **verifier dispatch prompt** carries the repair checklist: regression coverage case
  (a/b), validation of the LOGGED inversion evidence, minimal-diff confirmation. The
  verifier stays read-only — it never mutates the tree.

## Mode: research — additional checks

- **plan** — `eval_command` non-empty; EXACTLY ONE `metrics.primary` entry of the form
  `<name>:max` or `<name>:min`; `stop_conditions` carry one
  `target: <primary-name> <op> <number>` line (`<op>` ∈ `>=`/`<=` matching the direction)
  and only well-formed `tolerance: <name> regression <= <number>[%]` lines;
  `protected_scope` COVERS the eval assets (the `eval_command` script, eval datasets,
  ground truth) — non-empty alone is not enough.
- **check** — gates green (they run on every experiment);
  `iterations/iter-NN/metrics.jsonl` has exactly one `summary` line; `experiments.jsonl`
  has this iteration's record; for every `keep` decision the verifier RE-RUNS
  `eval_command` — exporting `LOEN_METRICS_PATH` to a throwaway temp path, never appending
  to canonical artifacts — and confirms the claimed delta. `revert` records are trusted
  as logged.
- **result** — kept changes are metric-backed (primary improved in its declared direction,
  secondaries within their stated tolerances) OR the budget is exhausted with a
  best-result report; the `experiments.jsonl` stream is consistent end-to-end with the
  per-iteration `metrics.jsonl` summaries.
- **verifier dispatch prompt** carries the research checklist: delta re-check via a
  throwaway `LOEN_METRICS_PATH`, stream cross-check (`experiments.jsonl` vs
  `metrics.jsonl`), protected eval assets untouched. The verifier stays read-only.

## report.html (every stage)

Invoke the `html-report` skill targeting `docs/loen/<run-id>/report.html` with: the
contract (`loop.yaml`), an iterations table (diff summary, gates pass/fail, verifier
verdict), metrics before/after — in research mode an experiments table (hypothesis,
before/after, delta, decision) — budget spend, current stage/verdict, and handoff
reasons. Self-contained, opens by double-click.

## Rules

- Never edit the diff you are judging. Never weaken a gate to pass.
- All writes land at canonical `docs/loen/<run-id>/` paths (the loop-guard hook enforces
  this); the report is `report.html`, nothing else.
```

- [ ] **Step 2: Verify frontmatter lint + key strings**

```bash
bash tests/test_loen_plugin.sh
grep -c "Mode: repair\|Mode: research\|LOEN_METRICS_PATH\|verifier dispatch" plugin/loen/skills/audit/SKILL.md
```

Expected: `PASS test_loen_plugin.sh`; grep count ≥ 6.

- [ ] **Step 3: Commit**

```bash
git add plugin/loen/skills/audit/SKILL.md
git commit -m "feat(loen): mode-aware audit stage checks for repair and research"
```

---

### Task 8: Subagent roster — planner→fable, verifier→opus

**Files:**
- Modify: `plugin/loen/agents/planner.md:5` (`model: opus` → `model: fable`)
- Modify: `plugin/loen/agents/verifier.md:5` (`model: sonnet` → `model: opus`)
- Modify: `docs/functions/LOEN.md:37-40` (Subagents section)

**Interfaces:**
- Consumes: user-confirmed roster (spec §7): planner=fable, verifier=opus, explorer=haiku (unchanged).
- Produces: frontmatter `model:` lines only — agent BODIES stay mode-blind (spec §5.5). Docs roster synced.

- [ ] **Step 1: Edit the two frontmatter lines**

`plugin/loen/agents/planner.md` line 5:

```yaml
model: fable
```

`plugin/loen/agents/verifier.md` line 5:

```yaml
model: opus
```

- [ ] **Step 2: Sync the docs roster**

In `docs/functions/LOEN.md`, replace the Subagents section body:

```markdown
## Subagents

`planner` (fable — strongest reasoning where the contract and decomposition are authored),
`explorer` (haiku — cheap evidence gathering), `verifier` (opus — stronger judge, and
model-diverse from a typically-fable worker session, preserving worker ≠ judge diversity) —
all read-only, isolated context; the worker (main session) is the single writer. The
frontmatter `model:` is a default and always overridable; on Claude Code versions without
the `fable` alias the model falls back per harness rules.
```

- [ ] **Step 3: Verify**

```bash
grep -H "^model:" plugin/loen/agents/planner.md plugin/loen/agents/verifier.md plugin/loen/agents/explorer.md
bash tests/test_loen_plugin.sh
```

Expected: `planner.md:model: fable`, `verifier.md:model: opus`, `explorer.md:model: haiku`; `PASS test_loen_plugin.sh`.

- [ ] **Step 4: Commit**

```bash
git add plugin/loen/agents/planner.md plugin/loen/agents/verifier.md docs/functions/LOEN.md
git commit -m "feat(loen): confirmed subagent roster — planner=fable, verifier=opus"
```

---

### Task 9: Documentation — LOEN.md, plugin README, root README (RU)

**Files:**
- Modify: `docs/functions/LOEN.md` (Use, Artifacts table, Scope)
- Modify: `plugin/loen/README.md` (skill catalogue — ships inside the 0.2.0 package)
- Modify: `README.md:320-337` ("Loop Engineering (loen)" section, Russian)

**Interfaces:**
- Consumes: everything shipped in Tasks 1–8.
- Produces: the docs leg of the three-way canonical-path sync (layout table gains `metrics.jsonl`; `experiments.jsonl` was already canonical in the hook but missing from the table — add both rows).

- [ ] **Step 1: Update `docs/functions/LOEN.md`**

In the **Use** section, after the `/loop-delivery` bullet add:

```markdown
- `/loop-repair <failure description>` — fix a failing test / CI / regression:
  reproduce first, isolate, minimal fix, regression test (mode `repair`,
  `budget.max_iterations`, default 3).
- `/loop-autoresearch <metric goal>` — improve one numeric metric:
  baseline → hypothesis → one bounded change → fixed eval → compare → keep/revert
  (mode `research`, `budget.max_experiments`, default 5). Metrics travel as JSONL:
  the eval appends to `$LOEN_METRICS_PATH` (per-iteration `metrics.jsonl`); every
  experiment is a record in `experiments.jsonl`, appended by the deterministic
  `scripts/log_experiment.py`.
```

In the **Artifacts** table, after the `iterations/iter-NN/{diff.patch,gates.log,verifier.md}` row add:

```markdown
| `iterations/iter-NN/metrics.jsonl` | research: eval JSONL events + one `summary` line (baseline lives in `iter-00`) |
| `experiments.jsonl` | research: run-level experiment stream (baseline + one record per experiment) |
```

Replace the **Scope** section body:

```markdown
## Scope

Shipped: delivery (`loop-delivery`), repair (`loop-repair`), research
(`loop-autoresearch`), verifier, guard. `/goal`+`/loop` wrapping, verifier microVM
isolation, and governance/observability are later increments.
```

- [ ] **Step 2: Update `plugin/loen/README.md`**

Replace the command list (after the intro paragraph) with:

```markdown
- `/loop-delivery <task>` — execute one delivery task as a loop (planner fills
  `loop.yaml`, you approve, worker makes the smallest diff, gates + verifier check it,
  report is generated).
- `/loop-repair <failure description>` — fix a failing test / CI / regression:
  reproduce first → isolate → minimal fix → regression test (mode `repair`).
- `/loop-autoresearch <metric goal>` — improve one numeric metric:
  baseline → hypothesis → one bounded change → fixed eval → compare → keep/revert,
  logging every experiment to `experiments.jsonl` (mode `research`).
- `loen:audit <stage>` — validate a stage (`plan|act|check|result`), mode-aware, and
  regenerate the human-readable `docs/loen/<run-id>/report.html`.
```

- [ ] **Step 3: Update root `README.md` (Russian section)**

Replace the bash block at `README.md:327-331` with:

```markdown
```bash
# В сессии:
/loop-delivery <task>              # выполнить петлю (planner → апрув → act → verifier → отчёт)
/loop-repair <описание падения>    # починка: воспроизвести → изолировать → минимальный фикс → регресс-тест
/loop-autoresearch <цель-метрика>  # исследование: baseline → гипотеза → изменение → фикс. eval → keep/revert
/loen:audit plan|act|check|result  # проверить стадию (mode-aware) + обновить report.html
```
```

And replace the artifacts paragraph at `README.md:333-335` with:

```markdown
**Артефакты:** `docs/loen/<run-id>/` (loop.yaml, plan.md, state.md, iterations/iter-NN/,
experiments.jsonl, report.html, pr-summary.md). В research-режиме eval пишет JSONL-метрики
в `iterations/iter-NN/metrics.jsonl` (через `$LOEN_METRICS_PATH`), а каждый эксперимент
логируется детерминированным `log_experiment.py`. Шаблоны — ассеты плагина. Хук
`loop-guard.py` жёстко контролирует раскладку/именование и scope; в не-loop репозиториях — no-op.
```

- [ ] **Step 4: Verify + commit**

```bash
grep -c "loop-repair\|loop-autoresearch" docs/functions/LOEN.md plugin/loen/README.md README.md
git add docs/functions/LOEN.md plugin/loen/README.md README.md
git commit -m "docs(loen): document loop-repair and loop-autoresearch (LOEN.md, plugin README, root README)"
```

Expected: each file grep count ≥ 2.

---

### Task 10: Version bump 0.2.0 + full suite

**Files:**
- Modify: `plugin/loen/.claude-plugin/plugin.json:4` (`"version": "0.1.0"` → `"0.2.0"`)
- Modify: `.claude-plugin/marketplace.json` (loen entry `"version": "0.1.0"` → `"0.2.0"`)

**Interfaces:**
- Consumes: version-sync equality check already in `tests/test_loen_plugin.sh` and `scripts/check-plugin-version-sync.sh`.
- Produces: publishable loen 0.2.0.

- [ ] **Step 1: Bump both versions**

`plugin/loen/.claude-plugin/plugin.json`:

```json
  "version": "0.2.0",
```

`.claude-plugin/marketplace.json` (the `"name": "loen"` entry):

```json
      "version": "0.2.0",
```

- [ ] **Step 2: Run the sync check + the full loen suite**

```bash
bash scripts/check-plugin-version-sync.sh
bash tests/test_loen_plugin.sh
python3 tests/test_loen_hook.py
bash tests/test_loen_layout.sh
bash tests/test_loen_templates.sh
bash tests/test_loen_guard.sh
python3 tests/test_loen_experiment.py
```

Expected: every command exits 0; `PASS …` lines for all five loen tests plus `test_loen_experiment.py`.

- [ ] **Step 3: Commit**

```bash
git add plugin/loen/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(loen): bump plugin to 0.2.0 (loop-repair + loop-autoresearch)"
```

---

### Task 11: Process obligations — iwiki page + wiki_lint

**Files:**
- Modify (wiki, not repo): iwiki domain `iclaude`, page `loen-plugin`

**Interfaces:**
- Consumes: shipped state from Tasks 1–10.
- Produces: wiki in sync with 0.2.0. (`docs/TODO.md` row `loen-repair-autoresearch` stays open — it is closed by `/check-chain result`, not by this plan.)

- [ ] **Step 1: Read the current page**

Call `wiki_read_page(domain="iclaude", slug="loen-plugin")` and identify the `##` headings covering: Components, Artifact model, loop.yaml contract, Roadmap/backlog.

- [ ] **Step 2: Update the sections in place**

Use `wiki_update_page(domain="iclaude", slug="loen-plugin", heading=<section>, new_body=..., source="plugin/loen")` per section (exact heading names come from Step 1):

- **Components**: add `skills/loop-repair/SKILL.md`, `skills/loop-autoresearch/SKILL.md`, `scripts/log_experiment.py`; roster planner=fable / verifier=opus / explorer=haiku; note that mode-specific behavior rides dispatch prompts (agent bodies mode-blind) and both new skills reuse `../loop-delivery/assets/`.
- **Artifact model**: add `iterations/iter-NN/metrics.jsonl` (canonical, three-way synced: hook / check_layout / docs) and the research stream semantics (`experiments.jsonl` records: baseline + experiment; baseline = `iter-00`; `$LOEN_METRICS_PATH` mechanism; checkpoint/revert: commit per keep, `diff.patch` vs last kept state excluding `docs/loen`, `git apply -R` revert).
- **loop.yaml contract**: add `eval_command` (string, research), `budget.max_experiments` (default 5, governs research; `max_iterations` ignored there); `metrics.primary` exactly one `<name>:max|min` in research; `target:`/`tolerance:` grammar in `stop_conditions`.
- **Roadmap/backlog**: mark backlog step 1 (`loop-repair` + `loop-autoresearch`) done as of 0.2.0; steps 2–4 (goal/loop wrapper, verifier microVM, governance) still deferred.

- [ ] **Step 3: Lint**

Call `wiki_lint(domain="iclaude")`.

Expected: no broken `[[refs]]`, no orphan/stale pages for `loen-plugin`.

---

## Self-Review (performed while writing this plan)

- **Spec coverage:** §2 delivery model → Tasks 5, 6, 10; §3 repair → Tasks 5, 7; §4.1–4.3 research cycle/metrics/rules → Tasks 1, 4, 6, 7; §4.2a checkpoints → Task 6 (steps 6, 8); §5.1 three-way sync → Tasks 2, 3, 9; §5.2 template → Task 4; §5.3 writer → Task 1; §5.4 audit → Task 7; §5.5 dispatch contracts → Tasks 5, 6, 7; §7 roster → Task 8; §8 error handling → Tasks 1 (null metrics_after), 6; §9 tests → Tasks 1–6; §10 process → Tasks 9, 10, 11. No gaps found.
- **Placeholder scan:** no TBD/TODO/"similar to Task N"; all code and doc content inlined.
- **Type consistency:** `log_experiment.py` required-key sets match the record shapes in `loop-autoresearch/SKILL.md` and audit's research checks; `iter-NN` regex `^iter-\d{2}$` matches the hook's `iter-\d{2}` and `check_layout.sh`'s `iter-[0-9][0-9]`; template keys `eval_command` / `budget.max_experiments` named identically in Tasks 4, 6, 7, 11.
