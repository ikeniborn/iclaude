---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-02-loen-goal-loop-wrapper-design.md
review:
  plan_hash: 76107995c8033aec
  last_run: 2026-07-02
  runner: "clean-context subagent (check-runner protocol)"
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - { id: F-001, phase: dependencies, severity: CRITICAL, verdict: fixed, note: "Task 5 consumed the PR number before the PR existed → reordered: sweep → open PR → Roadmap update, status text 'PR #<N> opened' (not 'merged')" }
    - { id: F-002, phase: verifiability, severity: WARNING, verdict: fixed, note: "Task 1 Step 2 expected-failure output corrected: the four 'no stdout' checks PASS while the script is missing" }
    - { id: F-003, phase: coverage, severity: INFO, verdict: fixed, note: "extra refusal conditions (unknown mode, non-integer budget) now exercised by two added negative test cases" }
    - { id: F-004, phase: coverage, severity: INFO, verdict: wontfix, note: "empty protected_scope omits the clause — plan-level decision documented in Self-Review; ratify at review" }
    - { id: F-005, phase: coverage, severity: INFO, verdict: wontfix, note: "LOEN.md Scope-section edit beyond spec §7 — conscious doc-sync per CLAUDE.md docs-currency rule" }
  verdict: OK
result_check:
  verdict: OK
  plan_hash: 76107995c8033aec
  last_run: 2026-07-02
---
# loen /goal + /loop Wrapper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the optional loen accelerator — a deterministic `make_goal.py` that prints a ready-to-paste, evidence-first `/goal` string from the active approved `loop.yaml`, plus a thin `loop-goal` skill that validates run state, hands the string to the human, and carries the `/loop` polling recipe.

**Architecture:** Two new plugin files only (`plugin/loen/scripts/make_goal.py`, `plugin/loen/skills/loop-goal/SKILL.md`) plus tests and docs. The generator mirrors the repo's line-oriented YAML readers (no PyYAML); the skill never bootstraps a run and never submits `/goal` itself. No hook, template, agent, or canonical-path changes; zero reverse dependencies from existing skills.

**Tech Stack:** Python 3 stdlib, Bash test harness, Claude Code plugin skill (Markdown + frontmatter).

**Spec:** `docs/superpowers/specs/2026-07-02-loen-goal-loop-wrapper-design.md`
**Chain topic:** `loen-goal-loop-wrapper` (row in `docs/TODO.md`, driven by `/check-chain`)

## Global Constraints

- `make_goal.py` is **stdlib only** — no PyYAML at runtime; line-oriented YAML reading mirrors `hooks/loop-guard.py` / `guard_protected.sh`.
- **New files only** inside the plugin: `skills/loop-goal/SKILL.md`, `scripts/make_goal.py`. No hook changes, no template changes, no new canonical paths, no agent edits, zero new hard dependencies.
- Version bump is **minor**: `0.2.1 → 0.3.0`, in BOTH `plugin/loen/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (sync enforced by `scripts/check-plugin-version-sync.sh`). If the current version is no longer `0.2.1` at implementation time (backlog steps 2–4 have no fixed merge order), bump minor from whatever is current.
- The skill is invoked as `/loen:loop-goal`; it **never submits `/goal` itself** and **never bootstraps a run**.
- Generator validation (exit 1, **nothing on stdout**): file missing/unreadable, unknown `mode`, empty `quality_gates`, empty `mutable_scope`, research mode without a `target:` line in `stop_conditions`, missing/non-integer mode budget (`max_iterations` for delivery/repair, `max_experiments` for research). Empty `protected_scope` is NOT an error — the `do not modify` clause is simply omitted (the skill's precondition "audit plan returned OK" already guarantees it non-empty in practice).
- The generated string always ends with the budget/stop clause (hard stop, never loops forever).
- Documentation language: English for `docs/functions/LOEN.md`, `plugin/loen/README.md`, SKILL.md, code comments; root `README.md` is Russian. `docs/README.ru.md` does not exist — do not create it.
- Branch workflow: create `dev-loen-goal-loop-wrapper` off `dev`; PR back into `dev` (matches loen PRs #75/#78). Commit messages in English.

---

### Task 1: `make_goal.py` — deterministic /goal generator (TDD)

**Files:**
- Create: `plugin/loen/scripts/make_goal.py`
- Test: `tests/test_loen_goal.py` (plain-script convention like `tests/test_loen_experiment.py` — `main()` + `check()` + `PASS/FAIL`, NOT pytest)

**Interfaces:**
- Consumes: an existing `loop.yaml` (contract shape from `plugin/loen/skills/loop-delivery/assets/loop.template.yaml`).
- Produces: CLI `python3 plugin/loen/scripts/make_goal.py [path]` (default path `docs/loen/current/loop.yaml`, resolved relative to cwd). Exit 0 → exactly one line on stdout starting with `/goal `. Exit 1 → empty stdout, reason on stderr. Task 2's skill calls exactly this CLI.

**Output string shapes (exact, assembled ONLY from contract fields — no LLM, no inference):**

Delivery / repair:

```
/goal <gate1> exits 0 and <gate2> exits 0 and … and Claude prints each command's output summary as evidence; change only <mutable globs, comma-joined>; do not modify <protected globs, comma-joined>; stop after <budget.max_iterations> failed attempts and report the blocker
```

Research (the `target: <name> <op> <number>` line from `stop_conditions` becomes the success clause; gates stay as invariants; budget uses `max_experiments`):

```
/goal the printed eval summary shows <name> <op> <number> and <gate1> exits 0 and … and Claude prints each command's output summary as evidence; change only <…>; do not modify <…>; stop after <budget.max_experiments> experiments and report the best kept state
```

- [ ] **Step 1: Write the failing test**

Create `tests/test_loen_goal.py` with exactly this content:

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
python3 tests/test_loen_goal.py
```

Expected: `FAIL test_loen_goal.py` listing all exit-code and string checks (the script does not exist yet, so `subprocess` returns exit code 2 with empty stdout). The four `* no stdout` checks PASS — stdout is empty when the script is missing — so they do not appear in the fail list.

- [ ] **Step 3: Write the implementation**

Create `plugin/loen/scripts/make_goal.py` with exactly this content:

```python
#!/usr/bin/env python3
"""loen /goal string generator (deterministic).

Usage: make_goal.py [path/to/loop.yaml]
Default path: docs/loen/current/loop.yaml (the active run).

Prints ONE ready-to-paste, evidence-first /goal line assembled only
from contract fields — no LLM, no inference. Refuses (exit 1, nothing
on stdout) contracts that would fail `loen:audit plan`: missing or
unreadable file, unknown mode, empty quality_gates, empty
mutable_scope, research mode without a `target: <name> <op> <number>`
stop condition, missing mode budget. Line-oriented YAML reading
mirrors hooks/loop-guard.py — stdlib only, no PyYAML."""
import re
import sys

DEFAULT_PATH = "docs/loen/current/loop.yaml"
LIST_KEYS = ("quality_gates", "mutable_scope", "protected_scope",
             "stop_conditions")
TARGET = re.compile(
    r"^target:\s*([\w.-]+)\s*(>=|<=)\s*(-?\d+(?:\.\d+)?)\s*$")
EVIDENCE = "Claude prints each command's output summary as evidence"


def fail(msg):
    sys.stderr.write("make_goal: " + msg + "\n")
    sys.exit(1)


def scalar(rest):
    """Value of 'key: <rest>' with a trailing comment stripped."""
    return rest.split("#", 1)[0].strip().strip('"').strip("'")


def inline_list(s):
    """Parse 'key: [a, b]' -> [a, b]; None if not an inline flow
    list. Tolerates a trailing comment (the shipped template has
    them on every empty-list line)."""
    m = re.match(r"^[\w-]+:\s*\[([^\]]*)\]\s*(?:#.*)?$", s)
    if m is None:
        return None
    body = m.group(1).strip()
    if not body:
        return []
    return [x.strip().strip('"').strip("'")
            for x in body.split(",") if x.strip()]


def parse(path):
    """Line-oriented read of the contract fields this generator
    needs: mode, the four list keys, and the budget block."""
    lists = {k: [] for k in LIST_KEYS}
    mode = ""
    budget = {}
    cur = None            # list collecting block-style '- item' lines
    in_budget = False
    try:
        f = open(path, encoding="utf-8")
    except OSError as e:
        fail(f"cannot read {path}: {e.strerror}")
    with f:
        for line in f:
            s = line.rstrip("\n")
            top = re.match(r"^([\w-]+):(.*)$", s)
            if top:
                key, rest = top.group(1), top.group(2)
                cur, in_budget = None, key == "budget"
                if key in lists:
                    inline = inline_list(s)
                    if inline is None:
                        cur = lists[key]   # block list on next lines
                    else:
                        lists[key].extend(inline)
                elif key == "mode":
                    mode = scalar(rest)
                continue
            if in_budget:
                m = re.match(r"^\s+([\w-]+):\s*(.*)$", s)
                if m:
                    budget[m.group(1)] = scalar(m.group(2))
                continue
            m = re.match(r"^\s*-\s*(.+?)\s*$", s)
            if m and cur is not None:
                cur.append(m.group(1).strip().strip('"').strip("'"))
    return mode, lists, budget


def budget_int(budget, key):
    v = budget.get(key, "")
    if not re.fullmatch(r"\d+", v):
        fail(f"budget.{key} missing or not an integer")
    return int(v)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PATH
    mode, lists, budget = parse(path)
    if mode not in ("delivery", "repair", "research"):
        fail(f"unsupported mode: {mode!r}")
    if not lists["quality_gates"]:
        fail("quality_gates is empty — contract is not audit-plan ready")
    if not lists["mutable_scope"]:
        fail("mutable_scope is empty — contract is not audit-plan ready")

    clauses = []
    if mode == "research":
        target = None
        for item in lists["stop_conditions"]:
            m = TARGET.match(item)
            if m:
                target = m
                break
        if target is None:
            fail("research contract lacks a "
                 "'target: <name> <op> <number>' stop condition")
        name, op, num = target.groups()
        clauses.append(
            f"the printed eval summary shows {name} {op} {num}")
    clauses += [f"{g} exits 0" for g in lists["quality_gates"]]
    clauses.append(EVIDENCE)

    parts = [" and ".join(clauses),
             "change only " + ", ".join(lists["mutable_scope"])]
    if lists["protected_scope"]:
        parts.append(
            "do not modify " + ", ".join(lists["protected_scope"]))
    if mode == "research":
        n = budget_int(budget, "max_experiments")
        parts.append(f"stop after {n} experiments "
                     f"and report the best kept state")
    else:
        n = budget_int(budget, "max_iterations")
        parts.append(f"stop after {n} failed attempts "
                     f"and report the blocker")
    print("/goal " + "; ".join(parts))


if __name__ == "__main__":
    main()
```

Then make it executable:

```bash
chmod +x plugin/loen/scripts/make_goal.py
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
python3 tests/test_loen_goal.py
```

Expected: `PASS test_loen_goal.py`

- [ ] **Step 5: Regression — the other loen suites still pass**

Run:

```bash
python3 tests/test_loen_experiment.py && bash tests/test_loen_plugin.sh
```

Expected: `PASS test_loen_experiment.py` and `PASS test_loen_plugin.sh` (this task touched neither).

- [ ] **Step 6: Commit**

```bash
git add plugin/loen/scripts/make_goal.py tests/test_loen_goal.py
git commit -m "feat(loen): deterministic make_goal.py — evidence-first /goal string from loop.yaml"
```

---

### Task 2: `loop-goal` skill + plugin lint coverage

**Files:**
- Create: `plugin/loen/skills/loop-goal/SKILL.md`
- Modify: `tests/test_loen_plugin.sh:49` (the skill lint loop)

**Interfaces:**
- Consumes: Task 1's CLI — `python3 <skill-base>/../../scripts/make_goal.py docs/loen/current/loop.yaml` (skills/loop-goal → `../../` → plugin/loen → `scripts/`).
- Produces: skill `/loen:loop-goal`; frontmatter `name: loop-goal` + `description:` (both required by the lint).

- [ ] **Step 1: Extend the lint list (the failing test)**

In `tests/test_loen_plugin.sh`, change the skill loop line:

```bash
for s in loop-delivery audit loop-repair loop-autoresearch; do
```

to:

```bash
for s in loop-delivery audit loop-repair loop-autoresearch loop-goal; do
```

- [ ] **Step 2: Run it to verify it fails**

Run:

```bash
bash tests/test_loen_plugin.sh
```

Expected: `FAIL: missing skill plugin/loen/skills/loop-goal/SKILL.md`

- [ ] **Step 3: Write the skill**

Create `plugin/loen/skills/loop-goal/SKILL.md` with exactly this content:

```markdown
---
name: loop-goal
description: OPTIONAL accelerator — wrap the active, human-approved loen run in Claude's native /goal condition (generated deterministically from loop.yaml by scripts/make_goal.py), plus a session-scoped /loop polling recipe for long-running gates. Validates run state, briefs the evidence-first /goal mechanics, never bootstraps a run, never submits /goal itself.
---

# Loop Goal — /goal + /loop wrapper (optional)

Wrap the ACTIVE loen run in a native `/goal` condition so "keep going until the
gates are green" runs multi-turn without hand-holding. Invoked as
`/loen:loop-goal` (optionally with an explicit run-id). This wrapper NEVER
weakens the loop protocol: `loen:audit` stages, the loop-guard hook, and the
human approval gate stay exactly as in the MVP — `/goal` only automates the
turn loop.

## Steps

1. **Preconditions.** An active run exists (`docs/loen/current` resolves to a
   run directory) whose contract was human-approved and whose `loen:audit plan`
   returned `OK` (both recorded in `docs/loen/<run-id>/state.md`). No active
   run → STOP and point to `/loop-delivery`, `/loop-repair`, or
   `/loop-autoresearch` — this skill wraps an existing run, it never bootstraps
   one. One goal run wraps ONE loen run: if the user passed a run-id that
   differs from the active run, REFUSE (mirror of the hook's cross-topic
   block).
2. **Generate.** Run the deterministic generator (the skill base directory is
   printed when this skill is invoked; the script is stdlib-only):
   `python3 <skill-base>/../../scripts/make_goal.py docs/loen/current/loop.yaml`.
   Exit 1 means the contract is not audit-plan shaped — report its stderr and
   stop. Show the produced string to the human VERBATIM for them to submit as
   `/goal …`. NEVER submit `/goal` yourself — it is a native user-level
   command; the human stays in control of granting multi-turn autonomy.
3. **Evidence-first briefing.** Alongside the string, restate the `/goal`
   mechanics: the `/goal` evaluator only reads the transcript — it runs no
   commands. During the goal run the worker MUST print every gate command, its
   exit code, and metric summaries into the conversation; a condition like
   "all tests pass" without printed evidence never evaluates true. The
   generated string already encodes this ("… prints each command's output
   summary as evidence") — do not trim it.
4. **`/loop` recipe (long-running gates).** For gates that poll external state
   (CI runs, deploys), offer: `/loop <interval> loen:audit check` with
   `<interval>` matched to the external system's cadence. The durability
   warning is MANDATORY: `/loop` is session-scoped — it dies with the session
   and recurring tasks auto-expire; durable scheduling belongs to Routines /
   OS schedulers / CI, outside this skill's scope.

## Guardrails

- The generated string always ends with the budget/stop clause, so the goal
  run hard-stops instead of looping forever; `handoff_conditions` keep
  hard-stopping as usual.
- Optional by construction: nothing in `loop-delivery`, `loop-repair`,
  `loop-autoresearch`, or `loen:audit` references this skill.
```

- [ ] **Step 4: Run the lint to verify it passes**

Run:

```bash
bash tests/test_loen_plugin.sh
```

Expected: `OK skill loop-goal` in the output and final `PASS test_loen_plugin.sh`.

- [ ] **Step 5: Commit**

```bash
git add plugin/loen/skills/loop-goal/SKILL.md tests/test_loen_plugin.sh
git commit -m "feat(loen): loop-goal skill — /goal + /loop wrapper for the active run"
```

---

### Task 3: Version bump 0.2.1 → 0.3.0 (minor, both manifests)

**Files:**
- Modify: `plugin/loen/.claude-plugin/plugin.json:4`
- Modify: `.claude-plugin/marketplace.json:18` (the `loen` entry)

**Interfaces:**
- Consumes: nothing from earlier tasks (independent edit; commit after Tasks 1–2 so the version bump ships the new files).
- Produces: `version: "0.3.0"` in both manifests — `scripts/check-plugin-version-sync.sh` and `tests/test_loen_plugin.sh` both assert equality.

If either file already shows a version above `0.2.1` (another backlog step merged first), bump minor from THAT version instead and keep both files identical.

- [ ] **Step 1: Bump `plugin.json`**

In `plugin/loen/.claude-plugin/plugin.json` change:

```json
  "version": "0.2.1",
```

to:

```json
  "version": "0.3.0",
```

- [ ] **Step 2: Bump `marketplace.json`**

In `.claude-plugin/marketplace.json`, inside the `"name": "loen"` entry, change:

```json
      "version": "0.2.1",
```

to:

```json
      "version": "0.3.0",
```

- [ ] **Step 3: Verify sync**

Run:

```bash
bash scripts/check-plugin-version-sync.sh && bash tests/test_loen_plugin.sh
```

Expected: version-sync check passes (no problems reported) and `PASS test_loen_plugin.sh`.

- [ ] **Step 4: Commit**

```bash
git add plugin/loen/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(loen): bump plugin to 0.3.0 (loop-goal wrapper)"
```

---

### Task 4: Repo docs — LOEN.md, plugin README, root README (RU)

**Files:**
- Modify: `docs/functions/LOEN.md` (Use section after the `loen:audit` bullet; Scope section last paragraph)
- Modify: `plugin/loen/README.md` (catalogue list, after the `loen:audit` bullet)
- Modify: `README.md` (Russian; the `### Loop Engineering (loen)` code block around line 332)

**Interfaces:**
- Consumes: names fixed by Tasks 1–2 — `/loen:loop-goal`, `scripts/make_goal.py`.
- Produces: user-facing docs in sync with the new skill (English), root README in Russian.

- [ ] **Step 1: `docs/functions/LOEN.md` — add the Use bullet**

After the `loen:audit plan|act|check|result` bullet, add:

```markdown
- `/loen:loop-goal` — optional accelerator: print a ready-to-paste, evidence-first
  `/goal` string generated deterministically from the active, approved `loop.yaml`
  (`scripts/make_goal.py`), plus a session-scoped `/loop` polling recipe for
  long-running gates. Never bootstraps a run, never submits `/goal` itself.
```

- [ ] **Step 2: `docs/functions/LOEN.md` — update the Scope section**

Change:

```markdown
Shipped: delivery (`loop-delivery`), repair (`loop-repair`), research
(`loop-autoresearch`), verifier, guard. `/goal`+`/loop` wrapping, verifier microVM
isolation, and governance/observability are later increments.
```

to:

```markdown
Shipped: delivery (`loop-delivery`), repair (`loop-repair`), research
(`loop-autoresearch`), verifier, guard, `/goal`+`/loop` wrapping (`loop-goal` +
`make_goal.py`). Verifier microVM isolation and governance/observability are later
increments.
```

- [ ] **Step 3: `plugin/loen/README.md` — add the catalogue bullet**

After the `loen:audit <stage>` bullet, add:

```markdown
- `/loen:loop-goal` — optional: generate a ready-to-paste, evidence-first `/goal`
  string from the active approved `loop.yaml` (deterministic `scripts/make_goal.py`),
  with a session-scoped `/loop` polling recipe for long-running gates. Never
  bootstraps a run, never submits `/goal` itself.
```

- [ ] **Step 4: Root `README.md` (Russian) — extend the loen code block**

In the `### Loop Engineering (loen)` section, change the code block:

```bash
# В сессии:
/loop-delivery <task>              # выполнить петлю (planner → апрув → act → verifier → отчёт)
/loop-repair <описание падения>    # починка: воспроизвести → изолировать → минимальный фикс → регресс-тест
/loop-autoresearch <цель-метрика>  # исследование: baseline → гипотеза → изменение → фикс. eval → keep/revert
/loen:audit plan|act|check|result  # проверить стадию (mode-aware) + обновить report.html
```

to:

```bash
# В сессии:
/loop-delivery <task>              # выполнить петлю (planner → апрув → act → verifier → отчёт)
/loop-repair <описание падения>    # починка: воспроизвести → изолировать → минимальный фикс → регресс-тест
/loop-autoresearch <цель-метрика>  # исследование: baseline → гипотеза → изменение → фикс. eval → keep/revert
/loen:audit plan|act|check|result  # проверить стадию (mode-aware) + обновить report.html
/loen:loop-goal                    # опционально: evidence-first строка /goal из одобренного loop.yaml + рецепт /loop
```

- [ ] **Step 5: Verify nothing broke**

Run:

```bash
bash tests/test_loen_plugin.sh && python3 tests/test_loen_goal.py
```

Expected: both `PASS` (docs edits touch no code).

- [ ] **Step 6: Commit**

```bash
git add docs/functions/LOEN.md plugin/loen/README.md README.md
git commit -m "docs(loen): document /loen:loop-goal wrapper in LOEN.md and READMEs"
```

---

### Task 5: iwiki update + final sweep

**Files:**
- Modify (via iwiki MCP tools, NOT file edits): wiki domain `iclaude`, page `loen-plugin` — sections `Components` and `Roadmap and backlog`.
- No repo files. `docs/TODO.md` row `loen-goal-loop-wrapper` is driven by `/check-chain` (do not hand-edit unless `/check-chain` is not being run for this task).

**Interfaces:**
- Consumes: shipped names — `loop-goal` skill, `scripts/make_goal.py`, version `0.3.0`, the PR number once known.
- Produces: wiki in sync; `wiki_lint` clean.

**Note for subagent-driven execution:** this task needs the iwiki MCP tools (`wiki_update_page`, `wiki_lint`), which live in the MAIN session. Execute it in the main session (orchestrator), not in a file-editing subagent.

- [ ] **Step 1: Update the `Components` section**

Call `wiki_update_page(domain="iclaude", slug="loen-plugin", heading="Components", new_body=..., source="plugin/loen/skills/loop-goal/SKILL.md")` where `new_body` is the CURRENT Components body (re-read it first via `wiki_read_page` — it may have drifted) with two additions:

After the `skills/audit/SKILL.md` bullet, add:

```markdown
- `skills/loop-goal/SKILL.md` — `/loen:loop-goal` (optional accelerator, shipped in 0.3.0): validates the active run (human-approved contract, `loen:audit plan` OK, active run only — cross-topic refused), runs `scripts/make_goal.py`, hands the `/goal` string to the human VERBATIM (never submits `/goal` itself), briefs the evidence-first `/goal` mechanics (the evaluator reads only the transcript — the worker must print gate commands, exit codes, metric summaries), and carries the session-scoped `/loop <interval> loen:audit check` polling recipe with the mandatory durability warning. No reverse dependencies — nothing in the other skills references it.
```

After the `scripts/log_experiment.py` bullet, add:

```markdown
- `scripts/make_goal.py` — deterministic /goal string generator (new in 0.3.0): reads a `loop.yaml` (default `docs/loen/current/loop.yaml`, line-oriented stdlib parsing like the hook), prints one evidence-first `/goal` line — delivery/repair: every gate as `<cmd> exits 0` + evidence clause + `change only <mutable_scope>` + `do not modify <protected_scope>` + `stop after <max_iterations> failed attempts and report the blocker`; research: the `target:` stop condition rendered as the success clause + gates as invariants + `stop after <max_experiments> experiments and report the best kept state`. Exit 1 with empty stdout on contracts that would fail `loen:audit plan` (missing file, empty `quality_gates`/`mutable_scope`, research without `target:`).
```

- [ ] **Step 2: Final regression sweep**

Run:

```bash
python3 tests/test_loen_goal.py && python3 tests/test_loen_experiment.py && bash tests/test_loen_plugin.sh && bash tests/test_loen_guard.sh && bash tests/test_loen_layout.sh && bash tests/test_loen_templates.sh && python3 tests/test_loen_hook.py && bash scripts/check-plugin-version-sync.sh
```

Expected: every suite prints its `PASS` line (or exits 0); no output changes outside the two new suites' additions.

- [ ] **Step 3: Finish the branch (open the PR)**

No commit here unless Step 1 changed repo files (it should not — wiki writes auto-commit in the wiki base). Open the PR from `dev-loen-goal-loop-wrapper` into `dev` using the git-workflow skill; PR body summarizes: new `make_goal.py` + `loop-goal` skill, version 0.3.0, tests, docs. Note the PR number — Step 4 uses it.

- [ ] **Step 4: Update the `Roadmap and backlog` section**

Via `wiki_update_page(domain="iclaude", slug="loen-plugin", heading="Roadmap and backlog", new_body=...)`: re-read the current body, change row 2's Status from `spec drafted (PR #78, pending review)` to `done (0.3.0, PR #<N> opened)` — using the real PR number from Step 3; merge happens later at human review, outside this plan — and append one sentence to the prose noting increment 2 shipped (loop-goal + make_goal.py, plugin 0.3.0, chain `loen-goal-loop-wrapper`).

- [ ] **Step 5: Lint the wiki**

Call `wiki_lint(domain="iclaude")`. Expected: no broken `[[refs]]`, no new orphan/stale pages.

---

## Self-Review (performed at plan-writing time)

- **Spec coverage:** §2 generator (Task 1 — output shapes, validation set, stdlib parsing), §3 skill steps 1–4 (Task 2 SKILL.md sections Steps 1–4), §4 guardrails (SKILL.md Guardrails + generated stop clause), §5 delivery model (Task 3 — minor bump both manifests, new files only), §6 testing (Task 1 test file covers every listed case incl. `quality_gates: []`, research w/o `target:`, missing file; Task 2 extends the lint list), §7 process obligations (Task 4 docs + Task 5 iwiki; `docs/TODO.md` via `/check-chain`), §8 out of scope respected (no durable scheduling, no auto-submit, no protocol changes).
- **Types/names consistency:** `make_goal.py` path `plugin/loen/scripts/make_goal.py` used identically in Tasks 1, 2 (`<skill-base>/../../scripts/`), 4, 5; skill name `loop-goal` matches the lint loop, frontmatter, and docs; version `0.3.0` consistent across Task 3 and Task 5 wiki text.
- **Decisions locked here (overridable at review):** the generator prints the full line INCLUDING the `/goal ` prefix (most literal reading of "ready-to-paste"); empty `protected_scope` omits the clause instead of failing (spec §2 enumerates exactly four refusal conditions); missing/non-integer mode budget refuses (falls under "unparsable" — the string cannot be assembled without it); test file follows the repo's plain-script convention rather than pytest (matches `test_loen_experiment.py`).
