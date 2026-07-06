# Intent: CI/CD auto-update — deliver new Claude Code binary via `git pull`

**Date:** 2026-06-14
**Status:** approved

## Objective

Auto-update via CI/CD appears broken: new Claude Code versions are not delivered
by `git pull`, forcing a manual local `iclaude --update`.

Root cause (verified, not the perceived one):
- The scheduled workflow `auto-update-claude.yml` runs daily and **works** — it
  bumps `claudeCodeVersion` in `package.json` + `.nvm-isolated-lockfile.json` and
  commits the **6 tracked metadata files** to `dev`.
- Since **v2.1.114** Claude Code ships as a **native binary** (`bin/claude.exe`,
  ~250MB), which is **gitignored** (`.gitignore:153`, `:191`) because it exceeds
  GitHub's 100MB limit. The legacy `cli.js` (small, tracked) is gone.
- Therefore `git pull dev` delivers the **version number bump but not the
  executable**. The on-disk `claude.exe` stays old → user must run local
  `iclaude --update` (npm postinstall) to actually fetch the new binary.
- This is a **delivery-medium** failure, not a CI failure: git can no longer
  carry the payload. Before v2.1.114, pull delivered real code.

User context: pulls `dev` (local HEAD == origin/dev, fully synced); "new versions"
= the Claude Code npm package version. master is a separate concern (stale since
2026-05-13) and out of scope here.

Why now: the manual `iclaude --update` step is recurring toil after every pull,
and the version number in git lies about what is actually installed.

## Desired Outcomes

- After `git pull` on `dev`, when the pulled commit bumped `claudeCodeVersion`,
  the on-disk `claude.exe` is automatically brought to match the lockfile version
  — **no manual `iclaude --update` required**.
- Running `claude --version` (or the iclaude statusline) after a pull reports the
  version recorded in `.nvm-isolated-lockfile.json`.
- `git pull` itself still succeeds and is never blocked, including offline / no
  network — the binary refresh degrades gracefully with a clear message.

## Health Metrics

These must not degrade:
- **`git pull` reliability** — pull must never fail or hang because of the new
  mechanism (offline, npm down, no TTY → pull still completes).
- **iclaude startup time** — must not regress; the refresh runs on pull (post-merge),
  not on every launch.
- **Existing update paths** — `--update`, `--isolated-update`, `--repair-isolated`
  keep working unchanged (the new mechanism reuses them, adds no parallel
  download logic).
- **CI auto-update workflow** (`auto-update-claude.yml`) — keeps running and
  committing the metadata bump unchanged.
- **CI / non-interactive runs** — must NOT trigger a 250MB download inside GitHub
  Actions or other non-TTY contexts.
- **Security hooks** (block-secrets, redact-secrets) — unaffected.

## Strategic Context

- Interacts with:
  - `git` post-merge hook (new) — trigger after `git pull`/merge.
  - `.nvm-isolated-lockfile.json` — version source of truth (`claudeCodeVersion`).
  - `lib/nvm/repair.sh` (`--repair-isolated`) / `--isolated-update` — existing
    binary download via npm postinstall.
  - `auto-update-claude.yml` — upstream producer of the version bump commits.
  - Hook-install precedent: `lib/lat/check.sh` already installs a pre-commit hook
    (git hooks are not cloned, so install must be wired into an existing setup
    command, e.g. `--repair-isolated`).
- Priority trade-off: **trust** over speed. Never break `git pull`; never silently
  hang; the refresh must be observable.

## Constraints

### Steering (behavioral guidance)
- Reuse the existing `--isolated-update` / `--repair-isolated` download path; do
  not write new binary-fetch logic.
- The post-merge hook must be non-blocking and fail-soft: on any error (offline,
  npm failure) print a clear message and let `pull` succeed.
- Print clear progress when a 250MB download starts (no silent multi-minute stalls).
- Match existing bash module style in `lib/`; install the hook the same way the
  lat pre-commit hook is installed.
- Provide an opt-out (env var or config flag) for users who do not want auto-download.

### Hard (architectural enforcement)
- The 250MB binary MUST NOT be committed to git (confirmed by user; GitHub 100MB
  limit). Delivery stays via npm download.
- The hook MUST NOT run the download in CI / non-TTY environments.
- The hook MUST NOT abort or fail `git pull`.
- Git hook install MUST NOT conflict with the existing pre-commit (lat-check) hook
  or any user-configured `core.hooksPath`.

## Autonomy Zones

- **Full autonomy** (reversible, low risk): writing the post-merge hook script,
  the lockfile-vs-installed version comparison, wiring install into an existing
  setup command, docs.
- **Guarded** (log + threshold): auto-running the 250MB npm download after pull —
  must log/announce; honor the opt-out flag; safe to proceed by default since the
  user chose "git pull — и всё само обновилось".
- **Proposal-first** (needs approval): any change to `.gitignore` tracking strategy,
  to `auto-update-claude.yml`, or introducing Git LFS / GitHub Release assets
  (rejected by hard constraint unless re-opened).
- **No autonomy** (human only): committing the binary to git in any form.

> These zones OVERRIDE subagent-driven-development's "continuous execution,
> don't pause" default. Any task touching proposal-first / no-go decisions
> is marked HUMAN CHECKPOINT in the plan.

## Stop Rules

- Halt if: a chosen approach requires committing the binary to git or modifying
  GitHub-side infra (LFS quota, release pipeline).
- Escalate if: the post-merge hook cannot reliably detect a version mismatch, or
  hook install collides with the existing pre-commit hook / `core.hooksPath`.
- Done when: on a machine carrying an **old** `claude.exe`, a `git pull` of a `dev`
  commit that bumped `claudeCodeVersion` results in the on-disk binary version
  **automatically matching** the lockfile version, with **no manual
  `iclaude --update`** — AND `git pull` still completes successfully when offline
  (hook degrades gracefully) — AND the `auto-update-claude.yml` workflow is
  unaffected.
