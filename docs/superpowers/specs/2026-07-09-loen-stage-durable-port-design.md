---
review:
  stage: spec
  spec_hash: 6c5950118645cca0
  last_run: 2026-07-09
  phases:
    structure: {status: passed}
    coverage: {status: passed}
    clarity: {status: passed}
    consistency: {status: passed}
  findings:
    - id: F-001
      phase: consistency
      severity: WARNING
      section: "3. Contract — loop.yaml"
      section_hash: f1743596d4e387db
      fragment: "stages: act: [worker] (schema) vs stages.<stage>.roles (loop-gate/tool-guard/§5)"
      text: "The loop.yaml schema binds stage roles as a direct list (stages.act: [worker]), but loop-gate.py, tool-guard.py and §5 reference stages.<stage>.roles — a nested roles: key that does not exist in the schema."
      fix: "Unify the path: either nest roles under stages.<stage>.roles: in the schema, or change all hook and §5 references to stages.<stage>."
      verdict: fixed
      verdict_at: 2026-07-09
    - id: F-002
      phase: consistency
      severity: WARNING
      section: "3. Contract — loop.yaml"
      section_hash: f1743596d4e387db
      fragment: "mutable_scope/protected_scope at top level AND under permissions.filesystem"
      text: "mutable_scope/protected_scope are declared twice — at the loop.yaml top level and again under permissions.filesystem — with no stated source of truth (validate_run_contract checks the top-level; scope-guard reads permissions.filesystem)."
      fix: "Declare one authoritative location, or state explicitly that permissions.filesystem mirrors the top-level values so they cannot diverge."
      verdict: fixed
      verdict_at: 2026-07-09
    - id: F-003
      phase: consistency
      severity: WARNING
      section: "5. Agents / roles"
      section_hash: 8285d71e77a24a7e
      fragment: "The four subagent roles are read-only (table lists 5: explorer, planner, verifier, reviewer, researcher)"
      text: "Prose says 'The four subagent roles are read-only', but the agents table lists five read-only subagents (explorer, planner, verifier, reviewer, researcher). Ambiguous whether the verifier is counted (L3 vs L1)."
      fix: "Say 'five subagent roles', or clarify that 'four' means the L1 subagents (planner/explorer/reviewer/researcher) excluding the L3 verifier."
      verdict: fixed
      verdict_at: 2026-07-09
    - id: F-004
      phase: coverage
      severity: WARNING
      section: "2. Skill set"
      section_hash: 199066281cb33745
      fragment: "loop-start 'dispatch planner -> 3_plan' vs loop-plan Writes: 3_plan.md"
      text: "Both loop-start (Responsibility: 'dispatch planner -> 3_plan') and loop-plan (Writes: 3_plan.md) claim to produce 3_plan.md; the relationship (does loop-start invoke loop-plan?) is unstated."
      fix: "State that loop-start delegates 3_plan generation to loop-plan (or the planner) and name the single writer of 3_plan.md."
      verdict: fixed
      verdict_at: 2026-07-09
    - id: F-005
      phase: clarity
      severity: WARNING
      section: "6. Auto-run mechanics"
      section_hash: 56ac68b43bd51984
      fragment: "if compaction is a risk, loop-run optionally emits a native /goal ... for large budgets"
      text: "The native-/goal cross-turn fallback triggers 'if compaction is a risk' / 'for large budgets' with no measurable threshold, leaving the activation criterion vague."
      fix: "Give a concrete trigger, e.g. budget.max_iterations > N or estimated context tokens > threshold."
      verdict: fixed
      verdict_at: 2026-07-09
    - id: F-006
      phase: clarity
      severity: INFO
      section: "4. Hook architecture"
      section_hash: 25e782e7dafc9784
      fragment: "make_goal.py — migrates ... or is removed if the fallback is inlined. (Resolved during planning.)"
      text: "The fate of make_goal.py is explicitly deferred to planning ('or is removed if the fallback is inlined'); acceptable for a design spec but leaves one script's disposition undecided."
      fix: "Resolve during planning; the plan's scripts step must pick migrate-vs-remove for make_goal.py with a DoD."
      verdict: open
      verdict_at: null
    - id: F-007
      phase: coverage
      severity: INFO
      section: "7. Migration, tests, versioning"
      section_hash: 3cacf33c7db95181
      fragment: "Add docs/architecture.md ... Update docs/functions/LOEN.md"
      text: "docs/architecture.md (new) and the docs/functions/LOEN.md update are documentation deliverables beyond the brainstorm's stated docs task, which mandated only the two READMEs. Reasonable elaboration, flagged for traceability."
      fix: "Confirm these extra docs are in scope; otherwise drop them."
      verdict: open
      verdict_at: null
chain:
  intent: n/a
  spec: docs/superpowers/specs/2026-07-09-loen-stage-durable-port-design.md
---
# loen — Port to Stage-Oriented Durable-Topic Model (adapted from icodex)

**Date:** 2026-07-09
**Status:** approved (design)
**Topic key:** `loen-stage-durable-port`
**Target version:** 1.0.0 (breaking change from 0.5.x)

## Problem

The current `plugin/loen` (Claude Code plugin) is **outcome-oriented**: six coarse skills
(`loop-delivery`, `loop-repair`, `loop-autoresearch`, `loop-goal`, `audit`, `governance`),
each of which drives the entire Plan→Act→Check→Report loop internally. State lives in a
single `state.md` plus per-iteration folders `docs/loen/<run-id>/iterations/iter-NN/`, and a
single fail-open `PreToolUse` hook (`loop-guard.py`) is the only enforcement.

The sibling project `icodex/plugins/loen` (a Codex plugin) implements a different, more robust
**operating principle**: a fine-grained, **stage-oriented durable-topic** model. State is
durable in files (not chat), the coarse outcomes become thin configurators over a shared
7-stage pipeline, enforcement is split across a small library of specialized hooks reading a
rich `loop.yaml` contract, roles are isolated via bounded context "capsules", and completion
is a written artifact rather than a claim.

**Goal:** port the icodex operating principle into `plugin/loen`, adapted to the Claude Code
runtime, and additionally make the run stage **execute automatically** after the plan is
approved.

## Decisions (locked)

1. **Adapted port, not 1:1 copy.** icodex is a Codex plugin (WASM/`wasmtime` isolation,
   `apply_patch`, `.toml` agents, `CODEX_HOME`); iclaude is a Claude Code plugin
   (`.claude-plugin`, Firecracker microVM, `Write`/`Edit`/`Bash`, `.md` agents,
   `CLAUDE_PLUGIN_ROOT`). Take the icodex *principle* — stage decomposition, 7 numbered
   artifacts, durable-topic, multi-hook enforcement, capsules, roles — and implement it under
   the Claude Code runtime. Keep iclaude's strong sides: microVM verifier, offline governance
   dashboard, and the native-autonomy bridge (formerly `/loop-goal`).
2. **Clean replace (breaking, v1.0.0).** The old `docs/loen/<run-id>/` layout (state.md +
   `iterations/`) is not supported. Outcome skills become thin configurators over the new
   pipeline. Old tests are rewritten to the new layout.
3. **Auto-run after plan approval.** One human gate: a person approves `3_plan.md` in
   `loop-start`. Then `loop-run` autonomously drives `act→check→reflect` in a loop until
   `7_result.md` (done) or `handoff.md`. The verifier judges each iteration. Human intervention
   otherwise only at the final PR review.
4. **Full stage skill set** (granular, individually invocable — resumability + manual drive).
5. **READMEs are a required deliverable.** After the rework, `plugin/loen/README.md` and
   `plugin/loen/README.ru.md` are both updated to the new process schema (stage pipeline +
   auto-run) and dependencies (library, hooks, agents, scripts), kept in sync (English +
   Russian translation of the same content).

## The core shift (one sentence)

From *"a skill that performs an outcome and remembers it in chat"* to *"a durable,
contract-governed, hook-enforced 7-stage topic where coarse outcomes become configurators over
the same file-backed pipeline, roles are isolated by capsule, and completion is a written
artifact — with the run stage executing automatically once the plan is approved."*

---

## 1. Artifact model

### Durable topic (replaces dated run-id)

- Path: `docs/loen/<topic>/` (durable slug; the date prefix of the old `<YYYY-MM-DD>-<topic>`
  run-id is dropped — a topic is resumable and lives across sessions).
- Active-loop signal: `loop.yaml: status: active` is the source of truth, **plus** a
  convenience pointer `docs/loen/current` — a plain text file holding one line: the active
  topic slug (replaces the old `docs/loen/current` symlink). Hooks run as separate processes
  per tool call, so env vars are not guaranteed between them; the `current` file gives O(1)
  active-topic discovery without scanning. `loop-start` writes it; `loop-run` clears/rewrites
  it on terminal.
- Slug rule: `validate_topic_slug` — lowercase kebab, `^[a-z0-9][a-z0-9-]*$`.

### Addressing & information flow

The single addressing scheme is the relative path `docs/loen/<topic>/` (relative to the repo
root; base root is env `LOEN_ARTIFACT_ROOT`, default `docs/loen`). Information reaches its
consumers three ways — always by path + file, never by chat history:

- **Orchestrator → subagent.** `loop-run` passes the subagent two things in its prompt: the
  relative topic path `docs/loen/<topic>/` and a rendered **capsule** (`render_capsule`, a
  bounded text digest of the artifacts). The subagent reads artifacts from that path via
  Read/Grep/Glob. Chat is not visible to it — this is the isolation boundary.
- **Hook ← tool event.** A PreToolUse hook receives the target edit path from the event;
  `topic_from_path("docs/loen/foo/4_act.md") → "foo"`, then reads `docs/loen/foo/loop.yaml`
  and enforces. All relative to the repo cwd.
- **Active-topic discovery** (`event_topic()` in `loen_common.py`), in priority order:
  1. env `LOEN_TOPIC` (active topic slug, when set);
  2. parse from the edited path (`topic_from_path`);
  3. `current_topic()` — read the `docs/loen/current` pointer, else scan
     `docs/loen/*/loop.yaml` for `status: active`.

### Seven numbered stage artifacts

```
docs/loen/<topic>/
  1_goal.md       # user request + success criteria
  2_context.md    # durable facts + constraints (relevant files live here)
  3_plan.md       # steps→verify + exact check commands  (APPROVAL GATE)
  4_act.md        # action taken, changed paths, commands
  5_check.md      # evidence + result (sentinel: PASS)
  6_reflect.md    # decision keep|fix|revert|handoff + reason + next step
  7_result.md     # terminal outcome + evidence files (sentinel: Done)
  loop.yaml       # machine-readable contract
  handoff.md      # non-terminal exit — human decision required
  audit.html      # regenerated report (replaces report.html)
  attempts.jsonl  # append-only iteration log (replaces iterations/iter-NN/)
  evidence/       # verifier output (verifier-verdict.md, gate logs, metrics)
```

Principle: **missing file = missing state** — a resume reads the disk, never "remembers" from
chat. Iterations are rows in `attempts.jsonl` plus the rewritten stage files (latest iteration
in `4_act`/`5_check`/`6_reflect`; history in the jsonl). `iter-NN/` folders are gone.

---

## 2. Skill set (13 skills, `loen:` namespace)

### Pipeline (7)

| Skill | Invoke | Responsibility | Writes |
|---|---|---|---|
| `loop-start` | `/loen:loop-start <topic>` | Bootstrap: validate slug, scaffold topic, write `1_goal`/`2_context`, **invoke `loop-plan`** (the single writer of `3_plan.md`, which dispatches `planner`), **plan approval gate**, commit `loop.yaml` with `status: active`, `run.plan_approved: true`, `run.plan_hash` | topic skeleton (delegates `3_plan.md` to `loop-plan`) |
| `loop-run` | `/loen:loop-run` | **Autonomous orchestrator.** Preflight the approved contract, then drive `act→check→reflect` in a loop to `7_result.md` or `handoff.md` | 4–7, handoff |
| `loop-plan` | `/loen:loop-plan` | goal+context → one bounded `3_plan.md` with exact verify commands | `3_plan.md` |
| `loop-act` | `/loen:loop-act` | Execute exactly one bounded action, record evidence | `4_act.md` |
| `loop-check` | `/loen:loop-check` | Run `quality_gates`, record exit codes / output summary | `5_check.md` |
| `loop-reflect` | `/loen:loop-reflect` | Decide keep/fix/revert/handoff; write result when complete | `6_reflect.md`, `7_result.md` |
| `loop-status` | `/loen:loop-status` | Read-only summary of topic state from disk | — |

### Configurators (outcome — thin; set `mode` and delegate into the pipeline)

| Skill | Invoke | mode |
|---|---|---|
| `loop-delivery` | `/loen:loop-delivery <task>` | `delivery` (default) |
| `loop-repair` | `/loen:loop-repair <failure>` | `repair` |
| `loop-autoresearch` | `/loen:loop-autoresearch <metric>` | `research` |
| `loop-review` | `/loen:loop-review <diff/PR>` | `review` (new) |

A configurator = "set `mode` + call `loop-start`, then `loop-run`". The chain:
`/loop-delivery <task>` → bootstrap → approve plan → **auto** `loop-run` → terminal.

### Cross-cutting (2)

| Skill | Invoke | Role |
|---|---|---|
| `governance` | `/loen:governance [--triage]` | Recurring policies (icodex) + offline dashboard across all topics (iclaude) |
| `audit` | `loen:audit <plan\|act\|check\|result>` | Manual stage re-validator (`OK`/`needs_work`). Inside `loop-run` gating is automatic (hooks + verifier); `audit` is the manual, human-driven check |

### Removed / repurposed

- `loop-goal` is removed as a standalone skill. Its "emit a native `/goal` string for
  cross-turn unattended autonomy" behavior folds into `loop-run` as an **optional fallback**
  for large budgets that risk context compaction. Default execution is the in-session loop.

---

## 3. Contract — `loop.yaml`

Adapted from the current iclaude schema, extended with the icodex driver/role/permission blocks:

```yaml
topic:                       # durable slug (was: name: <date>-<topic>)
mode: delivery               # delivery | repair | research | review
status: active               # active | done | handoff  (active-loop signal)
objective: ""                # one measurable end state
current_stage: goal          # goal|context|plan|act|check|reflect|result
context_sources: []          # files/docs the worker must read first
mutable_scope: []            # globs the worker MAY edit
protected_scope: []          # globs the worker MUST NOT edit
quality_gates: []            # commands that must exit 0
verifier_isolation: subagent # subagent (default) | microvm
eval_command: ""             # research mode: fixed eval
metrics: {primary: [], secondary: []}
budget:
  max_iterations: 3
  max_experiments: 5         # research mode
  max_wall_time_minutes: 90
  max_cost_usd: 5
stop_conditions: []
handoff_conditions: []       # schema / PII / license / architecture / prod-creds
rollback_policy: ""
run:                         # NEW — autonomy driver
  plan_approved: false       # auto-run refuses to start unless true
  plan_hash: ""              # binds execution to the approved 3_plan.md body
  state: prepare             # prepare|act|check|reflect|done|handoff
  max_passes: 3
  current_pass: 0
stages:                      # NEW — role bindings per stage (addressed as stages.<stage>.roles)
  act:     {roles: [worker]}
  check:   {roles: [verifier]}
  reflect: {roles: [reviewer]}
tools:                       # NEW — for tool-guard
  allowed: [Read, Grep, Glob, Bash, Write, Edit, MultiEdit]
  denied: []
permissions:                 # NEW — for scope-guard / permission-guard
  filesystem:                # MIRRORS the top-level mutable_scope/protected_scope
    mutable_scope: []        # single source of truth = the top-level lists; loop-start
    protected_scope: []      # copies them here so scope-guard reads one place. They cannot diverge.
  network: {mode: off, allowlist: []}
  shell: {allow: [], deny_patterns: []}
capsule:                     # NEW — bounded context payload for subagents
  required_fields: [topic, objective, mode, current_stage, mutable_scope,
                    protected_scope, quality_gates, relevant_files, last_evidence, question]
governance: {}               # only for recurring topics
logging:
  state_file: docs/loen/<topic>/attempts.jsonl
```

Scope lists are block-style YAML (the bespoke hook parser and shell guards expect block-style;
inline flow lists are tolerated but the planner emits block-style).

`validate_run_contract` (in `loen_artifacts.py`) is the authority: checks `run.plan_approved`,
`run.plan_hash` == `plan_body_hash(3_plan.md)`, valid mode, usable `mutable_scope`, verifier
command, positive budget, `rollback_policy` present, and mode-specific requirements (research
needs a `target:`-style stop condition; review needs a review scope).

---

## 4. Hook architecture (enforcement core)

Replaces the single fail-open `loop-guard.py`. Tool names adapt from Codex
(`apply_patch`/`shell`/`read`/`search`) to Claude Code
(`Write`/`Edit`/`MultiEdit`/`Bash`/`Read`/`Grep`/`Glob`).

### Shared library (`hooks/`)

| Module | Contents |
|---|---|
| `loen_common.py` | `mode()` (reads `LOEN_MODE`), `event_topic()` (env `LOEN_TOPIC` → path → `current_topic()` reading active `loop.yaml`), bespoke line-oriented YAML parser (no PyYAML dep), path helpers (`extract_paths`, `normalize_path`, `matches_any`, `is_loen_topic_path`, `topic_from_path`), `tool_class()` normalizing Claude Code tools → {edit, shell, read, search}, and `block_or_nudge(msg)` — the shared enforcement primitive (BLOCK=exit 2 in enforce/strict, print-only in advisory, silent in off) |
| `loen_artifacts.py` | `STAGE_FILES`, `validate_topic_slug`, `scaffold_topic`, `loop_yaml_text`, `validate_run_contract`, `render_audit` (regenerates `audit.html`), `upsert_todo_row` (idempotent `docs/TODO.md` row), `append_attempt` (attempts.jsonl), `plan_body_hash` |
| `loen_capsules.py` | `render_capsule(topic_dir, role, question)` — a bounded text block built from durable artifacts only (topic, objective, mode, current stage, mutable/protected scope, quality gates, relevant files from `2_context.md`, last evidence summary from `5_check.md`, and the specific question). This is the L1 isolation mechanism: a subagent is handed a fixed capsule, not chat history |

### Specialized hooks

| Hook | Event | Enforces | Detection |
|---|---|---|---|
| `loop-gate.py` | PreToolUse | Edits require an active loop (`status: active`); stage ordering (cannot write `N_*.md` while a lower-numbered artifact is missing); `7_result` requires `5_check` PASS; cannot jump `current_stage` past a missing artifact | `event_topic` + parsed proposed `stage:`/`current_stage:` |
| `scope-guard.py` | PreToolUse | Blocks edits to `protected_scope`; blocks edits outside `mutable_scope` (the topic's own dir is always allowed) | `permissions.filesystem` |
| `tool-guard.py` | PreToolUse | Tool class must be in `tools.allowed`; the acting role must be permitted for `current_stage` (`stages.<stage>.roles`) | `tools` / `stages`; role from event |
| `permission-guard.py` | PreToolUse | Shell `deny_patterns`, hardcoded `git reset --hard` block, network `mode: off` / `allowlist` (curl/wget/ssh/scp/nc host check), shell `allow` allowlist | `permissions.shell` / `permissions.network` |
| `evidence-gate.py` | **Stop** | On a "done"-signalling stop: requires `5_check.md`, `7_result.md`, a verifier verdict, and a non-empty `evidence/`. `strict` mode additionally requires distinct worker vs verifier identity | `event_topic`; inspects final markers |
| `audit-writer.py` | PostToolUse | (side-effecting) regenerates `audit.html` via `render_audit`, upserts the `docs/TODO.md` row | `event_topic` + `validate_topic_slug` |

### Graded `LOEN_MODE`

`off` (inert) / `advisory` (print only) / `enforce` (BLOCK=exit 2 — default) / `strict`
(enforce + worker≠verifier identity requirement). The current single fail-open behavior is
replaced by this graded ladder. All hooks share the prologue: `off` early-return →
`event_topic()` → `read_loop_artifact()` → mode-gated `block_or_nudge`.

### `hooks.json` wiring

```
PreToolUse  [Write|Edit|MultiEdit|Bash|Read|Grep|Glob]:
    loop-gate.py → scope-guard.py → tool-guard.py → permission-guard.py
PostToolUse [Write|Edit|MultiEdit|Bash]: audit-writer.py
Stop        [*]: evidence-gate.py
```

Order matters: gate → scope → tool → permission inbound, audit outbound, evidence at stop.

### Deterministic shell nets (kept)

- `check_layout.sh` — verifies every file under `docs/loen/<topic>/` matches a canonical path
  (catches Bash-written artifacts that bypass the PreToolUse hook).
- `guard_protected.sh` — quality-gate defense-in-depth: fails if `git diff` touches a
  `protected_scope` glob.
- `loen_stats.py` — offline governance aggregator (adapted to the topic layout).
- `log_experiment.py` — validating appender for research experiments (attempts / experiments).
- `verify_microvm.sh` — isolated verifier flow for `verifier_isolation: microvm`.
- `make_goal.py` — migrates into the `loop-run` native-`/goal` fallback, or is removed if the
  fallback is inlined. (Resolved during planning.)

---

## 5. Agents / roles (5 `.md`)

worker = the **main session** (the only writer); it is not a subagent. All five subagent roles
(explorer, planner, verifier, reviewer, researcher) are read-only.

| Agent | Model | Tools | Role / isolation |
|---|---|---|---|
| `explorer` | haiku | Read/Grep/Glob | evidence gathering, `path:line` digest (iclaude, kept) |
| `planner` | fable | Read/Grep/Glob | decomposition → `loop.yaml` + `3_plan` |
| `verifier` | opus | Read/Grep/Glob/Bash | independent per-iteration judge; L3 microVM optional |
| `reviewer` | opus | Read/Grep/Glob | **new** — reviews diff/PR → findings into `5_check`/`6_reflect` |
| `researcher` | fable | Read/Grep/Glob/Bash | **new** — research mode: metrics/experiments into `2_context`/`5_check` |

Isolation ladder: L0 same-session (worker) → L1 subagent + capsule (planner/explorer/reviewer/
researcher) → L3 Firecracker microVM (verifier, optional; the icodex WASM L3 maps to iclaude's
existing `verify_microvm.sh`). `stages.<stage>.roles` in `loop.yaml` binds which role may act
per stage (`act: [worker]`, `check: [verifier]`, `reflect: [reviewer]`).

---

## 6. Auto-run mechanics (`loop-run` state machine)

`loop-run` is a skill body that instructs the main agent (worker) to run a state machine — no
special runtime. The verifier is dispatched as a subagent on each check; hooks deterministically
enforce scope and evidence.

**Preflight (entry gate):** `validate_run_contract` — `run.plan_approved == true` AND
`plan_hash` matches the current `3_plan.md` body. Otherwise refuse: "approve the plan in
loop-start first." Auto-run therefore starts only from an approved plan.

**Loop (`run.state`):**

```
prepare → act → check → reflect ─┬─ keep + APPROVE ────────→ 7_result.md (status: done) STOP
   ↑                             │
   └──── REJECT & pass<max ──────┘   (current_pass++, required fixes feed back into act)
                                 │
                                 └─ budget exceeded / handoff_condition / REJECT past budget /
                                    gate needs human → handoff.md (status: handoff) STOP
```

- **act:** worker makes the smallest diff → `4_act.md` + a row in `attempts.jsonl`. scope-guard
  holds the boundaries.
- **check:** run `quality_gates` → `5_check.md`; dispatch the `verifier` subagent (fed a
  capsule, not chat) → `evidence/verifier-verdict.md`.
- **reflect:** read verdict + gates → `6_reflect.md`:
  - gates green AND verifier `APPROVE` → write `7_result.md`, `status: done`, stop.
  - `REJECT` and `current_pass < max_passes` → `current_pass++`, back to act with required fixes.
  - budget exhausted / a `handoff_condition` fired / `REJECT` past budget / a gate needs a human
    → write `handoff.md`, `status: handoff`, stop.
- Every transition updates `loop.yaml` (`run.state`, `run.current_pass`) so the loop is
  resumable after a compaction or interruption.

**Termination:** `7_result.md` (Done) or `handoff.md`. `evidence-gate.py` on Stop prevents
declaring "done" without `5_check` + `7_result` + a verifier verdict + a non-empty `evidence/`.

**Cross-turn survival (large budgets):** the in-session loop is the default. `loop-run` switches
to emitting and self-running a native `/goal` (this absorbs the old `loop-goal`) only when a
concrete threshold is crossed: `budget.max_iterations > 5` OR `budget.max_wall_time_minutes > 60`
(either implies the loop is likely to outlive one context window). Below both thresholds it stays
in-session.

---

## 7. Migration, tests, versioning

### Clean replace (breaking → v1.0.0)

- The old `docs/loen/<run-id>/` layout (state.md + `iterations/`) is unsupported. New layout is
  `docs/loen/<topic>/` with the 7 numbered artifacts.
- `loop-guard.py` is deleted, replaced by the 6 hooks + shared library.
- `loop-goal` is removed as a standalone skill.

### Test rewrite

| Old test | Fate |
|---|---|
| `test_loen_layout.sh` | → topic + 7 numbered paths |
| `test_loen_templates.sh` | → `1_goal`…`7_result` + `loop.yaml` + `handoff` |
| `test_loen_guard.sh`, `test_loen_hook.py` | → split into per-hook tests (6 hooks) |
| `test_loen_plugin.sh` | → new skill list (13) in `plugin.json` |
| `test_loen_stats.py` | → aggregator on the topic layout |
| `test_loen_experiment.py`, `test_loen_verify_microvm.sh` | keep (attempts.jsonl, microVM) |
| `test_loen_goal.py` | remove / repurpose (loop-goal removed) |

**New coverage:** slug validation + scaffold, stage-ordering gate, scope/tool/permission guards,
evidence-gate on Stop, audit-writer, capsule rendering, `validate_run_contract`
(plan_approved + plan_hash), the `loop-run` state machine
(`prepare→act→check→reflect→done/handoff`), and graded `LOEN_MODE` behavior.

### Documentation (mandatory)

- **Rewrite `plugin/loen/README.md` and `plugin/loen/README.ru.md`** (both, kept in sync) to
  the new process schema (stage pipeline + auto-run) and the new dependencies (shared library,
  6 hooks, 5 agents, scripts). English canonical + Russian translation of the same content.
  This is an explicit, required deliverable.
- Update `docs/functions/LOEN.md` to the new model.
- Add `docs/architecture.md` (the isolation ladder + operating model, mirroring icodex).
- Bump `plugin/loen/.claude-plugin/plugin.json` version to `1.0.0`.

## Implementation phases (for the plan)

1. Shared library (`loen_common.py`, `loen_artifacts.py`, `loen_capsules.py`).
2. Templates (`1_goal`…`7_result`, `loop.yaml`, `handoff.md`, `audit.html`).
3. Hooks (6 specialized) + `hooks.json`.
4. Agents (add `reviewer`, `researcher`; adjust `explorer`/`planner`/`verifier`).
5. Pipeline skills (`loop-start`, `loop-run`, `loop-plan`, `loop-act`, `loop-check`,
   `loop-reflect`, `loop-status`).
6. Configurators (`loop-delivery`, `loop-repair`, `loop-autoresearch`, `loop-review`) +
   `governance` + `audit`.
7. Scripts adaptation (`check_layout.sh`, `guard_protected.sh`, `loen_stats.py`,
   `log_experiment.py`, `verify_microvm.sh`; resolve `make_goal.py`).
8. Test rewrite + new coverage.
9. Docs: both READMEs, `docs/functions/LOEN.md`, `docs/architecture.md`, version bump.

## Out of scope

- Backward compatibility with the old `docs/loen/<run-id>/` layout.
- Auto-merge (the loop always ends at a human PR review).
- Full parity with icodex Codex-specific mechanics (WASM/`wasmtime`, `apply_patch`,
  `CODEX_HOME`) — these are mapped to Claude Code equivalents, not reproduced.
