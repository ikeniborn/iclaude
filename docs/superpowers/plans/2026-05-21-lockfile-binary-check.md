# Lockfile Binary Check Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix `check_lockfile_changes` so that a `git pull` with CI-updated `package.json` does not leave Claude Code running against an outdated native binary.

**Architecture:** Add a `bin/claude.exe` existence check inside the "versions match" early-exit branch of `check_lockfile_changes`. If the binary is missing, call `create_claude_symlink` (already handles download + symlink) before updating the hash file. One function, one file, ~8 lines added.

**Tech Stack:** Bash, existing `create_claude_symlink` from `lib/nvm/repair.sh`

---

### Task 1: Apply the fix to `check_lockfile_changes`

**Files:**
- Modify: `lib/lockfile/save.sh:348-353`

The current "versions match" branch (lines 348–353) silently updates the hash without checking whether the native binary actually exists on disk. Replace it with a version that checks `bin/claude.exe` first.

- [ ] **Step 1: Open `lib/lockfile/save.sh` and locate the target block**

Find this exact block (starts at line 348):

```bash
		if [[ -n "$installed_claude_ver" && "$installed_claude_ver" == "$lockfile_claude_ver" ]]; then
			# Installed version matches lockfile — environment is already up to date
			# (e.g. CI pushed npm packages to git, user ran git pull)
			update_lockfile_hash
			return 0
		fi
```

- [ ] **Step 2: Replace the block with the binary-aware version**

Replace the block above with:

```bash
		if [[ -n "$installed_claude_ver" && "$installed_claude_ver" == "$lockfile_claude_ver" ]]; then
			local claude_bin="${ISOLATED_NVM_DIR}/npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
			if [[ -f "$claude_bin" ]]; then
				# Binary present and version matches lockfile — truly up to date
				# (e.g. CI pushed npm packages to git, user ran git pull)
				update_lockfile_hash
				return 0
			fi
			# package.json matches lockfile but native binary is missing.
			# Typical cause: git pull updated package.json (tracked) but bin/claude.exe
			# is excluded from git (>100MB) and was not restored.
			echo ""
			print_info "Native binary missing after git pull — restoring..."
			echo ""
			create_claude_symlink
			update_lockfile_hash
			return 0
		fi
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n lib/lockfile/save.sh
```

Expected: no output, exit code 0.

- [ ] **Step 4: Commit**

```bash
git add lib/lockfile/save.sh
git commit -m "fix(lockfile): restore native binary when missing after git pull

check_lockfile_changes was silently updating the hash when package.json
version matched the lockfile, without verifying bin/claude.exe exists.
After a git pull with a CI auto-update commit, package.json is updated
but the native binary (excluded from git, >100MB) is not. Claude Code
would start against the old binary and prompt for an npm update every run.

Now checks for bin/claude.exe before the silent hash update. If missing,
calls create_claude_symlink() which runs install.cjs (pkg-fetch) and
falls back to npm install -g to restore the binary."
```

---

### Task 2: Manual verification

**Files:** (none changed — verification only)

- [ ] **Step 1: Simulate the bug — remove the binary and stale the hash**

```bash
# Back up binary (it will be restored by the fix)
cp .nvm-isolated/npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe \
   /tmp/claude.exe.bak

# Remove binary (simulates git pull not updating it)
rm .nvm-isolated/npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe

# Stale the hash (simulates lockfile changed by git pull)
echo "stale" > .nvm-isolated/.claude-isolated/.last-lockfile-hash
```

- [ ] **Step 2: Run iclaude and observe output**

```bash
./iclaude.sh --check-isolated 2>&1 | head -30
```

Expected output includes:
```
ℹ Native binary missing after git pull — restoring...
✓ Created: claude symlink
```

Expected: iclaude does NOT show "Lockfile has changed since last environment update" prompt.

- [ ] **Step 3: Verify binary was restored**

```bash
ls -la .nvm-isolated/npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe
```

Expected: file exists, is executable (non-zero size).

- [ ] **Step 4: Verify hash is now current**

```bash
stored=$(cat .nvm-isolated/.claude-isolated/.last-lockfile-hash)
current=$(sha256sum .nvm-isolated-lockfile.json | awk '{print $1}')
[ "$stored" = "$current" ] && echo "MATCH" || echo "MISMATCH: stored=$stored current=$current"
```

Expected: `MATCH`

- [ ] **Step 5: Verify subsequent launch is silent**

```bash
./iclaude.sh --check-isolated 2>&1 | grep -c "Lockfile has changed"
```

Expected: `0`

- [ ] **Step 6: Restore backup if needed**

```bash
# Only if binary was not restored by the fix (should not be needed)
# cp /tmp/claude.exe.bak \
#    .nvm-isolated/npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe
```
