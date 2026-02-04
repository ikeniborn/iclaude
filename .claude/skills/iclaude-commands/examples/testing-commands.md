# Testing & Validation Commands

## Overview

Commands for testing proxy configuration, checking environment status, and validating script syntax.

## Commands Table

| Command | Purpose | Example | Output |
|---------|---------|---------|--------|
| `--test` | Test proxy without launching Claude | `./iclaude.sh --test` | HTTP + HTTPS connection test |
| `--test --show-password` | Test with visible credentials | `./iclaude.sh --test --show-password` | Shows proxy URL with password |
| `--check-isolated` | Show isolated environment status | `./iclaude.sh --check-isolated` | Versions, symlinks, lockfile |
| `--check-config` | Show configuration mode | `./iclaude.sh --check-config` | Isolated vs shared config |
| `--check-router` | Show router status | `./iclaude.sh --check-router` | Router version, config, providers |
| `--check-lsp` | Show LSP server status | `./iclaude.sh --check-lsp` | Installed LSP servers |
| `--sandbox-check` | Check sandbox availability | `./iclaude.sh --sandbox-check` | Docker/bubblewrap status |
| `--refresh-token` | Manually refresh OAuth token | `./iclaude.sh --refresh-token` | Launches `claude setup-token` |
| `bash -n` | Validate bash syntax | `bash -n iclaude.sh` | Syntax errors (if any) |

## Detailed Examples

### Test Proxy Configuration

```bash
# Test with saved credentials
./iclaude.sh --test

# Test with new proxy URL
./iclaude.sh --proxy https://proxy:8118 --test

# Test and show password (for debugging)
./iclaude.sh --test --show-password
```

**Expected Output:**
```
Testing proxy connection...
✅ HTTP proxy test: OK (status 200)
✅ HTTPS proxy test: OK (status 200)
Proxy configuration is working correctly.
```

**Common Errors:**
- `ECONNREFUSED`: Proxy not running
- `ENOTFOUND`: Domain resolution failed
- `ETIMEDOUT`: Firewall blocking
- `TLS_ERROR`: Certificate issues (use `--proxy-ca`)

### Check Isolated Environment

```bash
./iclaude.sh --check-isolated
```

**Expected Output:**
```
=== Isolated Environment Status ===

Node.js: v18.20.8
Claude Code: 2.1.15
Router: 1.2.3 (installed)
gh CLI: 2.45.0

Symlinks:
✅ npm → versions/node/v18.20.8/lib/node_modules/npm/bin/npm-cli.js
✅ npx → versions/node/v18.20.8/lib/node_modules/npm/bin/npx-cli.js
✅ claude → versions/node/v18.20.8/lib/node_modules/@anthropic-ai/claude-code/cli.js

Lockfile: .nvm-isolated-lockfile.json
  Node: 18.20.8 ✅
  Claude: 2.1.15 ✅
  Installed: 2026-01-14T10:39:51Z
```

### Check Configuration Mode

```bash
./iclaude.sh --check-config
```

**Output:**
```
Configuration Mode: Isolated
Config Directory: /path/to/iclaude/.nvm-isolated/.claude-isolated
History: history.jsonl (isolated)
Sessions: session-env/ (isolated)
Credentials: .credentials.json (isolated)
```

### Validate Bash Syntax

```bash
bash -n iclaude.sh
```

**No output = success**
**Errors example:**
```
iclaude.sh: line 1234: syntax error near unexpected token `fi'
```

## Integration with Validation Loop

These commands are used in **PHASE 4 (Integration Tests)** of validation loop:

```bash
# After implementing feature:
bash -n iclaude.sh                # PHASE 1: Syntax
./iclaude.sh --test               # PHASE 4: Integration
./iclaude.sh --check-isolated     # PHASE 4: Verify status
```

## Troubleshooting

### Test Fails with ECONNREFUSED

**Problem:** Proxy not running or wrong port
**Solution:**
```bash
# Check proxy is running
curl -x http://proxy:8118 http://www.google.com

# Try different proxy
./iclaude.sh --proxy http://localhost:3128 --test
```

### Check-Isolated Shows Wrong Version

**Problem:** Symlinks broken or lockfile outdated
**Solution:**
```bash
# Repair symlinks
./iclaude.sh --repair-isolated

# Update lockfile
./iclaude.sh --check-isolated  # Auto-updates if needed
```

### Refresh-Token Fails

**Problem:** OAuth error or browser not opening
**Solution:**
```bash
# Check .credentials.json exists
ls -la .nvm-isolated/.claude-isolated/.credentials.json

# Try manual /login in Claude Code
./iclaude.sh
# Then run: /login
```
