#!/bin/bash
# Ollama Local Models Adapter
# Parses Ollama API format (OpenAI-compatible, but local)
#
# API Format: OpenAI-compatible Chat Completions
# - Uses .usage.prompt_tokens
# - Uses .usage.completion_tokens
# - Uses .model (local model name)
# - NO cache support (cache_* = 0)
# - Cost = 0 (local models are free)
#
# Popular Ollama models:
# - llama3, llama2, llama3.1, llama3.3
# - mistral, mixtral
# - qwen2.5, qwen2.5-coder
# - codellama, deepseek-coder
# - phi, vicuna, orca

# Source helper functions
ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ADAPTER_DIR/../provider-adapter.sh"

# Get context limit for Ollama models
# Args: $1 - model name
# Returns: context limit in tokens
get_ollama_context_limit() {
    local model="$1"

    # Convert to lowercase for comparison
    model=$(echo "$model" | tr '[:upper:]' '[:lower:]')

    case "$model" in
        # Llama 3.x models
        llama3*) echo "8192" ;;
        llama2*) echo "4096" ;;

        # Mistral models
        mistral*) echo "8192" ;;
        mixtral*) echo "32768" ;;

        # Qwen models
        qwen2.5*) echo "32768" ;;
        qwen*) echo "8192" ;;

        # Code models
        codellama*) echo "16384" ;;
        deepseek-coder*) echo "16384" ;;

        # Other models
        phi*) echo "2048" ;;
        vicuna*) echo "2048" ;;
        orca*) echo "4096" ;;

        # Default
        *) echo "4096" ;;
    esac
}

# Get friendly display name for Ollama models
# Args: $1 - model name
# Returns: display name
get_ollama_display_name() {
    local model="$1"

    # Remove version tags and sizes
    # Example: "llama3.1:70b-instruct-q4_K_M" -> "Llama 3.1"
    local base_name=$(echo "$model" | sed -E 's/:[^ ]*$//' | sed -E 's/[-_][0-9]+b.*//')

    # Capitalize first letter of each word
    base_name=$(echo "$base_name" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

    # Add "Local" prefix for clarity
    echo "$base_name (local)"
}

# Parse Ollama API session data
# Args: $1 - session_data (JSON string)
# Returns: unified JSON format
parse_ollama_data() {
    local session_data="$1"

    # Guard: empty data
    if [[ -z "$session_data" ]] || [[ "$session_data" == "null" ]]; then
        return 1
    fi

    # Parse token counts (same as OpenAI format)
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
    model_name=$(echo "$session_data" | jq -r '.model // "ollama"' 2>/dev/null)

    # Get display name
    local display_name
    display_name=$(get_ollama_display_name "$model_name")

    # Get context limit
    local context_limit
    context_limit=$(get_ollama_context_limit "$model_name")

    # Ollama does NOT support prompt cache
    local cache_read=0
    local cache_creation=0

    # Local models are FREE
    local cost=0

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
export -f get_ollama_context_limit
export -f get_ollama_display_name
export -f parse_ollama_data
