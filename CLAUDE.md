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
- **Two-layer security hooks** — block sensitive file access + redact secrets in content
- **PII proxy** — Python HTTP proxy with Presidio NLP masking 100% of Anthropic API traffic

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

# Run security hooks test suite (28 tests)
python3 -m pytest tests/test_patterns_examples.py -v

# Test block-secrets hook manually (should print "BLOCKED" and exit 2)
echo '{"tool_name":"Read","tool_input":{"file_path":"/project/.env"}}' \
  | python3 .nvm-isolated/.claude-isolated/hooks/block-secrets.py; echo "exit: $?"

# Test redact-secrets hook manually (should return toolInputOverride with masked content)
echo '{"tool_name":"Write","tool_input":{"file_path":"test.txt","content":"key=sk-ant-api03-ABCDEFGHIJKLMNOPQRSTUVabcdef"}}' \
  | python3 .nvm-isolated/.claude-isolated/hooks/redact-secrets.py
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

### PII Proxy (API Traffic Masking)

Python HTTP proxy that intercepts 100% of Anthropic API traffic to mask PII and secrets:
- **Masking scope:** system prompt, `messages[].content`, `tool_results` — all content types
- **Engine:** Presidio NLP (when installed) + deterministic regex fallback (always active)
- **Regex patterns:** API keys, JWT, AWS credentials, PEM keys, GitHub tokens, passwords, credit cards
- **Transport:** SSE streaming pass-through (no buffering for real-time responses)

**Setup:**
```bash
# Install Python venv + Presidio NLP (~500MB, one-time)
./iclaude.sh --install-pii-proxy

# Check installation
./iclaude.sh --check-pii-proxy

# Enable permanently
echo 'USE_PII_PROXY=true' >> .claude_config

# Enable for one session
./iclaude.sh --pii-proxy

# Combined mode: PII masking + CCR router (chain: claude → PII proxy → CCR → providers)
./iclaude.sh --pii-proxy --router
```

**Architecture (solo mode):** `claude → PII proxy (:9000) → Anthropic API`

**Architecture (combined mode):** `claude → PII proxy (:9000) → CCR (:3456) → providers`

- `ANTHROPIC_BASE_URL=http://127.0.0.1:9000` set before launch
- `ANTHROPIC_UPSTREAM_URL` preserves original upstream (Anthropic or CCR URL)
- Proxy started as background process; cleaned up via `trap EXIT` on claude exit
- **Combined mode** (`--pii-proxy --router`): CCR started as background daemon (`ccr start`),
  `ANTHROPIC_UPSTREAM_URL=http://127.0.0.1:3456` passed to PII proxy → all API traffic is
  masked before reaching CCR; CCR port parsed from `router.json` (default 3456)
- Solo `--pii-proxy` and solo `--router` modes unchanged (backward compatible)

**Documentation:** [docs/PII_MASKING.md](./docs/PII_MASKING.md)

### Status Line

Custom status line script showing real-time metrics. See **[docs/STATUSLINE.md](../../../docs/STATUSLINE.md)** for complete documentation.

**Quick Reference:**
- **Location:** `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
- **Format:** `112,762 total | 50,000 active (25%) [cache]79K Sonnet 4.5 $1.06 [proxy] [router]provider [session] branch`
- **Features:** Dual context tracking, cache visibility, session links, append-only optimization

### Security Hooks (PreToolUse)

Two-layer protection for sensitive data, active during all Claude Code sessions. Hooks are configured in `.nvm-isolated/.claude-isolated/settings.json` using `$CLAUDE_CONFIG_DIR` paths — exported by iclaude.sh before launch and inherited by hook subprocesses, so paths are correct in any project.

**Layer 1: `block-secrets.py`** — File path blocker

Intercepts Read/Edit/Write/MultiEdit/Bash calls. Blocks access to sensitive files by path pattern before the tool executes.

| Pattern | Action |
|---------|--------|
| `.env`, `.env.local`, `.env.production` | Blocked (реальные секреты) |
| `.pem`, `.key`, `.p12`, `.pfx` | Blocked (криптоключи) |
| `.ssh/`, `.gnupg/` | Blocked (системные ключи) |
| `.env.example`, `.env.sample`, `.env.template` | Allowed (безопасные суффиксы) |
| `.nvm-isolated/.claude-isolated/hooks/` | Allowed (самоисключение) |

Exit codes: `2` = block (tool NOT executed), `0` = allow

**Layer 2: `redact-secrets.py`** — Content redactor

Intercepts Write/Edit/MultiEdit/Bash calls. Rewrites tool arguments via `toolInputOverride` to mask secrets **before** they reach the tool (and before any logging).

| Pattern | Replacement |
|---------|-------------|
| Anthropic/OpenAI keys (`sk-ant-...`, `sk-proj-...`) | `[ANTHROPIC_API_KEY]` |
| AWS Access Key (`AKIA[0-9A-Z]{16}`) | `[AWS_ACCESS_KEY_ID]` |
| GitHub tokens (`ghp_`, `github_pat_`) | `[GITHUB_TOKEN]` |
| JWT tokens (`eyJ...header.payload.sig`) | `[JWT_REDACTED]` |
| URL credentials (`scheme://user:pass@host`) | `[CREDENTIALS_REDACTED]` |
| Password assignments (`password = value`) | `[PASSWORD_REDACTED]` |
| `.env` variables (`VAR_WITH_KEY=value{20+}`) | `[ENV_VAR_REDACTED]` |
| PEM private keys (`BEGIN ... PRIVATE KEY`) | `[PRIVATE_KEY_REDACTED]` |

**Note:** `Edit.old_string` is NOT redacted — it's a search pattern; masking would break the Edit tool.

**Configuration** (portable paths via `$CLAUDE_CONFIG_DIR`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Edit|Write|MultiEdit|Bash",
        "hooks": [{"type": "command", "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/block-secrets.py\""}]
      },
      {
        "matcher": "Write|Edit|MultiEdit|Bash",
        "hooks": [{"type": "command", "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/redact-secrets.py\""}]
      }
    ]
  }
}
```

**Documentation:** [docs/PII_MASKING.md](./docs/PII_MASKING.md)

## Code Architecture

### Main Components

For detailed architecture documentation, see **@skill:iclaude-architecture**.

**Quick overview:**

1. **Proxy Management** (lib/proxy/*.sh)
   - URL validation, credential storage, environment configuration
   - Domain-to-IP resolution, secure storage (chmod 600)

2. **Isolated Environment** (lib/nvm/*.sh)
   - Portable NVM+Node.js+Claude in `.nvm-isolated/`
   - Symlink management, lockfile-based pinning

3. **Version Management** (lib/lockfile/*.sh)
   - Lockfile tracking: Node.js, npm, Claude Code, Router, gh CLI, LSP servers
   - Installation from lockfile: `./iclaude.sh --install-from-lockfile`

4. **Configuration Isolation** (lib/config/*.sh)
   - Separate state between isolated and system installations
   - Config directory: `.nvm-isolated/.claude-isolated/`

5. **NVM Detection** (lib/nvm/detect.sh)
   - Find Claude Code binary in isolated/system/NVM environments
   - Handle temporary `.claude-*` binaries

6. **Update Management** (lib/update/*.sh)
   - Safe updates with cleanup of `.claude-code-*` temporary folders
   - Symlink recreation, lockfile auto-update

7. **OAuth Token Management** (lib/oauth/token.sh)
   - Automatic expiration checks and refresh
   - `claude setup-token` for long-lived tokens (~1 year)

8. **Router Management** (lib/router/*.sh)
   - Opt-in activation via `--router` flag
   - Configuration with environment variable substitution

9. **Security Hooks** (.nvm-isolated/.claude-isolated/hooks/)
   - PreToolUse interception: file path blocking + content redaction
   - `$CLAUDE_CONFIG_DIR` paths — works across machines and projects
   - Test suite: `tests/test_patterns_examples.py` (28 tests)

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

# PII proxy (set by iclaude.sh when --pii-proxy active)
ANTHROPIC_BASE_URL="http://127.0.0.1:9000"     # Redirects claude API traffic to proxy
ANTHROPIC_UPSTREAM_URL="https://api.anthropic.com"  # Proxy forwards here (or CCR URL)
```

## Modular Architecture

**Version 4.0** - Fully modular bash architecture with zero legacy dependencies.

### Library Structure

All functionality organized in `lib/` modules:

```
lib/
├── core/          # Validation, logging, JSON parsing
├── command/       # CLI argument parsing, help text
├── proxy/         # Proxy configuration and validation
├── nvm/           # NVM/Node.js/Claude detection and setup
├── oauth/         # OAuth token management
├── router/        # Claude Code Router integration
├── lsp/           # LSP server installation and management
├── config/        # Configuration isolation and export
├── lockfile/      # Version locking and reproducibility
├── update/        # Update management and cleanup
├── launcher/      # Claude Code launch orchestration
├── statusline/    # Status line integration
├── chrome/        # Chrome integration detection
├── ohmyposh/      # oh-my-posh integration
├── sandbox/       # Sandbox environment detection
└── pii-proxy/     # PII/secrets masking HTTP proxy (Presidio NLP)
```

**Module loading:** All modules are sourced in `iclaude.sh` entry point. Each module is self-contained and reusable.

**Testing:** Module-specific tests in `tests/` directory verify core functionality.

## File Structure

```
.
├── iclaude.sh                          # Modular entry point (~200 lines)
├── lib/                                # Modular bash libraries (v4.0)
├── .claude_config.example              # Configuration template (in git, safe to share)
├── .claude_config                      # Active config: proxy + API keys (chmod 600, not in git)
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
│       ├── settings.json              # User settings (in git)
│       ├── hooks/                     # PreToolUse security hooks (in git)
│       │   ├── block-secrets.py       # File path blocker (exit 2 = block)
│       │   └── redact-secrets.py      # Content redactor (toolInputOverride)
│       ├── skills/                    # Claude Code skills
│       ├── projects/                  # Project configs
│       └── scripts/                   # Custom scripts
│           └── claude-statusline.sh   # Status line script
├── .nvm-isolated-lockfile.json        # Version lockfile
└── README.md                          # User documentation
```

**Files NOT in git:**
- `.claude_config` - Active configuration with secrets (proxy credentials, API keys)
- `.claude_proxy_credentials` - Legacy filename (автоматически мигрирует в `.claude_config`)
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

### Plan Directory Configuration

Claude Code сохраняет планы выполнения задач в режиме планирования (plan mode).

**Настройка пути:** `.claude/settings.json`

```json
{
  "plansDirectory": "docs/plans"
}
```

**Особенности:**
- **По умолчанию**: Планы сохраняются в `~/.claude/plans/` (глобальный каталог)
- **С настройкой**: Планы сохраняются в каталоге проекта относительно корня
- **Версионирование**: Локальные планы можно коммитить в git
- **Совместная работа**: Команда видит историю планирования

**Преимущества локального хранения:**
- ✅ Планы под версионным контролем вместе с кодом
- ✅ Легко найти в IDE и через поиск
- ✅ Служат документацией принятых решений
- ✅ Прозрачность для команды

**Использование:**
```bash
# Создание плана в режиме планирования
./iclaude.sh
> /plan Implement user authentication

# Планы автоматически сохраняются в docs/plans/
```

См. [docs/plans/README.md](../../../docs/plans/README.md) для подробной информации.

### Sandbox Limitations

Claude Code sandbox (bubblewrap) **ОТКЛЮЧЁН ПО УМОЛЧАНИЮ** (`sandbox.enabled: false`) из-за upstream-бага.

**Проблема: bind-mount артефакты в других проектах**

При включённом sandbox (`sandbox.enabled: true`) bubblewrap создаёт 0-байтовые read-only заглушки в `.claude/` каталогах других проектов, которые были открыты в момент инициализации namespace:

```
.claude/settings.json       (0 bytes, chmod 444)
.claude/settings.local.json (0 bytes, chmod 444)
.claude/agents              (0 bytes, chmod 444) ← файл, не директория
.claude/commands            (0 bytes, chmod 444) ← файл, не директория
```

Файлы остаются на диске после завершения sandbox-контейнера — автоматической очистки нет.

**Причина:** bubblewrap использует технику `--ro-bind /dev/null <path>` для маскировки путей. Это поведение самого Claude Code, со стороны iclaude не исправляется.

**Два независимых механизма изоляции:**
- `CLAUDE_CONFIG_DIR` изоляция (всегда активна) — конфиг идёт в `.nvm-isolated/.claude-isolated/`
- Bubblewrap sandbox (отключён) — OS-уровень, изолирует инструментальные вызовы

**Очистка артефактов если sandbox был включён:**
```bash
find /path/to/project/.claude -maxdepth 1 -type f -empty -perm 444 \
  -exec chmod 644 {} \; -delete
```

**Двухуровневые security hooks** работают независимо от sandbox:

| Хук | Тип | Действие |
|-----|-----|----------|
| `block-secrets.py` | PreToolUse (Read/Edit/Write/Bash) | Блокирует по ПУТИ файла (exit 2) |
| `redact-secrets.py` | PreToolUse (Write/Edit/MultiEdit/Bash) | Маскирует СОДЕРЖИМОЕ через `toolInputOverride` |

Подробнее: **[Security Hooks (PreToolUse)](#security-hooks-pretooluse)** в разделе Features.

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

1. **Credential Storage:** `.claude_config` uses chmod 600 (owner-only); never committed to git
2. **Configuration Template:** `.claude_config.example` — safe template in git; copy → `.claude_config` and fill in secrets
3. **Password Display:** Hidden by default, use `--show-password` to debug
4. **HTTPS Proxy:** Prefer `--proxy-ca` over `--proxy-insecure`
5. **Proxy Trust:** Only use trusted proxy servers (MitM risk with `undici` ProxyAgent)
6. **TLS Verification:** `undici` does not verify target server certificates when proxying HTTPS ([HackerOne #1583680](https://hackerone.com/reports/1583680))
7. **Router API Keys:** Store in `.claude_config` as `export DEEPSEEK_API_KEY=...`; referenced in `router.json` via `${VAR}` placeholders
8. **Security Hooks:** `block-secrets.py` + `redact-secrets.py` — block sensitive file access and redact secrets in content; use `$CLAUDE_CONFIG_DIR` (exported by iclaude.sh, works across machines and projects)
9. **Hook Portability:** `settings.json` uses `$CLAUDE_CONFIG_DIR` (exported before launch, inherited by hook subprocesses) — hooks resolve correctly in any project, safe to commit to git
10. **PII Proxy:** When enabled, all API traffic (system prompt + messages + tool_results) is masked before reaching Anthropic servers; runs on localhost only (127.0.0.1)

