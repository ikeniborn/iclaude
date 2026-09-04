---
review:
  intent_hash: 08fdbe4c427a4757
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
  intent_hash: 08fdbe4c427a4757
  last_run: 2026-09-04
---

# Intent: launch-wiring-home-state

**Date:** 2026-09-04
**Status:** approved

> Derived from the user-approved rework plan
> (iwiki `iclaude/reference/plans/shared-store-per-project-home-architecture`, slice S4)
> and the user's instruction to take S4 next. Q1–Q6 restate the plan's decisions plus the
> bounded-discovery audit result recorded on the task page; no new scope was invented.

## Objective

S1–S3 made per-project homes functional, but the launch pipeline still contains paths
computed from the store constant `ISOLATED_CONFIG_DIR` regardless of the active
`CLAUDE_CONFIG_DIR`. The audit found exactly one defect: `cleanup_stale_session_env`
prunes `ISOLATED_CONFIG_DIR/session-env` — in per-project mode it garbage-collects the
wrong directory, and any project's launch can prune another project's long-idle live
session (the cross-project GC race named in the plan). S4 fixes the GC scope, adds the
two-project disjointness integration test, and records the home-vs-store classification
of every remaining path as documentation.

## Desired Outcomes

- `cleanup_stale_session_env` prunes `session-env/` under the **active**
  `CLAUDE_CONFIG_DIR` (the home in per-project mode, the store in shared mode) and never
  touches the store's `session-env/` when a home is active.
- Two projects launched in per-project mode get disjoint homes: separate markers,
  separate `session-env`/state roots, while both see the same shared store assets
  through S2 links (integration test).
- The home-vs-store classification is documented: PII proxy venv/logs/pid, microVM
  assets, `UV_BIN` stay store-anchored shared infrastructure (PID files are
  session-keyed); Claude Code state, task spool, statusline caches follow the home;
  `materialize_oauth_credentials` is confirmed safe through the S2 link semantics.
- Shared (default) mode behavior is unchanged: GC targets the same directory it targets
  today.

## Health Metrics

- Existing tests keep passing: per-project-home 21/21, shared-asset-links 21/21,
  settings-managed-region 18/18, env-map, config-migration, regression-phase0.
- S1–S3 GWT scenarios stay valid with stable IDs.
- No shared-infrastructure path (PII, microVM, UV) is repointed — no home-side fork of
  venvs or binaries.

## Strategic Context

- Interacts with: `cleanup_stale_session_env` (`lib/launcher/launch.sh`),
  `init_environment` path globals (`lib/core/init.sh` — read-only in this slice),
  `materialize_oauth_credentials` (`lib/oauth/token.sh` — read-only, audited safe),
  S5 (migration/default flip builds on this audit).
- Priority trade-off: trust (no behavior change beyond the GC scope fix) over speed.

## Constraints

### Steering (behavioral guidance)

- Keep the fix minimal: change the GC root resolution, not the retention algorithm.
- Documentation of the classification goes to the wiki architecture page, not into
  code comments.

### Hard (architectural enforcement)

- No repointing of PII/microVM/UV paths — shared infrastructure stays store-anchored.
- No changes to `materialize_oauth_credentials` or `init_environment` path values.
- No migration, no default flip (S5); no locking (S6).
- Shared-mode GC target is unchanged (store dir, as today).

## Autonomy Zones

- Full autonomy (reversible, low risk): the GC scope fix, tests, docs, wiki updates,
  commit/PR on the `dev-launch-wiring-home-state` branch.
- Guarded (log + evidence): anything that deletes directories — the GC must provably
  operate only under the active `CLAUDE_CONFIG_DIR` (test-backed).
- Proposal-first (needs approval): repointing any shared-infrastructure path; changing
  retention semantics; touching oauth materialization.
- No autonomy (human only): merging the PR.

## Stop Rules

- Halt if: the audit classification turns out wrong for some consumer (a store-anchored
  path actually needs per-home state) — that is a scope change to report, not to
  improvise.
- Escalate if: fixing the GC scope requires touching the launch pipeline beyond the one
  function.
- Done when: the GC prunes stale dirs under the active home and leaves the store's
  session-env untouched in per-project mode (test), shared-mode GC behavior is unchanged
  (test), two projects get disjoint homes with shared assets visible in both (test), and
  the full relevant test set passes.
