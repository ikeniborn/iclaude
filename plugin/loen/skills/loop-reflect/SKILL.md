---
name: loop-reflect
description: Use to decide keep/fix/revert/handoff from the check evidence and verifier verdict, and write the terminal result when the loop is complete. Writes 6_reflect.md and 7_result.md.
---

# Loop Reflect

Decide the iteration's outcome from the evidence. You optionally dispatch the read-only
`reviewer` subagent for a second opinion.

## Procedure

1. Read `docs/loen/<topic>/5_check.md` (`Result`) and `evidence/verifier-verdict.md`
   (`VERDICT`).
2. Write `6_reflect.md`:
   - `## Decision` — one of `keep | fix | revert | handoff`.
   - `## Reason` — the evidence behind the decision.
   - `## Next Step` — the concrete next action.
3. Apply the decision:
   - **keep** — gates `PASS` AND verifier `APPROVE`: ensure `evidence/verifier-verdict.md`
     exists FIRST (the Stop evidence-gate requires it), then write `7_result.md`
     (`## Outcome` = `Done`, `## Evidence Files` list), then set `loop.yaml` `status: done`.
     Leave the `docs/loen/current` pointer in place — the guards are already inert once
     `status != active`, and the evidence-gate needs the pointer to verify the terminal stop.
   - **fix** — verifier `REJECT` within budget: record the required fixes; `loop-run` loops
     back to `loop-act`.
   - **revert** — apply `rollback_policy`; record why.
   - **handoff** — a `handoff_condition` fired, budget is exhausted, or a gate needs a human:
     write `handoff.md` (state + required human decision), set `loop.yaml` `status: handoff`
     (the guards go inert; the pointer stays for the next `loop-start` to overwrite).

## Output

Report the decision and the terminal artifact written (`7_result.md` for Done, `handoff.md`
for a human decision). Never declare Done without gates `PASS` + verifier `APPROVE` + evidence
(the evidence-gate Stop hook enforces this).
