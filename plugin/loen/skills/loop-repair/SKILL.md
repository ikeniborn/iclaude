---
name: loop-repair
description: Use when a specific test, CI job, or regression is failing and must be fixed under a reproduce-first controlled loop with proven regression coverage. Not for delivering a change (use loop-delivery) or metrics (use loop-autoresearch).
---

# Loop Repair (mode: repair)

Thin configurator over the loen stage pipeline for a failing test / CI / regression. Owns no
artifacts.

## Procedure

1. Set `mode: repair`.
2. Invoke **`loop-start <topic>`**. Frame the failure into `2_context.md`: the exact failing
   command, its output, and the reproduction. Set `1_goal.md` to "reproduce → minimal fix →
   regression test". Put the reproduce command and the regression test in `quality_gates`.
3. After the human approves the plan, invoke **`loop-run`**. The autonomous loop must
   reproduce the failure first; if it will not reproduce, `loop-reflect` writes `handoff.md`.
   Root cause goes into `7_result.md`.

Chain: `/loen:loop-repair <failure>` → `loop-start` → approval → **auto** `loop-run` →
terminal. Never weaken a gate to go green.
