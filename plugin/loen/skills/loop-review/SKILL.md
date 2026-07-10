---
name: loop-review
description: Use to review ONE diff, branch, or pull request under a controlled loop — scope, findings, and a disposition recorded as durable artifacts. Not for making a change (use loop-delivery).
---

# Loop Review (mode: review)

Thin configurator over the loen stage pipeline for reviewing a diff / branch / PR. Owns no
artifacts.

## Procedure

1. Set `mode: review`.
2. Invoke **`loop-start <topic>`**. Put the review scope (the diff / branch / PR) into
   `1_goal.md` and `context_sources` (the contract validator requires a non-empty review
   scope for `mode: review`). `quality_gates` are the checks that must pass on the reviewed
   change.
3. After the human approves the plan, invoke **`loop-run`**. `loop-check` dispatches the
   `reviewer` subagent; findings land in `5_check.md`, the disposition in `6_reflect.md`, and
   the final verdict in `7_result.md`.

Chain: `/loen:loop-review <diff/PR>` → `loop-start` → approval → **auto** `loop-run` →
terminal. The review is read-only over the target — record findings, never silently edit it.
