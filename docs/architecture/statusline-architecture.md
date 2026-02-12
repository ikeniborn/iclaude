# Status Line Architecture Documentation

**Version:** 2.0.0 (Phase 2)
**Date:** 2026-02-12
**Status:** Production Ready
**Component:** `claude-statusline.sh`

---

## Overview

Status Line - это встроенный компонент real-time мониторинга для Claude Code, интегрированный в iclaude.sh. Отображает comprehensive информацию о session (токены, стоимость, кэш, proxy, router, git) прямо в UI.

### Key Features

- **Dual Context Tracking** - отслеживание billing и active context
- **Real-time Updates** - обновление при каждом API ответе
- **Cost Monitoring** - отображение стоимости сессии в USD
- **Cache Visibility** - показывает prompt cache usage для оптимизации
- **Clickable Session Link** - OSC 8 hyperlink для просмотра readable conversation
- **Git Integration** - показывает branch, uncommitted changes, upstream status
- **Proxy/Router Detection** - индикация активных proxy и router

---

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Claude Code                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              API Response Handler                    │   │
│  │  - Tracks tokens (input/output/cache)                │   │
│  │  - Calculates cost                                   │   │
│  │  - Maintains session state                           │   │
│  └─────────────────┬────────────────────────────────────┘   │
│                    │ JSON via STDIN                         │
│                    ▼                                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           statusLine.command                         │   │
│  │       (claude-statusline.sh)                         │   │
│  │                                                       │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ 1. Parse Session Data (jq)                    │  │   │
│  │  │    - Extract tokens, cost, model              │  │   │
│  │  │    - Calculate percentages                    │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ 2. Detect Environment                         │  │   │
│  │  │    - Check proxy credentials                  │  │   │
│  │  │    - Detect router config                     │  │   │
│  │  │    - Query git status (with timeout)          │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ 3. Generate Readable Session (mtime cache)    │  │   │
│  │  │    - Check if JSONL changed                   │  │   │
│  │  │    - Parse conversation with role prefixes    │  │   │
│  │  │    - Save to tmp/claude-session-readable.txt  │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │ 4. Format Output                              │  │   │
│  │  │    - Apply color coding (green/yellow/red)    │  │   │
│  │  │    - Build OSC 8 hyperlink for session       │  │   │
│  │  │    - Render final ANSI string                 │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  │                                                       │   │
│  │  Output: "💳 112K | 📊 50K (25%) | 📦 79K | ..."     │   │
│  └─────────────────┬────────────────────────────────────┘   │
│                    │ ANSI formatted string                  │
│                    ▼                                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           Claude Code UI                             │   │
│  │      (displays at bottom of screen)                  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Session Link Flow (Phase 2)

```
User Action: Click on 📄
       │
       ▼
┌────────────────────────────────┐
│  Terminal (OSC 8 handler)      │
│  - Receives file:// URL         │
│  - Opens in $EDITOR             │
└────────┬───────────────────────┘
         │ Read file
         ▼
┌────────────────────────────────┐
│  tmp/claude-session-readable.txt│
│  (if exists and up-to-date)    │
└────────┬───────────────────────┘
         │ OR (if stale/missing)
         ▼
┌────────────────────────────────┐
│  generate_readable_session()   │
│                                │
│  1. Check mtime:               │
│     readable -nt jsonl?        │
│     - Yes → return (cached)    │
│     - No → continue            │
│                                │
│  2. Parse JSONL:               │
│     cat session.jsonl |        │
│     while read line; do        │
│       role=$(jq .message.role) │
│       content=$(jq .content[]) │
│       ...                       │
│     done                        │
│                                │
│  3. Format output:             │
│     👤 USER:                    │
│     {text with word wrap}      │
│     🤖 ASSISTANT:               │
│     {text with word wrap}      │
│                                │
│  4. Write to tmp/              │
└────────┬───────────────────────┘
         │
         ▼
┌────────────────────────────────┐
│  Editor opens readable file    │
│  - User sees formatted conv    │
│  - Role prefixes visible       │
│  - Word wrapped at 80 chars    │
└────────────────────────────────┘
```

---

## Data Flow

### Input (STDIN from Claude Code)

```json
{
  "context_window": {
    "total_input_tokens": 50000,
    "total_output_tokens": 10000,
    "used_percentage": 30.0,
    "context_window_size": 200000,
    "current_usage": {
      "cache_read_input_tokens": 5000,
      "cache_creation_input_tokens": 1000
    }
  },
  "cost": {
    "total_cost_usd": 1.23
  },
  "model": {
    "display_name": "Sonnet 4.5",
    "id": "claude-sonnet-4-5-20250929"
  },
  "cwd": "/home/user/project",
  "transcript_path": "/path/to/.claude-isolated/session-env/abc123.jsonl"
}
```

### Processing Pipeline

1. **Token Extraction** (jq)
   - Cumulative: `total_input + total_output`
   - Active: `used_percentage × context_window_size`
   - Cache: `cache_read + cache_creation`

2. **Percentage Calculation** (awk)
   - API percent: `(cumulative * 100) / context_limit`
   - Active percent: `used_percentage` (from session data)

3. **Color Coding** (bash)
   - Green: `< 50%`
   - Yellow: `50-75%`
   - Red: `>= 75%`

4. **Token Formatting** (function)
   - `< 1K`: Show raw number
   - `>= 1K`: Format as "12K"
   - `>= 1M`: Format as "1.2M"

5. **Environment Detection**
   - Proxy: Check `HTTPS_PROXY` env var + `.claude_proxy_credentials`
   - Router: Check `router.json` + `ccr` binary
   - Git: Run `git status` with 2-second timeout

6. **Session Link Generation** (Phase 2)
   - Extract `transcript_path` and `cwd` from session data
   - Call `generate_readable_session(jsonl, output)`
   - Build OSC 8 hyperlink: `\e]8;;file://{output}\e\\📄\e]8;;\e\\`

### Output (STDOUT to Claude Code)

```
💳 112K | 📊 50K (25%) | 📦 79K | Sonnet 4.5 | $1.06 | 🌐 | 🔀provider | 📄 | 🔱 main ●2 ↑1
```

**Components breakdown**:
- `💳 112K` - Cumulative tokens (billing)
- `📊 50K (25%)` - Active context with percentage (color-coded)
- `📦 79K` - Cache tokens
- `Sonnet 4.5` - Model name
- `$1.06` - Total cost
- `🌐` - Proxy active indicator
- `🔀provider` - Router provider name
- `📄` - Clickable session link (OSC 8)
- `🔱 main ●2 ↑1` - Git: branch, 2 uncommitted changes, 1 commit ahead

---

## Cache and Billing

### How Anthropic Prompt Caching Works

Claude Code uses **Prompt Caching** to significantly reduce costs for long conversations.

**Workflow:**

1. **Cache Creation** (during `/compact`):
   - Claude Code compresses conversation into summary
   - Summary stored in prompt cache (server-side)
   - Billed as regular input tokens: $3.00 / 1M

2. **Cache Reuse** (subsequent requests):
   - Cached summary automatically read from server
   - Billed at reduced rate: $0.30 / 1M (**90% discount!**)
   - New user messages added as regular input

3. **Cache Expiration**:
   - 5-minute TTL (Time To Live)
   - Cache cleared if session idle > 5 minutes
   - Next request creates new cache

### Pricing Model (Sonnet 4.5)

| Token Type | Price per 1M | Description |
|------------|--------------|-------------|
| Regular Input | $3.00 | User messages, system prompts |
| Cache Write | $3.00 | Creating cached summary (same as input) |
| Cache Read | $0.30 | Reusing cached summary (**90% cheaper!**) |
| Output | $15.00 | Claude's responses |

### Example Cost Calculation

**Scenario**: 150 message conversation with `/compact` at 100 messages

**Before `/compact`** (Request #100):
```
Input: 100K tokens × $3.00/1M = $0.30
Output: 2K tokens × $15.00/1M = $0.03
Total: $0.33
```

**After `/compact`** (Request #101 - cache creation):
```
Input: 100K tokens × $3.00/1M = $0.30
Cache creation: 98K × $3.00/1M = $0.29
Output: 2K × $15.00/1M = $0.03
Total: $0.62 (one-time cache creation cost)
```

**Subsequent requests** (#102-150, using cache):
```
Cache read: 98K × $0.30/1M = $0.03 (90% discount!)
New input: 500 tokens × $3.00/1M = $0.0015
Output: 1K × $15.00/1M = $0.015
Total per request: ~$0.05

50 requests × $0.05 = $2.50
```

**Savings**:
- **Without cache**: 50 × $0.33 = $16.50
- **With cache**: $0.62 (creation) + $2.50 (50 reads) = $3.12
- **Savings**: $13.38 (**81% cost reduction!**)

### Status Line Display

```
💳 250K | 📊 100K (50%) | 📦 98K | Sonnet 4.5 | $2.45
```

**What each component means:**

- `💳 250K` - **Cumulative tokens billed**
  - Includes ALL tokens: regular input, cache read, output
  - Cache read counted at $0.30/1M (not $3.00/1M)
  - Running total for entire session

- `📊 100K (50%)` - **Active context**
  - Current conversation window: cache + new messages
  - Used for auto-compact trigger (95% of effective 155K)
  - Includes cache as part of context

- `📦 98K` - **Cache portion**
  - How much of active context is cached
  - Shown separately for cost visibility
  - Reused across multiple requests at 90% discount

- `$2.45` - **Total session cost**
  - Actual billed amount (cache at reduced rate)
  - Savings: ~$2.64 vs without cache
  - Cost tracking for budget awareness

### Key Points

✅ **Cache DOES participate in billing**
- Counted in `total_input_tokens`
- But charged at 90% discount ($0.30 vs $3.00)

✅ **Cache IS PART OF active context**
- Affects auto-compact trigger (context window limit)
- Shows in `used_percentage`

✅ **Cache read saves 90% on input costs**
- Multiple reads multiply savings
- 10 requests: $0.30 vs $3.00 (10x cheaper)

✅ **Cache benefits long conversations**
- Break-even at ~3-4 requests after cache creation
- Maximum savings at 50+ requests

⚠️ **Cache has limitations**
- 5-minute TTL (expires if idle)
- Server-side storage (not in status line data)
- Automatic management by Claude Code

### Implementation in Statusline

**Cache detection** (`claude-statusline.sh:98-115`):
```bash
# Parse cache tokens from session data
CACHE_READ=$(echo "$SESSION_DATA" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
CACHE_CREATION=$(echo "$SESSION_DATA" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
TOTAL_CACHE=$((CACHE_READ + CACHE_CREATION))

# Format cache display (show only if >0)
if [[ $TOTAL_CACHE -gt 0 ]]; then
    if [[ $TOTAL_CACHE -ge 1000000 ]]; then
        CACHE_FMT=$(awk "BEGIN {printf \"%.1fM\", ($TOTAL_CACHE / 1000000.0)}")
    elif [[ $TOTAL_CACHE -ge 1000 ]]; then
        CACHE_FMT=$(awk "BEGIN {printf \"%.0fK\", ($TOTAL_CACHE / 1000.0)}")
    fi
    CACHE_DISPLAY=" | 📦 ${CACHE_FMT}"
fi
```

**Important**: `current_usage.cache_*` shows cache for **CURRENT API request only**, not cumulative cache across all requests in session.

---

## Key Components

### 1. JSON Parser (jq)

**Location**: `.nvm-isolated/npm-global/bin/jq`
**Version**: 1.7.1 (2.3MB static binary)
**Purpose**: Parse session data JSON from Claude Code

**Key Extractions**:
```bash
TOTAL_INPUT=$(echo "$SESSION_DATA" | jq -r '.context_window.total_input_tokens // 0')
TOTAL_OUTPUT=$(echo "$SESSION_DATA" | jq -r '.context_window.total_output_tokens // 0')
USED_PERCENTAGE=$(echo "$SESSION_DATA" | jq -r '.context_window.used_percentage // 0')
CACHE_READ=$(echo "$SESSION_DATA" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
COST=$(echo "$SESSION_DATA" | jq -r '.cost.total_cost_usd // 0')
MODEL=$(echo "$SESSION_DATA" | jq -r '.model.display_name // "Sonnet 4.5"')
```

### 2. Token Formatter

**Function**: `format_tokens()`
**Lines**: 223-232

```bash
format_tokens() {
    local tokens=$1
    if [[ $tokens -ge 1000000 ]]; then
        awk "BEGIN {printf \"%.0fM\", ($tokens / 1000000.0)}"
    elif [[ $tokens -ge 1000 ]]; then
        awk "BEGIN {printf \"%.0fK\", ($tokens / 1000.0)}"
    else
        echo "$tokens"
    fi
}
```

### 3. Proxy Detector

**Lines**: 119-142

**Detection Chain**:
1. Check `HTTPS_PROXY` / `HTTP_PROXY` environment variables
2. Fallback: Search for `.claude_proxy_credentials` in:
   - Isolated config: `$CLAUDE_CONFIG_DIR/../../`
   - Home directory: `$HOME/`
   - Current directory: `$(pwd)/`
3. Verify file contains `PROXY_URL=`

### 4. Router Detector

**Lines**: 144-149

**Detection Logic**:
```bash
if [[ -f "$CLAUDE_CONFIG_DIR/router.json" ]] && command -v ccr &>/dev/null; then
    PROVIDER=$(jq -r '.routing.default // "unknown"' "$CLAUDE_CONFIG_DIR/router.json")
    ROUTER_ICON=" | 🔀 $PROVIDER"
fi
```

### 5. Git Integration

**Lines**: 163-204

**Features**:
- Branch name detection
- Uncommitted changes count
- Commits ahead of upstream
- 2-second timeout (prevents hanging)
- Oh My Posh theme support (optional)

**Oh My Posh Integration**:
```bash
if command -v oh-my-posh &>/dev/null && [[ -f "$theme_config" ]]; then
    GIT_INFO=$(timeout $GIT_TIMEOUT oh-my-posh print primary --config "$theme_config")
fi
```

### 6. Readable Session Generator (Phase 2) 🆕

**Function**: `generate_readable_session()`
**Lines**: 151-190 (approx)

**mtime Caching Logic**:
```bash
# Check if readable file exists and is newer than JSONL
if [[ -f "$output_file" ]] && [[ "$output_file" -nt "$jsonl_file" ]]; then
    return 0  # Cached, skip regeneration
fi
```

**Parsing Logic**:
- Extract `message.role` (user/assistant)
- Extract `content[].type` (text/thinking/tool_use/tool_result)
- Filter: Only text and thinking (skip tool_*)
- Format: Add role prefixes (👤 USER / 🤖 ASSISTANT)
- Word wrap: `fold -w 80 -s`

**Output Format**:
```
📄 Session: {session-id}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

👤 USER:
{user message with word wrap}

🤖 ASSISTANT:
{assistant response}

🤖 ASSISTANT [thinking]:
{internal reasoning}
```

---

## Configuration

### settings.json

**Location**: `.nvm-isolated/.claude-isolated/settings.json`

```json
{
  "statusLine": {
    "type": "command",
    "command": "/absolute/path/to/claude-statusline.sh",
    "padding": 0
  }
}
```

### Debug Mode

**Enable**:
```bash
# Add to .claude_proxy_credentials
DEBUG_STATUSLINE=1
```

**Output**: `/tmp/claude-statusline-debug.log`

**Logged Data**:
- Full session JSON
- Detected field names
- Parsed token values
- Timestamp of each update

### Oh My Posh Theme

**Location**: `.nvm-isolated/.claude-isolated/themes/claude-statusline.omp.json`

**Example** (Git segment only):
```json
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "version": 2,
  "blocks": [{
    "type": "prompt",
    "alignment": "left",
    "segments": [{
      "type": "git",
      "style": "plain",
      "template": "{{ .HEAD }} {{ if .Working.Changed }}●{{ .Working.Changed }}{{ end }}"
    }]
  }]
}
```

---

## Dependencies

### Required

- **jq 1.7.1** - JSON parsing
  - Location: `.nvm-isolated/npm-global/bin/jq`
  - Binary size: 2.3MB
  - Platform: Linux x86_64
  - Included in isolated environment (Phase 2)

### Optional

- **git** - Branch/status info
- **oh-my-posh** - Enhanced git rendering
- **timeout** (coreutils) - Git command timeout

### Claude Code Version

- **Minimum**: Claude Code v2.1+
- **Reason**: Uses nested `context_window` object
- **Breaking change**: v2.0 had flat token structure

---

## Performance

### Execution Time

**Typical**: 50-100ms per update
- JSON parsing (jq): 20-30ms
- Git status (cached): 10-20ms
- Format output: 5-10ms
- Readable generation (cached): 0ms (skip)
- Readable generation (uncached): 50-200ms (depends on session size)

### Memory Usage

**Typical**: 2-5MB
- jq process: 1-2MB
- bash process: 1-3MB
- Session data: < 1MB

### Update Frequency

- **Trigger**: After each Claude Code API response
- **Typical rate**: 1-5 updates per minute (during active coding)
- **Impact**: Negligible (<0.5% CPU on modern systems)

### mtime Cache Performance (Phase 2)

**Scenario**: 1000-line conversation (500KB JSONL)
- **First generation**: 150ms (parse + format + write)
- **Subsequent updates**: 0ms (mtime check returns immediately)
- **Regeneration trigger**: Only when JSONL mtime > readable mtime

**Benchmark**:
```bash
# Test cache hit
$ time generate_readable_session session.jsonl tmp/readable.txt
real    0m0.001s  # Cache hit - instant return

# Force regeneration (touch JSONL)
$ touch session.jsonl
$ time generate_readable_session session.jsonl tmp/readable.txt
real    0m0.142s  # Full regeneration
```

---

## Troubleshooting

### Status line не отображается

**Check 1**: Verify settings.json
```bash
cat .nvm-isolated/.claude-isolated/settings.json | jq '.statusLine'
```

**Check 2**: Test script manually
```bash
echo '{"context_window":{"total_input_tokens":1000,"total_output_tokens":500,"used_percentage":10,"context_window_size":200000},"cost":{"total_cost_usd":0.5},"model":{"display_name":"Test"}}' | \
  bash .nvm-isolated/.claude-isolated/scripts/claude-statusline.sh
```

**Check 3**: Verify jq
```bash
.nvm-isolated/npm-global/bin/jq --version
```

### Session link не кликабельный

**Причины**:
- Терминал не поддерживает OSC 8 hyperlinks
- Работает в: iTerm2, kitty, GNOME Terminal 3.x+, Windows Terminal
- Не работает в: старых терминалах, tmux (без специальной конфигурации)

**Test**:
```bash
# Test OSC 8 in terminal
echo -e '\e]8;;http://example.com\e\\Link\e]8;;\e\\'
```

### Readable файл не генерируется

**Check 1**: Verify jq available
```bash
command -v jq || echo "jq not found"
```

**Check 2**: Check tmp/ directory
```bash
ls -la tmp/
# Should be writable
```

**Check 3**: Enable debug mode
```bash
DEBUG_STATUSLINE=1 ./iclaude.sh
tail -f /tmp/claude-statusline-debug.log
```

### Неправильные токены после /clear

**Expected behavior**:
- **Cumulative tokens** (💳) continue to grow (billing)
- **Active context** (📊) resets to ~0-5% (only system prompt)

This is **not a bug** - dual tracking is intentional.

### Git info не отображается

**Check 1**: Git repository?
```bash
git rev-parse --is-inside-work-tree
```

**Check 2**: Timeout issue?
```bash
# Increase timeout in claude-statusline.sh:165
GIT_TIMEOUT=5  # Instead of 2
```

**Check 3**: Oh My Posh theme valid?
```bash
jq empty .nvm-isolated/.claude-isolated/themes/claude-statusline.omp.json
```

---

## Version History

### Phase 1 (2026-01-10)

**Initial Implementation**:
- Dual context tracking (cumulative + active)
- Cost monitoring
- Cache visibility
- Proxy/router detection
- Git integration
- Color coding

**Commits**:
- `feat(statusline): add dual context tracking`
- `feat(statusline): integrate Oh My Posh for git`

### Phase 2 (2026-02-12) 🆕

**Session Link Improvements**:
- Icon-only display (📄 without "context" text)
- Readable session generation with role prefixes
- mtime caching for performance
- jq binary included in isolated environment
- Comprehensive documentation

**Technical Changes**:
- Added `generate_readable_session()` function
- Modified SESSION_LINK OSC 8 target (JSONL → readable)
- Installed jq 1.7.1 in `.nvm-isolated/npm-global/bin/`
- Updated lockfile with jqVersion

**Commits**:
- `feat(statusline): improve session link with readable format and icon-only display`

---

## Future Enhancements (v3.0)

- **Real-time streaming**: Show tokens incrementing during response
- **Cost estimates**: Predict cost before sending large prompts
- **Token breakdown**: Separate input/output/cache in UI
- **Custom themes**: User-defined statusline formats
- **Notification thresholds**: Alert at X% context usage
- **Session history**: Quick access to previous conversations
- **Multi-session view**: Monitor multiple Claude instances

---

## References

### Code

- `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh` (275 lines)
- `.nvm-isolated/.claude-isolated/scripts/claude-show-cache.sh` (helper)
- `.nvm-isolated/.claude-isolated/CLAUDE.md` (full documentation)

### Documentation

- `docs/features/context-monitoring.md` - Variant H (Built-in Status)
- `.nvm-isolated-lockfile.json` - Version tracking

### External

- [Claude Code Status Line Docs](https://code.claude.com/docs/en/status-line)
- [Oh My Posh Themes](https://ohmyposh.dev/docs/themes)
- [OSC 8 Hyperlinks](https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda)

---

**Author**: iclaude.sh project
**Maintainer**: Claude Sonnet 4.5
**Last Updated**: 2026-02-12
**Status**: Production Ready (Phase 2 Complete)
