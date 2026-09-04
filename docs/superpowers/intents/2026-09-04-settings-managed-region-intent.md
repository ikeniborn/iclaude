---
review:
  intent_hash: 727ada8cdbecccfa
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
  intent_hash: 727ada8cdbecccfa
  last_run: 2026-09-04
---

# Intent: settings-managed-region

**Date:** 2026-09-04
**Status:** approved

> Derived from the user-approved rework plan
> (iwiki `iclaude/reference/plans/shared-store-per-project-home-architecture`, slice S3)
> and the user's instruction to deliver slices sequentially, S3 next. Q1–Q6 restate the
> plan's decisions; no new scope was invented.

## Objective

A per-project home (S1+S2) still has no `settings.json`: Claude Code falls back to
defaults, so permissions, hooks wiring, enabled plugins, and the statusline are missing
in per-project mode. Copying the file once would repeat the icodex `config.toml` defect —
21 homes drifting forever. S3 seeds `settings.json` from the store on first home
creation and then re-syncs only the machine-owned keys on every launch, keeping
user-owned keys per home untouched. This is the deliberate improvement over icodex's
copy-once model.

## Desired Outcomes

- On first home creation, the home gets a `settings.json` copied from the store
  (mode 600). A home that already has one is never re-seeded.
- On every `setup_claude_home` run, the managed keys — `hooks`, `enabledPlugins`,
  `statusLine`, `extraKnownMarketplaces` — mirror the store copy exactly: a changed or
  deleted managed key in the home is restored, a managed key removed from the store
  disappears from the home.
- User-owned keys in the home (`model`, `language`, `permissions`, `effortLevel`,
  `tui`, `plansDirectory`, `env`, and any other non-managed key) survive the sync
  byte-for-byte.
- The sync rewrites the file only when content actually differs (idempotent no-op
  otherwise) and never mutates the store.
- Without `jq`, or with no store `settings.json`, seeding/sync degrade gracefully
  (skip + warning), and the launch continues.
- Shared (default) mode behavior is byte-identical to today.
- The lockfile drift prompt stays single: `LOCKFILE_HASH_FILE` remains anchored to the
  store path, not to `CLAUDE_CONFIG_DIR` (already true structurally — guarded by review,
  not changed).

## Health Metrics

- Existing tests keep passing: test_per_project_home 21/21, test_shared_asset_links
  21/21, test_env_map, test_config_migration, regression-phase0.
- S1/S2 GWT scenarios stay valid with stable IDs.
- Hooks and statusline paths in the seeded file keep their `$CLAUDE_CONFIG_DIR/...`
  form, resolving through the S2 symlinks — no path rewriting is introduced.

## Strategic Context

- Interacts with: `setup_claude_home` (`lib/config/isolated.sh`, call site after
  `link_shared_assets`), the store `settings.json`, `repair_settings_paths`
  (`lib/nvm/repair.sh` — remains the single path-repair point; sync propagates repaired
  store values), future S4 (launch wiring audit) and S5 (migration/default flip).
- Priority trade-off: trust (user keys inviolable, store read-only, idempotent) over
  speed.

## Constraints

### Steering (behavioral guidance)

- Managed-key sync mirrors the store — the store copy is the single source of truth for
  machine-owned keys; do not invent per-key merge rules.
- Write via temp file + atomic move, only after a content comparison shows a change.

### Hard (architectural enforcement)

- Managed keys are exactly `hooks`, `enabledPlugins`, `statusLine`,
  `extraKnownMarketplaces` — extending the list is out of scope (proposal-first).
- The sync path never writes to the shared store.
- No migration of existing shared state, no default flip (S5), no symlinking of
  `settings.json` (defeats per-home user keys).
- `jq` stays an optional dependency: its absence degrades to a warning, never an error.
- Shared-mode code paths are untouched.

## Autonomy Zones

- Full autonomy (reversible, low risk): module code, tests, docs, wiki updates,
  commit/PR on the `dev-settings-managed-region` branch.
- Guarded (log + evidence): the sync overwrites managed keys inside a home
  `settings.json` — must provably never touch a non-managed key (test-backed).
- Proposal-first (needs approval): extending the managed-key list; touching
  `LOCKFILE_HASH_FILE`; any store-side mutation; path rewriting inside seeded settings.
- No autonomy (human only): merging the PR.

## Stop Rules

- Halt if: preserving user keys and mirroring managed keys conflict for the same key,
  or shared-mode behavior would change observably.
- Escalate if: correct behavior turns out to require rewriting paths inside the seeded
  file (that belongs to `repair_settings_paths`, not to this slice).
- Done when: a fresh home receives the seeded 600-mode file (test), a second run does
  not re-seed (test), managed keys are restored after home-side tampering and removed
  when absent from the store (tests), user keys survive the sync byte-for-byte (test),
  the no-change run does not rewrite the file (test), the store stays unmutated (test),
  jq-less and store-less runs degrade with a warning (test), shared mode stays clean
  (test), and the full relevant test set passes.
