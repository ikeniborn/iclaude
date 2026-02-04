# Example: Multi-Perspective Analysis for Refactoring

## Scenario

Refactor `configure_proxy_from_url()` to separate domain resolution and credential storage logic.

## Task Description

```
Current function configure_proxy_from_url() (iclaude.sh:1545-1666) does 3 things:
1. Parse proxy URL
2. Resolve domain to IP (optional)
3. Save credentials to file

Split into 3 focused functions for better maintainability.
```

## Multi-Perspective Analysis

### System Architect

**Concerns:**
- Function coupling: domain resolution mixed with credential storage
- Single Responsibility Principle violated
- Hard to test individual components

**Recommendations:**
- Create 3 separate functions:
  - `parse_proxy_url()` - Parse URL and extract components
  - `resolve_proxy_domain()` - Handle domain-to-IP conversion
  - `save_proxy_credentials()` - Save to `.claude_proxy_credentials`
- Each function should have single responsibility
- Functions should be composable (call sequentially)

**Architecture Decision:**
```
OLD: configure_proxy_from_url() [120 lines, does everything]
NEW: parse_proxy_url() → resolve_proxy_domain() → save_proxy_credentials()
     [40 lines each, focused responsibility]
```

### Backend Developer

**Concerns:**
- Performance: unnecessary domain resolution on every call
- Error handling: which function should handle failures?
- Return values: how to pass data between functions?

**Recommendations:**
- Cache domain resolution results (add `PROXY_DOMAIN_CACHE` associative array)
- Each function should return explicit exit codes:
  - 0 = success
  - 1 = invalid input
  - 2 = network error (for resolve_proxy_domain)
- Use global variables for data passing (bash limitation)
- Add error handling at each layer

**Data Flow:**
```bash
parse_proxy_url "https://proxy:8118"
  → PROXY_PROTOCOL="https"
  → PROXY_HOST="proxy"
  → PROXY_PORT="8118"

resolve_proxy_domain "$PROXY_HOST"
  → PROXY_IP="192.168.1.100" (cached)

save_proxy_credentials "$PROXY_PROTOCOL" "$PROXY_HOST" "$PROXY_PORT"
  → .claude_proxy_credentials (chmod 600)
```

### Security Specialist

**Concerns:**
- Credential exposure: passwords in function parameters?
- File permissions: ensure chmod 600 on every save
- Command injection: validate proxy URL before resolution

**Recommendations:**
- Pass passwords via environment variables or stdin (NOT function params)
- `save_proxy_credentials()` must always chmod 600 (even if file exists)
- `parse_proxy_url()` must validate URL format (reject shell metacharacters)
- Add URL sanitization: escape special chars before domain resolution

**Security Checklist:**
```bash
# ✅ Good: password not in process list
PROXY_PASS="secret" save_proxy_credentials

# ❌ Bad: password visible in ps aux
save_proxy_credentials "https" "proxy" "8118" "secret"

# ✅ Good: validate before resolution
validate_proxy_url "$url" || return 1

# ❌ Bad: resolve untrusted input
resolve_proxy_domain "$(rm -rf /)"  # Command injection!
```

### DevOps Engineer

**Concerns:**
- Backward compatibility: existing `.claude_proxy_credentials` format
- Testing: how to unit test 3 separate functions?
- CI/CD: automated testing without real network access

**Recommendations:**
- Maintain backward compat: new functions should read old credential files
- Mock domain resolution for tests:
  - Set `MOCK_DNS_RESOLUTION=true` in test environment
  - Use test fixture: `tests/fixtures/dns-responses.txt`
- Add integration test:
  ```bash
  # Test with mock DNS
  MOCK_DNS_RESOLUTION=true bats tests/proxy-refactor.bats
  ```
- Document migration path in README

**Test Strategy:**
```bash
# Unit tests (no network)
test_parse_proxy_url()
test_save_proxy_credentials()

# Integration test (mocked network)
test_resolve_proxy_domain_with_mock()

# E2E test (real network, CI only)
test_full_proxy_flow_with_real_dns()
```

### Technical Writer

**Concerns:**
- Documentation: CLAUDE.md mentions `configure_proxy_from_url()` at 5 locations
- Function signatures changed: update all references
- Migration guide: how to update scripts that call old function?

**Recommendations:**
- Update CLAUDE.md section "Critical Functions" (lines 389-446):
  - Remove `configure_proxy_from_url()`
  - Add 3 new functions with examples
- Add "Migration Guide" section:
  ```markdown
  ### Migration from v1.x to v2.0

  **Old code:**
  ```bash
  configure_proxy_from_url "https://proxy:8118"
  ```

  **New code:**
  ```bash
  parse_proxy_url "https://proxy:8118" && \
  resolve_proxy_domain "$PROXY_HOST" && \
  save_proxy_credentials
  ```
  ```
- Update line numbers in Architecture section

**Documentation Checklist:**
- [ ] Update CLAUDE.md:389-446 (Critical Functions)
- [ ] Update CLAUDE.md:212-219 (Proxy Management component location)
- [ ] Add Migration Guide section
- [ ] Update README.md examples
- [ ] Add inline comments for complex logic

## Summary

**Key Takeaways:**
- **Architecture:** Split 120-line function into 3 focused functions (40 lines each)
- **Performance:** Add domain resolution caching
- **Security:** Validate URLs, use environment variables for passwords
- **Testing:** Mock DNS for unit tests, maintain backward compatibility
- **Documentation:** Update 5 locations in CLAUDE.md + add migration guide

**Implementation Priority:**
1. Create new functions (parse, resolve, save)
2. Add tests with mocked DNS
3. Update CLAUDE.md and README
4. Deprecate old function (add warning, keep for backward compat)
5. Remove old function in v2.0

**Validation Plan:**
- PHASE 0: shellcheck (check for SC2155 in new functions)
- PHASE 1: bash -n (syntax check)
- PHASE 3: code-review (security: URL validation, password handling)
- PHASE 4: Run tests: `bats tests/proxy-refactor.bats`
- PHASE 5: Update documentation (5 locations)
