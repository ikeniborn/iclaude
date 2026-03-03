---
name: iclaude-architecture
version: 1.0.0
description: Code architecture reference for iclaude.sh (9 components + critical functions)
user-invocable: false
dependencies: []
tags: [reference, iclaude, architecture, bash]
files:
  - path: SKILL.md
    type: markdown
  - path: examples/components-overview.md
    type: markdown
  - path: examples/critical-functions.md
    type: markdown
---

# iclaude-architecture

Reference guide for iclaude.sh code architecture: 9 main components, critical functions, and file structure.

## When to Use

Use this skill when:
- Planning where to add new functionality
- Understanding existing component boundaries
- Debugging function interactions
- Reviewing code architecture

**Manual reference only** (not auto-invoked)

## Main Components Overview

### 1. Proxy Management (lines 1343-1666)
Domain-to-IP resolution, credential storage, environment configuration.
**Functions:** `save_credentials`, `load_credentials`, `configure_proxy_from_url`

### 2. Isolated Environment (lines 361-978)
Manage portable NVM+Node.js+Claude in `.nvm-isolated/`.
**Functions:** `setup_isolated_nvm`, `install_isolated_nvm`, `repair_isolated_environment`

### 3. Version Management (lines 616-768)
Track exact versions via lockfile for reproducibility.
**Functions:** `save_isolated_lockfile`, `install_from_lockfile`, `update_isolated_claude`

### 4. Configuration Isolation (lines 1099-1341)
Separate Claude Code state (isolated vs system).
**Functions:** `setup_isolated_config`, `check_config_status`, `export_config`, `import_config`

### 5. NVM Detection (lines 200-318)
Find Claude binary in various installation modes.
**Functions:** `detect_nvm`, `get_nvm_claude_path`

### 6. Update Management (lines 529-2389)
Safely update Claude Code, handle temporary artifacts.
**Functions:** `update_isolated_claude`, `update_claude_code`, `cleanup_old_claude_installations`

### 7. OAuth Token Management (lines 2749-2874)
Automatic token validation and refresh.
**Functions:** `check_oauth_token`, `refresh_oauth_token`

### 8. Router Management (lines 324-379, 584-637, 1333-1430)
Integrate Claude Code Router for alternative LLM providers.
**Functions:** `detect_router`, `get_router_path`, `install_isolated_router`, `check_router_status`

### 9. Auto-update Management (lines 1982-2024)
Auto-disable Claude Code CLI auto-updates for CI/CD.
**Function:** `disable_auto_updates`

### 10. PII Proxy Management (lib/pii-proxy/)
Intercept and mask PII/secrets in 100% of Anthropic API traffic via Python HTTP proxy.
**Functions:** `install_isolated_pii_proxy`, `detect_pii_proxy`, `check_pii_proxy_status`, `start_pii_proxy_server`, `stop_pii_proxy_server`
**Install:** Idempotent — skips venv/packages/spaCy model/script if already up to date; `--force` flag for full reinstall.

**См. подробнее:** `examples/components-overview.md`

## Critical Functions Quick Reference

| Function | Line | Purpose | Returns |
|----------|------|---------|---------|
| `validate_proxy_url()` | 56 | Validate proxy URL format | 0/1/2 |
| `resolve_domain_to_ip()` | 110 | Resolve domain to IP | IP or empty |
| `get_nvm_claude_path()` | 234 | Locate Claude binary | Path or empty |
| `repair_isolated_environment()` | 812 | Fix broken symlinks | 0 on success |
| `save_isolated_lockfile()` | 616 | Capture versions to lockfile | None |
| `detect_router()` | 324 | Check router availability | 0/1 |
| `disable_auto_updates()` | 1982 | Disable CLI auto-updates | 0/1 |

**См. подробнее:** `examples/critical-functions.md`

## File Structure

```
.
├── iclaude.sh                    # Main script (3325 lines)
├── .claude_proxy_credentials     # Proxy credentials (NOT in git)
├── .nvm-isolated/                # Isolated environment (~278MB)
│   ├── versions/node/v18.20.8/   # Node.js + npm + Claude
│   ├── npm-global/               # Global packages
│   └── .claude-isolated/         # Isolated Claude config
├── .nvm-isolated-lockfile.json   # Version lockfile (in git)
└── .claude/skills/               # Project-specific skills
```

## Integration

**Input:** None (reference skill)
**Output:** Architecture information, function locations

**Consumers:**
- iclaude-validation → Function locations for testing
- iclaude-best-practices → Architecture constraints
- iclaude-dev-tasks → Component boundaries for refactoring

## Examples

- **Components overview:** `examples/components-overview.md` - Detailed description of 9 components
- **Critical functions:** `examples/critical-functions.md` - Function signatures, parameters, usage

## Notes

- Component locations are approximate (code changes frequently)
- Always run `./iclaude.sh --check-isolated` to verify current state
- Use `grep -n "function_name" iclaude.sh` to find exact line numbers
- Symlinks break after `git clone` - run `--repair-isolated`
