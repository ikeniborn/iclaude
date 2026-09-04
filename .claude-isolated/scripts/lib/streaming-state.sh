#!/bin/bash
# Streaming State Management Module
# Manages persistent state for streaming sessions
#
# State files stored in: $CLAUDE_DIR/streaming-state/$SESSION_ID.state
# Format: JSON with token accumulation
# Cleanup: States older than 1 hour automatically removed

# Get state directory (create if not exists)
get_state_dir() {
    local state_dir="${CLAUDE_DIR:-$HOME/.claude-code}/streaming-state"

    if [[ ! -d "$state_dir" ]]; then
        mkdir -p "$state_dir" 2>/dev/null || {
            echo "[ERROR] Failed to create streaming state directory: $state_dir" >&2
            return 1
        }
    fi

    echo "$state_dir"
    return 0
}

# Get state file path for session
# Args: $1 - session_id
# Returns: path to state file
get_state_file() {
    local session_id="$1"

    [[ -z "$session_id" ]] && return 1

    local state_dir
    state_dir=$(get_state_dir) || return 1

    echo "$state_dir/${session_id}.state"
    return 0
}

# Initialize new streaming state
# Args: $1 - session_id
#       $2 - provider (anthropic, openai, ollama, gemini)
#       $3 - model name (optional)
# Returns: 0 on success, 1 on error
init_streaming_state() {
    local session_id="$1"
    local provider="$2"
    local model="${3:-Unknown}"

    # Guard: required params
    [[ -z "$session_id" ]] && return 1
    [[ -z "$provider" ]] && return 1

    local state_file
    state_file=$(get_state_file "$session_id") || return 1

    # Create initial state
    local state_json
    state_json=$(cat <<EOF
{
  "session_id": "$session_id",
  "provider": "$provider",
  "model": "$model",
  "streaming": true,
  "input_tokens": 0,
  "output_tokens": 0,
  "cache_read_tokens": 0,
  "cache_creation_tokens": 0,
  "chunks_received": 0,
  "last_update": $(date +%s),
  "completed": false
}
EOF
)

    # Atomic write: write to temp, then rename
    local temp_file="${state_file}.tmp.$$"

    echo "$state_json" > "$temp_file" || {
        rm -f "$temp_file"
        return 1
    }

    mv "$temp_file" "$state_file" || {
        rm -f "$temp_file"
        return 1
    }

    [[ "${DEBUG_STATUSLINE:-0}" == "1" ]] && \
        echo "[DEBUG] Streaming state initialized: $session_id" >&2

    return 0
}

# Update streaming state with new data
# Args: $1 - session_id
#       $2 - update data (JSON with fields to update)
# Returns: 0 on success, 1 on error
update_streaming_state() {
    local session_id="$1"
    local update_data="$2"

    # Guard: required params
    [[ -z "$session_id" ]] && return 1
    [[ -z "$update_data" ]] && return 1

    local state_file
    state_file=$(get_state_file "$session_id") || return 1

    # Check if state exists
    if [[ ! -f "$state_file" ]]; then
        [[ "${DEBUG_STATUSLINE:-0}" == "1" ]] && \
            echo "[DEBUG] State file not found, cannot update: $session_id" >&2
        return 1
    fi

    # Read current state
    local current_state
    current_state=$(cat "$state_file" 2>/dev/null) || return 1

    # Parse update data
    local input_add=$(echo "$update_data" | jq -r '.input_tokens // 0' 2>/dev/null)
    local output_add=$(echo "$update_data" | jq -r '.output_tokens // 0' 2>/dev/null)
    local cache_read_add=$(echo "$update_data" | jq -r '.cache_read_tokens // 0' 2>/dev/null)
    local cache_creation_add=$(echo "$update_data" | jq -r '.cache_creation_tokens // 0' 2>/dev/null)
    local completed=$(echo "$update_data" | jq -r '.completed // false' 2>/dev/null)

    # Get current values
    local current_input=$(echo "$current_state" | jq -r '.input_tokens // 0')
    local current_output=$(echo "$current_state" | jq -r '.output_tokens // 0')
    local current_cache_read=$(echo "$current_state" | jq -r '.cache_read_tokens // 0')
    local current_cache_creation=$(echo "$current_state" | jq -r '.cache_creation_tokens // 0')
    local current_chunks=$(echo "$current_state" | jq -r '.chunks_received // 0')

    # Accumulate tokens
    local new_input=$((current_input + input_add))
    local new_output=$((current_output + output_add))
    local new_cache_read=$((current_cache_read + cache_read_add))
    local new_cache_creation=$((current_cache_creation + cache_creation_add))
    local new_chunks=$((current_chunks + 1))

    # Update state
    local updated_state
    updated_state=$(echo "$current_state" | jq \
        --arg input "$new_input" \
        --arg output "$new_output" \
        --arg cache_read "$new_cache_read" \
        --arg cache_creation "$new_cache_creation" \
        --arg chunks "$new_chunks" \
        --arg timestamp "$(date +%s)" \
        --argjson completed "$completed" \
        '.input_tokens = ($input | tonumber) |
         .output_tokens = ($output | tonumber) |
         .cache_read_tokens = ($cache_read | tonumber) |
         .cache_creation_tokens = ($cache_creation | tonumber) |
         .chunks_received = ($chunks | tonumber) |
         .last_update = ($timestamp | tonumber) |
         .completed = $completed' 2>/dev/null)

    if [[ -z "$updated_state" ]]; then
        [[ "${DEBUG_STATUSLINE:-0}" == "1" ]] && \
            echo "[DEBUG] Failed to update state JSON" >&2
        return 1
    fi

    # Atomic write
    local temp_file="${state_file}.tmp.$$"

    echo "$updated_state" > "$temp_file" || {
        rm -f "$temp_file"
        return 1
    }

    mv "$temp_file" "$state_file" || {
        rm -f "$temp_file"
        return 1
    }

    [[ "${DEBUG_STATUSLINE:-0}" == "1" ]] && \
        echo "[DEBUG] Streaming state updated: $session_id (chunks: $new_chunks, output: $new_output)" >&2

    return 0
}

# Get current streaming state
# Args: $1 - session_id
# Returns: state JSON (stdout)
get_streaming_state() {
    local session_id="$1"

    [[ -z "$session_id" ]] && return 1

    local state_file
    state_file=$(get_state_file "$session_id") || return 1

    if [[ ! -f "$state_file" ]]; then
        return 1
    fi

    cat "$state_file" 2>/dev/null || return 1
    return 0
}

# Mark streaming state as completed
# Args: $1 - session_id
# Returns: 0 on success, 1 on error
finalize_streaming_state() {
    local session_id="$1"

    [[ -z "$session_id" ]] && return 1

    # Update with completed=true
    update_streaming_state "$session_id" '{"completed": true}' || return 1

    [[ "${DEBUG_STATUSLINE:-0}" == "1" ]] && \
        echo "[DEBUG] Streaming state finalized: $session_id" >&2

    return 0
}

# Check if session has active streaming state
# Args: $1 - session_id
# Returns: 0 if streaming, 1 if not
is_streaming_active() {
    local session_id="$1"

    [[ -z "$session_id" ]] && return 1

    local state
    state=$(get_streaming_state "$session_id") || return 1

    local streaming=$(echo "$state" | jq -r '.streaming // false' 2>/dev/null)
    local completed=$(echo "$state" | jq -r '.completed // false' 2>/dev/null)

    if [[ "$streaming" == "true" ]] && [[ "$completed" != "true" ]]; then
        return 0
    fi

    return 1
}

# Cleanup old streaming states (>1 hour)
# Returns: number of cleaned up states
cleanup_old_states() {
    local state_dir
    state_dir=$(get_state_dir) || return 1

    local current_time=$(date +%s)
    local cleanup_threshold=3600  # 1 hour
    local cleanup_count=0

    # Find and remove old state files
    while IFS= read -r state_file; do
        [[ ! -f "$state_file" ]] && continue

        local state_json
        state_json=$(cat "$state_file" 2>/dev/null) || continue

        local last_update=$(echo "$state_json" | jq -r '.last_update // 0' 2>/dev/null)
        local age=$((current_time - last_update))

        if [[ $age -gt $cleanup_threshold ]]; then
            rm -f "$state_file"
            cleanup_count=$((cleanup_count + 1))

            [[ "${DEBUG_STATUSLINE:-0}" == "1" ]] && \
                echo "[DEBUG] Cleaned up old state: $state_file (age: ${age}s)" >&2
        fi
    done < <(find "$state_dir" -name "*.state" -type f 2>/dev/null)

    echo "$cleanup_count"
    return 0
}

# Delete streaming state (manual cleanup)
# Args: $1 - session_id
# Returns: 0 on success, 1 on error
delete_streaming_state() {
    local session_id="$1"

    [[ -z "$session_id" ]] && return 1

    local state_file
    state_file=$(get_state_file "$session_id") || return 1

    if [[ -f "$state_file" ]]; then
        rm -f "$state_file"
        [[ "${DEBUG_STATUSLINE:-0}" == "1" ]] && \
            echo "[DEBUG] Streaming state deleted: $session_id" >&2
    fi

    return 0
}

# Export functions
export -f get_state_dir
export -f get_state_file
export -f init_streaming_state
export -f update_streaming_state
export -f get_streaming_state
export -f finalize_streaming_state
export -f is_streaming_active
export -f cleanup_old_states
export -f delete_streaming_state
