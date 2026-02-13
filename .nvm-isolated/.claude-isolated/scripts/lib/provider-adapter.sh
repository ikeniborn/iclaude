#!/bin/bash
# Provider Adapter Factory
# Detects LLM provider type and loads appropriate adapter
#
# Architecture: Strategy Pattern with automatic provider detection
# - Detects provider from session JSON structure
# - Loads provider-specific adapter
# - Returns unified data format for statusline
#
# Supported providers:
# - anthropic: Claude API (native)
# - openai: OpenAI/DeepSeek/OpenRouter (OpenAI-compatible)
# - ollama: Local models (zero cost)
# - gemini: Google Gemini API
# - generic: Fallback for unknown providers

# Get script directory for relative paths
ADAPTER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect provider type from session JSON structure
# Args: $1 - session_data (JSON string)
# Returns: "anthropic" | "openai" | "ollama" | "gemini" | "unknown"
detect_provider_type() {
    local session_data="$1"

    # Guard: empty or null data
    [[ -z "$session_data" ]] && echo "unknown" && return 1
    [[ "$session_data" == "null" ]] && echo "unknown" && return 1

    # Check for Anthropic Claude format
    # Signature: .context_window.total_input_tokens
    local has_context_window=$(echo "$session_data" | jq -r 'has("context_window")' 2>/dev/null)
    local has_total_input=$(echo "$session_data" | jq -r '.context_window.total_input_tokens // empty' 2>/dev/null)

    if [[ "$has_context_window" == "true" ]] && [[ -n "$has_total_input" ]]; then
        echo "anthropic"
        return 0
    fi

    # Check for Google Gemini format
    # Signature: .usageMetadata
    local has_usage_metadata=$(echo "$session_data" | jq -r 'has("usageMetadata")' 2>/dev/null)

    if [[ "$has_usage_metadata" == "true" ]]; then
        echo "gemini"
        return 0
    fi

    # Check for OpenAI-compatible format
    # Signature: .usage.prompt_tokens
    local has_usage=$(echo "$session_data" | jq -r 'has("usage")' 2>/dev/null)
    local has_prompt_tokens=$(echo "$session_data" | jq -r '.usage.prompt_tokens // empty' 2>/dev/null)

    if [[ "$has_usage" == "true" ]] && [[ -n "$has_prompt_tokens" ]]; then
        # Distinguish between OpenAI and Ollama by model name
        local model_name=$(echo "$session_data" | jq -r '.model // empty' 2>/dev/null)

        # Ollama models: llama*, mistral*, qwen*, codellama*, etc.
        if [[ "$model_name" =~ ^(llama|mistral|qwen|codellama|deepseek-coder|phi|vicuna|orca) ]]; then
            echo "ollama"
            return 0
        fi

        echo "openai"
        return 0
    fi

    # Unknown provider
    echo "unknown"
    return 1
}

# Get path to provider adapter script
# Args: $1 - provider_type (from detect_provider_type)
# Returns: path to adapter script
get_provider_adapter() {
    local provider_type="$1"
    local adapter_path="$ADAPTER_LIB_DIR/adapters/${provider_type}.sh"

    # Check if adapter exists
    if [[ -f "$adapter_path" ]]; then
        echo "$adapter_path"
        return 0
    fi

    # Fallback to generic adapter
    echo "$ADAPTER_LIB_DIR/adapters/generic.sh"
    return 0
}

# Create unified data structure (JSON)
# All adapters must return data in this format
# Args: named parameters via function call
# Returns: JSON string
create_unified_data() {
    local total_input="${1:-0}"
    local total_output="${2:-0}"
    local context_limit="${3:-200000}"
    local cache_read="${4:-0}"
    local cache_creation="${5:-0}"
    local model_name="${6:-Unknown}"
    local cost="${7:-0}"

    cat <<EOF
{
  "total_input_tokens": $total_input,
  "total_output_tokens": $total_output,
  "context_limit": $context_limit,
  "cache_read_tokens": $cache_read,
  "cache_creation_tokens": $cache_creation,
  "model_name": "$model_name",
  "total_cost_usd": $cost
}
EOF
}

# Parse session data using provider-specific adapter
# Args: $1 - session_data (JSON string)
# Returns: 0 on success, 1 on error
# Side effects: Sets global variables for statusline
parse_with_adapter() {
    local session_data="$1"

    # Detect provider
    local provider_type
    provider_type=$(detect_provider_type "$session_data")

    if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
        echo "[DEBUG] Detected provider: $provider_type" >&2
    fi

    # Get adapter path
    local adapter_path
    adapter_path=$(get_provider_adapter "$provider_type")

    if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
        echo "[DEBUG] Using adapter: $adapter_path" >&2
    fi

    # Check adapter exists
    if [[ ! -f "$adapter_path" ]]; then
        if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
            echo "[DEBUG] Adapter not found: $adapter_path" >&2
        fi
        return 1
    fi

    # Source adapter
    source "$adapter_path"

    # Call adapter-specific parse function
    # Function name format: parse_<provider>_data
    local parse_function="parse_${provider_type}_data"

    if ! declare -f "$parse_function" &>/dev/null; then
        if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
            echo "[DEBUG] Parse function not found: $parse_function" >&2
        fi
        return 1
    fi

    # Execute adapter parse function
    local unified_data
    unified_data=$($parse_function "$session_data")

    if [[ $? -ne 0 ]] || [[ -z "$unified_data" ]]; then
        if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
            echo "[DEBUG] Adapter parse failed" >&2
        fi
        return 1
    fi

    if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
        echo "[DEBUG] Unified data: $unified_data" >&2
    fi

    # Extract values from unified data and set global variables
    # These variables are used by statusline.sh
    TOTAL_INPUT=$(echo "$unified_data" | jq -r '.total_input_tokens // 0')
    TOTAL_OUTPUT=$(echo "$unified_data" | jq -r '.total_output_tokens // 0')
    CONTEXT_LIMIT=$(echo "$unified_data" | jq -r '.context_limit // 200000')
    CACHE_READ=$(echo "$unified_data" | jq -r '.cache_read_tokens // 0')
    CACHE_CREATION=$(echo "$unified_data" | jq -r '.cache_creation_tokens // 0')
    MODEL=$(echo "$unified_data" | jq -r '.model_name // "Unknown"')
    COST=$(printf "%.2f" "$(echo "$unified_data" | jq -r '.total_cost_usd // 0')")

    # Export provider type for icon display
    export PROVIDER_TYPE="$provider_type"

    return 0
}

# Export functions for use in statusline
export -f detect_provider_type
export -f get_provider_adapter
export -f create_unified_data
export -f parse_with_adapter
