# Isolated Environment Component Example

This example demonstrates the Isolated Environment component architecture and usage patterns.

## Component Overview

**Module**: Isolated Environment
**Location**: iclaude.sh:361-978
**Functions**: `setup_isolated_nvm`, `install_isolated_nvm`, `repair_isolated_environment`, `cleanup_isolated_environment`

## Key Features

1. **Self-Contained Installation**
   - NVM + Node.js + npm + Claude Code in `.nvm-isolated/` (~278MB)
   - No system dependencies (portable)
   - Git-friendly structure

2. **Symlink Management**
   - npm/npx/corepack symlinks in `npm-global/bin/`
   - Claude Code symlink to cli.js
   - Automatic repair after git clone

3. **Version Locking**
   - Lockfile-based reproducibility
   - Team synchronization via git
   - Exact version restoration

4. **Configuration Isolation**
   - Separate config directory (`.claude-isolated/`)
   - Independent from system installation
   - No conflicts between environments

## Directory Structure

```
.nvm-isolated/                          # Root of isolated environment
  nvm.sh                              # NVM installation script
  versions/
    node/
      v18.20.8/                       # Node.js installation
        bin/
          node                        # Node.js binary
          npm                         # npm binary (symlink)
          npx                         # npx binary (symlink)
          corepack                    # corepack binary (symlink)
        lib/
          node_modules/
            npm/                      # npm package
            @anthropic-ai/
              claude-code/            # Claude Code package
                cli.js                # Main Claude Code script
  npm-global/                         # Global npm packages
    bin/
      npm -> ../../versions/node/v18.20.8/lib/node_modules/npm/bin/npm-cli.js
      npx -> ../../versions/node/v18.20.8/lib/node_modules/npm/bin/npx-cli.js
      claude -> ../../versions/node/v18.20.8/lib/node_modules/@anthropic-ai/claude-code/cli.js
      ccr -> ../../versions/node/v18.20.8/lib/node_modules/@musistudio/claude-code-router/bin/ccr.js
  .claude-isolated/                   # Isolated Claude configuration
    history.jsonl                     # Command history
    session-env/                      # Active sessions
    .credentials.json                 # Anthropic credentials
    settings.json                     # User settings
    skills/                           # Claude Code skills
    scripts/
      claude-statusline.sh            # Status line script
```

## Example Usage

### Install Isolated Environment

```bash
# Fresh installation
./iclaude.sh --isolated-install

# Workflow:
# 1. Check if .nvm-isolated/ already exists
# 2. Download NVM to .nvm-isolated/
# 3. Install latest LTS Node.js (v18.20.8)
# 4. Install @anthropic-ai/claude-code via npm
# 5. Create symlinks in npm-global/bin/
# 6. Generate lockfile (.nvm-isolated-lockfile.json)
# 7. Setup isolated config directory (.claude-isolated/)
```

### Setup Isolated Environment (Existing Installation)

```bash
# Activate isolated environment in current shell
source iclaude.sh
setup_isolated_nvm

# Result:
# - NVM_DIR="/path/to/project/.nvm-isolated"
# - CLAUDE_DIR="/path/to/project/.nvm-isolated/.claude-isolated"
# - PATH updated to include isolated binaries
# - nvm.sh sourced
```

### Repair After Git Clone

```bash
# Symlinks break after git clone (absolute paths)
./iclaude.sh --repair-isolated

# Repairs:
# 1. Recreates npm symlink
# 2. Recreates npx symlink
# 3. Recreates corepack symlink
# 4. Recreates claude symlink
# 5. Recreates ccr symlink (if router installed)
# 6. Sets execute permissions (chmod +x)
# 7. Validates all symlinks
```

### Check Isolated Status

```bash
./iclaude.sh --check-isolated

# Output:
# Isolated NVM Environment Status
# ================================
# NVM Directory: /path/to/.nvm-isolated
# NVM Version: 0.39.7
# Node.js Version: 18.20.8
# npm Version: 10.9.2
# Claude Code Version: 2.1.15
# Router Version: 1.0.5 (or "not installed")
#
# Symlinks:
# ✓ npm -> ../../versions/node/v18.20.8/lib/node_modules/npm/bin/npm-cli.js
# ✓ npx -> ../../versions/node/v18.20.8/lib/node_modules/npm/bin/npx-cli.js
# ✓ claude -> ../../versions/node/v18.20.8/lib/node_modules/@anthropic-ai/claude-code/cli.js
#
# Lockfile: .nvm-isolated-lockfile.json
# ✓ Node.js matches lockfile (18.20.8)
# ✓ Claude Code matches lockfile (2.1.15)
```

### Cleanup Isolated Environment

```bash
# Remove isolated environment (preserves lockfile)
./iclaude.sh --cleanup-isolated

# Prompts:
# "This will remove the isolated NVM installation. Lockfile will be preserved."
# "Continue? [y/N]"

# Removes:
# - .nvm-isolated/ directory
# - All binaries and packages
#
# Preserves:
# - .nvm-isolated-lockfile.json (for reinstallation)
```

## Workflow Example

### Team Setup (First Clone)

```bash
# Step 1: Clone repository
git clone https://github.com/user/iclaude.git
cd iclaude

# Step 2: Symlinks are broken (absolute paths from original machine)
./iclaude.sh
# Error: Symlinks do not exist or are broken

# Step 3: Repair symlinks
./iclaude.sh --repair-isolated

# Step 4: Verify installation
./iclaude.sh --check-isolated

# Step 5: Launch Claude Code
./iclaude.sh
```

### Reproducible Installation from Lockfile

```bash
# Scenario: Team member wants exact same versions
cat .nvm-isolated-lockfile.json
# {
#   "nodeVersion": "18.20.8",
#   "claudeCodeVersion": "2.1.7",
#   "routerVersion": "1.0.5",
#   "ghCliVersion": "2.45.0",
#   "lspServers": {
#     "pyright": "1.1.347",
#     "@vtsls/language-server": "0.2.3"
#   },
#   ...
# }

# Install exact versions from lockfile
./iclaude.sh --install-from-lockfile

# Workflow:
# 1. Reads lockfile versions
# 2. Installs Node.js v18.20.8
# 3. Installs Claude Code v2.1.7
# 4. Installs Router v1.0.5
# 5. Installs gh CLI v2.45.0
# 6. Installs all LSP servers (exact versions)
# 7. Creates symlinks
# 8. Verifies all versions match lockfile
```

## Integration with Other Components

### Version Management Integration

```bash
# Component: Version Management (iclaude.sh:616-768)

# After installation, save lockfile
save_isolated_lockfile

# Lockfile tracks:
# - Node.js version (from node --version)
# - Claude Code version (from get_cli_version())
# - Router version (from ccr --version)
# - gh CLI version (from gh --version)
# - LSP servers (from npm list -g --depth=0)
# - Installation timestamp
```

### Configuration Isolation Integration

```bash
# Component: Configuration Isolation (iclaude.sh:1099-1341)

# Setup isolated config directory
setup_isolated_config

# Creates:
# .nvm-isolated/.claude-isolated/
#   history.jsonl           # Independent command history
#   session-env/            # Separate active sessions
#   .credentials.json       # Isolated Anthropic credentials
#   settings.json           # Environment-specific settings
```

### NVM Detection Integration

```bash
# Component: NVM Detection (iclaude.sh:200-318)

# Priority order for Claude Code binary:
# 1. Isolated environment (if USE_ISOLATED_FLAG=true)
get_nvm_claude_path

# Returns:
# .nvm-isolated/npm-global/bin/claude (if exists)
# OR
# .nvm-isolated/versions/node/v18.20.8/lib/node_modules/@anthropic-ai/claude-code/cli.js
```

## Environment Variables

```bash
# Set by setup_isolated_nvm()
NVM_DIR="/path/to/project/.nvm-isolated"
CLAUDE_DIR="/path/to/project/.nvm-isolated/.claude-isolated"
PATH="/path/to/project/.nvm-isolated/npm-global/bin:$PATH"
PATH="/path/to/project/.nvm-isolated/versions/node/v18.20.8/bin:$PATH"
```

## Symlink Structure

```bash
# npm-global/bin/ symlinks (relative paths)
npm -> ../../versions/node/v18.20.8/lib/node_modules/npm/bin/npm-cli.js
npx -> ../../versions/node/v18.20.8/lib/node_modules/npm/bin/npx-cli.js
corepack -> ../../versions/node/v18.20.8/lib/node_modules/corepack/dist/corepack.js
claude -> ../../versions/node/v18.20.8/lib/node_modules/@anthropic-ai/claude-code/cli.js
ccr -> ../../versions/node/v18.20.8/lib/node_modules/@musistudio/claude-code-router/bin/ccr.js
```

## Portability Considerations

### Why Relative Symlinks?

```bash
# Absolute symlink (breaks after git clone)
/home/user1/project/.nvm-isolated/npm-global/bin/npm ->
  /home/user1/project/.nvm-isolated/versions/node/v18.20.8/lib/node_modules/npm/bin/npm-cli.js

# Relative symlink (portable)
../../versions/node/v18.20.8/lib/node_modules/npm/bin/npm-cli.js

# Works when cloned to different path:
/home/user2/different-path/project/.nvm-isolated/npm-global/bin/npm
# Resolves correctly to:
/home/user2/different-path/project/.nvm-isolated/versions/node/v18.20.8/lib/node_modules/npm/bin/npm-cli.js
```

### Git-Friendly Structure

```bash
# Committed to git:
.nvm-isolated/
  nvm.sh                      # NVM installation script
  versions/node/v18.20.8/     # Node.js installation
  npm-global/bin/             # Symlinks (relative paths)
  .claude-isolated/
    skills/                   # Custom skills
    CLAUDE.md                 # Project documentation

# NOT committed to git (.gitignore):
.nvm-isolated/
  .cache/                     # npm cache
  .npm/                       # npm temporary files
  .claude-isolated/
    history.jsonl             # Session history
    session-env/              # Active sessions
    .credentials.json         # Anthropic credentials
```

## Troubleshooting

### Symlinks Broken After Git Clone

```bash
# Symptom:
./iclaude.sh
# Error: Symlinks do not exist or are broken

# Solution:
./iclaude.sh --repair-isolated
```

### Node.js Version Mismatch

```bash
# Symptom:
./iclaude.sh --check-isolated
# ✗ Node.js version mismatch (installed: 18.20.8, lockfile: 18.19.0)

# Solution: Reinstall from lockfile
./iclaude.sh --install-from-lockfile
```

### Claude Code Binary Not Found

```bash
# Symptom:
get_nvm_claude_path
# Returns: empty string

# Cause: Claude Code not installed or symlink broken

# Solution:
npm install -g @anthropic-ai/claude-code
./iclaude.sh --repair-isolated
```

## Testing

```bash
# Verify isolated environment
./iclaude.sh --check-isolated

# Test NVM detection
bash -c 'source ./iclaude.sh && get_nvm_claude_path'

# Test symlinks
ls -la .nvm-isolated/npm-global/bin/
# Should show relative symlinks

# Test environment variables
bash -c 'source ./iclaude.sh && setup_isolated_nvm && env | grep -E "(NVM_DIR|CLAUDE_DIR|PATH)"'
```

## Related Components

- **Version Management** - Lockfile tracking for reproducibility
- **Configuration Isolation** - Separate config directory for isolated environment
- **NVM Detection** - Priority-based Claude Code binary detection
- **Update Management** - Handles updates within isolated environment

## References

- Main implementation: iclaude.sh:361-978
- Repair function: `repair_isolated_environment()` - iclaude.sh:812
- Setup function: `setup_isolated_nvm()` - iclaude.sh:361
- Install function: `install_isolated_nvm()` - iclaude.sh:489
