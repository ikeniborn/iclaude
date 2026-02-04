# iclaude-best-practices

Best practices, common pitfalls, and development guidelines for iclaude.sh: proxy protocols, security, OAuth, tasks system, symlink management, testing, and debugging.

## Quick Reference

| Aspect | Details |
|--------|---------|
| **Invocation** | Referenced during development (not auto-invoked) |
| **Purpose** | Prevent common mistakes and follow best practices |
| **Categories** | Proxy, Security, OAuth, Tasks, Symlinks, Testing, Debugging |
| **Format** | Practice → Rationale → Example → Alternatives |

---

## When to Use

Use this skill when:
- Planning implementation of new features
- Reviewing code for best practices
- Debugging common issues
- Writing documentation

**Manual reference only** (not auto-invoked)

---

## Proxy Protocol Support

### ✅ Recommended: HTTPS Proxy

**Why:**
- Preserves domain names (required for Anthropic OAuth token refresh)
- TLS Server Name Indication (SNI) works correctly
- Host header validated by OAuth

**Example:**
```bash
./iclaude.sh --proxy https://proxy.example.com:8118
# Domain preserved: https://proxy.example.com:8118
```

### ⚠️ Supported but not recommended: HTTP Proxy

**Why:**
- Script offers domain-to-IP conversion (optional)
- IP conversion improves reliability (avoids DNS lookup issues)
- BUT: Breaks OAuth if converted to IP

**Example:**
```bash
./iclaude.sh --proxy http://proxy.example.com:8118
# User choice: convert to http://192.168.1.100:8118 or keep domain
```

### ❌ NOT Supported: SOCKS5 Proxy

**Why:**
- Claude Code uses `undici` HTTP client
- undici does NOT support SOCKS5 protocol
- Attempting SOCKS5 causes crash:
  ```
  InvalidArgumentError: Invalid URL protocol: the URL must start with `http:` or `https:`
  ```

**Workaround:**
- Use Privoxy or Squid to convert SOCKS5 → HTTPS locally
- Then use HTTPS proxy URL with iclaude.sh

---

## HTTPS Proxy Security

### ⚠️ Known Vulnerability

**Issue:** `undici` ProxyAgent does NOT verify TLS certificates of target servers when proxying HTTPS traffic

**Reference:** [HackerOne #1583680](https://hackerone.com/reports/1583680)

**Implications:**
- Proxy server can intercept ALL HTTPS traffic (MitM)
- Only use TRUSTED proxy servers
- Prefer `--proxy-ca` over `--proxy-insecure`

### ✅ Secure Configuration

```bash
# Best: Use trusted proxy with CA certificate
./iclaude.sh --proxy https://proxy:8118 --proxy-ca /path/to/cert.pem

# Alternative: Trust system CA bundle
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# ❌ Avoid: Disable TLS verification (insecure)
./iclaude.sh --proxy https://proxy:8118 --proxy-insecure
```

---

## OAuth Token Refresh

### Automatic Refresh (at launch)

**How it works:**
1. Check token expiration at every `iclaude.sh` launch
2. If expires within 7 days → attempt automatic refresh
3. Uses `claude setup-token` to generate long-lived token (~1 year)

**Configuration:**
- `TOKEN_REFRESH_THRESHOLD` constant (default: 604800 = 7 days)
- Token stored in `.credentials.json` with `expiresAt` timestamp (milliseconds)

### Manual Refresh

```bash
./iclaude.sh --refresh-token
```

### Behavior on Failure

- Does NOT delete credentials file (preserves `refreshToken`)
- Shows warning and directs user to run `/login` manually
- Claude Code may still use `refreshToken` internally

### ⚠️ Known Limitation

- `setup-token` requires interactive browser authentication
- Not suitable for fully headless/CI environments
- Solution: Use long-lived tokens or manual `/login` in CI

---

## Tasks System

### Automatic Activation

- iclaude.sh exports `CLAUDE_CODE_ENABLE_TASKS=true` by default
- New tasks system activates automatically
- Available tools: `TaskCreate`, `TaskGet`, `TaskList`, `TaskUpdate`, `TaskOutput`

### Disable (temporary revert to old system)

```bash
CLAUDE_CODE_ENABLE_TASKS=false ./iclaude.sh
```

### Capabilities

- Create task lists for progress tracking
- Manage dependencies between tasks (blocks/blockedBy)
- Track background processes (bash shell, subagents)
- Share tasks between sessions (via `CLAUDE_CODE_TASK_LIST_ID`)

### ⚠️ Important Note

- `CLAUDE_CODE_TASK_LIST_ID` is process-specific
- Must be set manually for cross-session task sharing
- Not automatically shared between multiple Claude Code instances

**Source:** [claude-code/CHANGELOG.md](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)

---

## Symlink Management

### Why Symlinks Break

After `git clone`, symlinks in `.nvm-isolated/` break because:
- Git stores symlink targets as text (relative paths)
- After clone, Node.js version may differ
- Symlink targets point to wrong paths

### ✅ Fix Broken Symlinks

```bash
./iclaude.sh --repair-isolated
```

**What it recreates:**
```
.nvm-isolated/npm-global/bin/npm → ../../versions/node/v*/lib/node_modules/npm/bin/npm-cli.js
.nvm-isolated/npm-global/bin/npx → ../../versions/node/v*/lib/node_modules/npm/bin/npx-cli.js
.nvm-isolated/npm-global/bin/claude → ../../versions/node/v*/lib/node_modules/@anthropic-ai/claude-code/cli.js
```

### When to Run

- ✅ After `git clone`
- ✅ After switching branches
- ✅ After `--update` (automatic but verify)
- ✅ When `command not found: claude` error occurs

---

## Update Behavior

### Update Process

When running `--update`, the script:
1. Runs `npm update -g @anthropic-ai/claude-code`
2. Cleans up `.claude-code-*` temporary folders
3. Recreates symlinks
4. Updates lockfile
5. Retries on ENOTEMPTY errors

### ✅ Verify Lockfile Update

```bash
./iclaude.sh --check-isolated
# Verify: Claude Code version matches lockfile claudeCodeVersion
```

### ⚠️ Temporary Folders

- npm creates `.claude-code-*` folders during updates
- Script auto-deletes these after successful update
- If ENOTEMPTY error: retry with exponential backoff

---

## Configuration Modes

### Isolated Config (default for isolated installation)

- Config in `.nvm-isolated/.claude-isolated/`
- Separate history/sessions from system installation
- Enabled automatically when using isolated environment

### Shared Config (default for system installation)

- Config in `~/.claude/`
- Shared between all installations
- Can be forced with `--shared-config`

### Switch Between Modes

```bash
./iclaude.sh --isolated-config  # Use isolated config
./iclaude.sh --shared-config    # Use shared config
```

---

## Testing Proxy Configuration

### Before Launching Claude Code

```bash
# Test connection
./iclaude.sh --test

# Check what will be configured (show password for debugging)
./iclaude.sh --proxy https://proxy:8118 --test --show-password
```

### What the Test Performs

1. HTTP request to `http://www.google.com`
2. HTTPS request to `https://www.anthropic.com`
3. Validates response codes and content

### ✅ Expected Output

```
Testing proxy connection...
✅ HTTP proxy test: OK (status 200)
✅ HTTPS proxy test: OK (status 200)
Proxy configuration is working correctly.
```

### ❌ Common Failures

- `ECONNREFUSED`: Proxy not running or wrong port
- `ENOTFOUND`: Domain resolution failed
- `ETIMEDOUT`: Firewall blocking connection
- `TLS_ERROR`: Certificate issues (use `--proxy-ca`)

---

## Handling Domain Names in Proxy URLs

### HTTPS Proxies (recommended)

- Domain names are **PRESERVED** (NOT converted to IP)
- Required for OAuth token refresh and TLS (SNI, Host header)
- Converting to IP breaks Anthropic authentication

```bash
# Input: https://proxy.example.com:8118
# Saved as: https://proxy.example.com:8118  (domain preserved!)
```

### HTTP Proxies (not recommended)

- Script offers to convert domain to IP (optional)
- IP conversion improves reliability (avoids DNS lookup issues)

```bash
# Input: http://proxy.example.com:8118
# User choice: convert to http://192.168.1.100:8118 or keep domain
```

### Why This Matters for HTTPS

- Anthropic OAuth validates the Host header during token refresh
- TLS Server Name Indication (SNI) requires the actual domain name
- Using IP instead of domain causes authentication failures

---

## Common Development Tasks

### Adding New Command-Line Options

1. Add option parsing in `main()` (iclaude.sh:~3020)
2. Add flag variable initialization (top of main)
3. Add to `show_usage()` help text (iclaude.sh:~2835)
4. Implement functionality in appropriate function

### Modifying Proxy Validation

- Edit `validate_proxy_url()` (iclaude.sh:56)
- Edit `parse_proxy_url()` (iclaude.sh:155)
- ⚠️ Be careful: Changes may affect saved credentials format

### Adding New Environment Variables

- Add configuration in `configure_proxy_from_url()` (iclaude.sh:1545)
- OR add in `setup_isolated_nvm()` (iclaude.sh:361)

---

## Debugging Tips

### Enable Bash Debug Mode

```bash
bash -x ./iclaude.sh --test
```

### Check Which Claude Binary Will Be Used

```bash
bash -c 'source ./iclaude.sh && get_nvm_claude_path'
```

### Verify Environment Setup

```bash
bash -c 'source ./iclaude.sh && setup_isolated_nvm && env | grep -E "(NVM|CLAUDE|PROXY)"'
```

### Check Lockfile Consistency

```bash
./iclaude.sh --check-isolated
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `command not found: claude` | Broken symlinks | `--repair-isolated` |
| `ENOTEMPTY` during update | NPM cleanup race condition | Wait 5s, retry |
| `OAuth token expired` | Token not refreshed | `--refresh-token` or `/login` |
| `Proxy connection failed` | Wrong URL or credentials | `--test --show-password` |
| `SOCKS5 protocol error` | Unsupported protocol | Use HTTPS proxy or Privoxy |

---

## Integration with Claude Code Skills

When developing iclaude.sh:

- Use `structured-planning` for breaking down complex features
- Use `bash-development` for refactoring bash functions (if exists)
- Use `git-workflow` for commit message generation
- Use `validation-framework` for testing new features

See README.md for full Skills documentation.

---

## LSP Integration

The `lsp-integration` skill provides automatic LSP plugin setup for bash development.

### For Bash Development

- **Language Server**: bash-language-server (bashls)
- **Linter**: shellcheck (integrated)
- **Features**: Syntax checking, variable validation, best practices

### Installation

```bash
# Install bash-language-server
npm install -g bash-language-server

# Install shellcheck (linter)
# macOS: brew install shellcheck
# Linux: apt-get install shellcheck
```

### Benefits

- **Syntax errors**: Caught before runtime
- **Unquoted variables**: SC2086 detection
- **Exit code checks**: SC2181 detection
- **Best practices**: SC-series warnings

---

## Chrome Integration

**Chrome integration is ENABLED BY DEFAULT** when launching via iclaude.sh.

### Disable Chrome Integration

```bash
./iclaude.sh --no-chrome
```

### Requirements

- Google Chrome browser installed and running
- Claude in Chrome extension v1.0.36+
- Claude Code CLI v2.0.73+
- Paid Claude plan (Pro/Team/Enterprise)

### Capabilities

- Navigate pages and open tabs
- Click elements and input text
- Fill forms
- Read console logs and network requests
- Record GIF of interactions

### ⚠️ Note

- Chrome integration increases context usage
- Use `--no-chrome` if you don't need browser automation

---

## Security Considerations

1. **Credential Storage**: `.claude_proxy_credentials` uses chmod 600 (owner-only)
2. **Git Exclusion**: Credentials NEVER committed to git (see .gitignore)
3. **Password Display**: Hidden by default, use `--show-password` to debug
4. **HTTPS Proxy**: Prefer `--proxy-ca` over `--proxy-insecure`
5. **Proxy Trust**: Only use TRUSTED proxy servers (MitM risk)

---

## Notes

- Always test with `--test` before committing proxy changes
- Run `--check-isolated` to verify lockfile consistency
- Update CLAUDE.md function locations after refactoring
- Use shellcheck before committing bash changes
- Test on both macOS and Linux for portability
