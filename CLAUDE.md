# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a utility tool for launching Claude Code through HTTP/HTTPS proxies with automatic credential management. The project consists of a single bash script (`iclaude.sh`) that can be installed globally or used in an isolated environment.

**Key Features:**
- ✅ Isolated NVM environment (portable, no system dependencies)
- ✅ Automatic proxy configuration with credential storage
- ✅ Lockfile-based reproducibility across machines
- ✅ HTTPS/HTTP proxy support with certificate management
- ✅ Git-aware proxy handling (disables proxy for git operations)

---

## Architecture

### Core Components

The script is organized into several key functional areas:

**1. Proxy Management** (lines 56-183)
- `validate_proxy_url()` - Validates proxy URL format (http/https/socks5)
- `parse_proxy_url()` - Extracts protocol, credentials, host, port
- `validate_certificate_file()` - Validates PEM certificates for HTTPS proxies
- `export_proxy_certificate_help()` - Displays certificate export instructions

**2. Environment Detection** (lines 185-220)
- `detect_nvm()` - Detects NVM installation (isolated → system → fallback)
- Priority: Isolated NVM → System NVM → System Node.js
- Uses `USE_ISOLATED_BY_DEFAULT=true` to prefer isolated environment

**3. Claude Code Detection** (lines 222-309)
- `get_nvm_claude_path()` - Finds Claude Code in NVM environment
- Handles temporary installations (`.claude-*`, `.claude-code-*`)
- Searches: binary → temporary binary → cli.js → temporary cli.js

**4. Isolated Environment** (lines 347-530)
- `setup_isolated_nvm()` - Exports environment variables for isolated NVM
- `install_isolated_nvm()` - Downloads and installs NVM to `.nvm-isolated/`
- `install_isolated_nodejs()` - Installs Node.js in isolated environment
- `install_isolated_claude()` - Installs Claude Code in isolated environment
- `save_isolated_lockfile()` - Saves exact versions to lockfile

**5. Credential Management** (lines 332-392)
- `save_credentials()` - Saves proxy settings to `.claude_proxy_credentials` (chmod 600)
- `load_credentials()` - Loads saved proxy settings
- `clear_credentials()` - Removes saved credentials

**6. Git Proxy Management** (lines 519-580)
- `save_git_proxy_settings()` - Backs up existing git proxy config
- `restore_git_proxy_settings()` - Restores git proxy after Claude exits
- Uses environment variables (HTTPS_PROXY, HTTP_PROXY, NO_PROXY)
- Does NOT modify global git config

**7. Proxy Testing** (lines 615-667)
- `test_proxy()` - Tests proxy connectivity via curl
- Validates connection before launching Claude

**8. Symlink Repair** (lines 660-820)
- `repair_isolated_symlinks()` - Fixes symlinks after git clone
- Repairs: npm, npx, corepack, claude (4 critical symlinks)
- Fixes Node.js binary permissions

### Key Constants

```bash
SCRIPT_DIR                    # Resolved script directory (follows symlinks)
CREDENTIALS_FILE              # .claude_proxy_credentials
GIT_BACKUP_FILE              # .claude_git_proxy_backup
ISOLATED_NVM_DIR             # .nvm-isolated/
ISOLATED_LOCKFILE            # .nvm-isolated-lockfile.json
USE_ISOLATED_BY_DEFAULT=true # Use isolated env by default
```

### File Structure

```
iclaude.sh                          # Main script (~2000 lines)
.claude_proxy_credentials           # Saved proxy settings (chmod 600, git-ignored)
.nvm-isolated/                      # Isolated NVM installation (~200-300MB, in git)
  ├── nvm.sh                        # NVM script
  ├── versions/node/vX.X.X/         # Node.js installation
  └── .claude-isolated/             # Isolated Claude config (session data git-ignored)
      ├── CLAUDE.md                 # This file (synced from main project)
      └── skills/                   # Claude Skills (synced from .claude/skills/)
.nvm-isolated-lockfile.json         # Version lockfile (in git)
.claude/                            # Main project Claude config
  └── skills/                       # Master copy of Skills
```

---

## Development Commands

### Testing Changes

```bash
# Test locally without installation
./iclaude.sh

# Test with proxy
./iclaude.sh --proxy http://user:pass@localhost:8118

# Test proxy connectivity only (no launch)
./iclaude.sh --test

# Check isolated environment status
./iclaude.sh --check-isolated

# Repair symlinks after git operations
./iclaude.sh --repair-isolated
```

### Common Development Tasks

**1. Add a new command-line flag:**
```bash
# Use bash-development skill
"Добавь новый флаг --timeout <seconds> для ограничения времени подключения"
```

**2. Debug proxy issues:**
```bash
# Use proxy-management skill
"Отладь проблему: proxy test failed с ошибкой 'SSL certificate problem'"
```

**3. Test isolated installation:**
```bash
# Clean and reinstall
./iclaude.sh --cleanup-isolated
./iclaude.sh --isolated-install
./iclaude.sh --check-isolated
```

**4. Update lockfile after changes:**
```bash
# Automatic during update
./iclaude.sh --update

# Manual update (if needed)
bash -c 'source ./iclaude.sh && save_isolated_lockfile'
```

**5. Sync skills to isolated environment:**
```bash
# Manual sync (skills auto-sync during isolated-install)
cp -r .claude/skills/* .nvm-isolated/.claude-isolated/skills/
```

### Debugging

**Enable bash tracing:**
```bash
bash -x ./iclaude.sh [args]
```

**Check environment variables:**
```bash
# After sourcing isolated environment
source <(./iclaude.sh --check-isolated 2>&1 | grep "export")
env | grep -E "(NVM_DIR|PATH|HTTPS_PROXY|HTTP_PROXY|NODE_EXTRA_CA_CERTS)"
```

**Debug Claude Code detection:**
```bash
# Test detection logic
bash -c 'source ./iclaude.sh && setup_isolated_nvm && get_nvm_claude_path'
```

**Check symlink status:**
```bash
# Detailed symlink check
./iclaude.sh --check-isolated

# Manual inspection
ls -la .nvm-isolated/versions/node/*/bin/{npm,npx,corepack,claude}
```

---

## Skills System

This project uses **Claude Skills** - modular templates for automating development tasks.

### Available Skills

**Project-Specific:**
- 🔧 **bash-development** - Add features, refactor functions, handle errors
- 🌐 **proxy-management** - Configure proxies, debug TLS, test connections
- 📦 **isolated-environment** - Manage isolated NVM, lockfiles, symlinks

**Universal (work in any project):**
- 📋 **structured-planning** - Create plans with JSON validation
- ✅ **validation-framework** - Validate acceptance criteria, syntax
- 🔀 **git-workflow** - Conventional Commits, changelog generation
- 🧠 **thinking-framework** - Structured reasoning for decisions
- ⏸️ **approval-gates** - Request confirmation before critical actions
- ❌ **error-handling** - Handle errors with proper actions (STOP/RETRY/ASK)
- 🔄 **phase-execution** - Execute single phase from phase file
- 📦 **task-decomposition** - Break complex tasks into 2-5 phases

**Usage:** Simply describe the task to Claude, and the appropriate skill will be applied automatically.

**Examples:**
- "Добавь флаг --retry для повторных попыток"
- "Отладь TLS ошибку с HTTPS прокси"
- "Создай lockfile для текущей установки"

**Full Documentation:** See [SKILLS.md](SKILLS.md)

---

## Common Development Patterns

### Adding a New Proxy Feature

**Example: Add SOCKS4 support**

1. **Update URL validation** (`validate_proxy_url`):
   ```bash
   if [[ ! "$url" =~ ^(http|https|socks4|socks5)://.*:[0-9]+$ ]]; then
   ```

2. **Update proxy parsing** (`parse_proxy_url`):
   Already handles all protocols generically.

3. **Test proxy connectivity** (`test_proxy`):
   Add SOCKS4-specific curl test:
   ```bash
   curl --socks4 "$host:$port" --proxy-user "$username:$password" ...
   ```

4. **Update help text** (`show_usage`):
   Add SOCKS4 to supported protocols list.

5. **Test:**
   ```bash
   ./iclaude.sh --proxy socks4://user:pass@localhost:1080 --test
   ```

### Adding Environment Management Functions

**Example: Add function to backup isolated environment**

1. **Create function:**
   ```bash
   backup_isolated_environment() {
       local backup_name="nvm-isolated-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
       tar -czf "$backup_name" .nvm-isolated/
       print_success "Backup created: $backup_name"
   }
   ```

2. **Add command-line flag:**
   ```bash
   --backup-isolated)
       backup_isolated_environment
       exit 0
       ;;
   ```

3. **Update help text** (`show_usage`).

4. **Test:**
   ```bash
   ./iclaude.sh --backup-isolated
   ```

### Handling Git Clone Symlink Issues

**Problem:** After git clone, symlinks stored as blob references don't work.

**Solution:** The `repair_isolated_symlinks()` function:
1. Finds Node.js version directory
2. Recreates 4 critical symlinks: npm, npx, corepack, claude
3. Fixes Node.js binary permissions
4. Provides detailed status output (✓/✗)

**Automatic repair:** Called during:
- `--update`
- `--isolated-update`
- `--repair-isolated` (manual)

---

## Environment Priority

### Without `--system` flag:

1. **Isolated environment** (`.nvm-isolated/`) - if exists and `USE_ISOLATED_BY_DEFAULT=true`
2. **System NVM** - if `NVM_DIR` is set
3. **System Node.js** - fallback

### With `--system` flag:

1. **System NVM** - if `NVM_DIR` is set
2. **System Node.js** - fallback
3. **Isolated environment** - skipped

This allows testing system installation while isolated environment exists.

---

## Security Considerations

### Proxy Credentials

- Stored in `.claude_proxy_credentials` (chmod 600)
- Git-ignored
- Contains: protocol, username, password, host, port, proxy_ca, proxy_insecure

### HTTPS Proxy Security

**Recommended:** Use `--proxy-ca` with proxy certificate:
```bash
iclaude --proxy https://proxy:8118 --proxy-ca /path/to/cert.pem
```

**Not Recommended:** `--proxy-insecure` disables TLS verification for ALL connections:
```bash
iclaude --proxy https://proxy:8118 --proxy-insecure  # ⚠️ INSECURE
```

**Export proxy certificate:**
```bash
openssl s_client -showcerts -connect proxy:8118 < /dev/null 2>/dev/null | \
  openssl x509 -outform PEM > proxy-cert.pem
```

### Git Proxy Handling

- Script uses **environment variables** (HTTPS_PROXY, HTTP_PROXY, NO_PROXY)
- Does **NOT** modify `git config --global`
- Proxy settings only apply to current session
- Git automatically respects NO_PROXY for localhost/127.0.0.1

---

## Testing

### Manual Test Cases

1. **Fresh installation:**
   ```bash
   rm -rf .nvm-isolated .nvm-isolated-lockfile.json
   ./iclaude.sh --isolated-install
   ./iclaude.sh --check-isolated
   ```

2. **Proxy connectivity:**
   ```bash
   ./iclaude.sh --proxy http://test:test@127.0.0.1:8118 --test
   ```

3. **Symlink repair:**
   ```bash
   # Simulate git clone by removing symlinks
   find .nvm-isolated/versions/node/*/bin -type l -delete
   ./iclaude.sh --repair-isolated
   ./iclaude.sh --check-isolated
   ```

4. **Update workflow:**
   ```bash
   ./iclaude.sh --update
   ./iclaude.sh --check-isolated  # Verify lockfile updated
   ```

5. **System vs Isolated:**
   ```bash
   ./iclaude.sh              # Uses isolated (default)
   ./iclaude.sh --system     # Uses system installation
   ```

### No Automated Tests

Currently no automated test suite exists. All testing is manual.

**Future improvement:** Add integration tests using bash testing framework (e.g., bats).

---

## Troubleshooting Common Issues

### Skills not available in isolated environment

**Symptoms:** Skills work in main project but not from other projects.

**Cause:** Skills not synced to `.nvm-isolated/.claude-isolated/skills/`

**Solution:**
```bash
# Automatic sync during install
./iclaude.sh --isolated-install

# Manual sync
cp -r .claude/skills/* .nvm-isolated/.claude-isolated/skills/
git add .nvm-isolated/.claude-isolated/skills/
```

### Symlinks broken after git clone

**Symptoms:** npm/node/claude commands not found.

**Solution:**
```bash
./iclaude.sh --repair-isolated
```

### Proxy test fails

**Debug:**
```bash
# Enable curl verbose output
CURL_VERBOSE="-v" ./iclaude.sh --test
```

### Lockfile not updating

**Symptoms:** `claudeCodeVersion` in lockfile doesn't match installed version.

**Solution:**
```bash
# Fixed in version from 24.10.2025
# Manual update if using old version:
bash -c 'source ./iclaude.sh && save_isolated_lockfile'
```

---

## Additional Resources

- **README.md** - User-facing documentation and usage examples
- **SKILLS.md** - Comprehensive Skills documentation
- **Skill Files** - `.claude/skills/*/SKILL.md` for each skill

---

## Quick Reference

### When to Use Which Skill

| Task | Skill | Example |
|------|-------|---------|
| Add bash function | bash-development | "Добавь флаг --retry" |
| Debug proxy | proxy-management | "Почему test failed?" |
| Manage isolated env | isolated-environment | "Создай lockfile" |
| Create plan | structured-planning | "Создай план задачи" |
| Validate results | validation-framework | "Провалидируй criteria" |
| Git commit | git-workflow | "Создай commit" |
| Analyze decision | thinking-framework | "Проанализируй опции" |
| Get approval | approval-gates | "Запроси подтверждение" |

### Common Commands

```bash
# Development
./iclaude.sh                          # Launch with isolated env
./iclaude.sh --test                   # Test proxy only
./iclaude.sh --check-isolated         # Check status

# Installation
./iclaude.sh --isolated-install       # Install isolated env
sudo ./iclaude.sh --create-symlink    # Create global symlink

# Maintenance
./iclaude.sh --update                 # Update Claude Code
./iclaude.sh --repair-isolated        # Fix symlinks
./iclaude.sh --cleanup-isolated       # Remove isolated env

# Proxy
./iclaude.sh --proxy http://...       # Set proxy
./iclaude.sh --proxy-ca cert.pem      # Use CA certificate
./iclaude.sh --clear                  # Clear credentials
./iclaude.sh --no-proxy               # Disable proxy

# System vs Isolated
./iclaude.sh --system                 # Force system installation
./iclaude.sh --system --update        # Update system installation
```

---

**Note:** This document focuses on technical architecture and development workflows. For user-facing documentation, see README.md.
