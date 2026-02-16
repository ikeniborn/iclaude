#!/bin/bash
# Streaming Chunk Parser Module
# Parses streaming chunks from different providers
#
# Extracts token counts and metadata from SSE/streaming formats
# Returns normalized JSON for state accumulation

# Source dependencies
PARSER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PARSER_DIR/streaming-detector.sh"

# Parse Anthropic streaming chunk
# Args: $1 - chunk data (JSON string)
# Returns: parsed data JSON (input_tokens, output_tokens, cache_*, completed)
parse_anthropic_chunk() {
    local chunk="$1"

    # Guard: empty or null
    [[ -z "$chunk" ]] && return 1
    [[ "$chunk" == "null" ]] && return 1

    local chunk_type
    chunk_type=$(get_chunk_type "$chunk")

    case "$chunk_type" in
        start)
            # message_start: extract input tokens, cache tokens, model
            local input=$(echo "$chunk" | jq -r '.message.usage.input_tokens // 0' 2>/dev/null)
            local cache_read=$(echo "$chunk" | jq -r '.message.usage.cache_read_input_tokens // 0' 2>/dev/null)
            local cache_creation=$(echo "$chunk" | jq -r '.message.usage.cache_creation_input_tokens // 0' 2>/dev/null)
            local model=$(echo "$chunk" | jq -r '.message.model // "unknown"' 2>/dev/null)

            cat <<EOF
{
  "input_tokens": $input,
  "output_tokens": 0,
  "cache_read_tokens": $cache_read,
  "cache_creation_tokens": $cache_creation,
  "model": "$model",
  "completed": false
}
EOF
            ;;

        delta)
            # message_delta: extract output tokens
            local output=$(echo "$chunk" | jq -r '.usage.output_tokens // 0' 2>/dev/null)

            cat <<EOF
{
  "input_tokens": 0,
  "output_tokens": $output,
  "cache_read_tokens": 0,
  "cache_creation_tokens": 0,
  "completed": false
}
EOF
            ;;

        stop)
            # message_stop: mark as completed
            cat <<EOF
{
  "input_tokens": 0,
  "output_tokens": 0,
  "cache_read_tokens": 0,
  "cache_creation_tokens": 0,
  "completed": true
}
EOF
            ;;

        ping|meta)
            # Ignore ping and metadata chunks
            cat <<EOF
{
  "input_tokens": 0,
  "output_tokens": 0,
  "cache_read_tokens": 0,
  "cache_creation_tokens": 0,
  "completed": false
}
EOF
            ;;

        *)
            return 1
            ;;
    esac

    return 0
}

# Parse OpenAI streaming chunk
# Args: $1 - chunk data (JSON string)
# Returns: parsed data JSON
parse_openai_chunk() {
    local chunk="$1"

    # Guard: empty or null
    [[ -z "$chunk" ]] && return 1
    [[ "$chunk" == "null" ]] && return 1

    local chunk_type
    chunk_type=$(get_chunk_type "$chunk")

    # OpenAI doesn't provide token counts in streaming chunks
    # We can only detect completion
    case "$chunk_type" in
        stop)
            # Final chunk with finish_reason
            cat <<EOF
{
  "input_tokens": 0,
  "output_tokens": 0,
  "cache_read_tokens": 0,
  "cache_creation_tokens": 0,
  "completed": true
}
EOF
            ;;

        delta)
            # Delta chunk - just increment chunk counter
            # Actual token counting done at the end
            cat <<EOF
{
  "input_tokens": 0,
  "output_tokens": 0,
  "cache_read_tokens": 0,
  "cache_creation_tokens": 0,
  "completed": false
}
EOF
            ;;

        *)
            return 1
            ;;
    esac

    return 0
}

# Parse Ollama streaming chunk
# Args: $1 - chunk data (JSON string)
# Returns: parsed data JSON
parse_ollama_chunk() {
    local chunk="$1"

    # Guard: empty or null
    [[ -z "$chunk" ]] && return 1
    [[ "$chunk" == "null" ]] && return 1

    local chunk_type
    chunk_type=$(get_chunk_type "$chunk")

    case "$chunk_type" in
        stop)
            # Final chunk with done=true
            # Ollama provides token counts in final chunk
            local prompt_tokens=$(echo "$chunk" | jq -r '.prompt_eval_count // 0' 2>/dev/null)
            local eval_tokens=$(echo "$chunk" | jq -r '.eval_count // 0' 2>/dev/null)

            cat <<EOF
{
  "input_tokens": $prompt_tokens,
  "output_tokens": $eval_tokens,
  "cache_read_tokens": 0,
  "cache_creation_tokens": 0,
  "completed": true
}
EOF
            ;;

        delta)
            # Intermediate chunk - no token info
            cat <<EOF
{
  "input_tokens": 0,
  "output_tokens": 0,
  "cache_read_tokens": 0,
  "cache_creation_tokens": 0,
  "completed": false
}
EOF
            ;;

        *)
            return 1
            ;;
    esac

    return 0
}

# Parse Gemini streaming chunk
# Args: $1 - chunk data (JSON string)
# Returns: parsed data JSON
parse_gemini_chunk() {
    local chunk="$1"

    # Guard: empty or null
    [[ -z "$chunk" ]] && return 1
    [[ "$chunk" == "null" ]] && return 1

    # Gemini streaming may not provide token counts per chunk
    # Check for finishReason to detect completion
    local finish_reason=$(echo "$chunk" | jq -r '.candidates[0].finishReason // empty' 2>/dev/null)

    if [[ -n "$finish_reason" ]] && [[ "$finish_reason" != "null" ]]; then
        # Final chunk
        cat <<EOF
{
  "input_tokens": 0,
  "output_tokens": 0,
  "cache_read_tokens": 0,
  "cache_creation_tokens": 0,
  "completed": true
}
EOF
    else
        # Intermediate chunk
        cat <<EOF
{
  "input_tokens": 0,
  "output_tokens": 0,
  "cache_read_tokens": 0,
  "cache_creation_tokens": 0,
  "completed": false
}
EOF
    fi

    return 0
}

# Parse generic streaming chunk (best-effort)
# Args: $1 - chunk data (JSON string)
# Returns: parsed data JSON
parse_generic_chunk() {
    local chunk="$1"

    # Guard: empty or null
    [[ -z "$chunk" ]] && return 1
    [[ "$chunk" == "null" ]] && return 1

    # Try to extract any token-like fields
    local input=$(echo "$chunk" | jq -r '.input_tokens // .prompt_tokens // .usage.input_tokens // 0' 2>/dev/null)
    local output=$(echo "$chunk" | jq -r '.output_tokens // .completion_tokens // .usage.output_tokens // 0' 2>/dev/null)

    # Check for completion indicators
    local completed=false
    local done=$(echo "$chunk" | jq -r '.done // .completed // .finished // empty' 2>/dev/null)
    local finish_reason=$(echo "$chunk" | jq -r '.finish_reason // .finishReason // empty' 2>/dev/null)

    if [[ "$done" == "true" ]] || [[ -n "$finish_reason" ]]; then
        completed=true
    fi

    cat <<EOF
{
  "input_tokens": $input,
  "output_tokens": $output,
  "cache_read_tokens": 0,
  "cache_creation_tokens": 0,
  "completed": $completed
}
EOF

    return 0
}

# Parse streaming chunk (auto-detect provider)
# Args: $1 - chunk data (JSON string)
# Returns: parsed data JSON
parse_streaming_chunk() {
    local chunk="$1"

    # Guard: empty or null
    [[ -z "$chunk" ]] && return 1
    [[ "$chunk" == "null" ]] && return 1

    # Detect provider
    local provider
    provider=$(get_streaming_provider "$chunk")

    case "$provider" in
        anthropic)
            parse_anthropic_chunk "$chunk"
            ;;
        openai)
            parse_openai_chunk "$chunk"
            ;;
        ollama)
            parse_ollama_chunk "$chunk"
            ;;
        gemini)
            parse_gemini_chunk "$chunk"
            ;;
        *)
            # Fallback to generic parser
            parse_generic_chunk "$chunk"
            ;;
    esac

    return $?
}

# Export functions
export -f parse_anthropic_chunk
export -f parse_openai_chunk
export -f parse_ollama_chunk
export -f parse_gemini_chunk
export -f parse_generic_chunk
export -f parse_streaming_chunk
