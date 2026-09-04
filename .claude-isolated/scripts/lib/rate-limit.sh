#!/bin/bash
# Rate Limit Module for Claude Code Statusline
# Fetches and caches Anthropic API rate limit info (unified 5h + 7d windows)
#
# API: POST https://api.anthropic.com/v1/messages (max_tokens:1, "quota")
#   - Costs 1 output token per call (~$0.00002) — minimal but not free
#   - Returns headers:
#     anthropic-ratelimit-unified-5h-utilization  (float 0.0-1.0)
#     anthropic-ratelimit-unified-5h-reset         (unix timestamp, seconds)
#     anthropic-ratelimit-unified-7d-utilization  (float 0.0-1.0)
#     anthropic-ratelimit-unified-7d-reset         (unix timestamp, seconds)
#
# Auth: OAuth Bearer token + anthropic-beta: oauth-2025-04-20
#       Token from $CLAUDE_CODE_OAUTH_TOKEN (long-lived `claude setup-token`,
#       set via .claude_config in iclaude setups) if set, else
#       $CLAUDE_CONFIG_DIR/.credentials.json
# Cache: /tmp/claude-ratelimit-cache.json  (TTL 60 seconds)
# Async: Background curl — never blocks statusline render
#
# Public functions:
#   get_rate_limit_display()              → prints "[RL:45% 2h30m | 7d 12% 3d]" or ""
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
    local utilization cached_at reset_at util_7d reset_7d
    utilization=$(echo "$cache_json" | jq -r '.utilization // empty' 2>/dev/null)
    cached_at=$(echo "$cache_json" | jq -r '.cached_at // 0' 2>/dev/null)
    reset_at=$(echo "$cache_json" | jq -r '.reset_at // 0' 2>/dev/null)
    util_7d=$(echo "$cache_json" | jq -r '.utilization_7d // empty' 2>/dev/null)
    reset_7d=$(echo "$cache_json" | jq -r '.reset_at_7d // 0' 2>/dev/null)

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

    # Optional 7-day (weekly) window — same call, no extra API cost
    local week_str=""
    if [[ -n "$util_7d" ]] && [[ "$util_7d" =~ ^[0-9]+\.?[0-9]*$ ]] && \
       [[ -n "$reset_7d" ]] && [[ "$reset_7d" != "0" ]]; then
        local pct_7d delta_7d days_7d time_7d
        pct_7d=$(awk "BEGIN{printf \"%.0f\", $util_7d * 100}")
        delta_7d=$((reset_7d - now))
        if [[ $delta_7d -le 0 ]]; then
            time_7d="reset"
        else
            days_7d=$((delta_7d / 86400))
            if [[ $days_7d -gt 0 ]]; then
                time_7d="${days_7d}d"
            else
                time_7d="$(( (delta_7d % 86400) / 3600 ))h"
            fi
        fi
        local color_7d
        if [[ $pct_7d -lt 50 ]]; then
            color_7d=$'\033[32m'
        elif [[ $pct_7d -lt 80 ]]; then
            color_7d=$'\033[33m'
        else
            color_7d=$'\033[31m'
        fi
        week_str=$(printf ' %s7d:%d%% %s%s' "$color_7d" "$pct_7d" "$time_7d" "$rl_reset")
    fi

    printf '%s[RL:%d%% %s]%s%s' "$rl_color" "$pct" "$time_str" "$rl_reset" "$week_str"
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
    # iclaude setups commonly authenticate via CLAUDE_CODE_OAUTH_TOKEN (long-lived
    # token from `claude setup-token`, see lib/oauth/token.sh) instead of an
    # interactive login — no .credentials.json file is ever written in that case.
    local env_token="${CLAUDE_CODE_OAUTH_TOKEN:-}"

    # Background fetch — fire and forget
    (
        exec </dev/null >/dev/null 2>/dev/null
        cleanup_rl() {
            rm -f "$lock_file" "/tmp/claude-ratelimit-headers-$$.tmp" 2>/dev/null
        }
        trap cleanup_rl EXIT

        local token="$env_token"
        if [[ -z "$token" ]]; then
            [[ ! -f "$creds_file" ]] && exit 0
            token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        fi
        [[ -z "$token" ]] && exit 0

        # POST /v1/messages with max_tokens:1 — same method Claude Code uses internally
        # Requires anthropic-beta: oauth-2025-04-20 to allow OAuth Bearer token
        # Model must be a currently valid id — an unknown/retired id returns 429
        # rate_limit_error with NO anthropic-ratelimit-unified-* headers at all,
        # silently breaking this fetch. Haiku 4.5 is the cheapest current model.
        local body='{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"quota"}]}'
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

        local utilization reset_at util_7d reset_7d
        utilization=$(grep -i "anthropic-ratelimit-unified-5h-utilization:" "$headers_file" \
                      | awk '{print $2}' | tr -d '\r\n')
        reset_at=$(grep -i "anthropic-ratelimit-unified-5h-reset:" "$headers_file" \
                   | awk '{print $2}' | tr -d '\r\n')
        util_7d=$(grep -i "anthropic-ratelimit-unified-7d-utilization:" "$headers_file" \
                  | awk '{print $2}' | tr -d '\r\n')
        reset_7d=$(grep -i "anthropic-ratelimit-unified-7d-reset:" "$headers_file" \
                   | awk '{print $2}' | tr -d '\r\n')

        [[ -z "$utilization" ]] && exit 0
        [[ -z "$reset_at" ]] && exit 0
        [[ ! "$utilization" =~ ^[0-9]+\.?[0-9]*$ ]] && exit 0
        [[ ! "$reset_at" =~ ^[0-9]+$ ]] && exit 0

        # 7d fields are optional — blank out on any validation failure
        [[ ! "$util_7d" =~ ^[0-9]+\.?[0-9]*$ ]] && util_7d=""
        [[ ! "$reset_7d" =~ ^[0-9]+$ ]] && reset_7d=""

        local now
        now=$(date +%s)
        local tmp_cache="/tmp/claude-ratelimit-cache.json.$$.tmp"
        printf '{"utilization":%s,"reset_at":%s,"cached_at":%s,"utilization_7d":%s,"reset_at_7d":%s}\n' \
            "$utilization" "$reset_at" "$now" \
            "${util_7d:-null}" "${reset_7d:-null}" > "$tmp_cache" && \
            mv "$tmp_cache" "/tmp/claude-ratelimit-cache.json"

        exit 0
    ) &
    disown $! 2>/dev/null

    return 0
}

export -f get_rate_limit_display
export -f trigger_rate_limit_fetch
