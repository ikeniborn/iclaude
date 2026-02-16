#!/bin/bash
# Streaming Detection Module
# Detects if data is streaming chunk vs complete response
#
# Supports:
# - Anthropic Claude (SSE format with message_start/delta/stop)
# - OpenAI (streaming delta format)
# - Ollama (done: false/true format)
# - Gemini (streaming format if supported)

# Detect if data is a streaming chunk (vs complete response)
# Args: $1 - data (JSON string)
# Returns: 0 if streaming chunk, 1 if complete response
is_streaming_chunk() {
    local data="$1"

    # Guard: empty or null data
    [[ -z "$data" ]] && return 1
    [[ "$data" == "null" ]] && return 1

    # Check for Anthropic SSE format
    # Signature: has "type" field with streaming event types
    local has_type=$(echo "$data" | jq -r 'has("type")' 2>/dev/null)
    if [[ "$has_type" == "true" ]]; then
        local event_type=$(echo "$data" | jq -r '.type' 2>/dev/null)

        # Anthropic streaming events
        case "$event_type" in
            message_start|content_block_start|content_block_delta|content_block_stop|message_delta|message_stop|ping)
                return 0
                ;;
        esac
    fi

    # Check for OpenAI streaming format
    # Signature: has "choices[].delta" field
    local has_delta=$(echo "$data" | jq -r '.choices[0].delta // empty' 2>/dev/null)
    if [[ -n "$has_delta" ]]; then
        return 0
    fi

    # Check for Ollama streaming format
    # Signature: has "done" field (false = streaming, true = final)
    local has_done=$(echo "$data" | jq -r 'has("done")' 2>/dev/null)
    if [[ "$has_done" == "true" ]]; then
        local done_value=$(echo "$data" | jq -r '.done' 2>/dev/null)
        # done=false means still streaming
        # done=true means final chunk (but still considered streaming format)
        return 0
    fi

    # Check for Gemini streaming format (if supported)
    # Signature: has "candidates[].content.parts" with streaming flag
    local has_candidates=$(echo "$data" | jq -r 'has("candidates")' 2>/dev/null)
    if [[ "$has_candidates" == "true" ]]; then
        # Gemini may include finishReason in streaming chunks
        local has_finish=$(echo "$data" | jq -r '.candidates[0].finishReason // empty' 2>/dev/null)
        # If has finishReason, it's likely a streaming chunk
        if [[ -n "$has_finish" ]]; then
            return 0
        fi
    fi

    # Not a streaming chunk (complete response)
    return 1
}

# Get streaming chunk type
# Args: $1 - chunk data (JSON string)
# Returns: chunk type string (message_start, delta, stop, unknown)
get_chunk_type() {
    local chunk="$1"

    # Guard: empty or null
    [[ -z "$chunk" ]] && echo "unknown" && return 1
    [[ "$chunk" == "null" ]] && echo "unknown" && return 1

    # Anthropic format
    local has_type=$(echo "$chunk" | jq -r 'has("type")' 2>/dev/null)
    if [[ "$has_type" == "true" ]]; then
        local event_type=$(echo "$chunk" | jq -r '.type' 2>/dev/null)

        case "$event_type" in
            message_start)
                echo "start"
                return 0
                ;;
            content_block_delta|message_delta)
                echo "delta"
                return 0
                ;;
            message_stop)
                echo "stop"
                return 0
                ;;
            ping)
                echo "ping"
                return 0
                ;;
            content_block_start|content_block_stop)
                echo "meta"
                return 0
                ;;
        esac
    fi

    # OpenAI format
    local has_delta=$(echo "$chunk" | jq -r '.choices[0].delta // empty' 2>/dev/null)
    if [[ -n "$has_delta" ]]; then
        local finish_reason=$(echo "$chunk" | jq -r '.choices[0].finish_reason // empty' 2>/dev/null)

        if [[ -n "$finish_reason" ]] && [[ "$finish_reason" != "null" ]]; then
            echo "stop"
        else
            echo "delta"
        fi
        return 0
    fi

    # Ollama format
    local has_done=$(echo "$chunk" | jq -r 'has("done")' 2>/dev/null)
    if [[ "$has_done" == "true" ]]; then
        local done_value=$(echo "$chunk" | jq -r '.done' 2>/dev/null)

        if [[ "$done_value" == "true" ]]; then
            echo "stop"
        else
            echo "delta"
        fi
        return 0
    fi

    # Unknown format
    echo "unknown"
    return 1
}

# Check if chunk is the final chunk in stream
# Args: $1 - chunk data (JSON string)
# Returns: 0 if final chunk, 1 if not final
is_final_chunk() {
    local chunk="$1"

    local chunk_type
    chunk_type=$(get_chunk_type "$chunk")

    [[ "$chunk_type" == "stop" ]] && return 0

    return 1
}

# Get provider type from streaming chunk
# Args: $1 - chunk data (JSON string)
# Returns: provider type (anthropic, openai, ollama, gemini, unknown)
get_streaming_provider() {
    local chunk="$1"

    # Guard: empty or null
    [[ -z "$chunk" ]] && echo "unknown" && return 1
    [[ "$chunk" == "null" ]] && echo "unknown" && return 1

    # Anthropic: has .type field with message_* events
    local has_type=$(echo "$chunk" | jq -r 'has("type")' 2>/dev/null)
    if [[ "$has_type" == "true" ]]; then
        local event_type=$(echo "$chunk" | jq -r '.type' 2>/dev/null)
        if [[ "$event_type" =~ ^(message_|content_block_|ping) ]]; then
            echo "anthropic"
            return 0
        fi
    fi

    # OpenAI: has .choices[].delta
    local has_delta=$(echo "$chunk" | jq -r '.choices[0].delta // empty' 2>/dev/null)
    if [[ -n "$has_delta" ]]; then
        echo "openai"
        return 0
    fi

    # Ollama: has .done field + .model field
    local has_done=$(echo "$chunk" | jq -r 'has("done")' 2>/dev/null)
    local has_model=$(echo "$chunk" | jq -r 'has("model")' 2>/dev/null)
    if [[ "$has_done" == "true" ]] && [[ "$has_model" == "true" ]]; then
        local model_name=$(echo "$chunk" | jq -r '.model // empty' 2>/dev/null)
        # Check if Ollama model pattern
        if [[ "$model_name" =~ ^(llama|mistral|qwen|codellama|deepseek-coder|phi|vicuna|orca|gemma|starcoder|solar|yi) ]]; then
            echo "ollama"
            return 0
        fi

        # Generic OpenAI-compatible
        echo "openai"
        return 0
    fi

    # Gemini: has .candidates
    local has_candidates=$(echo "$chunk" | jq -r 'has("candidates")' 2>/dev/null)
    if [[ "$has_candidates" == "true" ]]; then
        echo "gemini"
        return 0
    fi

    # Unknown
    echo "unknown"
    return 1
}

# Export functions
export -f is_streaming_chunk
export -f get_chunk_type
export -f is_final_chunk
export -f get_streaming_provider
