# Loop Engineering (loen)

`loen` is an in-repo Claude Code plugin (`plugin/loen/`, marketplace `iclaude`) that runs one
bounded task as a **stage-oriented durable-topic** loop: seven numbered artifacts under
`docs/loen/<topic>/`, an autonomous `loop-run` orchestrator, an independent verifier, and six
hook-enforced guardrails. See `docs/architecture.md` for the operating model.

## Install

The plugin ships with the repo. Enable it at user scope through the plugin system
(marketplace `iclaude`, plugin `loen`). The `iclaude` marketplace is a `directory` source, so
Claude Code loads the plugin straight from the repo checkout (`plugin/loen/`).

User-facing docs ship with the plugin: `plugin/loen/README.md` (English) and
`plugin/loen/README.ru.md` (Russian).

## Use

The loop has one human gate — plan approval — after which `loop-run` executes autonomously.

**Configurators (entry points, thin — set `mode`, delegate to the pipeline):**

- `/loen:loop-delivery <task>` — deliver one bounded change (mode `delivery`).
- `/loen:loop-repair <failure>` — fix a failing test / CI / regression, reproduce-first
  (mode `repair`).
- `/loen:loop-autoresearch <metric>` — improve one numeric metric via a fixed eval
  (mode `research`).
- `/loen:loop-review <diff/PR>` — review a diff / branch / PR (mode `review`).

Each chains: configurator → `loop-start` (bootstrap + approval gate) → **auto** `loop-run` →
`7_result.md` (Done) or `handoff.md`.

**Pipeline skills (individually invocable — resumability + manual drive):**

- `/loen:loop-start <topic>` — bootstrap the topic, write `1_goal`/`2_context`, delegate
  `3_plan.md` to `loop-plan`, hold the approval gate, arm the contract
  (`run.plan_approved`, `run.plan_hash`).
- `/loen:loop-run` — autonomous orchestrator: preflight the approved contract, then drive
  `act → check → reflect` to terminal.
- `/loen:loop-plan` / `loop-act` / `loop-check` / `loop-reflect` — the single stage owners.
- `/loen:loop-status` — read-only state summary from disk.

**Cross-cutting:**

- `loen:audit plan|act|check|result` — manual stage re-validator (`OK` / `needs_work`). Inside
  `loop-run` this gating is automatic (hooks + verifier).
- `/loen:governance [--triage]` — cross-topic dashboard from `scripts/loen_stats.py` →
  `docs/loen/governance.html`; owns the `governance:` recurrence policy for recurring topics;
  `--triage` proposes next actions (proposals only). Offline-first.

## Artifacts

All state lives under `docs/loen/<topic>/`:

| Path | Content |
|---|---|
| `1_goal.md` | user request + success criteria |
| `2_context.md` | durable facts, constraints, relevant files |
| `3_plan.md` | one bounded plan: `## Steps` + `## Checks` (approval gate) |
| `4_act.md` | action taken, changed paths, commands |
| `5_check.md` | evidence + result (`PASS` sentinel) |
| `6_reflect.md` | decision keep/fix/revert/handoff |
| `7_result.md` | terminal outcome (`Done` sentinel) |
| `loop.yaml` | the machine-readable contract |
| `handoff.md` | non-terminal exit — human decision required |
| `audit.html` | regenerated report |
| `attempts.jsonl` | append-only iteration log |
| `evidence/` | verifier output (`verifier-verdict.md`, gate logs, metrics) |

Top level: `docs/loen/current` (active-topic pointer), `docs/loen/governance.html`
(cross-topic dashboard).

Templates ship inside the plugin (`assets/templates/`). Six hooks + a shared library
(`loen_common` / `loen_artifacts` / `loen_capsules`) enforce the contract; `LOEN_MODE`
(`off`/`advisory`/`enforce`/`strict`) grades enforcement. The plugin is inert without a
`loop.yaml`.

## Roles

The worker is the main session (the only writer). Five read-only subagents: `planner` (fable),
`explorer` (haiku), `verifier` (opus), `reviewer` (opus), `researcher` (fable). Each is fed a
bounded capsule — durable-artifact text, never chat. `stages.<stage>.roles` binds which role
acts per stage.

## Hardening: verifier microVM isolation

Opt-in per topic: set `verifier_isolation: microvm` in `loop.yaml` (default `subagent`). With
`microvm`, the verifier runs headless inside an iclaude Firecracker microVM
(`scripts/verify_microvm.sh`) against a disposable snapshot — read-only by construction.
Requires the iclaude microVM install (KVM, Firecracker, images — see
`docs/functions/MICROVM.md`).

## Scope

Shipped: the 7-stage durable-topic pipeline (7 pipeline skills), four outcome configurators,
governance + audit, six hook-enforced guardrails with a graded `LOEN_MODE`, five role
subagents with capsule isolation, and opt-in verifier microVM isolation.
