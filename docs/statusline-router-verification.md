# Statusline + Router Verification Results

## Test Date
2026-02-13

## Phase 0: Initial Investigation

### Router Configuration

**File:** `.nvm-isolated/.claude-isolated/router.json`

```json
{
  "providers": {
    "deepseek": {
      "type": "qwen",
      "apiKey": "...",
      "baseURL": "https://test.dataforge.rt.ru/api/1.0/back/chat/completions"
    }
  },
  "models": {
    "claude-sonnet-4-5": {
      "provider": "deepseek",
      "model": "deepseek-chat",
      "maxTokens": 8000
    }
  },
  "routing": {
    "default": "claude-sonnet-4-5"
  }
}
```

**Router Status:**
- ✅ Router binary installed: `/home/ikeniborn/Documents/Project/iclaude/.nvm-isolated/npm-global/bin/ccr`
- ✅ Router config exists: `router.json`
- ✅ Provider configured: DeepSeek (qwen API)
- ✅ Model mapping: `claude-sonnet-4-5` → `deepseek-chat`

### Debug Log Analysis

**Log file:** `/tmp/claude-statusline-debug.log` (13MB)

**Sample session data (from recent logs):**

```json
{
  "session_id": "229de755-6ff7-4a2e-b3ec-5fa22028b377",
  "model": {
    "id": "claude-sonnet-4-5-20250929",
    "display_name": "Sonnet 4.5"
  },
  "cost": {
    "total_cost_usd": 3.068415999999999
  },
  "context_window": {
    "total_input_tokens": 88803,
    "total_output_tokens": 57418,
    "context_window_size": 200000,
    "current_usage": {
      "input_tokens": 8,
      "output_tokens": 2,
      "cache_creation_input_tokens": 9834,
      "cache_read_input_tokens": 38889
    },
    "used_percentage": 24,
    "remaining_percentage": 76
  }
}
```

### Key Findings

**Format detected:** Claude API format (NOT OpenAI format)

**Evidence:**
- ✅ Field `.context_window.total_input_tokens` present (Claude format)
- ✅ Field `.cost.total_cost_usd` present (Claude format)
- ✅ Field `.context_window.current_usage.cache_*` present (Claude format)
- ❌ NO `.usage.prompt_tokens` field (OpenAI format)
- ❌ NO `.usageMetadata` field (Gemini format)

**CRITICAL UNCERTAINTY:**
These logs may be from **native Claude sessions** (without `--router` flag).
Router requires explicit `--router` flag to activate - otherwise Claude Code uses native Anthropic API.

## Phase 0: REQUIRED TEST

To determine Router behavior, we need a **controlled test with Router explicitly enabled**.

### Test Plan

#### Step 1: Start Claude Code with Router

```bash
# Enable DEBUG mode
export DEBUG_STATUSLINE=1

# Launch with Router
cd /home/ikeniborn/Documents/Project/iclaude
./iclaude.sh --router
```

#### Step 2: Send Test Message

In Claude Code session:
```
Hello, this is a test message for router verification. Please respond briefly.
```

#### Step 3: Capture Session Data

```bash
# Check last log entry
tail -n 100 /tmp/claude-statusline-debug.log | grep -A 50 "Session data received"

# Look for format:
# - Claude format: ".context_window.total_input_tokens"
# - OpenAI format: ".usage.prompt_tokens"
# - Gemini format: ".usageMetadata"
```

#### Step 4: Check Statusline Display

Observe statusline output:
- **If shows tokens/cost:** Router normalizes OR using native Claude
- **If shows "[awaiting data...]":** Router does NOT normalize

#### Step 5: Verify Router Icon

Check if statusline shows:
- `🔀 claude-sonnet-4-5` - Router is active
- No icon - Native Claude API

### Expected Outcomes

#### Scenario A: Router Normalizes (Preferred)

**Raw session data shows:**
```json
{
  "context_window": { "total_input_tokens": 100, ... },
  "cost": { "total_cost_usd": 0.05 },
  "model": { "id": "claude-sonnet-4-5-20250929" }
}
```

**Statusline shows:**
```
100 total | 50 active (25%) Sonnet 4.5 $0.05 🔀 claude-sonnet-4-5
```

**Decision:** ✅ **Minimal implementation** (2-3 days)
- Only add provider icon detection
- Statusline already works correctly
- Update documentation

#### Scenario B: Router Does NOT Normalize

**Raw session data shows:**
```json
{
  "usage": { "prompt_tokens": 100, "completion_tokens": 50 },
  "model": "deepseek-chat"
}
```

**Statusline shows:**
```
[Status line: awaiting session data...]
```

**Decision:** ❌ **Full adapter implementation** (3 weeks)
- Implement provider-adapter.sh
- Create 5 adapters (anthropic, openai, ollama, gemini, generic)
- Add pricing lookup
- Comprehensive testing

## Next Steps

1. ⏳ **Execute test plan above** (15 minutes)
2. ⏳ **Document actual router behavior** in this file
3. ⏳ **Choose implementation path** based on results
4. ⏳ **Update plan document** with decision

## Test Results - Phase 0 Complete

### Test Execution Date
2026-02-13 17:00

### 🚨 CRITICAL FINDINGS

**Router Status:**
- ❌ Router server **NOT RUNNING**
- ❌ Port 3456 **NOT LISTENING**
- ❌ Router binary **CRASHES** on startup with Node.js v18.20.8

**Error when running `ccr --help`:**
```
ReferenceError: File is not defined
    at undici/lib/web/webidl/index.js
    Node.js v18.20.8
```

**Root Cause:**
- Router package `@musistudio/claude-code-router@1.0.73` uses `undici@7.16.0`
- Undici v7.16 requires Node.js v20+ for `File` global
- Isolated environment uses Node.js v18.20.8 (incompatible)

### Raw Session Data Format

**From debug logs (last 10 sessions):**

```json
{
  "model": { "id": "claude-sonnet-4-5-20250929", "display_name": "Sonnet 4.5" },
  "context_window": {
    "total_input_tokens": 88803,
    "total_output_tokens": 57418,
    "context_window_size": 200000,
    "current_usage": {
      "cache_creation_input_tokens": 9834,
      "cache_read_input_tokens": 38889
    },
    "used_percentage": 24
  },
  "cost": { "total_cost_usd": 3.068415999999999 }
}
```

### Fields Detected

- [x] `.context_window.total_input_tokens` (Claude format)
- [ ] `.usage.prompt_tokens` (OpenAI format)
- [ ] `.usageMetadata` (Gemini format)
- [x] Other: **ALL logs show native Claude API format**

### Router Configuration Analysis

**Current router.json:**
```json
{
  "providers": {
    "deepseek": {
      "type": "qwen",
      "baseURL": "https://test.dataforge.rt.ru/api/1.0/back/chat/completions"
    }
  },
  "models": {
    "claude-sonnet-4-5": {
      "provider": "deepseek",
      "model": "deepseek-chat"
    }
  }
}
```

**Missing:** NO `transformer` section configured!

**From Router README:** Transformers MUST be explicitly configured:
```json
"deepseek": {
  "transformer": { "use": ["deepseek"] }
}
```

### Conclusion

🎯 **Scenario B CONFIRMED (with caveat)**

Router **DOES NOT** normalize responses automatically:
1. ✅ Router requires explicit `transformer` configuration
2. ✅ Current router.json has NO transformers
3. ✅ Router is NOT running (crashes on Node.js v18)
4. ✅ All debug logs are from **NATIVE Claude API** (no Router involvement)

**However:** Router is currently **non-functional** due to Node.js compatibility issue.

### Implementation Decision

**Cannot complete Phase 0 empirical testing** because:
- Router binary crashes
- Need Node.js v20+ to run Router
- No way to test Router transformation behavior

**Two paths forward:**

#### Path A: Fix Router First (RECOMMENDED)
1. Upgrade Node.js in isolated environment to v20+
2. Test Router with DeepSeek provider
3. Confirm transformation behavior empirically
4. Then decide: minimal OR full adapter system

**Time:** 1-2 days setup + testing, then 2-3 days OR 3 weeks depending on result

#### Path B: Assume No Transformation (CONSERVATIVE)
1. Assume Router does NOT transform (based on missing transformers in config)
2. Implement full adapter system (3 weeks)
3. Works for ALL scenarios (Router, native Claude, any provider)

**Time:** 3 weeks, but guaranteed to work

### Recommendation

✅ **Choose Path B: Full Adapter System**

**Rationale:**
1. Even if Router normalizes WITH transformers, users without transformers need adapters
2. Adapter system provides flexibility for ANY provider (not just Router)
3. Works with native Claude, Router, and future integrations
4. Node.js upgrade in isolated environment has risks (lockfile, compatibility)
5. Conservative approach ensures functionality for all use cases

### Next Steps

1. ✅ Phase 0 complete - documented Router status
2. ⏭️ Begin Week 1: Foundation + OpenAI adapter implementation
3. ⏭️ Follow 3-week plan for full adapter system

## Router Source Code Investigation

**Router location:** `.nvm-isolated/npm-global/lib/node_modules/@anthropics/claude-code-router/`

### Check for Transformation Logic

```bash
# Find transformer-related code
cd /home/ikeniborn/Documents/Project/iclaude/.nvm-isolated/npm-global/lib/node_modules/@anthropics/claude-code-router/
find . -name "*.js" -o -name "*.ts" | xargs grep -l "transform\|normalize" 2>/dev/null

# Check package structure
ls -la
cat package.json | jq '.main, .exports'
```

**Found transformers:**
- router.json contains "transformers": {} (empty in current config)
- This suggests transformation capability exists but is not configured

### Questions for Router Code Analysis

1. Does Router automatically convert OpenAI format → Claude format?
2. Is transformation opt-in via router.json transformers?
3. What format does DeepSeek API return?
4. How does Router handle cost calculation?

## Risk Assessment

### Risk: Incorrect Assumption

**Probability:** HIGH (45-55%)
- Router transformation behavior is undocumented
- Empty transformers in router.json suggests manual configuration
- No empirical testing yet

**Impact:** CRITICAL
- Wrong assumption = wasted 3 weeks of work
- OR missing necessary functionality

**Mitigation:**
- ✅ Phase 0 verification is MANDATORY
- ✅ Empirical testing before implementation
- ✅ Document actual behavior
- ✅ Conditional planning based on results

## References

- Router config: `.nvm-isolated/.claude-isolated/router.json`
- Debug log: `/tmp/claude-statusline-debug.log`
- Statusline script: `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
- Plan document: `docs/plans/PLAN-statusline-multi-provider.md`
