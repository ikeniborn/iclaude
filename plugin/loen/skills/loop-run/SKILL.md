---
name: loop-run
description: Use to run an approved topic autonomously — drive act→check→reflect to 7_result.md or handoff.md. Starts only from an approved plan; the loop's autonomous engine.
---

# Loop Run

Run the active topic **autonomously** to a terminal outcome. You are the worker. After the
one human gate (plan approval in `loop-start`), this skill loops without further prompting
until `7_result.md` (Done) or `handoff.md` (human decision required).

## Preflight gate (refuse an unapproved plan)

1. Read `docs/loen/<topic>/loop.yaml` and `3_plan.md`.
2. Run the contract validator:

   ```bash
   python3 - "$TOPIC" <<'PY'
   import sys; sys.path.insert(0, "plugin/loen/hooks")
   import loen_common as c, loen_artifacts as a
   topic = sys.argv[1]
   loop = c.loop_policy(topic)
   plan = open("docs/loen/%s/3_plan.md" % topic).read()
   ok, errs = a.validate_run_contract(loop, plan)
   print("OK" if ok else "FAIL")
   [print(" -", e) for e in errs]
   PY
   ```

   If it prints `FAIL` (usually `run.plan_approved != true` or a `run.plan_hash` mismatch),
   **do not run** — write `handoff.md` ("approve the plan in loop-start first") and stop.

## State machine (`run.state`: prepare → act → check → reflect)

Loop these stages, updating `loop.yaml` `run.state` and `run.current_pass` on every
transition (so the loop resumes after a compaction or interruption):

1. **prepare** — pick the next unfinished plan step.
2. **act** — invoke `loop-act` (one bounded action → `4_act.md`).
3. **check** — invoke `loop-check` (run `quality_gates` → `5_check.md`; dispatch the
   `verifier` with a capsule → `evidence/verifier-verdict.md`).
4. **reflect** — invoke `loop-reflect`, then branch:
   - gates `PASS` **and** verifier `APPROVE` → write `7_result.md`, set `status: done`, **STOP**.
   - verifier `REJECT` and `run.current_pass < budget.max_iterations` → `run.current_pass++`,
     feed the required fixes back into **act**.
   - budget exhausted, a `handoff_condition` fired, a `REJECT` past budget, or a gate needs a
     human → write `handoff.md`, set `status: handoff`, **STOP**.

## Termination

`7_result.md` (Done) or `handoff.md`. Never auto-merge — the loop always ends at a human PR
review. The evidence-gate Stop hook blocks a "done" stop without
`5_check.md` + `7_result.md` + a verifier verdict + non-empty `evidence/`.

## Cross-turn fallback (large budgets)

Default is the in-session loop. Only when `budget.max_iterations > 5` OR
`budget.max_wall_time_minutes > 60` (the loop is likely to outlive one context window), emit
and self-run a native `/goal` string built from `loop.yaml` so the loop survives compaction
across turns. Below both thresholds, stay in-session.

## Output

Report each pass's decision, and at termination the outcome (`7_result.md` Done or
`handoff.md` reason) plus the regenerated `audit.html`.
