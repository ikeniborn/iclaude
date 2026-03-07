# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**iclaude** is a bash-based wrapper script for launching Claude Code with automatic HTTP/HTTPS proxy configuration. It provides both isolated (portable) and system-wide installation modes, with secure credential storage and automatic environment setup.

Key features: isolated env (`.nvm-isolated/`), proxy management, version locking, OAuth auto-refresh, Claude Code Router, two-layer security hooks, PII proxy (Presidio NLP).

See [README.md](README.md) for full feature list.

## Quick Start

```bash
# Clone and install
git clone <repo-url> && cd iclaude
./iclaude.sh --isolated-install
./iclaude.sh

# With proxy
./iclaude.sh --proxy https://user:pass@proxy.example.com:8118

# With router (alternative LLM providers)
./iclaude.sh --install-router
./iclaude.sh --router
```

## Development Workflow

### Daily Commands

```bash
./iclaude.sh                    # Launch with saved settings
./iclaude.sh --no-proxy         # Launch without proxy
./iclaude.sh --no-chrome        # Launch without Chrome integration
./iclaude.sh --update           # Update Claude Code
```

### Testing and Validation

```bash
./iclaude.sh --test             # Test proxy configuration
./iclaude.sh --check-isolated   # Check isolated environment status
./iclaude.sh --check-config     # Check configuration status
./iclaude.sh --refresh-token    # Refresh OAuth token manually
bash -n iclaude.sh              # Validate script syntax

# Security hooks test suite (28 tests)
python3 -m pytest tests/test_patterns_examples.py -v

# Test block-secrets hook (should print "BLOCKED" and exit 2)
echo '{"tool_name":"Read","tool_input":{"file_path":"/project/.env"}}' \
  | python3 .nvm-isolated/.claude-isolated/hooks/block-secrets.py; echo "exit: $?"

# Test redact-secrets hook (should return toolInputOverride with masked content)
echo '{"tool_name":"Write","tool_input":{"file_path":"test.txt","content":"key=sk-ant-api03-ABCDEFGHIJKLMNOPQRSTUVabcdef"}}' \
  | python3 .nvm-isolated/.claude-isolated/hooks/redact-secrets.py
```

### Installation Management

```bash
./iclaude.sh --install-from-lockfile  # Install from lockfile (exact versions)
./iclaude.sh --repair-isolated        # Repair symlinks after git clone
./iclaude.sh --cleanup-isolated       # Clean up isolated environment
./iclaude.sh --install-lsp            # Install LSP servers (TypeScript + Python)
./iclaude.sh --check-lsp              # Check LSP server status
./iclaude.sh --install-pii-proxy      # Install PII proxy (Python venv + Presidio NLP)
./iclaude.sh --pii-proxy              # Launch with PII masking enabled
./iclaude.sh --pii-proxy --router     # Combined: PII masking + CCR router
```

## Features

| Feature | Docs |
|---------|------|
| Proxy Management (HTTPS/HTTP, CA certs) | [docs/PROXY.md](docs/PROXY.md) |
| Router Integration (OpenRouter, DeepSeek, Ollama…) | [docs/ROUTER.md](docs/ROUTER.md) |
| PII Proxy (Presidio NLP, SSE streaming) | [docs/PII_MASKING.md](docs/PII_MASKING.md) |
| Status Line (context usage, cache, session links) | [docs/STATUSLINE.md](docs/STATUSLINE.md) |
| OAuth Token Management (auto-refresh, ~1yr tokens) | `lib/oauth/token.sh` |
| Isolated Environment (NVM+Node.js in `.nvm-isolated/`) | `lib/nvm/` |
| Configuration Variables | [docs/CONFIGURATION.md](docs/CONFIGURATION.md) |
| LSP Integration | @skill:lsp-integration |
| Migration Roadmap (npm → native installer) | [docs/MIGRATION.md](docs/MIGRATION.md) |

## Security Hooks (PreToolUse)

Two-layer protection active during all Claude Code sessions. Configured in `settings.json` via `$CLAUDE_CONFIG_DIR` (exported by iclaude.sh, portable across machines and projects).

**Layer 1: `block-secrets.py`** — File path blocker (exit 2 = block tool)

| Pattern | Action |
|---------|--------|
| `.env`, `.env.local`, `.env.production` | Blocked |
| `.pem`, `.key`, `.p12`, `.pfx` | Blocked |
| `.ssh/`, `.gnupg/` | Blocked |
| `.env.example`, `.env.sample`, `.env.template` | Allowed |
| `.nvm-isolated/.claude-isolated/hooks/` | Allowed (self-exclusion) |

**Layer 2: `redact-secrets.py`** — Content redactor (`toolInputOverride`)

| Pattern | Replacement |
|---------|-------------|
| Anthropic/OpenAI keys (`sk-ant-...`, `sk-proj-...`) | `[ANTHROPIC_API_KEY]` |
| AWS Access Key (`AKIA[0-9A-Z]{16}`) | `[AWS_ACCESS_KEY_ID]` |
| GitHub tokens (`ghp_`, `github_pat_`) | `[GITHUB_TOKEN]` |
| JWT tokens (`eyJ...`) | `[JWT_REDACTED]` |
| URL credentials (`scheme://user:pass@host`) | `[CREDENTIALS_REDACTED]` |
| Password assignments | `[PASSWORD_REDACTED]` |
| `.env` variables (`VAR_WITH_KEY=value{20+}`) | `[ENV_VAR_REDACTED]` |
| PEM private keys | `[PRIVATE_KEY_REDACTED]` |

**Note:** `Edit.old_string` is NOT redacted (search pattern — masking would break Edit).

```json
{
  "hooks": { "PreToolUse": [
    {"matcher": "Read|Edit|Write|MultiEdit|Bash",
     "hooks": [{"type": "command", "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/block-secrets.py\""}]},
    {"matcher": "Write|Edit|MultiEdit|Bash",
     "hooks": [{"type": "command", "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/redact-secrets.py\""}]}
  ]}
}
```

## Sandbox Limitations

Sandbox (bubblewrap) is **DISABLED BY DEFAULT** (`sandbox.enabled: false`) due to upstream bug.

When enabled, bubblewrap creates 0-byte read-only stubs in `.claude/` of other open projects:
```
.claude/settings.json (0 bytes, chmod 444)   .claude/agents (0 bytes, chmod 444)
```
Files persist after sandbox exit — no automatic cleanup.

**Two independent isolation mechanisms:**
- `CLAUDE_CONFIG_DIR` isolation (always active) → config goes to `.nvm-isolated/.claude-isolated/`
- Bubblewrap sandbox (disabled) → OS-level, isolates tool calls

**Cleanup if sandbox was enabled:**
```bash
find /path/to/project/.claude -maxdepth 1 -type f -empty -perm 444 \
  -exec chmod 644 {} \; -delete
```

Security hooks work independently of sandbox — see [Security Hooks](#security-hooks-pretooluse).

## Important Notes

### Chrome Integration

Chrome integration is **ENABLED BY DEFAULT**. Disable: `./iclaude.sh --no-chrome`

Requirements: Chrome running + Claude in Chrome extension v1.0.36+ + Claude Code CLI v2.0.73+ + paid plan.

### Tasks System

Tasks system is **ENABLED BY DEFAULT** via `CLAUDE_CODE_ENABLE_TASKS=true`.
Disable: `CLAUDE_CODE_ENABLE_TASKS=false ./iclaude.sh`

### Plan Directory Configuration

Plans saved to `docs/plans/` (local, versioned) via `.claude/settings.json`:
```json
{ "plansDirectory": "docs/plans" }
```
See [docs/plans/README.md](docs/plans/README.md).

### Configuration Best Practices

- Use HTTPS proxy (not HTTP) for OAuth compatibility
- Run `--repair-isolated` after `git clone`
- Verify lockfile after `--update`
- Test proxy with `--test` before launching

## Code Architecture

**Version 4.0** — modular bash in `lib/` (15 modules: core, command, proxy, nvm, oauth, router, lsp, config, lockfile, update, launcher, statusline, chrome, ohmyposh, pii-proxy).

For implementation details: **@skill:iclaude-architecture** | **@skill:iclaude-commands**

## RFC Documents (Agent Protocol Specifications)

- [RFC-0001: Documentation Standards](docs/RFC-0001-documentation-standards.md)
- [RFC-0002: Agent Pipeline Protocol](docs/RFC-0002-agent-protocol-spec.md)
- [RFC-0003: TOON Protocol](docs/RFC-0003-toon-protocol.md)
- [RFC-0004: Inter-Agent Communication Optimization](docs/RFC-0004-inter-agent-communication.md)

## Related Skills

- **@skill:iclaude-architecture** — Code architecture and implementation details
- **@skill:iclaude-commands** — Command reference and usage examples
- **@skill:lsp-integration** — Language Server Protocol integration
- **@skill:git-workflow** — Git commit message generation and PR creation

## Security Considerations

1. **Credential Storage:** `.claude_config` uses chmod 600; never committed to git
2. **Configuration Template:** `.claude_config.example` — safe template; copy → `.claude_config` and fill secrets
3. **HTTPS Proxy:** Prefer `--proxy-ca` over `--proxy-insecure`
4. **Proxy Trust:** Only trusted proxy servers (MitM risk with `undici` ProxyAgent)
5. **TLS Verification:** `undici` does not verify target server certs when proxying HTTPS ([HackerOne #1583680](https://hackerone.com/reports/1583680))
6. **Router API Keys:** Store in `.claude_config` as `export DEEPSEEK_API_KEY=...`; referenced in `router.json` via `${VAR}` placeholders
7. **Security Hooks:** `block-secrets.py` + `redact-secrets.py` use `$CLAUDE_CONFIG_DIR` — work in any project, safe to commit
8. **PII Proxy:** All API traffic masked before Anthropic servers; runs on localhost only (127.0.0.1)
9. **CCR + Anthropic:** CCR cannot use OAuth token (`sk-ant-oat01-...`); requires real API key (`sk-ant-api03-...`) from `console.anthropic.com`

## Docs for LLM

Short docs for read always docs/llms.txt
After read docs/llms.txt for search use docs/llms-full.txt and use target docs after searching.