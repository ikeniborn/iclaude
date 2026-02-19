# Example: Debugging Common Issues

This example demonstrates systematic debugging approaches for common iclaude.sh issues.

## Debugging Workflows

### Scenario 1: Proxy Connection Fails

**Symptom**: Claude Code fails to connect through proxy, shows network errors.

#### Step 1: Verify Proxy Connectivity

```bash
# Test proxy without Claude Code
./iclaude.sh --test
```

**Expected output**:
```
Testing proxy configuration...
Proxy credentials loaded from .claude_proxy_credentials
Testing HTTP connection...
HTTP test successful
Testing HTTPS connection...
HTTPS test successful
Proxy configuration is working correctly
```

**If test fails**:
```bash
# Show proxy password to verify credentials
./iclaude.sh --test --show-password
```

#### Step 2: Check Environment Variables

```bash
# Verify proxy environment variables are set
bash -c 'source iclaude.sh && load_credentials && env | grep -E "PROXY|proxy"'
```

**Expected output**:
```
HTTPS_PROXY=https://user:pass@192.168.1.100:8118
HTTP_PROXY=https://user:pass@192.168.1.100:8118
NO_PROXY=localhost,127.0.0.1,github.com,...
```

#### Step 3: Test Proxy Directly

```bash
# Test with curl
curl -x https://192.168.1.100:8118 https://www.anthropic.com

# Test with Node.js (same as Claude Code)
node -e "
const https = require('https');
const ProxyAgent = require('undici').ProxyAgent;

const proxy = new ProxyAgent('https://192.168.1.100:8118');
https.get('https://www.anthropic.com', { agent: proxy }, (res) => {
    console.log('Status:', res.statusCode);
    process.exit(0);
}).on('error', (err) => {
    console.error('Error:', err.message);
    process.exit(1);
});
"
```

#### Step 4: Check Credential File

```bash
# Verify credential file format
cat .claude_proxy_credentials

# Check file permissions (should be 600)
ls -l .claude_proxy_credentials
```

**Expected**:
```
-rw------- 1 user user 45 Feb 12 10:30 .claude_proxy_credentials
```

#### Step 5: Enable Debug Logging

```bash
# Launch with bash debug mode
bash -x ./iclaude.sh 2>&1 | grep -E "(proxy|PROXY)"
```

**Debug checklist**:
- [ ] Credentials file exists and is readable
- [ ] Proxy URL format is valid (HTTP/HTTPS only)
- [ ] Environment variables are exported
- [ ] Direct proxy test succeeds
- [ ] NO_PROXY doesn't block target domains

---

### Scenario 2: Symlinks Broken After Git Clone

**Symptom**: `./iclaude.sh` shows "claude: command not found" or fails to launch.

#### Step 1: Check Symlink Status

```bash
# List symlinks in isolated environment
ls -la .nvm-isolated/npm-global/bin/
```

**Broken symlinks show in red** (or with `->` pointing to non-existent target):
```
lrwxrwxrwx 1 user user 50 Feb 12 10:30 claude -> ../../versions/node/v18.20.8/lib/node_modules/@anthropic-ai/claude-code/cli.js
lrwxrwxrwx 1 user user 50 Feb 12 10:30 npm -> ../../versions/node/v18.20.8/lib/node_modules/npm/bin/npm-cli.js
```

#### Step 2: Verify Symlink Targets

```bash
# Check if target files exist
ls -l .nvm-isolated/versions/node/v*/lib/node_modules/@anthropic-ai/claude-code/cli.js
ls -l .nvm-isolated/versions/node/v*/lib/node_modules/npm/bin/npm-cli.js
```

#### Step 3: Repair Symlinks

```bash
# Auto-repair broken symlinks
./iclaude.sh --repair-isolated
```

**Expected output**:
```
Repairing isolated environment symlinks...
Creating npm symlink...
Creating npx symlink...
Creating corepack symlink...
Creating claude symlink...
Symlinks repaired successfully
```

#### Step 4: Verify Repair

```bash
# Test Claude Code binary
.nvm-isolated/npm-global/bin/claude --version

# Test npm binary
.nvm-isolated/npm-global/bin/npm --version
```

#### Step 5: Check Isolated Environment Status

```bash
./iclaude.sh --check-isolated
```

**Expected output**:
```
Isolated Environment Status:
Node.js version: v18.20.8
npm version: 10.9.2
Claude Code version: 2.1.15
Lockfile version: 2.1.15
Status: Versions match lockfile
```

**Debug checklist**:
- [ ] Symlinks exist in `.nvm-isolated/npm-global/bin/`
- [ ] Symlink targets exist in `node_modules/`
- [ ] Symlinks are executable (`chmod +x`)
- [ ] `--repair-isolated` completes without errors
- [ ] `--check-isolated` shows matching versions

---

### Scenario 3: OAuth Token Expired

**Symptom**: Claude Code shows "Authentication failed" or "Token expired" error.

#### Step 1: Check Token Expiration

```bash
# Read expiration timestamp from credentials file
jq -r '.claudeAiOauth.expiresAt' .nvm-isolated/.claude-isolated/.credentials.json
```

**Convert timestamp to human-readable**:
```bash
# On Linux
date -d @$(( $(jq -r '.claudeAiOauth.expiresAt' .nvm-isolated/.claude-isolated/.credentials.json) / 1000 ))

# On macOS
date -r $(( $(jq -r '.claudeAiOauth.expiresAt' .nvm-isolated/.claude-isolated/.credentials.json) / 1000 ))
```

**Example output**:
```
Sun Feb 23 14:30:15 PST 2026
```

#### Step 2: Check Current Time

```bash
# Compare with current time
date
```

**If current time > expiration time**, token is expired.

#### Step 3: Attempt Automatic Refresh

```bash
# Refresh token automatically
./iclaude.sh --refresh-token
```

**Expected output**:
```
Checking OAuth token expiration...
Token expires at: 2026-02-23 14:30:15
Token expires in 6 days
Attempting automatic token refresh...
Token refreshed successfully
```

#### Step 4: Manual Refresh (if automatic fails)

```bash
# Launch Claude Code and run /login
./iclaude.sh

# Inside Claude Code session:
# Type: /login
# Follow browser authentication flow
```

#### Step 5: Verify New Token

```bash
# Check new expiration
jq -r '.claudeAiOauth.expiresAt' .nvm-isolated/.claude-isolated/.credentials.json

# Convert to date
date -d @$(( $(jq -r '.claudeAiOauth.expiresAt' .nvm-isolated/.claude-isolated/.credentials.json) / 1000 ))
```

**Debug checklist**:
- [ ] Credentials file exists (`.nvm-isolated/.claude-isolated/.credentials.json`)
- [ ] `expiresAt` field is present and valid
- [ ] Token expiration is in the past
- [ ] `--refresh-token` completes successfully
- [ ] New `expiresAt` is ~1 year in future

---

### Scenario 4: Version Mismatch in Lockfile

**Symptom**: `--check-isolated` shows "Version mismatch" warning.

#### Step 1: Check Lockfile vs Installed Versions

```bash
./iclaude.sh --check-isolated
```

**Example output showing mismatch**:
```
Isolated Environment Status:
Node.js version: v18.20.8
npm version: 10.9.2
Claude Code version: 2.1.16  <-- Installed
Lockfile version: 2.1.15     <-- Lockfile
Warning: Installed version does not match lockfile
```

#### Step 2: Determine Cause

**Possible causes**:
1. Manual `npm update` without lockfile update
2. `--update` flag didn't update lockfile
3. Git pull with different lockfile

```bash
# Check git status
git status .nvm-isolated-lockfile.json

# Check recent lockfile changes
git log --oneline -5 -- .nvm-isolated-lockfile.json
```

#### Step 3: Update Lockfile

```bash
# Auto-update lockfile to match installed versions
# (This happens automatically, but can be forced)
./iclaude.sh --check-isolated

# Verify lockfile updated
git diff .nvm-isolated-lockfile.json
```

#### Step 4: Or Reinstall from Lockfile

```bash
# Revert to lockfile versions (exact reproducibility)
./iclaude.sh --install-from-lockfile
```

**Expected output**:
```
Installing from lockfile...
Node.js version: 18.20.8
Claude Code version: 2.1.15
Router version: not installed
Installing Node.js v18.20.8...
Installing Claude Code v2.1.15...
Installation from lockfile complete
```

#### Step 5: Verify Consistency

```bash
./iclaude.sh --check-isolated
```

**Expected**:
```
Status: Versions match lockfile ✓
```

**Debug checklist**:
- [ ] `--check-isolated` shows version mismatch
- [ ] Git status shows no unexpected lockfile changes
- [ ] Lockfile updated or installation reverted
- [ ] Versions now match after fix

---

### Scenario 5: Router Not Detected

**Symptom**: `./iclaude.sh --router` shows "Router not available" error.

#### Step 1: Check Router Status

```bash
./iclaude.sh --check-router
```

**Expected output (if not installed)**:
```
Router Status:
Installation: not installed
Configuration: router.json not found
Configured providers: N/A

To install router:
  ./iclaude.sh --install-router
```

#### Step 2: Verify Router Components

```bash
# Check if ccr binary exists
ls -l .nvm-isolated/npm-global/bin/ccr

# Check if router.json exists
ls -l .nvm-isolated/.claude-isolated/router.json
```

**Two cases**:
- Binary missing: Install router with `--install-router`
- Config missing: Copy `router.json.example` to `router.json`

#### Step 3: Install Router

```bash
# Install Claude Code Router
./iclaude.sh --install-router
```

**Expected output**:
```
Installing Claude Code Router...
Router installed successfully
Creating router.json from router.json.example...

Next steps:
1. Edit router.json with your provider configuration
2. Export API keys: export DEEPSEEK_API_KEY=...
3. Launch with --router flag: ./iclaude.sh --router
```

#### Step 4: Configure Router

```bash
# Edit router configuration
nano .nvm-isolated/.claude-isolated/router.json

# Verify JSON syntax
jq '.' .nvm-isolated/.claude-isolated/router.json
```

**Minimal config**:
```json
{
  "providers": {
    "deepseek": {
      "apiKey": "${DEEPSEEK_API_KEY}"
    }
  },
  "defaultProvider": "deepseek",
  "defaultModel": "deepseek-chat"
}
```

#### Step 5: Export API Keys

```bash
# Export provider API key
export DEEPSEEK_API_KEY="your-api-key-here"

# Verify environment variable
echo $DEEPSEEK_API_KEY
```

#### Step 6: Test Router Launch

```bash
./iclaude.sh --router --check-router
```

**Expected output**:
```
Router Status:
Installation: installed
Router version: 1.2.3
Configuration: /path/to/.nvm-isolated/.claude-isolated/router.json
Configured providers: deepseek
Default model: deepseek-chat
Status: Router will be activated on next launch
```

#### Step 7: Launch with Router

```bash
./iclaude.sh --router
```

**Debug checklist**:
- [ ] `ccr` binary exists and is executable
- [ ] `router.json` exists and has valid JSON
- [ ] API keys exported as environment variables
- [ ] `--check-router` shows router available
- [ ] Launch with `--router` succeeds

---

## General Debugging Tips

### Enable Bash Debug Mode

```bash
# Full trace of script execution
bash -x ./iclaude.sh --test 2>&1 | less

# Filter for specific patterns
bash -x ./iclaude.sh --test 2>&1 | grep -E "(proxy|claude)"
```

### Check Function Output

```bash
# Source script and test individual functions
bash -c '
source iclaude.sh
get_nvm_claude_path
'
```

### Verify Environment Setup

```bash
# Check all relevant environment variables
bash -c 'source iclaude.sh && setup_isolated_nvm && env | grep -E "(NVM|CLAUDE|PROXY|NODE)"'
```

### Inspect Lockfile

```bash
# Pretty-print lockfile
jq '.' .nvm-isolated-lockfile.json

# Check specific version
jq -r '.claudeCodeVersion' .nvm-isolated-lockfile.json
```

### Test Without Isolated Environment

```bash
# Use system installation for comparison
./iclaude.sh --system --no-proxy
```

### Check Recent Changes

```bash
# Compare with last working commit
git diff HEAD~1 iclaude.sh

# Show recent changes to script
git log --oneline -10 -- iclaude.sh
```

## Debugging Checklist

Use this systematic approach for any issue:

1. **Reproduce**: Confirm issue is reproducible
2. **Isolate**: Determine which component is failing
3. **Validate**: Check assumptions (file exists, permissions correct, etc.)
4. **Test incrementally**: Test each step separately
5. **Check logs**: Review error messages carefully
6. **Compare**: Test working vs non-working configurations
7. **Document**: Record findings for future reference

## Common Error Messages

### "Command not found: claude"

**Cause**: Symlinks broken or PATH not set

**Fix**:
```bash
./iclaude.sh --repair-isolated
```

### "Invalid URL protocol"

**Cause**: SOCKS5 proxy used (not supported)

**Fix**: Use HTTP or HTTPS proxy instead

### "Permission denied"

**Cause**: Credential file permissions too open

**Fix**:
```bash
chmod 600 .claude_proxy_credentials
```

### "ENOTEMPTY: directory not empty"

**Cause**: npm trying to remove `.claude-code-*` folder during update

**Fix**: Script auto-retries, or manually remove:
```bash
rm -rf .nvm-isolated/versions/node/v*/lib/node_modules/.claude-code-*
./iclaude.sh --update
```

### "Token expired"

**Cause**: OAuth token past expiration date

**Fix**:
```bash
./iclaude.sh --refresh-token
```

### "Router not available"

**Cause**: `router.json` or `ccr` binary missing

**Fix**:
```bash
./iclaude.sh --install-router
```

## Performance Debugging

### Measure Startup Time

```bash
# Time isolated mode startup
time ./iclaude.sh --no-proxy -- exit

# Time system mode startup
time ./iclaude.sh --system --no-proxy -- exit

# Compare
echo "Isolated mode:"
time ./iclaude.sh --no-proxy -- exit
echo "System mode:"
time ./iclaude.sh --system --no-proxy -- exit
```

### Profile Function Execution

```bash
# Add timestamps to trace output
PS4='+ $(date "+%T.%3N"): ' bash -x ./iclaude.sh --test 2>&1 | less
```

### Identify Slow Operations

```bash
# Find functions taking >1 second
PS4='+ $(date "+%T.%3N"): ' bash -x ./iclaude.sh --test 2>&1 | \
    awk '/^+ [0-9]{2}:[0-9]{2}:[0-9]{2}/ {print}' | \
    sort -t. -k2 -n
```

## Related Examples

- `add-command-option.md` - Adding debug flags
- `modify-proxy-validation.md` - Debugging proxy validation

## Getting Help

If debugging fails:

1. Check CLAUDE.md for architectural context
2. Review recent git commits for breaking changes
3. Compare with last known working version
4. Create minimal reproduction case
5. Document environment (OS, shell, versions)
6. Open issue with reproduction steps
