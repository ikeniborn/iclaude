# Example: Installing Isolated Environment

This example demonstrates how to set up an isolated iclaude environment from scratch.

## Scenario

You've cloned the iclaude repository and want to install the isolated environment for the first time.

## Steps

```bash
# 1. Navigate to the repository
cd /path/to/iclaude

# 2. Install isolated environment (downloads NVM, Node.js, Claude Code)
./iclaude.sh --isolated-install

# 3. Verify installation
./iclaude.sh --check-isolated

# 4. Save lockfile for team reproducibility
git add .nvm-isolated-lockfile.json
git commit -m "chore: lock iclaude environment versions"
```

## Expected Output

```
Installing isolated NVM environment...
✓ NVM v0.39.7 installed
✓ Node.js v18.20.8 installed
✓ npm v10.5.0 installed
✓ Claude Code v2.1.7 installed
✓ Symlinks created
✓ Lockfile saved

Isolated environment ready at: .nvm-isolated/
```

## Verification

```bash
# Check versions
./iclaude.sh --check-isolated

# Expected output:
# Isolated environment status:
# NVM version: 0.39.7
# Node.js version: 18.20.8
# npm version: 10.5.0
# Claude Code version: 2.1.7
# Lockfile: .nvm-isolated-lockfile.json (exists)
```

## Troubleshooting

**Symlinks broken after git clone?**

```bash
./iclaude.sh --repair-isolated
```

**Want to use specific versions?**

Edit `.nvm-isolated-lockfile.json` before running `--install-from-lockfile`:

```json
{
  "nodeVersion": "18.20.8",
  "claudeCodeVersion": "2.1.7"
}
```

Then install from lockfile:

```bash
./iclaude.sh --install-from-lockfile
```

## Related Commands

- `--repair-isolated` - Fix broken symlinks
- `--cleanup-isolated` - Remove isolated environment (preserves lockfile)
- `--install-from-lockfile` - Install exact versions from lockfile
