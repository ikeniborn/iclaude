---
name: loop-autoresearch
description: Use when improving ONE numeric metric under a controlled research loop with a fixed eval and kept/reverted experiments. Not for a feature (use loop-delivery) or a failing test (use loop-repair).
---

# Loop AutoResearch (mode: research)

Thin configurator over the loen stage pipeline for a metric-driven experiment loop. Owns no
artifacts.

## Procedure

1. Set `mode: research`.
2. Invoke **`loop-start <topic>`**. Set `eval_command` (the fixed eval), `metrics.primary`,
   and a `stop_conditions` entry naming the `target` (the contract validator requires it).
   Put the measurable question and baseline in `2_context.md`.
3. After the human approves the plan, invoke **`loop-run`**. Each experiment runs the fixed
   `eval_command`; the `researcher` subagent records the metric into `5_check.md`; kept
   changes are those that beat the baseline, reverted otherwise (per `rollback_policy`).

Chain: `/loen:loop-autoresearch <metric goal>` → `loop-start` → approval → **auto** `loop-run`
→ terminal. Never claim a result the eval did not produce.
