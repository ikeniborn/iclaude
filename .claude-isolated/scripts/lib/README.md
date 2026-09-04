# Provider Adapter System

Multi-provider support for Claude Code statusline with automatic format detection and cost calculation.

## Architecture

```
Session JSON → Provider Detection → Adapter Selection → Unified Format → Statusline Display
                      ↓
            ┌─────────┴─────────┐
       anthropic  openai  ollama  gemini  generic
            ↓       ↓       ↓       ↓       ↓
          Claude  DeepSeek Local  Google  Unknown
```

## Components

### 1. Provider Adapter Factory (`provider-adapter.sh`)

**Core functions:**

- `detect_provider_type(session_data)` - Auto-detects provider from JSON structure
- `get_provider_adapter(provider_type)` - Returns path to adapter script
- `create_unified_data(...)` - Creates standardized data format
- `parse_with_adapter(session_data)` - Main entry point, sets global variables

**Provider detection logic:**

```bash
Anthropic: .context_window.total_input_tokens (Claude format)
OpenAI:    .usage.prompt_tokens (OpenAI-compatible)
Ollama:    .usage.prompt_tokens + local model names (llama*, mistral*, etc.)
Gemini:    .usageMetadata.promptTokenCount (Google format)
Generic:   Fallback for unknown formats
```

### 2. Pricing Lookup Module (`pricing-lookup.sh`)

**Pricing database:**
- 30+ models with input/output pricing (USD per 1M tokens)
- Updated: 2026-02-13

**Functions:**

- `calculate_cost(model, input_tokens, output_tokens)` - Returns USD cost
- `normalize_model_name(model)` - Handles version suffixes
- `get_model_display_name(model)` - Friendly names

**Supported models:**
- OpenAI: gpt-4, gpt-4o, gpt-3.5-turbo, o1, o1-mini
- DeepSeek: deepseek-chat, deepseek-coder, deepseek-r1
- Gemini: gemini-2.5-pro, gemini-2.0-flash, gemini-1.5-pro
- Anthropic: claude-opus-4, claude-sonnet-4.5, claude-haiku-4

### 3. Provider Adapters (`adapters/`)

#### Anthropic Adapter (`anthropic.sh`)

**Format:** Claude API (native)
**Fields:** `.context_window.*`, `.cost.total_cost_usd`
**Cache:** Yes (cache_read, cache_creation)
**Cost:** Pre-calculated by API
**Icon:** None (native provider)

**100% backward compatible** with original statusline.sh logic.

#### OpenAI Adapter (`openai.sh`)

**Format:** OpenAI Chat Completions API
**Fields:** `.usage.prompt_tokens`, `.usage.completion_tokens`
**Cache:** No
**Cost:** Calculated via pricing-lookup.sh
**Icon:** 🤖

**Compatible with:**
- OpenAI (gpt-4, gpt-3.5-turbo, o1)
- DeepSeek (deepseek-chat, deepseek-coder)
- OpenRouter (various models)

**Context limits:**
- gpt-4o: 128K
- deepseek-chat: 64K
- Default: 8K

#### Ollama Adapter (`ollama.sh`)

**Format:** OpenAI-compatible (local)
**Fields:** `.usage.prompt_tokens`, `.usage.completion_tokens`
**Cache:** No
**Cost:** 0 (local models are free)
**Icon:** 🦙

**Supported models:**
- Llama: llama3.1, llama3.3 (8K context)
- Mistral: mistral, mixtral (8-32K context)
- Qwen: qwen2.5, qwen2.5-coder (32K context)
- Code models: codellama, deepseek-coder (16K context)

#### Gemini Adapter (`gemini.sh`)

**Format:** Google Gemini REST API
**Fields:** `.usageMetadata.promptTokenCount`, `.usageMetadata.candidatesTokenCount`
**Cache:** No (not reported in API)
**Cost:** Calculated via pricing-lookup.sh
**Icon:** ✨

**Supported models:**
- Gemini 2.5 Pro (2M context)
- Gemini 2.5 Flash (1M context)
- Gemini 1.5 Pro/Flash

#### Generic Adapter (`generic.sh`)

**Format:** Best-effort parsing
**Strategy:** Tries multiple field patterns
**Cache:** No
**Cost:** 0 (unknown pricing)
**Icon:** ❓

**Fallback patterns:**
- `.usage.*`, `.tokens.*`, top-level fields
- Common aliases: `input_tokens`, `output_tokens`
- Always succeeds (returns valid data even with minimal info)

### 4. Streaming Support Modules (NEW - Week 2)

#### Streaming Detector (`streaming-detector.sh`)

**Functions:**
- `is_streaming_chunk(data)` - Detect SSE chunk vs complete response
- `get_chunk_type(data)` - Extract type (start, delta, stop, ping)
- `is_final_chunk(data)` - Check if stream completed
- `get_streaming_provider(data)` - Auto-detect provider from chunk

**Supported formats:**
- **Anthropic**: message_start, content_block_delta, message_delta, message_stop
- **OpenAI**: choices[].delta with finish_reason
- **Ollama**: done: false/true
- **Gemini**: candidates[].finishReason

#### State Management (`streaming-state.sh`)

**Functions:**
- `init_streaming_state(session_id, provider, model)` - Create session state
- `update_streaming_state(session_id, data)` - Accumulate tokens from chunks
- `get_streaming_state(session_id)` - Read current accumulated state
- `finalize_streaming_state(session_id)` - Mark stream as completed
- `is_streaming_active(session_id)` - Check if streaming in progress
- `cleanup_old_states()` - Remove states older than 1 hour

**State file location:**
```
$CLAUDE_DIR/streaming-state/$SESSION_ID.state
```

**State format:**
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

#### Chunk Parser (`streaming-parser.sh`)

**Functions:**
- `parse_anthropic_chunk(chunk)` - Extract tokens from Anthropic SSE events
- `parse_openai_chunk(chunk)` - Parse OpenAI streaming delta
- `parse_ollama_chunk(chunk)` - Parse Ollama done=true format
- `parse_gemini_chunk(chunk)` - Parse Gemini streaming response
- `parse_streaming_chunk(chunk)` - Auto-detect and parse

**Anthropic chunk example:**
```json
// message_start
{"type":"message_start","message":{"usage":{"input_tokens":1000}}}

// message_delta
{"type":"message_delta","usage":{"output_tokens":50}}

// message_stop
{"type":"message_stop"}
```

**Token accumulation:**
- `message_start` → Initialize input tokens, cache tokens
- `message_delta` → Accumulate output tokens
- `message_stop` → Mark completed

#### Integration with Provider Adapter

**Streaming detection in `parse_with_adapter()`:**
1. Check if data is streaming chunk (via `is_streaming_chunk()`)
2. If streaming:
   - Get provider from chunk
   - Parse chunk (extract tokens)
   - Initialize state (first chunk) or update state (subsequent chunks)
   - Return accumulated state for display
3. If not streaming:
   - Use existing adapter logic (complete response)

**Session-based state:**
- Each session has unique state file
- State persists across chunks
- Automatic cleanup after 1 hour

**Real-time display:**
- Statusline shows accumulated tokens during streaming
- 🔄 indicator appears when `STREAMING_ACTIVE=1`
- Updates on each chunk received

## Unified Data Format

All adapters return this JSON structure:

```json
{
  "total_input_tokens": 50000,
  "total_output_tokens": 10000,
  "context_limit": 200000,
  "cache_read_tokens": 1000,
  "cache_creation_tokens": 500,
  "model_name": "Claude Sonnet 4.5",
  "total_cost_usd": 1.05
}
```

## Integration with Statusline

**File:** `../claude-statusline.sh`

**Integration points:**

1. **Line 51-65:** Source adapter system and call `parse_with_adapter()`
2. **Line 85-103:** Legacy fallback (if adapters unavailable)
3. **Line 146-151:** Parse cost (conditional)
4. **Line 179-201:** Provider icon display
5. **Line 737:** Full mode output with `${PROVIDER_ICON}`
6. **Line 755:** Compact mode output with `${PROVIDER_ICON}`

**Global variables set by adapters:**

```bash
TOTAL_INPUT      # Input tokens
TOTAL_OUTPUT     # Output tokens
CONTEXT_LIMIT    # Context window size
CACHE_READ       # Cache read tokens
CACHE_CREATION   # Cache creation tokens
MODEL            # Model display name
COST             # Total cost USD (formatted)
PROVIDER_TYPE    # Provider type (for icon)
```

## Usage

### Automatic Mode (Default)

Statusline automatically detects provider and uses appropriate adapter:

```bash
# Works with any provider
cat session.json | claude-statusline.sh
```

### Debug Mode

Enable verbose logging:

```bash
export DEBUG_STATUSLINE=1
cat session.json | claude-statusline.sh
```

**Debug output shows:**
- Provider detection result
- Adapter path used
- Unified data structure
- Parsed values

### Manual Testing

Test individual adapters:

```bash
# Run all unit tests
./test/test-adapters.sh

# Test specific provider
cat test/fixtures/openai-session.json | claude-statusline.sh
```

## Adding New Providers

To add a new provider adapter:

1. **Create adapter file:** `adapters/my-provider.sh`

2. **Implement parse function:**

```bash
#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/../provider-adapter.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../pricing-lookup.sh"

parse_my_provider_data() {
    local session_data="$1"

    # Parse tokens
    local input=$(echo "$session_data" | jq -r '.my_field.input')
    local output=$(echo "$session_data" | jq -r '.my_field.output')

    # Get model name
    local model=$(echo "$session_data" | jq -r '.model')

    # Calculate cost
    local cost=$(calculate_cost "$model" "$input" "$output")

    # Return unified format
    create_unified_data "$input" "$output" 128000 0 0 "$model" "$cost"
}

export -f parse_my_provider_data
```

3. **Update detection logic** in `provider-adapter.sh`:

```bash
detect_provider_type() {
    # ... existing logic ...

    # Add new provider detection
    local has_my_field=$(echo "$session_data" | jq -r 'has("my_field")')
    if [[ "$has_my_field" == "true" ]]; then
        echo "my-provider"
        return 0
    fi

    # ... rest of logic ...
}
```

4. **Add icon** in `claude-statusline.sh`:

```bash
case "$PROVIDER_TYPE" in
    # ... existing cases ...
    my-provider)
        PROVIDER_ICON=" 🎯"
        ;;
esac
```

5. **Add pricing** (if applicable) in `pricing-lookup.sh`:

```bash
declare -gA MODEL_PRICING_INPUT=(
    # ... existing models ...
    ["my-model"]="1.50"
)

declare -gA MODEL_PRICING_OUTPUT=(
    # ... existing models ...
    ["my-model"]="5.00"
)
```

6. **Create test fixture:** `test/fixtures/my-provider-session.json`

7. **Add test case** in `test/test-adapters.sh`

## Troubleshooting

### Adapter not loading

**Symptom:** Statusline shows "[awaiting session data...]"

**Causes:**
- Adapter system unavailable (missing lib/ directory)
- Provider not detected (unknown format)
- JSON parsing error

**Fix:**
```bash
# Check adapter availability
ls -la .claude-isolated/scripts/lib/

# Enable debug mode
export DEBUG_STATUSLINE=1

# Check provider detection
cat session.json | jq . # Validate JSON
```

### Wrong provider detected

**Symptom:** Incorrect icon or cost

**Debug:**
```bash
export DEBUG_STATUSLINE=1
cat session.json | claude-statusline.sh 2>&1 | grep "Detected provider"
```

**Common issues:**
- Ollama detected as OpenAI (model name not in pattern)
- Generic fallback used (add explicit detection)

### Cost calculation incorrect

**Symptom:** Cost is $0.00 or wrong amount

**Causes:**
- Model not in pricing database
- Pricing outdated
- Unknown provider

**Fix:**
```bash
# Check model name
cat session.json | jq '.model'

# Add to pricing-lookup.sh if missing
# Or update existing pricing
```

### Cache not showing

**Symptom:** No 📦 icon

**Causes:**
- Provider doesn't support cache (OpenAI, Ollama, Gemini)
- Cache tokens are 0
- Anthropic-only feature

**Expected behavior:**
- Anthropic: Cache shown when present
- Others: No cache support (by design)

## Performance

**Overhead:** ~20-50ms per statusline refresh

**Optimizations:**
- Lazy loading (adapters sourced only when needed)
- No network calls (all pricing hardcoded)
- Minimal jq operations
- Exit early on errors

## Backward Compatibility

**Legacy mode:** If adapter system unavailable, statusline falls back to original Anthropic-only parsing.

**Compatibility guarantee:**
- Existing users see no changes
- Native Claude API works identically
- No breaking changes to output format

## Testing

**Unit tests:** `test/test-adapters.sh`
- 27 tests covering all adapters
- Provider detection tests
- Integration tests

**Integration tests:** `test/test-statusline-integration.sh`
- End-to-end tests with real statusline
- Tests all providers with mock fixtures

**Run all tests:**
```bash
cd .claude-isolated/scripts/test
./test-adapters.sh
./test-statusline-integration.sh
```

## Future Extensions

**Potential additions:**
- Volcengine provider
- SiliconFlow provider
- Custom provider plugins
- Dynamic pricing updates
- Cache support for Gemini (when API supports)
- Streaming mode detection

## License

Part of iclaude project. Same license as parent project.
