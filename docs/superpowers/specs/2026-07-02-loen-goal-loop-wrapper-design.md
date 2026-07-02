---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-07-02-loen-goal-loop-wrapper-design.md
review:
  spec_hash: 03c23b55e19a4704
  last_run: 2026-07-02
  runner: "clean-context subagent (check-runner protocol)"
  phases:
    structure:   { status: passed }
    coverage:    { status: passed }
    clarity:     { status: passed }
    consistency: { status: passed }
  findings:
    - { id: F-001, phase: structure, severity: WARNING, verdict: fixed, note: "stray CJK char in §1 ('string每 run') → 'string each run'" }
    - { id: F-002, phase: structure, severity: INFO, verdict: fixed, note: "§8 double slash between /goal and /loop → single separator" }
    - { id: F-003, phase: structure, severity: INFO, verdict: wontfix, note: "§9 cites §3.2-3.4 as list items, resolvable — cosmetic" }
    - { id: F-004, phase: clarity, severity: INFO, verdict: wontfix, note: "/loop interval left context-dependent by design" }
  verdict: OK
---
# loen backlog step 2 — /goal + /loop wrapper — Design Spec

- **Topic:** `loen-goal-loop-wrapper`
- **Date:** 2026-07-02
- **Status:** design draft — defaults chosen during brainstorming (user AFK on the option
  poll; every default is explicitly overridable at spec review / plan time)
- **Parent spec:** `docs/superpowers/specs/2026-07-01-loen-loop-engineering-plugin-design.md` §15
- **Source methodology:** `docs/superpowers/notes/final_loop_engineering_methodology.md`
  §6.2 (Claude `/goal` mechanics), tools overview line (Claude `/goal`/`/loop`/Routines are
  distinct mechanics with distinct durability)
- **Scope:** loen backlog step 2 only — an OPTIONAL accelerator that wraps the
  self-contained `loop-delivery` (and its `repair`/`research` specializations) in Claude's
  native `/goal` condition and the session-scoped `/loop` polling skill. `loop-delivery`
  stays fully usable without it. Backlog steps 3–4 are separate specs.

---

## 1. Summary

The MVP loop already carries everything a `/goal` condition needs — `objective`,
`quality_gates`, `mutable_scope`/`protected_scope`, `budget` — inside the human-approved
`loop.yaml`. Today a user who wants multi-turn autonomy must hand-write the `/goal` string
and knows nothing about the evidence-first rule (methodology §6.2: the `/goal` evaluator
only reads the transcript — it runs no commands — so the worker MUST print command, exit
code, and metric summary as evidence). This spec adds a thin, deterministic bridge:

- **`scripts/make_goal.py`** (new, deterministic) — reads the active contract and prints a
  ready-to-paste, evidence-first `/goal` string.
- **`skills/loop-goal/SKILL.md`** (new, thin) — invoked as `/loen:loop-goal`; validates
  the run state, runs the generator, hands the string to the human, and carries the
  `/loop` polling recipe for long-running gates.

**Design decision (default, overridable): thin skill + deterministic generator** — chosen
over (a) a doc-only recipe (no code; relies on the human re-deriving the string each run
and misses the evidence-first trap) and (b) a bare script without a skill (no guardrails: no
run-state validation, no /goal-mechanics warning at the moment of use).

## 2. Component: `plugin/loen/scripts/make_goal.py` (new, deterministic)

- **Input:** path to a `loop.yaml` (default `docs/loen/current/loop.yaml`).
- **Output (stdout):** one `/goal` string assembled ONLY from contract fields — no LLM,
  no inference:
  - **delivery / repair:** every `quality_gates` entry joined as
    `<cmd> exits 0` + `and Claude prints each command's output summary as evidence` +
    `; change only <mutable_scope globs>` + `; do not modify <protected_scope globs>` +
    `; stop after <budget.max_iterations> failed attempts and report the blocker`.
  - **research:** the `target:` line from `stop_conditions` is rendered as the success
    clause (`<eval evidence> shows <primary-name> <op> <number>`), gates stay as
    invariants, and the budget clause uses `budget.max_experiments`
    (`stop after <max_experiments> experiments and report the best kept state`).
- **Validation (exit 1, nothing printed):** file missing / unparsable; `quality_gates`
  empty; mode `research` without a `target:` line in `stop_conditions`; empty
  `mutable_scope`. These are the same preconditions `loen:audit plan` enforces — the
  generator refuses to wrap an unapproved-shaped contract.
- stdlib only (mirror of the repo's line-oriented YAML readers in `loop-guard.py` /
  `guard_protected.sh` — no PyYAML dependency at runtime).

## 3. Component: `plugin/loen/skills/loop-goal/SKILL.md` (new, thin)

Invoked as `/loen:loop-goal` (optionally with an explicit run-id). Steps encoded in the
skill body:

1. **Preconditions.** An active run exists (`docs/loen/current`), the contract was
   human-approved, and `loen:audit plan` returned `OK`. No active run → stop and point to
   `loop-delivery`/`loop-repair`/`loop-autoresearch` bootstrap. Never bootstraps a run
   itself — it wraps an existing one.
2. **Generate.** Run `make_goal.py` (resolved from `<skill-base>/../../scripts/`); show
   the produced string to the human VERBATIM for them to submit as `/goal …`. The skill
   never submits `/goal` itself — `/goal` is a native user-level command and the human
   stays in control of granting multi-turn autonomy.
3. **Evidence-first briefing.** The skill restates §6.2 mechanics next to the string: the
   evaluator reads only the transcript, so during the goal run the worker MUST print every
   gate command, its exit code, and metric summaries; conditions like "all tests pass"
   without printed evidence never evaluate true.
4. **`/loop` recipe (long-running gates).** For gates that poll external state (CI runs,
   deploys), the skill carries a ready recipe: `/loop <interval> loen:audit check` with
   the interval matched to the external system's cadence, plus the durability warning —
   `/loop` is session-scoped (dies with the session, recurring tasks auto-expire); durable
   scheduling belongs to Routines / OS schedulers / CI and is OUT of this spec's scope.

## 4. Guardrails and behavior rules

- The wrapper NEVER weakens the loop protocol: `loen:audit` stages, the loop-guard hook,
  and the human approval gate stay exactly as in the MVP; `/goal` only automates the
  "keep going until the gates are green" turn loop.
- One goal run wraps ONE loen run (the active `docs/loen/current`); cross-topic wrapping
  is refused (mirrors the hook's cross-topic block).
- Handoff conditions keep hard-stopping: the generated string always ends with the
  budget/stop clause so the goal run terminates instead of looping forever.
- The skill is optional by construction: nothing in `loop-delivery`, `loop-repair`,
  `loop-autoresearch`, or `loen:audit` references it (no reverse dependency).

## 5. Delivery model

- Same plugin `plugin/loen/`; version bump **minor** in BOTH `plugin.json` and
  `marketplace.json` (exact number resolved at implementation time from whatever is
  current — backlog steps 2–4 have no fixed merge order; sync enforced by
  `check-plugin-version-sync.sh`).
- New files only: `skills/loop-goal/SKILL.md`, `scripts/make_goal.py`; no hook changes,
  no template changes, no new canonical paths, no agent edits, zero new hard dependencies.

## 6. Testing

Extends the flat `tests/` convention:

- **`tests/test_loen_goal.py` (new)** — `make_goal.py` against fixture contracts:
  delivery contract → string contains every gate + `exits 0` + evidence clause + both
  scope clauses + `max_iterations` budget clause; research contract → string carries the
  `target:` clause and the `max_experiments` budget clause; `quality_gates: []` → exit 1,
  empty stdout; research without `target:` → exit 1; missing file → exit 1.
- `tests/test_loen_plugin.sh` — skill lint list extended with `loop-goal`; version sync
  green after the bump.

## 7. Process obligations (per CLAUDE.md, at implementation time)

- `docs/functions/LOEN.md` Use section + `plugin/loen/README.md` catalogue + root
  `README.md` (RU) gain the `/loen:loop-goal` entry; iwiki `iclaude/loen-plugin`
  Components + Roadmap updated; `docs/TODO.md` row `loen-goal-loop-wrapper` driven by
  `/check-chain`.

## 8. Out of scope

- Durable scheduling (Claude Routines, OS cron, CI schedules) — methodology explicitly
  separates their durability from session-scoped `/goal` / `/loop`.
- Codex Automations wrapping (methodology §7.5) — different runtime.
- Auto-submitting `/goal` on the user's behalf.
- Any change to the loop protocol itself (stages, gates, artifacts).

## 9. Resolved decisions log

1. Form: **thin skill + deterministic generator** (default chosen with user AFK;
   alternatives doc-only recipe / bare script recorded in §1 and reversible at review).
2. The generator refuses contracts that would fail `loen:audit plan` (§2 validation set).
3. The skill never submits `/goal` itself; human stays the autonomy grantor (§3.2).
4. Evidence-first rule is briefed at the moment of use, not only in docs (§3.3).
5. `/loop` positioned ONLY for session-scoped polling of long-running gates; durability
   caveat mandatory in the skill text (§3.4).
6. No reverse dependencies from existing skills — accelerator stays optional (§4).
