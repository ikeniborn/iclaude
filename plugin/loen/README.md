# loen — Loop Engineering

Run one bounded engineering task as a controlled loop — **Plan → Act → Check → Report** —
pinned to a machine-readable `loop.yaml` contract, judged by an independent verifier, and
leaving a complete audit trail under `docs/loen/<run-id>/`.

Version 0.5.0 · [Русская версия](README.ru.md) · Full guide: `docs/functions/LOEN.md`

## Why loen

An unsupervised agent run drifts: it edits files it should not touch, reviews its own
work, declares success without evidence, and leaves nothing to audit afterwards. loen
closes each of those gaps by construction:

- **A contract instead of a chat.** The task is pinned to a `loop.yaml` a human approves
  before any edit: objective, editable scope, protected scope, quality gates, budget,
  stop and handoff conditions.
- **Worker ≠ judge.** The main session (the worker) is the only writer; an independent
  `verifier` subagent — a different model, isolated context — approves or rejects every
  iteration. Optionally the verifier runs inside a Firecracker microVM and cannot touch
  the worker's tree at all.
- **Deterministic guardrails, not promises.** A PreToolUse hook hard-blocks edits outside
  `mutable_scope`, any touch of `protected_scope`, and any artifact written to a
  non-canonical path. Shell scripts (`guard_protected.sh`, `check_layout.sh`) re-check
  the same invariants as quality gates.
- **Evidence, not claims.** Every iteration persists its diff, gate logs, and verifier
  verdict. The loop always ends at a human PR review — never auto-merge.

In a repo with no active loop the plugin is inert: the hook is a no-op until a loop
skill bootstraps a run.

## What it solves

| You need to… | Invoke | You get |
|---|---|---|
| Deliver one bounded change safely | `/loop-delivery <task>` | Smallest reviewed diff + PR-ready summary + report |
| Fix a failing test / CI / regression | `/loop-repair <failure description>` | Reproduced → minimal fix + regression test, root cause in `pr-summary.md` |
| Improve one numeric metric | `/loop-autoresearch <metric goal>` | Metric-backed kept changes + full experiment log (`experiments.jsonl`) |
| Validate a loop stage / refresh the report | `loen:audit plan\|act\|check\|result` | `OK` / `needs_work` verdict + regenerated `report.html` |
| Let the loop run multi-turn unattended | `/loen:loop-goal` | Ready-to-paste, evidence-first `/goal` string (you submit it) |
| Oversee all runs at once | `/loen:governance [--triage]` | `docs/loen/governance.html` dashboard; `--triage` proposes next actions |

## How it works

1. **Plan.** The `planner` subagent decomposes the task and fills `loop.yaml` from the
   plugin's template. **A human approves the contract (scope + budget) before any edit.**
   `loen:audit plan` must return `OK`.
2. **Act.** The worker makes the smallest diff toward the objective, staying inside
   `mutable_scope` — the loop-guard hook blocks anything else. The diff is saved as
   `iterations/iter-NN/diff.patch`.
3. **Check.** The contract's `quality_gates` run (output → `gates.log`); `loen:audit
   check` dispatches the independent `verifier`, whose `APPROVE`/`REJECT` verdict lands
   in `verifier.md`. Only verifier-confirmed issues are fixed; the cycle repeats within
   `budget.max_iterations`.
4. **Report.** On green gates + `APPROVE`, `loen:audit result` finalizes `report.html`
   and `pr-summary.md`. Budget exhaustion, a failing gate that needs a human decision,
   or any `handoff_conditions` trigger (schema / PII / license / architecture / prod
   credentials) stops the loop and hands off to the human.

## Install

The plugin ships inside the iclaude repo (`plugin/loen/`) and is registered in the
`iclaude` marketplace (root `.claude-plugin/marketplace.json`, a `directory` source —
Claude Code loads the plugin straight from the repo checkout). Enable it at user scope:

```bash
claude plugin marketplace add /path/to/iclaude
claude plugin install loen@iclaude
```

Requirements: Claude Code with plugin support, `python3` (all scripts are stdlib-only),
`git`, `bash`. Optional microVM isolation additionally needs the iclaude Firecracker
setup (see `docs/functions/MICROVM.md`).

## Usage

### `/loop-delivery <task>` — deliver one bounded change

The base loop. The planner drafts the contract, you approve it, the worker iterates
Act → Check until the verifier approves within budget.

**Expected result:** a minimal diff on your working tree, plus
`docs/loen/<run-id>/{loop.yaml,plan.md,state.md,report.html,pr-summary.md}` and
per-iteration evidence — everything a reviewer needs to trust the change.

### `/loop-repair <failure description>` — fix a failure (mode: repair)

`reproduce → isolate → minimal fix → regression test`. The failing command is recorded
up front and must appear among the quality gates; **no reproduction → stop** (never
"fix" what cannot be reproduced). Regression coverage is evidenced: either a new test
with logged inversion proof (stash the fix → test fails → pop → test passes) or the
originally-failing test itself. Default budget: 3 iterations.

**Expected result:** the originally-failing command exits 0, a regression test guards
it, `pr-summary.md` states the root cause and a rollback note.

### `/loop-autoresearch <metric goal>` — improve a metric (mode: research)

`baseline → hypothesis → one bounded change → fixed eval → compare → keep/revert`.
Exactly one primary metric (`<name>:max|min`), a numeric target, fixed eval command /
dataset / seed; eval assets sit in `protected_scope` so the loop can never "improve"
the metric by editing the ruler. Kept changes are committed; reverted ones stay logged
as data. The verifier re-runs the eval to confirm every claimed `keep` delta. Default
budget: 5 experiments.

**Expected result:** metric-backed kept changes (or a best-result report on budget
exhaustion), per-experiment metrics in `iterations/iter-NN/metrics.jsonl`, the full
experiment stream in `experiments.jsonl`, an experiments table in `report.html`.

### `loen:audit <stage>` — stage validator + live report

`stage ∈ plan | act | check | result`, mode-aware. Each stage returns `OK`/`needs_work`,
gates progression to the next stage, regenerates `report.html`, and appends to
`state.md`. This is also where the verifier is dispatched (`check`) and where the run is
finalized (`result`).

### `/loen:loop-goal` — optional multi-turn accelerator

Generates — deterministically, via `scripts/make_goal.py` — a ready-to-paste,
evidence-first `/goal` string from the active approved `loop.yaml`, plus a
session-scoped `/loop` polling recipe for long-running gates. It never bootstraps a run
and never submits `/goal` itself: granting multi-turn autonomy stays a human act.

### `/loen:governance [--triage]` — cross-run oversight

Aggregates every run under `docs/loen/` with the deterministic, offline
`scripts/loen_stats.py` (no network, no LLM) and renders `docs/loen/governance.html`:
success rate, research metric deltas, handoff reasons, failure taxonomy from REJECT
verdicts, protected-path alerts, layout drift. Cost/tokens and latency/VRAM are
explicitly n/a — never fabricated. `--triage` lists failing runs with proposed next
actions (e.g. `/loen:loop-repair <failing command>`) — proposals only, the human
executes.

## Artifacts

All results live under `docs/loen/<run-id>/` (run-id = `<YYYY-MM-DD>-<topic>`); the
active run is the `docs/loen/current` symlink.

| Path | Content |
|---|---|
| `loop.yaml` | the contract (planner-filled, human-approved) |
| `plan.md` | the step plan |
| `state.md` | append-only attempt/decision log |
| `iterations/iter-NN/{diff.patch,gates.log,verifier.md}` | per-iteration evidence |
| `iterations/iter-NN/metrics.jsonl` | research: eval JSONL events + one `summary` line |
| `experiments.jsonl` | research: run-level experiment stream (baseline + one record each) |
| `report.html` | consolidated human-readable report |
| `pr-summary.md` | PR-ready summary |
| `../governance.html` | cross-run dashboard (top level, outside run dirs) |

Templates ship as plugin assets — nothing is scaffolded into your project.

## Guardrails

- **`hooks/loop-guard.py`** (PreToolUse on `Write|Edit|MultiEdit`) — inside `docs/loen/`
  enforces canonical layout/naming for the active topic; outside it enforces
  `protected_scope` (deny wins) and `mutable_scope` from the active contract. Only a
  deliberate block (exit 2) stops an edit — a crash or timeout fails open, so the guard
  can never wedge your session.
- **`scripts/guard_protected.sh`** — quality-gate command that fails if `git diff HEAD`
  touches a protected glob (defense in depth behind the hook).
- **`scripts/check_layout.sh`** — deterministic filesystem net that catches
  non-canonical artifacts written via Bash (which bypasses PreToolUse hooks); run by
  `loen:audit` at every stage.
- **`verifier_isolation: microvm`** (`loop.yaml`, opt-in) — `scripts/verify_microvm.sh`
  runs the verifier as a headless Claude Code session inside an iclaude Firecracker
  microVM against a disposable snapshot of the tree: the judge is read-only **by
  construction**. A VM failure yields `needs_work` — never a silent fallback to the
  in-session verifier. Default `subagent` keeps the fast in-session judge.

## Subagents

All three run read-only in isolated context; the worker (main session) is the single
writer. Frontmatter models are defaults and always overridable.

| Agent | Model | Role |
|---|---|---|
| `planner` | fable | decomposes the task, assesses risk, fills `loop.yaml` + step plan |
| `explorer` | haiku | cheap read-only evidence gathering, keeps worker context clean |
| `verifier` | opus | strict independent judge; may run gates; defaults to REJECT without evidence |

## Learn more

- `docs/functions/LOEN.md` — full user guide in the iclaude repo.
- `docs/functions/MICROVM.md` — the Firecracker setup used by microVM isolation.
- Design specs and methodology: `docs/superpowers/specs/2026-07-01-loen-*.md` and
  `docs/superpowers/notes/final_loop_engineering_methodology.md`.
