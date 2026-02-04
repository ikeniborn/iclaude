# Example: Validation Checkpoints for OAuth Token Refresh

## Scenario

Implement automatic OAuth token refresh that checks expiration on every `iclaude.sh` launch and refreshes tokens within 7 days of expiration.

## Validation Plan

### PHASE 0: LSP Diagnostics (shellcheck)

**Tool:** `shellcheck -x iclaude.sh`

**Focus Areas:**
- SC2086: Unquoted variable expansions in token parsing
- SC2181: Checking exit codes directly instead of `$?`
- SC2155: Declare and assign in separate statements for error handling

**Commands:**
```bash
# Run shellcheck on new functions
shellcheck -x iclaude.sh | grep -E "check_oauth_token|refresh_oauth_token"

# Expected: No SC2086, SC2181, SC2155 in these functions
```

**Blocking:** ✅ Yes - Must pass before proceeding

**Success Criteria:**
- Zero shellcheck errors in `check_oauth_token()` and `refresh_oauth_token()`
- Warnings SC2034 (unused variables) are acceptable for exported vars

### PHASE 1: Syntax Check

**Tool:** `bash -n iclaude.sh`

**Focus Areas:**
- Proper function syntax (no missing `}` or `fi`)
- Correct if-then-else structure
- Valid JSON parsing with jq

**Commands:**
```bash
# Validate bash syntax
bash -n iclaude.sh

# Validate jq JSON parsing syntax
echo '{"expiresAt": 1766460813792}' | jq '.expiresAt' > /dev/null
```

**Blocking:** ✅ Yes - Syntax errors prevent execution

**Success Criteria:**
- `bash -n` returns 0
- All jq commands have valid syntax

### PHASE 2: Unit Tests (Optional)

**Tool:** bats-core (if available)

**Test Cases:**
```bash
# tests/oauth-token.bats

@test "check_oauth_token detects expired token" {
  # Mock .credentials.json with expired token
  echo '{"claudeAiOauth":{"expiresAt":1000000000000}}' > /tmp/test-creds.json

  CLAUDE_CONFIG_DIR=/tmp run check_oauth_token
  [ "$status" -eq 1 ]  # Should return 1 (expired)
}

@test "check_oauth_token accepts valid token" {
  # Mock with token expiring in 30 days
  EXPIRES_AT=$(($(date +%s)*1000 + 30*24*60*60*1000))
  echo "{\"claudeAiOauth\":{\"expiresAt\":$EXPIRES_AT}}" > /tmp/test-creds.json

  CLAUDE_CONFIG_DIR=/tmp run check_oauth_token
  [ "$status" -eq 0 ]  # Should return 0 (valid)
}

@test "refresh_oauth_token calls claude setup-token" {
  # Mock claude binary
  function claude() { echo "setup-token called"; }
  export -f claude

  run refresh_oauth_token
  [[ "$output" =~ "setup-token" ]]
}
```

**Commands:**
```bash
# Run unit tests
bats tests/oauth-token.bats
```

**Blocking:** ⚠️ Optional - Nice to have but not required

**Success Criteria:**
- All 3 tests pass
- Mock credentials tested (expired, valid, near-expiration)

### PHASE 3: Code Review

**Tool:** `@skill:code-review`

**Security Checks:**
1. **Token Storage:**
   - ✅ `.credentials.json` has chmod 600?
   - ✅ No token values logged to stdout/stderr?
   - ✅ Error messages don't expose token details?

2. **Command Injection:**
   - ✅ jq inputs sanitized?
   - ✅ No `eval` used with token data?
   - ✅ File paths validated before read?

3. **Error Handling:**
   - ✅ Failed refresh doesn't delete credentials file?
   - ✅ Graceful degradation if `claude` binary missing?
   - ✅ User notified of refresh failure?

**Performance Checks:**
1. Token check should be fast (<100ms):
   - ✅ No unnecessary file reads?
   - ✅ Exit early if .credentials.json missing?
   - ✅ No network calls in check (only in refresh)?

2. Refresh should be user-initiated:
   - ✅ Auto-refresh only within threshold (7 days)?
   - ✅ Manual refresh available via `--refresh-token`?

**Commands:**
```bash
# Manual security review
grep -n "expiresAt\|accessToken\|refreshToken" iclaude.sh

# Check file permissions in code
grep -n "chmod 600" iclaude.sh

# Verify no eval usage
grep -n "eval" iclaude.sh | grep -v "# safe"
```

**Blocking:** ⚠️ No - Warnings acceptable

**Success Criteria:**
- No critical security issues
- Performance within acceptable range
- Error handling tested manually

### PHASE 4: Integration Tests

**Test Case 1: Expired Token Scenario**
```bash
# Setup: Create expired token
cat > .nvm-isolated/.claude-isolated/.credentials.json <<EOF
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-oat01-EXPIRED",
    "refreshToken": "sk-ant-ort01-VALID",
    "expiresAt": 1000000000000,
    "scopes": ["user:inference"]
  }
}
EOF
chmod 600 .nvm-isolated/.claude-isolated/.credentials.json

# Test: Launch should trigger refresh
./iclaude.sh

# Expected: Prompt for browser authentication
# User action: Complete OAuth flow in browser
# Verify: New token in .credentials.json
jq '.claudeAiOauth.expiresAt' .nvm-isolated/.claude-isolated/.credentials.json
# Should be ~1 year in future
```

**Test Case 2: Valid Token Scenario**
```bash
# Setup: Create valid token (expires in 30 days)
EXPIRES_AT=$(($(date +%s)*1000 + 30*24*60*60*1000))
cat > .nvm-isolated/.claude-isolated/.credentials.json <<EOF
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-oat01-VALID",
    "expiresAt": $EXPIRES_AT
  }
}
EOF

# Test: Launch should NOT trigger refresh
./iclaude.sh

# Expected: No refresh prompt, Claude Code launches normally
# Verify: Token unchanged
```

**Test Case 3: Near-Expiration Scenario**
```bash
# Setup: Create token expiring in 3 days
EXPIRES_AT=$(($(date +%s)*1000 + 3*24*60*60*1000))
cat > .nvm-isolated/.claude-isolated/.credentials.json <<EOF
{
  "claudeAiOauth": {
    "expiresAt": $EXPIRES_AT
  }
}
EOF

# Test: Launch should trigger auto-refresh
./iclaude.sh

# Expected: Auto-refresh within 7 day threshold
# Verify: New expiresAt ~1 year in future
```

**Test Case 4: Manual Refresh**
```bash
# Test: Manual refresh regardless of expiration
./iclaude.sh --refresh-token

# Expected: Always triggers refresh
# Verify: New token generated
```

**Blocking:** ✅ Yes - Must work in real environment

**Success Criteria:**
- All 4 scenarios work as expected
- No data loss (credentials preserved on failure)
- User experience is smooth (clear prompts)

### PHASE 5: Documentation Sync

**Files to Update:**

1. **CLAUDE.md** (lines 299-318):
   ```markdown
   #### 7. OAuth Token Management (`check_oauth_token`, `refresh_oauth_token`)
   - **Location**: iclaude.sh:2749-2874
   - **Purpose**: Automatic OAuth token validation and refresh
   - **Key Features**:
     - Checks token expiration at every launch
     - Auto-refreshes within 7 days (configurable `TOKEN_REFRESH_THRESHOLD`)
     - Uses `claude setup-token` (~1 year tokens)
     - Preserves credentials file on failure
     - Manual refresh via `--refresh-token`
   ```

2. **CLAUDE.md** (lines 580-602) - Add new section:
   ```markdown
   ### OAuth Token Refresh

   **Automatic refresh** (at launch):
   - Checks token expiration at every `iclaude.sh` launch
   - If expires within 7 days → auto-refresh
   - Uses `claude setup-token` (~1 year tokens)

   **Manual refresh:**
   ```bash
   ./iclaude.sh --refresh-token
   ```

   **Configuration:**
   - `TOKEN_REFRESH_THRESHOLD` (default: 604800 = 7 days)
   - Token in `.credentials.json` with `expiresAt` (milliseconds)
   ```

3. **README.md** - Update Testing section:
   ```markdown
   ### OAuth Token Management
   - Auto-refresh: Within 7 days of expiration
   - Manual: `./iclaude.sh --refresh-token`
   - Long-lived tokens: ~1 year validity
   ```

4. **CHANGELOG.md** - Add entry:
   ```markdown
   ## [2.2.0] - 2026-02-04

   ### Added
   - Automatic OAuth token refresh on launch
   - `--refresh-token` flag for manual refresh
   - TOKEN_REFRESH_THRESHOLD configuration (default: 7 days)

   ### Security
   - Credentials file preserved on refresh failure
   - No token values logged or exposed
   ```

**Blocking:** ⚠️ No - But critical for maintainability

**Success Criteria:**
- All 4 files updated with accurate information
- Line numbers verified (use `grep -n`)
- Examples tested and working

## Validation Results Summary

| Phase | Status | Errors | Warnings | Notes |
|-------|--------|--------|----------|-------|
| PHASE 0: LSP | ✅ Passed | 0 | 2 (SC2034 acceptable) | No critical issues |
| PHASE 1: Syntax | ✅ Passed | 0 | 0 | Clean syntax |
| PHASE 2: Unit Tests | ⚠️ Skipped | - | - | bats-core not available |
| PHASE 3: Code Review | ✅ Passed | 0 | 1 (function length) | Security verified |
| PHASE 4: Integration | ✅ Passed | 0 | 0 | All 4 scenarios work |
| PHASE 5: Documentation | ✅ Completed | 0 | 0 | 4 files updated |

## Key Takeaways

**Validation Effectiveness:**
- PHASE 0 (LSP) caught 0 errors → code quality high from start
- PHASE 4 (Integration) revealed UX issue: unclear refresh prompt → fixed
- PHASE 5 (Documentation) prevented function location drift

**Time Investment:**
- PHASE 0-1: 5 min (automated)
- PHASE 3: 15 min (manual review)
- PHASE 4: 30 min (4 test cases)
- PHASE 5: 20 min (4 files)
- **Total: 70 min** vs **4+ hours debugging without validation**

**Best Practices Applied:**
- ✅ Blocking phases (LSP, Syntax, Integration) prevented broken code
- ✅ Non-blocking review caught performance concerns early
- ✅ Documentation sync prevented future confusion
- ✅ Multi-perspective analysis (Security Specialist) identified credential exposure risk
