---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-01-loen-loop-engineering-plugin-design.md
review:
  spec_hash: 654552a8347f5bac
  last_run: 2026-07-01
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - { id: F-001, phase: consistency, severity: WARNING, verdict: fixed, note: "tautology in the §9 cross-topic rule; reworded to <R>-segment == active run-id" }
    - { id: F-002, phase: clarity, severity: INFO, verdict: fixed, note: "run-id vs topic drift in §5.2; convergence reworded to topic" }
  verdict: OK
---
# loen — Loop Engineering Plugin — Design Spec

- **Topic:** `loen-loop-engineering-plugin`
- **Date:** 2026-07-01
- **Status:** design approved (brainstorming); ready for implementation planning
- **Source methodology:** `docs/superpowers/notes/final_loop_engineering_methodology.md`
- **Scope of this spec:** MVP increment only (increment A+B-min+C). Later increments listed in §3.

---

## 1. Summary

`loen` ("loop engineering") packages the Loop Engineering methodology as a **self-contained,
publishable Claude Code plugin**. It gives any project a controlled agent loop —
`Goal → Context → Plan → Act → Check → Reflect/Fix → Stop/Handoff` — driven by a machine-readable
contract, executed by a worker, and judged by an **independent verifier** (worker ≠ judge).

Core principle (methodology): *the worker must not be the sole judge of its own work*. Success is
confirmed by deterministic gates plus an independent verifier subagent, with the human doing the
final PR review. No auto-merge.

The plugin ships everything (skills, agents, hooks, templates, guard script) as versioned plugin
assets. The **only** thing written into a target project is run **results**, under `docs/loen/`.

## 2. Delivery model

- **Form:** in-repo plugin at `plugin/loen/`, following the `plugin/iwiki/` precedent, registered in
  the repo-root `.claude-plugin/marketplace.json` (marketplace `iclaude`, `source: ./plugin/loen`).
- **Install:** standard marketplace install → cached at
  `.nvm-isolated/.claude-isolated/plugins/cache/iclaude/loen/<version>/`, enabled at **user scope**
  (always-on), tracked in `installed_plugins.json`. Installs "as if it were a marketplace plugin".
- **Publishable:** `plugin.json` carries full metadata (name, version, description, author, keywords,
  `license: MIT`, homepage/repository placeholders). **Zero hard dependencies** on iclaude `lib/`
  internals or on the `superpowers` plugin → the plugin directory can later be published to a public
  marketplace by copy.
- **Version sync:** `plugin.json.version` must equal the `loen` entry version in `marketplace.json`
  (enforced by the existing `scripts/check-plugin-version-sync.sh`, extended to cover `loen`).
- **Composition with superpowers:** OPTIONAL. If `superpowers:*` skills are present, `loop-delivery`
  MAY delegate to `superpowers:writing-plans` / `executing-plans` / `verification-before-completion`.
  If absent, loen's own `planner` / `verifier` cover it. Never a hard dependency.

## 3. Scope

**MVP (this spec):**
- Plugin skeleton + marketplace registration (publishable).
- Skill `loop-delivery` (executor).
- Skill `audit` (per-stage validator + live HTML report).
- Subagents `planner`, `explorer`, `verifier` (distinct models, read-only, isolated context).
- Hook `loop-guard.py` (deterministic scope + layout/naming enforcement).
- Plugin assets: `loop.yaml` schema, `state.md` skeleton, `guard_protected.sh`, HTML report template.
- Artifact model under `docs/loen/`.

**Deferred (later increments, own spec each):**
- spec 2: skills `loop-repair`, `loop-autoresearch` (research loop, `experiments.jsonl`, metrics).
- spec 3 (optional): governance / observability (traces, dashboards, failure taxonomy). Tension with
  iclaude's offline/PII posture — may be dropped.

## 4. Artifact model

### 4.1 Where things live (hard split)

| Location | Contents | Property |
|---|---|---|
| **Plugin** `cache/iclaude/loen/<ver>/` | `loop.yaml` schema, `state.md` skeleton, `guard_protected.sh`, hooks, skills, agents, HTML report template — **all TEMPLATES** | read-only, install-time, versioned with plugin, read via `${CLAUDE_PLUGIN_ROOT}` |
| **Project** `docs/loen/<run-id>/` | run **RESULTS** only | written only by the worker, enforced by the hook |

`.agent-loop/` is **removed**. No template blanks are scaffolded into the project. There is no
`loen-init`. The run directory is created by `loop-delivery` at run start.

### 4.2 Per-run directory layout (per loop step)

```
docs/loen/
  current -> 2026-07-01-<topic>/      # pointer to the active run (hook/guard read from here)
  RUNBOOK.md                          # persistent, project check commands (optional; planner may infer)
  2026-07-01-<topic>/                 # RUN = <date>-<topic>  (== check-chain / TODO topic key)
    loop.yaml                         # contract (planner-filled -> human-approved)   [PLAN]
    plan.md                           # step plan (planner)                            [PLAN]
    state.md                          # append-only attempt/decision log               [CROSS]
    iterations/                       # per Act/Check cycle:
      iter-01/
        diff.patch                    # diff of this iteration                         [ACT]
        gates.log                     # command outputs + exit codes                   [CHECK]
        verifier.md                   # APPROVE/REJECT + findings                       [CHECK]
      iter-02/ ...
    experiments.jsonl                 # research mode: metrics before/after (spec 2)
    pr-summary.md                     # final PR-ready summary                          [REPORT]
    report.html                       # consolidated human-readable report             [REPORT]
```

Directory per step: `PLAN` → run root (`loop.yaml`, `plan.md`); `ACT`/`CHECK` → `iterations/iter-NN/`;
`REPORT` → run root (`report.html`, `pr-summary.md`).

### 4.3 Naming convention (traceability)

- **run-id = `<YYYY-MM-DD>-<topic>`** — single join key. Matches the `<topic>` in `docs/TODO.md` and
  the check-chain elaboration chain → IDD→SDD and loen artifacts cross-reference by topic.
- Iterations are strictly `iter-NN` (zero-padded, sequential).
- `loop.yaml.name == run-id`; `state.md` references `iter-NN`; `report.html` aggregates by run-id.
- Every artifact has a predictable name at a predictable path → the link between artifacts is
  traceable by path alone. This convention is **enforced by the hook** (§9), not left to the model.

## 5. Components

```
plugin/loen/
  .claude-plugin/plugin.json     # full publishable metadata
  README.md
  skills/
    loop-delivery/
      SKILL.md                   # executor: drives plan->act->check->report
      assets/
        loop.template.yaml       # loop-card schema (methodology §1.2)
        state.template.md        # state.md skeleton
        report.template.html     # base for the html-report render
    audit/
      SKILL.md                   # loen:audit plan|act|check|result — validator + report updater
  agents/
    planner.md                   # decompose, risks, fill loop.yaml, plan.md
    explorer.md                  # read-only evidence gathering
    verifier.md                  # strict independent checker
  hooks/
    hooks.json                   # PreToolUse: Write|Edit|MultiEdit -> loop-guard.py
    loop-guard.py                # deterministic scope + layout/naming enforcement
  scripts/
    guard_protected.sh           # git-diff protected-path guard (defense-in-depth)
```

### 5.1 Skill `loop-delivery` (executor)

Independent of the IDD→SDD chain (works in any repo). Steps:
1. Determine run-id from `<date>-<topic>`; create `docs/loen/<run-id>/`; set `docs/loen/current`.
2. Dispatch `planner` (isolated) → fill `loop.yaml` + `plan.md`. Worker persists.
3. **`loen:audit plan`** gate → must return `OK` (contract sane + human-approved) before Act.
4. Act: worker makes the smallest diff. Each edit passes `loop-guard.py`. Persist `iterations/iter-NN/diff.patch`.
5. Check: run `quality_gates` → `gates.log`; **`loen:audit check`** dispatches `verifier` → `verifier.md`.
6. Fix only verifier-confirmed issues, within `budget.max_iterations`.
7. **`loen:audit result`** when gates green + verifier `APPROVE` → finalize `report.html` + `pr-summary.md`.
8. Stop conditions: gates pass; human-decision gate; budget exceeded; handoff condition.

### 5.2 Skill `audit` (validator + live report) — `loen:audit <stage>`

Mirrors the existing `check-chain` pattern, applied to the execution loop instead of the elaboration
chain. Stage map:

| `check-chain` (elaboration) | `loen:audit` (execution) | Validates | Side-effect |
|---|---|---|---|
| spec | **plan** | `loop.yaml` (schema, scope/budget sane, human-approved) + `plan.md` | upsert `state.md` + `report.html` |
| plan | **act** | iteration `diff.patch` within `mutable_scope`; guard passed | + `report.html` |
| — | **check** | dispatch `verifier` → `verifier.md` + `gates.log`; `OK`/`needs_work` | + `report.html` |
| result | **result** | all iterations converged; gates green + verifier `APPROVE` | final `report.html` + `docs/TODO.md` Result |

- Each stage returns a verdict `OK` / `needs_work` and **gates progression** (no Act before `plan` is `OK`).
- Each stage **regenerates `report.html`** via the `html-report` skill — the live human-readable index
  (analogous to how `check-chain` upserts `docs/TODO.md`).
- Converges on the **topic** (the `<topic>` part of the run-id) → the elaboration and execution
  chains join at `docs/TODO.md`.
- Replaces any standalone `/loen-report` command (report generation is this skill's side-effect).

### 5.3 Subagents (roster, distinct models, read-only)

Worker = the main session (owns task context, user's model, single writer). Subagents:

| Subagent | Task | Model | Tools | Writes files? |
|---|---|---|---|---|
| `loen:planner` | decompose, risks, fill `loop.yaml` + `plan.md` | opus / high-reasoning | Read/Grep/Glob | no |
| `loen:explorer` | gather code evidence before act/review | haiku→sonnet | Read/Grep/Glob | no |
| `loen:verifier` | strict independent check of diff + evidence | sonnet, high-effort | Read/Grep/Glob/**Bash** | no |

- All subagents are **read-only** (no Write/Edit). Their artifact is their **return value** (text);
  the **worker** persists it (single-writer). This removes the read-only-vs-write contradiction.
- `verifier` gets **Bash** to independently run gates/tests for confirmation; it edits nothing.
- Models are defaults in agent frontmatter, overridable.

## 6. `loop.yaml` contract

Authoritative machine contract (YAML for reliable hook/guard parsing). Schema (from methodology §1.2):

```yaml
name:            # run-id: <date>-<topic>
mode: delivery   # delivery | repair | research  (which loop skill picks it up)
objective:       # one measurable end state
context_sources: []
mutable_scope: []      # editable globs
protected_scope: []    # forbidden globs — guard/hook read from here
quality_gates: []      # verifier commands (exit 0 required)
metrics: {primary: [], secondary: []}
budget: {max_iterations: 3, max_wall_time_minutes: 90, max_cost_usd: 5}
stop_conditions: []
handoff_conditions: []
rollback_policy:
logging: {state_file: docs/loen/<run-id>/state.md}
```

**Lifecycle (default authoring path):**
`/loop-delivery <task>` → `planner` (isolated) fills the schema from task + repo + RUNBOOK/inferred
commands → worker writes `docs/loen/<run-id>/loop.yaml` (after YAML-parse validation) →
**human approves** the card (scope + budget gate; never auto-trusted) → loop runs against it.
Hand-written `loop.yaml` is also supported; `planner` validates it instead of filling.

## 7. Context handling (isolation)

- Each subagent runs in an **isolated context fork** (its own window; does not inherit the main chat).
- **State is exchanged via `docs/loen/<run>/` artifacts, not via context** (methodology §5:
  repo-state outlives chat-state). Artifacts are the shared memory.
- A subagent reads its inputs from artifacts (`loop.yaml`, `diff.patch`, `gates.log`) and returns a
  **compact** result; the worker persists it.
- The main `loop-delivery` context accumulates only the compact returns + control flow → it is not
  polluted by subagents' file reads / exploration (e.g. `explorer` reads many files in its fork and
  returns a digest).
- `verifier` runs in a **fresh** isolated context → it never sees the worker's rationalizations →
  genuine independence.

## 8. Data flow (end-to-end)

```
/loop-delivery <task>
  -> create docs/loen/<run-id>/ ; set docs/loen/current
  -> planner (isolated) fills loop.yaml + plan.md ; worker persists
  -> human approves loop.yaml (scope/budget gate)
  -> loen:audit plan  => OK gates progression
  -> Act: worker minimal diff (each edit through loop-guard hook) -> iterations/iter-NN/diff.patch
  -> Check: run quality_gates -> gates.log ; loen:audit check dispatches verifier -> verifier.md
  -> worker fixes confirmed issues (<= budget.max_iterations)
  -> loen:audit result: gates green + verifier APPROVE -> report.html + pr-summary.md ; TODO.md Result
  -> Stop: gates pass | human-decision gate | budget exceeded | handoff condition
  -> human reviews as a normal PR. No auto-merge.
```

## 9. Guardrails — hook enforcement

`hooks/loop-guard.py`, PreToolUse `Write|Edit|MultiEdit`. **Deterministic** (regex, no reasoning).
Two responsibilities; composes with iclaude's always-on `block-secrets` / `redact-secrets`.

**A. Layout / naming enforcement (within the topic).** If the target path is under `docs/loen/`:
- Active run `R` (run-id `<date>-<topic>`) is read from the `docs/loen/current` pointer.
- Path must match a canonical pattern for `R`, else **block (exit 2)** + print the expected path.
- The `<R>` segment of the target path must equal the active run-id; a differing `<R>` is a
  cross-topic write → **block (exit 2)** (keeps every write within the active topic).
- Bootstrap: setting `docs/loen/current` to a well-formed new `R` is allowed (establishes the topic;
  resolves the chicken-and-egg).

Canonical set (sole source of truth = the hook's regexes):
```
run-id:  ^\d{4}-\d{2}-\d{2}-[a-z0-9-]+$
docs/loen/current
docs/loen/RUNBOOK.md
docs/loen/<R>/loop.yaml
docs/loen/<R>/plan.md
docs/loen/<R>/state.md
docs/loen/<R>/pr-summary.md
docs/loen/<R>/report.html
docs/loen/<R>/experiments.jsonl
docs/loen/<R>/iterations/iter-\d{2}/diff.patch
docs/loen/<R>/iterations/iter-\d{2}/gates.log
docs/loen/<R>/iterations/iter-\d{2}/verifier.md
```
Any other name/location under `docs/loen/` → block(2).

**B. Scope enforcement.** If the target path is outside `docs/loen/`:
- `protected_scope` → block(2); code edits must be within `mutable_scope`, else block(2).

If `docs/loen/current` is absent, only bootstrap writes under `docs/loen/` are allowed; non-loen paths
are unaffected (no-op) so non-loop repositories are never constrained.

**Defense-in-depth:** `scripts/guard_protected.sh` (`git diff --name-only` vs `protected_scope`,
exit 1) runs inside `quality_gates` to catch mutations the PreToolUse hook cannot see (e.g. files
created by Bash).

## 10. Worker / checker split

- Worker (main session) is the single writer and makes the diff.
- `verifier` is independent: read-only tools, fresh isolated context, separate model. Advisory to the
  worker (returns `APPROVE`/`REJECT` + evidence + missing checks + risks + required fixes); the worker
  fixes only confirmed issues; the human does the final PR review.
- Two verification layers: deterministic gates (cheap, always) + verifier subagent (judgment,
  high-effort). Methodology §16: the higher the autonomy, the more mechanical/cheap/independent the
  verifier — satisfied by the deterministic layer; the subagent adds judgment.

## 11. Error handling / budget / handoff / rollback

- `planner` returns invalid YAML → worker validates parse **before** writing; re-prompts on failure.
- `verifier` `REJECT` → worker fixes within `budget`; budget exhausted → handoff.
- Flaky gates → `RUNBOOK.md` documents reproduce steps.
- `budget.{max_iterations, max_wall_time_minutes, max_cost_usd}` → stop + report best on exhaustion.
- `handoff_conditions` (schema / PII / license / architecture / production creds) → hard stop, human.
- `rollback_policy` → revert failed experiments; keep only metric-backed changes.

## 12. HTML report

- `loen:audit` regenerates `docs/loen/<run-id>/report.html` at every stage via the **`html-report`**
  skill, targeting that path.
- Content: contract (`loop.yaml`), iterations table (diff summary, gates pass/fail, verifier verdict),
  metrics before/after, budget spend, final decision, handoff reasons. Self-contained, opens by
  double-click.

## 13. Testing

Flat `tests/`, shell + python per repo convention (`test-redact-hook.sh` is the hook-test precedent).
- `test_loen_plugin.sh` — `plugin.json` valid; version == `marketplace.json` (extend
  `check-plugin-version-sync.sh`).
- `test_loen_hook.py` — no `current` → no-op; cross-topic → block(2); malformed `iter` name → block(2);
  canonical path → allow; bootstrap `current` → allow; `protected_scope` → block(2); `mutable_scope`
  edit → allow; non-loen path → no-op.
- `test_loen_guard.sh` — protected diff → exit 1; clean diff → exit 0.
- `test_loen_templates.sh` — `loop.template.yaml` parses as valid YAML.
- Skills/agents frontmatter lint (name/description/tools/model). Smoke: run `loop-delivery` on a toy
  fixture repo → `loop.yaml` filled, `state.md` appended, `report.html` emitted, verifier invoked,
  artifacts land at canonical paths.

## 14. Process obligations (per CLAUDE.md)

- Register `loen` in `.claude-plugin/marketplace.json` (full metadata for future publish).
- `docs/functions/LOEN.md` + a section in the root `README.md` (Russian; no `docs/README.ru.md` exists).
- iwiki page in the `iclaude` domain (`wiki_write_page` + `wiki_lint`).
- Row in `docs/TODO.md` (topic `loen-loop-engineering-plugin`).

## 15. Out of scope (MVP)

- `loop-repair`, `loop-autoresearch` skills (spec 2).
- Governance / observability / Langfuse (spec 3, optional).
- Native `/goal` / `/loop` wrapping — optional accelerator only; loop-delivery is self-contained.
- microVM hard FS-isolation for verifier — optional hardening, noted, not default.

## 16. Resolved decisions log

1. Target: distributable feature for user projects (not iclaude self-dev only).
2. MVP boundary: rails + delivery + verifier + guard (autoresearch/repair/governance deferred).
3. `loop-delivery` fully independent of the IDD→SDD chain.
4. Packaging: plugin `plugin/loen/` (iwiki precedent), publishable, superpowers optional.
5. Install: standard marketplace install, user scope, co-installed next to superpowers (not copied in).
6. Multi-agent roster with distinct models: planner / explorer / verifier (worker = main session).
7. Artifact persistence: single-writer (worker); subagents read-only, return text.
8. Contract is YAML (`loop.yaml`); planner auto-fills + human approves.
9. Artifacts under `docs/loen/<run-id>/`; templates are plugin assets (`.agent-loop/` removed; no `loen-init`).
10. Reporting/validation skill named **`loen:audit`** (renamed from `check-loop`); mirrors `check-chain`.
11. Subagents run in isolated context forks; artifacts are the shared memory.
12. Hook `loop-guard.py` deterministically enforces both scope and layout/naming within the topic.
