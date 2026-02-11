#!/bin/bash
# Claude Code Status Line Script
# Displays dual context tracking (cumulative + active), model, cost, cache, proxy/router status, and git info
#
# Requirements: Claude Code v2.1+ (uses context_window object)
#
# Debug mode: export DEBUG_STATUSLINE=1 to enable verbose logging
#   - Logs session data JSON to /tmp/claude-statusline-debug.log
#   - Shows detected field names and parsed values
#
# Enable debug mode: DEBUG_STATUSLINE=1
[[ "${DEBUG_STATUSLINE:-0}" == "1" ]] && set -x

# Detect config directory (isolated vs system)
# When Claude Code calls this script, $CLAUDE_CONFIG_DIR is not set
# So we detect it based on script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../router.json" ]] || [[ -f "$SCRIPT_DIR/../settings.json" ]]; then
    # Running in isolated environment: scripts/ -> .claude-isolated/
    CLAUDE_CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    # Fallback to system config
    CLAUDE_CONFIG_DIR="${HOME}/.claude"
fi

# Read session data from STDIN
SESSION_DATA=$(cat)

# Debug: Log session data to file for diagnostics
LOG_FILE="/tmp/claude-statusline-debug.log"
if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
    {
        echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo "Session data received:"
        echo "$SESSION_DATA"
        echo "---"
    } >> "$LOG_FILE"
fi

# Debug: Log session data if debug mode enabled
if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
    echo "DEBUG: Session data received (logged to $LOG_FILE):" >&2
    echo "$SESSION_DATA" >&2
fi

# Check for jq availability
if ! command -v jq &>/dev/null; then
    echo "[Status line requires jq - install: sudo apt install jq]"
    exit 0  # Don't break Claude Code UI
fi

# Parse Claude session data (tokens, model, cost)
# Requires Claude Code v2.1+ (nested context_window object)
# Note: total_input/output_tokens = billing tokens (excludes cache reads)
TOTAL_INPUT=$(echo "$SESSION_DATA" | jq -r '.context_window.total_input_tokens // 0' 2>/dev/null)
TOTAL_OUTPUT=$(echo "$SESSION_DATA" | jq -r '.context_window.total_output_tokens // 0' 2>/dev/null)

# Debug: Log detected field names and parsed values
if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
    echo "DEBUG: Detected relevant field names:" >&2
    echo "$SESSION_DATA" | jq -r 'keys | map(select(test("token|cost|model"; "i"))) | join(", ")' >&2
    echo "DEBUG: Parsed tokens: INPUT=$TOTAL_INPUT, OUTPUT=$TOTAL_OUTPUT" >&2
fi

# Validate parsed data
if [[ -z "$TOTAL_INPUT" ]] || [[ -z "$TOTAL_OUTPUT" ]] || \
   [[ "$TOTAL_INPUT" == "null" ]] || [[ "$TOTAL_OUTPUT" == "null" ]]; then
    echo "[Status line: awaiting session data...]"
    exit 0  # Show message instead of breaking
fi

TOTAL_TOKENS=$((TOTAL_INPUT + TOTAL_OUTPUT))

# Parse model display name (Claude Code v2.1+)
MODEL=$(echo "$SESSION_DATA" | jq -r '.model.display_name // .model.id // "Sonnet 4.5"' 2>/dev/null)

# Get context limit from session data (Claude Code v2.1+)
CONTEXT_LIMIT=$(echo "$SESSION_DATA" | jq -r '.context_window.context_window_size // 200000' 2>/dev/null)

# Calculate API tokens percentage (billing only, excludes cache reads)
# Note: This is different from used_percentage which includes cache tokens
PERCENT=$(awk "BEGIN {printf \"%.0f\", ($TOTAL_TOKENS * 100.0 / $CONTEXT_LIMIT)}")

# Parse active context percentage (resets after /clear)
# This shows the actual context size for the NEXT message (includes cache reads!)
# Active context = API tokens + cache_read_tokens (often > API tokens)
ACTIVE_PERCENT=$(echo "$SESSION_DATA" | jq -r '.context_window.used_percentage // null' 2>/dev/null)

# Calculate active context tokens (if available)
ACTIVE_TOKENS=0
if [[ "$ACTIVE_PERCENT" != "null" ]] && [[ -n "$ACTIVE_PERCENT" ]]; then
    ACTIVE_TOKENS=$(awk "BEGIN {printf \"%.0f\", ($CONTEXT_LIMIT * $ACTIVE_PERCENT / 100.0)}")
fi

# Parse cache tokens (Claude Code v2.1+)
CACHE_READ=$(echo "$SESSION_DATA" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0' 2>/dev/null)
CACHE_CREATION=$(echo "$SESSION_DATA" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0' 2>/dev/null)
TOTAL_CACHE=$((CACHE_READ + CACHE_CREATION))

# Format cache display (show only if >0)
CACHE_DISPLAY=""
if [[ $TOTAL_CACHE -gt 0 ]]; then
    # Format: K for thousands, M for millions
    if [[ $TOTAL_CACHE -ge 1000000 ]]; then
        CACHE_FMT=$(awk "BEGIN {printf \"%.1fM\", ($TOTAL_CACHE / 1000000.0)}")
    elif [[ $TOTAL_CACHE -ge 1000 ]]; then
        CACHE_FMT=$(awk "BEGIN {printf \"%.0fK\", ($TOTAL_CACHE / 1000.0)}")
    else
        CACHE_FMT="$TOTAL_CACHE"
    fi
    CACHE_DISPLAY=" | 📦 ${CACHE_FMT}"
fi

COST=$(printf "%.2f" "$(echo "$SESSION_DATA" | jq -r '.cost.total_cost_usd // 0' 2>/dev/null)")

# Proxy detection (environment variables + fallback)
# Note: HTTPS_PROXY/HTTP_PROXY may not be set when Claude Code calls this script
# Try multiple fallback locations for proxy credentials
PROXY_ICON=""
if [[ -n "$HTTPS_PROXY" ]] || [[ -n "$HTTP_PROXY" ]]; then
    PROXY_ICON=" 🌐"
else
    # Try multiple fallback locations
    PROXY_CREDS_LOCATIONS=(
        "$CLAUDE_CONFIG_DIR/../../.claude_proxy_credentials"  # Isolated
        "$HOME/.claude_proxy_credentials"                      # Home directory
        "$(pwd)/.claude_proxy_credentials"                     # Current directory
    )

    for creds_file in "${PROXY_CREDS_LOCATIONS[@]}"; do
        if [[ -f "$creds_file" ]] && [[ -r "$creds_file" ]]; then
            # Check if file contains PROXY_URL
            if grep -q "^PROXY_URL=" "$creds_file" 2>/dev/null; then
                PROXY_ICON=" 🌐"
                break
            fi
        fi
    done
fi

# Router detection (check config file + ccr binary)
ROUTER_ICON=""
if [[ -f "$CLAUDE_CONFIG_DIR/router.json" ]] && command -v ccr &>/dev/null; then
    PROVIDER=$(jq -r '.routing.default // "unknown"' "$CLAUDE_CONFIG_DIR/router.json" 2>/dev/null)
    ROUTER_ICON=" | 🔀 $PROVIDER"
fi

# Git info (branch + uncommitted changes)
GIT_INFO=""
GIT_TIMEOUT=2  # 2 second timeout

if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    # Call Oh My Posh for git rendering (if available)
    theme_config="$CLAUDE_CONFIG_DIR/themes/claude-statusline.omp.json"
    if command -v oh-my-posh &>/dev/null && [[ -f "$theme_config" ]]; then
        # Validate theme file is valid JSON
        if jq empty "$theme_config" 2>/dev/null; then
            # Use timeout if available
            if command -v timeout &>/dev/null; then
                GIT_INFO=$(timeout $GIT_TIMEOUT oh-my-posh print primary --config "$theme_config" 2>/dev/null || true)
            else
                GIT_INFO=$(oh-my-posh print primary --config "$theme_config" 2>/dev/null || true)
            fi
            # Remove ANSI color codes for consistent output
            GIT_INFO=$(echo "$GIT_INFO" | sed 's/\x1b\[[0-9;]*m//g')
        fi
    fi

    # Fallback to bash git parsing if Oh My Posh unavailable or failed
    if [[ -z "$GIT_INFO" ]]; then
        if command -v timeout &>/dev/null; then
            BRANCH=$(timeout $GIT_TIMEOUT git symbolic-ref --short HEAD 2>/dev/null || timeout $GIT_TIMEOUT git rev-parse --short HEAD 2>/dev/null || echo "unknown")
            CHANGES=$(timeout $GIT_TIMEOUT git status --porcelain 2>/dev/null | wc -l || echo "?")
            # Get commits ahead of upstream
            AHEAD=$(timeout $GIT_TIMEOUT git rev-list --count @{upstream}..HEAD 2>/dev/null || echo "0")
        else
            BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "unknown")
            CHANGES=$(git status --porcelain 2>/dev/null | wc -l || echo "?")
            # Get commits ahead of upstream
            AHEAD=$(git rev-list --count @{upstream}..HEAD 2>/dev/null || echo "0")
        fi
        GIT_INFO=" | 🔱 $BRANCH"
        [[ "$CHANGES" != "0" ]] && [[ "$CHANGES" != "?" ]] && GIT_INFO+=" ●$CHANGES"
        [[ "$AHEAD" != "0" ]] && GIT_INFO+=" ↑$AHEAD"
    else
        # Add separator for Oh My Posh output
        GIT_INFO=" | ${GIT_INFO}"
    fi
fi

# Color selection based on context usage
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"
RESET="\033[0m"

if [[ $PERCENT -lt 50 ]]; then
    COLOR=$GREEN
elif [[ $PERCENT -lt 75 ]]; then
    COLOR=$YELLOW
else
    COLOR=$RED
fi

# Format tokens in compact K/M format (like cache display)
# Format: K for thousands, M for millions
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

TOTAL_TOKENS_FMT=$(format_tokens $TOTAL_TOKENS)
ACTIVE_TOKENS_FMT=$(format_tokens $ACTIVE_TOKENS)

# Build context display string
# Shows: API tokens (billing) | active context (includes cache reads)
# Note: Active context often > API tokens due to prompt caching
# Handle temporary null values immediately after /clear
if [[ "$ACTIVE_PERCENT" == "null" ]] || [[ -z "$ACTIVE_PERCENT" ]]; then
    # Immediately after /clear: used_percentage is null for ~10-40 seconds
    # Show 0% active until Claude Code sends real data
    ACTIVE_COLOR=$GREEN
    ACTIVE_TOKENS=0
    ACTIVE_TOKENS_FMT="0"
    ACTIVE_PERCENT="0"
elif [[ "$ACTIVE_PERCENT" == "0" ]] || [[ "$ACTIVE_PERCENT" == "0.0" ]]; then
    # Active context reset to 0% (only system prompt)
    ACTIVE_COLOR=$GREEN
    ACTIVE_TOKENS=0
    ACTIVE_TOKENS_FMT="0"
else
    # Color active context based on its percentage (not cumulative)
    if [[ ${ACTIVE_PERCENT%.*} -lt 50 ]]; then
        ACTIVE_COLOR=$GREEN
    elif [[ ${ACTIVE_PERCENT%.*} -lt 75 ]]; then
        ACTIVE_COLOR=$YELLOW
    else
        ACTIVE_COLOR=$RED
    fi
fi

CONTEXT_DISPLAY="💳 ${TOTAL_TOKENS_FMT} | ${ACTIVE_COLOR}📊 ${ACTIVE_TOKENS_FMT} (${ACTIVE_PERCENT}%)${RESET}"

# Output formatted status line
echo -e "${CONTEXT_DISPLAY}${CACHE_DISPLAY} | ${BLUE}${MODEL}${RESET} | \$${COST} |${PROXY_ICON}${ROUTER_ICON}${GIT_INFO}"
