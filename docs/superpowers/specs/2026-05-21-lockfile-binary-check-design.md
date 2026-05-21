# Lockfile Binary Check Fix

**Date:** 2026-05-21  
**Status:** Approved  
**Scope:** `lib/lockfile/save.sh` — `check_lockfile_changes` function

## Problem

After `git pull` that includes a CI auto-update commit (`chore(deps): auto-update Claude Code`), Claude Code starts showing "A new version is available, run npm install..." on every launch.

### Root Cause

`check_lockfile_changes` detects version mismatch via lockfile hash, then runs an early-exit optimization:

```bash
if [[ -n "$installed_claude_ver" && "$installed_claude_ver" == "$lockfile_claude_ver" ]]; then
    update_lockfile_hash
    return 0  # "Already up to date"
fi
```

`installed_claude_ver` is read from `package.json` (tracked in git). After `git pull`, `package.json` reflects the new version — so this comparison passes and iclaude silently marks the environment as up to date.

However, `bin/claude.exe` (~237MB native binary) is excluded from git. The binary is NOT updated by `git pull`. Claude Code launches with the old binary, sees a newer version in `package.json`, and shows the update prompt.

**The gap:** `package.json` version ≠ binary version after `git pull`. iclaude trusts `package.json`; Claude Code runs the binary.

## Design

### Change Location

`lib/lockfile/save.sh`, function `check_lockfile_changes`, lines 347–353.

### Change

Add a binary existence check inside the "versions match" branch before doing the silent hash update:

```bash
# BEFORE:
if [[ -n "$installed_claude_ver" && "$installed_claude_ver" == "$lockfile_claude_ver" ]]; then
    update_lockfile_hash
    return 0
fi

# AFTER:
if [[ -n "$installed_claude_ver" && "$installed_claude_ver" == "$lockfile_claude_ver" ]]; then
    local claude_bin="${ISOLATED_NVM_DIR}/npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
    if [[ -f "$claude_bin" ]]; then
        update_lockfile_hash
        return 0
    fi
    # package.json matches lockfile but binary is missing (typical after git pull)
    echo ""
    print_info "Native binary missing after git pull — restoring..."
    echo ""
    create_claude_symlink
    update_lockfile_hash
    return 0
fi
```

### How `create_claude_symlink` Restores the Binary

Already implemented in `lib/nvm/repair.sh`:

1. Runs `node install.cjs` (postinstall — downloads native binary via pkg-fetch)
2. Fallback: `npm install -g @anthropic-ai/claude-code` (fetches optional platform package)
3. Recreates the `bin/claude` symlink pointing to `bin/claude.exe`

NVM is already sourced at this point (via `setup_isolated_nvm` called earlier in `detect_nvm`).

### Edge Cases

| Scenario | Result |
|---|---|
| Binary present, versions match | Silent hash update — unchanged behavior |
| Binary missing, versions match | `create_claude_symlink` restores binary → hash update |
| Binary missing, versions differ | Falls through to existing prompt for `--install-from-lockfile` |
| `install.cjs` unavailable (corrupt install) | `create_claude_symlink` returns error, hash not updated → next launch prompts again |
| No internet | `npm install` fails, hash not updated → user sees error |

## Testing

### Reproduce the Bug

```bash
# Simulate git pull with CI update (binary missing, package.json updated)
mv .nvm-isolated/npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe /tmp/claude.exe.bak
echo "stale" > .nvm-isolated/.claude-isolated/.last-lockfile-hash

# Launch — should auto-restore binary
./iclaude.sh

# Verify binary restored
ls -la .nvm-isolated/npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe
```

### Verify Normal Path Unchanged

```bash
# Binary present, hash current — should start silently
./iclaude.sh
```

### Success Criteria

- After `git pull` with CI update: iclaude auto-restores binary, Claude Code starts without "new version available" prompt
- Normal launch (binary present): no change in behavior
- Hash file updated after restore: next launch is silent
