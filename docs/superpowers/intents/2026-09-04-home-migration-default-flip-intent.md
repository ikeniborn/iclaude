---
review:
  intent_hash: 3c46a142be896fb5
  last_run: 2026-09-04
  phases:
    structure: passed
    completeness: passed
    clarity: passed
    consistency: passed
    alignment: passed
  findings: []
result_check:
  verdict: OK
  intent_hash: 3c46a142be896fb5
  last_run: 2026-09-04
---

# Intent: home-migration-default-flip

**Date:** 2026-09-04
**Status:** approved

> Derived from the user-approved rework plan
> (iwiki `iclaude/reference/plans/shared-store-per-project-home-architecture`, slice S5)
> and the user's instruction to take S5 next. Q1–Q6 restate the plan's decisions; no new
> scope was invented.

## Objective

S1–S4 made per-project homes correct and usable behind an opt-in flag, but a switched
project starts with empty Claude Code state: no onboarding flags, no project history, no
transcripts — and the default is still the shared directory with its `.claude.json`
last-writer-wins races. S5 delivers copy-based first-launch migration of exactly this
project's slice of the shared state into its home, then flips the default to
`per-project`, keeping `ICLAUDE_HOME_MODE=shared` as the escape hatch. Migration never
mutates the store, so rollback is deleting the home.

## Desired Outcomes

- On first launch into a fresh home, the home receives a `.claude.json` built from the
  store copy: every global/onboarding key, `.projects` reduced to only this project's
  entry (or empty when the store has none). An existing home `.claude.json` is never
  overwritten.
- The project's transcript directory `projects/<mangled-root>/` is copied from the store
  into the home when present; store originals stay in place.
- `history.jsonl` entries whose `project` field equals this project's root are copied
  into the home history; without `jq` or without a store history the home starts fresh.
- With `ICLAUDE_HOME_MODE` unset, `setup_isolated_config` now selects `per-project`
  (default flip); `ICLAUDE_HOME_MODE=shared` (env or `.claude_config`) restores the old
  shared behavior exactly; `--per-project-home` stays a no-op-equivalent explicit form.
- `--check-config` reports the active home mode and, in per-project mode, the resolved
  home directory.
- The store is never mutated by migration (guard + test); deleting a home and
  relaunching re-migrates from the unchanged store.

## Health Metrics

- Existing tests keep passing: per-project-home 21/21 (its explicit-mode assertions,
  not the old default), shared-asset-links 21/21, settings-managed-region 18/18,
  launch-wiring 12/12, env-map, config-migration, regression-phase0.
- S1–S4 GWT scenarios stay valid with stable IDs; the S1 scenario's given already names
  `per-project` explicitly, so the flip does not invalidate it.
- Migration copies only: store `.claude.json`, `projects/`, `history.jsonl` byte-identical
  after any number of migrations.

## Strategic Context

- Interacts with: `setup_isolated_config` / `setup_claude_home`
  (`lib/config/isolated.sh` — migration call site after seed/sync),
  `check_config_status` (`lib/config/status.sh`), the S1 dispatch default, README docs,
  S7 (GC relies on copy-based rollback semantics).
- Priority trade-off: trust (copy-only, reversible, escape hatch) over speed.

## Constraints

### Steering (behavioral guidance)

- Migration runs once per home, keyed on the absence of the home `.claude.json` —
  no separate migration marker file.
- Follow Claude Code's observed path mangling (every char outside `[a-zA-Z0-9]` → `-`)
  for the transcript directory name.

### Hard (architectural enforcement)

- Migration is copy-only: no delete, rename, or rewrite inside the store, ever.
- The default flip is exactly one changed fallback value in the S1 dispatch; the
  `shared` mode path stays byte-identical to today when selected.
- `jq` remains optional: without it, `.claude.json` seeding falls back to a plain copy
  of the store file minus nothing (skip the `.projects` reduction with a warning) — no
  hard failure; history filter is skipped (fresh history).
- No locking (S6), no home GC (S7), no changes to shared-infrastructure paths.

## Autonomy Zones

- Full autonomy (reversible, low risk): module code, tests, docs, wiki updates,
  commit/PR on the `dev-home-migration-default-flip` branch.
- Guarded (log + evidence): the default flip itself — must be provably reversible via
  `ICLAUDE_HOME_MODE=shared` (test-backed) and called out in the PR description.
- Proposal-first (needs approval): any store-side mutation; migrating state beyond the
  three named artifacts; changing the escape-hatch semantics.
- No autonomy (human only): merging the PR.

## Stop Rules

- Halt if: correct migration would require mutating or locking the store, or the
  `.projects` entry cannot be reduced without breaking Claude Code's file format.
- Escalate if: the flip breaks any existing launch path that cannot be restored by
  `ICLAUDE_HOME_MODE=shared`.
- Done when: a fresh home receives the reduced `.claude.json`, its transcripts, and its
  filtered history (tests); re-launch does not re-migrate (test); the store is
  byte-identical after migration (test); unset mode now resolves per-project and
  `shared` restores today's behavior (tests); `--check-config` shows the home info; and
  the full relevant test set passes.
