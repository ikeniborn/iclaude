---
review:
  intent_hash: 5e883e422a553ed0
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
  intent_hash: 5e883e422a553ed0
  last_run: 2026-09-04
---

# Intent: shared-asset-symlink-layer

**Date:** 2026-09-04
**Status:** approved

> Derived from the user-approved rework plan
> (iwiki `iclaude/reference/plans/shared-store-per-project-home-architecture`, slice S2)
> and the user's instruction to deliver slices sequentially, S2 next. Q1–Q6 restate the
> plan's decisions; no new scope was invented.

## Objective

S1 gave per-project homes, but a home starts empty: a per-project session sees none of
the shared assets (skills, hooks, plugins, MCP registrations, global CLAUDE.md,
credentials, router config) that live in the shared store
`.nvm-isolated/.claude-isolated/`. S2 wires those assets into every home as symlinks, so
editing the store once takes effect for all projects on the next launch, while sessions,
history, and state stay home-local. This makes per-project mode actually usable and
unblocks S3 (settings) and S4 (launch wiring).

## Desired Outcomes

- After `setup_claude_home`, the home contains symlinks to the store for every shared
  entry that exists there: `skills/`, `hooks/`, `commands/`, `agents/`, `plugins/`,
  `mcp/`, `scripts/`, `CLAUDE.md`, `.credentials.json`, `router.json` — whole-entry
  links, one per name.
- A wrong or dangling link (or a real file/dir where a link belongs) is repaired to the
  exact expected target on the next launch; a correct link is left untouched.
- A store entry absent on disk (today: `commands/`, `agents/`) is skipped without error
  and gets linked automatically on a later launch once it appears; a stale link to a
  removed store entry is removed.
- A guard function detects a managed entry that is not a symlink and repairs it,
  logging a warning — the icodex `hooks.json` de-share defect cannot recur silently.
- Shared (default) mode behavior is byte-identical to today: no links are created in the
  shared config dir.

## Health Metrics

- Existing tests keep passing: `tests/test_per_project_home.sh` 21/21,
  `tests/test_env_map.sh`, `tests/test_config_migration.sh`, `tests/regression-phase0.sh`.
- The S1 contract is unchanged: home id format, `home.json` marker, `CLAUDE_CONFIG_DIR`
  export (GWT scenario `per-project-home-resolution` stays valid, ID stable).
- No writes into the shared store from the linking path — it only reads store paths.

## Strategic Context

- Interacts with: `setup_claude_home` (`lib/config/isolated.sh`, insertion point after
  marker creation), the shared store `.nvm-isolated/.claude-isolated/`, future S3
  (settings.json seeding — deliberately excluded here) and S4 (launch wiring audit).
- Priority trade-off: trust (self-repairing, idempotent, default untouched) over speed.

## Constraints

### Steering (behavioral guidance)

- Follow the icodex `_link_shared` pattern: compare `readlink` to the exact expected
  target; on mismatch remove and re-link; on match do nothing.
- Prefer whole-entry links (one symlink per name) — never per-file fan-out, avoiding the
  icodex `skills/` drift between docs and runtime.
- Log each repair action; silence only when nothing changed.

### Hard (architectural enforcement)

- `settings.json` is NOT linked or seeded — that is S3.
- Session/state entries (`projects/`, `history.jsonl`, `sessions/`, `state/`, `logs/`,
  `shell-snapshots/`, `file-history/`, `session-env/`, `.claude.json`) are never linked —
  they stay home-local.
- The linking path never creates, modifies, or deletes anything inside the shared store.
- Links are created only in per-project homes; shared mode paths are untouched.
- No new dependencies; pure bash + coreutils.

## Autonomy Zones

- Full autonomy (reversible, low risk): module code, tests, docs, wiki updates,
  commit/PR on the `dev-shared-asset-symlink-layer` branch.
- Guarded (log + evidence): the repair path deletes wrong links or materialized copies
  inside a home — must only ever remove a path whose name is on the managed-entry list.
- Proposal-first (needs approval): linking any entry beyond the listed ten; touching
  settings.json; any store-side mutation.
- No autonomy (human only): merging the PR.

## Stop Rules

- Halt if: repairing a link would require deleting a path that is not on the managed
  list, or shared-mode behavior would change observably.
- Escalate if: an asset turns out to need copy-plus-sync semantics instead of a symlink
  (that is S3 territory — do not improvise it here).
- Done when: in per-project mode a fresh home contains correct links for every store
  entry that exists (proven by the new test), a corrupted link/materialized dir is
  repaired on the next call (proven by test), absent store entries are skipped and stale
  links pruned (proven by test), shared mode creates no links (proven by test), and the
  full relevant test set passes.
