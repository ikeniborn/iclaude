# loen — Loop Engineering

Run one bounded engineering task as a controlled loop: **Plan → Act → Check → Report**,
against a machine-readable `loop.yaml` contract, judged by an independent verifier.

- `/loop-delivery <task>` — execute one delivery task as a loop (planner fills
  `loop.yaml`, you approve, worker makes the smallest diff, gates + verifier check it,
  report is generated).
- `/loop-repair <failure description>` — fix a failing test / CI / regression:
  reproduce first → isolate → minimal fix → regression test (mode `repair`).
- `/loop-autoresearch <metric goal>` — improve one numeric metric:
  baseline → hypothesis → one bounded change → fixed eval → compare → keep/revert,
  logging every experiment to `experiments.jsonl` (mode `research`).
- `loen:audit <stage>` — validate a stage (`plan|act|check|result`), mode-aware, and
  regenerate the human-readable `docs/loen/<run-id>/report.html`.
- `/loen:loop-goal` — optional: generate a ready-to-paste, evidence-first `/goal`
  string from the active approved `loop.yaml` (deterministic `scripts/make_goal.py`),
  with a session-scoped `/loop` polling recipe for long-running gates. Never
  bootstraps a run, never submits `/goal` itself.
- `verifier_isolation: microvm` (`loop.yaml`, opt-in) — run the verifier headless inside
  an iclaude Firecracker microVM against a disposable snapshot of the tree: the judge
  cannot touch the worker's tree at all. Requires the iclaude microVM install; default
  `subagent` keeps the in-session verifier.

All results live under `docs/loen/<run-id>/`. Templates ship inside the plugin.
A PreToolUse hook hard-enforces the artifact layout/naming and the loop's mutable/protected
scope. See the repo `docs/functions/LOEN.md` for the full guide.
