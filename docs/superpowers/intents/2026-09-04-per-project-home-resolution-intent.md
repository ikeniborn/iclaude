---
review:
  intent_hash: 8f0aef0abb4f3c74
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
  intent_hash: 8f0aef0abb4f3c74
  last_run: 2026-09-04
---

# Intent: per-project-home-resolution

**Date:** 2026-09-04
**Status:** approved

> Derived from the user-approved rework plan
> (iwiki `iclaude/reference/plans/shared-store-per-project-home-architecture`, slice S1)
> and the user's explicit instruction to implement S1. Q1–Q6 answers below restate the
> plan's decisions; no new scope was invented.

## Objective

iclaude points every project at one shared `CLAUDE_CONFIG_DIR`
(`.nvm-isolated/.claude-isolated/`), so concurrent sessions from different projects race
on `.claude.json` (last-writer-wins), share prompt history, and cannot have per-project
settings. The rework plan adopts icodex's two-layer model (shared store + per-project
homes). S1 lays the foundation now — deterministic home id resolution and home
scaffolding behind a feature gate — so later slices (symlink layer, settings sync,
launch wiring, migration) have a stable base. No default behavior changes in S1.

## Desired Outcomes

- With `ICLAUDE_HOME_MODE=per-project` (env or `.claude_config`) or `--per-project-home`,
  a launch resolves a home id `<project-basename>-<sha256(git-root-path)[0:12]>` and
  creates `.claude-homes/<id>/` with a `home.json` marker (absolute project root, created
  timestamp, schema version), and exports `CLAUDE_CONFIG_DIR` pointing at that home.
- Same project + same checkout path → same home id on every launch; a git worktree of the
  same repo gets a different home id; a non-git directory falls back to its physical path.
- With the flag unset or `ICLAUDE_HOME_MODE=shared` (default), behavior is byte-identical
  to today: `CLAUDE_CONFIG_DIR=.nvm-isolated/.claude-isolated`, no `.claude-homes/`
  directory is created.
- `.claude-homes/` is git-ignored.

## Health Metrics

- Default (shared) launch path unchanged: existing tests in `tests/` keep passing;
  `setup_isolated_config` behavior without the flag is untouched.
- No new mandatory dependency: id resolution uses git + sha256sum already required by
  the launcher.
- `apply_iclaude_env_map` regression tests keep passing after adding
  `ICLAUDE_HOME_MODE` to the native list.

## Strategic Context

- Interacts with: `lib/config/isolated.sh` (`setup_isolated_config` — insertion point),
  `lib/config/env-map.sh` (`_ICLAUDE_NATIVE_LIST`), `lib/core/init.sh` (path globals),
  `lib/launcher/launch.sh` (`_derive_project_id` slug pattern to reuse), future slices
  S2–S5 which consume the home id and marker.
- Priority trade-off: trust (deterministic, reversible, default untouched) over speed.

## Constraints

### Steering (behavioral guidance)

- Follow the icodex pattern (`resolve_project_root` = git toplevel, fallback `pwd -P`;
  id = `basename-sha256[0:12]`) so both wrappers stay structurally parallel.
- Reuse the sanitization approach of `_derive_project_id` for the basename part.
- Marker file `home.json` fixes the icodex gap: every home must be attributable to its
  project root for future GC (S7).

### Hard (architectural enforcement)

- Default mode stays `shared`; no migration, no symlinks, no settings seeding in S1
  (those are S2/S3/S5).
- `ICLAUDE_HOME_MODE` is a native `ICLAUDE_*` variable: added to `_ICLAUDE_NATIVE_LIST`,
  never de-prefixed to `HOME_MODE`.
- Per-home content in S1 is only the marker file — the home becomes `CLAUDE_CONFIG_DIR`
  so Claude Code populates it itself; iclaude writes nothing else into it yet.
- No writes outside the repository and `.claude-homes/`; no network.

## Autonomy Zones

- Full autonomy (reversible, low risk): module code, tests, docs, wiki updates,
  commit/PR on the `dev-per-project-home-resolution` branch.
- Guarded (log + evidence): touching shared launch path (`setup_isolated_config`) —
  must keep default branch behavior byte-identical, proven by tests.
- Proposal-first (needs approval): any default flip, any migration of existing state,
  any change outside the S1 scope listed above.
- No autonomy (human only): merging the PR.

## Stop Rules

- Halt if: preserving default shared behavior requires changing observable behavior of
  any existing flag or test.
- Escalate if: S1 turns out to need symlink or settings work to be testable (scope creep
  into S2/S3).
- Done when: `ICLAUDE_HOME_MODE=per-project` launch resolves and creates the home with a
  valid marker and exports `CLAUDE_CONFIG_DIR` to it (proven by the new test script),
  default launch produces no `.claude-homes/` and keeps `CLAUDE_CONFIG_DIR` at the shared
  dir (proven by test), and the full existing test suite passes.
