#!/bin/bash
# Rate Limit Module for Claude Code Statusline
# Fetches and caches Anthropic API rate limit info (unified 5h window)
#
# API: POST https://api.anthropic.com/v1/messages (max_tokens:1, "quota")
#   - Costs 1 output token per call (~$0.00002) — minimal but not free
#   - Returns headers:
#     anthropic-ratelimit-unified-5h-utilization  (float 0.0-1.0)
#     anthropic-ratelimit-unified-5h-reset         (unix timestamp, seconds)
#
# Auth: OAuth Bearer token + anthropic-beta: oauth-2025-04-20
#       Token from $CLAUDE_CONFIG_DIR/.credentials.json
# Cache: /tmp/claude-ratelimit-cache.json  (TTL 60 seconds)
# Async: Background curl — never blocks statusline render
#
# Public functions:
#   get_rate_limit_display()              → prints "[RL:45% 2h30m]" or ""
#   trigger_rate_limit_fetch <config_dir> → fires background curl, returns immediately

# Read cached rate limit and return formatted display string.
# Returns empty string on any error or cache miss.
get_rate_limit_display() {
    local cache_file="/tmp/claude-ratelimit-cache.json"
    local max_age=300  # 5 minutes hard expiry for display

    # Fast exit: no cache file
    [[ ! -f "$cache_file" ]] && return 0

    # Read cache
    local cache_json
    cache_json=$(cat "$cache_file" 2>/dev/null) || return 0
    [[ -z "$cache_json" ]] && return 0

    # Parse fields with jq
    local utilization cached_at reset_at
    utilization=$(echo "$cache_json" | jq -r '.utilization // empty' 2>/dev/null)
    cached_at=$(echo "$cache_json" | jq -r '.cached_at // 0' 2>/dev/null)
    reset_at=$(echo "$cache_json" | jq -r '.reset_at // 0' 2>/dev/null)

    # Validate non-empty
    [[ -z "$utilization" ]] && return 0
    [[ -z "$reset_at" || "$reset_at" == "0" ]] && return 0

    # Validate numerics
    [[ ! "$utilization" =~ ^[0-9]+\.?[0-9]*$ ]] && return 0
    [[ ! "$cached_at" =~ ^[0-9]+$ ]] && return 0

    # Check staleness
    local now
    now=$(date +%s)
    local age=$((now - cached_at))
    [[ $age -gt $max_age ]] && return 0

    # Convert utilization to integer percent
    local pct
    pct=$(awk "BEGIN{printf \"%.0f\", $utilization * 100}")

    # Compute time-to-reset
    local delta=$((reset_at - now))
    local time_str
    if [[ $delta -le 0 ]]; then
        time_str="reset"
    else
        local hours=$((delta / 3600))
        local minutes=$(((delta % 3600) / 60))
        if [[ $hours -gt 0 ]]; then
            time_str="${hours}h$(printf '%02d' $minutes)m"
        else
            time_str="${minutes}m"
        fi
    fi

    # Color: green < 50%, yellow 50-79%, red >= 80%
    local rl_color
    if [[ $pct -lt 50 ]]; then
        rl_color=$'\033[32m'
    elif [[ $pct -lt 80 ]]; then
        rl_color=$'\033[33m'
    else
        rl_color=$'\033[31m'
    fi
    local rl_reset=$'\033[0m'

    printf '%s[RL:%d%% %s]%s' "$rl_color" "$pct" "$time_str" "$rl_reset"
    return 0
}

# Fire background curl to refresh rate limit cache.
# Respects TTL — skips if cache is fresh or fetch already in progress.
# Arguments: $1 = CLAUDE_CONFIG_DIR (path to .claude-isolated/)
trigger_rate_limit_fetch() {
    local config_dir="${1:-}"
    local cache_file="/tmp/claude-ratelimit-cache.json"
    local lock_file="/tmp/claude-ratelimit-fetch.lock"
    local ttl=60  # seconds between fetches

    [[ -z "$config_dir" ]] && return 0
    command -v curl &>/dev/null || return 0
    command -v jq &>/dev/null || return 0

    # Check TTL: skip if cache is fresh
    if [[ -f "$cache_file" ]]; then
        local cached_at now age
        cached_at=$(jq -r '.cached_at // 0' "$cache_file" 2>/dev/null || echo 0)
        now=$(date +%s)
        age=$((now - cached_at))
        [[ $age -lt $ttl ]] && return 0
    fi

    # Check lock: skip if another fetch is in progress (< 30s old)
    if [[ -f "$lock_file" ]]; then
        local lock_time lock_age now
        lock_time=$(cat "$lock_file" 2>/dev/null || echo 0)
        now=$(date +%s)
        lock_age=$((now - lock_time))
        [[ $lock_age -lt 30 ]] && return 0
    fi

    # Write lock atomically
    local lock_tmp="${lock_file}.$$"
    date +%s > "$lock_tmp" 2>/dev/null && mv "$lock_tmp" "$lock_file" 2>/dev/null || return 0

    # Capture for subshell
    local creds_file="$config_dir/.credentials.json"

    # Background fetch — fire and forget
    (
        exec </dev/null >/dev/null 2>/dev/null
        cleanup_rl() {
            rm -f "$lock_file" "/tmp/claude-ratelimit-headers-$$.tmp" 2>/dev/null
        }
        trap cleanup_rl EXIT

        [[ ! -f "$creds_file" ]] && exit 0

        local token
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        [[ -z "$token" ]] && exit 0

        # POST /v1/messages with max_tokens:1 — same method Claude Code uses internally
        # Requires anthropic-beta: oauth-2025-04-20 to allow OAuth Bearer token
        local body='{"model":"claude-sonnet-4-6","max_tokens":1,"messages":[{"role":"user","content":"quota"}]}'
        local headers_file="/tmp/claude-ratelimit-headers-$$.tmp"

        curl -s \
            -X POST \
            -H "Authorization: Bearer $token" \
            -H "anthropic-version: 2023-06-01" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "Content-Type: application/json" \
            -H "User-Agent: claude-code/2.1.47" \
            -d "$body" \
            -m 15 \
            -D "$headers_file" \
            -o /dev/null \
            "https://api.anthropic.com/v1/messages" 2>/dev/null || exit 0

        [[ ! -f "$headers_file" ]] && exit 0

        local utilization reset_at
        utilization=$(grep -i "anthropic-ratelimit-unified-5h-utilization:" "$headers_file" \
                      | awk '{print $2}' | tr -d '\r\n')
        reset_at=$(grep -i "anthropic-ratelimit-unified-5h-reset:" "$headers_file" \
                   | awk '{print $2}' | tr -d '\r\n')

        [[ -z "$utilization" ]] && exit 0
        [[ -z "$reset_at" ]] && exit 0
        [[ ! "$utilization" =~ ^[0-9]+\.?[0-9]*$ ]] && exit 0
        [[ ! "$reset_at" =~ ^[0-9]+$ ]] && exit 0

        local now
        now=$(date +%s)
        local tmp_cache="/tmp/claude-ratelimit-cache.json.$$.tmp"
        printf '{"utilization":%s,"reset_at":%s,"cached_at":%s}\n' \
            "$utilization" "$reset_at" "$now" > "$tmp_cache" && \
            mv "$tmp_cache" "/tmp/claude-ratelimit-cache.json"

        exit 0
    ) &
    disown $! 2>/dev/null

    return 0
}

export -f get_rate_limit_display
export -f trigger_rate_limit_fetch
