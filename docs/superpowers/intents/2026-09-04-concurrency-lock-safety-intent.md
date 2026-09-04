---
review:
  intent_hash: c935dbd9d05c6a43
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
  intent_hash: c935dbd9d05c6a43
  last_run: 2026-09-04
---

# Intent: concurrency-lock-safety

**Date:** 2026-09-04
**Status:** approved

> Derived from the user-approved rework plan
> (iwiki `iclaude/reference/plans/shared-store-per-project-home-architecture`, slice S6)
> and the user's instruction to take S6 next. Q1–Q6 restate the plan's decisions; no new
> scope was invented.

## Objective

Neither icodex nor iclaude has any locking: two launches of the same project race on the
home's `settings.json`, symlinks, and migration; concurrent `--update` or lockfile
writes race on the store. Since S5 the per-project path is the default, so home
mutations happen on every launch. S6 adds flock-based mutual exclusion — one lock per
home around the populate block, one store lock around lockfile writes and npm installs —
with fail-soft semantics: a missing flock, unlockable filesystem, or timeout warns and
proceeds, never blocking a launch or making anything worse than today.

## Desired Outcomes

- A reusable `iclaude_with_lock <lockfile> <timeout> <command...>` helper serializes
  concurrent callers on the same lock file; on lock failure or timeout it warns and
  runs the command anyway (fail-soft, observable via warning).
- Concurrent mutators of a shared counter under the helper lose no increments
  (mutual-exclusion proof test).
- `setup_claude_home` populates the home (marker, links, settings seed/sync, migration)
  under a per-home lock; two concurrent setups of the same project both succeed and
  leave a single valid marker and settings file.
- `save_isolated_lockfile`, `update_lockfile_hash`, and
  `install_npm_package_with_lockfile` run under one store lock; concurrent hash writes
  leave a valid single-line hash file.
- Behavior in the absence of contention is unchanged: same outputs, same exit codes,
  all existing tests pass.

## Health Metrics

- Existing tests keep passing: home-migration 16/16, per-project-home 20/20,
  shared-asset-links 21/21, settings-managed-region 18/18, launch-wiring 12/12,
  env-map, config-migration, regression-phase0.
- S1–S5 GWT scenarios stay valid with stable IDs (locking adds no observable behavior
  change on the uncontended path).
- No launch may block indefinitely: every lock acquisition carries a timeout.

## Strategic Context

- Interacts with: `setup_claude_home` (`lib/config/isolated.sh`),
  `save_isolated_lockfile` / `update_lockfile_hash` (`lib/lockfile/save.sh`),
  `install_npm_package_with_lockfile` (`lib/nvm/install.sh`), module sourcing order in
  `iclaude.sh` (new `lib/core/lock.sh` sourced with the core modules).
- Priority trade-off: trust (fail-soft, timeout-bounded, uncontended path identical)
  over speed.

## Constraints

### Steering (behavioral guidance)

- Wrapper pattern: rename the existing function body to `_<name>_unlocked` and make the
  public name a thin lock wrapper — call sites stay untouched.
- Lock files: `<home>/.iclaude.lock` per home, `$ISOLATED_NVM_DIR/.iclaude-store.lock`
  for the store; both are runtime state, git-ignored by existing rules.

### Hard (architectural enforcement)

- Fail-soft everywhere: no code path may turn a lock problem into a launch failure.
- Timeouts: short (≤60s) for home and lockfile writes; long (≤600s) for npm installs.
- No changes to what the wrapped functions do — locking only.
- flock(1) absence degrades to running unlocked with a warning.
- No new dependencies beyond util-linux flock.

## Autonomy Zones

- Full autonomy (reversible, low risk): helper module, wrappers, tests, docs, wiki
  updates, commit/PR on the `dev-concurrency-lock-safety` branch.
- Guarded (log + evidence): wrapping the npm-install chokepoint — must not change its
  arguments, outputs, or error propagation (test-backed).
- Proposal-first (needs approval): locking any additional call site; changing retention
  of lock files; blocking (non-fail-soft) semantics.
- No autonomy (human only): merging the PR.

## Stop Rules

- Halt if: fail-soft semantics cannot be preserved for some wrapped path, or a wrapper
  changes a wrapped function's observable contract.
- Escalate if: correct serialization requires locking beyond the four named call sites.
- Done when: the mutual-exclusion proof test passes (no lost increments), concurrent
  same-project setups leave a consistent home (test), concurrent hash writes leave a
  valid file (test), timeout fail-soft is proven (test), and the full relevant test set
  passes unchanged.
