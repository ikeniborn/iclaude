# Debugging Tips & Common Issues

## Debugging Commands

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

## Common Issues & Solutions

### Issue 1: `command not found: claude`

**Cause:** Broken symlinks
**Solution:**
```bash
./iclaude.sh --repair-isolated
```

### Issue 2: `ENOTEMPTY` During Update

**Cause:** NPM cleanup race condition
**Solution:**
```bash
# Wait 5 seconds and retry
sleep 5 && ./iclaude.sh --update

# Or manually delete temp folders
rm -rf .nvm-isolated/versions/node/*/lib/node_modules/.claude-code-*
./iclaude.sh --update
```

### Issue 3: `OAuth Token Expired`

**Cause:** Token not refreshed
**Solution:**
```bash
# Automatic: within 7 days threshold
./iclaude.sh  # Auto-refreshes if needed

# Manual: any time
./iclaude.sh --refresh-token

# Fallback: use /login in Claude Code
./iclaude.sh
# Then run: /login
```

### Issue 4: `Proxy Connection Failed`

**Cause:** Wrong URL or credentials
**Solution:**
```bash
# Test proxy with visible credentials
./iclaude.sh --test --show-password

# Check proxy is running
curl -x http://proxy:8118 http://www.google.com

# Try different proxy
./iclaude.sh --proxy http://localhost:3128 --test
```

### Issue 5: `SOCKS5 Protocol Error`

**Cause:** Unsupported protocol
**Solution:**
- Use HTTPS proxy OR
- Use Privoxy to convert SOCKS5 → HTTPS:
  ```bash
  # Install Privoxy
  sudo apt-get install privoxy

  # Configure to forward to SOCKS5
  echo "forward-socks5 / localhost:1080 ." >> /etc/privoxy/config

  # Use Privoxy
  ./iclaude.sh --proxy http://localhost:8118
  ```

### Issue 6: Symlinks Broken After Update

**Cause:** Update didn't recreate symlinks
**Solution:**
```bash
./iclaude.sh --repair-isolated
```

### Issue 7: Lockfile Outdated After Manual npm Update

**Cause:** Updated Claude via npm directly, lockfile not updated
**Solution:**
```bash
# Lockfile auto-updates on next check
./iclaude.sh --check-isolated

# Or trigger update manually
./iclaude.sh --update  # Even if already latest
```

### Issue 8: Router Installation Fails

**Cause:** npm permission error or network issue
**Solution:**
```bash
# Check npm prefix
npm config get prefix
# Should be: /path/to/iclaude/.nvm-isolated/npm-global

# Retry installation
./iclaude.sh --install-router

# Manual installation (if needed)
npm install -g @musistudio/claude-code-router
```

## Testing Best Practices

### Before Committing

```bash
# 1. Validate syntax
bash -n iclaude.sh

# 2. Test proxy
./iclaude.sh --test

# 3. Check environment
./iclaude.sh --check-isolated

# 4. Run shellcheck (if available)
shellcheck -x iclaude.sh
```

### After Git Clone

```bash
# 1. Repair symlinks
./iclaude.sh --repair-isolated

# 2. Restore from lockfile (if needed)
./iclaude.sh --install-from-lockfile

# 3. Verify setup
./iclaude.sh --check-isolated
```

### Before Pushing Changes

```bash
# 1. Verify lockfile updated
git diff .nvm-isolated-lockfile.json

# 2. Update CLAUDE.md (if function locations changed)
grep -n "function_name" iclaude.sh  # Get actual line numbers

# 3. Test on clean environment (optional)
docker run -it ubuntu:22.04 bash
# Clone repo, test install-from-lockfile
```

## Chrome Integration Debugging

### Chrome Integration Disabled by Default?

**Check:**
```bash
# Chrome is enabled by default
./iclaude.sh  # Chrome included

# To disable:
./iclaude.sh --no-chrome
```

### Requirements

- Google Chrome browser installed and running
- Claude in Chrome extension v1.0.36+
- Claude Code CLI v2.0.73+
- Paid Claude plan (Pro/Team/Enterprise)

### ⚠️ Note

Chrome integration increases context usage. Use `--no-chrome` if you don't need browser automation.

## LSP Integration Debugging

### Check LSP Server Status

```bash
./iclaude.sh --check-lsp
```

### Install Missing LSP Servers

```bash
# Python
npm install -g pyright

# TypeScript
npm install -g @vtsls/language-server

# Go
go install golang.org/x/tools/gopls@latest

# Rust (via rustup)
rustup component add rust-analyzer
```

### Common LSP Issues

**Issue:** LSP plugin installed but server binary missing
**Solution:** Install server binary (see above)

**Issue:** LSP diagnostics not showing
**Solution:** Check plugin is active: `/plugin list`

## Troubleshooting Workflow

### Step 1: Identify Issue Category

- **Installation:** `--install-from-lockfile` or `--isolated-install`
- **Symlinks:** `--repair-isolated`
- **Proxy:** `--test --show-password`
- **OAuth:** `--refresh-token`
- **Update:** Clean and retry

### Step 2: Check Logs

```bash
# Enable debug mode
bash -x ./iclaude.sh <command> 2>&1 | tee debug.log

# Check for errors
grep -i "error\|fail\|warn" debug.log
```

### Step 3: Verify Environment

```bash
# Check versions
./iclaude.sh --check-isolated

# Check config mode
./iclaude.sh --check-config

# Check router (if using)
./iclaude.sh --check-router
```

### Step 4: Clean and Reinstall (if needed)

```bash
# 1. Backup credentials
cp .claude_proxy_credentials /tmp/

# 2. Clean up
./iclaude.sh --cleanup-isolated

# 3. Reinstall from lockfile
./iclaude.sh --install-from-lockfile

# 4. Restore credentials
cp /tmp/.claude_proxy_credentials .
```

## Best Practices Summary

**DO:**
- ✅ Test with `--test` before committing proxy changes
- ✅ Run `--repair-isolated` after `git clone`
- ✅ Check status with `--check-isolated` before updates
- ✅ Update CLAUDE.md after function location changes
- ✅ Use shellcheck for bash validation

**DON'T:**
- ❌ Manually edit `.nvm-isolated/` files
- ❌ Use SOCKS5 proxy (not supported)
- ❌ Commit `.claude_proxy_credentials` to git
- ❌ Skip `--test` after proxy changes
- ❌ Ignore shellcheck warnings (SC2086, SC2155 are critical)
