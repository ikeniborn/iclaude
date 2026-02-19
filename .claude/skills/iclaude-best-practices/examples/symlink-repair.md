# Symlink Repair Workflow After Git Operations

This example demonstrates how to diagnose and repair broken symlinks in the isolated environment after git operations.

## Scenario

**Operation**: Clone iclaude repository to new development machine
**Issue**: Symlinks in `.nvm-isolated/` are broken (relative path resolution fails)
**Impact**: `./iclaude.sh` fails to launch Claude Code

## Understanding Symlink Structure

### Why Symlinks Break

Symlinks in `.nvm-isolated/` use **relative paths** to maintain portability:

```bash
# npm symlink (relative path)
.nvm-isolated/npm-global/bin/npm → ../../versions/node/v18.20.8/lib/node_modules/npm/bin/npm-cli.js

# When repository moved/cloned, relative path resolution may fail
# because symlink target depends on current directory structure
```

**Common operations that break symlinks**:
- `git clone` (new repository copy)
- `git pull` (updates Node.js version)
- `git checkout` (switches branches with different Node.js versions)
- Moving repository directory
- Restoring from backup

### Symlinks Managed by iclaude.sh

**npm/npx** (package manager):
```
.nvm-isolated/npm-global/bin/npm → ../../versions/node/v*/lib/node_modules/npm/bin/npm-cli.js
.nvm-isolated/npm-global/bin/npx → ../../versions/node/v*/lib/node_modules/npm/bin/npx-cli.js
```

**Claude Code** (CLI binary):
```
.nvm-isolated/npm-global/bin/claude → ../../versions/node/v*/lib/node_modules/@anthropic-ai/claude-code/cli.js
```

**corepack** (package manager wrapper):
```
.nvm-isolated/npm-global/bin/corepack → ../../versions/node/v*/lib/node_modules/corepack/dist/corepack.js
```

## Diagnostic Workflow

### Step 1: Detect Broken Symlinks

**Symptom**: Launch fails with "command not found"
```bash
./iclaude.sh
# Error: claude: command not found
```

**Check symlink status**:
```bash
./iclaude.sh --check-isolated
```

**Expected output (broken symlinks)**:
```
Checking isolated environment...
✗ npm symlink BROKEN (target not found)
✗ npx symlink BROKEN (target not found)
✗ claude symlink BROKEN (target not found)

Isolated environment has issues. Run --repair-isolated to fix.
```

**Manual verification**:
```bash
# List symlinks in isolated bin directory
ls -la .nvm-isolated/npm-global/bin/

# Check if symlinks are valid
file .nvm-isolated/npm-global/bin/npm
file .nvm-isolated/npm-global/bin/npx
file .nvm-isolated/npm-global/bin/claude
```

**Valid symlink output**:
```
.nvm-isolated/npm-global/bin/npm: symbolic link to ../../versions/node/v18.20.8/lib/node_modules/npm/bin/npm-cli.js
```

**Broken symlink output**:
```
.nvm-isolated/npm-global/bin/npm: broken symbolic link to ../../versions/node/v18.20.8/lib/node_modules/npm/bin/npm-cli.js
```

### Step 2: Identify Root Cause

**Check Node.js installation**:
```bash
# Verify Node.js directory exists
ls -la .nvm-isolated/versions/node/

# Check lockfile for expected version
cat .nvm-isolated-lockfile.json | jq -r '.nodeVersion'
```

**Possible causes**:

**Cause A: Node.js not installed**
```bash
ls -la .nvm-isolated/versions/node/
# Output: ls: cannot access '.nvm-isolated/versions/node/': No such file or directory
```
→ Run `--isolated-install` to install from lockfile

**Cause B: Version mismatch**
```bash
# Lockfile shows v18.20.8
cat .nvm-isolated-lockfile.json | jq -r '.nodeVersion'
# Output: 18.20.8

# But directory shows v18.19.0
ls .nvm-isolated/versions/node/
# Output: v18.19.0
```
→ Run `--install-from-lockfile` to restore correct version

**Cause C: Symlinks outdated**
```bash
# Node.js installed at correct version
ls .nvm-isolated/versions/node/
# Output: v18.20.8

# But symlinks point to old version
readlink .nvm-isolated/npm-global/bin/npm
# Output: ../../versions/node/v18.19.0/lib/node_modules/npm/bin/npm-cli.js
```
→ Run `--repair-isolated` to recreate symlinks

## Repair Workflows

### Workflow 1: Simple Symlink Repair

**When to use**: Node.js installed, versions match, only symlinks broken

**Command**:
```bash
./iclaude.sh --repair-isolated
```

**What happens**:
1. Detects Node.js version in `.nvm-isolated/versions/node/`
2. Recreates npm/npx/corepack symlinks
3. Recreates Claude Code symlink
4. Sets execute permissions (chmod +x)
5. Validates all symlinks

**Expected output**:
```
Repairing isolated environment symlinks...
✓ npm symlink recreated
✓ npx symlink recreated
✓ corepack symlink recreated
✓ claude symlink recreated
Symlink repair completed successfully.
```

**Verification**:
```bash
./iclaude.sh --check-isolated
# Should show all symlinks valid
```

### Workflow 2: Full Environment Restoration

**When to use**: Node.js missing or version mismatch

**Command**:
```bash
./iclaude.sh --install-from-lockfile
```

**What happens**:
1. Reads `.nvm-isolated-lockfile.json`
2. Installs exact Node.js version from lockfile
3. Installs exact Claude Code version from lockfile
4. Installs Router (if lockfile has version != "not installed")
5. Installs LSP servers (all listed versions)
6. Creates all symlinks
7. Validates environment

**Expected output**:
```
Installing from lockfile (.nvm-isolated-lockfile.json)...
Installing Node.js v18.20.8...
Installing Claude Code v2.1.7...
Installing Router v1.0.5...
Installing LSP servers...
  pyright v1.1.347
  @vtsls/language-server v0.2.3
Creating symlinks...
Installation completed successfully.
```

**Verification**:
```bash
./iclaude.sh --check-isolated
# Should show all components at lockfile versions
```

### Workflow 3: Clean Reinstall

**When to use**: Isolated environment corrupted beyond repair

**Commands**:
```bash
# Step 1: Clean up isolated environment
./iclaude.sh --cleanup-isolated

# Step 2: Reinstall from lockfile
./iclaude.sh --install-from-lockfile
```

**What happens**:
1. **Cleanup**: Removes `.nvm-isolated/` (preserves lockfile)
2. **Reinstall**: Full installation from lockfile

**Warning**: This deletes all isolated configuration (history, sessions, credentials)

## Post-Git Operation Checklist

### After Git Clone

```bash
# 1. Clone repository
git clone https://github.com/user/iclaude.git
cd iclaude

# 2. Verify lockfile exists
ls -la .nvm-isolated-lockfile.json

# 3. Check if isolated environment needs repair
./iclaude.sh --check-isolated

# 4. Repair if needed
./iclaude.sh --repair-isolated

# 5. Verify repair success
./iclaude.sh --check-isolated
```

### After Git Pull

```bash
# 1. Pull latest changes
git pull origin master

# 2. Check if lockfile changed
git diff HEAD@{1} .nvm-isolated-lockfile.json

# 3. If lockfile changed, reinstall from lockfile
if git diff --quiet HEAD@{1} .nvm-isolated-lockfile.json; then
    echo "Lockfile unchanged, repair symlinks only"
    ./iclaude.sh --repair-isolated
else
    echo "Lockfile changed, reinstall from lockfile"
    ./iclaude.sh --install-from-lockfile
fi

# 4. Verify environment
./iclaude.sh --check-isolated
```

### After Git Checkout

```bash
# 1. Checkout branch
git checkout feature-branch

# 2. Check for Node.js version changes
git diff master -- .nvm-isolated-lockfile.json

# 3. Repair or reinstall
if git diff --quiet master -- .nvm-isolated-lockfile.json; then
    ./iclaude.sh --repair-isolated
else
    ./iclaude.sh --install-from-lockfile
fi

# 4. Verify environment
./iclaude.sh --check-isolated
```

## Common Issues and Solutions

### Issue 1: Permission Denied After Repair

**Error**:
```bash
./iclaude.sh
# Error: npm: Permission denied
```

**Cause**: Symlinks not executable

**Solution**:
```bash
# Fix permissions manually
chmod +x .nvm-isolated/npm-global/bin/*

# Or run repair again
./iclaude.sh --repair-isolated
```

### Issue 2: Symlink Points to Wrong Node.js Version

**Symptom**:
```bash
readlink .nvm-isolated/npm-global/bin/npm
# Output: ../../versions/node/v18.19.0/... (old version)

cat .nvm-isolated-lockfile.json | jq -r '.nodeVersion'
# Output: 18.20.8 (expected version)
```

**Cause**: Symlinks not updated after Node.js version change

**Solution**:
```bash
# Reinstall from lockfile to get correct Node.js version
./iclaude.sh --install-from-lockfile
```

### Issue 3: Claude Code Symlink Missing After Update

**Symptom**:
```bash
./iclaude.sh --check-isolated
# ✗ claude symlink BROKEN (target not found)
```

**Cause**: `npm update` created temporary folder, symlink points to old location

**Solution**:
```bash
# Repair symlinks (script auto-detects new location)
./iclaude.sh --repair-isolated

# Or run update again (includes symlink recreation)
./iclaude.sh --update
```

### Issue 4: Symlinks Valid But Launch Still Fails

**Symptom**:
```bash
./iclaude.sh --check-isolated
# ✓ All symlinks valid

./iclaude.sh
# Error: claude: command not found
```

**Cause**: PATH not configured correctly

**Diagnosis**:
```bash
# Check if isolated bin directory in PATH
echo $PATH | grep -o ".nvm-isolated/npm-global/bin"

# Manually test symlink
.nvm-isolated/npm-global/bin/claude --version
```

**Solution**:
```bash
# Script should handle PATH automatically
# If not, manually source NVM setup
source .nvm-isolated/nvm.sh
nvm use 18.20.8

# Then try launch
./iclaude.sh
```

## Automated Repair Strategies

### Git Hook for Automatic Repair

Create `.git/hooks/post-checkout`:

```bash
#!/bin/bash

# Auto-repair symlinks after checkout
cd "$(git rev-parse --show-toplevel)" || exit 1

if [[ -f "./iclaude.sh" ]]; then
    echo "Checking isolated environment after checkout..."
    ./iclaude.sh --check-isolated --quiet || {
        echo "Repairing isolated environment..."
        ./iclaude.sh --repair-isolated
    }
fi
```

Make hook executable:
```bash
chmod +x .git/hooks/post-checkout
```

### Pre-Launch Check Wrapper

Create `~/.local/bin/iclaude-safe`:

```bash
#!/bin/bash

ICLAUDE_DIR="$HOME/projects/iclaude"
cd "$ICLAUDE_DIR" || exit 1

# Check isolated environment before launch
if ! ./iclaude.sh --check-isolated --quiet; then
    echo "Isolated environment needs repair. Run ./iclaude.sh --repair-isolated? [Y/n]"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        ./iclaude.sh --repair-isolated || exit 1
    else
        echo "Aborted. Fix isolated environment manually."
        exit 1
    fi
fi

# Launch Claude Code
exec ./iclaude.sh "$@"
```

Make wrapper executable:
```bash
chmod +x ~/.local/bin/iclaude-safe

# Use safe wrapper instead of direct launch
iclaude-safe
```

## Best Practices

### 1. Always Check Before Launch

```bash
# Good habit: check before every launch
./iclaude.sh --check-isolated && ./iclaude.sh
```

### 2. Repair After Git Operations

```bash
# After clone/pull/checkout
git pull && ./iclaude.sh --repair-isolated
```

### 3. Commit Lockfile Changes

```bash
# After updating Claude Code or Node.js
./iclaude.sh --update
git add .nvm-isolated-lockfile.json
git commit -m "chore: update lockfile after Claude Code upgrade"
```

### 4. Document Team Workflow

Add to team README:
```markdown
## Setup for New Developers

1. Clone repository:
   ```bash
   git clone https://github.com/team/iclaude.git
   cd iclaude
   ```

2. Restore environment from lockfile:
   ```bash
   ./iclaude.sh --install-from-lockfile
   ```

3. Verify installation:
   ```bash
   ./iclaude.sh --check-isolated
   ```

4. Launch Claude Code:
   ```bash
   ./iclaude.sh
   ```
```

### 5. Monitor Symlink Health

```bash
# Add to daily checks
crontab -e

# Add line:
0 9 * * * cd /path/to/iclaude && ./iclaude.sh --check-isolated || echo "iclaude symlinks broken" | mail -s "Alert" user@example.com
```

## Troubleshooting Decision Tree

```
Symlinks broken?
├─ Yes
│  ├─ Node.js installed?
│  │  ├─ Yes
│  │  │  ├─ Version matches lockfile?
│  │  │  │  ├─ Yes → Run --repair-isolated
│  │  │  │  └─ No → Run --install-from-lockfile
│  │  │  └─ Version check failed → Run --install-from-lockfile
│  │  └─ No → Run --install-from-lockfile
│  └─ Check failed → Run --check-isolated for details
└─ No
   ├─ Launch still fails?
   │  ├─ Yes → Check PATH configuration
   │  └─ No → Environment OK
   └─ All good → Launch Claude Code
```

## References

- iclaude-best-practices skill: Symlink Management section
- iclaude-best-practices skill: Update Behavior section
- iclaude-architecture skill: Isolated Environment section
- iclaude-commands skill: `--repair-isolated`, `--install-from-lockfile`, `--check-isolated`
