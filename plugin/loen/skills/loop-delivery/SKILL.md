---
name: loop-delivery
description: Use when delivering ONE bounded change — a feature, refactor, or chore — as a controlled, audited loop in any repo. Not for a failing test (use loop-repair) or a numeric metric (use loop-autoresearch).
---

# Loop Delivery

Run ONE bounded task as a controlled loop. You are the **worker** and the **only writer**.
Subagents (`planner`, `explorer`, `verifier`) run in isolated context and return text — you
persist their output. All artifacts go under `docs/loen/<run-id>/` (the loop-guard hook
enforces the layout).

## Steps

1. **Bootstrap the run.** Derive `<today>` via `date +%F`; `run-id = <today>-<topic>`
   (`<topic>` must be lowercase kebab-case, e.g. `fix-auth-bug` — the loop-guard hook
   only accepts run-ids matching `^\d{4}-\d{2}-\d{2}-[a-z0-9-]+$`).
   With **Bash** (not the Write tool) create the run dir and the pointer BEFORE any
   Write-tool artifact — the loop-guard hook blocks docs/loen writes when no run is active:
   `mkdir -p docs/loen/<run-id>/iterations && ln -sfn <run-id> docs/loen/current`.
   Copy the state skeleton from this skill's `assets/state.template.md` (the skill base
   directory is printed when this skill is invoked; `assets/` is a sibling of this SKILL.md)
   into `docs/loen/<run-id>/state.md`.
2. **Author the contract.** Dispatch the `planner` subagent (isolated), passing the task and
   the ABSOLUTE path to this skill's `assets/loop.template.yaml` (resolved from the skill
   base directory — not `${CLAUDE_PLUGIN_ROOT}`, which is unset outside hooks). Instruct the
   planner to emit `mutable_scope`/`protected_scope` as block-style YAML lists. It returns a
   filled `loop.yaml` + a plan. Validate the YAML parses, then write
   `docs/loen/<run-id>/loop.yaml` and `docs/loen/<run-id>/plan.md`.
3. **Human approval gate.** Show the contract (scope + budget). Ask the human to approve
   before any edit. Do not proceed without it.
4. **Run `loen:audit plan`** — must return `OK` before Act.
5. **Act.** Make the smallest diff toward the objective. When the change adds or alters
   behavior, work test-first: add a failing test that pins the objective, confirm it fails
   for the right reason, then write the smallest code that makes it pass. A pure refactor
   keeps the existing tests green; config/chore work with no behavioral surface is exempt.
   Stay in `mutable_scope` (the hook
   blocks otherwise). Save the iteration diff to
   `docs/loen/<run-id>/iterations/iter-NN/diff.patch` (`git diff > …`), where `iter-NN`
   is zero-padded to two digits (e.g. `iter-01`) — the hook and `check_layout.sh` reject
   anything else. Use `explorer` when you need code evidence without loading files into
   this context.
6. **Check.** Run the `quality_gates` from `loop.yaml`; capture output to
   `iterations/iter-NN/gates.log`. Then **run `loen:audit check`** — it dispatches the
   `verifier` and writes `iterations/iter-NN/verifier.md`.
7. **Fix.** Address only verifier-confirmed issues. Repeat Act→Check within
   `budget.max_iterations`.
8. **Report.** When gates are green and the verifier APPROVEs, **run `loen:audit result`**
   to finalize `report.html`, write `pr-summary.md`, and mark the `docs/TODO.md` row.

## Stop conditions
- All quality gates pass and the verifier APPROVEs → produce the PR-ready summary.
- A gate fails for a reason needing a human decision → stop.
- `budget` exceeded → stop, report the best result and the blocker.
- A `handoff_conditions` trigger (schema / PII / license / architecture / prod creds) →
  hard stop, ask the human. Never auto-merge.

## Red Flags — STOP

- Writing production code for a behavior change before a failing test exists → delete it; restart test-first.
- Editing a `protected_scope` path → stop; the scope IS the contract.
- Weakening or skipping a quality gate to go green → never; fix the code.
- Editing the diff you are verifying, or self-approving instead of the independent verifier → stop; only the verifier judges.
- Reporting the task done without green gates AND a verifier APPROVE for the final iteration → not done; re-run, don't claim.
- Auto-merging, or proceeding past a `handoff_conditions` trigger (schema / PII / license / architecture / prod-creds) → hard stop, ask the human.
- Continuing past `budget` → stop; report the best result and the blocker.
