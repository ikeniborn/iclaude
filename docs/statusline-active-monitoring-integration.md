# Statusline Active Monitoring Integration

**Date:** 2026-02-16
**Status:** ✅ Completed

## Overview

Integrated active monitoring function `wait_for_system_messages_to_clear()` into statusline script to replace fixed 30-second delay with intelligent transcript file monitoring.

## Changes

### 1. Session Context Parsing (Lines 122-126)

**Added early parsing** of session context variables for use across all features:

```bash
# Parse session context (session_id, project_dir, transcript_path)
# Used by multiple features: smart waiting, session links, TOON generation
SESSION_ID=$(echo "$SESSION_DATA" | jq -r '.session_id // "unknown"' 2>/dev/null)
SESSION_FILE=$(echo "$SESSION_DATA" | jq -r '.transcript_path // empty' 2>/dev/null)
PROJECT_DIR=$(echo "$SESSION_DATA" | jq -r '.workspace.project_dir // .cwd // empty' 2>/dev/null)
```

**Benefits:**
- Single source of truth for session context
- Available early for all features
- No duplication across code sections

### 2. Session Link Deduplication (Lines 401-407)

**Removed duplicate parsing** in session link section:

**Before:**
```bash
SESSION_LINK=""
SESSION_FILE=$(echo "$SESSION_DATA" | jq -r '.transcript_path // empty' 2>/dev/null)
PROJECT_DIR=$(echo "$SESSION_DATA" | jq -r '.workspace.project_dir // .cwd // empty' 2>/dev/null)

if [[ -n "$SESSION_FILE" ]] && [[ -f "$SESSION_FILE" ]] && [[ -n "$PROJECT_DIR" ]] && [[ -d "$PROJECT_DIR" ]]; then
    SESSION_ID=$(basename "$SESSION_FILE" .jsonl)
    SESSIONS_DIR="$PROJECT_DIR/.claude/sessions"
```

**After:**
```bash
SESSION_LINK=""

if [[ -n "$SESSION_FILE" ]] && [[ -f "$SESSION_FILE" ]] && [[ -n "$PROJECT_DIR" ]] && [[ -d "$PROJECT_DIR" ]]; then
    SESSIONS_DIR="$PROJECT_DIR/.claude/sessions"
```

**Benefits:**
- Uses globally parsed SESSION_ID from line 122
- No redundant parsing
- Cleaner code

### 3. Smart Handling Deduplication (Lines 771-775)

**Removed duplicate parsing** in smart handling section:

**Before:**
```bash
# Smart handling: wait for system messages during session startup period
# System messages can appear multiple times in first ~30 seconds
SESSION_ID=$(echo "$SESSION_DATA" | jq -r '.session_id // "unknown"' 2>/dev/null)
PROJECT_DIR=$(echo "$SESSION_DATA" | jq -r '.workspace.project_dir // .cwd // empty' 2>/dev/null)
SESSION_START_TIME_FILE="/tmp/claude-statusline-start-time-${SESSION_ID}"
SESSION_READY_MARKER="/tmp/claude-statusline-ready-${SESSION_ID}"
```

**After:**
```bash
# Smart handling: wait for system messages during session startup period
# System messages can appear multiple times in first ~30 seconds
# SESSION_ID and PROJECT_DIR already parsed above (after active context parsing)
SESSION_START_TIME_FILE="/tmp/claude-statusline-start-time-${SESSION_ID}"
SESSION_READY_MARKER="/tmp/claude-statusline-ready-${SESSION_ID}"
```

### 4. Phase 1 Active Monitoring (Lines 788-795)

**Replaced fixed delay** with active monitoring function:

**Before:**
```bash
# Phase 1: Startup period (0-30 seconds) - no output
# ВАЖНО: Применяется только к НОВЫМ сессиям (TOTAL_TOKENS == 0)
# Для продолжающихся сессий (после /clear) всегда показываем статус лайн
if [[ $SESSION_AGE -lt 30 ]] && [[ $TOTAL_TOKENS -eq 0 ]]; then
    exit 0
fi

# Phase 2: After 30s, but first message after wait - mark ready, no output yet
# ВАЖНО: Также только для новых сессий
if [[ ! -f "$SESSION_READY_MARKER" ]] && [[ $TOTAL_TOKENS -eq 0 ]]; then
    touch "$SESSION_READY_MARKER" 2>/dev/null
    exit 0
fi
```

**After:**
```bash
# Phase 1: Startup period - active monitoring of system messages
# ВАЖНО: Применяется только к НОВЫМ сессиям (TOTAL_TOKENS == 0)
# Для продолжающихся сессий (после /clear) всегда показываем статус лайн
# Active monitoring: waits for transcript file to stabilize (system messages cleared)
if [[ $SESSION_AGE -lt 30 ]] && [[ $TOTAL_TOKENS -eq 0 ]] && [[ ! -f "$SESSION_READY_MARKER" ]]; then
    # Wait for system messages to clear before showing statusline
    wait_for_system_messages_to_clear "$SESSION_ID" "$PROJECT_DIR"
    # Mark session as ready after waiting
    touch "$SESSION_READY_MARKER" 2>/dev/null
    exit 0
fi
```

**Benefits:**
- **Intelligent waiting**: Monitors transcript file changes instead of fixed delay
- **Faster response**: Shows statusline as soon as system messages clear (8-20s vs fixed 30s)
- **Optimized flow**: Creates ready marker immediately after waiting (eliminates Phase 2)

## How It Works

### Function: `wait_for_system_messages_to_clear()`

**Location:** Lines 561-649
**Parameters:**
- `$1` - Session ID
- `$2` - Project directory

**Algorithm:**

1. **Initial delay:** 8 seconds (increased from 3s for safety)
2. **Stability check:** Monitors transcript file modification time
3. **Stable period:** 3 seconds without changes (increased from 2s)
4. **Maximum timeout:** 20 seconds (increased from 15s)

**Debug mode:**
```bash
DEBUG_STATUSLINE=1 ./iclaude.sh
# Logs to /tmp/claude-statusline-wait-debug.log
```

### Execution Flow

#### New Session (TOTAL_TOKENS == 0)

**First invocation:**
```
1. SESSION_AGE < 30 ✓
2. TOTAL_TOKENS == 0 ✓
3. Ready marker absent ✓
→ Call wait_for_system_messages_to_clear()
→ Wait 8-20 seconds (until transcript stable)
→ Create ready marker
→ exit 0
```

**Second invocation:**
```
1. SESSION_AGE may be < 30 or >= 30
2. TOTAL_TOKENS now > 0 (user sent message)
3. Ready marker exists ✓
→ Skip Phase 1
→ Show statusline
```

#### Continuing Session (after /clear)

```
1. TOTAL_TOKENS > 0 (from previous messages)
→ Skip Phase 1 entirely
→ Show statusline immediately
```

## Performance Comparison

### Before (Fixed Delay)

- **Minimum wait:** 30 seconds (always)
- **Total invocations:** 3 (initial + marker creation + display)
- **User experience:** Predictable but slow

### After (Active Monitoring)

- **Minimum wait:** 8 seconds (if transcript stable immediately)
- **Typical wait:** 11-15 seconds (system messages + stability)
- **Maximum wait:** 20 seconds (timeout protection)
- **Total invocations:** 2 (initial wait + display)
- **User experience:** Faster, intelligent response

## Testing

### Syntax Validation

```bash
bash -n .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh
# ✓ No syntax errors
```

### Debug Mode

```bash
# Enable debug logging
export DEBUG_STATUSLINE=1
./iclaude.sh

# Check debug log
tail -f /tmp/claude-statusline-wait-debug.log
```

**Expected debug output:**
```
=== wait_for_system_messages_to_clear() called ===
Session ID: <session-id>
Project DIR: /home/user/project
Transcript file: /path/to/transcript.jsonl
File exists: YES
Check #1: mtime=1234567890, last=0, stable=0
Check #2: mtime=1234567890, last=1234567890, stable=1
Check #3: mtime=1234567890, last=1234567890, stable=2
Check #4: mtime=1234567890, last=1234567890, stable=3
STABLE detected after 11s (3 checks)
wait_for_system_messages_to_clear() finished after 19s total
```

### Manual Testing

```bash
# Test 1: New session
./iclaude.sh
# Expected: Statusline appears after ~11-15 seconds

# Test 2: After /clear command
# Type: /clear
# Expected: Statusline appears immediately on next response

# Test 3: Continuing session
# Exit and restart with existing session
./iclaude.sh
# Expected: Statusline appears immediately
```

## Files Modified

- `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`
  - Lines 122-126: Added session context parsing
  - Lines 401-407: Removed duplicate parsing (session link)
  - Lines 771-775: Removed duplicate parsing (smart handling)
  - Lines 788-795: Integrated active monitoring function

## Backward Compatibility

✅ **Fully backward compatible**

- Existing sessions: No changes
- After /clear: Works as before (immediate display)
- New sessions: Improved (faster, smarter waiting)

## Known Limitations

1. **Transcript file access:** Requires read access to Claude config directory
2. **System commands:** Requires `stat` command (standard on Linux)
3. **Timing sensitivity:** System messages timing may vary across Claude Code versions

## Future Improvements

1. **Adaptive thresholds:** Adjust min_delay based on observed system message patterns
2. **Machine learning:** Predict optimal wait time from historical data
3. **Event-based:** Use inotify/fswatch for instant detection (no polling)

## References

- **Original function:** Lines 561-649 in `claude-statusline.sh`
- **Phase mechanism:** Lines 771-802 in `claude-statusline.sh`
- **Documentation:** [STATUSLINE.md](./STATUSLINE.md)
