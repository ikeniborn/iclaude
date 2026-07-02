# loen — Loop Engineering

Run one bounded engineering task as a controlled loop: **Plan → Act → Check → Report**,
against a machine-readable `loop.yaml` contract, judged by an independent verifier.

- `/loop-delivery <task>` — execute the loop (planner fills `loop.yaml`, you approve, worker
  makes the smallest diff, gates + verifier check it, report is generated).
- `loen:audit <stage>` — validate a stage (`plan|act|check|result`) and regenerate the
  human-readable `docs/loen/<run-id>/report.html`.

All results live under `docs/loen/<run-id>/`. Templates ship inside the plugin.
A PreToolUse hook hard-enforces the artifact layout/naming and the loop's mutable/protected
scope. See the repo `docs/functions/LOEN.md` for the full guide.
