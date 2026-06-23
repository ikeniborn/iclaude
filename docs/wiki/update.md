# Update

## Overview

Updating Claude Code in iclaude: `--update` runs the universal `update_claude_code` (isolated NVM, system NVM, or root system); `--isolated-update` runs the isolated-only `update_isolated_claude`. Both pre-clean symlinks/temp folders, `npm install -g @latest`, then refresh [[lockfile#Save]]. A post-merge git hook nudges re-install after pulls. See [[nvm]] for the isolated setup.

## Commands

`--update` calls `update_claude_code "$use_system"`; `--isolated-update` calls `update_isolated_claude` (and rejects `--system`); `--check-update` calls `check_update` (in `lib/core/remaining.sh`) to report availability without installing. Dispatch lives in `iclaude.sh`. See [[command]] for the full flag table.

## Update Flow

`update_claude_code` (in `lib/update/update.sh`) is the entry point for `--update`. It detects the runtime context via `detect_nvm` (see [[nvm]]) and branches:

- **Isolated NVM** (`$NVM_DIR == $ISOLATED_NVM_DIR`): sources `nvm.sh`, runs `npm install -g @anthropic-ai/claude-code@latest`, then calls `repair_isolated_environment` (see [[nvm#Repair]]) followed by `save_isolated_lockfile` (see [[lockfile#Save]]).
- **System NVM**: same npm command, then `cleanup_old_claude_installations` and `recreate_claude_symlinks` (see [[update#Cleanup and Symlinks]]).
- **System (non-NVM)**: requires root (`EUID -eq 0`) and runs `npm install -g` with no repair steps.

If NVM is detected but the script runs under sudo, it warns and prompts; confirming downgrades the operation to a system update (`using_nvm=false`).

Before updating, it reads the current version via `get_claude_version`, queries the registry with `npm view @anthropic-ai/claude-code version`, and returns early if already latest (still refreshing the lockfile for isolated environments). Otherwise it asks `Proceed with update? (Y/n)`. After a successful `npm install` it runs `hash -r`, re-reads the version, and errors out with diagnostic hints if the binary is no longer found.

## Pre-Update Cleanup

Both update paths run the same cleanup before any npm invocation, to avoid `EEXIST` and `ENOTEMPTY` errors during npm's post-install:

- Remove all `claude` and `.claude-*` symlinks in `npm-global/bin/`.
- Remove all `.claude-code-*` temporary folders under `npm-global/lib/node_modules/@anthropic-ai/`.
- `update_claude_code` additionally removes an incomplete `claude-code/` directory that lacks `cli.js`.

In `update_claude_code` this runs only when `npm prefix -g` resolves to an NVM path (`*.nvm*`); `update_isolated_claude` targets `$ISOLATED_NVM_DIR/npm-global` directly.

## Isolated Update

`update_isolated_claude` (in `lib/update/isolated.sh`) backs `--isolated-update` — an isolated-only command that needs no sudo. It first calls `setup_isolated_nvm` (see [[nvm#Environment Setup]]) to configure `PATH`, then verifies `$NVM_DIR/nvm.sh` and `npm` are present. Crucially it does NOT source `nvm.sh` itself: that triggers `nvm_auto` → `nvm use`, which can fail under `set -e` in CI when no default alias is set. It relies on the `PATH` already set by `setup_isolated_nvm`.

The sequence:
1. Read current version from `package.json` at `$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/package.json` (fails early if the package is missing).
2. Pre-update cleanup (see [[update#Pre-Update Cleanup]]) — symlinks and `.claude-code-*` temp folders.
3. `npm install -g @anthropic-ai/claude-code@latest`.
4. `hash -r` to clear the bash command cache, then re-read the version from `package.json`.
5. If defined, `repair_vendor_permissions` (see [[nvm#Repair]]) restores execute bits on vendored binaries such as `rg` that git strips after update.
6. If defined, `update_gsd_if_installed` keeps GSD ([[gsd]]) in sync.
7. `save_isolated_lockfile` (see [[lockfile#Save]]) to pin the new version.

On failure it prints recovery hints (check network, `--repair-isolated`, or `--cleanup-isolated` + `--isolated-install`).

## Cleanup and Symlinks

`cleanup_old_claude_installations` (in `lib/update/cleanup.sh`) runs in the system-NVM path after a successful update. It is a no-op unless `NVM_DIR` is set and `npm prefix -g` resolves to an NVM path.

It categorises `.claude-code-*` temporary folders in `npm-global/lib/node_modules/@anthropic-ai/` by modification time:
- **Older than 7 days**: listed (with versions via `get_cli_version`) and auto-removed without prompting.
- **Newer than 7 days**: listed and removed only after an interactive `Y/n` confirmation.

It then scans `npm-global/bin/` for broken `.claude-*` symlinks (target missing) and offers to remove them, and finally offers to remove an incomplete `claude-code/` directory (present but missing `cli.js`).

`recreate_claude_symlinks` (in `lib/update/cleanup.sh`) rebuilds the `claude` symlink after cleanup. It searches `npm-global/lib/node_modules/@anthropic-ai/` for `cli.js`, preferring the standard `claude-code/cli.js`; absent that, it picks the newest `.claude-code-*/cli.js` by modification time. It removes all old `claude`/`.claude-*` symlinks and creates a fresh `claude` symlink (with `chmod +x`) pointing at the located `cli.js`, then reports the version. It returns 1 if no `cli.js` is found.

## Post-Merge Refresh

A tracked git hook at `.githooks/post-merge` (active via `core.hooksPath=.githooks`) runs after `git pull`/merge. When the pulled commit bumped `claudeCodeVersion` in the lockfile, it compares the lockfile version against the real on-disk binary (`claude --version`) and offers a `y/N` prompt to run `--install-from-lockfile`. It is fail-soft: silent when in sync, warning-only in non-interactive environments (CI/GUI), and never blocks the pull. Set `ICLAUDE_NO_AUTO_UPDATE=1` to opt out.

The launch-time `check_lockfile_changes` (see [[lockfile#Hash Tracking]]) is a complementary fallback that catches pulls bypassing git hooks.
