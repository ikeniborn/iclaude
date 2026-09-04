# Claude Statusline Documentation

Complete documentation for `claude-statusline.sh` - custom status line script for Claude Code.

## Overview

### Purpose

Provide real-time session statistics in Claude Code status bar, displaying context usage, cost, cache metrics, and session metadata.

### Data Source

Receives JSON session data via STDIN from Claude Code. The script parses this data and formats it for display in the status bar.

### Required Version

Claude Code v2.1+ (uses nested `context_window` object)

### Script Location

`.claude-isolated/scripts/claude-statusline.sh`

## ✨ Multi-Provider Support (NEW)

**Version:** 4.1+ (February 2026)

Status line now automatically detects and supports multiple LLM providers:

### Supported Providers

| Provider | Icon | Cost Calculation | Cache Support | Notes |
|----------|------|------------------|---------------|-------|
| **Anthropic** (Claude) | None | Pre-calculated | ✅ Yes | Native provider, 100% backward compatible |
| **OpenAI** | 🤖 | Calculated | ❌ No | gpt-4, gpt-3.5-turbo, o1 models |
| **DeepSeek** | 🤖 | Calculated | ❌ No | deepseek-chat, deepseek-coder, deepseek-r1 |
| **OpenRouter** | 🤖 | Calculated | ❌ No | Various models via OpenRouter API |
| **Ollama** | 🦙 | Zero (local) | ❌ No | Local models (llama, mistral, qwen, etc.) |
| **Gemini** | ✨ | Calculated | ❌ No | Google Gemini API (2.5 Pro, 2.0 Flash) |
| **Unknown** | ❓ | Zero | ❌ No | Generic fallback for unrecognized providers |

### Provider Detection

Automatic detection based on JSON structure:

```bash
# Anthropic Claude format
{ "context_window": { "total_input_tokens": ... } }

# OpenAI-compatible format (OpenAI, DeepSeek, OpenRouter)
{ "usage": { "prompt_tokens": ..., "completion_tokens": ... } }

# Ollama format (OpenAI-compatible + local model names)
{ "usage": { ... }, "model": "llama3.1:70b-instruct" }

# Google Gemini format
{ "usageMetadata": { "promptTokenCount": ... } }
```

### Cost Calculation

**Pre-calculated (Anthropic):**
- Native Claude API provides `total_cost_usd`
- No calculation needed

**Calculated (Others):**
- Pricing database with 30+ models
- Formula: `(input_tokens / 1M) × input_price + (output_tokens / 1M) × output_price`
- Updated: February 2026

**Zero cost (Ollama):**
- Local models are free
- Always shows `$0.00`

### Provider Icons

Icons appear after cost, before Router icon:

```
Σ 2K | DeepSeek | $0.00 🤖 | 🔀 provider | ...
```

**Icon meanings:**
- 🤖 = OpenAI-compatible (OpenAI, DeepSeek, OpenRouter)
- 🦙 = Ollama (local models)
- ✨ = Google Gemini
- ❓ = Unknown provider (generic fallback)
- No icon = Native Anthropic Claude

### Architecture

**Adapter System:**

```
Session JSON → Provider Detection → Adapter → Unified Format → Display
                      ↓
            anthropic | openai | ollama | gemini | generic
```

**Location:** `.claude-isolated/scripts/lib/`

**Files:**
- `provider-adapter.sh` - Factory & detection logic
- `pricing-lookup.sh` - Cost calculation (30+ models)
- `adapters/anthropic.sh` - Claude API adapter
- `adapters/openai.sh` - OpenAI/DeepSeek/OpenRouter adapter
- `adapters/ollama.sh` - Local models adapter
- `adapters/gemini.sh` - Google Gemini adapter
- `adapters/generic.sh` - Fallback adapter

### Usage Examples

**With Claude Code Router:**

```bash
# Configure Router with DeepSeek
./iclaude.sh --router

# Status line automatically detects and shows:
# Σ 1.5K | DeepSeek Chat | $0.0004 🤖 | ...
```

**With Ollama (local):**

```bash
# Status line shows zero cost:
# Σ 850 | Llama3.1 (local) | $0.00 🦙 | ...
```

**With native Claude (unchanged):**

```bash
# No provider icon, works exactly as before:
# Σ 50K | 25K active (12%) | 📦 90% · R9K/W1K | Sonnet 4.5 | $1.05 | ...
```

### Backward Compatibility

**100% compatible** with existing setups:

- ✅ Native Claude users see no changes
- ✅ Falls back to legacy parsing if adapters unavailable
- ✅ No breaking changes to output format
- ✅ Graceful degradation for unknown providers

### Troubleshooting

**Provider not detected:**

```bash
# Enable debug mode
export DEBUG_STATUSLINE=1
cat session.json | claude-statusline.sh

# Check detection
# Output: "[DEBUG] Detected provider: openai"
```

**Wrong cost:**

- Check model name: `cat session.json | jq '.model'`
- Update pricing in `lib/pricing-lookup.sh` if model missing
- Pricing updated Feb 2026, may need refresh for new models

**No provider icon:**

- Anthropic/Claude: No icon by design (native provider)
- Unknown format: Shows ❓ icon (generic fallback)
- Debug with `DEBUG_STATUSLINE=1`

### Adding New Providers

See `lib/README.md` for complete guide on adding new provider adapters.

## 🔄 Streaming Mode Support (NEW - Week 2)

**Status:** Production-ready ✅

Real-time token accumulation and display during streaming requests.

### Overview

Streaming mode automatically detects SSE (Server-Sent Events) chunks and accumulates tokens in real-time:

**Streaming Flow:**
```
Request Start → message_start (input tokens)
             → content_block_delta (text chunks)
             → message_delta (output tokens)
             → message_stop (completion)
                      ↓
             Real-time statusline updates
```

### Features

✅ **Automatic Detection** - Streaming vs non-streaming auto-detected
✅ **Real-time Updates** - Tokens accumulate as chunks arrive
✅ **Session-based State** - Isolated state per streaming session
✅ **Provider Support** - Anthropic, OpenAI, Ollama, Gemini
✅ **🔄 Indicator** - Visual feedback during streaming
✅ **Backward Compatible** - Non-streaming requests unchanged

### Display Examples

**During Streaming:**
```
1,000 | 127 generating... 🔄 | Sonnet 4.5 | $0.00
```

**After Completion:**
```
1,000 | 2,000 | Sonnet 4.5 | $1.05
```

**With Provider Icon:**
```
50K | GPT-4o | $0.10 🤖🔄 | master
```

### Streaming Indicator (🔄)

**When shown:**
- During active streaming (chunks being received)
- `STREAMING_ACTIVE=1` flag set

**When hidden:**
- After stream completion
- Non-streaming requests
- `STREAMING_ACTIVE=0` or unset

**Position:**
- After provider icon (🤖🦙✨)
- Before router icon
- Part of cost display section

### Supported Chunk Formats

#### Anthropic (Claude)

**message_start** - Initial chunk with input tokens:
```json
{
  "type": "message_start",
  "message": {
    "id": "msg_abc123",
    "model": "claude-sonnet-4.5",
    "usage": {
      "input_tokens": 1000,
      "cache_read_input_tokens": 500
    }
  }
}
```

**message_delta** - Output token updates:
```json
{
  "type": "message_delta",
  "usage": {
    "output_tokens": 50
  }
}
```

**message_stop** - Stream completion:
```json
{
  "type": "message_stop"
}
```

#### OpenAI (GPT-4, DeepSeek)

**Delta chunks:**
```json
{
  "id": "chatcmpl-123",
  "choices": [{
    "delta": {"content": "Hello"},
    "index": 0
  }]
}
```

**Final chunk:**
```json
{
  "id": "chatcmpl-123",
  "choices": [{
    "delta": {},
    "finish_reason": "stop"
  }]
}
```

#### Ollama (Local Models)

**Streaming chunks:**
```json
{
  "model": "llama3.1",
  "done": false,
  "message": {"content": "Hello"}
}
```

**Final chunk:**
```json
{
  "model": "llama3.1",
  "done": true,
  "prompt_eval_count": 100,
  "eval_count": 25
}
```

### State Management

**State Location:**
```
$CLAUDE_DIR/streaming-state/$SESSION_ID.state
```

**State Format:**
```json
{
  "session_id": "msg_abc123",
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

**Automatic Cleanup:**
- States older than 1 hour removed automatically
- Manual cleanup: `cleanup_old_states` (in `lib/streaming-state.sh`)

### Performance

**Measured Overhead:**
- Chunk detection: <2ms
- State update: <10ms (file I/O)
- Chunk parsing: <3ms
- **Total per chunk:** <15ms

**Impact:** Imperceptible in real-world usage ✅

### Token Accuracy

**Anthropic:**
- ✅ Accurate per-chunk token counts
- ✅ Cache tokens tracked
- ✅ Real-time accumulation

**OpenAI/DeepSeek:**
- ⚠️ No per-chunk token counts (API limitation)
- ✅ Final chunk provides accurate totals
- 💡 Shows "generating..." during streaming

**Ollama:**
- ⚠️ Tokens only in final chunk (done=true)
- ✅ Accurate final counts
- 💡 Shows chunk progress during streaming

**Gemini:**
- ⚠️ Limited per-chunk metadata
- ✅ Completion detection works
- 💡 Similar to OpenAI behavior

### Cost During Streaming

**Behavior:**
- Cost shows $0.00 during streaming
- Updated after completion
- Prevents inaccurate estimates

**Rationale:**
- Complete token counts required for accurate cost
- Some providers don't provide per-chunk counts
- Final cost displayed after stream completes

### Debug Mode

**Enable:**
```bash
export DEBUG_STATUSLINE=1
```

**Output Example:**
```
[DEBUG] Streaming chunk detected
[DEBUG] Streaming provider: anthropic
[DEBUG] Streaming state initialized: msg_123
[DEBUG] Streaming state updated: msg_123 (chunks: 1, output: 0)
[DEBUG] Streaming state updated: msg_123 (chunks: 2, output: 50)
[DEBUG] Streaming state finalized: msg_123
```

### Usage Examples

**Example 1: Anthropic Streaming Session**
```bash
export SESSION_ID="msg_abc123"

# Chunk 1: message_start (input tokens)
# Statusline: 1,000 | 0 | Sonnet 4.5 | $0.00 🔄

# Chunk 2: content_block_delta (text generation)
# Statusline: 1,000 | 0 generating... 🔄 | Sonnet 4.5

# Chunk 3: message_delta (output tokens)
# Statusline: 1,000 | 50 🔄 | Sonnet 4.5 | $0.00

# Chunk 4: message_stop (completion)
# Statusline: 1,000 | 50 | Sonnet 4.5 | $0.05
```

**Example 2: OpenAI Streaming**
```bash
export SESSION_ID="chatcmpl-xyz"

# Multiple delta chunks
# Statusline: Generating... 🔄

# Final chunk (finish_reason="stop")
# Statusline: 1,000 | 500 | GPT-4o | $0.10 🤖
```

### Backward Compatibility

**Guaranteed:**
- ✅ Non-streaming requests work identically
- ✅ No performance impact on complete responses
- ✅ Existing tests still pass (27 from Week 1)
- ✅ Legacy parsing path preserved

**Graceful Degradation:**
- If streaming modules unavailable → fallback to non-streaming
- If state file unavailable → best-effort display
- If chunks malformed → show partial data

### Troubleshooting

**Problem: 🔄 not showing**
- Check: `echo $STREAMING_ACTIVE` (should be "1")
- Solution: Ensure `parse_with_adapter()` called with session_id

**Problem: Tokens not accumulating**
- Check: State file exists in `streaming-state/` directory
- Solution: Verify session_id passed correctly

**Problem: Old states accumulating**
- Check: `ls -lh $CLAUDE_DIR/streaming-state/`
- Solution: Run `cleanup_old_states()` manually

**Comprehensive Guide:**
- See: `docs/streaming-troubleshooting-guide.md`

### Migration Guide

**For custom statusline users:**
- See: `docs/streaming-migration-guide.md`
- 3 migration scenarios (Minimal/Basic/Full)
- Step-by-step instructions
- Testing procedures

### Architecture

**Components:**
- `lib/streaming-detector.sh` - Chunk detection
- `lib/streaming-state.sh` - State management
- `lib/streaming-parser.sh` - Chunk parsing
- `lib/provider-adapter.sh` - Integration (updated)
- `claude-statusline.sh` - Display (updated)

**Flow:**
```
Chunk → Detector → Parser → State Manager → Display
   ↓        ↓         ↓           ↓            ↓
 Type?  Provider?  Tokens?   Accumulate?   Show 🔄
```

**Details:**
- See: `lib/README.md` (Section 4: Streaming Support)
- See: `docs/week2-streaming-mode-summary.md`

## Display Format

### Example Output

```
112,762 total | 50,000 active (25%) [cache]79K Sonnet 4.5 $1.06 [proxy] [router]provider [session]  branch
```

### Format Notes

- **Always shows dual context**: cumulative (billing) and active (NEW tokens only, excluding cache)
- **After /clear**: Shows `0 active (0%)` for ~10-40 seconds until Claude Code sends first API response
- **After /compact**: Shows only NEW tokens (input + output), excluding cache. For example, if used_percentage=77% (155K total), cache=154K, active context shows 1K (0.5%). Cache portion shown separately in `[cache] 154K`. This clearly distinguishes fresh conversation from cached context.

## Components

Detailed breakdown of status line components (left to right):

### 1. Context Usage

Shows two token metrics:

- **Cumulative tokens** (`total_input + total_output`): Total tokens used in session for billing
- **Active context** (`(used_percentage × context_window_size) - cache`): NEW tokens only (input + output)

**Behavior:**
- Active context resets to ~0 after `/clear` (only system prompt remains)
- Active context stays LOW after `/compact` (~1K) while cache is HIGH (~150K)
- Cumulative tokens continue to grow (billing tracking)
- Color coded based on active context:
  - Green: <50%
  - Yellow: 50-75%
  - Red: >75%

### 2. Cache Tokens

Format: `📦 87% · R1.2M/W12k`

**Calculation:** hit-rate `cache_read / (cache_read + cache_creation + input_tokens)`, integer percent, with the read (`R`) and creation (`W`) token volumes.

**Features:**
- `R`/`W` formatted K for thousands, M for millions; hit-rate shown as `n/a` only if the denominator is 0
- Only shown when total cache tokens > 0
- Replaces the earlier summed token count, surfacing prefix reuse (high %) vs. rewrite (`W` = cache_creation spike)
- Cache tokens are shown SEPARATELY from active context
- Active context shows only NEW tokens (input + output), excluding cache
- After `/compact`, active context is LOW (~0.3%) while cache is HIGH (~150K) - this clearly distinguishes new vs reused context

### 3. Model Name

Displays `display_name` from session data (e.g., "Sonnet 4.5")

### 4. Cost

Displays `total_cost_usd` in USD (e.g., "$1.06")

### 5. Proxy Indicator

Shows `[proxy]` icon if proxy configured via iclaude.sh

### 6. Router Indicator

Shows `[router]provider` if Claude Code Router is active (e.g., `[router]deepseek`)

### 7. Session Link

Format: `📄` - clickable hyperlink (OSC 8)

**Features:**
- Click to open human-readable conversation in your editor (TOON format)
- **Session-specific files**: Each session has unique readable file (no conflicts)
- **Append-only optimization**: Only processes new messages (19x faster)
- **Smart regeneration**: Full rebuild only when needed (/compact, first run, JSONL truncated)
- **Performance**: 94ms append vs 1.87s full regen (200 lines)
- Readable file saved to: `<project>/.claude/sessions/readable-{session-id}.toon`
- Metadata tracking: `.claude/sessions/readable-{session-id}.toon.meta` (processed lines count)
- **Compact detection**: Detects `/compact` in last 5 JSONL lines and triggers full rebuild
- **Broken JSONL recovery**: Falls back to Python3 parser when `jq` fails on malformed records
- Works in modern terminals: iTerm2, kitty, GNOME Terminal 3.x+, Windows Terminal
- Falls back to plain text in terminals without hyperlink support

### 8. Memory Link

Format: `🧠` - clickable hyperlink (OSC 8)

**Features:**
- Click to open the project's auto-memory file (`MEMORY.md`) directly in your editor
- Auto-memory is maintained by Claude Code across sessions (persistent project knowledge)
- **Shown only when the file exists**: icon appears only if `MEMORY.md` is present for the current project
- **Project-key resolution**: key extracted from `transcript_path` in session data — correctly handles dots, Cyrillic, and any non-ASCII characters in project paths
- File location: `$CLAUDE_CONFIG_DIR/projects/{project-key}/memory/MEMORY.md`
- Available in: **full** and **compact** display modes

### 9. Git Info

Branch name + uncommitted changes count (e.g., "master" or "feature-branch +3")

### 10. Rate Limit

Format: `[RL:45% 2h30m 7d:62% 3d]` — Anthropic-only (hidden with `--router`).

- Read from `anthropic-ratelimit-unified-5h-*` and `anthropic-ratelimit-unified-7d-*`
  response headers, fetched via a single minimal `POST /v1/messages` call
  (`lib/rate-limit.sh`) and cached for 60s (5-minute hard expiry for display).
- Auth for that call: `$CLAUDE_CODE_OAUTH_TOKEN` if set (long-lived `claude setup-token`,
  set via `.claude_config` → `ICLAUDE_CLAUDE_CODE_OAUTH_TOKEN` in iclaude setups), else
  `$CLAUDE_CONFIG_DIR/.credentials.json`. Silently shows nothing if neither is available
  (e.g. auth stored in an OS keychain the module doesn't read).
- First segment is the 5-hour session window; `7d:` is the weekly window, shown only
  when the API returns it. Colored green (<50%), yellow (50-79%), red (≥80%) per window.
- Time shown is time-to-reset (`2h30m` for 5h, `3d` for 7d).

## Features

### Key Capabilities

- **Dual context tracking**: Shows both cumulative (billing) and active (next message) token counts
- **Automatic /clear detection**: Active context resets when user runs `/clear`, cumulative continues
- **Cache visibility**: Shows prompt cache usage separately to understand reuse vs fresh tokens
- **Null-safe**: Handles temporary `null` values after `/clear` (shows `0 active (0%)` until data arrives)
- **Debug logging**: Set `DEBUG_STATUSLINE=1` to log session data to `/tmp/claude-statusline-debug.log`
- **Session-specific readable files**: Each session gets unique file (no conflicts between parallel sessions)
- **Append-only optimization**: Incremental updates instead of full regeneration (19x faster)
- **Compact detection**: Automatically rebuilds readable file after `/compact` with summary marker
- **Adaptive display**: Three display modes based on terminal width to prevent line wrapping

### Adaptive Display Modes

The status line automatically adapts to terminal width to prevent line wrapping and maintain readability.

#### Context markers

`detect_real_context_window()` resolves the true window **by model name**, because
Claude Code reports `context_window_size: 200000` even for 1M-window models
(Opus/Sonnet 4.x). Mapping: Opus 5, Sonnet 5, Opus/Sonnet 4.5+ → 1M, Haiku → 200K,
Fable/Mythos → 1M, unknown → reported.

- **Σ** — remaining tokens until the window is full (`window − active`), e.g. `Σ 680K ↓`.
- **📊** — active context (real `total_input_tokens`, incl. cache) and its % of the
  full window, e.g. `📊 320K (32%)`. `⚠️` appended if active exceeds the window.
  Derived from real token counts, **not** from `used_percentage` (which Claude Code
  saturates at 100 against its stale 200K value). A `🗜️~92%` marker is appended once
  active usage reaches the estimated auto-compact threshold (Anthropic doesn't publish
  the exact trigger, so this defaults to 92% and can be overridden with
  `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`).
- **📦** — cache hit-rate % and read/write split, e.g. `📦 86% · R310K/W10K` (`R` = cache_read, `W` = cache_creation; hit-rate = read / (read + creation + input)).

The fixed `🔒 45K` reserved-buffer marker was removed — it was meaningless at 1M.

#### Display Modes

**Full Mode (≥130 columns)**
```
Σ 680K ↓ | 📊 320K (32%) | 📦 86% · R310K/W10K | Opus 4.8 | $13.38 🌐 | 📄 | 🧠 | 🔱 test ●2
```
- All components visible without abbreviations
- Full model name, full router provider
- 🧠 shown when project has `MEMORY.md`
- Optimal for wide terminals (≥130 cols)

**Compact Mode (110-129 columns)**
```
Σ 680K ↓ | 📊 320K (32%) | 📦 86% · R310K/W10K | O4.8 | $13.38 | 🧠
```
- Smart abbreviations to save space
- Model abbreviated: "Opus 4.8" → "O4.8"
- Router, proxy, session link, git info hidden
- 🧠 retained (quick access to project memory)

**Minimal Mode (<110 columns)**
```
Σ 680K ↓ | 📊 320K (32%) | O4.8 | $13.38
```
- Only critical metrics: tokens, model, cost
- Hides cache, proxy, router, session link, memory link, git info
- Guaranteed to fit in narrow terminals

#### Configuration

**Disable adaptive mode** (always use full mode):
```bash
export STATUSLINE_ADAPTIVE=0
./iclaude.sh
```

**Debug terminal width detection**:
```bash
# Check detected width
tput cols

# Test with specific width
COLUMNS=120 ./iclaude.sh
```

#### Implementation Details

- **Width detection**: Uses `tput cols` (fallback to `stty size`, then 80 cols)
- **Overhead**: ~5ms per status line update (negligible)
- **Fallback**: If detection fails, defaults to 80 cols (compact mode)
- **Zero configuration**: Adapts automatically based on terminal

#### System Message Handling

Claude Code asynchronously inserts system messages (e.g., "Claude Code has switched from npm to native installer...") into stdout during session startup. This can interrupt status line output and cause line wrapping.

**Solution**: Silent wait, then show after first message (default)

- **Detection**: Uses session start time tracker `/tmp/claude-statusline-start-time-${SESSION_ID}`
- **Phase 1 (0-30 seconds)**: No output (silent wait)
- **Phase 2 (30s+, first call)**: Mark ready, still no output
- **Phase 3 (30s+, after first message)**: Normal full status line appears

**Three-phase approach:**
```
0s:    Session start → no output
15s:   User message → no output (age < 30s)
30s:   Wait complete → still no output
35s:   User message → creates ready marker, no output
40s:   User message → STATUS LINE APPEARS ✅
```

**Why this approach?**
- Eliminates ALL race conditions (no output = no races)
- Waits for both: 30s timeout AND user activity
- Guarantees clean output after system messages cleared
- Only shows when actually useful (user is interacting)

**Why skip instead of wait?**
- System messages are inserted asynchronously by Claude Code main process
- Race condition: Message can appear DURING script printf execution
- No bash-level solution can prevent async stdout insertion
- Skipping eliminates race condition entirely

**Alternative mode** (stability detection - experimental):
```bash
export STATUSLINE_SKIP_STARTUP=0  # Enable wait mode
./iclaude.sh
```

Wait mode behavior:
- Minimum delay: 8 seconds
- Monitors transcript file for changes
- Stable period: 3 seconds of no changes
- Maximum timeout: 20 seconds
- Debug: `export DEBUG_STATUSLINE=1`

**Why 30 seconds?**
- System messages can appear at session start AND after first user message
- 30 seconds covers both startup + first message interaction
- After 30s, session is stable and no more system messages expected

**How stability detection works:**
- Monitors session transcript file: `.claude-isolated/projects/[project]/${SESSION_ID}.jsonl`
- Checks file modification time every second
- If file unchanged for 2 consecutive seconds → system messages cleared
- Guarantees status line appears after all async output completed

**Benefits:**
- ✅ Reliable detection of message completion
- ✅ Adapts to system speed (fast exit on quick systems)
- ✅ Timeout protection (never hangs indefinitely)
- ✅ Zero false positives (actually waits for stability)

**Alternative approaches tested** (did not work consistently):
- Fixed delays (2s-15s): Either too short (races) or too long (slow)
- Skip first run completely: Status line missing until user types
- `printf` with flush: Cannot control async stdout from Claude Code
- Stderr redirection: Status line not visible
- Process monitoring: Cannot detect stdout vs stderr activity

### Token Parsing (Claude Code v2.1+)

```bash
Input:  .context_window.total_input_tokens
Output: .context_window.total_output_tokens
Cache:  .context_window.current_usage.cache_read_input_tokens + cache_creation_input_tokens
Cost:   .cost.total_cost_usd
Model:  .model.display_name

# How Claude Code calculates used_percentage:
# used_percentage = (cache_read + input + output) / context_window_size × 100

# How statusline calculates active tokens (NEW logic - subtracts cache):
# TOTAL_CONTEXT = used_percentage × context_window_size  (includes cache!)
# ACTIVE_TOKENS = TOTAL_CONTEXT - CACHE  (excludes cache, shows only NEW tokens)

# Example after /compact:
#   cache_read: 154576, input: 0, output: 652
#   used_percentage = (154576 + 0 + 652) / 200000 × 100 = 77.6%
#   TOTAL_CONTEXT = 77.6% × 200000 = 155228 tokens
#   CACHE = 154576 tokens
#   ACTIVE_TOKENS = 155228 - 154576 = 652 tokens ← Only NEW conversation!
#   Display: [stats] 652 (0.3%) | [cache] 154K
# This clearly separates fresh conversation (652) from cached context (154K)
```

### Session Link Optimizations (Phase 2.1+)

The readable session generation uses three key optimizations for performance:

#### 1. Session-Specific Filenames

- Each session gets unique file: `.claude/sessions/readable-{session-id}.toon`
- Prevents conflicts when running multiple parallel Claude sessions
- Example: `readable-abc123.toon`, `readable-def456.toon`

#### 2. Append-Only Updates

- Tracks processed lines in metadata file: `.claude/sessions/readable-{session-id}.toon.meta`
- Only processes NEW messages since last update (incremental)
- Performance: 94ms (append) vs 1.87s (full regen) for 200-line session
- **19x faster** for incremental updates
- **Atomic writes**: full regeneration uses `.tmp.PID` + `mv` to prevent 0-byte artifacts

#### 3. Smart Regeneration Triggers

Full rebuild occurs only when necessary:
- First run (readable file doesn't exist)
- `/compact` detected in last 5 JSONL lines (context compression happened)
- JSONL truncated (current lines < processed lines)
- Append-only used for normal message additions

#### 4. Broken JSONL Recovery (Scenario B)

Some JSONL files contain literal newlines inside JSON string values (e.g., multi-line tool outputs). `jq -s` exits with a parse error on these files, silently returning empty output.

**Fallback strategy:**
1. `jq -s` attempted first (fast path)
2. On empty output → Python3 line-by-line parser activated
3. Python reads each line independently; lines not starting with `{` are skipped (continuation lines from broken records)
4. Each candidate line parsed with `json.loads()` — failures silently discarded
5. Result: valid messages extracted even from corrupted JSONL

**Why icon was missing in other projects** (two root causes):
- **Transient**: New session JSONL contains only system metadata → `jq` returns `[]` → no messages → no icon. Self-corrects after first user message.
- **Permanent**: JSONL has literal newlines in string values → `jq` parse error suppressed with `2>/dev/null` → `messages_json` empty → icon never appears. Fixed by Python3 fallback.

### Compact Detection

When `/compact` is used, the readable file shows a special marker:

```
━━━ [cache] Context Compact ━━━
{Summary of compressed context}
━━━━━━━━━━━━━━━━━━━━━━━━━

[user] USER:
{First message after compact}
```

### File Structure

```
.claude/sessions/
  readable-abc123.toon       # Session abc123 conversation (TOON format)
  readable-abc123.toon.meta  # Metadata: processed lines count
  readable-def456.toon       # Session def456 conversation
  readable-def456.toon.meta  # Metadata
```

## Configuration

### Setup Instructions

Enable statusline in Claude Code settings:

**File:** `.claude-isolated/settings.json` (isolated mode) or `~/.claude/settings.json` (system mode)

```json
{
  "statusLine": {
    "type": "command",
    "command": "/absolute/path/to/.claude-isolated/scripts/claude-statusline.sh"
  }
}
```

### Debug Mode

Add to `.claude_proxy_credentials` or export in shell:

```bash
DEBUG_STATUSLINE=1
```

This logs session data to `/tmp/claude-statusline-debug.log` for troubleshooting.

### Automatic Configuration

The `iclaude.sh` script automatically:
- Exports `DEBUG_STATUSLINE` from `.claude_proxy_credentials` (if set)
- Configures statusline path when using isolated environment

## Dependencies

### Required

- **jq**: JSON parsing (included in isolated environment)
  - Install: `sudo apt install jq` (Debian/Ubuntu) or `brew install jq` (macOS)

### Optional

- **git**: Branch and status info
- **oh-my-posh**: Enhanced git rendering with icons and colors
  - Without oh-my-posh: Shows plain branch name
  - With oh-my-posh: Shows styled branch with status indicators

## Error Handling

The script handles various error conditions gracefully:

### Missing jq

Shows warning message instead of breaking UI:
```
[Status line: jq not found - install jq for session stats]
```

### Invalid or Missing Data

Shows placeholder until data arrives:
```
[Status line: awaiting session data...]
```

### Git Timeout

2-second timeout prevents hanging on slow repositories. Falls back to "unknown" if git operations take too long.

### Null Values After /clear

Handles temporary `null` values in session data by showing `0 active (0%)` until Claude Code sends first API response.

## Helper Scripts

### claude-show-cache.sh

View session context and cached summary directly from command line.

#### Usage Examples

```bash
# View cached summary (after /compact)
.claude-isolated/scripts/claude-show-cache.sh --cache

# View last 5 messages (default)
.claude-isolated/scripts/claude-show-cache.sh

# View last N messages
.claude-isolated/scripts/claude-show-cache.sh --last 10

# View full conversation
.claude-isolated/scripts/claude-show-cache.sh --full
```

#### Features

- Shows current session ID and file location
- Displays cached summary from /compact (if available)
- Shows recent messages with role indicators ([user] USER, [assistant] ASSISTANT)
- Truncates long messages by default (use --full to see complete text)
- Provides clickable file:// link for opening in editor

### Viewing Readable Sessions

Auto-generated readable files can be accessed directly:

```bash
# List all readable sessions
ls -lh .claude/sessions/

# View specific session (TOON format)
toon --decode .claude/sessions/readable-{session-id}.toon

# View most recent session
ls -t .claude/sessions/readable-*.toon | head -1 | xargs toon --decode

# Check metadata (processed lines)
cat .claude/sessions/readable-{session-id}.toon.meta

# Cleanup old sessions (older than 7 days)
find .claude/sessions/ -name "readable-*.toon*" -mtime +7 -delete
```

## Troubleshooting

### Status line not showing

**Symptoms:** No status line visible in Claude Code UI

**Solutions:**
1. Check `settings.json` has correct `statusLine` configuration
2. Verify script path is absolute (not relative)
3. Ensure script is executable: `chmod +x claude-statusline.sh`
4. Check Claude Code version (requires v2.1+)

### Incorrect token counts

**Symptoms:** Active context doesn't match expected values

**Solutions:**
1. Enable debug mode (`DEBUG_STATUSLINE=1`)
2. Check `/tmp/claude-statusline-debug.log` for raw session data
3. Verify Claude Code v2.1+ (older versions use different JSON structure)
4. After `/clear`: Wait 10-40 seconds for first API response

### Session link not clickable

**Symptoms:** 📄 icon shows but not clickable

**Solutions:**
1. Check terminal emulator supports OSC 8 hyperlinks:
   - Supported: iTerm2, kitty, GNOME Terminal 3.x+, Windows Terminal
   - Not supported: Basic xterm, older terminals
2. Verify readable file exists: `ls .claude/sessions/readable-*.toon`
3. Check file permissions: `chmod 644 .claude/sessions/readable-*.toon`

### Session icon 📄 not showing in other projects

**Cause A — Transient (new session):** JSONL contains only system metadata → `jq` returns `[]` → file is 0 bytes → icon hidden. Self-corrects after first user message.

**Cause B — Permanent (broken JSONL):** JSONL file has literal newlines inside JSON string values. `jq -s` exits with parse error (suppressed via `2>/dev/null`) → `messages_json` empty → icon never appears.

**Fix for Cause B:** Python3 fallback now activates automatically when `jq` returns empty output. Requires `python3` installed (`which python3`).

**Debug:**
```bash
# Check if jq parse error is the issue
jq -s '.' ~/.claude/projects/YOUR_PROJECT/SESSION_ID.jsonl 2>&1 | head -5

# If you see "parse error" → Cause B. Python3 fallback handles this automatically.
# If empty output with no error → Cause A (transient, wait for first message).
```

### High memory usage

**Symptoms:** Statusline script consuming excessive memory

**Solutions:**
1. Check for very large session files (>10MB)
2. Use `/clear` periodically to reset context
3. Disable append-only optimization if causing issues (regenerate always)
4. Cleanup old sessions: `find .claude-sessions/ -name "readable-*.txt*" -mtime +7 -delete`

### Git info missing

**Symptoms:** No branch name or status shown

**Solutions:**
1. Ensure `git` installed: `which git`
2. Check current directory is git repository: `git status`
3. Verify git timeout not triggering (2-second limit)
4. For slow repos: Consider disabling git info in script

### Cache metrics incorrect after /compact

**Symptoms:** Cache tokens don't match expected values

**Solutions:**
1. Verify using Claude Code v2.1+ (older versions don't report cache correctly)
2. Enable debug mode and check raw `cache_read_input_tokens` + `cache_creation_input_tokens`
3. Remember: Active context = TOTAL - CACHE (shows only NEW tokens)
4. After `/compact`: Active context should be LOW (~0.3%), cache HIGH (~150K)

### Debug log not created

**Symptoms:** `/tmp/claude-statusline-debug.log` not appearing

**Solutions:**
1. Check `DEBUG_STATUSLINE=1` exported before launching Claude Code
2. Verify `/tmp` directory writable: `touch /tmp/test && rm /tmp/test`
3. Check script has permission to write: `ls -l /tmp/claude-statusline-debug.log`
4. Try running script manually with test data: `echo '{"context_window":{}}' | ./claude-statusline.sh`

## Performance Considerations

### Append-Only Optimization

- **Initial load**: ~1.87s for 200-line session (full parse)
- **Incremental update**: ~94ms for new messages (19x faster)
- **Optimal for**: Long-running sessions with frequent updates
- **Trigger full rebuild**: Only when necessary (/compact, first run, truncation)

### Memory Footprint

- **Minimal overhead**: Processes only new messages incrementally
- **Metadata tracking**: Tiny `.meta` files (~10 bytes)
- **No caching**: Session data parsed on-demand from STDIN

### Terminal Rendering

- **OSC 8 hyperlinks**: Minimal overhead in modern terminals
- **Fallback mode**: Plain text if hyperlinks unsupported
- **Color codes**: ANSI escape sequences for context usage colors

## Advanced Usage

### Custom Status Line Format

Edit `claude-statusline.sh` to modify display format. Key sections:

```bash
# Line 120-180: Token calculation logic
# Line 200-250: Output formatting
# Line 300-350: Git info rendering
```

### Integration with oh-my-posh

For enhanced git rendering with custom themes:

```bash
# Install oh-my-posh
curl -s https://ohmyposh.dev/install.sh | bash -s

# Configure theme
export POSH_THEME="/path/to/theme.json"

# Statusline will auto-detect and use oh-my-posh
```

### Session Data Export

Extract session data programmatically:

```bash
# Get current session ID
SESSION_ID=$(jq -r '.id' < "$CLAUDE_DIR/session-env/$(ls -t $CLAUDE_DIR/session-env/ | head -1)")

# Read raw session JSONL
cat "$CLAUDE_DIR/session-env/$SESSION_ID.jsonl"

# Parse with jq
cat "$CLAUDE_DIR/session-env/$SESSION_ID.jsonl" | jq -s '.'
```

### Parallel Session Management

When running multiple Claude Code sessions:

```bash
# Each session creates unique readable file
ls .claude-sessions/readable-*.txt

# Monitor all sessions
watch -n 5 'tail -1 .claude-sessions/readable-*.txt'

# Find session by content
grep -l "search term" .claude-sessions/readable-*.txt
```

## Related Documentation

- **Main Documentation**: `README.md` - iclaude.sh usage and installation
- **Developer Guide**: `.claude-isolated/CLAUDE.md` - Architecture and internals
- **Skills System**: `.claude-isolated/skills/` - Claude Code skills integration
- **Proxy Configuration**: `README.md` section on proxy setup
- **Router Integration**: `README.md` section on Claude Code Router

## Changelog

### Phase 2.5 (Current — March 2026)
- **PII Proxy Icon (🛡)**: shows when `ICLAUDE_PII_ACTIVE=1`; displays live masked-items counter from `/api/metrics` with 30s TTL cache; becomes an OSC 8 hyperlink to the server log when the file exists
- Env vars: `ICLAUDE_PII_ACTIVE`, `ICLAUDE_PII_MASKING_LEVEL`, `ICLAUDE_PII_ACTIVE_PORT`, `ICLAUDE_PII_LOG_PATH` — all exported automatically by `launch.sh`
- Log path: `{pii-proxy-logs}/{session}.log` (in `.claude-isolated/pii-proxy-logs/`)

### Phase 2.4 (March 2026)
- **Memory Link (🧠)**: new OSC 8 hyperlink to project `MEMORY.md` (auto-memory maintained by Claude Code)
- Shown only when file exists; available in full and compact display modes
- Project-key resolution via `transcript_path` — correctly handles dots, Cyrillic, and non-ASCII paths (fixes regression where `sed 's|/|-|g'` only replaced slashes)

### Phase 2.3 (February 2026)
- **Append-only caching for `generate_toon_session()`**: `.toon.meta` tracks processed line count; only new JSONL lines are encoded and appended on each statusline call
- **Broken JSONL fallback (Scenario B)**: When `jq -s` fails on JSONL with literal newlines inside string values, Python3 line-by-line parser activates automatically; continuation lines (not starting with `{`) are skipped silently
- **Atomic writes**: full regeneration writes to `.tmp.PID` temp file and `mv`s into place only on success — eliminates 0-byte TOON artifacts
- **No-op fast path**: when `current_lines == processed_lines`, function returns immediately with no file I/O
- Fixed: session icon 📄 not appearing in other projects (transient: new session; permanent: broken JSONL)

### Phase 2.2
- Added adaptive display modes (full/compact/minimal)
- Automatic terminal width detection
- Smart abbreviations for narrow terminals
- Prevents line wrapping on all terminal sizes
- Configurable via STATUSLINE_ADAPTIVE environment variable

### Phase 2.1
- Added append-only optimization (19x faster) for `generate_readable_session()`
- Session-specific readable files (no conflicts)
- Smart regeneration triggers
- Compact detection with summary marker

### Phase 2.0
- Added clickable session links (OSC 8)
- Readable session file generation
- Metadata tracking for processed lines

### Phase 1.0
- Initial release with context tracking
- Cache visibility
- Cost and model display
- Git integration

## License

Part of the iclaude project. See main repository LICENSE.
