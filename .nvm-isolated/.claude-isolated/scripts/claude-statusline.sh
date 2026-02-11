#!/bin/bash
# Claude Code Status Line Script
# Displays context usage, model, cost, proxy/router status, and git info
#
# Debug mode: export DEBUG_STATUSLINE=1 to enable verbose logging
#   - Shows session data JSON structure
#   - Logs detected field names (filtered: token/cost/model fields only)
#   - Displays parsed token values
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
# Support multiple field name formats for compatibility
TOTAL_INPUT=$(echo "$SESSION_DATA" | jq -r '
  .lastTotalInputTokens //
  .totalInputTokens //
  .inputTokens //
  0
' 2>/dev/null)

TOTAL_OUTPUT=$(echo "$SESSION_DATA" | jq -r '
  .lastTotalOutputTokens //
  .totalOutputTokens //
  .outputTokens //
  0
' 2>/dev/null)

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

# Parse model - handle both string and object formats
# Support multiple field names for compatibility with different Claude Code versions
MODEL=$(echo "$SESSION_DATA" | jq -r '
  if .model | type == "object" then
    .model.display_name // .model.displayName // .model.id // .model.modelId // .model.modelName // "unknown"
  else
    .model // .modelId // .modelName // "sonnet-4.5"
  end
' 2>/dev/null)

# Detect context limit based on model
case "$MODEL" in
    *opus*|*Opus*)
        CONTEXT_LIMIT=200000
        ;;
    *sonnet*|*Sonnet*)
        CONTEXT_LIMIT=200000
        ;;
    *haiku*|*Haiku*)
        CONTEXT_LIMIT=200000
        ;;
    *)
        CONTEXT_LIMIT=200000  # Default
        ;;
esac

# Use floating-point arithmetic to avoid truncation for small token counts
PERCENT=$(awk "BEGIN {printf \"%.0f\", ($TOTAL_TOKENS * 100.0 / $CONTEXT_LIMIT)}")

COST=$(printf "%.2f" "$(echo "$SESSION_DATA" | jq -r '
  .lastCost // .totalCost // .cost // 0
' 2>/dev/null)")

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
    ROUTER_ICON=" 🔀$PROVIDER"
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
        else
            BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "unknown")
            CHANGES=$(git status --porcelain 2>/dev/null | wc -l || echo "?")
        fi
        GIT_INFO="  $BRANCH"
        [[ "$CHANGES" != "0" ]] && [[ "$CHANGES" != "?" ]] && GIT_INFO+=" ●$CHANGES"
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

# Format tokens with thousands separator
# Set locale for number formatting (with fallback)
export LC_NUMERIC="${LC_NUMERIC:-en_US.UTF-8}"
TOTAL_TOKENS_FMT=$(printf "%'d" $TOTAL_TOKENS 2>/dev/null || echo "$TOTAL_TOKENS")
CONTEXT_LIMIT_FMT=$(printf "%'d" $CONTEXT_LIMIT 2>/dev/null || echo "$CONTEXT_LIMIT")

# Output formatted status line
echo -e "${COLOR}${TOTAL_TOKENS_FMT}/${CONTEXT_LIMIT_FMT} (${PERCENT}%)${RESET} ${BLUE}${MODEL}${RESET} \$${COST}${PROXY_ICON}${ROUTER_ICON}${GIT_INFO}"
