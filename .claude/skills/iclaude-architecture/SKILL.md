# iclaude-architecture

Reference guide for iclaude.sh code architecture: 9 main components, critical functions, environment variables, and file structure.

## Quick Reference

| Aspect | Details |
|--------|---------|
| **Invocation** | On-demand reference (not auto-invoked) |
| **Purpose** | Navigate iclaude.sh codebase (3325 lines) |
| **Components** | 9 functional modules + 10 critical functions |
| **Format** | Component → Location → Purpose → Key Features |
| **Integration** | Use `@skill:architecture-documentation` for auto-generation |

---

## When to Use

Use this skill when:
- Planning where to add new functionality
- Understanding existing component boundaries
- Debugging function interactions
- Reviewing code architecture

**Manual reference only** (not auto-invoked)

---

## Main Components

### 1. Proxy Management
- **Functions**: `save_credentials`, `load_credentials`, `configure_proxy_from_url`
- **Location**: iclaude.sh:1343-1666
- **Purpose**: Proxy URL validation, credential storage, environment configuration
- **Key Features**:
  - Domain-to-IP resolution (`resolve_domain_to_ip`)
  - Secure credential storage (chmod 600)
  - HTTP/HTTPS protocols (SOCKS5 not supported)
  - NO_PROXY configuration

### 2. Isolated Environment
- **Functions**: `setup_isolated_nvm`, `install_isolated_nvm`, `repair_isolated_environment`
- **Location**: iclaude.sh:361-978
- **Purpose**: Manage portable NVM+Node.js+Claude in `.nvm-isolated/`
- **Key Features**:
  - Self-contained installation (~278MB)
  - Symlink management for binaries
  - Lockfile-based version pinning
  - Git-friendly structure

### 3. Version Management
- **Functions**: `save_isolated_lockfile`, `install_from_lockfile`, `update_isolated_claude`
- **Location**: iclaude.sh:616-768
- **Purpose**: Track exact versions (Node.js, npm, Claude, Router, gh, LSP)
- **Lockfile Format**:
  ```json
  {
    "nodeVersion": "18.20.8",
    "claudeCodeVersion": "2.1.7",
    "routerVersion": "unknown",
    "ghCliVersion": "2.45.0",
    "lspServers": {"pyright": "1.1.347", ...},
    "lspPlugins": {"pyright-lsp@claude-plugins-official": "1.0.0", ...},
    "installedAt": "2026-01-14T10:39:51Z",
    "nvmVersion": "0.39.7"
  }
  ```

### 4. Configuration Isolation
- **Functions**: `setup_isolated_config`, `check_config_status`, `export_config`, `import_config`
- **Location**: iclaude.sh:1099-1341
- **Purpose**: Separate Claude Code state (isolated vs system)
- **Isolated Directory**: `.nvm-isolated/.claude-isolated/`
- **What Gets Isolated**: session-env/, history.jsonl, .credentials.json, settings.json, projects/, file-history/, todos/

### 5. NVM Detection
- **Functions**: `detect_nvm`, `get_nvm_claude_path`
- **Location**: iclaude.sh:200-318
- **Purpose**: Find Claude binary in various installation modes
- **Priority Order**:
  1. Isolated environment (`.nvm-isolated/`)
  2. System NVM (`$NVM_DIR`)
  3. System Node.js
- **Handles**: Standard `claude` binary, temporary `.claude-*` binaries, direct cli.js execution

### 6. Update Management
- **Functions**: `update_isolated_claude`, `update_claude_code`, `cleanup_old_claude_installations`
- **Location**: iclaude.sh:529-2389
- **Purpose**: Safely update Claude Code, handle temp artifacts
- **Key Features**:
  - Auto-cleanup `.claude-code-*` folders
  - Symlink recreation after updates
  - Lockfile auto-update
  - ENOTEMPTY error handling

### 7. OAuth Token Management
- **Functions**: `check_oauth_token`, `refresh_oauth_token`
- **Location**: iclaude.sh:2749-2874
- **Purpose**: Automatic token validation and refresh
- **Key Features**:
  - Checks expiration at every launch
  - Auto-refreshes within 7 days (configurable `TOKEN_REFRESH_THRESHOLD`)
  - Uses `claude setup-token` (~1 year tokens)
  - Preserves credentials file on failure
- **Token Structure**:
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

### 8. Router Management
- **Functions**: `detect_router`, `get_router_path`, `install_isolated_router`, `check_router_status`
- **Location**: iclaude.sh:324-379 (detection), 584-637 (install), 1333-1430 (status)
- **Purpose**: Integrate Claude Code Router for alternative LLM providers
- **Key Features**:
  - Opt-in via `--router` flag
  - Supports OpenRouter, DeepSeek, OpenAI, Ollama, Gemini, Volcengine, SiliconFlow
  - Environment variable substitution (`${VAR_NAME}`)
  - Lockfile integration
- **Configuration Files**:
  - `router.json.example` - Template (in git)
  - `router.json` - Team config with `${VAR}` placeholders (in git)
  - `~/.claude-code-router/config.json` - Runtime config (NOT in git)

### 9. Auto-update Management
- **Function**: `disable_auto_updates`
- **Location**: iclaude.sh:1982-2024
- **Purpose**: Auto-disable Claude Code CLI auto-updates
- **Key Features**:
  - Runs automatically on every launch
  - Sets `autoUpdates: false` in `.claude.json`
  - Works for isolated and shared configs
  - Idempotent (safe to run multiple times)
- **Why This Matters**:
  - Prevents Claude from self-updating
  - Ensures all machines use same version from git
  - Updates controlled via CI/CD

---

## Critical Functions

### `validate_proxy_url()` - line 56
- **Purpose**: Validate proxy URL format and protocol
- **Returns**: `0` (valid IP), `1` (invalid), `2` (valid but domain)
- **IMPORTANT**: Only HTTP/HTTPS supported (SOCKS5 crashes undici)

### `resolve_domain_to_ip()` - line 110
- **Purpose**: Resolve domain to IP using fallback chain
- **Fallback Order**: getent → host → dig → nslookup
- **Note**: Only for HTTP proxies (optional). HTTPS preserves domains for OAuth/TLS

### `get_nvm_claude_path()` - line 234
- **Purpose**: Locate Claude installation in NVM environment
- **Handles**: Standard binary, temporary `.claude-*` binaries, direct cli.js, temp `.claude-code-*` folders

### `repair_isolated_environment()` - line 812
- **Purpose**: Fix broken symlinks after `git clone`
- **Recreates**: npm/npx/corepack/claude symlinks with correct permissions

### `save_isolated_lockfile()` - line 616
- **Purpose**: Capture current versions to lockfile
- **Detects**: Node.js, Claude, Router, gh, LSP servers, LSP plugins
- **Critical for**: Reproducible deployments

### `detect_router()` - line 324
- **Purpose**: Check if Router is available (NOT if it should be used)
- **Returns**: `0` (available), `1` (missing)
- **Important**: Router activated ONLY with `--router` flag

### `get_router_path()` - line 355
- **Purpose**: Locate `ccr` binary
- **Priority**: Isolated environment → System PATH

### `install_isolated_router()` - line 584
- **Purpose**: Install Router npm package
- **Steps**: npm install → create router.json from example → show next steps

### `check_router_status()` - line 1333
- **Purpose**: Show router status (version, config, providers, default model)

### `disable_auto_updates()` - line 1982
- **Purpose**: Disable Claude CLI auto-updates
- **Automatic**: Runs on every launch
- **Atomic**: Uses temp file + mv for safety

---

## Environment Variables

```bash
# Proxy configuration
HTTPS_PROXY="https://user:pass@proxy:port"
HTTP_PROXY="https://user:pass@proxy:port"
NO_PROXY="localhost,127.0.0.1,github.com,..."

# TLS configuration (optional)
NODE_EXTRA_CA_CERTS="/path/to/proxy-cert.pem"
NODE_TLS_REJECT_UNAUTHORIZED=0  # Insecure mode (not recommended)

# Isolated environment
NVM_DIR="$SCRIPT_DIR/.nvm-isolated"
CLAUDE_DIR="$SCRIPT_DIR/.nvm-isolated/.claude-isolated"
PATH="$ISOLATED_NVM_DIR/npm-global/bin:$ISOLATED_NVM_DIR/versions/node/.../bin:$PATH"

# Claude Code features
CLAUDE_CODE_ENABLE_TASKS="true"  # Enable tasks system
```

---

## File Structure

```
.
├── iclaude.sh                          # Main wrapper script (3325 lines)
├── .claude_proxy_credentials           # Proxy credentials (chmod 600, NOT in git)
├── .nvm-isolated/                      # Isolated NVM environment (~278MB)
│   ├── nvm.sh                         # NVM installation script
│   ├── versions/node/v18.20.8/        # Node.js installation
│   │   ├── bin/                       # npm, npx, node, claude binaries
│   │   └── lib/node_modules/          # Global packages
│   ├── npm-global/                    # Global npm packages
│   └── .claude-isolated/              # Isolated Claude configuration
│       ├── history.jsonl
│       ├── session-env/
│       ├── .credentials.json
│       ├── settings.json
│       ├── skills/
│       └── projects/
└── .nvm-isolated-lockfile.json        # Version lockfile (in git)
```

### Files NOT in Git

- `.claude_proxy_credentials` - Sensitive credentials
- `.nvm-isolated/.cache/` - NPM cache
- `.nvm-isolated/.npm/` - NPM temp files
- `.nvm-isolated/.claude-isolated/*` - Session data (except skills/ and CLAUDE.md)

---

## Integration with Other Skills

### Input Dependencies

None (reference skill only)

### Output Consumers

Referenced by:
- `iclaude-validation` → Function locations for testing
- `iclaude-dev-tasks` → Component boundaries for refactoring
- `iclaude-best-practices` → Architecture constraints

### See Also

- `@skill:architecture-documentation` - Auto-generate architecture docs from code
- `@skill:iclaude-commands` - CLI command reference
- `@skill:iclaude-best-practices` - Development best practices

---

## Notes

- Component locations are approximate (code changes frequently)
- Always run `./iclaude.sh --check-isolated` to verify current state
- Use `grep -n "function_name" iclaude.sh` to find exact line numbers
- Symlinks break after `git clone` - run `--repair-isolated`
