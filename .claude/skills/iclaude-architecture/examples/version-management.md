# Version Management Component Example

This example demonstrates the Version Management component architecture and usage patterns.

## Component Overview

**Module**: Version Management
**Location**: iclaude.sh:616-768
**Functions**: `save_isolated_lockfile`, `install_from_lockfile`, `update_isolated_claude`, `get_cli_version`

## Key Features

1. **Lockfile-Based Versioning**
   - Track exact versions of all components
   - JSON format for easy parsing
   - Git-friendly (committed to repository)

2. **Reproducible Installations**
   - Install exact versions from lockfile
   - Team synchronization
   - CI/CD compatibility

3. **Version Detection**
   - Automatic version detection for all components
   - Handles multiple installation sources
   - Validates version consistency

4. **Update Management**
   - Safe update workflow
   - Automatic lockfile regeneration
   - Rollback support via git

## Lockfile Format

```json
{
  "nodeVersion": "18.20.8",
  "claudeCodeVersion": "2.1.15",
  "routerVersion": "1.0.5",
  "ghCliVersion": "2.45.0",
  "lspServers": {
    "pyright": "1.1.347",
    "@vtsls/language-server": "0.2.3",
    "gopls": "0.14.2",
    "rust-analyzer": "2024-01-15"
  },
  "lspPlugins": {
    "pyright-lsp@claude-plugins-official": "1.0.0",
    "typescript-lsp@claude-plugins-official": "1.0.0",
    "gopls-lsp@claude-plugins-official": "1.0.0"
  },
  "installedAt": "2026-01-14T10:39:51Z",
  "nvmVersion": "0.39.7"
}
```

## Example Usage

### Save Lockfile

```bash
# Generate lockfile from current installation
save_isolated_lockfile

# Detects versions:
# - Node.js: node --version
# - Claude Code: claude --version or package.json parsing
# - Router: ccr --version (if installed)
# - gh CLI: gh --version (if installed)
# - LSP servers: npm list -g --depth=0 | grep -E "(pyright|vtsls|gopls|rust-analyzer)"
# - LSP plugins: claude /plugin list (if Claude running)
# - NVM: cat $NVM_DIR/.nvm-version
# - Timestamp: date -u +"%Y-%m-%dT%H:%M:%SZ"

# Creates: .nvm-isolated-lockfile.json
```

### Install from Lockfile

```bash
# Install exact versions from lockfile
./iclaude.sh --install-from-lockfile

# Workflow:
# 1. Read lockfile versions
# 2. Install NVM (if not exists)
# 3. Install Node.js (exact version)
#    nvm install 18.20.8
# 4. Install Claude Code (exact version)
#    npm install -g @anthropic-ai/claude-code@2.1.15
# 5. Install Router (if version != "not installed")
#    npm install -g @musistudio/claude-code-router@1.0.5
# 6. Install gh CLI (if version != "not installed")
#    # Linux: wget GitHub release, extract, move to path
#    # macOS: brew install gh@2.45.0
# 7. Install LSP servers (exact versions)
#    npm install -g pyright@1.1.347
#    npm install -g @vtsls/language-server@0.2.3
# 8. Install LSP plugins (manual step, requires Claude running)
#    echo "Run: /plugin install pyright-lsp@claude-plugins-official"
# 9. Create symlinks
# 10. Verify versions match lockfile
```

### Update Claude Code

```bash
# Update to latest version and regenerate lockfile
./iclaude.sh --update

# Workflow:
# 1. Backup current lockfile
#    cp .nvm-isolated-lockfile.json .nvm-isolated-lockfile.json.backup
# 2. Run npm update
#    npm update -g @anthropic-ai/claude-code
# 3. Cleanup temporary folders
#    rm -rf .nvm-isolated/versions/node/*/lib/node_modules/.claude-code-*
# 4. Recreate symlinks
#    ./iclaude.sh --repair-isolated
# 5. Regenerate lockfile
#    save_isolated_lockfile
# 6. Show version change
#    echo "Updated: 2.1.7 → 2.1.15"
```

### Get CLI Version

```bash
# Detect Claude Code version
get_cli_version

# Detection methods (in order):
# 1. Try: claude --version
#    Output: "Claude Code 2.1.15"
#    Parse: "2.1.15"
#
# 2. Try: package.json parsing
#    File: .nvm-isolated/versions/node/v18.20.8/lib/node_modules/@anthropic-ai/claude-code/package.json
#    Parse: jq -r '.version'
#
# 3. Try: npm list
#    Command: npm list -g @anthropic-ai/claude-code
#    Output: "@anthropic-ai/claude-code@2.1.15"
#    Parse: "2.1.15"
#
# Returns: version string or "unknown"
```

## Workflow Example

### Team Synchronization

```bash
# Developer A updates Claude Code
cd iclaude
./iclaude.sh --update

# Lockfile changes:
# - claudeCodeVersion: "2.1.7" → "2.1.15"
# - installedAt: "2026-01-10T08:23:15Z" → "2026-01-14T10:39:51Z"

# Commit lockfile
git add .nvm-isolated-lockfile.json
git commit -m "chore: update Claude Code to v2.1.15"
git push

# Developer B pulls changes
git pull

# Install exact versions from lockfile
./iclaude.sh --install-from-lockfile

# Result: Both developers have identical versions
```

### CI/CD Integration

```bash
#!/bin/bash
# .github/workflows/test.yml

# Step 1: Checkout repository
git clone https://github.com/user/iclaude.git
cd iclaude

# Step 2: Install from lockfile (reproducible)
./iclaude.sh --install-from-lockfile

# Step 3: Verify versions
./iclaude.sh --check-isolated

# Step 4: Run tests with exact versions
./iclaude.sh --test
```

### Rollback via Git

```bash
# Current lockfile (broken version)
cat .nvm-isolated-lockfile.json
# "claudeCodeVersion": "2.1.15"  (has bug)

# View git history
git log --oneline .nvm-isolated-lockfile.json
# abc123 chore: update Claude Code to v2.1.15
# def456 chore: update Claude Code to v2.1.7

# Rollback to previous version
git checkout def456 -- .nvm-isolated-lockfile.json

# Reinstall from rolled-back lockfile
./iclaude.sh --install-from-lockfile

# Verify
./iclaude.sh --check-isolated
# Claude Code Version: 2.1.7
```

## Integration with Other Components

### Isolated Environment Integration

```bash
# Component: Isolated Environment (iclaude.sh:361-978)

# After isolated install, save lockfile
./iclaude.sh --isolated-install
# Internally calls: save_isolated_lockfile

# Lockfile captures current state
cat .nvm-isolated-lockfile.json
```

### Update Management Integration

```bash
# Component: Update Management (iclaude.sh:529-2389)

# Update workflow uses lockfile
./iclaude.sh --update
# 1. npm update -g @anthropic-ai/claude-code
# 2. save_isolated_lockfile (automatic)
# 3. git diff .nvm-isolated-lockfile.json (show changes)
```

### LSP Integration

```bash
# Lockfile tracks LSP servers and plugins separately

# LSP servers (npm packages):
"lspServers": {
  "pyright": "1.1.347",
  "@vtsls/language-server": "0.2.3"
}

# LSP plugins (Claude Code plugins):
"lspPlugins": {
  "pyright-lsp@claude-plugins-official": "1.0.0",
  "typescript-lsp@claude-plugins-official": "1.0.0"
}

# Install LSP servers from lockfile:
./iclaude.sh --install-from-lockfile
# Runs: npm install -g pyright@1.1.347 @vtsls/language-server@0.2.3

# Install LSP plugins (manual, requires Claude running):
# /plugin install pyright-lsp@claude-plugins-official
# /plugin install typescript-lsp@claude-plugins-official
```

## Version Detection Implementation

### Node.js Version

```bash
# Method 1: node --version
node --version
# Output: v18.20.8
# Parse: Remove 'v' prefix → "18.20.8"

# Method 2: .nvmrc (if exists)
cat .nvm-isolated/.nvmrc
# Output: 18.20.8
```

### Claude Code Version

```bash
# Method 1: claude --version (preferred)
claude --version
# Output: "Claude Code 2.1.15"
# Parse: Extract "2.1.15"

# Method 2: package.json
jq -r '.version' .nvm-isolated/versions/node/v18.20.8/lib/node_modules/@anthropic-ai/claude-code/package.json
# Output: "2.1.15"

# Method 3: npm list
npm list -g @anthropic-ai/claude-code --depth=0
# Output: "@anthropic-ai/claude-code@2.1.15"
# Parse: Extract "2.1.15"
```

### Router Version

```bash
# Method 1: ccr --version
ccr --version
# Output: "1.0.5"

# Method 2: package.json (if ccr not in PATH)
jq -r '.version' .nvm-isolated/versions/node/v18.20.8/lib/node_modules/@musistudio/claude-code-router/package.json
# Output: "1.0.5"

# Method 3: Not installed
# Returns: "not installed"
```

### gh CLI Version

```bash
# Method 1: gh --version
gh --version
# Output: "gh version 2.45.0 (2024-03-05)"
# Parse: Extract "2.45.0"

# Method 2: Not installed
# Returns: "not installed"
```

### LSP Server Versions

```bash
# Method 1: npm list -g
npm list -g --depth=0 | grep -E "(pyright|vtsls|gopls)"
# Output:
# ├── pyright@1.1.347
# ├── @vtsls/language-server@0.2.3

# Parse:
# pyright: "1.1.347"
# @vtsls/language-server: "0.2.3"

# Method 2: Binary version (if available)
pyright --version
# Output: "1.1.347"
```

## Troubleshooting

### Lockfile Version Mismatch

```bash
# Symptom:
./iclaude.sh --check-isolated
# ✗ Claude Code version mismatch (installed: 2.1.15, lockfile: 2.1.7)

# Cause: Manual update without regenerating lockfile

# Solution 1: Regenerate lockfile
save_isolated_lockfile
git add .nvm-isolated-lockfile.json
git commit -m "chore: update lockfile to match installed versions"

# Solution 2: Reinstall from lockfile
./iclaude.sh --install-from-lockfile
```

### Version Detection Fails

```bash
# Symptom:
get_cli_version
# Returns: "unknown"

# Cause: Claude Code not properly installed

# Solution:
npm install -g @anthropic-ai/claude-code
./iclaude.sh --repair-isolated
get_cli_version
# Returns: "2.1.15"
```

### LSP Server Not in Lockfile

```bash
# Symptom:
cat .nvm-isolated-lockfile.json
# "lspServers": {}  (empty)

# Cause: LSP servers installed after lockfile generation

# Solution: Regenerate lockfile
./iclaude.sh --install-lsp python typescript
save_isolated_lockfile

# Verify:
cat .nvm-isolated-lockfile.json
# "lspServers": {
#   "pyright": "1.1.347",
#   "@vtsls/language-server": "0.2.3"
# }
```

## Testing

```bash
# Verify lockfile format
jq empty .nvm-isolated-lockfile.json
# No output = valid JSON

# Test version detection
get_cli_version
# Should return version string

# Test lockfile generation
save_isolated_lockfile
git diff .nvm-isolated-lockfile.json
# Shows changes

# Test installation from lockfile
./iclaude.sh --install-from-lockfile
./iclaude.sh --check-isolated
# All versions should match lockfile
```

## Related Components

- **Isolated Environment** - Lockfile tracks versions of isolated components
- **Update Management** - Updates trigger automatic lockfile regeneration
- **LSP Integration** - LSP servers and plugins tracked separately
- **Router Management** - Router version included in lockfile

## References

- Main implementation: iclaude.sh:616-768
- Save function: `save_isolated_lockfile()` - iclaude.sh:616
- Install function: `install_from_lockfile()` - iclaude.sh:681
- Version detection: `get_cli_version()` - iclaude.sh:319
- Lockfile path: `.nvm-isolated-lockfile.json`
