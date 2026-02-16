# Week 2: Streaming Mode Support - Implementation Plan

**Date:** 2026-02-13
**Status:** 🟡 Planning
**Estimated Time:** 5 hours
**Priority:** High

---

## Problem Statement

### Current Limitations

**Adapter system предполагает complete responses:**
```json
{
  "usage": {
    "prompt_tokens": 1000,
    "completion_tokens": 500
  }
}
```

**Streaming responses приходят по частям (SSE chunks):**
```json
// Chunk 1
{"type": "message_start", "message": {"usage": {"input_tokens": 1000}}}

// Chunk 2
{"type": "content_block_delta", "delta": {"text": "Hello"}}

// Chunk 3
{"type": "message_delta", "usage": {"output_tokens": 5}}

// Chunk 4 (final)
{"type": "message_stop"}
```

**Проблемы:**
1. ❌ Токены разбросаны по chunks (input в начале, output в конце)
2. ❌ Нет накопления состояния между chunks
3. ❌ Statusline показывает только финальный результат
4. ❌ Нет real-time progress tracking

---

## Requirements

### Functional Requirements

1. **Streaming Detection** - автоматически определять streaming vs non-streaming
2. **Token Accumulation** - собирать токены из chunks в real-time
3. **State Persistence** - сохранять состояние между chunks
4. **Real-time Display** - обновлять statusline во время генерации
5. **Provider Support** - работать со всеми провайдерами
6. **Backward Compatibility** - не ломать non-streaming режим

### Non-Functional Requirements

1. **Performance** - minimal overhead (<10ms per chunk)
2. **Reliability** - graceful handling incomplete streams
3. **Testability** - unit tests для streaming logic
4. **Documentation** - clear examples

---

## Architecture Design

### Component Overview

```
Streaming Request → Chunk Parser → State Accumulator → Statusline Display
                         ↓              ↓
                    Detection      State File
                                   (session-specific)
```

### Components

#### 1. Streaming Detection Module
**File:** `lib/streaming-detector.sh`

**Functions:**
- `is_streaming_chunk(data)` - detect if data is SSE chunk
- `get_chunk_type(data)` - extract chunk type (message_start, delta, stop)
- `is_final_chunk(data)` - check if stream completed

**Detection Logic:**
```bash
# Anthropic streaming format:
# - Has "type" field (message_start, content_block_delta, message_delta, message_stop)
# - Usage spread across chunks

# OpenAI streaming format:
# - Has "choices[].delta" field
# - Each chunk has partial completion

# Ollama streaming format:
# - Has "done: false/true" field
# - Progressive token counting
```

#### 2. State Management Module
**File:** `lib/streaming-state.sh`

**State File Location:**
```bash
$CLAUDE_DIR/streaming-state/$SESSION_ID.state
```

**State Format (JSON):**
```json
{
  "session_id": "abc123",
  "provider": "anthropic",
  "model": "claude-sonnet-4.5",
  "streaming": true,
  "input_tokens": 1000,
  "output_tokens": 127,
  "cache_read_tokens": 500,
  "cache_creation_tokens": 100,
  "chunks_received": 15,
  "last_update": 1707854321,
  "completed": false
}
```

**Functions:**
- `init_streaming_state(session_id, provider)` - create new state
- `update_streaming_state(session_id, data)` - accumulate tokens
- `get_streaming_state(session_id)` - read current state
- `finalize_streaming_state(session_id)` - mark as completed
- `cleanup_old_states()` - remove expired state files (>1 hour)

#### 3. Chunk Parser Module
**File:** `lib/streaming-parser.sh`

**Functions:**
- `parse_anthropic_chunk(chunk)` - parse Anthropic SSE format
- `parse_openai_chunk(chunk)` - parse OpenAI streaming format
- `parse_ollama_chunk(chunk)` - parse Ollama streaming format
- `parse_gemini_chunk(chunk)` - parse Gemini streaming format

**Example Anthropic Parser:**
```bash
parse_anthropic_chunk() {
    local chunk="$1"
    local chunk_type=$(echo "$chunk" | jq -r '.type')

    case "$chunk_type" in
        message_start)
            # Extract input tokens, cache tokens
            local input=$(jq -r '.message.usage.input_tokens // 0')
            local cache_read=$(jq -r '.message.usage.cache_read_input_tokens // 0')
            echo "{\"input_tokens\": $input, \"cache_read_tokens\": $cache_read}"
            ;;
        message_delta)
            # Extract output tokens
            local output=$(jq -r '.usage.output_tokens // 0')
            echo "{\"output_tokens\": $output}"
            ;;
        message_stop)
            echo "{\"completed\": true}"
            ;;
    esac
}
```

#### 4. Adapter Updates
**Files:** `lib/adapters/*.sh`

**Changes:**
- Add `parse_<provider>_streaming()` functions
- Check for streaming state before parsing complete response
- Fallback to state file if session data incomplete

**Example:**
```bash
parse_anthropic_data() {
    local session_data="$1"

    # Check if streaming mode
    if is_streaming_chunk "$session_data"; then
        # Parse as chunk and update state
        local chunk_data=$(parse_anthropic_chunk "$session_data")
        update_streaming_state "$SESSION_ID" "$chunk_data"

        # Return current accumulated state
        get_streaming_state "$SESSION_ID"
    else
        # Parse as complete response (existing logic)
        # ...
    fi
}
```

#### 5. Statusline Integration
**File:** `claude-statusline.sh`

**Changes:**
- Check for streaming state before parsing session
- Display streaming indicator (🔄 icon)
- Update more frequently during streaming (500ms vs 2s)
- Show "Generating..." status

**Display Format:**
```
50,000 total | 127 generating... 🔄 | Sonnet 4.5 | $1.06 (estimated)
```

---

## Implementation Plan

### Phase 1: Core Streaming Infrastructure (2 hours)

**Task 1.1: Create streaming-detector.sh**
- [ ] `is_streaming_chunk()` - detect SSE format
- [ ] `get_chunk_type()` - extract type field
- [ ] `is_final_chunk()` - completion detection
- [ ] Support Anthropic, OpenAI, Ollama formats
- [ ] Unit tests (10 tests)

**Task 1.2: Create streaming-state.sh**
- [ ] `init_streaming_state()` - initialize state file
- [ ] `update_streaming_state()` - accumulate tokens
- [ ] `get_streaming_state()` - read current state
- [ ] `finalize_streaming_state()` - mark completed
- [ ] `cleanup_old_states()` - garbage collection
- [ ] State directory creation
- [ ] File locking for concurrent access
- [ ] Unit tests (15 tests)

**Task 1.3: Create streaming-parser.sh**
- [ ] `parse_anthropic_chunk()` - Anthropic SSE
- [ ] `parse_openai_chunk()` - OpenAI streaming
- [ ] `parse_ollama_chunk()` - Ollama streaming
- [ ] `parse_gemini_chunk()` - Gemini streaming (if supported)
- [ ] Token extraction logic
- [ ] Unit tests (20 tests)

---

### Phase 2: Adapter Updates (1.5 hours)

**Task 2.1: Update provider-adapter.sh**
- [ ] Source streaming modules
- [ ] Add streaming detection to `parse_with_adapter()`
- [ ] Route to streaming vs non-streaming paths
- [ ] Integration with state management

**Task 2.2: Update adapters**
- [ ] `anthropic.sh` - add streaming support
- [ ] `openai.sh` - add streaming support
- [ ] `ollama.sh` - add streaming support
- [ ] `gemini.sh` - add streaming support (if applicable)
- [ ] `generic.sh` - best-effort streaming

**Task 2.3: Testing**
- [ ] Mock streaming chunks for each provider
- [ ] Test token accumulation
- [ ] Test state persistence
- [ ] Test completion detection
- [ ] Integration tests (10 tests)

---

### Phase 3: Statusline Integration (1 hour)

**Task 3.1: Update claude-statusline.sh**
- [ ] Check for streaming state
- [ ] Display streaming indicator (🔄)
- [ ] Show "generating..." status
- [ ] Real-time token count updates
- [ ] Estimated cost during streaming
- [ ] Faster refresh rate during streaming

**Task 3.2: Testing**
- [ ] Test with mock streaming state
- [ ] Test transition from streaming → complete
- [ ] Test display formatting

---

### Phase 4: Testing & Documentation (0.5 hours)

**Task 4.1: Comprehensive Testing**
- [ ] End-to-end streaming test
- [ ] Multiple concurrent streams
- [ ] Error handling (incomplete streams)
- [ ] State cleanup
- [ ] Performance profiling

**Task 4.2: Documentation**
- [ ] Update `lib/README.md` - streaming section
- [ ] Add streaming examples
- [ ] Update troubleshooting guide

---

## Technical Details

### Streaming Detection Logic

**Anthropic Claude:**
```json
// message_start
{"type": "message_start", "message": {"id": "msg_123", "usage": {"input_tokens": 1000}}}

// content_block_start
{"type": "content_block_start", "index": 0, "content_block": {"type": "text"}}

// content_block_delta (repeated)
{"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "Hello"}}

// content_block_stop
{"type": "content_block_stop", "index": 0}

// message_delta
{"type": "message_delta", "delta": {"stop_reason": "end_turn"}, "usage": {"output_tokens": 127}}

// message_stop
{"type": "message_stop"}
```

**OpenAI:**
```json
// Chunk format
{"id": "chatcmpl-123", "choices": [{"delta": {"content": "Hello"}, "index": 0}]}

// Final chunk
{"id": "chatcmpl-123", "choices": [{"delta": {}, "finish_reason": "stop"}]}
```

**Ollama:**
```json
// Chunk format
{"model": "llama3.1", "message": {"content": "Hello"}, "done": false}

// Final chunk
{"model": "llama3.1", "done": true, "total_duration": 123, "eval_count": 127}
```

---

### State File Management

**Directory Structure:**
```
$CLAUDE_DIR/streaming-state/
├── abc123.state          # Active streaming session
├── def456.state          # Active streaming session
└── .cleanup.lock         # Cleanup process lock
```

**Cleanup Policy:**
- States older than 1 hour → delete
- Completed states → keep for 5 minutes (для cache display)
- Run cleanup every 10 minutes (background cron)

**File Locking:**
```bash
# Acquire lock before writing
exec 200>/tmp/streaming-state-$SESSION_ID.lock
flock -n 200 || exit 1

# Write state
echo "$STATE_JSON" > "$STATE_FILE"

# Release lock
flock -u 200
```

---

## Testing Strategy

### Unit Tests

**Test Suite 1: Streaming Detection (10 tests)**
- ✅ Detect Anthropic message_start
- ✅ Detect OpenAI streaming chunk
- ✅ Detect Ollama done=false
- ✅ Detect Gemini streaming (if supported)
- ✅ Detect final chunks
- ✅ Handle non-streaming data
- ✅ Handle malformed chunks
- ✅ Edge cases (empty chunks, null)

**Test Suite 2: State Management (15 tests)**
- ✅ Initialize new state
- ✅ Update existing state (token accumulation)
- ✅ Read state
- ✅ Finalize state
- ✅ Cleanup old states
- ✅ File locking (concurrent access)
- ✅ State persistence across updates
- ✅ Handle corrupted state files
- ✅ Directory creation
- ✅ Session ID validation

**Test Suite 3: Chunk Parsing (20 tests)**
- ✅ Parse Anthropic message_start (input tokens)
- ✅ Parse Anthropic message_delta (output tokens)
- ✅ Parse Anthropic cache tokens
- ✅ Parse OpenAI delta chunks
- ✅ Parse OpenAI finish_reason
- ✅ Parse Ollama chunks
- ✅ Parse Ollama done=true
- ✅ Token extraction accuracy
- ✅ Handle missing fields
- ✅ Handle malformed JSON

**Test Suite 4: Integration (10 tests)**
- ✅ End-to-end streaming flow
- ✅ Multi-chunk accumulation
- ✅ Provider-specific formats
- ✅ State → unified format conversion
- ✅ Statusline integration
- ✅ Concurrent streams
- ✅ Error recovery
- ✅ Cleanup after completion

**Total Tests:** 55 new tests (+ existing 27 = 82 total)

---

## Edge Cases & Error Handling

### Edge Cases

1. **Incomplete Stream**
   - Connection lost mid-stream
   - No final chunk received
   - **Solution:** Timeout after 5 minutes, mark as error

2. **Duplicate Chunks**
   - Same chunk received twice
   - **Solution:** Idempotent updates (don't double-count)

3. **Out-of-Order Chunks**
   - message_delta before message_start
   - **Solution:** Buffer chunks until message_start

4. **Concurrent Streams**
   - Multiple sessions streaming simultaneously
   - **Solution:** Per-session state files + locking

5. **State Corruption**
   - Partial write, filesystem error
   - **Solution:** Atomic writes + validation

### Error Handling

```bash
# Graceful degradation
if ! update_streaming_state "$SESSION_ID" "$CHUNK"; then
    # Fallback to non-streaming mode
    [[ "${DEBUG_STATUSLINE:-0}" == "1" ]] && \
        echo "[WARN] Streaming state update failed, falling back to non-streaming" >&2

    # Continue with best-effort parsing
fi
```

---

## Performance Considerations

### Optimization Targets

- **Chunk parsing:** <5ms per chunk
- **State update:** <10ms (file I/O)
- **Statusline refresh:** 500ms during streaming (vs 2s normal)
- **State cleanup:** <100ms (async background)

### Optimizations

1. **Minimal jq calls** - parse only needed fields
2. **File locking** - fast acquire/release
3. **Atomic writes** - write to temp, then rename
4. **Lazy cleanup** - background process, not inline
5. **State caching** - keep in memory during active stream

---

## Backward Compatibility

### Guarantees

✅ **Non-streaming mode unchanged**
- Complete responses use existing logic
- No performance impact
- Same output format

✅ **Graceful degradation**
- If streaming detection fails → fallback to complete parsing
- If state file unavailable → best-effort display
- If chunks malformed → show partial data

✅ **Existing tests pass**
- All 27 existing unit tests still pass
- No breaking changes to adapters

---

## Success Criteria

### Acceptance Criteria

✅ **Functional:**
- [ ] Streaming chunks correctly detected
- [ ] Tokens accumulated in real-time
- [ ] Statusline updates during generation
- [ ] All 5 providers supported
- [ ] Final state matches complete response

✅ **Performance:**
- [ ] <5ms chunk parsing
- [ ] <10ms state update
- [ ] <100ms cleanup overhead

✅ **Testing:**
- [ ] 55 new unit tests passing
- [ ] Integration tests with mock streams
- [ ] All existing tests still pass (27)

✅ **Documentation:**
- [ ] Updated lib/README.md
- [ ] Streaming examples
- [ ] Troubleshooting guide

---

## Timeline

**Day 1 (Today):**
- Phase 1: Core infrastructure (2h)
- Phase 2: Adapter updates (1.5h)

**Day 2 (If needed):**
- Phase 3: Statusline integration (1h)
- Phase 4: Testing & docs (0.5h)

**Total:** ~5 hours

---

## Risks & Mitigation

### Risk 1: Complex State Management
**Risk:** File locking issues, race conditions
**Mitigation:**
- Use flock for atomic operations
- Extensive concurrent access testing
- Fallback to in-memory state if file I/O fails

### Risk 2: Provider Format Variations
**Risk:** Streaming formats differ across providers
**Mitigation:**
- Provider-specific parsers
- Generic fallback parser
- Comprehensive test coverage

### Risk 3: Performance Overhead
**Risk:** State I/O slows down chunk processing
**Mitigation:**
- Async writes where possible
- In-memory caching
- Performance profiling

---

**Plan Status:** 🟡 Ready for Implementation
**Next Step:** Begin Phase 1 - Core Streaming Infrastructure
