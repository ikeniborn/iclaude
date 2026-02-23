#!/bin/bash
# postToolUse hook - monitors context window usage and alerts on threshold
# Triggered after each tool execution in Claude Code

# Read JSON input from stdin
INPUT=$(cat)

# Exit early if jq not available
if ! command -v jq &>/dev/null; then
    exit 0
fi

# Extract token usage from current turn
CURRENT_INPUT=$(echo "$INPUT" | jq -r '.usage.input_tokens // 0' 2>/dev/null)
CURRENT_OUTPUT=$(echo "$INPUT" | jq -r '.usage.output_tokens // 0' 2>/dev/null)
CURRENT_TOTAL=$((CURRENT_INPUT + CURRENT_OUTPUT))

# Get cumulative tokens from .claude.json
CLAUDE_JSON="${CLAUDE_DIR:-$HOME/.claude}/.claude.json"
PROJECT_PATH=$(pwd)

if [[ -f "$CLAUDE_JSON" ]]; then
    # Extract total tokens for current project
    TOTAL_INPUT=$(jq -r --arg path "$PROJECT_PATH" \
        '.projects[$path].lastTotalInputTokens // 0' "$CLAUDE_JSON" 2>/dev/null)
    TOTAL_OUTPUT=$(jq -r --arg path "$PROJECT_PATH" \
        '.projects[$path].lastTotalOutputTokens // 0' "$CLAUDE_JSON" 2>/dev/null)
    CACHE_READ=$(jq -r --arg path "$PROJECT_PATH" \
        '.projects[$path].lastTotalCacheReadInputTokens // 0' "$CLAUDE_JSON" 2>/dev/null)

    TOTAL_TOKENS=$((TOTAL_INPUT + TOTAL_OUTPUT))
else
    TOTAL_TOKENS=$CURRENT_TOTAL
fi

# Configuration
CONTEXT_LIMIT=200000  # Sonnet 4.5 limit
WARNING_THRESHOLD=80  # Warn at 80%
CRITICAL_THRESHOLD=90 # Critical at 90%

# Calculate percentage
if [[ $TOTAL_TOKENS -gt 0 ]]; then
    PERCENT=$((TOTAL_TOKENS * 100 / CONTEXT_LIMIT))
else
    PERCENT=0
fi

# Format numbers with thousands separators
format_number() {
    printf "%'d" "$1"
}

# Send notification to stderr (Claude Code displays this)
send_notification() {
    local level=$1
    local message=$2

    # Claude Code displays stderr messages in UI
    echo "[$level] $message" >&2

    # Optional: system notification (if notify-send available)
    if command -v notify-send &>/dev/null; then
        notify-send "Claude Code - Context Warning" "$message" --urgency=normal
    fi
}

# Check thresholds and alert
if [[ $PERCENT -ge $CRITICAL_THRESHOLD ]]; then
    send_notification "🔴 CRITICAL" \
        "Context usage: $(format_number $TOTAL_TOKENS)/$CONTEXT_LIMIT tokens (${PERCENT}%) - Consider starting new session"

elif [[ $PERCENT -ge $WARNING_THRESHOLD ]]; then
    send_notification "⚠️  WARNING" \
        "Context usage: $(format_number $TOTAL_TOKENS)/$CONTEXT_LIMIT tokens (${PERCENT}%) - Approaching limit"
fi

# Log to file for debugging (optional)
LOG_FILE="/tmp/claude-context-monitor.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') | Tokens: $TOTAL_TOKENS/$CONTEXT_LIMIT (${PERCENT}%) | Cache: $CACHE_READ" >> "$LOG_FILE"

# Exit 0 to allow operation to continue (non-blocking)
exit 0
