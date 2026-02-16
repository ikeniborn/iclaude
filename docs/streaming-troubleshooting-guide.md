# Streaming Mode Troubleshooting Guide

**Version:** 4.2.0
**Last Updated:** 2026-02-13

Comprehensive troubleshooting guide for streaming mode issues in Claude Code statusline.

---

## Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Common Issues](#common-issues)
3. [Streaming Detection Problems](#streaming-detection-problems)
4. [State Management Issues](#state-management-issues)
5. [Display Problems](#display-problems)
6. [Performance Issues](#performance-issues)
7. [Provider-Specific Issues](#provider-specific-issues)
8. [Debug Mode](#debug-mode)
9. [Recovery Procedures](#recovery-procedures)
10. [FAQ](#faq)

---

## Quick Diagnostics

### Is Streaming Mode Working?

**Check 1: Streaming modules available**
```bash
ls -la .nvm-isolated/.claude-isolated/scripts/lib/streaming-*.sh
```
Expected: 3 files (detector, state, parser)

**Check 2: Test streaming detection**
```bash
source lib/streaming-detector.sh
CHUNK='{"type":"message_start","message":{"id":"msg_123"}}'
is_streaming_chunk "$CHUNK" && echo "✅ Working" || echo "❌ Failed"
```

**Check 3: State directory exists**
```bash
ls -la ~/.claude-code/streaming-state/
```
Expected: Directory exists (may be empty)

**Check 4: Statusline integration**
```bash
grep -n "STREAMING_ICON" .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh
```
Expected: Found on lines 207-211, 743, 761

---

## Common Issues

### Issue 1: Streaming icon (🔄) not showing

**Symptoms:**
- Tokens update during streaming
- But no 🔄 icon appears

**Diagnosis:**
```bash
# Check if STREAMING_ACTIVE is set
echo "STREAMING_ACTIVE=${STREAMING_ACTIVE:-not set}"

# Should output: STREAMING_ACTIVE=1 during streaming
```

**Causes & Solutions:**

**Cause A: parse_with_adapter() called without session_id**
```bash
# ❌ Wrong - no session_id
parse_with_adapter "$CHUNK"

# ✅ Correct - with session_id
parse_with_adapter "$CHUNK" "$SESSION_ID"
```

**Cause B: Statusline cached before STREAMING_ACTIVE set**
- **Solution:** Force statusline refresh after parsing chunk

**Cause C: STREAMING_ICON not added to display**
- **Check:** `grep STREAMING_ICON claude-statusline.sh`
- **Solution:** Re-apply Phase 3 changes

---

### Issue 2: Tokens not accumulating

**Symptoms:**
- First chunk shows correct tokens
- Subsequent chunks don't add tokens
- Output stays at 0

**Diagnosis:**
```bash
# Check state file
export SESSION_ID="your_session_id"
cat ~/.claude-code/streaming-state/$SESSION_ID.state | jq .

# Check chunks_received counter
jq '.chunks_received' ~/.claude-code/streaming-state/$SESSION_ID.state
```

**Causes & Solutions:**

**Cause A: State file not updating**
```bash
# Check file permissions
ls -l ~/.claude-code/streaming-state/$SESSION_ID.state

# Should be: -rw-r--r-- (644) or -rw------- (600)
```
**Solution:** Fix permissions
```bash
chmod 644 ~/.claude-code/streaming-state/$SESSION_ID.state
```

**Cause B: update_streaming_state() failing silently**
```bash
# Enable debug mode
export DEBUG_STATUSLINE=1

# Re-run parsing
parse_with_adapter "$CHUNK" "$SESSION_ID"

# Check for errors in output
```

**Cause C: Chunk data parsing returns empty**
```bash
# Test chunk parsing
source lib/streaming-parser.sh
PARSED=$(parse_streaming_chunk "$CHUNK")
echo "$PARSED" | jq .

# Should return valid JSON with token fields
```

---

### Issue 3: State files accumulating (disk space)

**Symptoms:**
- Many old .state files in streaming-state/
- Disk usage increasing

**Diagnosis:**
```bash
# Count state files
ls ~/.claude-code/streaming-state/*.state | wc -l

# Check oldest files
ls -lt ~/.claude-code/streaming-state/ | tail -10

# Check disk usage
du -sh ~/.claude-code/streaming-state/
```

**Solutions:**

**Solution A: Manual cleanup**
```bash
# Remove states older than 1 hour
find ~/.claude-code/streaming-state/ -name "*.state" -mmin +60 -delete

# Or use built-in cleanup
source lib/streaming-state.sh
cleanup_old_states
```

**Solution B: Automatic cleanup cron**
```bash
# Add to crontab (every 10 minutes)
*/10 * * * * bash -c 'source ~/.claude-code/scripts/lib/streaming-state.sh && cleanup_old_states'
```

**Solution C: Check cleanup is running**
```bash
# Verify cleanup function works
source lib/streaming-state.sh
COUNT=$(cleanup_old_states)
echo "Cleaned up: $COUNT files"
```

---

### Issue 4: Streaming never completes

**Symptoms:**
- 🔄 icon stays forever
- completed=false in state
- No final chunk received

**Diagnosis:**
```bash
# Check state completion status
jq '.completed' ~/.claude-code/streaming-state/$SESSION_ID.state

# Check last update timestamp
LAST_UPDATE=$(jq '.last_update' ~/.claude-code/streaming-state/$SESSION_ID.state)
NOW=$(date +%s)
AGE=$((NOW - LAST_UPDATE))
echo "State age: ${AGE}s"
```

**Causes & Solutions:**

**Cause A: Connection lost mid-stream**
- **Solution:** Timeout after 5 minutes (manual finalization)
```bash
# Force finalize
source lib/streaming-state.sh
finalize_streaming_state "$SESSION_ID"
```

**Cause B: Final chunk not detected**
```bash
# Check chunk type detection
FINAL_CHUNK='{"type":"message_stop"}'
is_final_chunk "$FINAL_CHUNK" && echo "Detected" || echo "Not detected"
```

**Cause C: Provider-specific completion format**
- **OpenAI:** Check for `finish_reason`
- **Ollama:** Check for `done: true`
- **Gemini:** Check for `finishReason`

---

## Streaming Detection Problems

### Problem: Complete response detected as streaming

**Symptoms:**
- Non-streaming request shows 🔄 icon
- State file created for complete response

**Diagnosis:**
```bash
# Test detection
COMPLETE='{"usage":{"prompt_tokens":1000,"completion_tokens":500}}'
is_streaming_chunk "$COMPLETE" && echo "❌ False positive" || echo "✅ Correct"
```

**Solution:**
- Check response format matches non-streaming signature
- Verify detection logic in streaming-detector.sh

### Problem: Streaming chunk detected as complete

**Symptoms:**
- Streaming request processed as complete
- No 🔄 icon
- No state file

**Diagnosis:**
```bash
# Test detection
CHUNK='{"type":"message_delta","usage":{"output_tokens":50}}'
is_streaming_chunk "$CHUNK" && echo "✅ Correct" || echo "❌ False negative"
```

**Solution:**
- Verify chunk format matches provider specification
- Check provider detection logic

---

## State Management Issues

### Problem: State file corrupted

**Symptoms:**
- jq parse errors
- State file contains partial JSON

**Diagnosis:**
```bash
# Validate JSON
jq . ~/.claude-code/streaming-state/$SESSION_ID.state

# Check file integrity
cat ~/.claude-code/streaming-state/$SESSION_ID.state
```

**Recovery:**
```bash
# Delete corrupted state
rm ~/.claude-code/streaming-state/$SESSION_ID.state

# Reinitialize
source lib/streaming-state.sh
init_streaming_state "$SESSION_ID" "anthropic" "claude-sonnet-4.5"
```

### Problem: Concurrent access conflicts

**Symptoms:**
- State updates lost
- Inconsistent token counts

**Diagnosis:**
```bash
# Check for multiple processes
ps aux | grep streaming

# Check file locks
lsof ~/.claude-code/streaming-state/$SESSION_ID.state
```

**Solution:**
- Implement file locking (future enhancement)
- Use unique session IDs per process

---

## Display Problems

### Problem: Statusline shows "[awaiting session data...]"

**Symptoms:**
- No metrics displayed
- Even though chunks received

**Diagnosis:**
```bash
# Check if state file exists
ls ~/.claude-code/streaming-state/$SESSION_ID.state

# Check state content
cat ~/.claude-code/streaming-state/$SESSION_ID.state | jq .
```

**Solutions:**

**If state exists:**
```bash
# Check parse_with_adapter return value
parse_with_adapter "$CHUNK" "$SESSION_ID"
echo $?  # Should be 0
```

**If state missing:**
```bash
# Verify session_id passed
echo "SESSION_ID=$SESSION_ID"  # Must not be empty
```

### Problem: Display format broken

**Symptoms:**
- Extra spaces or missing separators
- Icons overlapping

**Diagnosis:**
```bash
# Check STREAMING_ICON value
echo "STREAMING_ICON='$STREAMING_ICON'"

# Check PROVIDER_ICON value
echo "PROVIDER_ICON='$PROVIDER_ICON'"
```

**Solution:**
- Verify icon variables have leading space: " 🔄"
- Check STATUS_LINE construction in claude-statusline.sh

---

## Performance Issues

### Problem: Slow chunk processing

**Symptoms:**
- Lag between chunks
- Statusline updates delayed

**Diagnosis:**
```bash
# Measure chunk processing time
time parse_with_adapter "$CHUNK" "$SESSION_ID"

# Should be < 50ms
```

**Solutions:**

**If > 50ms:**
1. Check disk I/O
```bash
# Monitor I/O
iostat -x 1
```

2. Profile with DEBUG mode
```bash
export DEBUG_STATUSLINE=1
# Look for slow operations in debug output
```

3. Check state file size
```bash
# State files should be < 1KB
ls -lh ~/.claude-code/streaming-state/$SESSION_ID.state
```

### Problem: High CPU usage

**Diagnosis:**
```bash
# Monitor CPU during streaming
top -p $(pgrep -f streaming)
```

**Solutions:**
- Reduce jq operations (use cached values)
- Optimize regex patterns in detection
- Batch state updates (future enhancement)

---

## Provider-Specific Issues

### Anthropic Streaming

**Problem: Cache tokens not showing**
```bash
# Check message_start parsing
CHUNK='{"type":"message_start","message":{"usage":{"cache_read_input_tokens":500}}}'
PARSED=$(parse_anthropic_chunk "$CHUNK")
echo "$PARSED" | jq '.cache_read_tokens'
# Should output: 500
```

**Problem: Output tokens not accumulating**
```bash
# Check message_delta parsing
CHUNK='{"type":"message_delta","usage":{"output_tokens":50}}'
PARSED=$(parse_anthropic_chunk "$CHUNK")
echo "$PARSED" | jq '.output_tokens'
# Should output: 50
```

### OpenAI Streaming

**Problem: Tokens always 0**
- **Expected:** OpenAI doesn't provide per-chunk tokens
- **Workaround:** Wait for final chunk with usage summary

**Problem: Never completes**
```bash
# Check finish_reason detection
CHUNK='{"choices":[{"delta":{},"finish_reason":"stop"}]}'
is_final_chunk "$CHUNK" && echo "Detected" || echo "Not detected"
```

### Ollama Streaming

**Problem: Tokens only on last chunk**
- **Expected:** Ollama provides counts in done=true chunk
- **Behavior:** Normal, not a bug

**Problem: Not detected as Ollama**
```bash
# Check model name pattern
MODEL="llama3.1"
if [[ "$MODEL" =~ ^(llama|mistral|qwen|...) ]]; then
    echo "Matched"
else
    echo "Not matched - update regex in provider-adapter.sh"
fi
```

---

## Debug Mode

### Enable Debug Logging

```bash
export DEBUG_STATUSLINE=1
```

### Debug Output Interpretation

**Normal flow:**
```
[DEBUG] Streaming chunk detected
[DEBUG] Streaming provider: anthropic
[DEBUG] Streaming state initialized: msg_123
[DEBUG] Streaming state updated: msg_123 (chunks: 1, output: 0)
[DEBUG] Streaming state updated: msg_123 (chunks: 2, output: 50)
[DEBUG] Streaming state finalized: msg_123
```

**Problem indicators:**
- `[DEBUG] Failed to parse streaming chunk` - Parser issue
- `[DEBUG] Adapter not found` - Module loading issue
- `[DEBUG] State file not found` - Initialization issue

### Verbose Testing

```bash
# Test full streaming flow with debug
export DEBUG_STATUSLINE=1
export SESSION_ID="test_$(date +%s)"

# Chunk 1
parse_with_adapter '{"type":"message_start",...}' "$SESSION_ID"

# Chunk 2
parse_with_adapter '{"type":"message_delta",...}' "$SESSION_ID"

# Check state
cat ~/.claude-code/streaming-state/$SESSION_ID.state | jq .

# Cleanup
delete_streaming_state "$SESSION_ID"
```

---

## Recovery Procedures

### Complete Reset

```bash
# 1. Stop all streaming sessions
# (no active claude processes)

# 2. Remove all state files
rm -rf ~/.claude-code/streaming-state/*

# 3. Recreate directory
mkdir -p ~/.claude-code/streaming-state

# 4. Test basic functionality
source lib/streaming-state.sh
init_streaming_state "test_session" "anthropic" "claude-sonnet-4.5"

# 5. Verify state created
ls ~/.claude-code/streaming-state/
```

### Reinitialize Single Session

```bash
# 1. Get session ID
SESSION_ID="msg_abc123"

# 2. Delete existing state
delete_streaming_state "$SESSION_ID"

# 3. Reinitialize
init_streaming_state "$SESSION_ID" "anthropic" "claude-sonnet-4.5"

# 4. Resume streaming
parse_with_adapter "$NEXT_CHUNK" "$SESSION_ID"
```

### Module Reload

```bash
# 1. Unset functions
unset -f is_streaming_chunk get_chunk_type parse_streaming_chunk

# 2. Re-source modules
source lib/streaming-detector.sh
source lib/streaming-state.sh
source lib/streaming-parser.sh

# 3. Verify
declare -f is_streaming_chunk > /dev/null && echo "✅ Loaded"
```

---

## FAQ

### Q1: Does streaming mode work with Router?

**A:** Yes, streaming mode is provider-agnostic. Router passes chunks through, and the adapter system detects the provider from chunk format.

### Q2: Can I disable streaming mode?

**A:** Streaming mode is auto-detected. To force non-streaming:
```bash
# Don't pass session_id to parse_with_adapter
parse_with_adapter "$DATA"  # No session_id = non-streaming path
```

### Q3: Why is cost $0.00 during streaming?

**A:** Cost calculation requires complete token counts. Cost updates after stream completes.

### Q4: Can multiple sessions stream simultaneously?

**A:** Yes, each session has isolated state file. No conflicts.

### Q5: What happens if statusline crashes mid-stream?

**A:** State file persists. On restart, can continue from last known state (manual recovery needed).

### Q6: How do I cleanup abandoned sessions?

**A:** Automatic cleanup runs via `cleanup_old_states()` (1 hour expiry). Or manual:
```bash
find ~/.claude-code/streaming-state/ -name "*.state" -mmin +60 -delete
```

### Q7: Does streaming mode increase latency?

**A:** No. Overhead is <15ms per chunk, imperceptible in real-world usage.

### Q8: Can I customize the streaming icon?

**A:** Yes, edit claude-statusline.sh:
```bash
# Line 209-210
STREAMING_ICON=" 🔄"  # Change to your preferred icon
```

### Q9: Why don't I see token counts for OpenAI streaming?

**A:** OpenAI doesn't provide per-chunk token counts. Counts appear in final chunk.

### Q10: How do I report a streaming bug?

**A:**
1. Enable debug mode: `export DEBUG_STATUSLINE=1`
2. Capture debug output
3. Include: chunk format, provider, expected vs actual behavior
4. Create issue on GitHub

---

## Getting Help

### Before Asking for Help

1. ✅ Enable debug mode
2. ✅ Check this troubleshooting guide
3. ✅ Verify modules are loaded
4. ✅ Test with mock chunks
5. ✅ Check state files manually

### Include in Bug Reports

- Claude Code version
- Provider (Anthropic, OpenAI, Ollama, Gemini)
- Sample chunk (sanitized)
- Debug output
- Expected vs actual behavior
- State file content (if relevant)

### Support Resources

- **GitHub Issues:** https://github.com/anthropics/claude-code/issues
- **Documentation:** docs/week2-streaming-mode-summary.md
- **Architecture:** lib/README.md (Section 4: Streaming Support)

---

**Last Updated:** 2026-02-13
**Version:** 4.2.0
**Streaming Mode:** Production-ready ✅
