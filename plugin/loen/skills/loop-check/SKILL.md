---
name: loop-check
description: Use to run the topic's quality gates, record exit codes and evidence, and dispatch the independent verifier. Writes 5_check.md.
---

# Loop Check

Verify the latest action against the contract's `quality_gates`, then get an independent
verdict. You never approve your own work.

## Procedure

1. Read `docs/loen/<topic>/loop.yaml` `quality_gates`.
2. Run each gate command; capture the exit code and a short output summary.
3. Write `5_check.md`:
   - `## Evidence` — a ```text block with each command, its exit code, and key output.
   - `## Result` — `PASS` if every gate exited 0, otherwise `FAIL`.
4. **Dispatch the `verifier` subagent** with a bounded capsule
   (`loen_capsules.render_capsule(topic_dir, "verifier", question)`) — never chat history —
   and **`LOEN_ROLE=verifier` in its environment** so `tool-guard` constrains it to
   `stages.check.roles` (the main-session worker, having no role, orchestrates unconstrained).
   When `verifier_isolation: microvm`, run it via `scripts/verify_microvm.sh`. The verifier
   writes `evidence/verifier-verdict.md` and returns `VERDICT: APPROVE|REJECT`.

## Output

Report the gate result (`PASS`/`FAIL`), the verifier `VERDICT`, and that `loop-reflect`
decides next. Both the gates and the verifier must agree before the loop can terminate.

The parent (never this hook) records a `verification` event on the topic's wiki task page
`reference/tasks/<topic>` with the gate result and verifier `VERDICT` — this is a material
stage boundary per the Task Log rule.
