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

    # ONE-SHOT parse всех полей за один вызов jq
    local _parsed
    _parsed=$(echo "$session_data" | jq -r '
        (.context_window.total_input_tokens // 0 | tostring),
        (.context_window.total_output_tokens // 0 | tostring),
        (.model.display_name // .model.id // "Claude"),
        (.context_window.context_window_size // 200000 | tostring),
        (.context_window.current_usage.cache_read_input_tokens // 0 | tostring),
        (.context_window.current_usage.cache_creation_input_tokens // 0 | tostring),
        (.cost.total_cost_usd // 0 | tostring)
    ' 2>/dev/null)

    local total_input total_output model_name context_limit cache_read cache_creation cost
    {
        read -r total_input
        read -r total_output
        read -r model_name
        read -r context_limit
        read -r cache_read
        read -r cache_creation
        read -r cost
    } <<< "$_parsed"

    # Validate: check if we got valid data
    if [[ -z "$total_input" ]] || [[ -z "$total_output" ]] || \
       [[ "$total_input" == "null" ]] || [[ "$total_output" == "null" ]]; then
        return 1
    fi

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
