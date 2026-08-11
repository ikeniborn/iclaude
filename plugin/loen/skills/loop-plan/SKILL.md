---
name: loop-plan
description: Use to turn a topic's goal + context + loop.yaml into ONE bounded plan with exact verify commands. The single writer of 3_plan.md.
---

# Loop Plan

Produce ONE bounded plan for the active topic. You are the single writer of `3_plan.md`.

## Procedure

1. Read `docs/loen/<topic>/1_goal.md`, `2_context.md`, and `loop.yaml`.
2. Optionally dispatch the `planner` subagent (read-only) with the loop.yaml schema template
   path to draft the contract + plan; you persist its output.
3. Write `3_plan.md`:
   - `## Steps` — 3–8 numbered steps, each `step -> verify: <check>`, each with a one-line
     definition of done. Every step must fit inside `mutable_scope`.
   - `## Checks` — a ```bash block of the exact `quality_gates` commands that must exit 0.
4. Keep the plan minimal (YAGNI). Flag any handoff-worthy risk (schema / PII / license /
   architecture / prod-creds) explicitly so `loop-start`'s approval gate can catch it.

## Output

Report that `3_plan.md` is written and ready for the human approval gate in `loop-start`.
Do not arm `run.plan_approved` — that is `loop-start`'s job after approval.
