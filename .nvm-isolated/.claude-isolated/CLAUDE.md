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

## Quick Start

### First Time Setup

```bash
# Clone repository
git clone <repo-url>
cd iclaude

# Install isolated environment
./iclaude.sh --isolated-install

# Launch Claude Code
./iclaude.sh
```

### With Proxy

```bash
# Configure proxy (credentials saved securely)
./iclaude.sh --proxy https://user:pass@proxy.example.com:8118

# Launch with saved credentials
./iclaude.sh
```

### With Router (Alternative LLM Providers)

```bash
# Install Claude Code Router
./iclaude.sh --install-router

# Edit router.json with provider configuration
# Export API keys: export DEEPSEEK_API_KEY=...

# Launch via router
./iclaude.sh --router
```

## Development Workflow

### Daily Commands

```bash
# Launch with saved settings (proxy + isolated)
./iclaude.sh

# Launch without proxy
./iclaude.sh --no-proxy

# Launch without Chrome integration
./iclaude.sh --no-chrome

# Update Claude Code
./iclaude.sh --update
```

### Testing and Validation

```bash
# Test proxy configuration
./iclaude.sh --test

# Check isolated environment status
./iclaude.sh --check-isolated

# Check configuration status
./iclaude.sh --check-config

# Refresh OAuth token manually
./iclaude.sh --refresh-token

# Validate script syntax
bash -n iclaude.sh
```

### Installation Management

```bash
# Install from lockfile (exact versions)
./iclaude.sh --install-from-lockfile

# Repair symlinks after git clone
./iclaude.sh --repair-isolated

# Clean up isolated environment
./iclaude.sh --cleanup-isolated
```

### LSP Server Management

```bash
# Install LSP servers (TypeScript + Python)
./iclaude.sh --install-lsp

# Install specific LSP servers
./iclaude.sh --install-lsp python go

# Check LSP server status
./iclaude.sh --check-lsp
```

### Router Commands

```bash
# Install router
./iclaude.sh --install-router

# Check router status
./iclaude.sh --check-router

# Launch via router (opt-in)
./iclaude.sh --router

# Launch native Claude (default)
./iclaude.sh
```

## Features

### Proxy Management

**Supported protocols:**
- **HTTPS** (recommended) - Preserves domain names for OAuth/TLS
- **HTTP** (optional domain-to-IP conversion)
- **NOT supported:** SOCKS5 (causes crash due to undici limitations)

**Configuration:**
```bash
# Save proxy credentials
./iclaude.sh --proxy https://user:pass@proxy.example.com:8118

# Test proxy
./iclaude.sh --test

# With custom CA certificate
./iclaude.sh --proxy https://proxy:8118 --proxy-ca /path/to/cert.pem
```

**Security:**
- Credentials stored in `.claude_proxy_credentials` (chmod 600)
- HTTPS proxy recommended (HTTP proxy has MitM risks)
- Prefer `--proxy-ca` over `--proxy-insecure`

### Isolated Environment

Self-contained installation in `.nvm-isolated/`:
- Node.js + npm + Claude Code (~278MB)
- Separate configuration from system installation
- Lockfile-based version pinning
- Git-friendly with symlink repair

**Configuration isolation:**
- Sessions: `.nvm-isolated/.claude-isolated/session-env/`
- History: `.nvm-isolated/.claude-isolated/history.jsonl`
- Credentials: `.nvm-isolated/.claude-isolated/.credentials.json`
- Settings: `.nvm-isolated/.claude-isolated/settings.json`

### OAuth Token Management

Automatic token refresh at launch:
- Checks expiration every launch
- Refreshes if expires within 7 days
- Uses `claude setup-token` for long-lived tokens (~1 year)
- Manual refresh: `./iclaude.sh --refresh-token`

### Router Integration

Opt-in activation for alternative LLM providers:
- **Providers:** OpenRouter, DeepSeek, OpenAI, Ollama, Gemini, Volcengine, SiliconFlow
- **Configuration:** `router.json` with `${VAR_NAME}` placeholders
- **Launch:** `./iclaude.sh --router` (default: native Claude)
- **Proxy compatible:** Inherits `HTTPS_PROXY` environment variables

### Status Line

Custom status line script showing real-time metrics. See **[docs/STATUSLINE.md](../../../docs/STATUSLINE.md)** for complete documentation.

**Quick Reference:**
- **Location:** `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
- **Format:** `112,762 total | 50,000 active (25%) [cache]79K Sonnet 4.5 $1.06 [proxy] [router]provider [session] branch`
- **Features:** Dual context tracking, cache visibility, session links, append-only optimization

### Loop Mode

Execute tasks with retry logic (experimental):
```bash
# Sequential execution
./iclaude.sh --loop task.md

# Parallel execution (Week 2 - not yet implemented)
./iclaude.sh --loop-parallel task.md --max-parallel 3
```

**Features:**
- Exponential backoff (2s, 4s, 8s, 16s, 32s, max 60s)
- Completion promise verification
- Git integration (auto-commit + push)
- Markdown task definition format

## Code Architecture

### Main Components

For detailed architecture documentation, see **@skill:iclaude-architecture**.

**Quick overview:**

1. **Proxy Management** (iclaude.sh:1343-1666)
   - URL validation, credential storage, environment configuration
   - Domain-to-IP resolution, secure storage (chmod 600)

2. **Isolated Environment** (iclaude.sh:361-978)
   - Portable NVM+Node.js+Claude in `.nvm-isolated/`
   - Symlink management, lockfile-based pinning

3. **Version Management** (iclaude.sh:616-768)
   - Lockfile tracking: Node.js, npm, Claude Code, Router, gh CLI, LSP servers
   - Installation from lockfile: `./iclaude.sh --install-from-lockfile`

4. **Configuration Isolation** (iclaude.sh:1099-1341)
   - Separate state between isolated and system installations
   - Config directory: `.nvm-isolated/.claude-isolated/`

5. **NVM Detection** (iclaude.sh:200-318)
   - Find Claude Code binary in isolated/system/NVM environments
   - Handle temporary `.claude-*` binaries

6. **Update Management** (iclaude.sh:529-2389)
   - Safe updates with cleanup of `.claude-code-*` temporary folders
   - Symlink recreation, lockfile auto-update

7. **OAuth Token Management** (iclaude.sh:2749-2874)
   - Automatic expiration checks and refresh
   - `claude setup-token` for long-lived tokens (~1 year)

8. **Router Management** (iclaude.sh:324-379, 584-637, 1333-1430)
   - Opt-in activation via `--router` flag
   - Configuration with environment variable substitution

### Critical Functions

For implementation details, see **@skill:iclaude-architecture**.

**Key functions:**
- `validate_proxy_url()` - Validates URL format (HTTP/HTTPS only)
- `resolve_domain_to_ip()` - DNS resolution fallback chain
- `get_nvm_claude_path()` - Locates Claude Code binary
- `repair_isolated_environment()` - Fixes broken symlinks
- `save_isolated_lockfile()` - Captures versions to lockfile
- `detect_router()` - Checks router availability
- `check_oauth_token()` - Automatic token validation

### Environment Variables

```bash
# Proxy configuration
HTTPS_PROXY="https://user:pass@proxy:port"
HTTP_PROXY="https://user:pass@proxy:port"
NO_PROXY="localhost,127.0.0.1,github.com,..."

# TLS configuration (optional)
NODE_EXTRA_CA_CERTS="/path/to/proxy-cert.pem"
NODE_TLS_REJECT_UNAUTHORIZED=0  # Insecure mode (not recommended)

# Isolated environment (when active)
NVM_DIR="$SCRIPT_DIR/.nvm-isolated"
CLAUDE_DIR="$SCRIPT_DIR/.nvm-isolated/.claude-isolated"
PATH="$ISOLATED_NVM_DIR/npm-global/bin:$ISOLATED_NVM_DIR/versions/node/.../bin:$PATH"

# Claude Code features
CLAUDE_CODE_ENABLE_TASKS="true"  # Enable tasks system
```

## File Structure

```
.
├── iclaude.sh                          # Main wrapper script (3325 lines)
├── .claude_proxy_credentials           # Proxy credentials (chmod 600, not in git)
├── .nvm-isolated/                      # Isolated environment (~278MB)
│   ├── nvm.sh                         # NVM installation
│   ├── versions/node/v18.20.8/        # Node.js installation
│   │   ├── bin/                       # Binaries (npm, npx, node, claude)
│   │   └── lib/node_modules/          # Global packages
│   ├── npm-global/                    # Global npm packages
│   └── .claude-isolated/              # Isolated configuration
│       ├── history.jsonl              # Command history
│       ├── session-env/               # Active sessions
│       ├── .credentials.json          # Anthropic credentials
│       ├── settings.json              # User settings
│       ├── skills/                    # Claude Code skills
│       ├── projects/                  # Project configs
│       └── scripts/                   # Custom scripts
│           └── claude-statusline.sh   # Status line script
├── .nvm-isolated-lockfile.json        # Version lockfile
└── README.md                          # User documentation
```

**Files NOT in git:**
- `.claude_proxy_credentials` - Sensitive credentials
- `.nvm-isolated/.cache/` - NPM cache
- `.nvm-isolated/.npm/` - NPM temporary files
- `.nvm-isolated/.claude-isolated/*` - Session data (except skills/, scripts/, CLAUDE.md)

## Important Notes

### Configuration Best Practices

See **@skill:iclaude-commands** for best practices and troubleshooting.

**Key points:**
- Use HTTPS proxy (not HTTP) for OAuth compatibility
- Run `--repair-isolated` after `git clone`
- Verify lockfile after `--update`
- Test proxy with `--test` before launching

### Chrome Integration

Chrome integration is **ENABLED BY DEFAULT**.

**To disable:**
```bash
./iclaude.sh --no-chrome
```

**Requirements:**
- Google Chrome browser running
- Claude in Chrome extension v1.0.36+
- Claude Code CLI v2.0.73+
- Paid Claude plan (Pro/Team/Enterprise)

**Capabilities:**
- Navigate pages, open tabs
- Click elements, input text
- Fill forms
- Read console logs, network requests
- Record GIF interactions

### Tasks System

Claude Code tasks system is **ENABLED BY DEFAULT** via `CLAUDE_CODE_ENABLE_TASKS=true`.

**To disable:**
```bash
CLAUDE_CODE_ENABLE_TASKS=false ./iclaude.sh
```

**Features:**
- Task tracking with status (pending/in_progress/completed)
- Dependencies management (blocks/blockedBy)
- Background process tracking
- Session sharing via `CLAUDE_CODE_TASK_LIST_ID`

## External Documentation

### Status Line Documentation

**File:** [docs/STATUSLINE.md](../../../docs/STATUSLINE.md)

**Contents:**
- Real-time context usage tracking
- Dual context display (cumulative + active)
- Cache visibility and /compact detection
- Session link generation (OSC 8 hyperlinks)
- Append-only optimization (19x faster)
- Helper scripts (`claude-show-cache.sh`)

### Migration Roadmap

**File:** [docs/MIGRATION.md](../../../docs/MIGRATION.md)

**Contents:**
- npm deprecation status
- Native installer comparison
- Phase 2: Hybrid Support (Q2 2026)
- Phase 3: Full Migration (if npm removed)
- FAQ and technical notes

### LSP Integration

**Skill:** @skill:lsp-integration

**Supported languages:**
TypeScript, Python, Go, Rust, C#, Java, Kotlin, Lua, PHP, C/C++, Swift

**Workflow:**
- Detects project language
- Checks LSP plugin installation
- Verifies LSP server binary
- Recommends installation if missing

## Related Skills

- **@skill:iclaude-architecture** - Code architecture and implementation details
- **@skill:iclaude-commands** - Command reference and usage examples
- **@skill:lsp-integration** - Language Server Protocol integration
- **@skill:git-workflow** - Git commit message generation and PR creation

## Security Considerations

1. **Credential Storage:** `.claude_proxy_credentials` uses chmod 600 (owner-only)
2. **Git Exclusion:** Credentials never committed to git (see .gitignore)
3. **Password Display:** Hidden by default, use `--show-password` to debug
4. **HTTPS Proxy:** Prefer `--proxy-ca` over `--proxy-insecure`
5. **Proxy Trust:** Only use trusted proxy servers (MitM risk with `undici` ProxyAgent)
6. **TLS Verification:** `undici` does not verify target server certificates when proxying HTTPS ([HackerOne #1583680](https://hackerone.com/reports/1583680))
