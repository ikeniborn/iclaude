#!/bin/bash
# Anthropic Claude API Adapter
# Parses native Claude API format (from Anthropic)
#
# API Format: Claude Code v2.1+ session data
# - Uses .context_window.total_input_tokens (billing tokens)
# - Uses .context_window.total_output_tokens (billing tokens)
# - Uses .context_window.current_usage.cache_* (cache metrics)
# - Uses .cost.total_cost_usd (pre-calculated cost)
#
# 100% backward compatible with existing claude-statusline.sh logic

# Source helper functions
ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ADAPTER_DIR/../provider-adapter.sh"

# Parse Anthropic Claude API session data
# Args: $1 - session_data (JSON string)
# Returns: unified JSON format (via create_unified_data)
parse_anthropic_data() {
    local session_data="$1"

    # Guard: empty data
    if [[ -z "$session_data" ]] || [[ "$session_data" == "null" ]]; then
        return 1
    fi

    # Parse token counts (billing tokens, excludes cache reads)
    # These are the exact same fields as current statusline.sh (lines 55-56)
    local total_input
    local total_output
    total_input=$(echo "$session_data" | jq -r '.context_window.total_input_tokens // 0' 2>/dev/null)
    total_output=$(echo "$session_data" | jq -r '.context_window.total_output_tokens // 0' 2>/dev/null)

    # Validate: check if we got valid data
    if [[ -z "$total_input" ]] || [[ -z "$total_output" ]] || \
       [[ "$total_input" == "null" ]] || [[ "$total_output" == "null" ]]; then
        return 1
    fi

    # Parse model info (line 75 in statusline.sh)
    local model_name
    model_name=$(echo "$session_data" | jq -r '.model.display_name // .model.id // "Claude"' 2>/dev/null)

    # Parse context limit (line 78 in statusline.sh)
    local context_limit
    context_limit=$(echo "$session_data" | jq -r '.context_window.context_window_size // 200000' 2>/dev/null)

    # Parse cache tokens (lines 99-100 in statusline.sh)
    local cache_read
    local cache_creation
    cache_read=$(echo "$session_data" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0' 2>/dev/null)
    cache_creation=$(echo "$session_data" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0' 2>/dev/null)

    # Parse cost (line 117 in statusline.sh)
    # Claude API provides pre-calculated cost
    local cost
    cost=$(echo "$session_data" | jq -r '.cost.total_cost_usd // 0' 2>/dev/null)

    # Create unified data structure
    create_unified_data \
        "$total_input" \
        "$total_output" \
        "$context_limit" \
        "$cache_read" \
        "$cache_creation" \
        "$model_name" \
        "$cost"

    return 0
}

# Export function
export -f parse_anthropic_data
