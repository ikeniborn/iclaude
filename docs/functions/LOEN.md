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
- `loen:audit plan|act|check|result` — validate a stage, gate progression, and regenerate
  `docs/loen/<run-id>/report.html`.

## Artifacts

All results live under `docs/loen/<run-id>/` (run-id = `<YYYY-MM-DD>-<topic>`):

| Path | Content |
|---|---|
| `loop.yaml` | the contract (planner-filled, human-approved) |
| `plan.md` | the step plan |
| `state.md` | append-only attempt/decision log |
| `iterations/iter-NN/{diff.patch,gates.log,verifier.md}` | per-iteration evidence |
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

MVP ships delivery + verifier + guard. `loop-repair` / `loop-autoresearch` and governance
are later increments.
