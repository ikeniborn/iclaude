---
name: loop-status
description: Use to report the current state of one or more loen topics from their artifacts — stage, latest evidence, open decisions, next action. Read-only.
---

# Loop Status

Report a topic's state from disk. Read-only — you write nothing. **Missing file = missing
state** — never infer progress from chat history.

## Procedure

1. Resolve the topic: the argument, else the `docs/loen/current` pointer, else scan
   `docs/loen/*/loop.yaml` for `status: active`.
2. Read `loop.yaml` (`mode`, `status`, `current_stage`, `run.current_pass` / budget).
3. Read the numbered artifacts to establish progress: the highest-numbered present stage file
   is the reached stage. Report each stage as present or missing.
4. Read `5_check.md` (`Result`) and `evidence/verifier-verdict.md` (`VERDICT`) for the latest
   evidence; `6_reflect.md` for the open decision; `7_result.md` / `handoff.md` for terminal
   state.

## Output

Report, per topic: mode + status, current stage, pass/budget, latest gate result + verifier
verdict, the open decision (if any), and the recommended next action (`loop-run`, or the
human decision named in `handoff.md`). If a topic has no artifacts, say so plainly rather than
guessing.
