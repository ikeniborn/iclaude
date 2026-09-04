#!/bin/bash
# Generic Fallback Adapter
# Handles unknown/unrecognized provider formats
#
# Strategy: Best-effort parsing with graceful degradation
# - Tries multiple common field patterns
# - Returns minimal data if full parsing fails
# - Always succeeds (never returns error)
#
# Use cases:
# - New providers not yet supported
# - Custom API endpoints
# - Malformed/incomplete responses
# - Future-proofing

# Source helper functions
ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ADAPTER_DIR/../provider-adapter.sh"

# Try to extract tokens from various possible fields
# Args: $1 - session_data (JSON string)
# Returns: tokens as integer, or 0 if not found
try_extract_tokens() {
    local session_data="$1"
    local field_name="$2"

    # Try multiple possible field locations
    local value

    # Pattern 1: .usage.field_name
    value=$(echo "$session_data" | jq -r ".usage.${field_name} // empty" 2>/dev/null)
    [[ -n "$value" ]] && [[ "$value" != "null" ]] && echo "$value" && return 0

    # Pattern 2: .tokens.field_name
    value=$(echo "$session_data" | jq -r ".tokens.${field_name} // empty" 2>/dev/null)
    [[ -n "$value" ]] && [[ "$value" != "null" ]] && echo "$value" && return 0

    # Pattern 3: .field_name (top level)
    value=$(echo "$session_data" | jq -r ".${field_name} // empty" 2>/dev/null)
    [[ -n "$value" ]] && [[ "$value" != "null" ]] && echo "$value" && return 0

    # Pattern 4: Common aliases
    case "$field_name" in
        prompt_tokens)
            value=$(echo "$session_data" | jq -r '.usage.input_tokens // .input_tokens // empty' 2>/dev/null)
            ;;
        completion_tokens)
            value=$(echo "$session_data" | jq -r '.usage.output_tokens // .output_tokens // empty' 2>/dev/null)
            ;;
    esac

    [[ -n "$value" ]] && [[ "$value" != "null" ]] && echo "$value" && return 0

    # Not found
    echo "0"
    return 1
}

# Try to extract model name
# Args: $1 - session_data (JSON string)
# Returns: model name string, or "Unknown" if not found
try_extract_model() {
    local session_data="$1"

    # Try multiple possible field locations
    local model

    model=$(echo "$session_data" | jq -r '.model // empty' 2>/dev/null)
    [[ -n "$model" ]] && [[ "$model" != "null" ]] && echo "$model" && return 0

    model=$(echo "$session_data" | jq -r '.model.name // empty' 2>/dev/null)
    [[ -n "$model" ]] && [[ "$model" != "null" ]] && echo "$model" && return 0

    model=$(echo "$session_data" | jq -r '.model.id // empty' 2>/dev/null)
    [[ -n "$model" ]] && [[ "$model" != "null" ]] && echo "$model" && return 0

    model=$(echo "$session_data" | jq -r '.modelVersion // empty' 2>/dev/null)
    [[ -n "$model" ]] && [[ "$model" != "null" ]] && echo "$model" && return 0

    # Not found
    echo "Unknown Provider"
    return 1
}

# Parse generic/unknown provider data
# Args: $1 - session_data (JSON string)
# Returns: unified JSON format (always succeeds)
parse_generic_data() {
    local session_data="$1"

    # Guard: empty data - return minimal valid response
    if [[ -z "$session_data" ]] || [[ "$session_data" == "null" ]]; then
        create_unified_data 0 0 200000 0 0 "Unknown" 0
        return 0
    fi

    # Try to extract tokens using best-effort patterns
    local prompt_tokens
    local completion_tokens
    prompt_tokens=$(try_extract_tokens "$session_data" "prompt_tokens")
    completion_tokens=$(try_extract_tokens "$session_data" "completion_tokens")

    # Try to extract model name
    local model_name
    model_name=$(try_extract_model "$session_data")

    # Default context limit (conservative estimate)
    local context_limit=8192

    # No cache support for unknown providers
    local cache_read=0
    local cache_creation=0

    # Unknown cost (cannot calculate without knowing provider)
    local cost=0

    # Create unified data structure
    # Even if we got minimal data, we always return valid JSON
    create_unified_data \
        "$prompt_tokens" \
        "$completion_tokens" \
        "$context_limit" \
        "$cache_read" \
        "$cache_creation" \
        "$model_name" \
        "$cost"

    # Debug: log what we found
    if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
        echo "[DEBUG] Generic adapter: tokens=$prompt_tokens/$completion_tokens, model=$model_name" >&2
    fi

    return 0
}

# Export functions
export -f try_extract_tokens
export -f try_extract_model
export -f parse_generic_data
