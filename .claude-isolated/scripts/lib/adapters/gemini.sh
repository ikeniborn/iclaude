#!/bin/bash
# Google Gemini API Adapter
# Parses Google Gemini API format
#
# API Format: Gemini REST API
# - Uses .usageMetadata.promptTokenCount
# - Uses .usageMetadata.candidatesTokenCount
# - Uses .modelVersion (model identifier)
# - NO native cache support (cache_* = 0)
# - Cost calculated via pricing-lookup.sh
#
# Supported models:
# - gemini-2.0-flash, gemini-2.5-flash
# - gemini-1.5-flash, gemini-1.5-pro
# - gemini-2.5-pro

# Source helper functions
ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ADAPTER_DIR/../provider-adapter.sh"
source "$ADAPTER_DIR/../pricing-lookup.sh"

# Get context limit for Gemini models
# Args: $1 - model name
# Returns: context limit in tokens
get_gemini_context_limit() {
    local model="$1"

    # Normalize for comparison
    local normalized=$(echo "$model" | tr '[:upper:]' '[:lower:]')

    case "$normalized" in
        # Gemini 2.x models
        gemini-2.0-flash*) echo "1000000" ;;  # 1M context
        gemini-2.5-flash*) echo "1000000" ;;
        gemini-2.5-pro*) echo "2000000" ;;    # 2M context

        # Gemini 1.5 models
        gemini-1.5-flash*) echo "1000000" ;;
        gemini-1.5-pro*) echo "2000000" ;;

        # Default
        *) echo "32000" ;;
    esac
}

# Parse Google Gemini API session data
# Args: $1 - session_data (JSON string)
# Returns: unified JSON format
parse_gemini_data() {
    local session_data="$1"

    # Guard: empty data
    if [[ -z "$session_data" ]] || [[ "$session_data" == "null" ]]; then
        return 1
    fi

    # Parse token counts (Gemini uses usageMetadata)
    local prompt_tokens
    local candidates_tokens
    prompt_tokens=$(echo "$session_data" | jq -r '.usageMetadata.promptTokenCount // 0' 2>/dev/null)
    candidates_tokens=$(echo "$session_data" | jq -r '.usageMetadata.candidatesTokenCount // 0' 2>/dev/null)

    # Validate: check if we got valid data
    if [[ -z "$prompt_tokens" ]] || [[ -z "$candidates_tokens" ]] || \
       [[ "$prompt_tokens" == "null" ]] || [[ "$candidates_tokens" == "null" ]]; then
        return 1
    fi

    # Parse model version
    # Gemini returns full model path like "models/gemini-2.5-pro-001"
    local model_version
    model_version=$(echo "$session_data" | jq -r '.modelVersion // .model // "gemini"' 2>/dev/null)

    # Extract short model name
    # "models/gemini-2.5-pro-001" -> "gemini-2.5-pro"
    local model_name=$(echo "$model_version" | sed -E 's|^models/||' | sed -E 's/-[0-9]{3,}$//')

    # Get display name
    local display_name
    display_name=$(get_model_display_name "$model_name")

    # Get context limit
    local context_limit
    context_limit=$(get_gemini_context_limit "$model_name")

    # Gemini supports cache, but not always reported in API
    # For now, set to 0 (can be extended later)
    local cache_read=0
    local cache_creation=0

    # Calculate cost using pricing lookup
    local cost
    cost=$(calculate_cost "$model_name" "$prompt_tokens" "$candidates_tokens")

    # Create unified data structure
    create_unified_data \
        "$prompt_tokens" \
        "$candidates_tokens" \
        "$context_limit" \
        "$cache_read" \
        "$cache_creation" \
        "$display_name" \
        "$cost"

    return 0
}

# Export functions
export -f get_gemini_context_limit
export -f parse_gemini_data
