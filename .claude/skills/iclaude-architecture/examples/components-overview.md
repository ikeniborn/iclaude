# Components Overview

Detailed description of 9 main functional modules in iclaude.sh.

## 1. Proxy Management (lines 1343-1666)

**Functions:** `save_credentials`, `load_credentials`, `configure_proxy_from_url`

**Key Features:**
- Domain-to-IP resolution with `resolve_domain_to_ip()` (4 fallback methods)
- Secure credential storage (chmod 600 on `.claude_proxy_credentials`)
- HTTP/HTTPS protocols only (SOCKS5 NOT supported - crashes undici)
- NO_PROXY configuration for bypassing proxy

**Credential File Format:**
```
https://user:password@proxy.example.com:8118
```

**When to modify:** Adding new proxy protocols, changing credential format, implementing certificate handling.

## 2. Isolated Environment (lines 361-978)

**Functions:** `setup_isolated_nvm`, `install_isolated_nvm`, `repair_isolated_environment`

**Key Features:**
- Self-contained installation (~278MB in `.nvm-isolated/`)
- Symlink management for npm/npx/claude binaries
- Lockfile-based version pinning
- Git-friendly structure with repair capabilities

**Directory Structure:**
```
.nvm-isolated/
├── nvm.sh                    # NVM installation script
├── versions/node/v18.20.8/   # Node.js + global packages
├── npm-global/bin/           # Symlinks to binaries
└── .claude-isolated/         # Claude configuration
```

**When to modify:** Changing Node.js version, adding new global packages, modifying symlink paths.

## 3. Version Management (lines 616-768)

**Functions:** `save_isolated_lockfile`, `install_from_lockfile`, `update_isolated_claude`

**Lockfile Schema:**
```json
{
  "nodeVersion": "18.20.8",
  "claudeCodeVersion": "2.1.7",
  "routerVersion": "1.2.3",
  "ghCliVersion": "2.45.0",
  "lspServers": {"pyright": "1.1.347", ...},
  "lspPlugins": {"pyright-lsp@claude-plugins-official": "1.0.0", ...},
  "installedAt": "2026-01-14T10:39:51Z",
  "nvmVersion": "0.39.7"
}
```

**Critical for:** Reproducible deployments, team synchronization, CI/CD.

**When to modify:** Adding new tracked components (e.g., Docker version), changing lockfile format.

## 4. Configuration Isolation (lines 1099-1341)

**Functions:** `setup_isolated_config`, `check_config_status`, `export_config`, `import_config`

**Isolated Config Directory:** `.nvm-isolated/.claude-isolated/`

**What Gets Isolated:**
- Session data (`session-env/`)
- History (`history.jsonl`)
- Credentials (`.credentials.json`)
- Settings (`settings.json`)
- Project configs (`projects/`)
- File history (`file-history/`)
- TODOs (`todos/`)

**Why Important:** Prevents conflicts between isolated and system Claude installations.

**When to modify:** Adding new isolated state, changing config directory structure.

## 5. NVM Detection (lines 200-318)

**Functions:** `detect_nvm`, `get_nvm_claude_path`

**Priority Order** (without `--system` flag):
1. Isolated environment (`.nvm-isolated/`)
2. System NVM (`$NVM_DIR`)
3. System Node.js

**Handles Edge Cases:**
- Standard `claude` binary in `bin/`
- Temporary `.claude-*` binaries (from npm updates, sorted by mtime)
- Direct cli.js execution via Node
- Temporary `.claude-code-*` folders

**When to modify:** Adding new installation detection logic, changing priority order.

## 6. Update Management (lines 529-2389)

**Functions:** `update_isolated_claude`, `update_claude_code`, `cleanup_old_claude_installations`

**Key Features:**
- Automatic cleanup of `.claude-code-*` temporary folders
- Symlink recreation after updates
- Lockfile auto-update
- ENOTEMPTY error handling with retry logic

**Update Flow:**
1. Run `npm update -g @anthropic-ai/claude-code`
2. Clean up temp folders
3. Recreate symlinks
4. Update lockfile
5. Retry on ENOTEMPTY (exponential backoff)

**When to modify:** Changing update strategy, adding pre/post-update hooks.

## 7. OAuth Token Management (lines 2749-2874)

**Functions:** `check_oauth_token`, `refresh_oauth_token`

**Key Features:**
- Checks expiration at every launch
- Auto-refreshes within 7 days (configurable `TOKEN_REFRESH_THRESHOLD`)
- Uses `claude setup-token` for long-lived tokens (~1 year)
- Preserves credentials file on failure (doesn't delete refreshToken)

**Token Structure:**
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

**When to modify:** Changing refresh threshold, implementing headless refresh, adding token validation logic.

## 8. Router Management (lines 324-379, 584-637, 1333-1430)

**Functions:** `detect_router`, `get_router_path`, `install_isolated_router`, `check_router_status`

**Key Features:**
- Opt-in via `--router` flag (native Claude by default)
- Supports OpenRouter, DeepSeek, OpenAI, Ollama, Gemini, Volcengine, SiliconFlow
- Environment variable substitution (`${VAR_NAME}`)
- Lockfile integration for version tracking

**Configuration Files:**
- `router.json.example` - Template (in git)
- `router.json` - Team config with `${VAR}` placeholders (in git)
- `~/.claude-code-router/config.json` - Runtime config (NOT in git)

**Launch Flow (when `--router` specified):**
1. Check if `USE_ROUTER_FLAG=true`
2. Verify `router.json` exists and `ccr` binary installed
3. Copy `router.json` to `~/.claude-code-router/config.json`
4. Launch via `ccr code` instead of `claude`

**When to modify:** Adding new provider support, implementing router auto-update.

## 9. Auto-update Management (lines 1982-2024)

**Function:** `disable_auto_updates`

**Purpose:** Automatically disable Claude Code CLI auto-updates for CI/CD-managed installations.

**Key Features:**
- Runs automatically on every `iclaude.sh` launch
- Sets `autoUpdates: false` in `.claude.json`
- Works for both isolated and shared configurations
- Idempotent (safe to run multiple times)

**Why This Matters:**
- Prevents Claude Code from updating itself
- Ensures all machines use same version from git
- Updates controlled via CI/CD instead
- Consistent development environment across team

**When to modify:** Adding configuration validation, implementing version alerts.

## Integration Between Components

**Dependency Graph:**
```
NVM Detection → Isolated Environment → Configuration Isolation
     ↓
Version Management → Update Management
     ↓
OAuth Token Management → Auto-update Management
     ↓
Proxy Management → Router Management
```

**Common Interaction Pattern:**
1. Detect installation (Component 5)
2. Setup environment (Component 2)
3. Load configuration (Component 4)
4. Check versions (Component 3)
5. Configure proxy (Component 1)
6. Check OAuth token (Component 7)
7. Disable auto-updates (Component 9)
8. Launch Claude (via Router if `--router` flag)
