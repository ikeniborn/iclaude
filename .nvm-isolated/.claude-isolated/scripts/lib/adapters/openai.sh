#!/bin/bash
# OpenAI-Compatible API Adapter
# Parses OpenAI API format (also used by DeepSeek, OpenRouter, and others)
#
# API Format: OpenAI Chat Completions API
# - Uses .usage.prompt_tokens
# - Uses .usage.completion_tokens
# - Uses .model (model identifier)
# - NO native cache support (cache_* = 0)
# - Cost calculated via pricing-lookup.sh
#
# Compatible providers:
# - OpenAI (gpt-4, gpt-3.5-turbo, etc.)
# - DeepSeek (deepseek-chat, deepseek-coder)
# - OpenRouter (various models)
# - Any OpenAI-compatible endpoint

# Source helper functions
ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ADAPTER_DIR/../provider-adapter.sh"
source "$ADAPTER_DIR/../pricing-lookup.sh"

# Get context limit for known models
# Args: $1 - model name
# Returns: context limit in tokens
get_context_limit_for_model() {
    local model="$1"

    # Normalize for comparison
    local normalized
    normalized=$(normalize_model_name "$model")

    case "$normalized" in
        # OpenAI models
        gpt-4o) echo "128000" ;;
        gpt-4-turbo) echo "128000" ;;
        gpt-4) echo "8192" ;;
        gpt-3.5-turbo) echo "16385" ;;
        o1) echo "200000" ;;
        o1-mini) echo "128000" ;;

        # DeepSeek models
        deepseek-chat) echo "64000" ;;
        deepseek-coder) echo "64000" ;;
        deepseek-reasoner) echo "64000" ;;
        deepseek-v3) echo "64000" ;;
        deepseek-r1) echo "64000" ;;

        # Default fallback
        *) echo "8192" ;;
    esac
}

# Parse OpenAI-compatible API session data
# Args: $1 - session_data (JSON string)
# Returns: unified JSON format
parse_openai_data() {
    local session_data="$1"

    # Guard: empty data
    if [[ -z "$session_data" ]] || [[ "$session_data" == "null" ]]; then
        return 1
    fi

    # Parse token counts
    local prompt_tokens
    local completion_tokens
    prompt_tokens=$(echo "$session_data" | jq -r '.usage.prompt_tokens // 0' 2>/dev/null)
    completion_tokens=$(echo "$session_data" | jq -r '.usage.completion_tokens // 0' 2>/dev/null)

    # Validate: check if we got valid data
    if [[ -z "$prompt_tokens" ]] || [[ -z "$completion_tokens" ]] || \
       [[ "$prompt_tokens" == "null" ]] || [[ "$completion_tokens" == "null" ]]; then
        return 1
    fi

    # Parse model name
    local model_name
    model_name=$(echo "$session_data" | jq -r '.model // "unknown"' 2>/dev/null)

    # Get display name (friendly)
    local display_name
    display_name=$(get_model_display_name "$model_name")

    # Get context limit
    local context_limit
    context_limit=$(get_context_limit_for_model "$model_name")

    # OpenAI API does NOT support prompt cache
    # Set cache tokens to 0
    local cache_read=0
    local cache_creation=0

    # Calculate cost using pricing lookup
    local cost
    cost=$(calculate_cost "$model_name" "$prompt_tokens" "$completion_tokens")

    # Create unified data structure
    create_unified_data \
        "$prompt_tokens" \
        "$completion_tokens" \
        "$context_limit" \
        "$cache_read" \
        "$cache_creation" \
        "$display_name" \
        "$cost"

    return 0
}

# Export functions
export -f get_context_limit_for_model
export -f parse_openai_data
