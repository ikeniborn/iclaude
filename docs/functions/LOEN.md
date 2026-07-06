# Loop Engineering (loen)

`loen` is an in-repo Claude Code plugin (`plugin/loen/`, marketplace `iclaude`) that runs a
controlled `Plan → Act → Check → Report` agent loop with an independent verifier.

## Install

The plugin ships with the repo. Enable it at user scope through the plugin system
(marketplace `iclaude`, plugin `loen`). The `iclaude` marketplace is a `directory`
source, so Claude Code loads the plugin straight from the repo checkout
(`plugin/loen/`) — no versioned copy is placed under `plugins/cache/`.

User-facing docs ship with the plugin: `plugin/loen/README.md` (English) and
`plugin/loen/README.ru.md` (Russian).

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
- `/loen:governance [--triage]` — cross-run governance: the deterministic
  `scripts/loen_stats.py` aggregates every run under `docs/loen/` (success rate,
  keep/revert, handoff reasons, failure taxonomy from REJECT verdicts' numbered
  `REQUIRED FIXES:` items, protected-path alerts, layout-drift `foreign` list) and the
  skill renders the `docs/loen/governance.html` dashboard via `html-report`. The §10.3
  rows loen artifacts cannot back — cost/tokens and latency/VRAM — are explicitly n/a,
  never fabricated. `--triage` lists failing runs (last verdict REJECT, or absent while
  iterations exist) with proposed next actions (`/loen:loop-repair <failing command>`
  for repair-shaped failures; "review contract/budget" otherwise) — proposals only, the
  human executes. Offline-first: no network, no LLM in the aggregation.

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

Cross-run (top level, outside run dirs): `docs/loen/governance.html` — the governance
dashboard `/loen:governance` renders from `scripts/loen_stats.py` output. It joins
`current` and `RUNBOOK.md` in the hook's top-level canon set (early allow guard +
`canon_patterns()` entry; this Artifacts entry is the second leg of the canon sync —
`check_layout.sh` is unaffected because it validates inside one run dir). The
aggregator picks up handoff/stop reasons from `state.md` `## Attempts` lines of the
form `- handoff: <reason>` / `- stop: <reason>`.

## Subagents

`planner` (fable — strongest reasoning where the contract and decomposition are authored),
`explorer` (haiku — cheap evidence gathering), `verifier` (opus — stronger judge, and
model-diverse from a typically-fable worker session, preserving worker ≠ judge diversity) —
all read-only, isolated context; the worker (main session) is the single writer. The
frontmatter `model:` is a default and always overridable; on Claude Code versions without
the `fable` alias the model falls back per harness rules.

## Hardening: verifier microVM isolation

Opt-in per run: set `verifier_isolation: microvm` in `loop.yaml` (default `subagent`
keeps MVP behavior byte-for-byte). With `microvm`, `loen:audit check` runs the verifier
as a headless Claude Code session inside an iclaude Firecracker microVM (this plugin's
`scripts/verify_microvm.sh`) against a disposable snapshot of the tree — `git archive
HEAD` + tracked staged/unstaged changes + the run's `docs/loen/<run-id>/` evidence;
untracked files excluded. There is no sync-back channel: the judge is read-only **by
construction**, not by convention. Requires the iclaude microVM install (KVM,
Firecracker, images — see `docs/functions/MICROVM.md`). `loen:audit plan` validates the
key and host capability up front; a VM failure at check time yields `needs_work` with
the failure log — never a silent fallback to the in-session subagent. Cost: VM boot +
snapshot add seconds-to-tens-of-seconds per check iteration, which is why the mode is
opt-in.

## Scope

Shipped: delivery (`loop-delivery`), repair (`loop-repair`), research
(`loop-autoresearch`), verifier, guard, `/goal`+`/loop` wrapping (`loop-goal` +
`make_goal.py`), opt-in verifier microVM isolation (`verifier_isolation: microvm`),
governance/observability (`/loen:governance` + `loen_stats.py` →
`docs/loen/governance.html`).
