---
name: loop-delivery
description: Use when delivering ONE bounded change — a feature, refactor, or chore — as a controlled, audited loop. Not for a failing test (use loop-repair) or a numeric metric (use loop-autoresearch).
---

# Loop Delivery (mode: delivery)

Thin configurator over the loen stage pipeline. It owns no artifacts — it sets the mode and
delegates to the durable pipeline.

## Procedure

1. Set `mode: delivery`.
2. Invoke **`loop-start <topic>`**: it scaffolds `docs/loen/<topic>/`, writes `1_goal.md`
   (the bounded change) and `2_context.md`, generates `3_plan.md` via `loop-plan`, and holds
   the one human approval gate. Fill `mutable_scope`, `protected_scope`, `quality_gates`,
   and `rollback_policy` in `loop.yaml`.
3. After the human approves the plan, invoke **`loop-run`** — it drives `act→check→reflect`
   autonomously to `7_result.md` (Done) or `handoff.md`.

The chain is: `/loen:loop-delivery <task>` → `loop-start` (bootstrap + approval) → **auto**
`loop-run` → terminal. Never auto-merge; the loop ends at a human PR review.
