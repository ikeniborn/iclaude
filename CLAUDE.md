# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**iclaude** is a bash wrapper for launching Claude Code with HTTP/HTTPS proxy, isolated environment, OAuth auto-refresh, Claude Code Router, PII proxy (Presidio NLP), microVM sandbox (Firecracker), Graphify knowledge graph, and GSD framework.

Key paths: `.nvm-isolated/` (isolated env), `lib/` (16 bash modules), `docs/` (feature docs).

See [README.md](README.md) for the full feature list.

## IDD → SDD workflow

For non-trivial features (new module, new CLI flag, API change, architectural decision):

1. `/idd <topic>` — creates intent doc in `docs/superpowers/intents/`
2. `/brainstorm` — reads intent doc as context (Step 1 picks it up automatically)

## Commands

### Daily

```bash
./iclaude.sh                    # Launch with saved settings
./iclaude.sh --no-proxy         # Launch without proxy
./iclaude.sh --update           # Update Claude Code (npm + lockfile)
```

### Testing

```bash
./iclaude.sh --test             # Test proxy configuration
./iclaude.sh --check-isolated   # Check isolated environment status
bash -n iclaude.sh              # Validate script syntax

# Security hooks test suite (28 tests)
python3 -m pytest tests/test_patterns_examples.py -v

# Test block-secrets hook (should print "BLOCKED" and exit 2)
echo '{"tool_name":"Read","tool_input":{"file_path":"/project/.env"}}' \
  | python3 .nvm-isolated/.claude-isolated/hooks/block-secrets.py; echo "exit: $?"
```

### Installation

```bash
./iclaude.sh --isolated-install       # First-time install
./iclaude.sh --repair-isolated        # After git clone: download native binary + repair symlinks
./iclaude.sh --install-from-lockfile  # Install exact versions from lockfile
./iclaude.sh --install-lsp            # Install LSP servers (TypeScript + Python)
./iclaude.sh --install-pii-proxy      # Install PII proxy (Python venv + Presidio NLP)
./iclaude.sh --install-graphify       # Install Graphify (uv + Python 3.12 + graphifyy)
./iclaude.sh --install-lat         # Install lat.md (Node 22 + MCP)
./iclaude.sh --lat-init            # Initialize lat.md/ in current project
./iclaude.sh --lat-check           # Check doc link integrity + install pre-commit hook
./iclaude.sh --check-lat           # Show lat.md status
./iclaude.sh --install-gsd            # Install GSD framework (npx get-shit-done-cc)
./iclaude.sh --check-gsd              # Check GSD installation status
./iclaude.sh --install-microvm        # Install Firecracker (~1.4GB)
./iclaude.sh --sandbox-microvm        # Launch with microVM kernel isolation
```

## Features

| Feature | Docs |
|---------|------|
| Proxy Management (HTTPS/HTTP, CA certs) | [docs/PROXY.md](docs/PROXY.md) |
| Router Integration (OpenRouter, DeepSeek, Ollama) | [docs/ROUTER.md](docs/ROUTER.md) |
| PII Proxy (Presidio NLP, SSE streaming) | [docs/PII_MASKING.md](docs/PII_MASKING.md) |
| Status Line (context usage, cache, session links) | [docs/STATUSLINE.md](docs/STATUSLINE.md) |
| microVM Sandbox (Firecracker, virtio-blk+SSH, KVM) | [docs/MICROVM.md](docs/MICROVM.md) |
| Graphify Knowledge Graph (uv, Python 3.12, graphifyy) | `lib/graphify/` |
| lat.md Documentation Graph (Node 22, MCP server) | `lib/lat/` |
| GSD Framework (meta-prompting, spec-driven dev) | [docs/superpowers/specs/2026-05-14-gsd-integration-design.md](docs/superpowers/specs/2026-05-14-gsd-integration-design.md) |
| OAuth Token Management | `lib/oauth/token.sh` |
| Configuration Variables | [docs/CONFIGURATION.md](docs/CONFIGURATION.md) |

## Security Hooks (PreToolUse)

Two-layer protection. Configured in `settings.json` via `$CLAUDE_CONFIG_DIR`.

**Layer 1: `block-secrets.py`** — blocks file access (exit 2)

| Pattern | Action |
|---------|--------|
| `.env`, `.pem`, `.key`, `.p12`, `.pfx` | Blocked |
| `.ssh/`, `.gnupg/` | Blocked |
| `.env.example`, `.env.sample` | Allowed |
| `.nvm-isolated/.claude-isolated/hooks/` | Allowed (self-exclusion) |

**Layer 2: `redact-secrets.py`** — redacts content (`toolInputOverride`)

| Pattern | Replacement |
|---------|-------------|
| `sk-ant-...`, `sk-proj-...` | `[ANTHROPIC_API_KEY]` |
| `AKIA[0-9A-Z]{16}` | `[AWS_ACCESS_KEY_ID]` |
| `ghp_`, `github_pat_` | `[GITHUB_TOKEN]` |
| `eyJ...` (JWT) | `[JWT_REDACTED]` |
| `scheme://[CREDENTIALS]@host` | `[CREDENTIALS_REDACTED]` |
| `.env` vars (`KEY=value{20+}`) | `[ENV_VAR_REDACTED]` |
| PEM private keys | `[PRIVATE_KEY_REDACTED]` |

`Edit.old_string` is NOT redacted — it is a search pattern; masking would break the Edit tool.

## Isolation Mechanisms

- `CLAUDE_CONFIG_DIR` isolation (always active) — config in `.nvm-isolated/.claude-isolated/`
- microVM (Firecracker) — kernel-level isolation via `--sandbox-microvm`

bubblewrap (bwrap) was removed (2026-03) because it created 0-byte read-only stub files in `.claude/` of other open projects.

## Notes

### Native Binary (since v2.1.114)

Claude Code uses a native binary (`bin/claude.exe`, ~237MB) excluded from git (exceeds GitHub 100MB limit).

After `git clone`, run `--repair-isolated` to download the binary via `npm install` + postinstall. Without it, detection falls through to the legacy `cli.js` path, or fails with a clear error.

Detection order (`lib/nvm/detect.sh::get_nvm_claude_path()`):
1. `$npm_prefix/bin/claude` (symlink)
2. `bin/claude.exe` (native binary, v2.1.114+)
3. `cli.js` via `node` (legacy pre-v2.1.114)

### Chrome Integration

DISABLED BY DEFAULT — requires paid plan + Chrome extension v1.0.36+ + Claude Code CLI v2.0.73+; enabling without these causes startup errors.

```bash
./iclaude.sh --chrome    # Enable Chrome integration
./iclaude.sh --no-chrome # Disable explicitly
```

### Tasks System

ENABLED BY DEFAULT. Disable only if the tasks UI conflicts with your workflow:

```bash
CLAUDE_CODE_ENABLE_TASKS=false ./iclaude.sh
```

### Plans Directory

Plans saved to `docs/plans/` via `.claude/settings.json`:
```json
{ "plansDirectory": "docs/plans" }
```

### Configuration Best Practices

- Use HTTPS proxy (not HTTP) for OAuth compatibility
- Run `--repair-isolated` after `git clone`
- Verify lockfile after `--update`
- Test proxy with `--test` before launching

## Architecture

**Version 4.0** — modular bash in `lib/` (17 modules: core, command, proxy, nvm, oauth, router, lsp, config, lockfile, update, launcher, statusline, chrome, ohmyposh, pii-proxy, sandbox, graphify).

Source order: Phase 0 (core) → Phase 2–8.1 (feature modules) → Phase 14 (command dispatch).

Key exports (set by `lib/core/init.sh` + `lib/nvm/setup.sh`):
- `ISOLATED_NVM_DIR` — `.nvm-isolated/`
- `CLAUDE_CONFIG_DIR` — exported before Claude launch; used by hooks
- `NPM_CONFIG_PREFIX` — `$ISOLATED_NVM_DIR/npm-global`

When modifying `lib/` modules, invoke **@skill:iclaude-architecture** first.

## Security Considerations

1. `.claude_config` — chmod 600, never committed; use `.claude_config.example` as template
2. Prefer `--proxy-ca` over `--proxy-insecure`
3. `undici` does not verify target server certs when proxying HTTPS ([HackerOne #1583680](https://hackerone.com/reports/1583680))
4. Router API keys: store in `.claude_config` as `export DEEPSEEK_API_KEY=...`
5. PII Proxy runs on localhost only (127.0.0.1)
6. CCR requires real API key (`sk-ant-api03-...`), not OAuth token (`sk-ant-oat01-...`)

## Skills

Before answering questions about this project, invoke **@skill:context-awareness** to load relevant docs.

- **@skill:iclaude-architecture** — implementation details of `lib/` modules
- **@skill:iclaude-commands** — CLI command reference
- **@skill:lsp-integration** — LSP integration
- **@skill:git-workflow** — commit messages and PR creation
