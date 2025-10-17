# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a utility tool for launching Claude Code through HTTP/SOCKS5 proxies with automatic credential management. The project consists of a single bash script that can be installed globally.

## Architecture

The codebase is a standalone bash script (`init_claude.sh`) that:

1. **Credential Management**: Stores proxy credentials in `.claude_proxy_credentials` (chmod 600, git-ignored)
2. **Proxy Configuration**: Sets environment variables (HTTPS_PROXY, HTTP_PROXY, NO_PROXY) for Claude Code
3. **Git Proxy Management**: Automatically disables proxy for git operations while keeping it enabled for Claude Code
4. **Global Installation**: Creates symlink at `/usr/local/bin/init_claude` for system-wide access
5. **Proxy Detection**: Prioritizes global Claude Code installation over local installations

### Key Components

- **Proxy URL Parsing** (lines 66-103): Extracts protocol, username, password, host, port from URLs
- **Credential Persistence** (lines 166-203): Saves/loads proxy settings from `.claude_proxy_credentials`
- **Git Proxy Management** (lines 290-349): Automatically saves/restores git proxy settings
  - `save_git_proxy_settings()`: Backs up current git proxy config
  - `configure_git_no_proxy()`: Disables proxy for git operations
  - `restore_git_proxy()`: Restores original git proxy settings
- **Proxy Configuration** (lines 274-288): Sets environment variables and configures git
- **Proxy Testing** (lines 391-403): Validates connectivity via curl before launching
- **Dependency Installation** (lines 426-570): Auto-installs Node.js, npm, and Claude Code if missing
- **Claude Detection** (lines 597-643): Finds global Claude Code binary, avoiding local npm installations

## Common Commands

### Installation
```bash
# Install globally (creates /usr/local/bin/init_claude)
# Automatically checks and installs dependencies:
# - Node.js and npm (if missing)
# - Claude Code (if missing)
sudo ./init_claude.sh --install

# Uninstall
sudo init_claude --uninstall
```

### Usage
```bash
# Launch with saved credentials (interactive prompt if none exist)
init_claude

# Set proxy directly
init_claude --proxy http://user:pass@host:port

# Test proxy without launching Claude
init_claude --test

# Clear saved credentials
init_claude --clear

# Restore git proxy settings from backup
init_claude --restore-git-proxy

# Launch without proxy (also restores git proxy if backup exists)
init_claude --no-proxy

# Skip connectivity test
init_claude --no-test

# Pass arguments to Claude Code
init_claude -- --model claude-3-opus

# Skip permission checks (use with caution)
init_claude --dangerously-skip-permissions
```

## Development Notes

### Proxy URL Format
Supported formats: `http://`, `https://`, `socks5://`

Pattern: `protocol://[username:password@]host:port`

Examples:
- `http://alice:secret@127.0.0.1:8118`
- `socks5://user:pass@proxy.example.com:1080`

### Security Considerations

**General:**
- Credentials file has 600 permissions (owner read/write only)
- Passwords are masked in output by default (use `--show-password` to reveal)
- The credentials file is automatically excluded from git

**HTTPS Proxy Security:**

⚠️ **Important:** The `--proxy-insecure` flag disables TLS certificate verification for ALL Node.js connections, not just the proxy. This creates security risks:

**Current Issue with `--proxy-insecure`:**
```bash
# ⚠️  INSECURE (NOT RECOMMENDED)
init_claude --proxy https://proxy:8118 --proxy-insecure
```
- ❌ Proxy connection: No TLS verification (needed for self-signed cert)
- ❌ **Claude Code → Anthropic API: NO TLS VERIFICATION (DANGEROUS!)**
- ❌ Vulnerable to Man-in-the-Middle attacks on API connections

**Secure Solution with `--proxy-ca` (RECOMMENDED):**
```bash
# ✅ SECURE (RECOMMENDED)
init_claude --proxy https://proxy:8118 --proxy-ca /path/to/proxy-cert.pem
```
- ✅ Proxy connection: Uses proxy CA certificate
- ✅ **Claude Code → Anthropic API: FULL TLS VERIFICATION (SECURE)**
- ✅ Protected from Man-in-the-Middle attacks

**How to Export Proxy Certificate:**
```bash
# Get help
init_claude --help-export-cert

# Method 1: Using openssl
openssl s_client -showcerts -connect proxy.example.com:8118 < /dev/null 2>/dev/null | \
  openssl x509 -outform PEM > proxy-cert.pem

# Method 2: From browser (connect via proxy, view certificate, export as PEM)

# Then use it
init_claude --proxy https://user:pass@proxy.example.com:8118 --proxy-ca proxy-cert.pem
```

**Technical Details:**
- `--proxy-ca` uses `NODE_EXTRA_CA_CERTS` to add ONLY the proxy certificate to trusted CAs
- `--proxy-insecure` uses `NODE_TLS_REJECT_UNAUTHORIZED=0` which disables verification globally
- The script uses `curl --proxy-cacert` for testing when `--proxy-ca` is provided

### Script Behavior
- Uses `set -euo pipefail` for strict error handling
- Follows symlinks to resolve the script's actual directory
- **NVM Support**: Automatically detects and uses Claude Code installed via NVM
  - Searches for standard `claude` binary
  - Handles temporary npm binaries (`.claude-*`)
  - Falls back to direct `cli.js` execution if binaries not found
  - Supports temporary installation folders (`.claude-code-*`)
- Prioritizes NVM installations over system installations
- Warns if local Claude installation detected and attempts to find global installation

### Dependency Installation
During `--install`, the script automatically checks and installs missing dependencies:

1. **Node.js and npm** (if missing):
   - Uses NodeSource official repository (Node.js 18 LTS)
   - Command: `curl -fsSL https://deb.nodesource.com/setup_18.x | bash -`
   - Then: `apt-get install -y nodejs`
   - Prompts for confirmation before installing

2. **Claude Code** (if missing):
   - Installs globally via npm
   - Command: `npm install -g @anthropic-ai/claude-code`
   - Prompts for confirmation before installing

3. **Installation Flow**:
   - Checks npm → if missing, offers to install Node.js
   - Checks Claude Code → if missing, offers to install
   - Only proceeds with script installation if dependencies are satisfied
   - Can skip dependency installation but warns about missing requirements

### Git and Proxy Considerations

**Environment Variable Approach:**

The script uses **environment variables** (HTTPS_PROXY, HTTP_PROXY, NO_PROXY) to configure proxy settings. These variables:
- Only affect the current process and its child processes (like Claude Code)
- **Do NOT modify global git configuration**
- Git automatically respects NO_PROXY for localhost and 127.0.0.1

**How it works:**
1. When proxy is configured, the script:
   - Sets environment variables: HTTPS_PROXY, HTTP_PROXY, NO_PROXY
   - These variables are inherited by Claude Code when launched
   - Git automatically uses NO_PROXY to bypass proxy for local addresses

2. Git operations work normally:
   - Git respects the NO_PROXY environment variable
   - Local operations (localhost, 127.0.0.1) bypass proxy automatically
   - Remote operations use your existing git config (not modified by this script)

3. Claude Code uses the proxy:
   - Reads HTTPS_PROXY and HTTP_PROXY from environment
   - Uses proxy for API calls to Anthropic

**Important Notes:**
- The script does **NOT** modify `git config --global` settings
- Your system's git configuration remains unchanged
- Proxy settings only apply to the `init_claude` session and Claude Code

**Files:**
- `.claude_proxy_credentials` - Proxy credentials for Claude Code (chmod 600)
- `.claude_git_proxy_backup` - Deprecated (kept for compatibility)

### Updating Claude Code

**Check for updates:**
```bash
# Check if updates are available (no installation)
init_claude --check-update
```

**Update Claude Code:**
```bash
# Update to latest version
init_claude --update  # For NVM installations
sudo init_claude --update  # For system installations
```

**NVM-specific behavior:**
- Automatically detects and cleans up old temporary installations (`.claude-code-*`)
- Removes broken symlinks (`.claude-*`) before updating
- Removes incomplete installations (folders without `cli.js`)
- Verifies update success by checking for working `cli.js`

**Troubleshooting ENOTEMPTY errors:**

If you see `npm error ENOTEMPTY` during update:

1. **Automatic cleanup (recommended):**
   ```bash
   init_claude --update
   # The script will offer to clean up old installations automatically
   ```

2. **Manual cleanup:**
   ```bash
   # Remove old temporary installations
   rm -rf ~/.nvm/versions/node/*/lib/node_modules/@anthropic-ai/.claude-code-*

   # Remove broken symlinks
   find ~/.nvm/versions/node/*/bin -type l -name ".claude-*" ! -exec test -e {} \; -delete

   # Then update
   npm install -g @anthropic-ai/claude-code@latest
   ```

3. **Nuclear option (complete reinstall):**
   ```bash
   npm uninstall -g @anthropic-ai/claude-code
   npm install -g @anthropic-ai/claude-code@latest
   ```

**Note:** Updates are never automatic - they only happen when you explicitly run `--update` or `--check-update`.

### Testing
No automated tests exist. Test manually:
```bash
# Test proxy connectivity
init_claude --test

# Test full flow
init_claude --proxy http://test:test@127.0.0.1:8118 --no-test
```
