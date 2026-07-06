---
name: loop-goal
description: Use when an active, human-approved loen run should keep going multi-turn on its own — wraps it in Claude's native /goal from loop.yaml. Optional; never bootstraps a run or submits /goal itself.
---

# Loop Goal — /goal + /loop wrapper (optional)

Wrap the ACTIVE loen run in a native `/goal` condition so "keep going until the
gates are green" runs multi-turn without hand-holding. Invoked as
`/loen:loop-goal` (optionally with an explicit run-id). This wrapper NEVER
weakens the loop protocol: `loen:audit` stages, the loop-guard hook, and the
human approval gate stay exactly as in the MVP — `/goal` only automates the
turn loop.

## Steps

1. **Preconditions.** An active run exists (`docs/loen/current` resolves to a
   run directory) whose contract was human-approved and whose `loen:audit plan`
   returned `OK` (both recorded in `docs/loen/<run-id>/state.md`). No active
   run → STOP and point to `/loop-delivery`, `/loop-repair`, or
   `/loop-autoresearch` — this skill wraps an existing run, it never bootstraps
   one. One goal run wraps ONE loen run: if the user passed a run-id that
   differs from the active run, REFUSE (mirror of the hook's cross-topic
   block).
2. **Generate.** Run the deterministic generator (the skill base directory is
   printed when this skill is invoked; the script is stdlib-only):
   `python3 <skill-base>/../../scripts/make_goal.py docs/loen/current/loop.yaml`.
   Exit 1 means the contract is not audit-plan shaped — report its stderr and
   stop. Show the produced string to the human VERBATIM for them to submit as
   `/goal …`. NEVER submit `/goal` yourself — it is a native user-level
   command; the human stays in control of granting multi-turn autonomy.
3. **Evidence-first briefing.** Alongside the string, restate the `/goal`
   mechanics: the `/goal` evaluator only reads the transcript — it runs no
   commands. During the goal run the worker MUST print every gate command, its
   exit code, and metric summaries into the conversation; a condition like
   "all tests pass" without printed evidence never evaluates true. The
   generated string already encodes this ("… prints each command's output
   summary as evidence") — do not trim it.
4. **`/loop` recipe (long-running gates).** For gates that poll external state
   (CI runs, deploys), offer: `/loop <interval> loen:audit check` with
   `<interval>` matched to the external system's cadence. The durability
   warning is MANDATORY: `/loop` is session-scoped — it dies with the session
   and recurring tasks auto-expire; durable scheduling belongs to Routines /
   OS schedulers / CI, outside this skill's scope.

## Guardrails

- The generated string always ends with the budget/stop clause, so the goal
  run hard-stops instead of looping forever; `handoff_conditions` keep
  hard-stopping as usual.
- Optional by construction: nothing in `loop-delivery`, `loop-repair`,
  `loop-autoresearch`, or `loen:audit` references this skill.
