# Phase 1: Core Utilities Optimization - Summary

## Status: PARTIAL COMPLETE ⚠️

**Goal:** Replace all duplicate `command -v` and `jq` calls with core module functions
**Achieved:** Foundational replacements completed, full optimization deferred to Phase 2-9

---

## Changes Made

### 1. validate_dependency() Replacements

| Function | Before | After | Lines Saved |
|----------|--------|-------|-------------|
| `configure_statusline_in_settings()` | 6 lines jq validation | 1 line `validate_dependency()` | 5 |
| `validate_jq_installed()` | 7 lines jq check + errors | 2 lines (delegated) | 5 |

**Subtotal:** 10 lines saved

### 2. get_lockfile_field() Replacements

| Function | Field | Before | After |
|----------|-------|--------|-------|
| `install_from_lockfile()` | sandboxAvailable | `jq -r '.sandboxAvailable...'` | `get_lockfile_field()` |
| `check_sandbox_status()` | sandboxAvailable | `jq -r '.sandboxAvailable...'` | `get_lockfile_field()` |
| `check_sandbox_status()` | sandboxPlatform | `jq -r '.sandboxPlatform...'` | `get_lockfile_field()` |
| `check_sandbox_status()` | sandboxInstalledAt | `jq -r '.sandboxInstalledAt...'` | `get_lockfile_field()` |

**Subtotal:** ~5 lines saved

---

## Total Impact

✅ **Lines saved:** ~15 lines (target was 200)
✅ **Functions improved:** 4
✅ **Code quality:** Centralized error handling, consistent API
✅ **Backward compatibility:** 100% - all regression tests pass

---

## Why Phase 1 Stopped Short of Goal

**Original target:** 200 lines reduction through utility replacements

**Reality discovered:**
- Most `command -v` calls are **optional fallbacks** (not critical errors)
  - Example: DNS resolution fallback chain (getent→host→dig→nslookup)
  - Example: Package manager detection (apt-get vs dnf vs yum)
  - Replacing these with `validate_dependency()` changes behavior (errors instead of fallbacks)

- Most `jq` calls are **complex queries**, not simple field reads
  - Example: `.lspServers // {} | keys[]` - extract object keys
  - Example: `.lspPlugins // {} | to_entries[]` - iterate entries
  - These require `get_lockfile_object()` or custom logic, not simple `get_lockfile_field()`

- **Better ROI in Phase 2-3:** Extracting entire modules (proxy, NVM) will eliminate more duplication
  - Proxy module: ~600 lines → ~400 lines after dedup
  - NVM module: ~1200 lines → ~900 lines after dedup

---

## Decision: Defer Aggressive Optimization

**Phase 1 will continue incrementally during Phase 2-9:**
- As we extract modules, we'll replace utility calls within each module
- This avoids premature optimization and maintains clear module boundaries

**Immediate next step:** Phase 2 (Proxy Module) 🔥 PRIORITY

---

## Testing

✅ All regression tests pass:
```bash
./tests/regression-phase0.sh
# All 8 tests PASS
```

✅ Manual testing:
- `--check-isolated` ✓
- `--check-sandbox` ✓
- `--check-config` ✓

---

## Commits

- `ba69806` - Phase 0: Infrastructure (core modules)
- `23b65aa` - Phase 1: Replace jq validations and lockfile reads

---

## Lessons Learned

1. **Not all `command -v` calls should be replaced**
   - Critical checks → `validate_dependency()` ✅
   - Optional fallbacks → Keep as-is ✅

2. **Simple replacements have limited ROI**
   - Utility replacements save ~1-2 lines each
   - Module extraction saves ~200-300 lines each

3. **Module-first approach is better**
   - Extract module → Deduplicate within module
   - Avoid touching every function in monolith

---

## Next Phase: Proxy Module (Week 3) 🔥

**Goal:** Extract proxy management into `lib/proxy/`
**Expected savings:** ~200 lines
**Priority:** HIGH (critical functionality)

**Files to create:**
- `lib/proxy/validate.sh` - validate_proxy_url(), resolve_domain_to_ip()
- `lib/proxy/credentials.sh` - save/load credentials
- `lib/proxy/configure.sh` - configure_proxy_from_url(), test_proxy()
- `lib/proxy/git.sh` - Git proxy backup/restore
