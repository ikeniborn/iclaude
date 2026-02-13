#!/bin/bash
# Claude Code Context Viewer
# Shows current session context and cached summary after /compact
#
# Usage:
#   claude-show-cache.sh [--full]     Show full context
#   claude-show-cache.sh [--last N]   Show last N messages (default: 5)
#   claude-show-cache.sh [--cache]    Show only cached summary

set -euo pipefail

# Detect config directory (isolated vs system)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../settings.json" ]]; then
    CLAUDE_CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    CLAUDE_CONFIG_DIR="${HOME}/.claude"
fi

# Check for jq
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required. Install: sudo apt install jq" >&2
    exit 1
fi

# Parse arguments
SHOW_FULL=false
SHOW_CACHE_ONLY=false
LAST_N=5

while [[ $# -gt 0 ]]; do
    case "$1" in
        --full)
            SHOW_FULL=true
            shift
            ;;
        --cache)
            SHOW_CACHE_ONLY=true
            shift
            ;;
        --last)
            LAST_N="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--full|--cache|--last N]" >&2
            exit 1
            ;;
    esac
done

# Find active session (most recently modified .jsonl file)
# Claude Code v2.x stores sessions in projects/ directory
PROJECTS_DIR="$CLAUDE_CONFIG_DIR/projects"
if [[ ! -d "$PROJECTS_DIR" ]]; then
    echo "Error: No projects directory found at $PROJECTS_DIR" >&2
    exit 1
fi

# Get current project path (convert /home/user/project -> -home-user-project)
CURRENT_PROJECT_PATH=$(pwd | sed 's|/|-|g')
PROJECT_SESSION_DIR="$PROJECTS_DIR/$CURRENT_PROJECT_PATH"

# Find most recent session file in current project (or all projects if not found)
if [[ -d "$PROJECT_SESSION_DIR" ]]; then
    ACTIVE_SESSION=$(find "$PROJECT_SESSION_DIR" -maxdepth 1 -name "*.jsonl" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
else
    # Fallback: search all projects
    ACTIVE_SESSION=$(find "$PROJECTS_DIR" -name "*.jsonl" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
fi

if [[ -z "$ACTIVE_SESSION" ]]; then
    echo "Error: No active session found in $PROJECTS_DIR" >&2
    echo "Current project: $CURRENT_PROJECT_PATH" >&2
    exit 1
fi

SESSION_ID=$(basename "$ACTIVE_SESSION" .jsonl)
echo "📄 Session: $SESSION_ID"
echo "📍 File: $ACTIVE_SESSION"
echo ""

# Show cache info first (if requested or available)
if [[ "$SHOW_CACHE_ONLY" == true ]] || [[ "$SHOW_FULL" == true ]]; then
    # Look for compact/summary messages in session
    COMPACT_MSG=$(grep -E '"type":"compact"|"compacted":true' "$ACTIVE_SESSION" 2>/dev/null | tail -1 || true)

    if [[ -n "$COMPACT_MSG" ]]; then
        echo "🗜️  CACHED SUMMARY (from /compact):"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Extract summary text from compact message
        SUMMARY=$(echo "$COMPACT_MSG" | jq -r '.summary // .content // "No summary text found"' 2>/dev/null)
        echo "$SUMMARY" | fold -w 80 -s

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        # Show cache stats
        CACHE_SIZE=$(echo "$COMPACT_MSG" | jq -r '.cacheTokens // "unknown"' 2>/dev/null)
        echo "📦 Cache size: $CACHE_SIZE tokens"
        echo ""
    else
        echo "ℹ️  No cached summary found (session not compacted yet)"
        echo ""
    fi

    if [[ "$SHOW_CACHE_ONLY" == true ]]; then
        exit 0
    fi
fi

# Show recent messages
if [[ "$SHOW_FULL" == true ]]; then
    echo "💬 FULL CONVERSATION:"
    MESSAGES=$(cat "$ACTIVE_SESSION")
else
    echo "💬 LAST $LAST_N MESSAGES:"
    MESSAGES=$(tail -n "$LAST_N" "$ACTIVE_SESSION")
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Parse and display messages
echo "$MESSAGES" | while IFS= read -r line; do
    # Extract message fields (Claude Code v2.x structure)
    ROLE=$(echo "$line" | jq -r '.message.role // .userType // "unknown"' 2>/dev/null)
    TYPE=$(echo "$line" | jq -r '.type // "message"' 2>/dev/null)

    # Get content type and text
    CONTENT_TYPE=$(echo "$line" | jq -r '.message.content[0].type // "unknown"' 2>/dev/null)

    # Extract text based on content type
    case "$CONTENT_TYPE" in
        text)
            CONTENT_TEXT=$(echo "$line" | jq -r '.message.content[0].text // empty' 2>/dev/null)
            CONTENT_LABEL=""
            ;;
        thinking)
            CONTENT_TEXT=$(echo "$line" | jq -r '.message.content[0].thinking // empty' 2>/dev/null)
            CONTENT_LABEL=" [thinking]"
            ;;
        tool_use)
            TOOL_NAME=$(echo "$line" | jq -r '.message.content[0].name // "unknown"' 2>/dev/null)
            TOOL_INPUT=$(echo "$line" | jq -c '.message.content[0].input // {}' 2>/dev/null)
            CONTENT_TEXT="Tool: $TOOL_NAME\nInput: $TOOL_INPUT"
            CONTENT_LABEL=" [tool_use]"
            ;;
        tool_result)
            TOOL_CONTENT=$(echo "$line" | jq -r '.message.content[0].content // empty' 2>/dev/null)
            CONTENT_TEXT="$TOOL_CONTENT"
            CONTENT_LABEL=" [tool_result]"
            ;;
        *)
            # Unknown content type - show raw JSON
            CONTENT_TEXT=$(echo "$line" | jq -c '.message.content[0] // empty' 2>/dev/null)
            CONTENT_LABEL=" [$CONTENT_TYPE]"
            ;;
    esac

    # Skip empty messages
    if [[ -z "$CONTENT_TEXT" ]] || [[ "$CONTENT_TEXT" == "null" ]]; then
        continue
    fi

    # Format based on role
    case "$ROLE" in
        user)
            echo -e "\n👤 USER${CONTENT_LABEL}:"
            ;;
        assistant)
            echo -e "\n🤖 ASSISTANT${CONTENT_LABEL}:"
            ;;
        system)
            echo -e "\n⚙️  SYSTEM${CONTENT_LABEL}:"
            ;;
        external)
            echo -e "\n👤 USER${CONTENT_LABEL}:"
            ;;
        *)
            echo -e "\n📝 $ROLE ($TYPE)${CONTENT_LABEL}:"
            ;;
    esac

    # Show content (truncate if too long and not --full)
    if [[ "$SHOW_FULL" == true ]]; then
        echo "$CONTENT_TEXT" | fold -w 80 -s
    else
        # Show first 300 chars
        PREVIEW=$(echo "$CONTENT_TEXT" | head -c 300)
        echo "$PREVIEW" | fold -w 80 -s
        CONTENT_LEN=$(echo "$CONTENT_TEXT" | wc -c)
        if [[ $CONTENT_LEN -gt 300 ]]; then
            echo "... (truncated, use --full to see complete message)"
        fi
    fi
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Usage:"
echo "  claude-show-cache.sh --full      # Show full conversation"
echo "  claude-show-cache.sh --cache     # Show only cached summary"
echo "  claude-show-cache.sh --last 10   # Show last 10 messages"
echo "  code $ACTIVE_SESSION             # Open session in VS Code"
