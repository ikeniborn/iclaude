---
review:
  intent_hash: 3e3be67b21ee1e28
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
  intent_hash: 3e3be67b21ee1e28
  last_run: 2026-09-04
---

# Intent: binary-integrity-pinning

**Date:** 2026-09-04
**Status:** approved

> Derived from the user-approved rework plan
> (iwiki `iclaude/reference/plans/shared-store-per-project-home-architecture`, slice S8)
> and the user's instruction to take S8 next. Q1–Q6 restate the plan's decisions; no new
> scope was invented. S8.3 (npm dist.integrity) is low priority and deliberately out of
> scope.

## Objective

iclaude's lockfile pins versions only; icodex pins the actual artifact
(`{version, asset, sha256}`). Claude Code cannot use icodex's single-static-binary model
(npm delivery + native postinstall), so the plan's middle path applies: hash what is
actually on disk. S8 records the sha256 of the installed Claude native binary in
`.nvm-isolated-lockfile.json` after every install/update through the existing chokepoint
and verifies it at startup — a mismatch warns with a repair hint, never silently, never
blocking the launch.

## Desired Outcomes

- After installing `@anthropic-ai/claude-code` through
  `install_npm_package_with_lockfile`, the lockfile carries `claudeBinarySha256` equal
  to the sha256 of the resolved installed binary (`npm-global/bin/claude` target,
  `claude.exe`, or legacy `cli.js`).
- At startup (next to the lockfile drift check), a recorded hash that does not match
  the on-disk binary produces a warning naming the mismatch and hinting
  `--install-from-lockfile` / `--update`; the launch continues.
- A missing recorded hash (pre-S8 lockfile), a missing binary, or missing `jq`/`sha256sum`
  degrade silently or with a warning — never an error, never a blocked launch.
- Installing any other npm package (router, LSP servers) records no binary hash.
- A matching hash produces no output (quiet on the healthy path).

## Health Metrics

- Existing tests keep passing: lockfile-core-sync 27/27, lock-safety 13/13,
  home-migration 16/16, per-project-home 20/20, shared-asset-links 21/21,
  settings-managed-region 18/18, launch-wiring 12/12, env-map, config-migration,
  regression-phase0.
- S1–S7 GWT scenarios stay valid with stable IDs.
- The install chokepoint's arguments, outputs, and error propagation are unchanged.

## Strategic Context

- Interacts with: `_install_npm_package_with_lockfile_unlocked` (`lib/nvm/install.sh` —
  write point after `set_lockfile_field`), `lib/lockfile/save.sh` (record/verify
  functions live with the hash logic), startup call sites of `check_lockfile_changes`
  (`iclaude.sh`), `set_lockfile_field` (`lib/core/json.sh`).
- Priority trade-off: trust (warn-only, quiet healthy path, no new failure modes) over
  speed.

## Constraints

### Steering (behavioral guidance)

- Resolve the binary with the same layout preferences as `get_nvm_claude_path`
  (bin/claude target → claude.exe → cli.js).
- Record inside the existing store lock (the chokepoint already runs under it since S6).

### Hard (architectural enforcement)

- Verification is warn-only: no exit-code change, no launch block, ever.
- The hash is recorded only for `@anthropic-ai/claude-code`.
- No network calls; no npm registry queries (S8.3 out of scope).
- The lockfile field is exactly `claudeBinarySha256`; no other lockfile shape changes.

## Autonomy Zones

- Full autonomy (reversible, low risk): record/verify functions, wiring, tests, docs,
  wiki updates, commit/PR on the `dev-binary-integrity-pinning` branch.
- Guarded (log + evidence): touching the install chokepoint — contract unchanged
  (test-backed by the existing lockfile-core-sync suite).
- Proposal-first (needs approval): blocking semantics, hashing other packages,
  dist.integrity recording, lockfile shape changes beyond the one field.
- No autonomy (human only): merging the PR.

## Stop Rules

- Halt if: warn-only semantics cannot be preserved, or the chokepoint contract would
  change observably.
- Escalate if: the binary cannot be resolved deterministically across the three known
  layouts.
- Done when: the recorded hash matches the installed fixture binary after a simulated
  install (test), a tampered binary triggers the mismatch warning while exit stays 0
  (test), absent hash/binary/jq degrade quietly (tests), non-claude packages record
  nothing (test), and the full relevant test set passes.
