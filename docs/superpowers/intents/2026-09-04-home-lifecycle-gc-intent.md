---
review:
  intent_hash: aedfe8d3aaab3140
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
  intent_hash: aedfe8d3aaab3140
  last_run: 2026-09-04
---

# Intent: home-lifecycle-gc

**Date:** 2026-09-04
**Status:** approved

> Derived from the user-approved rework plan
> (iwiki `iclaude/reference/plans/shared-store-per-project-home-architecture`, slice S7)
> and the user's instruction to take S7 next. Q1–Q6 restate the plan's decisions; no new
> scope was invented.

## Objective

Per-project homes are now the default, so `.claude-homes/` grows with every project and
worktree; icodex's evidence (15 GB across 21 untraceable homes, permanent homes for
deleted worktree branches) shows unbounded growth without lifecycle tooling. S1's
`home.json` marker made every home attributable; S5's copy-only migration made deletion
safe (a deleted home re-migrates). S7 adds the operability layer: list homes with
attribution and size, prune orphans whose project root no longer exists, and delete one
home by id — always with confirmation, never automatically.

## Desired Outcomes

- `--list-homes` prints one line per home: id, project root (from `home.json`, `unknown`
  when the marker is missing or unreadable), size, last-used date, and an `orphan` mark
  when the recorded root no longer exists on disk.
- `--clean-homes` removes exactly the orphan homes (marker present, root missing) after
  a per-run confirmation; a declined confirmation or non-interactive run without an
  explicit yes removes nothing. Homes with an unknown marker and homes whose root exists
  are never touched.
- `--clean-home <id>` removes exactly the named home after confirmation; an unknown id
  fails with a clear error and removes nothing.
- Deleting a live project's home is recoverable by design: the next launch re-migrates
  from the untouched store (already guaranteed by S5, referenced not re-tested).
- No automatic pruning: nothing is deleted on the ordinary launch path.

## Health Metrics

- Existing tests keep passing: lock-safety 13/13, home-migration 16/16,
  per-project-home 20/20, shared-asset-links 21/21, settings-managed-region 18/18,
  launch-wiring 12/12, env-map, config-migration, regression-phase0.
- S1–S6 GWT scenarios stay valid with stable IDs.
- The launch path is untouched — list/clean run only via their explicit flags.

## Strategic Context

- Interacts with: `home.json` marker (S1), `ISOLATED_HOMES_DIR` global,
  flag dispatch in `iclaude.sh` and `lib/command/usage.sh`; closes the icodex weakness
  "no orphan-home cleanup, no size control" from the analysis.
- Priority trade-off: trust (confirmation-gated, orphans only, unknown never touched)
  over speed.

## Constraints

### Steering (behavioral guidance)

- List output is plain text, one home per line, stable field order — usable by eyes and
  by grep.
- Worktree hint (plan S7.3): an orphan whose id suffix matches a `dev-*` naming pattern
  is already covered by the orphan mark; no extra git introspection.

### Hard (architectural enforcement)

- Deletion candidates are exactly: orphans (readable marker, recorded root absent) for
  `--clean-homes`, and the explicitly named id for `--clean-home`.
- A home without a readable marker is reported `unknown` and is never deleted by
  `--clean-homes`.
- Confirmation required on every deletion path; `ICLAUDE_ASSUME_YES=1` is the only
  non-interactive bypass (for tests and scripting).
- No deletions from the ordinary launch path; no store mutations.

## Autonomy Zones

- Full autonomy (reversible, low risk): module code, tests, docs, wiki updates,
  commit/PR on the `dev-home-lifecycle-gc` branch.
- Guarded (log + evidence): the deletion code itself — must provably remove only
  eligible homes (test-backed for orphan, unknown, live, and named-id cases).
- Proposal-first (needs approval): any automatic pruning, age-based policies, or
  deletion beyond the two named commands.
- No autonomy (human only): merging the PR.

## Stop Rules

- Halt if: correct orphan detection would require deleting anything with an unreadable
  marker, or the ordinary launch path would gain a deletion.
- Escalate if: attribution turns out insufficient to distinguish orphan from live homes.
- Done when: list shows id/root/size/last-used/orphan correctly for live, orphan, and
  marker-less fixtures (tests); clean-homes removes only orphans under ICLAUDE_ASSUME_YES
  and nothing without it (tests); clean-home removes the named id and errors on an
  unknown one (tests); and the full relevant test set passes.
