# Update

Update flow for Claude Code in the isolated environment: detects the installation type (isolated NVM vs. system), performs pre-update cleanup to avoid npm errors, runs `npm install -g @latest`, refreshes the lockfile, and repairs symlinks. See [[lockfile]] for version pinning and [[nvm]] for the NVM setup that underpins the isolated path.

## Universal Update

`update_claude_code` (in `lib/update/update.sh`) is the entry point for `--update`. It detects the runtime context via `detect_nvm` and branches:

- **Isolated NVM** (`$NVM_DIR == $ISOLATED_NVM_DIR`): sources `nvm.sh`, updates via `npm install -g @anthropic-ai/claude-code@latest`, then calls `repair_isolated_environment` followed by `save_isolated_lockfile` (see [[lockfile#Save]]).
- **Non-isolated NVM**: same npm command, then calls `cleanup_old_claude_installations` and `recreate_claude_symlinks` (see [[update#Cleanup and Symlinks]]).
- **System (non-NVM)**: requires root (`EUID -eq 0`) and proceeds with `npm install -g` without repair steps.

Before any npm invocation, pre-update cleanup removes:
- All existing `claude` and `.claude-*` symlinks in `npm-global/bin/` (avoids `EEXIST` during npm post-install).
- All `.claude-code-*` temporary folders under `npm-global/lib/node_modules/@anthropic-ai/` (avoids `ENOTEMPTY`).
- Incomplete `claude-code/` installations that lack `cli.js`.

The function reads the current version from `package.json` before updating and from `get_claude_version` after, printing both. If the binary is not found after a successful `npm install`, it returns 1 with diagnostic hints. If versions already match the npm registry latest, the function returns early (still refreshes the lockfile for isolated environments).

## Isolated Update

`update_isolated_claude` (in `lib/update/isolated.sh`) is a focused variant used internally when the caller has already established the isolated NVM context. Unlike `update_claude_code`, it does NOT source `nvm.sh` (to avoid `nvm_auto` failures under `set -e` in CI); it relies on the `PATH` already configured by `setup_isolated_nvm`.

The sequence is:
1. Read current version from `package.json` at `$ISOLATED_NVM_DIR/npm-global/lib/node_modules/@anthropic-ai/claude-code/package.json`.
2. Pre-update cleanup (same pattern as the universal function).
3. `npm install -g @anthropic-ai/claude-code@latest`.
4. `hash -r` to clear the bash command cache.
5. Optionally call `repair_vendor_permissions` (if the function is defined) to restore execute bits on vendored binaries such as `rg` that git strips after update.
6. Optionally call `update_gsd_if_installed` to keep GSD ([[gsd]]) in sync.
7. `save_isolated_lockfile` to pin the new version.

## Cleanup and Symlinks

`cleanup_old_claude_installations` (in `lib/update/cleanup.sh`) is used in the non-isolated NVM path after a successful update. It operates only when `NVM_DIR` is set and `npm prefix -g` resolves to an NVM path.

It categorises `.claude-code-*` temporary folders in `npm-global/lib/node_modules/@anthropic-ai/` by age:
- **Older than 7 days**: auto-removed without prompting.
- **Newer than 7 days**: listed with version strings; removal confirmed interactively.

It also scans `npm-global/bin/` for broken symlinks matching `.claude-*` (symlink exists but target is missing) and offers to remove them. Finally, it checks for an incomplete `claude-code/` directory (present but missing `cli.js`) and offers to remove it.

`recreate_claude_symlinks` (in `lib/update/cleanup.sh`) rebuilds the `claude` symlink after cleanup. It searches `npm-global/lib/node_modules/@anthropic-ai/` for `cli.js`, preferring the standard `claude-code/cli.js`; if absent it picks the newest `.claude-code-*/cli.js` by modification time. It then removes all old `claude` and `.claude-*` symlinks in `bin/` and creates a fresh `claude` symlink pointing at the located `cli.js`.

## Post-Merge Refresh

A tracked git hook at `.githooks/post-merge` (activated via `core.hooksPath=.githooks`) runs automatically after `git pull` or merge. When the pulled commit bumped `claudeCodeVersion` in the lockfile, the hook compares the lockfile version against the real on-disk binary (`claude --version`) and offers a `y/N` prompt to run `--install-from-lockfile`. The hook is fail-soft: silent when versions are in sync, warning-only in non-interactive environments (CI/GUI), never blocks the pull. Set `ICLAUDE_NO_AUTO_UPDATE=1` to opt out.

The launch-time `check_lockfile_changes` (see [[lockfile#Hash Tracking]]) is a complementary fallback that catches pulls that bypass git hooks.
