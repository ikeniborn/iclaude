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

`.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`

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

Format: `[cache]79K`

**Calculation:** `cache_read + cache_creation`

**Features:**
- Format: K for thousands, M for millions
- Only shown when cache > 0
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

Format: `[session]` - clickable hyperlink (OSC 8)

**Features:**
- Click to open human-readable conversation in your editor
- **Session-specific files**: Each session has unique readable file (no conflicts)
- **Append-only optimization**: Only processes new messages (19x faster)
- **Smart regeneration**: Full rebuild only when needed (/compact, first run, JSONL truncated)
- **Performance**: 94ms append vs 1.87s full regen (200 lines)
- Readable file saved to: `<project>/.claude-sessions/readable-{session-id}.txt`
- Metadata tracking: `.claude-sessions/readable-{session-id}.txt.meta` (processed lines count)
- **Compact detection**: Shows `━━━ [cache] Context Compact ━━━` marker after /compact
- Format: [user] USER / [assistant] ASSISTANT prefixes with word wrap (80 chars)
- Works in modern terminals: iTerm2, kitty, GNOME Terminal 3.x+, Windows Terminal
- Falls back to plain text in terminals without hyperlink support

### 8. Git Info

Branch name + uncommitted changes count (e.g., "master" or "feature-branch +3")

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

#### Display Modes

**Full Mode (≥130 columns)**
```
💳 113K | 📊 51K (26%) | 📦 79K | 🔒 45K | Sonnet 4.5 | $1.06 🌐 | 🔀 claude-sonnet-4-5 | 📄 | 🔱 test ●2
```
- All components visible without abbreviations
- Shows buffer (🔒), full model name, full router provider
- Optimal for wide terminals (≥130 cols)

**Compact Mode (110-129 columns)**
```
💳 113K | 📊 51K (26%) | 📦 79K | S4.5 | $1.06 🌐 | 🔀 sonnet-4-5 | 📄 | 🔱 test ●2
```
- Smart abbreviations to save space
- Model abbreviated: "Sonnet 4.5" → "S4.5"
- Router abbreviated: "claude-sonnet-4-5" → "sonnet-4-5"
- Buffer hidden (not critical)
- Saves ~24 characters compared to full mode

**Minimal Mode (<110 columns)**
```
💳 113K | 📊 51K (26%) | S4.5 | $1.06
```
- Only critical metrics: tokens, model, cost
- Hides cache, proxy, router, session link, git info
- Guaranteed to fit in narrow terminals
- Saves ~84 characters compared to full mode

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

**Solution**: Smart waiting with stability detection

- **Detection**: Uses session-specific marker file `/tmp/claude-statusline-first-run-${SESSION_ID}`
- **First run behavior**:
  1. **Minimum delay** (3 seconds): Wait for system messages to appear
  2. **Stability check**: Monitor session transcript file for changes
  3. **Adaptive waiting**: Exit when file stable for 2 seconds (no changes)
  4. **Timeout protection**: Maximum 15 seconds wait
  5. **Output**: Show status line after messages cleared
- **Subsequent runs**: Normal instant output (no delay)

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

### Session Link Optimizations (Phase 2.1)

The readable session generation uses three key optimizations for performance:

#### 1. Session-Specific Filenames

- Each session gets unique file: `.claude-sessions/readable-{session-id}.txt`
- Prevents conflicts when running multiple parallel Claude sessions
- Example: `readable-abc123.txt`, `readable-def456.txt`

#### 2. Append-Only Updates

- Tracks processed lines in metadata file: `.claude-sessions/readable-{session-id}.txt.meta`
- Only processes NEW messages since last update (incremental)
- Performance: 94ms (append) vs 1.87s (full regen) for 200-line session
- **19x faster** for incremental updates

#### 3. Smart Regeneration Triggers

Full rebuild occurs only when necessary:
- First run (readable file doesn't exist)
- `/compact` detected (context compression happened)
- JSONL truncated (current lines < processed lines)
- Append-only used for normal message additions

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
.claude-sessions/
  readable-abc123.txt       # Session abc123 conversation
  readable-abc123.txt.meta  # Metadata: processed lines count
  readable-def456.txt       # Session def456 conversation
  readable-def456.txt.meta  # Metadata
```

## Configuration

### Setup Instructions

Enable statusline in Claude Code settings:

**File:** `.nvm-isolated/.claude-isolated/settings.json` (isolated mode) or `~/.claude/settings.json` (system mode)

```json
{
  "statusLine": {
    "type": "command",
    "command": "/absolute/path/to/.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh"
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
.nvm-isolated/.claude-isolated/scripts/claude-show-cache.sh --cache

# View last 5 messages (default)
.nvm-isolated/.claude-isolated/scripts/claude-show-cache.sh

# View last N messages
.nvm-isolated/.claude-isolated/scripts/claude-show-cache.sh --last 10

# View full conversation
.nvm-isolated/.claude-isolated/scripts/claude-show-cache.sh --full
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
ls -lh .claude-sessions/

# View specific session
cat .claude-sessions/readable-{session-id}.txt

# View most recent session (statusline generates them automatically)
ls -t .claude-sessions/readable-*.txt | head -1 | xargs cat

# Check metadata (processed lines)
cat .claude-sessions/readable-{session-id}.txt.meta

# Cleanup old sessions (older than 7 days)
find .claude-sessions/ -name "readable-*.txt*" -mtime +7 -delete
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

**Symptoms:** [session] icon shows but not clickable

**Solutions:**
1. Check terminal emulator supports OSC 8 hyperlinks:
   - Supported: iTerm2, kitty, GNOME Terminal 3.x+, Windows Terminal
   - Not supported: Basic xterm, older terminals
2. Verify readable file exists: `ls .claude-sessions/readable-*.txt`
3. Check file permissions: `chmod 644 .claude-sessions/readable-*.txt`

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
- **Developer Guide**: `.nvm-isolated/.claude-isolated/CLAUDE.md` - Architecture and internals
- **Skills System**: `.nvm-isolated/.claude-isolated/skills/` - Claude Code skills integration
- **Proxy Configuration**: `README.md` section on proxy setup
- **Router Integration**: `README.md` section on Claude Code Router

## Changelog

### Phase 2.2 (Current)
- Added adaptive display modes (full/compact/minimal)
- Automatic terminal width detection
- Smart abbreviations for narrow terminals
- Prevents line wrapping on all terminal sizes
- Configurable via STATUSLINE_ADAPTIVE environment variable

### Phase 2.1
- Added append-only optimization (19x faster)
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
