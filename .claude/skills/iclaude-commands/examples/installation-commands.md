# Installation & Update Commands

## Commands Table

| Command | Purpose | Duration | Notes |
|---------|---------|----------|-------|
| `--isolated-install` | Install isolated environment | ~5-10 min | Downloads Node.js + Claude |
| `--update` | Update Claude Code in isolated env | ~2-3 min | Preserves Node.js version |
| `--install-from-lockfile` | Restore exact versions from lockfile | ~5-10 min | Reproducible deployments |
| `--repair-isolated` | Fix broken symlinks | ~5 sec | After git clone |
| `--cleanup-isolated` | Delete isolated environment | ~10 sec | Preserves lockfile |
| `--install-router` | Install Router npm package | ~1-2 min | Global npm install |
| `--install-lsp` | Install LSP servers | ~2-5 min | Default: TS + Python |
| `--install-microvm` | Install Firecracker microVM | ~5-10 min | Requires KVM (/dev/kvm) |

## Detailed Examples

### Initial Setup

```bash
# 1. Clone repository
git clone https://github.com/user/iclaude.git
cd iclaude

# 2. Install isolated environment
./iclaude.sh --isolated-install

# Output:
# Installing isolated NVM environment...
# Downloading NVM v0.39.7...
# Installing Node.js v18.20.8...
# Installing Claude Code CLI...
# Creating symlinks...
# Saving lockfile...
# ✅ Installation complete!
```

### Update Claude Code

```bash
./iclaude.sh --update

# Output:
# Updating Claude Code...
# npm update -g @anthropic-ai/claude-code
# Cleaning up temporary folders...
# Recreating symlinks...
# Updating lockfile...
# ✅ Claude Code updated to 2.1.16
```

**After update, verify:**
```bash
./iclaude.sh --check-isolated
# Claude Code: 2.1.16 ✅
```

### Restore from Lockfile

**Use case:** CI/CD, new team member, or clean environment

```bash
# Clone repo
git clone https://github.com/user/iclaude.git
cd iclaude

# Restore exact versions
./iclaude.sh --install-from-lockfile

# Output:
# Reading lockfile: .nvm-isolated-lockfile.json
# Installing Node.js v18.20.8...
# Installing Claude Code v2.1.15...
# Installing Router v1.2.3...
# Installing gh CLI v2.45.0...
# Installing LSP servers:
#   - pyright v1.1.347
#   - @vtsls/language-server v0.2.3
# Installing LSP plugins...
# ✅ Environment restored from lockfile
```

### Repair Symlinks After Git Clone

**Problem:** After `git clone`, symlinks point to wrong paths

```bash
./iclaude.sh --repair-isolated

# Output:
# Repairing symlinks...
# ✅ npm → versions/node/v18.20.8/.../npm-cli.js
# ✅ npx → versions/node/v18.20.8/.../npx-cli.js
# ✅ claude → versions/node/v18.20.8/.../@anthropic-ai/claude-code/cli.js
# ✅ Symlinks repaired
```

### Install Router

```bash
./iclaude.sh --install-router

# Output:
# Installing Claude Code Router...
# npm install -g @musistudio/claude-code-router
# Creating router.json from router.json.example...
# ✅ Router installed

# Next steps:
# 1. Edit router.json with provider config
# 2. Export API keys: export DEEPSEEK_API_KEY=...
# 3. Launch with: ./iclaude.sh --router
```

### Install LSP Servers

```bash
# Install defaults (TypeScript + Python)
./iclaude.sh --install-lsp

# Install specific languages
./iclaude.sh --install-lsp python go rust

# Output:
# Installing LSP servers...
# npm install -g pyright
# go install golang.org/x/tools/gopls@latest
# rustup component add rust-analyzer
# ✅ LSP servers installed
```

## Cleanup and Maintenance

### Clean Up Isolated Environment

**Warning:** Deletes all installed packages but preserves lockfile

```bash
./iclaude.sh --cleanup-isolated

# Confirmation prompt:
# This will delete .nvm-isolated/ (lockfile preserved)
# Continue? (y/N): y

# Output:
# Removing .nvm-isolated/...
# ✅ Cleanup complete (lockfile preserved)
```

### Reinstall from Scratch

```bash
# 1. Clean up
./iclaude.sh --cleanup-isolated

# 2. Reinstall from lockfile
./iclaude.sh --install-from-lockfile

# Result: Fresh installation with exact versions
```

## Troubleshooting

### ENOTEMPTY Error During Update

**Problem:** npm can't delete temporary folders

**Solution:**
```bash
# Wait 5 seconds and retry
sleep 5 && ./iclaude.sh --update

# Or manually delete temp folders
rm -rf .nvm-isolated/versions/node/*/lib/node_modules/.claude-code-*
./iclaude.sh --update
```

### Symlinks Broken After Update

**Problem:** Update didn't recreate symlinks

**Solution:**
```bash
./iclaude.sh --repair-isolated
```

### Lockfile Outdated After Manual npm update

**Problem:** Updated Claude via npm directly, lockfile not updated

**Solution:**
```bash
# Lockfile auto-updates on next check
./iclaude.sh --check-isolated

# Or trigger update manually
./iclaude.sh --update  # Even if already latest
```

### Router Installation Fails

**Problem:** npm permission error or network issue

**Solution:**
```bash
# Check npm prefix
npm config get prefix
# Should be: /path/to/iclaude/.nvm-isolated/npm-global

# Retry installation
./iclaude.sh --install-router

# Manual installation (if needed)
npm install -g @musistudio/claude-code-router
```
