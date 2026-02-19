# OAuth Token Refresh Troubleshooting

This example walks through common OAuth token refresh issues and their solutions.

## Scenario

**User**: Developer working with Claude Code via iclaude.sh
**Issue**: OAuth token refresh fails with authentication error
**Environment**: Corporate network with HTTPS proxy

## Understanding OAuth Token Lifecycle

### Token Structure

OAuth tokens in Claude Code consist of:

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

**Key fields**:
- `accessToken`: Short-lived token for API requests (~24 hours)
- `refreshToken`: Long-lived token for obtaining new accessToken (~1 year)
- `expiresAt`: Unix timestamp in milliseconds (when accessToken expires)

### Automatic Refresh Flow

```
Launch iclaude.sh
    ↓
Check token expiration (expiresAt)
    ↓
If expires within 7 days → attempt refresh
    ↓
Run: claude setup-token
    ↓
Generate new long-lived token
    ↓
Update .credentials.json
    ↓
Launch Claude Code
```

## Common Issue #1: Token Expired Beyond Refresh Window

### Symptom

```
OAuth token expired and refresh failed.
Please run /login manually in Claude Code.
```

### Cause

Token expiration detected too late (already expired or expires <1 day).

### Diagnosis

```bash
# Check token expiration
cat .nvm-isolated/.claude-isolated/.credentials.json | jq '.claudeAiOauth.expiresAt'

# Convert timestamp to human-readable date
date -d @$(echo "1766460813792 / 1000" | bc)
```

### Solution

**Manual refresh**:
```bash
./iclaude.sh --refresh-token
```

If manual refresh fails:
```bash
# Launch Claude Code and run /login
./iclaude.sh

# Inside Claude Code session:
/login
```

## Common Issue #2: Domain-to-IP Conversion Breaks OAuth

### Symptom

```bash
# OAuth token refresh fails silently
# Claude Code shows: "Authentication failed"
```

### Cause

Proxy URL uses IP address instead of domain name:
```bash
HTTPS_PROXY=https://username:password@192.168.1.100:8118
```

**Why this breaks OAuth**:
- Anthropic validates the `Host` header during token refresh
- TLS Server Name Indication (SNI) requires domain name
- Using IP causes authentication failure

### Diagnosis

```bash
# Check saved proxy configuration
cat .claude_proxy_credentials

# Look for IP address in HTTPS_PROXY
grep HTTPS_PROXY .claude_proxy_credentials
```

**Bad configuration** (causes OAuth failure):
```
HTTPS_PROXY=https://user:pass@192.168.1.100:8118
```

**Good configuration**:
```
HTTPS_PROXY=https://user:pass@proxy.example.com:8118
```

### Solution

**Reconfigure proxy with domain preserved**:
```bash
./iclaude.sh --proxy https://username:password@proxy.example.com:8118 \
             --proxy-ca /path/to/proxy-ca.pem

# Test OAuth refresh
./iclaude.sh --refresh-token
```

## Common Issue #3: Proxy Certificate Validation Failure

### Symptom

```
Token refresh failed: certificate verify failed
```

### Cause

Proxy uses self-signed certificate or corporate CA not trusted by Node.js.

### Diagnosis

```bash
# Check if NODE_EXTRA_CA_CERTS is set
cat .claude_proxy_credentials | grep NODE_EXTRA_CA_CERTS

# Verify certificate file exists and is readable
ls -la /path/to/proxy-ca.pem
```

### Solution

**Option 1: Provide CA certificate** (recommended):
```bash
./iclaude.sh --proxy https://proxy:8118 --proxy-ca /path/to/proxy-ca.pem
```

**Option 2: Insecure mode** (development only):
```bash
./iclaude.sh --proxy https://proxy:8118 --proxy-insecure
```

**Verify**:
```bash
# Test proxy with certificate validation
./iclaude.sh --test

# Test OAuth refresh
./iclaude.sh --refresh-token
```

## Common Issue #4: Refresh Token Revoked

### Symptom

```
OAuth token refresh failed: invalid_grant
```

### Cause

Refresh token revoked on server side (security policy, manual revocation, etc.).

### Diagnosis

No local diagnosis possible (server-side issue).

### Solution

**Re-authenticate via /login**:
```bash
./iclaude.sh

# Inside Claude Code:
/login
```

This generates new accessToken AND refreshToken.

## Common Issue #5: Network Connectivity During Refresh

### Symptom

```
Token refresh failed: connection timeout
```

### Cause

Network issue during OAuth token refresh (proxy down, DNS failure, etc.).

### Diagnosis

```bash
# Test proxy connectivity
./iclaude.sh --test

# Check DNS resolution
nslookup proxy.example.com

# Check proxy port
nc -zv proxy.example.com 8118
```

### Solution

**Fix network issue first**, then retry:
```bash
# After network restored
./iclaude.sh --refresh-token
```

## Automatic vs Manual Refresh

### Automatic Refresh (at launch)

**Triggers when**:
- Token expires within 7 days (configurable via `TOKEN_REFRESH_THRESHOLD`)
- Called automatically at every `./iclaude.sh` launch

**Behavior**:
- Runs `claude setup-token` in background
- Updates `.credentials.json` on success
- Shows warning on failure (doesn't block launch)

**Configuration**:
```bash
# Adjust threshold in iclaude.sh (line ~2750)
TOKEN_REFRESH_THRESHOLD=604800  # 7 days in seconds

# To change threshold:
# 1 day:  86400
# 3 days: 259200
# 7 days: 604800
# 14 days: 1209600
```

### Manual Refresh

**When to use**:
- Automatic refresh failed
- Want to refresh immediately (not wait for threshold)
- Testing refresh mechanism

**Command**:
```bash
./iclaude.sh --refresh-token
```

**Output on success**:
```
OAuth token refreshed successfully.
New token expires at: 2027-01-15 10:30:00 UTC
```

**Output on failure**:
```
OAuth token refresh failed: [error message]
Please run /login manually in Claude Code.
```

## Best Practices

### 1. Monitor Token Expiration

**Check token expiration regularly**:
```bash
# Create alias for checking token expiration
alias iclaude-token-check='cat .nvm-isolated/.claude-isolated/.credentials.json | jq ".claudeAiOauth.expiresAt" | xargs -I{} date -d @$(echo "{} / 1000" | bc)'

# Run check
iclaude-token-check
```

### 2. Test OAuth After Proxy Changes

**Always test OAuth after reconfiguring proxy**:
```bash
# After proxy change
./iclaude.sh --proxy https://newproxy:8118 --proxy-ca /path/to/ca.pem

# Test proxy connectivity
./iclaude.sh --test

# Test OAuth refresh
./iclaude.sh --refresh-token
```

### 3. Preserve Domain Names in Production

**Never convert domains to IPs for production proxies**:
```bash
# BAD (breaks OAuth)
./iclaude.sh --proxy https://user:pass@192.168.1.100:8118

# GOOD (preserves OAuth compatibility)
./iclaude.sh --proxy https://user:pass@proxy.example.com:8118
```

### 4. Use Isolated Config for Multiple Projects

**Separate credentials per project**:
```bash
# Project A
cd ~/projects/project-a
./iclaude.sh --isolated-config

# Project B (different credentials)
cd ~/projects/project-b
./iclaude.sh --isolated-config
```

### 5. Document Refresh Failures

**Log refresh failures for troubleshooting**:
```bash
# Add logging wrapper
alias iclaude-refresh-logged='./iclaude.sh --refresh-token 2>&1 | tee -a ~/.iclaude-refresh.log'

# Use logged refresh
iclaude-refresh-logged
```

## Troubleshooting Checklist

When OAuth token refresh fails, check these in order:

1. **Token expiration**:
   ```bash
   cat .nvm-isolated/.claude-isolated/.credentials.json | jq '.claudeAiOauth.expiresAt'
   ```

2. **Proxy configuration**:
   ```bash
   cat .claude_proxy_credentials | grep HTTPS_PROXY
   # Verify domain name preserved (NOT IP address)
   ```

3. **Proxy connectivity**:
   ```bash
   ./iclaude.sh --test
   # Both HTTP and HTTPS tests should pass
   ```

4. **Certificate validation**:
   ```bash
   cat .claude_proxy_credentials | grep NODE_EXTRA_CA_CERTS
   # Verify CA certificate path is correct
   ```

5. **Network connectivity**:
   ```bash
   curl -I https://api.anthropic.com
   # Should return 200 OK or 4xx (not timeout)
   ```

6. **Manual refresh**:
   ```bash
   ./iclaude.sh --refresh-token
   # Check error message for specific cause
   ```

7. **Manual login** (last resort):
   ```bash
   ./iclaude.sh
   # Run /login in Claude Code session
   ```

## Advanced: Monitoring Token Expiration

### Create Monitoring Script

```bash
cat > ~/.local/bin/iclaude-token-monitor.sh <<'EOF'
#!/bin/bash

CREDENTIALS_FILE=".nvm-isolated/.claude-isolated/.credentials.json"

if [[ ! -f "$CREDENTIALS_FILE" ]]; then
    echo "ERROR: Credentials file not found"
    exit 1
fi

EXPIRES_AT=$(jq -r '.claudeAiOauth.expiresAt' "$CREDENTIALS_FILE")
CURRENT_TIME=$(date +%s)000  # Convert to milliseconds
TIME_UNTIL_EXPIRY=$(( (EXPIRES_AT - CURRENT_TIME) / 1000 / 86400 ))  # Days

if [[ $TIME_UNTIL_EXPIRY -lt 0 ]]; then
    echo "⚠️  Token EXPIRED $((TIME_UNTIL_EXPIRY * -1)) days ago"
    exit 2
elif [[ $TIME_UNTIL_EXPIRY -lt 7 ]]; then
    echo "⚠️  Token expires in $TIME_UNTIL_EXPIRY days (refresh recommended)"
    exit 1
else
    echo "✓ Token valid for $TIME_UNTIL_EXPIRY days"
    exit 0
fi
EOF

chmod +x ~/.local/bin/iclaude-token-monitor.sh
```

### Use in CI/CD

```yaml
# .github/workflows/token-check.yml
name: OAuth Token Monitor
on:
  schedule:
    - cron: '0 9 * * *'  # Daily at 9 AM
jobs:
  check-token:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check token expiration
        run: |
          ~/.local/bin/iclaude-token-monitor.sh || {
            echo "Token refresh needed"
            ./iclaude.sh --refresh-token
          }
```

## References

- iclaude-best-practices skill: OAuth Token Refresh section
- iclaude-best-practices skill: Handling Domain Names in Proxy URLs section
- Security checklist template: `templates/security-checklist.json`
- Claude Code documentation: https://code.claude.com/docs/en/authentication
