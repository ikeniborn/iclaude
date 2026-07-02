# Loop Engineering (loen)

`loen` is an in-repo Claude Code plugin (`plugin/loen/`, marketplace `iclaude`) that runs a
controlled `Plan → Act → Check → Report` agent loop with an independent verifier.

## Install

The plugin ships with the repo. Enable it at user scope through the plugin system
(marketplace `iclaude`, plugin `loen`). It installs to
`.nvm-isolated/.claude-isolated/plugins/cache/iclaude/loen/<version>/`.

## Use

- `/loop-delivery <task>` — the executor. The `planner` subagent fills a `loop.yaml`
  contract, you approve scope + budget, the worker makes the smallest diff, `quality_gates`
  + the independent `verifier` check it, and a report is produced.
- `/loop-repair <failure description>` — fix a failing test / CI / regression:
  reproduce first, isolate, minimal fix, regression test (mode `repair`,
  `budget.max_iterations`, default 3).
- `/loop-autoresearch <metric goal>` — improve one numeric metric:
  baseline → hypothesis → one bounded change → fixed eval → compare → keep/revert
  (mode `research`, `budget.max_experiments`, default 5). Metrics travel as JSONL:
  the eval appends to `$LOEN_METRICS_PATH` (per-iteration `metrics.jsonl`); every
  experiment is a record in `experiments.jsonl`, appended by the deterministic
  `scripts/log_experiment.py`.
- `loen:audit plan|act|check|result` — validate a stage (mode-aware), gate progression,
  and regenerate `docs/loen/<run-id>/report.html`.
- `/loen:loop-goal` — optional accelerator: print a ready-to-paste, evidence-first
  `/goal` string generated deterministically from the active, approved `loop.yaml`
  (`scripts/make_goal.py`), plus a session-scoped `/loop` polling recipe for
  long-running gates. Never bootstraps a run, never submits `/goal` itself.

## Artifacts

All results live under `docs/loen/<run-id>/` (run-id = `<YYYY-MM-DD>-<topic>`):

| Path | Content |
|---|---|
| `loop.yaml` | the contract (planner-filled, human-approved) |
| `plan.md` | the step plan |
| `state.md` | append-only attempt/decision log |
| `iterations/iter-NN/{diff.patch,gates.log,verifier.md}` | per-iteration evidence |
| `iterations/iter-NN/metrics.jsonl` | research: eval JSONL events + one `summary` line (baseline lives in `iter-00`) |
| `experiments.jsonl` | research: run-level experiment stream (baseline + one record per experiment) |
| `report.html` | consolidated human-readable report |
| `pr-summary.md` | PR-ready summary |

Templates ship inside the plugin (not scaffolded into the project). A PreToolUse hook
(`loop-guard.py`) hard-enforces the layout/naming within the active topic and the loop's
`mutable_scope`/`protected_scope`. It is a no-op in non-loop repos.

## Subagents

`planner` (fable — strongest reasoning where the contract and decomposition are authored),
`explorer` (haiku — cheap evidence gathering), `verifier` (opus — stronger judge, and
model-diverse from a typically-fable worker session, preserving worker ≠ judge diversity) —
all read-only, isolated context; the worker (main session) is the single writer. The
frontmatter `model:` is a default and always overridable; on Claude Code versions without
the `fable` alias the model falls back per harness rules.

## Scope

Shipped: delivery (`loop-delivery`), repair (`loop-repair`), research
(`loop-autoresearch`), verifier, guard, `/goal`+`/loop` wrapping (`loop-goal` +
`make_goal.py`). Verifier microVM isolation and governance/observability are later
increments.
