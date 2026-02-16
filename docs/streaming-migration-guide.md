# Streaming Mode Migration Guide

**Version:** 4.2.0
**Target Audience:** Users with custom statusline implementations
**Last Updated:** 2026-02-13

Guide for migrating custom statusline scripts to support streaming mode.

---

## Table of Contents

1. [Overview](#overview)
2. [Pre-Migration Checklist](#pre-migration-checklist)
3. [Migration Scenarios](#migration-scenarios)
4. [Step-by-Step Migration](#step-by-step-migration)
5. [Testing Your Migration](#testing-your-migration)
6. [Backward Compatibility](#backward-compatibility)
7. [Examples](#examples)
8. [Troubleshooting](#troubleshooting)

---

## Overview

### What Changed?

**Week 2 (Streaming Mode) introduced:**
- ✅ Streaming chunk detection
- ✅ Session-based state management
- ✅ Real-time token accumulation
- ✅ 🔄 streaming indicator

### Who Needs to Migrate?

**You need to migrate if:**
- ✅ You have a custom statusline script (not using stock `claude-statusline.sh`)
- ✅ You want real-time token updates during streaming
- ✅ You want the 🔄 streaming indicator

**You DON'T need to migrate if:**
- ❌ You use stock `claude-statusline.sh` (already updated)
- ❌ You only use non-streaming requests
- ❌ You don't need streaming visualization

### Migration Complexity

| Scenario | Complexity | Time | Requires |
|----------|-----------|------|----------|
| Minimal (indicator only) | 🟢 Low | 10 min | Add STREAMING_ICON |
| Basic (state reading) | 🟡 Medium | 30 min | Source modules + read state |
| Full (chunk parsing) | 🔴 High | 1-2h | Integrate provider-adapter |

---

## Pre-Migration Checklist

### 1. Backup Your Current Script

```bash
# Backup custom statusline
cp your-statusline.sh your-statusline.sh.backup

# Test backup works
bash your-statusline.sh.backup < test-session.json
```

### 2. Verify Streaming Modules Installed

```bash
# Check modules exist
ls -la .nvm-isolated/.claude-isolated/scripts/lib/streaming-*.sh

# Expected: 3 files
# - streaming-detector.sh
# - streaming-state.sh
# - streaming-parser.sh
```

### 3. Understand Your Current Implementation

**Questions to answer:**
1. How do you parse session data? (jq, bash, other?)
2. Do you use provider-adapter.sh? (yes/no)
3. Do you have custom token parsing logic? (yes/no)
4. What display format do you use? (full/compact/custom)

### 4. Read Reference Implementation

```bash
# Study stock statusline for reference
less .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh

# Key sections:
# - Lines 51-65: Provider adapter sourcing
# - Lines 207-211: Streaming indicator
# - Lines 743, 761: Display integration
```

---

## Migration Scenarios

### Scenario A: Minimal (Indicator Only)

**Goal:** Show 🔄 during streaming, no chunk parsing

**Prerequisites:**
- Already using `provider-adapter.sh`
- Session ID available via environment

**Changes Needed:**
1. Add streaming indicator variable
2. Update display string

**Estimated Time:** 10 minutes

---

### Scenario B: Basic (State Reading)

**Goal:** Read streaming state, display accumulated tokens

**Prerequisites:**
- Can read session ID
- Can source streaming modules

**Changes Needed:**
1. Source streaming-state.sh
2. Check for streaming state
3. Read state file if exists
4. Display accumulated tokens
5. Add streaming indicator

**Estimated Time:** 30 minutes

---

### Scenario C: Full (Chunk Parsing)

**Goal:** Parse chunks, accumulate tokens, display real-time

**Prerequisites:**
- Receive streaming chunks
- Have session ID management

**Changes Needed:**
1. Source all streaming modules
2. Detect streaming vs non-streaming
3. Parse chunks via streaming-parser
4. Update state via streaming-state
5. Display from state
6. Add streaming indicator

**Estimated Time:** 1-2 hours

---

## Step-by-Step Migration

### Scenario A: Minimal Migration

**Step 1: Add Streaming Indicator Variable**

```bash
# Add after provider icon logic
STREAMING_ICON=""
if [[ "${STREAMING_ACTIVE:-0}" == "1" ]]; then
    STREAMING_ICON=" 🔄"
fi
```

**Step 2: Update Display String**

```bash
# Before:
STATUS_LINE="${TOKENS} | ${MODEL} | \$${COST}${PROVIDER_ICON}"

# After:
STATUS_LINE="${TOKENS} | ${MODEL} | \$${COST}${PROVIDER_ICON}${STREAMING_ICON}"
```

**Step 3: Test**

```bash
# Set flag manually
export STREAMING_ACTIVE=1

# Run your statusline
bash your-statusline.sh < test-session.json

# Should show 🔄 icon
```

**Done!** Minimal migration complete.

---

### Scenario B: Basic Migration

**Step 1: Source Streaming State Module**

```bash
# At top of script (after shebang)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source streaming-state.sh
if [[ -f "$SCRIPT_DIR/lib/streaming-state.sh" ]]; then
    source "$SCRIPT_DIR/lib/streaming-state.sh"
    STREAMING_STATE_AVAILABLE=1
else
    STREAMING_STATE_AVAILABLE=0
fi
```

**Step 2: Check for Streaming State**

```bash
# Get session ID (from environment or parse from data)
SESSION_ID="${CLAUDE_SESSION_ID:-}"

# Check if streaming active
if [[ "$STREAMING_STATE_AVAILABLE" == "1" ]] && [[ -n "$SESSION_ID" ]]; then
    if is_streaming_active "$SESSION_ID"; then
        STREAMING_ACTIVE=1
    else
        STREAMING_ACTIVE=0
    fi
else
    STREAMING_ACTIVE=0
fi
```

**Step 3: Read State if Streaming**

```bash
if [[ "$STREAMING_ACTIVE" == "1" ]]; then
    # Read accumulated state
    STREAMING_STATE=$(get_streaming_state "$SESSION_ID")

    # Extract tokens from state
    TOTAL_INPUT=$(echo "$STREAMING_STATE" | jq -r '.input_tokens // 0')
    TOTAL_OUTPUT=$(echo "$STREAMING_STATE" | jq -r '.output_tokens // 0')
    CACHE_READ=$(echo "$STREAMING_STATE" | jq -r '.cache_read_tokens // 0')
    MODEL=$(echo "$STREAMING_STATE" | jq -r '.model // "Unknown"')

    # Cost is calculated after completion
    COST="0.00"
else
    # Parse from complete session data (your existing logic)
    TOTAL_INPUT=$(echo "$SESSION_DATA" | jq -r '.context_window.total_input_tokens // 0')
    # ... existing parsing ...
fi
```

**Step 4: Add Streaming Indicator**

```bash
# (Same as Scenario A)
STREAMING_ICON=""
if [[ "${STREAMING_ACTIVE:-0}" == "1" ]]; then
    STREAMING_ICON=" 🔄"
fi
```

**Step 5: Update Display**

```bash
STATUS_LINE="${TOTAL_INPUT} in | ${TOTAL_OUTPUT} out | ${MODEL} | \$${COST}${STREAMING_ICON}"
```

**Done!** Basic migration complete.

---

### Scenario C: Full Migration

**Step 1: Source All Streaming Modules**

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source streaming modules
if [[ -f "$SCRIPT_DIR/lib/streaming-detector.sh" ]]; then
    source "$SCRIPT_DIR/lib/streaming-detector.sh"
    source "$SCRIPT_DIR/lib/streaming-state.sh"
    source "$SCRIPT_DIR/lib/streaming-parser.sh"
    STREAMING_SUPPORT=1
else
    STREAMING_SUPPORT=0
fi
```

**Step 2: Add Chunk Detection**

```bash
# Read input data
SESSION_DATA=$(cat)

# Detect streaming vs non-streaming
if [[ "$STREAMING_SUPPORT" == "1" ]] && is_streaming_chunk "$SESSION_DATA"; then
    # Streaming path
    STREAMING_MODE=1
else
    # Non-streaming path
    STREAMING_MODE=0
fi
```

**Step 3: Parse Chunks (Streaming Path)**

```bash
if [[ "$STREAMING_MODE" == "1" ]]; then
    # Get session ID (from environment or extract from chunk)
    SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$SESSION_DATA" | jq -r '.message.id // .id // ""')}"

    # Get provider
    PROVIDER=$(get_streaming_provider "$SESSION_DATA")

    # Parse chunk
    CHUNK_DATA=$(parse_streaming_chunk "$SESSION_DATA")

    # Initialize state if first chunk
    if ! is_streaming_active "$SESSION_ID"; then
        MODEL=$(echo "$SESSION_DATA" | jq -r '.message.model // .model // "Unknown"')
        init_streaming_state "$SESSION_ID" "$PROVIDER" "$MODEL"
    fi

    # Update state
    update_streaming_state "$SESSION_ID" "$CHUNK_DATA"

    # Read accumulated state for display
    STREAMING_STATE=$(get_streaming_state "$SESSION_ID")
    TOTAL_INPUT=$(echo "$STREAMING_STATE" | jq -r '.input_tokens')
    TOTAL_OUTPUT=$(echo "$STREAMING_STATE" | jq -r '.output_tokens')
    CACHE_READ=$(echo "$STREAMING_STATE" | jq -r '.cache_read_tokens')
    MODEL=$(echo "$STREAMING_STATE" | jq -r '.model')
    COST="0.00"
    STREAMING_ACTIVE=1
else
    # Non-streaming path (your existing logic)
    TOTAL_INPUT=$(echo "$SESSION_DATA" | jq -r '.context_window.total_input_tokens // 0')
    # ... existing parsing ...
    STREAMING_ACTIVE=0
fi
```

**Step 4: Add Streaming Indicator**

```bash
STREAMING_ICON=""
if [[ "${STREAMING_ACTIVE:-0}" == "1" ]]; then
    STREAMING_ICON=" 🔄"
fi
```

**Step 5: Update Display**

```bash
STATUS_LINE="${TOTAL_INPUT} in | ${TOTAL_OUTPUT} out | ${MODEL} | \$${COST}${STREAMING_ICON}"
```

**Done!** Full migration complete.

---

## Testing Your Migration

### Test 1: Non-Streaming (Backward Compatibility)

```bash
# Test with complete response
COMPLETE_DATA='{"context_window":{"total_input_tokens":1000,"total_output_tokens":500},"model":{"display_name":"Claude Sonnet 4.5"},"cost":{"total_cost_usd":0.50}}'

echo "$COMPLETE_DATA" | bash your-statusline.sh

# Expected:
# - Tokens displayed correctly
# - No 🔄 icon
# - Cost shown
```

### Test 2: Streaming (First Chunk)

```bash
export SESSION_ID="test_session_$$"

# Test message_start
CHUNK1='{"type":"message_start","message":{"id":"'$SESSION_ID'","model":"claude-sonnet-4.5","usage":{"input_tokens":1000,"cache_read_input_tokens":500}}}'

echo "$CHUNK1" | bash your-statusline.sh

# Expected:
# - Input tokens: 1000
# - Cache read: 500
# - Output tokens: 0
# - 🔄 icon visible
```

### Test 3: Streaming (Delta Chunk)

```bash
# Test message_delta
CHUNK2='{"type":"message_delta","usage":{"output_tokens":50}}'

echo "$CHUNK2" | bash your-statusline.sh

# Expected:
# - Input tokens: 1000 (unchanged)
# - Output tokens: 50 (accumulated)
# - 🔄 icon visible
```

### Test 4: Streaming (Final Chunk)

```bash
# Test message_stop
CHUNK3='{"type":"message_stop"}'

echo "$CHUNK3" | bash your-statusline.sh

# Expected:
# - Tokens same as before
# - 🔄 icon may still be visible (until finalized)
```

### Test 5: Cleanup

```bash
# Cleanup test state
source lib/streaming-state.sh
delete_streaming_state "$SESSION_ID"

# Verify removed
ls ~/.claude-code/streaming-state/$SESSION_ID.state
# Should output: No such file
```

---

## Backward Compatibility

### Ensure Non-Breaking Changes

**✅ DO:**
- Keep existing non-streaming path unchanged
- Add streaming as optional code path
- Check for module availability before using
- Fallback to existing logic if modules unavailable

**❌ DON'T:**
- Remove existing parsing logic
- Require streaming modules
- Break non-streaming display format
- Change existing global variables

### Compatibility Checklist

```bash
# Test non-streaming still works
echo "$COMPLETE_DATA" | bash your-statusline.sh
# Should work identically to before

# Test with modules unavailable
mv lib/streaming-detector.sh lib/streaming-detector.sh.disabled
echo "$COMPLETE_DATA" | bash your-statusline.sh
# Should still work (graceful degradation)
mv lib/streaming-detector.sh.disabled lib/streaming-detector.sh

# Test with malformed data
echo "invalid json" | bash your-statusline.sh
# Should not crash (error handling)
```

---

## Examples

### Example 1: Minimal Custom Statusline

**Before migration:**
```bash
#!/bin/bash
SESSION_DATA=$(cat)
TOKENS=$(echo "$SESSION_DATA" | jq -r '.context_window.total_input_tokens')
MODEL=$(echo "$SESSION_DATA" | jq -r '.model.display_name')
echo "$TOKENS | $MODEL"
```

**After migration (Minimal):**
```bash
#!/bin/bash
SESSION_DATA=$(cat)
TOKENS=$(echo "$SESSION_DATA" | jq -r '.context_window.total_input_tokens')
MODEL=$(echo "$SESSION_DATA" | jq -r '.model.display_name')

# Add streaming indicator
STREAMING_ICON=""
if [[ "${STREAMING_ACTIVE:-0}" == "1" ]]; then
    STREAMING_ICON=" 🔄"
fi

echo "$TOKENS | $MODEL${STREAMING_ICON}"
```

### Example 2: Custom with Provider Detection

**Before migration:**
```bash
#!/bin/bash
SESSION_DATA=$(cat)

# Detect provider
if echo "$SESSION_DATA" | jq -e '.context_window' > /dev/null; then
    PROVIDER="anthropic"
    TOKENS=$(echo "$SESSION_DATA" | jq -r '.context_window.total_input_tokens')
else
    PROVIDER="openai"
    TOKENS=$(echo "$SESSION_DATA" | jq -r '.usage.prompt_tokens')
fi

echo "$PROVIDER | $TOKENS"
```

**After migration (Basic):**
```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_DATA=$(cat)

# Source streaming state
if [[ -f "$SCRIPT_DIR/lib/streaming-state.sh" ]]; then
    source "$SCRIPT_DIR/lib/streaming-state.sh"
fi

# Check for streaming state
SESSION_ID="${CLAUDE_SESSION_ID:-}"
if [[ -n "$SESSION_ID" ]] && is_streaming_active "$SESSION_ID" 2>/dev/null; then
    # Read from streaming state
    STATE=$(get_streaming_state "$SESSION_ID")
    PROVIDER=$(echo "$STATE" | jq -r '.provider')
    TOKENS=$(echo "$STATE" | jq -r '.input_tokens')
    STREAMING_ICON=" 🔄"
else
    # Existing detection logic
    if echo "$SESSION_DATA" | jq -e '.context_window' > /dev/null; then
        PROVIDER="anthropic"
        TOKENS=$(echo "$SESSION_DATA" | jq -r '.context_window.total_input_tokens')
    else
        PROVIDER="openai"
        TOKENS=$(echo "$SESSION_DATA" | jq -r '.usage.prompt_tokens')
    fi
    STREAMING_ICON=""
fi

echo "$PROVIDER | $TOKENS${STREAMING_ICON}"
```

---

## Troubleshooting

### Issue: "command not found: is_streaming_chunk"

**Cause:** Streaming modules not sourced

**Solution:**
```bash
# Verify modules exist
ls lib/streaming-detector.sh

# Source module
source lib/streaming-detector.sh

# Verify function loaded
declare -f is_streaming_chunk > /dev/null && echo "✅ Loaded"
```

### Issue: State file not found

**Cause:** Session ID not passed or incorrect

**Solution:**
```bash
# Debug session ID
echo "SESSION_ID=$SESSION_ID"

# Check state directory
ls ~/.claude-code/streaming-state/

# Verify state file path
echo ~/.claude-code/streaming-state/$SESSION_ID.state
```

### Issue: Streaming indicator always shows

**Cause:** STREAMING_ACTIVE not reset between requests

**Solution:**
```bash
# Reset at start of script
STREAMING_ACTIVE=0

# Set only if truly streaming
if is_streaming_active "$SESSION_ID"; then
    STREAMING_ACTIVE=1
fi
```

### Issue: Tokens not updating

**Cause:** State not being read or updated

**Solution:**
```bash
# Enable debug mode
export DEBUG_STATUSLINE=1

# Check debug output
bash your-statusline.sh < chunk.json 2>&1 | grep DEBUG
```

---

## Getting Help

### Migration Support

**Before asking for help:**
1. ✅ Check this migration guide
2. ✅ Review troubleshooting section
3. ✅ Test with reference implementation
4. ✅ Enable debug mode

**Include in questions:**
- Your migration scenario (A/B/C)
- Current implementation (code snippet)
- Expected vs actual behavior
- Error messages (if any)

### Support Resources

- **Troubleshooting Guide:** docs/streaming-troubleshooting-guide.md
- **Architecture Docs:** lib/README.md (Section 4)
- **Reference Implementation:** claude-statusline.sh (lines 51-65, 207-211)
- **GitHub Issues:** https://github.com/anthropics/claude-code/issues

---

## Summary

### Quick Reference

| Migration Type | Add Modules | Add Detection | Add State | Add Indicator | Time |
|---------------|-------------|---------------|-----------|---------------|------|
| Minimal | ❌ | ❌ | ❌ | ✅ | 10 min |
| Basic | streaming-state.sh | ❌ | ✅ Read only | ✅ | 30 min |
| Full | All 3 modules | ✅ | ✅ Read + Write | ✅ | 1-2h |

### Migration Checklist

- [ ] Backup existing script
- [ ] Choose migration scenario (A/B/C)
- [ ] Source required modules
- [ ] Add streaming detection (if Full)
- [ ] Add state management (if Basic/Full)
- [ ] Add streaming indicator
- [ ] Test non-streaming (backward compat)
- [ ] Test streaming (all chunk types)
- [ ] Verify cleanup works
- [ ] Update documentation

---

**Version:** 4.2.0
**Last Updated:** 2026-02-13
**Streaming Mode:** Production-ready ✅
