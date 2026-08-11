# loen — Loop Engineering

Run one bounded engineering task as a **stage-oriented durable-topic loop**. State lives in
seven numbered artifacts under `docs/loen/<topic>/` — never in chat. After one human gate
(plan approval) the `loop-run` orchestrator drives `Act → Check → Reflect` autonomously to a
written result, judged by an independent verifier and enforced by six deterministic hooks.

Version 1.0.0 · [Русская версия](README.ru.md) · Full guide: `docs/functions/LOEN.md` ·
Architecture: `docs/architecture.md`

## Why loen

An unsupervised agent run drifts: it edits files it should not touch, reviews its own work,
declares success without evidence, and forgets its progress when the context compacts. loen
closes each gap by construction:

- **Durable state, not chat.** Every unit of work is a *topic* under `docs/loen/<topic>/`,
  carried through seven numbered stage files (`1_goal … 7_result`). *Missing file = missing
  state* — a resume reads the disk, never the conversation.
- **A contract instead of a chat.** The task is pinned to a `loop.yaml` a human approves
  before any edit: objective, editable/protected scope, quality gates, budget, stop and
  handoff conditions, role bindings, tool and permission policy.
- **Autonomous after one gate.** `loop-start` holds the single approval gate; then `loop-run`
  runs `Act → Check → Reflect` on its own until `7_result.md` (Done) or `handoff.md`.
- **Worker ≠ judge.** The main session (the worker) is the only writer; an independent
  `verifier` subagent — different model, isolated context, fed a bounded capsule — approves
  or rejects each iteration. Optionally it runs inside a Firecracker microVM.
- **Deterministic guardrails, graded.** Six hooks read the contract and enforce scope, tools,
  roles, shell/network policy, stage ordering, and final evidence — graded by `LOEN_MODE`
  (`off`/`advisory`/`enforce`/`strict`). The loop always ends at a human PR review — never
  auto-merge.

Without a `loop.yaml` the plugin is inert.

## What it solves

| You need to… | Invoke | You get |
|---|---|---|
| Deliver one bounded change safely | `/loen:loop-delivery <task>` | Smallest reviewed diff, evidence-backed `7_result.md` |
| Fix a failing test / CI / regression | `/loen:loop-repair <failure>` | Reproduced → minimal fix + regression test |
| Improve one numeric metric | `/loen:loop-autoresearch <metric>` | Metric-backed kept changes + experiment log |
| Review a diff / branch / PR | `/loen:loop-review <diff/PR>` | Findings + disposition as durable artifacts |
| Run an approved loop autonomously | `/loen:loop-run` | `Act → Check → Reflect` to `7_result.md` / `handoff.md` |
| Check a topic's state | `/loen:loop-status` | Stage, latest evidence, next action (read-only) |
| Validate one stage manually | `loen:audit plan\|act\|check\|result` | `OK` / `needs_work` + regenerated `audit.html` |
| Oversee all topics at once | `/loen:governance [--triage]` | `docs/loen/governance.html`; `--triage` proposes next actions |

## How it works

1. **Start.** A configurator (`loop-delivery`/`repair`/`autoresearch`/`review`) sets the
   `mode` and invokes `loop-start`, which validates the topic slug, scaffolds
   `docs/loen/<topic>/`, writes `1_goal.md` + `2_context.md`, delegates `3_plan.md` to
   `loop-plan`, and **holds the one human approval gate**. On approval it arms the contract
   (`run.plan_approved: true`, `run.plan_hash`).
2. **Run (autonomous).** `loop-run` preflights the approved contract
   (`validate_run_contract`), then loops the state machine:
   - **act** (`loop-act`) — the worker makes the smallest diff inside `mutable_scope` →
     `4_act.md`;
   - **check** (`loop-check`) — `quality_gates` run → `5_check.md`; the `verifier` subagent
     judges with a bounded capsule → `evidence/verifier-verdict.md`;
   - **reflect** (`loop-reflect`) — gates `PASS` + verifier `APPROVE` → `7_result.md` (Done);
     `REJECT` within budget → loop back to act; budget/handoff → `handoff.md`.
   Each transition updates `loop.yaml` `run.state`/`run.current_pass`, so the loop resumes
   after a compaction.
3. **Terminate.** `7_result.md` (Done) or `handoff.md` (human decision). The Stop hook blocks
   a "done" claim without `5_check` + `7_result` + a verifier verdict + evidence.

## Install

The plugin ships inside the iclaude repo (`plugin/loen/`), registered in the `iclaude`
marketplace (a `directory` source). Enable it at user scope:

```bash
claude plugin marketplace add /path/to/iclaude
claude plugin install loen@iclaude
```

Requirements: Claude Code with plugin support, `python3` (all scripts/hooks are stdlib-only),
`git`, `bash`. Optional microVM isolation additionally needs the iclaude Firecracker setup
(see `docs/functions/MICROVM.md`).

## Configuration

`LOEN_MODE` grades hook enforcement: `off` (inert) · `advisory` (print only) · `enforce`
(block, default) · `strict` (+ require distinct worker/verifier identity). `LOEN_ARTIFACT_ROOT`
overrides the artifact root (default `docs/loen`).

## Artifacts

All state lives under `docs/loen/<topic>/`:

| Path | Content |
|---|---|
| `1_goal.md … 7_result.md` | the seven numbered stage artifacts |
| `loop.yaml` | the machine-readable contract |
| `handoff.md` | non-terminal exit — human decision required |
| `audit.html` | regenerated report |
| `attempts.jsonl` | append-only iteration log |
| `evidence/` | verifier verdict, gate logs, metrics |
| `../current` | pointer to the active topic slug |
| `../governance.html` | cross-topic dashboard |

Templates ship as plugin assets (`assets/templates/`) — nothing is scaffolded into your
project until a loop starts.

## Components

**Skills (13):** pipeline — `loop-start`, `loop-run`, `loop-plan`, `loop-act`, `loop-check`,
`loop-reflect`, `loop-status`; configurators — `loop-delivery`, `loop-repair`,
`loop-autoresearch`, `loop-review`; cross-cutting — `governance`, `audit`.

**Hooks + shared library:** `loen_common` / `loen_artifacts` / `loen_capsules` back six hooks —
`loop-gate`, `scope-guard`, `tool-guard`, `permission-guard` (PreToolUse), `evidence-gate`
(Stop), `audit-writer` (PostToolUse). Deterministic shell nets `check_layout.sh` and
`guard_protected.sh` re-check the layout and protected scope for Bash-written artifacts.

**Agents (5, read-only; the worker is the main session):**

| Agent | Model | Role |
|---|---|---|
| `planner` | fable | decomposes the task, fills `loop.yaml` + step plan |
| `explorer` | haiku | cheap read-only evidence gathering |
| `verifier` | opus | strict independent judge; may run gates; defaults to REJECT without evidence |
| `reviewer` | opus | reviews the diff/PR at reflect; records findings + disposition |
| `researcher` | fable | research mode: runs the fixed eval, records metrics |

Each subagent is fed a bounded **capsule** (durable-artifact text, never chat).

**Scripts:** `loen_stats.py` (governance aggregator), `log_experiment.py` (experiment log),
`verify_microvm.sh` (optional isolated verifier), `check_layout.sh`, `guard_protected.sh`.

## Learn more

- `docs/architecture.md` — operating model, isolation ladder, hook map.
- `docs/functions/LOEN.md` — full user guide.
- `docs/functions/MICROVM.md` — the Firecracker setup used by microVM isolation.
