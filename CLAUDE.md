# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**iclaude** is a bash-based wrapper script for launching Claude Code with automatic HTTP/HTTPS proxy configuration. It provides both isolated (portable) and system-wide installation modes, with secure credential storage and automatic environment setup.

### Key Features
- Dual installation modes: isolated (`.nvm-isolated/`) and system-wide
- Automatic proxy configuration with credential persistence
- Version locking via lockfile for reproducible deployments
- Isolated configuration to prevent conflicts between installations
- Domain-to-IP resolution for proxy URLs
- TLS certificate support for HTTPS proxies
- **Automatic OAuth token refresh** using `claude setup-token` (long-lived ~1 year tokens)
- **Claude Code Router integration** for alternative LLM providers (OpenRouter, DeepSeek, Ollama, Gemini)

## Development Commands

### Testing and Validation

```bash
# Test proxy configuration without launching Claude
./iclaude.sh --test

# Check isolated environment status (shows versions, symlinks, lockfile)
./iclaude.sh --check-isolated

# Check configuration status (isolated vs shared)
./iclaude.sh --check-config

# Refresh OAuth token manually (generates long-lived token ~1 year)
./iclaude.sh --refresh-token

# Validate script without execution
bash -n iclaude.sh
```

### Installation and Updates

```bash
# Install isolated environment (recommended for development)
./iclaude.sh --isolated-install

# Update Claude Code in isolated environment
./iclaude.sh --update

# Install from lockfile (exact versions)
./iclaude.sh --install-from-lockfile

# Repair symlinks after git clone
./iclaude.sh --repair-isolated

# Clean up isolated environment (preserves lockfile)
./iclaude.sh --cleanup-isolated
```

### Running the Script

```bash
# Launch with saved proxy credentials
./iclaude.sh

# Launch without proxy
./iclaude.sh --no-proxy

# Launch with custom proxy
./iclaude.sh --proxy https://user:pass@proxy.example.com:8118

# Use system installation instead of isolated
./iclaude.sh --system

# Pass arguments to Claude Code
./iclaude.sh -- --model claude-3-opus
```

### Router Commands

```bash
# Install Claude Code Router in isolated environment
./iclaude.sh --install-router

# Check router status and configuration
./iclaude.sh --check-router

# Launch via router (opt-in with --router flag)
./iclaude.sh --router

# Launch with native Claude (default behavior)
./iclaude.sh
```

### Chrome Integration Commands

```bash
# Launch WITHOUT Chrome integration (Chrome enabled by default)
./iclaude.sh --no-chrome

# Chrome is enabled by default, so this is equivalent to plain launch:
./iclaude.sh  # Chrome integration included

# Combine with other flags (proxy without Chrome)
./iclaude.sh --proxy https://proxy:8118 --no-chrome
```

### LSP Server Management

```bash
# Install LSP servers for TypeScript and Python (default)
./iclaude.sh --install-lsp

# Install specific LSP servers
./iclaude.sh --install-lsp python          # Python only
./iclaude.sh --install-lsp typescript go   # TypeScript + Go

# Check LSP server status
./iclaude.sh --check-lsp

# Install all versions from lockfile (includes LSP)
./iclaude.sh --install-from-lockfile
```

### Loop Mode Commands

```bash
# Execute task sequentially with retry logic (Week 1)
./iclaude.sh --loop task.md

# Execute tasks in parallel with git worktrees (Week 2 - not yet implemented)
./iclaude.sh --loop-parallel task.md

# Limit parallel agents to 3
./iclaude.sh --loop-parallel task.md --max-parallel 3

# Example task definition (task.md):
# Task: Fix TypeScript errors
#
# ## Description
# Fix all TypeScript compilation errors in src/
#
# ## Completion Promise
# npm run type-check
#
# ## Validation Command
# npm run type-check
#
# ## Max Iterations
# 5
#
# ## Git Config
# Branch: fix/typescript-errors
# Commit message: fix: resolve TypeScript errors
# Auto-push: true
```

**Loop Mode Features:**
- Sequential execution with retry logic
- Exponential backoff (2s, 4s, 8s, 16s, 32s, capped at 60s)
- Completion promise verification via validation command
- Git integration (auto-commit + push)
- Markdown task definition format
- Parallel execution with worktree isolation (Week 2)

**Example task files:**
- `examples/test-loop-simple.md` - Basic task (succeeds on first iteration)
- `examples/test-loop-retry.md` - Retry logic test (exponential backoff)

## Code Architecture

### Main Components

The script is organized into functional modules:

#### 1. Proxy Management (`save_credentials`, `load_credentials`, `configure_proxy_from_url`)
- **Location**: iclaude.sh:1343-1666
- **Purpose**: Handle proxy URL validation, credential storage, and environment variable configuration
- **Key Features**:
  - Domain-to-IP resolution with `resolve_domain_to_ip()`
  - Secure credential storage (chmod 600)
  - Support for HTTP/HTTPS protocols (SOCKS5 not supported by undici)
  - NO_PROXY configuration for bypassing proxy

#### 2. Isolated Environment (`setup_isolated_nvm`, `install_isolated_nvm`, `repair_isolated_environment`)
- **Location**: iclaude.sh:361-978
- **Purpose**: Manage portable NVM+Node.js+Claude installation in `.nvm-isolated/`
- **Key Features**:
  - Self-contained installation (~278MB)
  - Symlink management for npm/npx/claude binaries
  - Lockfile-based version pinning
  - Git-friendly structure with repair capabilities

#### 3. Version Management (`save_isolated_lockfile`, `install_from_lockfile`, `update_isolated_claude`)
- **Location**: iclaude.sh:616-768
- **Purpose**: Track and reproduce exact versions of Node.js, npm, and Claude Code
- **Lockfile Format**:
  ```json
  {
    "nodeVersion": "18.20.8",           // Node.js version
    "claudeCodeVersion": "2.1.7",       // Claude Code CLI
    "routerVersion": "unknown",         // Claude Code Router (or "not installed")
    "ghCliVersion": "2.45.0",           // GitHub CLI (or "not installed")
    "lspServers": {                     // LSP server binaries
      "pyright": "1.1.347",
      "@vtsls/language-server": "0.2.3"
    },
    "lspPlugins": {                     // Claude Code LSP plugins
      "pyright-lsp@claude-plugins-official": "1.0.0",
      "typescript-lsp@claude-plugins-official": "1.0.0"
    },
    "installedAt": "2026-01-14T10:39:51Z",
    "nvmVersion": "0.39.7"
  }
  ```

**Complete installation from lockfile**:
```bash
./iclaude.sh --install-from-lockfile
```

This installs exact versions of:
- Node.js
- Claude Code CLI
- Router (if version != "not installed")
- **gh CLI** (if version != "not installed") ← Now restored from lockfile
- **LSP servers** (all listed versions) ← Now restored from lockfile

#### 4. Configuration Isolation (`setup_isolated_config`, `check_config_status`, `export_config`, `import_config`)
- **Location**: iclaude.sh:1099-1341
- **Purpose**: Separate Claude Code state between isolated and system installations
- **Isolated Config Directory**: `.nvm-isolated/.claude-isolated/`
- **What Gets Isolated**:
  - Session data (`session-env/`)
  - History (`history.jsonl`)
  - Credentials (`.credentials.json`)
  - Settings (`settings.json`)
  - Project configs (`projects/`)
  - File history (`file-history/`)
  - TODOs (`todos/`)

#### 5. NVM Detection (`detect_nvm`, `get_nvm_claude_path`)
- **Location**: iclaude.sh:200-318
- **Purpose**: Find Claude Code binary in various installation modes
- **Priority Order** (without `--system` flag):
  1. Isolated environment (`.nvm-isolated/`)
  2. System NVM (`$NVM_DIR`)
  3. System Node.js
- **Handles**:
  - Standard `claude` binary
  - Temporary `.claude-*` binaries (from npm updates)
  - Direct cli.js execution via Node

#### 6. Update Management (`update_isolated_claude`, `update_claude_code`, `cleanup_old_claude_installations`)
- **Location**: iclaude.sh:529-2389
- **Purpose**: Safely update Claude Code and handle temporary installation artifacts
- **Key Features**:
  - Automatic cleanup of `.claude-code-*` temporary folders
  - Symlink recreation after updates
  - Lockfile auto-update
  - ENOTEMPTY error handling

#### 7. OAuth Token Management (`check_oauth_token`, `refresh_oauth_token`)
- **Location**: iclaude.sh:2749-2874
- **Purpose**: Automatic OAuth token validation and refresh
- **Key Features**:
  - Checks token expiration at every launch
  - Automatically refreshes tokens within 7 days of expiration (configurable via `TOKEN_REFRESH_THRESHOLD`)
  - Uses `claude setup-token` for long-lived tokens (~1 year validity)
  - Preserves credentials file (doesn't delete refreshToken on failure)
  - Manual refresh via `--refresh-token` option
- **Token Structure** (`.credentials.json`):
  ```json
  {
    "claudeAiOauth": {
      "accessToken": "sk-ant-oat01-...",
      "refreshToken": "sk-ant-ort01-...",
      "expiresAt": 1766460813792,
      "scopes": ["user:inference", "user:profile", "user:sessions:claude_code"],
      "subscriptionType": "max"
    }
  }
  ```

#### 8. Router Management (`detect_router`, `get_router_path`, `install_isolated_router`, `check_router_status`)
- **Location**: iclaude.sh:324-379 (detection), 584-637 (installation), 1333-1430 (status)
- **Purpose**: Integrate Claude Code Router for alternative LLM providers
- **Key Features**:
  - Opt-in activation via `--router` flag (native Claude by default)
  - Support for multiple providers (OpenRouter, DeepSeek, OpenAI, Ollama, Gemini, Volcengine, SiliconFlow)
  - Configuration with environment variable substitution (`${VAR_NAME}`)
  - Lockfile integration for router version tracking
  - Backward compatibility (zero breaking changes)
- **Configuration Files**:
  - `router.json.example` - Comprehensive template with all providers (committed to git)
  - `router.json` - Team's actual config with `${VAR}` placeholders (committed to git)
  - `~/.claude-code-router/config.json` - Runtime config (copied at launch, NOT in git)
- **Launch Flow** (when `--router` flag is specified):
  1. Check if `USE_ROUTER_FLAG` is true
  2. Verify `router.json` exists and `ccr` binary installed
  3. Copy `router.json` to `~/.claude-code-router/config.json`
  4. Launch via `ccr code` instead of `claude`
  5. Router intercepts Claude API calls → routes to configured provider
  6. **Default behavior** (without `--router`): Launch native Claude directly

**Router + Proxy Compatibility:**
- Router inherits `HTTPS_PROXY` and `HTTP_PROXY` environment variables
- No special handling needed - works automatically
- Router uses proxy for both provider API calls AND Claude API calls

**Environment Variable Substitution:**
```json
{
  "providers": {
    "deepseek": {
      "apiKey": "${DEEPSEEK_API_KEY}"
    }
  }
}
```
At runtime, `${DEEPSEEK_API_KEY}` is replaced with value from environment.

#### 9. Auto-update Management (`disable_auto_updates`)
- **Location**: iclaude.sh:1982-2024
- **Purpose**: Automatically disable Claude Code CLI auto-updates for CI/CD-managed installations
- **Key Features**:
  - Runs automatically on every `iclaude.sh` launch
  - Sets `autoUpdates: false` in `.claude.json`
  - Works for both isolated and shared configurations
  - Idempotent (safe to run multiple times)
  - Graceful handling of missing jq or config file
- **Why This Matters**:
  - Prevents Claude Code from updating itself
  - Ensures all machines use same version from git
  - Updates controlled via CI/CD (GitHub Actions)
  - Consistent development environment across team
- **Automatic Behavior**:
  ```bash
  # On every launch, iclaude.sh automatically:
  # 1. Checks if .claude.json exists
  # 2. If autoUpdates == true → sets to false
  # 3. If autoUpdates == false → no action
  # 4. If file missing → skips (will be created on first Claude run)
  ```
- **Manual Check**:
  ```bash
  # View current setting
  jq '.autoUpdates' .nvm-isolated/.claude-isolated/.claude.json
  ```

### Critical Functions

#### `validate_proxy_url()` - iclaude.sh:56
Validates proxy URL format and protocol. Returns:
- `0`: Valid URL with IP address
- `1`: Invalid format
- `2`: Valid but contains domain (warning)

**IMPORTANT**: Only HTTP/HTTPS protocols are supported. SOCKS5 will cause Claude Code to crash due to undici library limitations.

#### `resolve_domain_to_ip()` - iclaude.sh:110
Resolves domain names to IP addresses using fallback chain:
1. `getent` (most reliable)
2. `host`
3. `dig`
4. `nslookup`

**Note**: Only used for HTTP proxies (optional conversion). HTTPS proxies ALWAYS preserve domain names to maintain OAuth/TLS compatibility.

#### `get_nvm_claude_path()` - iclaude.sh:234
Locates Claude Code installation in NVM environment. Handles:
- Standard `claude` binary in `$NVM_DIR/versions/node/*/bin/`
- Temporary `.claude-*` binaries (sorted by mtime, newest first)
- Direct cli.js in `node_modules/@anthropic-ai/claude-code/`
- Temporary `.claude-code-*` folders

#### `repair_isolated_environment()` - iclaude.sh:812
Fixes broken symlinks after `git clone` or repository moves:
- Recreates npm/npx/corepack symlinks
- Recreates Claude Code symlink
- Sets correct permissions (chmod +x)
- Validates all symlinks

#### `save_isolated_lockfile()` - iclaude.sh:616
Captures current versions to lockfile. Critical for reproducibility:
- Detects Node.js version via `node --version`
- Detects Claude Code version via `get_cli_version()`
- Saves ISO 8601 timestamp
- Detects NVM version
- **Now includes router version** for reproducible router installations

#### `detect_router()` - iclaude.sh:324
Determines if Claude Code Router is available (NOT whether it should be used). Returns:
- `0`: Router available (router.json exists AND ccr binary installed)
- `1`: Router not available (missing config or binary)

**Logic:**
1. Check if `router.json` exists in isolated or system config directory
2. Verify `ccr` binary available via `get_router_path()`
3. If config exists but binary missing, warns user to run `--install-router`

**Important**: This function only checks availability. Router is activated ONLY when `USE_ROUTER_FLAG=true` (set by `--router` flag). By default, native Claude is used even if router is available.

#### `get_router_path()` - iclaude.sh:355
Locates `ccr` binary in isolated or system environment. Priority order:
1. Isolated environment: `.nvm-isolated/npm-global/bin/ccr`
2. System PATH: `command -v ccr`

Returns empty string if not found.

#### `install_isolated_router()` - iclaude.sh:584
Installs Claude Code Router npm package into isolated environment:
1. Runs `npm install -g @musistudio/claude-code-router`
2. Creates `router.json` from `router.json.example` if missing
3. Displays next steps (edit config, export API keys, commit to git)

**Post-install instructions:**
- Edit `router.json` with provider configuration
- Use `${VAR_NAME}` syntax for API keys (environment variables)
- Commit `router.json` to git (with placeholders, NOT real keys)
- Export API keys via environment: `export DEEPSEEK_API_KEY=...`

#### `check_router_status()` - iclaude.sh:1333
Shows comprehensive router status:
- Installation status (installed/not installed)
- Router version (from `ccr --version`)
- Configuration file location
- Configured providers (parsed from `router.json` using jq)
- Default model
- Activation status (will be used on next launch)

Useful for debugging router configuration and verifying setup.

#### `disable_auto_updates()` - iclaude.sh:1982
Disables Claude Code CLI auto-updates in configuration file:
- Takes optional config directory path (defaults to `$CLAUDE_CONFIG_DIR`)
- Checks if `.claude.json` exists, skips if missing
- Sets `autoUpdates: false` if currently `true`
- Uses atomic update (temp file + mv) for safety
- Returns 0 on success or if no action needed
- Returns 1 only on jq error (rarely happens)

**Automatic invocation**:
- Called after `setup_isolated_config()` (both explicit and auto-detected)
- Called for shared config mode
- Runs on every `./iclaude.sh` launch

**Why automatic**:
- Ensures consistent behavior across all machines
- Prevents Claude Code from self-updating
- Updates managed via CI/CD instead
- Team always works on same version from git

### Environment Variables

The script configures these variables:

```bash
# Proxy configuration
HTTPS_PROXY="https://user:pass@proxy:port"
HTTP_PROXY="https://user:pass@proxy:port"
NO_PROXY="localhost,127.0.0.1,github.com,..."

# TLS configuration (optional)
NODE_EXTRA_CA_CERTS="/path/to/proxy-cert.pem"  # For self-signed certificates
NODE_TLS_REJECT_UNAUTHORIZED=0                 # Insecure mode (not recommended)

# Isolated environment (when active)
NVM_DIR="$SCRIPT_DIR/.nvm-isolated"
CLAUDE_DIR="$SCRIPT_DIR/.nvm-isolated/.claude-isolated"
PATH="$ISOLATED_NVM_DIR/npm-global/bin:$ISOLATED_NVM_DIR/versions/node/.../bin:$PATH"

# Claude Code features
CLAUDE_CODE_ENABLE_TASKS="true"                    # Enable tasks system (set to false for old system)
```

## File Structure

```
.
   iclaude.sh                          # Main wrapper script (3325 lines)
   .claude_proxy_credentials           # Encrypted proxy credentials (chmod 600, not in git)
   .nvm-isolated/                      # Isolated NVM environment (~278MB, in git)
      nvm.sh                         # NVM installation script
      versions/node/v18.20.8/        # Node.js installation
         bin/                       # Binaries (npm, npx, node, claude)
         lib/node_modules/          # Global npm packages
      npm-global/                    # Global npm packages
      .claude-isolated/              # Isolated Claude configuration
          history.jsonl              # Command history
          session-env/               # Active sessions
          .credentials.json          # Anthropic credentials
          settings.json              # User settings
          skills/                    # Claude Code skills
          projects/                  # Project-specific configs
   .nvm-isolated-lockfile.json        # Version lockfile (in git)
   README.md                          # User documentation
```

### Files NOT in Git

- `.claude_proxy_credentials` - Contains sensitive proxy credentials
- `.nvm-isolated/.cache/` - NPM cache
- `.nvm-isolated/.npm/` - NPM temporary files
- `.nvm-isolated/.claude-isolated/*` - Session data (except skills/ and CLAUDE.md)

## Important Notes for Development

### Proxy Protocol Support

**Recommended**: HTTPS (preserves domain names for OAuth/TLS)
**Supported but not recommended**: HTTP (offers domain-to-IP conversion)
**NOT Supported**: SOCKS5 (causes crash)

**Why HTTPS is recommended**:
- Domain names are preserved (required for Anthropic OAuth token refresh)
- TLS Server Name Indication (SNI) and Host header work correctly
- Using HTTP or converting domains to IPs breaks authentication

Claude Code uses the `undici` HTTP client library, which does not support SOCKS5 protocol. Attempting to use SOCKS5 will result in:
```
InvalidArgumentError: Invalid URL protocol: the URL must start with `http:` or `https:`
```

**Workaround for SOCKS5**: Use Privoxy or Squid to convert SOCKS5 → HTTPS locally.

### HTTPS Proxy Security

When using HTTPS proxy, there's a critical security consideration:

**Vulnerability**: `undici` ProxyAgent does not verify TLS certificates of target servers when proxying HTTPS traffic ([HackerOne #1583680](https://hackerone.com/reports/1583680))

**Implications**:
- The proxy server can intercept all HTTPS traffic (MitM)
- Only use trusted proxy servers
- Prefer `--proxy-ca` over `--proxy-insecure`

**Secure configuration**:
```bash
./iclaude.sh --proxy https://proxy:8118 --proxy-ca /path/to/cert.pem
```

### OAuth Token Refresh

OAuth tokens expire and require manual `/login`. The script now automatically handles token refresh:

**Automatic refresh** (at launch):
- Checks token expiration at every `iclaude.sh` launch
- If token expires within 7 days (configurable), attempts automatic refresh
- Uses `claude setup-token` to generate long-lived token (~1 year)

**Manual refresh**:
```bash
./iclaude.sh --refresh-token
```

**Configuration**:
- `TOKEN_REFRESH_THRESHOLD` constant in iclaude.sh (default: 604800 = 7 days)
- Token stored in `.credentials.json` with `expiresAt` timestamp (milliseconds)

**Behavior on failure**:
- Does NOT delete credentials file (preserves refreshToken for Claude Code)
- Shows warning and directs user to run `/login` manually
- Claude Code may still be able to use the refreshToken internally

**Known limitation**: `setup-token` requires interactive browser authentication. Not suitable for fully headless/CI environments.

### Tasks System

Claude Code включает систему управления задачами (tasks) для отслеживания прогресса выполнения работы.

**Автоматическая активация**:
- iclaude.sh экспортирует `CLAUDE_CODE_ENABLE_TASKS=true` по умолчанию
- Новая система задач активируется автоматически при запуске
- Доступны инструменты: `TaskCreate`, `TaskGet`, `TaskList`, `TaskUpdate`, `TaskOutput`

**Отключение** (временный возврат к старой системе):
```bash
CLAUDE_CODE_ENABLE_TASKS=false ./iclaude.sh
```

**Возможности**:
- Создание списка задач для отслеживания работы
- Управление зависимостями между задачами (blocks/blockedBy)
- Отслеживание фоновых процессов (bash shell, subagents)
- Шаринг задач между сессиями (через `CLAUDE_CODE_TASK_LIST_ID`)

**Примечание**: Переменная `CLAUDE_CODE_TASK_LIST_ID` является процессной и должна устанавливаться вручную при необходимости шаринга задач между несколькими экземплярами Claude Code.

**Источник**: [claude-code/CHANGELOG.md](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)

### Symlink Management

After `git clone`, symlinks in `.nvm-isolated/` may break. Always run:
```bash
./iclaude.sh --repair-isolated
```

This recreates:
- `.nvm-isolated/npm-global/bin/npm` � `../../versions/node/v*/lib/node_modules/npm/bin/npm-cli.js`
- `.nvm-isolated/npm-global/bin/npx` � `../../versions/node/v*/lib/node_modules/npm/bin/npx-cli.js`
- `.nvm-isolated/npm-global/bin/claude` � `../../versions/node/v*/lib/node_modules/@anthropic-ai/claude-code/cli.js`

### Update Behavior

When running `--update`, the script:
1. Runs `npm update -g @anthropic-ai/claude-code`
2. Cleans up `.claude-code-*` temporary folders
3. Recreates symlinks
4. Updates lockfile
5. Retries on ENOTEMPTY errors

**Important**: Always verify lockfile update after `--update`:
```bash
./iclaude.sh --check-isolated
# Verify Claude Code version matches lockfile claudeCodeVersion
```

### Configuration Modes

**Isolated Config** (default for isolated installation):
- Config in `.nvm-isolated/.claude-isolated/`
- Separate history/sessions from system installation
- Enabled automatically when using isolated environment

**Shared Config** (default for system installation):
- Config in `~/.claude/`
- Shared between all installations
- Can be forced with `--shared-config`

**Switch between modes**:
```bash
./iclaude.sh --isolated-config  # Use isolated config
./iclaude.sh --shared-config    # Use shared config
```

### Testing Proxy Configuration

Before launching Claude Code, test proxy separately:
```bash
# Test connection
./iclaude.sh --test

# Check what will be configured
./iclaude.sh --proxy https://proxy:8118 --test --show-password
```

The test performs:
1. HTTP request to `http://www.google.com`
2. HTTPS request to `https://www.anthropic.com`
3. Validates response codes and content

### Handling Domain Names in Proxy URLs

**Important change**: Domain names are handled differently based on proxy protocol:

**HTTPS Proxies** (recommended):
- Domain names are **PRESERVED** (NOT converted to IP)
- Required for OAuth token refresh and TLS (SNI, Host header)
- Converting to IP breaks Anthropic authentication

```bash
# Input: https://proxy.example.com:8118
# Saved as: https://proxy.example.com:8118  (domain preserved!)
```

**HTTP Proxies** (not recommended):
- Script offers to convert domain to IP (optional)
- IP conversion improves reliability by avoiding DNS lookup issues

```bash
# Input: http://proxy.example.com:8118
# User choice: convert to http://192.168.1.100:8118 or keep domain
```

**Why this matters for HTTPS**:
- Anthropic OAuth validates the Host header during token refresh
- TLS Server Name Indication (SNI) requires the actual domain name
- Using IP instead of domain causes authentication failures

## Common Development Tasks

### Using Chrome Integration

**Chrome integration is ENABLED BY DEFAULT** when launching Claude Code via iclaude.sh.

To disable Chrome integration:
```bash
./iclaude.sh --no-chrome
```

**Requirements:**
- Google Chrome browser installed and running
- Claude in Chrome extension v1.0.36 or higher
- Claude Code CLI v2.0.73 or higher
- Paid Claude plan (Pro/Team/Enterprise)

**Capabilities:**
- Navigate pages and open tabs
- Click elements and input text
- Fill forms
- Read console logs and network requests
- Record GIF of interactions

**Note:** Chrome integration increases context usage. Use `--no-chrome` if you don't need browser automation.

### Adding New Command-Line Options

1. Add option parsing in `main()` (iclaude.sh:2996)
2. Add flag variable initialization
3. Add to `show_usage()` help text (iclaude.sh:2807)
4. Implement functionality in appropriate function

### Modifying Proxy Validation

Edit `validate_proxy_url()` (iclaude.sh:56) and `parse_proxy_url()` (iclaude.sh:155).

**Be careful**: Changes may affect existing saved credentials format.

### Adding New Environment Variables

Add configuration in `configure_proxy_from_url()` (iclaude.sh:1545) or `setup_isolated_nvm()` (iclaude.sh:361).

### Debugging Tips

```bash
# Enable bash debug mode
bash -x ./iclaude.sh --test

# Check which Claude binary will be used
bash -c 'source ./iclaude.sh && get_nvm_claude_path'

# Verify environment setup
bash -c 'source ./iclaude.sh && setup_isolated_nvm && env | grep -E "(NVM|CLAUDE|PROXY)"'

# Check lockfile consistency
./iclaude.sh --check-isolated
```

## Integration with Claude Code Skills

The repository includes a Skills system in `.nvm-isolated/.claude-isolated/skills/`. When developing iclaude.sh:

- Use `structured-planning` skill for breaking down complex features
- Use `bash-development` skill for refactoring bash functions
- Use `git-workflow` skill for commit message generation
- Use `validation-framework` skill for testing new features

See README.md for full Skills documentation.

## LSP Integration

The `lsp-integration` skill provides automatic Language Server Protocol (LSP) plugin setup for enhanced code intelligence across 11+ languages.

### Supported Languages

- **TypeScript/JavaScript** - typescript-lsp (vtsls server)
- **Python** - pyright-lsp (pyright server)
- **Go** - gopls-lsp (gopls server)
- **Rust** - rust-analyzer-lsp (rust-analyzer server)
- **C#** - csharp-lsp (OmniSharp server)
- **Java** - jdtls-lsp (Eclipse JDT LS)
- **Kotlin** - kotlin-lsp (kotlin-language-server)
- **Lua** - lua-lsp (lua-language-server)
- **PHP** - php-lsp (Intelephense server)
- **C/C++** - clangd-lsp (clangd server)
- **Swift** - swift-lsp (SourceKit-LSP server)

### How It Works

The `lsp-integration` skill automatically:
1. Detects project language from `context-awareness` skill
2. Checks if LSP plugin is installed for current project
3. Verifies LSP server binary is available
4. Recommends installation if missing (non-blocking)
5. Outputs `lsp_status` for enhanced code-review and validation

### Workflow Integration

**PHASE 0:** LSP integration runs after `context-awareness` and before `adaptive-workflow`
**PHASE 3:** Code review benefits from LSP-detected type errors and code intelligence
**PHASE 4:** Validation includes LSP diagnostics when available

### Benefits

- **Go-to-definition**: Navigate to symbol definitions across files
- **Find references**: Locate all usages of symbols
- **Type checking**: Catch type errors before runtime
- **Auto-completion**: Intelligent code suggestions

### Manual Installation

If LSP plugin not auto-installed, install manually:
```bash
# Inside Claude Code session
/plugin install pyright-lsp@claude-plugins-official
/plugin install typescript-lsp@claude-plugins-official
# ... etc
```

### LSP Server Installation

After plugin installation, install LSP server binary:
```bash
# Python
npm install -g pyright

# TypeScript
npm install -g @vtsls/language-server

# Go
go install golang.org/x/tools/gopls@latest

# Rust (via rustup)
rustup component add rust-analyzer
```

See `skills/lsp-integration/SKILL.md` for language-specific prerequisites and troubleshooting.

## Future Migration: Native Installer

### Current Status

**iclaude.sh uses npm-based installation** (deprecated by Anthropic but continues to work normally)

Starting with Claude Code v2.1.0, Anthropic recommends using the native installer instead of npm for installing and updating Claude Code. The npm installation method is deprecated but **remains fully functional**.

### Why Anthropic Recommends Native Installer

**Benefits:**
- **Automatic updates**: No manual `npm update` commands required
- **System integration**: Better integration with system package managers (apt, brew, etc.)
- **Simplified setup**: Single command installation without Node.js/npm prerequisites
- **Consistent experience**: Same installation process across all platforms

**Official documentation**: https://code.claude.com/docs/en/setup

### Why iclaude.sh Continues Using npm

**Strategic reasons:**
1. **Zero breaking changes**: Existing users' workflows remain unchanged
2. **Version control**: Lockfile-based reproducibility for teams
3. **Isolated environment**: Self-contained installation in `.nvm-isolated/`
4. **Proxy compatibility**: Proven HTTP/HTTPS proxy support via npm
5. **LSP/Router integration**: Same npm-based toolchain for all components

**Technical guarantee**: npm installation will continue to work as long as `@anthropic-ai/claude-code` npm package exists.

### What This Means for Users

**Current behavior** (no action required):
- iclaude.sh works normally with npm-based installation
- Claude Code v2.1.15 shows informational warning at launch
- All features (OAuth, proxy, router, LSP) function correctly
- Warning is informational only, not a critical error

**When you see the warning:**
```
Claude Code has switched from npm to native installer.
The npm package will continue to work, but is no longer recommended.
```

This is **expected behavior**. iclaude.sh acknowledges this deprecation but continues to use npm for the reasons outlined above.

### Migration Roadmap

#### Phase 1: Documentation (Current) ✅
- Document native installer recommendation
- Add informational message to `--check-isolated`
- Explain npm deprecation status
- No changes to installation behavior

#### Phase 2: Hybrid Support (Q2 2026)
**Goal**: Offer native installer as opt-in alternative

**Planned features:**
- New flag: `--install-native` for native installer setup
- Function: `detect_native_claude()` to find native installation
- Hybrid detection: Prefer native if exists, fall back to npm
- Preserve npm as default (backward compatibility)

**User experience:**
```bash
# Opt-in to native installer
./iclaude.sh --install-native

# Continue using npm (default)
./iclaude.sh --isolated-install
```

#### Phase 3: Full Migration (If Anthropic Removes npm Package)
**Trigger**: Anthropic discontinues `@anthropic-ai/claude-code` npm package

**Migration plan:**
1. Switch to native installer as default
2. Preserve lockfile for Node.js, LSP servers, Router versions
3. Migrate existing isolated environments to native
4. Provide migration guide with backward compatibility notes

**Breaking change**: Yes (major version bump to iclaude v2.0.0)

### FAQ

**Q: Should I switch to native installer now?**
A: Not required. npm installation works normally. iclaude.sh will add opt-in support in Phase 2.

**Q: Will iclaude.sh stop working?**
A: No. npm installation is deprecated but functional. Anthropic has not announced removal timeline.

**Q: Can I use native installer manually alongside iclaude.sh?**
A: Yes, but manage separately. iclaude.sh won't detect native installation in Phase 1.

**Q: How does this affect OAuth token refresh?**
A: No impact. OAuth mechanism is independent of installation method.

**Q: What about proxy configuration?**
A: Native installer should support same proxy environment variables (`HTTPS_PROXY`, etc.). Will be tested in Phase 2.

**Q: Will lockfile still work?**
A: Yes. Node.js, LSP servers, and Router versions remain in lockfile. Claude Code version tracking may change in Phase 3.

### Technical Comparison: npm vs Native

| Feature | npm (Current) | Native Installer |
|---------|---------------|------------------|
| Auto-updates | Manual `npm update` | Automatic via installer |
| Prerequisites | Node.js + npm | None (self-contained) |
| Isolated install | Yes (`.nvm-isolated/`) | System-wide only |
| Version locking | Lockfile support | System package manager |
| Proxy support | `HTTPS_PROXY` env vars | TBD (likely same) |
| Team reproduction | `--install-from-lockfile` | Platform-specific packages |
| Integration | npm ecosystem | OS package managers |

### Developer Notes

**If implementing native installer support:**
1. Add `detect_native_claude()` function after `detect_router()` (iclaude.sh:~380)
2. Modify `get_nvm_claude_path()` to check native paths first
3. Update lockfile schema to include `installMethod: "npm" | "native"`
4. Test proxy compatibility with native binary
5. Document migration path in this section

**Native installer paths** (for future detection):
- **Linux**: `/usr/local/bin/claude` or `~/.local/bin/claude`
- **macOS**: `/usr/local/bin/claude` or `/Applications/Claude.app/Contents/MacOS/claude`
- **Windows**: `%LOCALAPPDATA%\Programs\Claude\claude.exe`

**Configuration directory** (native installer):
- Same as npm: `~/.claude/` or `$CLAUDE_DIR`
- iclaude.sh isolated config (`--isolated-config`) should work unchanged

## Security Considerations

1. **Credential Storage**: `.claude_proxy_credentials` uses chmod 600 (owner-only)
2. **Git Exclusion**: Credentials never committed to git (see .gitignore)
3. **Password Display**: Hidden by default, use `--show-password` to debug
4. **HTTPS Proxy**: Prefer `--proxy-ca` over `--proxy-insecure`
5. **Proxy Trust**: Only use trusted proxy servers (MitM risk)
