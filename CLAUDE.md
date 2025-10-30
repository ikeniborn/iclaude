# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a utility tool for launching Claude Code through HTTP/SOCKS5 proxies with automatic credential management. The project consists of a single bash script that can be installed globally.

## Available Skills

The project uses Claude Skills to automate common development tasks. See [SKILLS.md](SKILLS.md) for detailed documentation.

### 🔧 [Bash Development](/.claude/skills/bash-development/SKILL.md)
Автоматизирует создание bash-функций, добавление флагов, рефакторинг кода, обработку ошибок.

**Use when:** Adding new features, refactoring functions, working with environment variables.

**Example requests:**
- "Добавь новый флаг --timeout для ограничения времени ожидания"
- "Создай функцию для ротации credentials backups"
- "Рефактори функцию launch_claude() для улучшения читаемости"

### 🌐 [Proxy Management](/.claude/skills/proxy-management/SKILL.md)
Автоматизирует настройку прокси, тестирование подключений, отладку TLS проблем.

**Use when:** Debugging proxy issues, adding proxy protocols, working with certificates.

**Example requests:**
- "Отладь проблему с HTTPS прокси и самоподписанным сертификатом"
- "Добавь поддержку SOCKS4 прокси"
- "Почему proxy test failed с HTTP 407?"

### 📦 [Isolated Environment](/.claude/skills/isolated-environment/SKILL.md)
Управляет изолированным NVM окружением в директории проекта для воспроизводимых установок.

**Use when:** Setting up isolated environment, working with lockfiles, managing reproducible installations.

**Example requests:**
- "Установи Claude Code в изолированное окружение"
- "Создай lockfile текущей установки"
- "Почему isolated environment не обнаруживается?"

## Architecture

The codebase is a standalone bash script (`iclaude.sh`) that:

1. **Isolated Environment** (NEW): Installs NVM + Node.js + Claude Code in project directory (`.nvm-isolated/`) by default
2. **Lockfile-based Reproducibility**: Saves exact versions to `.nvm-isolated-lockfile.json` for consistent setup across machines
3. **Credential Management**: Stores proxy credentials in `.claude_proxy_credentials` (chmod 600, git-ignored)
4. **Proxy Configuration**: Sets environment variables (HTTPS_PROXY, HTTP_PROXY, NO_PROXY) for Claude Code
5. **Git Proxy Management**: Automatically disables proxy for git operations while keeping it enabled for Claude Code
6. **Global Installation**: Creates symlink at `/usr/local/bin/iclaude` for system-wide access

### Key Components

For detailed implementation guidance, use the **bash-development** skill.

- **Proxy URL Parsing** (lines 143-180): Extracts protocol, username, password, host, port from URLs
- **Credential Persistence** (lines 332-392): Saves/loads proxy settings from `.claude_proxy_credentials`
- **Git Proxy Management** (lines 519-580): Automatically saves/restores git proxy settings
- **Proxy Configuration** (lines 467-515): Sets environment variables and configures git
- **Proxy Testing** (lines 615-667): Validates connectivity via curl before launching
- **Isolated Environment Repair** (lines 660-820): Restores symlinks and permissions after git clone
  - Fixes 4 critical symlinks (npm, npx, corepack, claude)
  - Verifies Node.js binary permissions
  - Provides detailed status output with ✓/✗ indicators
  - Automatically called during updates
- **Dependency Installation** (lines 684-740): Auto-installs Node.js, npm, and Claude Code if missing
- **Claude Detection** (lines 745-790, 1419-1506): Finds global Claude Code binary, avoiding local npm installations

## Development Workflows

### Workflow 1: Adding New Features

Use the **bash-development** skill for:

```
Добавь новый флаг --retry <count> для повторных попыток подключения к прокси
```

The skill will guide you through:
1. Adding the flag to the argument parser
2. Implementing the retry logic
3. Adding validation
4. Updating `show_usage()`
5. Checking the completion checklist

### Workflow 2: Proxy Configuration & Debugging

Use the **proxy-management** skill for:

```
Отладь проблему: Test proxy failed с ошибкой "SSL certificate problem: self signed certificate"
```

The skill will guide you through:
1. Analyzing the TLS error
2. Explaining --proxy-ca vs --proxy-insecure
3. Providing certificate export commands
4. Testing the solution

### Workflow 3: Combined Tasks

For complex tasks, Claude will automatically combine skills:

```
Добавь поддержку SOCKS4 прокси в iclaude.sh с полной валидацией и тестированием
```

Claude uses:
- **proxy-management** → validates and parses SOCKS4 URLs
- **bash-development** → creates bash functions with proper error handling
- **proxy-management** → adds curl tests for SOCKS4
- **bash-development** → updates documentation

## Isolated Environment (Recommended)

The script supports **isolated installation** where NVM, Node.js, and Claude Code are installed in the project directory (`.nvm-isolated/`) instead of globally. This approach:

✅ **Avoids conflicts** with system NVM installations
✅ **Enables reproducible setups** via lockfile (`.nvm-isolated-lockfile.json`)
✅ **Portable across machines** - commit lockfile, not 200MB+ binaries
✅ **Used by default** when available

### Isolated Installation Workflow

**Initial Setup:**
```bash
# Install everything in isolated environment
./iclaude.sh --isolated-install

# This creates:
# - .nvm-isolated/          (git-ignored, ~200-300MB)
# - .nvm-isolated-lockfile.json (commit this!)
```

**Check Status:**
```bash
./iclaude.sh --check-isolated
```

**Setup on Another Machine:**

*Option 1: Full environment from git (includes .nvm-isolated/)*
```bash
# Clone repository
git clone <repo>

# Repair symlinks after git clone
./iclaude.sh --repair-isolated

# Ready to use
./iclaude.sh
```

*Option 2: Install from lockfile (lighter for git)*
```bash
# Clone repository (includes lockfile only)
git clone <repo>

# Install exact same versions from lockfile
./iclaude.sh --install-from-lockfile

# Ready to use
./iclaude.sh
```

**Cleanup (preserves lockfile):**
```bash
./iclaude.sh --cleanup-isolated
```

### Isolated Environment Behavior

- **By default**: Script automatically uses `.nvm-isolated/` if it exists
- **Priority**: Isolated environment > System NVM > System Node.js
- **Lockfile**: Records exact versions (Node.js, Claude Code, NVM)
- **Git workflow**: Commit entire `.nvm-isolated/` directory (cache files excluded)
- **Symlinks**: After git clone, symlinks need restoration (use `--repair-isolated`)
  - Git stores symlinks as blob references, not actual symlinks
  - 4 critical symlinks: npm, npx, corepack, claude
  - Automatic repair during updates

### Files

- `.nvm-isolated/` - Isolated NVM installation (~200-300MB, committed to git)
- `.nvm-isolated/.claude-isolated/` - Isolated Claude Code config (git-ignored)
- `.nvm-isolated-lockfile.json` - Version lockfile (committed to git)
- `.claude_proxy_credentials` - Proxy credentials (chmod 600, git-ignored)

**Note:** Only cache and temporary files are git-ignored (`.cache/`, `.npm/`, `*.log`)

## Isolated Configuration

By default, Claude Code stores all data (history, sessions, credentials) in the shared directory `~/.claude/`, which is used by all installations (isolated and system). This can lead to data loss when switching between installations.

**Isolated configuration** solves this problem by creating a separate storage for each installation:

**Architecture:**

```bash
# Isolated installation → .nvm-isolated/.claude-isolated/
# System installation → ~/.claude/
```

**Automatic behavior:**

- When using isolated installation, configuration is automatically isolated
- When using system installation (`--system`), shared configuration is used (`~/.claude/`)
- Can be explicitly controlled via flags

**Configuration management:**

```bash
# Check current configuration
./iclaude.sh --check-config

# Explicitly use isolated configuration
./iclaude.sh --isolated-config

# Explicitly use shared configuration (default)
./iclaude.sh --shared-config

# Export configuration to backup
./iclaude.sh --export-config /path/to/backup

# Import configuration from backup
./iclaude.sh --import-config /path/to/backup
```

**What is isolated:**

- ✅ Command history (`history.jsonl`)
- ✅ Active sessions (`session-env/`)
- ✅ Credentials (`.credentials.json`)
- ✅ Settings (`settings.json`)
- ✅ Project settings (`projects/`)
- ✅ TODO lists (`todos/`)
- ✅ File history (`file-history/`)

**Environment Variable:**

Claude Code uses the `CLAUDE_CONFIG_DIR` environment variable to determine the configuration directory:

```bash
# Default (if not set)
CLAUDE_CONFIG_DIR=$HOME/.claude

# Isolated (set by iclaude.sh)
CLAUDE_CONFIG_DIR=$SCRIPT_DIR/.nvm-isolated/.claude-isolated
```

**Note:** Isolated configuration is git-ignored. Use `--export-config` to create backups.

## Common Commands

### Isolated Environment (Recommended)
```bash
# Install isolated environment (NO system npm required!)
./iclaude.sh --isolated-install

# Create global symlink (NO system npm required!)
sudo ./iclaude.sh --create-symlink

# Update Claude Code in isolated environment (NO sudo!)
./iclaude.sh --isolated-update

# Check status
./iclaude.sh --check-isolated

# Repair after git clone
./iclaude.sh --repair-isolated

# Remove symlink only (keeps isolated environment)
sudo iclaude --uninstall-symlink
```

### System Installation (Alternative)
```bash
# Install globally (requires sudo + system npm ~200MB)
sudo ./iclaude.sh --install

# Uninstall
sudo iclaude --uninstall

# Update system Claude Code
sudo iclaude --update

# Launch from system installation (skip isolated)
iclaude --system

# Update system installation (skip isolated)
sudo iclaude --system --update
```

### Usage
```bash
# Launch with saved credentials
iclaude

# Set proxy directly
iclaude --proxy http://user:pass@host:port

# Test proxy without launching Claude
iclaude --test

# Clear saved credentials
iclaude --clear

# Launch without proxy
iclaude --no-proxy

# Check updates
iclaude --check-update
```

For detailed usage information, see [README.md](README.md).

## Development Notes

### Proxy URL Format
Supported formats: `http://`, `https://`, `socks5://`

Pattern: `protocol://[username:password@]host:port`

For detailed proxy management, use the **proxy-management** skill.

### Security Considerations

**HTTPS Proxy Security:**

⚠️ **Important:** The `--proxy-insecure` flag disables TLS certificate verification for ALL Node.js connections.

**Secure Solution with `--proxy-ca` (RECOMMENDED):**
```bash
# ✅ SECURE
iclaude --proxy https://proxy:8118 --proxy-ca /path/to/proxy-cert.pem
```
- ✅ Proxy connection: Uses proxy CA certificate
- ✅ Claude Code → Anthropic API: FULL TLS VERIFICATION (SECURE)

**How to Export Proxy Certificate:**
```bash
# Get help
iclaude --help-export-cert

# Using openssl
openssl s_client -showcerts -connect proxy.example.com:8118 < /dev/null 2>/dev/null | \
  openssl x509 -outform PEM > proxy-cert.pem
```

For troubleshooting TLS issues, use the **proxy-management** skill.

### Script Behavior
- Uses `set -euo pipefail` for strict error handling
- Follows symlinks to resolve the script's actual directory
- **NVM Support**: Automatically detects and uses Claude Code installed via NVM

**Environment Priority (without `--system`):**
1. Isolated environment (`.nvm-isolated/`) - if exists and `USE_ISOLATED_BY_DEFAULT=true`
2. System NVM - if `NVM_DIR` is set
3. System Node.js - fallback

**Environment Priority (with `--system`):**
1. System NVM - if `NVM_DIR` is set
2. System Node.js - fallback
3. Isolated environment is skipped

**Note:** The `--system` flag allows you to explicitly choose system installation even when isolated environment exists. This is useful for:
- Testing system installation while isolated exists
- Updating system installation separately
- Temporary switch without removing isolated environment

For adding new bash functions or modifying behavior, use the **bash-development** skill.

### Git and Proxy Considerations

**Environment Variable Approach:**

The script uses **environment variables** (HTTPS_PROXY, HTTP_PROXY, NO_PROXY) to configure proxy settings. These variables:
- Only affect the current process and its child processes (like Claude Code)
- **Do NOT modify global git configuration**
- Git automatically respects NO_PROXY for localhost and 127.0.0.1

**Important Notes:**
- The script does **NOT** modify `git config --global` settings
- Your system's git configuration remains unchanged
- Proxy settings only apply to the `iclaude` session and Claude Code

### Updating Claude Code

```bash
# Check if updates are available
iclaude --check-update

# Update to latest version
iclaude --update  # For NVM installations
sudo iclaude --update  # For system installations
```

**NVM-specific behavior:**
- Automatically detects and cleans up old temporary installations (`.claude-code-*`)
- Removes broken symlinks (`.claude-*`) before updating
- Verifies update success by checking for working `cli.js`

**Troubleshooting ENOTEMPTY errors:**

If you see `npm error ENOTEMPTY` during update, the script will offer automatic cleanup or you can do it manually.

**Symlink Issues After Git Clone:**

After cloning a repository with `.nvm-isolated/`, symlinks may not work properly:

**Symptoms:**
- `./iclaude.sh` fails with command not found errors
- npm/npx commands don't work
- Claude Code not detected

**Solution:**
```bash
# Check symlink status
./iclaude.sh --check-isolated

# Repair all symlinks and permissions
./iclaude.sh --repair-isolated
```

The repair function:
- Verifies and recreates 4 critical symlinks (npm, npx, corepack, claude)
- Fixes Node.js binary permissions (chmod +x)
- Provides detailed status output (✓ OK / ✗ BROKEN)
- Automatically runs during updates

For detailed update procedures and troubleshooting, use the **bash-development** skill.

### Testing

No automated tests exist. Test manually:
```bash
# Test proxy connectivity
iclaude --test

# Test full flow
iclaude --proxy http://test:test@127.0.0.1:8118 --no-test
```

For creating test cases or debugging issues, use the **bash-development** and **proxy-management** skills together.

## Quick Reference

### When to Use Which Skill

| Task | Skill | Example Request |
|------|-------|----------------|
| Add new flag/option | bash-development | "Добавь флаг --retry" |
| Create bash function | bash-development | "Создай функцию rotate_credentials()" |
| Refactor code | bash-development | "Рефактори launch_claude()" |
| Debug proxy issue | proxy-management | "Почему proxy test failed?" |
| Configure TLS | proxy-management | "Настрой --proxy-ca" |
| Add proxy protocol | proxy-management + bash-development | "Добавь SOCKS4" |
| Setup isolated environment | isolated-environment | "Установи изолированное окружение" |
| Fix symlink issues | isolated-environment | "Почему симлинки не работают после git clone?" |
| Update documentation | bash-development | "Обнови show_usage()" |

### Common Request Patterns

Instead of reading lengthy documentation, just ask Claude with these patterns:

**Development:**
- "Добавь новый флаг --{name} для {purpose}"
- "Создай функцию {name}() которая {description}"
- "Рефактори {function_name}() для {improvement}"
- "Добавь валидацию для {parameter}"

**Proxy Management:**
- "Отладь проблему с {proxy_type} прокси"
- "Почему test proxy failed с ошибкой '{error_message}'?"
- "Как настроить HTTPS прокси с самоподписанным сертификатом?"
- "Добавь поддержку {protocol} прокси"

**Isolated Environment:**
- "Установи изолированное окружение"
- "Почему симлинки не работают после git clone?"
- "Как проверить статус изолированного окружения?"
- "Создай lockfile текущей установки"

**Combined:**
- "Добавь поддержку {feature} с полной валидацией и тестированием"
- "Оптимизируй {component} для лучшей производительности"
- "Исправь баг: {description}"

## Additional Resources

- **SKILLS.md**: Comprehensive documentation on available skills
- **README.md**: User-facing documentation and usage examples
- **Skill Files**:
  - `.claude/skills/bash-development/SKILL.md`: Bash development patterns and templates
  - `.claude/skills/proxy-management/SKILL.md`: Proxy configuration and troubleshooting

---

**Note:** This document has been optimized to work with Claude Skills. Instead of providing exhaustive details here, we reference specialized skills that contain:
- Step-by-step implementation guides
- Code templates
- Checklists
- Troubleshooting guides
- Real-world examples

Simply describe what you want to Claude, and it will automatically use the appropriate skill to help you.
