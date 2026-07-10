---
name: loop-act
description: Use to execute exactly ONE bounded action of the active plan as the worker, then record the evidence. Writes 4_act.md.
---

# Loop Act

Execute exactly ONE bounded action from `3_plan.md`. You are the worker — the only writer —
and you stay inside `mutable_scope` (scope-guard enforces this).

## Procedure

1. Read `docs/loen/<topic>/3_plan.md` and `loop.yaml`; pick the next unfinished step.
2. Make the **smallest** change that advances that step. Never touch `protected_scope`.
3. Write `4_act.md`:
   - `## Action` — what you did, in one paragraph.
   - `## Changed Paths` — every file you touched, one bullet each.
   - `## Commands` — a ```bash block of the commands you ran.
4. Append one row to `attempts.jsonl` (pass number, step, changed-path count) via
   `loen_artifacts.append_attempt`.

## Output

Report the action taken, the changed paths, and that `loop-check` should run next.
Do one action only — `loop-run` calls you again for the next.
