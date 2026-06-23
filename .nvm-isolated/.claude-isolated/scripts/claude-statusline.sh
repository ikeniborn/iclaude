#!/bin/bash
# Claude Code Status Line Script
# Displays dual context tracking (cumulative + active), model, cost, cache, proxy/router status, and git info
#
# Requirements: Claude Code v2.1+ (uses context_window object)
#
# Debug mode: export DEBUG_STATUSLINE=1 to enable verbose logging
#   - Logs session data JSON to /tmp/claude-statusline-debug.log
#   - Shows detected field names and parsed values
#
# Enable debug mode: DEBUG_STATUSLINE=1
# TEMPORARILY DISABLED for testing - set -x causes formatting artifacts
# [[ "${DEBUG_STATUSLINE:-0}" == "1" ]] && set -x

# Detect config directory (isolated vs system)
# When Claude Code calls this script, $CLAUDE_CONFIG_DIR is not set
# So we detect it based on script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../router.json" ]] || [[ -f "$SCRIPT_DIR/../settings.json" ]]; then
    # Running in isolated environment: scripts/ -> .claude-isolated/
    CLAUDE_CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    # Fallback to system config
    CLAUDE_CONFIG_DIR="${HOME}/.claude"
fi

# Read session data from STDIN
SESSION_DATA=$(cat)

# Debug: Log session data to file for diagnostics
LOG_FILE="/tmp/claude-statusline-debug.log"
if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
    {
        echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo "Session data received:"
        echo "$SESSION_DATA"
        echo "---"
    } >> "$LOG_FILE"
fi

# Debug: Log session data if debug mode enabled
if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
    echo "DEBUG: Session data received (logged to $LOG_FILE):" >&2
    echo "$SESSION_DATA" >&2
fi

# Check for jq availability
if ! command -v jq &>/dev/null; then
    echo "[Status line requires jq - install: sudo apt install jq]"
    exit 0  # Don't break Claude Code UI
fi

# ONE-SHOT SESSION_DATA parse — все поля за один вызов jq (вместо 14+ отдельных вызовов)
# SESSION_ID, SESSION_FILE, PROJECT_DIR доступны сразу для обоих путей (adapter + legacy)
_SD_PARSED=$(echo "$SESSION_DATA" | jq -r '
  (has("context_window") | tostring),
  (.context_window.total_input_tokens // 0 | tostring),
  (.context_window.total_output_tokens // 0 | tostring),
  (.model.display_name // .model.id // "Sonnet 4.5"),
  (.context_window.context_window_size // 200000 | tostring),
  (.context_window.current_usage.cache_read_input_tokens // 0 | tostring),
  (.context_window.current_usage.cache_creation_input_tokens // 0 | tostring),
  (.cost.total_cost_usd // 0 | tostring),
  (.context_window.used_percentage // 0 | tostring),
  (.session_id // "unknown"),
  (.transcript_path // ""),
  (.workspace.project_dir // .cwd // "")
' 2>/dev/null)
{
    read -r _SD_IS_ANTHROPIC
    read -r _SD_TOTAL_INPUT
    read -r _SD_TOTAL_OUTPUT
    read -r _SD_MODEL
    read -r _SD_CONTEXT_LIMIT
    read -r _SD_CACHE_READ
    read -r _SD_CACHE_CREATION
    read -r _SD_COST_RAW
    read -r _SD_USED_PCT
    read -r SESSION_ID
    read -r SESSION_FILE
    read -r PROJECT_DIR
} <<< "$_SD_PARSED"

# --- Statusline caching (Variant D) ---
# Возвращает кэшированный вывод мгновенно (<1ms), обновляет в фоне каждые 3с.
# ICLAUDE_SL_NO_CACHE=1 предотвращает рекурсию в фоновом обновителе.
_SL_CACHE_FILE="/tmp/iclaude-sl-cache-${SESSION_ID:-unknown}"
_SL_WRITE_CACHE=0
if [[ "${ICLAUDE_SL_NO_CACHE:-0}" == "0" ]] && [[ "${SESSION_ID:-unknown}" != "unknown" ]]; then
    _SL_TTL=3
    _SL_LOCK="/tmp/iclaude-sl-lock-${SESSION_ID}"
    if [[ -f "$_SL_CACHE_FILE" ]]; then
        _SL_CACHED_AT=$(stat -c %Y "$_SL_CACHE_FILE" 2>/dev/null || echo 0)
        _SL_NOW=$(date +%s)
        _SL_AGE=$(( _SL_NOW - _SL_CACHED_AT ))
        if [[ $_SL_AGE -lt $_SL_TTL ]]; then
            # Кэш свежий — выдаём сразу, запускаем фоновое обновление (если нет лока)
            cat "$_SL_CACHE_FILE"
            _SL_LOCK_AGE=999
            if [[ -f "$_SL_LOCK" ]]; then
                _SL_LOCK_AT=$(stat -c %Y "$_SL_LOCK" 2>/dev/null || echo 0)
                _SL_LOCK_AGE=$(( _SL_NOW - _SL_LOCK_AT ))
            fi
            if [[ $_SL_LOCK_AGE -gt 5 ]]; then
                (
                    exec </dev/null >/dev/null 2>/dev/null
                    touch "$_SL_LOCK"
                    ICLAUDE_SL_NO_CACHE=1 timeout 2 bash "$0" <<< "$SESSION_DATA" \
                        > "${_SL_CACHE_FILE}.tmp" 2>/dev/null \
                        && mv "${_SL_CACHE_FILE}.tmp" "$_SL_CACHE_FILE" 2>/dev/null
                    rm -f "$_SL_LOCK" 2>/dev/null
                ) &
                disown $! 2>/dev/null
            fi
            exit 0
        fi
    fi
    _SL_WRITE_CACHE=1
fi

# Source provider adapter system (if available)
PROVIDER_ADAPTER_AVAILABLE=0
if [[ -f "$SCRIPT_DIR/lib/provider-adapter.sh" ]]; then
    source "$SCRIPT_DIR/lib/provider-adapter.sh"
    PROVIDER_ADAPTER_AVAILABLE=1
fi

# Source rate limit module (if available)
RATE_LIMIT_AVAILABLE=0
if [[ -f "$SCRIPT_DIR/lib/rate-limit.sh" ]]; then
    source "$SCRIPT_DIR/lib/rate-limit.sh"
    RATE_LIMIT_AVAILABLE=1
fi

# Detect the REAL context window by model name.
# Claude Code reports context_window_size=200000 even for 1M-window models
# (Opus/Sonnet 4.x), so the reported value can't be trusted. Map by model and
# take max(known, reported) — falling back to the reported size for unknowns.
detect_real_context_window() {
    local model="$1" reported="${2:-200000}" known=0
    case "${model,,}" in
        *haiku*) known=200000 ;;                                  # Haiku 4.5 = 200K
        *opus*|*sonnet*)
            case "${model,,}" in
                *4-8*|*4.8*|*4-7*|*4.7*|*4-6*|*4.6*|*4-5*|*4.5*) known=1000000 ;;  # 1M
                *) known=0 ;;                                     # 4.0/4.1 → reported
            esac ;;
    esac
    [[ "$reported" =~ ^[0-9]+$ ]] || reported=200000
    (( known > reported )) && echo "$known" || echo "$reported"
}

# Parse session data
# Anthropic fast path: если one-shot parse дал валидные данные — пропускаем весь адаптер.
# Адаптер нужен только для не-Anthropic провайдеров (Gemini, OpenAI, Ollama via router).
if [[ "$_SD_IS_ANTHROPIC" == "true" ]]; then
    # Anthropic fast path — используем pre-parsed значения, пропускаем адаптер
    TOTAL_INPUT="$_SD_TOTAL_INPUT"
    TOTAL_OUTPUT="$_SD_TOTAL_OUTPUT"
    TOTAL_TOKENS=$((TOTAL_INPUT + TOTAL_OUTPUT))
    MODEL="$_SD_MODEL"
    CONTEXT_LIMIT="$_SD_CONTEXT_LIMIT"
    CACHE_READ="$_SD_CACHE_READ"
    CACHE_CREATION="$_SD_CACHE_CREATION"
    COST=$(printf "%.2f" "$_SD_COST_RAW")
    PROVIDER_TYPE="anthropic"
elif [[ "$PROVIDER_ADAPTER_AVAILABLE" == "1" ]]; then
    # Non-Anthropic provider (Gemini, OpenAI, Ollama via router) — используем адаптер
    if ! parse_with_adapter "$SESSION_DATA"; then
        echo "[Status line: awaiting session data...]"
        exit 0
    fi
    TOTAL_TOKENS=$((TOTAL_INPUT + TOTAL_OUTPUT))
else
    echo "[Status line: awaiting session data...]"
    exit 0
fi

# Override the reported context window with the real per-model window.
# Covers both branches above (MODEL + CONTEXT_LIMIT are set in each).
CONTEXT_LIMIT=$(detect_real_context_window "$MODEL" "$CONTEXT_LIMIT")

# Calculate API tokens percentage (billing only, excludes cache reads)
# Note: This is different from used_percentage which includes cache tokens
PERCENT=$(awk "BEGIN {printf \"%.0f\", ($TOTAL_TOKENS * 100.0 / $CONTEXT_LIMIT)}")

# Active context = real input tokens of the current request (cache + conversation).
# total_input_tokens is the actual window content; used_percentage is NOT used —
# Claude Code saturates it at 100 against its stale 200K window.
USED_PERCENTAGE="$_SD_USED_PCT"  # parsed but no longer the source of truth

ACTIVE_TOKENS="$TOTAL_INPUT"
[[ "$ACTIVE_TOKENS" =~ ^[0-9]+$ ]] || ACTIVE_TOKENS=0
ACTIVE_PERCENT=$(awk "BEGIN {printf \"%.1f\", ($ACTIVE_TOKENS * 100.0 / $CONTEXT_LIMIT)}")

# SESSION_ID, SESSION_FILE, PROJECT_DIR — уже установлены one-shot parse выше
# CACHE_READ, CACHE_CREATION — уже установлены one-shot parse (legacy) или адаптером
TOTAL_CACHE=$((CACHE_READ + CACHE_CREATION))

# Format cache display (show only if >0)
CACHE_DISPLAY=""
if [[ $TOTAL_CACHE -gt 0 ]]; then
    # Format: K for thousands, M for millions
    if [[ $TOTAL_CACHE -ge 1000000 ]]; then
        CACHE_FMT=$(awk "BEGIN {printf \"%.1fM\", ($TOTAL_CACHE / 1000000.0)}")
    elif [[ $TOTAL_CACHE -ge 1000 ]]; then
        CACHE_FMT=$(awk "BEGIN {printf \"%.0fK\", ($TOTAL_CACHE / 1000.0)}")
    else
        CACHE_FMT="$TOTAL_CACHE"
    fi
    CACHE_DISPLAY=" | 📦 ${CACHE_FMT}"
    # Clean cache display immediately
    CACHE_DISPLAY=$(printf '%s' "$CACHE_DISPLAY" | tr -d '\n\r')
fi

# COST — уже установлен one-shot parse (legacy) или адаптером

# Proxy detection (environment variables + fallback)
# Note: HTTPS_PROXY/HTTP_PROXY may not be set when Claude Code calls this script
# Try multiple fallback locations for proxy credentials
PROXY_ICON=""
if [[ -n "$HTTPS_PROXY" ]] || [[ -n "$HTTP_PROXY" ]]; then
    PROXY_ICON=" 🌐"
else
    # Try multiple fallback locations (new .claude_config + legacy .claude_proxy_credentials)
    PROXY_CREDS_LOCATIONS=(
        "$CLAUDE_CONFIG_DIR/../../.claude_config"              # Isolated (new name)
        "$CLAUDE_CONFIG_DIR/../../.claude_proxy_credentials"   # Isolated (legacy)
        "$HOME/.claude_config"                                 # Home directory (new name)
        "$HOME/.claude_proxy_credentials"                      # Home directory (legacy)
        "$(pwd)/.claude_config"                                # Current directory (new name)
        "$(pwd)/.claude_proxy_credentials"                     # Current directory (legacy)
    )

    for creds_file in "${PROXY_CREDS_LOCATIONS[@]}"; do
        if [[ -f "$creds_file" ]] && [[ -r "$creds_file" ]]; then
            # Check if file contains PROXY_URL
            if grep -q "^PROXY_URL=" "$creds_file" 2>/dev/null; then
                PROXY_ICON=" 🌐"
                break
            fi
        fi
    done
fi

# Router detection — query CCR API for actual routed model info
# ICLAUDE_ROUTER_ACTIVE=1 is set by iclaude.sh when launched with --router flag
_CCR_DEFAULT_MODEL=""
ROUTER_ICON=""
if [[ "${ICLAUDE_ROUTER_ACTIVE:-0}" == "1" ]]; then
    # Determine CCR API port (default 3456, or from router.json PORT field)
    _CCR_PORT=3456
    if [[ -f "$CLAUDE_CONFIG_DIR/router.json" ]]; then
        _p=$(jq -r '.PORT // empty' "$CLAUDE_CONFIG_DIR/router.json" 2>/dev/null || true)
        [[ "$_p" =~ ^[0-9]+$ ]] && _CCR_PORT="$_p"
    fi

    # Query CCR /api/config with 30s TTL cache (same pattern as PII metrics)
    _CCR_API_CACHE="/tmp/iclaude-ccr-api-${SESSION_ID:-default}"
    _CCR_NOW_TS=$(date +%s)
    _CCR_API_VALID=0
    if [[ -f "$_CCR_API_CACHE" ]]; then
        _CCR_AGE=$(( _CCR_NOW_TS - $(stat -c %Y "$_CCR_API_CACHE" 2>/dev/null || echo 0) ))
        [[ $_CCR_AGE -lt 30 ]] && _CCR_API_VALID=1
    fi
    if [[ "$_CCR_API_VALID" == "1" ]]; then
        _CCR_CONFIG=$(cat "$_CCR_API_CACHE" 2>/dev/null)
    else
        _CCR_CONFIG=$(curl -s --max-time 0.3 "http://127.0.0.1:${_CCR_PORT}/api/config" 2>/dev/null)
        [[ -n "$_CCR_CONFIG" ]] && printf '%s' "$_CCR_CONFIG" > "$_CCR_API_CACHE"
    fi
    if [[ -n "${_CCR_CONFIG:-}" ]]; then
        _CCR_DEFAULT_MODEL=$(printf '%s' "$_CCR_CONFIG" | \
            jq -r '.Router.default // empty' 2>/dev/null || true)
    fi

    if [[ -n "$_CCR_DEFAULT_MODEL" ]]; then
        # CCR running — model display overridden in format section below
        ROUTER_ICON=" | 🔀"
    elif [[ -f "$CLAUDE_CONFIG_DIR/router.json" ]]; then
        # CCR not running — fallback: read router.json directly
        _fallback=$(jq -r '.Router.default // .routing.default // ""' \
            "$CLAUDE_CONFIG_DIR/router.json" 2>/dev/null || true)
        [[ -n "$_fallback" ]] && ROUTER_ICON=" | 🔀 ${_fallback}" || ROUTER_ICON=" | 🔀"
    else
        ROUTER_ICON=" | 🔀"
    fi
fi

# Security hook event indicator — 🔒 (block) или ⚠️ (redact), показывается FLAG_TTL секунд
SECURITY_ICON=""
_SEC_FLAG="/tmp/iclaude-security-event.json"
if [[ -f "$_SEC_FLAG" ]]; then
    { read -r _SEC_TS; read -r _SEC_TTL; read -r _SEC_TYPE; } < <(
        jq -r '(.ts | floor | tostring), (.ttl | tostring), .type' "$_SEC_FLAG" 2>/dev/null
    )
    _SEC_TS=${_SEC_TS:-0}; _SEC_TTL=${_SEC_TTL:-30}; _SEC_TYPE=${_SEC_TYPE:-}
    _SEC_NOW=$(date +%s 2>/dev/null || echo 0)
    _SEC_AGE=$(( _SEC_NOW - _SEC_TS ))
    if [[ $_SEC_AGE -lt ${_SEC_TTL:-30} ]]; then
        if [[ "$_SEC_TYPE" == "block" ]]; then
            SECURITY_ICON=" | 🔒"
        else
            SECURITY_ICON=" | ⚠️"
        fi
    else
        rm -f "$_SEC_FLAG" 2>/dev/null
    fi
fi

# Caveman badge — show ⛏ when .caveman-active exists in $CLAUDE_CONFIG_DIR.
# Prefer THIS session's suffix (⛏ <session> · Σ<cumulative>), written by
# caveman-stats.js as .caveman-statusline-suffix-<session_id>; fall back to the
# global cumulative-only .caveman-statusline-suffix (e.g. before the first Stop).
CAVEMAN_ICON=""
if [[ -f "$CLAUDE_CONFIG_DIR/.caveman-active" ]]; then
    _CAVEMAN_SUFFIX=""
    if [[ -n "$SESSION_ID" && "$SESSION_ID" != "unknown" ]]; then
        _CAVEMAN_PS_FILE="$CLAUDE_CONFIG_DIR/.caveman-statusline-suffix-${SESSION_ID}"
        [[ -f "$_CAVEMAN_PS_FILE" ]] && _CAVEMAN_SUFFIX=$(cat "$_CAVEMAN_PS_FILE" 2>/dev/null | tr -d '\n\r')
    fi
    if [[ -z "$_CAVEMAN_SUFFIX" ]]; then
        _CAVEMAN_GLOBAL_FILE="$CLAUDE_CONFIG_DIR/.caveman-statusline-suffix"
        [[ -f "$_CAVEMAN_GLOBAL_FILE" ]] && _CAVEMAN_SUFFIX=$(cat "$_CAVEMAN_GLOBAL_FILE" 2>/dev/null | tr -d '\n\r')
    fi
    [[ -n "$_CAVEMAN_SUFFIX" ]] && CAVEMAN_ICON=" | ${_CAVEMAN_SUFFIX}" || CAVEMAN_ICON=" | ⛏"
fi

# PII proxy detection — show when ICLAUDE_PII_ACTIVE=1 (set by launch.sh after proxy starts)
# Fetches live masking count from /api/metrics with 30s TTL cache
PII_ICON=""
if [[ "${ICLAUDE_PII_ACTIVE:-0}" == "1" ]] && [[ -n "${ICLAUDE_PII_ACTIVE_PORT:-}" ]]; then
    _PII_CACHE_FILE="/tmp/pii-metrics-${SESSION_ID:-default}"
    _PII_NOW=$(date +%s 2>/dev/null || echo 0)
    _PII_CACHE_VALID=0
    if [[ -f "$_PII_CACHE_FILE" ]]; then
        _PII_CACHE_AGE=$(( _PII_NOW - $(stat -c %Y "$_PII_CACHE_FILE" 2>/dev/null || echo 0) ))
        [[ $_PII_CACHE_AGE -lt 30 ]] && _PII_CACHE_VALID=1
    fi
    if [[ "$_PII_CACHE_VALID" == "1" ]]; then
        _PII_METRICS=$(cat "$_PII_CACHE_FILE" 2>/dev/null)
    else
        _PII_METRICS=$(curl -s --max-time 0.2 \
            "http://127.0.0.1:${ICLAUDE_PII_ACTIVE_PORT}/api/metrics" 2>/dev/null)
        [[ -n "$_PII_METRICS" ]] && printf '%s' "$_PII_METRICS" > "$_PII_CACHE_FILE"
    fi
    if [[ -n "$_PII_METRICS" ]]; then
        _PII_COUNT=$(printf '%s' "$_PII_METRICS" | \
            python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('masked_items_total',0))" 2>/dev/null)
        if [[ -n "$_PII_COUNT" ]] && [[ "$_PII_COUNT" =~ ^[0-9]+$ ]]; then
            PII_ICON=" | 🛡 ${_PII_COUNT}"
        else
            PII_ICON=" | 🛡"
        fi
    else
        PII_ICON=" | 🛡"
    fi
    # Wrap PII icon in OSC 8 hyperlink to PII audit log when the file exists
    if [[ -n "${ICLAUDE_PII_LOG_PATH:-}" ]] && [[ -f "${ICLAUDE_PII_LOG_PATH}" ]]; then
        OSC8_ESC=$'\033'
        _PII_LABEL="${PII_ICON# | }"
        PII_ICON=" | ${OSC8_ESC}]8;;file://${ICLAUDE_PII_LOG_PATH}${OSC8_ESC}\\${_PII_LABEL}${OSC8_ESC}]8;;${OSC8_ESC}\\"
    fi
fi

# microVM sandbox detection — show ⚡ when running inside Firecracker microVM
# ICLAUDE_MICROVM_ACTIVE=1 exported by configure_guest_environment() in microvm.sh
# MICRO_VM_WORKSPACE_MODE: full (bidirectional sync) | isolated (sealed, no sync-back)
# ICLAUDE_MICROVM_INFO_PATH: host-side txt file with launch params (OSC 8 hover tooltip)
MICROVM_ICON=""
if [[ "${ICLAUDE_MICROVM_ACTIVE:-0}" == "1" ]]; then
    case "${MICRO_VM_WORKSPACE_MODE:-full}" in
        isolated) _vm_label="⚡🔐" ;;   # workspace sealed — no sync-back to host
        *)        _vm_label="⚡"    ;;   # full bidirectional sync (default)
    esac
    # Wrap in OSC 8 hyperlink → hover shows path, click opens vm-info.txt.
    # NOTE: no [[ -f ]] check — vm-info.txt lives on the HOST, not accessible
    # from inside the guest VM where this script runs. The file is guaranteed
    # to exist (created in start_microvm() before configure_guest_environment).
    if [[ -n "${ICLAUDE_MICROVM_INFO_PATH:-}" ]]; then
        _VM_ESC=$'\033'
        MICROVM_ICON=" | ${_VM_ESC}]8;;file://${ICLAUDE_MICROVM_INFO_PATH}${_VM_ESC}\\${_vm_label}${_VM_ESC}]8;;${_VM_ESC}\\"
    else
        MICROVM_ICON=" | ${_vm_label}"
    fi
fi

# Rate limit display (Anthropic-only, no router)
# Fetches async via background curl, reads from 60s TTL cache
# ICLAUDE_ROUTER_ACTIVE=1 is exported by iclaude.sh when --router is used
RL_DISPLAY=""
if [[ "$RATE_LIMIT_AVAILABLE" == "1" ]] && \
   [[ "${PROVIDER_TYPE:-}" == "anthropic" ]] && \
   [[ "${ICLAUDE_ROUTER_ACTIVE:-0}" != "1" ]]; then
    trigger_rate_limit_fetch "$CLAUDE_CONFIG_DIR"
    RL_RAW=$(get_rate_limit_display)
    if [[ -n "$RL_RAW" ]]; then
        RL_DISPLAY=" | ${RL_RAW}"
    fi
fi

# Provider icon display (when using adapter system)
PROVIDER_ICON=""
if [[ "$PROVIDER_ADAPTER_AVAILABLE" == "1" ]] && [[ -n "${PROVIDER_TYPE:-}" ]]; then
    case "$PROVIDER_TYPE" in
        anthropic)
            # No icon for native Claude (default)
            ;;
        openai)
            PROVIDER_ICON=" 🤖"
            ;;
        ollama)
            PROVIDER_ICON=" 🦙"
            ;;
        gemini)
            PROVIDER_ICON=" ✨"
            ;;
        unknown|generic)
            PROVIDER_ICON=" ❓"
            ;;
    esac
fi

# Streaming indicator (when active streaming detected)
STREAMING_ICON=""
if [[ "${STREAMING_ACTIVE:-0}" == "1" ]]; then
    STREAMING_ICON=" 🔄"
fi

# Session context link (OSC 8 hyperlink to session JSONL file)
SESSION_LINK=""

if [[ -n "$SESSION_FILE" ]] && [[ -f "$SESSION_FILE" ]]; then
    OSC8_ESC=$'\033'
    SESSION_LINK=" | ${OSC8_ESC}]8;;file://${SESSION_FILE}${OSC8_ESC}\\📄${OSC8_ESC}]8;;${OSC8_ESC}\\"
fi

# Memory link (OSC 8 hyperlink to project MEMORY.md)
# Project key extracted from SESSION_FILE path (Claude Code's own encoding — handles dots, Cyrillic, etc.)
# SESSION_FILE = $CLAUDE_CONFIG_DIR/projects/{project-key}/{session-id}.jsonl
MEMORY_LINK=""

if [[ -n "$SESSION_FILE" ]]; then
    MEMORY_KEY=$(basename "$(dirname "$SESSION_FILE")")
    MEMORY_PATH="${CLAUDE_CONFIG_DIR}/projects/${MEMORY_KEY}/memory/MEMORY.md"
    if [[ -f "$MEMORY_PATH" ]]; then
        OSC8_ESC=$'\033'
        MEMORY_LINK=" | ${OSC8_ESC}]8;;file://${MEMORY_PATH}${OSC8_ESC}\\🧠${OSC8_ESC}]8;;${OSC8_ESC}\\"
    fi
fi

# Git info (branch + uncommitted changes)
GIT_INFO=""
GIT_TIMEOUT=2  # 2 second timeout

if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    # Call Oh My Posh for git rendering (if available)
    theme_config="$CLAUDE_CONFIG_DIR/themes/claude-statusline.omp.json"
    if command -v oh-my-posh &>/dev/null && [[ -f "$theme_config" ]]; then
        # Validate theme file is valid JSON
        if jq empty "$theme_config" 2>/dev/null; then
            # Use timeout if available
            if command -v timeout &>/dev/null; then
                GIT_INFO=$(timeout $GIT_TIMEOUT oh-my-posh print primary --config "$theme_config" 2>/dev/null || true)
            else
                GIT_INFO=$(oh-my-posh print primary --config "$theme_config" 2>/dev/null || true)
            fi
            # Remove ANSI color codes for consistent output
            GIT_INFO=$(echo "$GIT_INFO" | sed 's/\x1b\[[0-9;]*m//g')
        fi
    fi

    # Build OSC 8 hyperlink to branch on remote (GitHub/GitLab)
    GIT_ESC=$'\033'
    GIT_REMOTE_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's|^git@\([^:]*\):\(.*\)|https://\1/\2|')

    # Fallback to bash git parsing if Oh My Posh unavailable or failed
    if [[ -z "$GIT_INFO" ]]; then
        if command -v timeout &>/dev/null; then
            BRANCH=$(timeout $GIT_TIMEOUT git symbolic-ref --short HEAD 2>/dev/null || timeout $GIT_TIMEOUT git rev-parse --short HEAD 2>/dev/null || echo "unknown")
            CHANGES=$(timeout $GIT_TIMEOUT git status --porcelain 2>/dev/null | wc -l || echo "?")
            # Get commits ahead of upstream
            AHEAD=$(timeout $GIT_TIMEOUT git rev-list --count @{upstream}..HEAD 2>/dev/null || echo "0")
        else
            BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "unknown")
            CHANGES=$(git status --porcelain 2>/dev/null | wc -l || echo "?")
            # Get commits ahead of upstream
            AHEAD=$(git rev-list --count @{upstream}..HEAD 2>/dev/null || echo "0")
        fi

        # Wrap branch icon in OSC 8 hyperlink if remote available
        GIT_BRANCH_LABEL="🔱 $BRANCH"
        BRANCH_SHORT="${BRANCH:0:8}"
        [[ ${#BRANCH} -gt 8 ]] && BRANCH_SHORT+="…"
        GIT_BRANCH_LABEL_SHORT="🔱 $BRANCH_SHORT"
        if [[ -n "$GIT_REMOTE_URL" ]]; then
            BRANCH_URL="${GIT_REMOTE_URL}/tree/${BRANCH}"
            GIT_BRANCH_LABEL="${GIT_ESC}]8;;${BRANCH_URL}${GIT_ESC}\\🔱 $BRANCH${GIT_ESC}]8;;${GIT_ESC}\\"
            GIT_BRANCH_LABEL_SHORT="${GIT_ESC}]8;;${BRANCH_URL}${GIT_ESC}\\🔱 $BRANCH_SHORT${GIT_ESC}]8;;${GIT_ESC}\\"
        fi

        # Full git info (with full branch name)
        GIT_INFO=" | ${GIT_BRANCH_LABEL}"
        [[ "$CHANGES" != "0" ]] && [[ "$CHANGES" != "?" ]] && GIT_INFO+=" ●$CHANGES"
        [[ "$AHEAD" != "0" ]] && GIT_INFO+=" ↑$AHEAD"

        # Compact git info (abbreviated branch name to save space)
        GIT_INFO_COMPACT=" | ${GIT_BRANCH_LABEL_SHORT}"
        [[ "$CHANGES" != "0" ]] && [[ "$CHANGES" != "?" ]] && GIT_INFO_COMPACT+=" ●$CHANGES"
        [[ "$AHEAD" != "0" ]] && GIT_INFO_COMPACT+=" ↑$AHEAD"
    else
        # Add separator for Oh My Posh output
        # Wrap the entire oh-my-posh output in a hyperlink to the remote
        if [[ -n "$GIT_REMOTE_URL" ]]; then
            GIT_INFO=" | ${GIT_ESC}]8;;${GIT_REMOTE_URL}${GIT_ESC}\\${GIT_INFO}${GIT_ESC}]8;;${GIT_ESC}\\"
        else
            GIT_INFO=" | ${GIT_INFO}"
        fi
        # For Oh My Posh, compact version is same as full (already formatted)
        GIT_INFO_COMPACT="${GIT_INFO}"
    fi
fi

# Color selection based on context usage (using $'...' for real ANSI codes)
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
BLUE=$'\033[34m'
RESET=$'\033[0m'

if [[ $PERCENT -lt 50 ]]; then
    COLOR=$GREEN
elif [[ $PERCENT -lt 75 ]]; then
    COLOR=$YELLOW
else
    COLOR=$RED
fi

# Format tokens in compact K/M format (like cache display)
# Format: K for thousands, M for millions
format_tokens() {
    local tokens=$1
    if [[ $tokens -ge 1000000 ]]; then
        awk "BEGIN {printf \"%.0fM\", ($tokens / 1000000.0)}"
    elif [[ $tokens -ge 1000 ]]; then
        awk "BEGIN {printf \"%.0fK\", ($tokens / 1000.0)}"
    else
        printf "%s" "$tokens"  # FIX: Use printf, not echo (echo adds \n)
    fi
}

TOTAL_TOKENS_FMT=$(format_tokens $TOTAL_TOKENS)
ACTIVE_TOKENS_FMT=$(format_tokens $ACTIVE_TOKENS)

# Adaptive status line: terminal width detection
# Determines terminal width for adaptive display modes
get_terminal_width() {
    # Попытка 1: tput (наиболее надежно)
    if command -v tput &>/dev/null; then
        local width=$(tput cols 2>/dev/null)
        if [[ -n "$width" ]] && [[ "$width" =~ ^[0-9]+$ ]]; then
            echo "$width"
            return
        fi
    fi

    # Попытка 2: stty (fallback)
    if command -v stty &>/dev/null; then
        local width=$(stty size 2>/dev/null | cut -d' ' -f2)
        if [[ -n "$width" ]] && [[ "$width" =~ ^[0-9]+$ ]]; then
            echo "$width"
            return
        fi
    fi

    # Fallback: 80 колонок (compact mode)
    echo "80"
}

# Adaptive status line: model name shortening
# Shortens model names for compact display
shorten_model_name() {
    local model="$1"
    case "$model" in
        *"claude-sonnet-4-5"*) echo "Sonnet 4.5" ;;
        *"claude-sonnet-4"*) echo "Sonnet 4" ;;
        *"claude-opus-4-6"*) echo "Opus 4.6" ;;
        *"claude-opus-4"*) echo "Opus 4" ;;
        *"claude-haiku-4-5"*) echo "Haiku 4.5" ;;
        *"claude-haiku-4"*) echo "Haiku 4" ;;
        *"Sonnet 4.5"*) echo "Sonnet 4.5" ;;
        *"Sonnet 4"*) echo "Sonnet 4" ;;
        *"Sonnet"*) echo "$model" | sed 's/claude-sonnet/Sonnet/g; s/Sonnet /Sonnet/g; s/-20[0-9]*//g' ;;
        *"Opus"*) echo "$model" | sed 's/claude-opus/Opus/g; s/Opus /Opus/g; s/-20[0-9]*//g' ;;
        *"Haiku"*) echo "$model" | sed 's/claude-haiku/Haiku/g; s/Haiku /Haiku/g; s/-20[0-9]*//g' ;;
        *) echo "${model:0:15}" ;;
    esac
}

# Adaptive status line: router provider shortening
# Removes 'claude-' prefix from router providers
shorten_router_provider() {
    local provider="$1"
    echo "$provider" | sed 's/^claude-//g'
}

# CCR model formatting: "provider,model" → emoji + short name
# Input examples: "ollama,qwen3.5:397b-cloud", "deepseek,deepseek-chat"
# Output examples: "🦙 qwen3.5", "🔮 deepseek-chat"
format_ccr_model() {
    local ccr_model="$1"
    local provider="${ccr_model%%,*}"
    local model_name="${ccr_model#*,}"
    # Remove version/quantization tags (":tag") to keep base name, truncate to 15 chars
    local short_name="${model_name%%:*}"
    [[ ${#short_name} -gt 15 ]] && short_name="${short_name:0:15}…"
    local icon
    case "$provider" in
        ollama)          icon="🦙" ;;
        deepseek)        icon="🔮" ;;
        openai)          icon="🤖" ;;
        openrouter)      icon="🌐" ;;
        anthropic)       icon="" ;;
        google|gemini)   icon="✨" ;;
        *)               icon="🔀" ;;
    esac
    if [[ -n "$icon" ]]; then
        printf '%s %s' "$icon" "$short_name"
    else
        printf '%s' "$short_name"
    fi
}

# Quick transcript stability check (lightweight, no delays)
# Returns 0 if stable, 1 if recently changed
# Used on every invocation to detect late system messages
check_transcript_stability() {
    local session_id="$1"
    local project_dir="$2"

    # Convert project path to Claude's internal format
    local project_key=$(echo "$project_dir" | sed 's|/|-|g')
    local transcript_file="${CLAUDE_CONFIG_DIR}/projects/${project_key}/${session_id}.jsonl"

    # If transcript doesn't exist, consider it stable
    [[ ! -f "$transcript_file" ]] && return 0

    # Get last modification time
    local current_mtime=$(stat -c %Y "$transcript_file" 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local age=$((current_time - current_mtime))

    # If modified in last 2 seconds, consider unstable (system message may be appearing)
    if [[ $age -lt 2 ]]; then
        if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
            echo "check_transcript_stability: UNSTABLE (modified ${age}s ago)" >> /tmp/claude-statusline-debug.log
        fi
        return 1
    fi

    if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
        echo "check_transcript_stability: STABLE (modified ${age}s ago)" >> /tmp/claude-statusline-debug.log
    fi
    return 0
}

# Smart waiting: wait for system messages to clear
# Monitors session transcript file for stability
wait_for_system_messages_to_clear() {
    local session_id="$1"
    local project_dir="$2"

    # Debug mode
    local debug_log="/tmp/claude-statusline-wait-debug.log"
    if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
        echo "=== wait_for_system_messages_to_clear() called ===" >> "$debug_log"
        echo "Session ID: $session_id" >> "$debug_log"
        echo "Project DIR: $project_dir" >> "$debug_log"
    fi

    # Convert project path to Claude's internal format
    # /home/user/project -> -home-user-project
    local project_key=$(echo "$project_dir" | sed 's|/|-|g')

    # Path to session transcript file
    local transcript_file="${CLAUDE_CONFIG_DIR}/projects/${project_key}/${session_id}.jsonl"

    if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
        echo "Transcript file: $transcript_file" >> "$debug_log"
        echo "File exists: $(test -f "$transcript_file" && echo YES || echo NO)" >> "$debug_log"
    fi

    # Parameters
    local min_delay=8        # Minimum wait (increased from 3 to 8)
    local max_wait=20        # Maximum timeout (increased from 15 to 20)
    local stable_period=3    # Seconds of no changes (increased from 2 to 3)

    # Initial delay (let system messages appear)
    sleep $min_delay

    local start_time=$(date +%s)
    local last_mtime=0
    local stable_count=0
    local check_count=0

    # Wait for stability (transcript file stops changing)
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        check_count=$((check_count + 1))

        # Timeout protection
        if [[ $elapsed -ge $max_wait ]]; then
            if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
                echo "TIMEOUT reached after ${elapsed}s" >> "$debug_log"
            fi
            break
        fi

        # Check transcript file modification time
        if [[ -f "$transcript_file" ]]; then
            local current_mtime=$(stat -c %Y "$transcript_file" 2>/dev/null || echo 0)

            if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
                echo "Check #${check_count}: mtime=${current_mtime}, last=${last_mtime}, stable=${stable_count}" >> "$debug_log"
            fi

            if [[ $current_mtime -eq $last_mtime ]]; then
                # File unchanged - increment stability counter
                stable_count=$((stable_count + 1))

                # If stable for N seconds, consider messages cleared
                if [[ $stable_count -ge $stable_period ]]; then
                    if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
                        echo "STABLE detected after ${elapsed}s (${stable_count} checks)" >> "$debug_log"
                    fi
                    break
                fi
            else
                # File changed - reset counter
                stable_count=0
                last_mtime=$current_mtime
            fi
        else
            if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]] && [[ $check_count -eq 1 ]]; then
                echo "WARNING: Transcript file not found!" >> "$debug_log"
            fi
        fi

        sleep 1
    done

    if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
        echo "wait_for_system_messages_to_clear() finished after $(($(date +%s) - start_time + min_delay))s total" >> "$debug_log"
        echo "" >> "$debug_log"
    fi
}

# Adaptive status line: display mode selection
# Returns display mode based on terminal width
# - full (≥130 cols): all components
# - compact (70-129 cols): smart abbreviations + git info
# - minimal (<70 cols): critical metrics only (tokens, cache, model, cost)
get_display_mode() {
    local width=$1
    if [[ $width -ge 80 ]]; then
        echo "full"
    elif [[ $width -ge 40 ]]; then
        echo "compact"
    else
        echo "minimal"
    fi
}

# Detect terminal width and display mode
# Can be disabled with STATUSLINE_ADAPTIVE=0 for debugging
TERM_WIDTH=$(get_terminal_width)
DISPLAY_MODE="full"
if [[ "${STATUSLINE_ADAPTIVE:-1}" == "1" ]]; then
    DISPLAY_MODE=$(get_display_mode "$TERM_WIDTH")
fi

# Percentage of the full context window
EFFECTIVE_PERCENT=$(awk "BEGIN {printf \"%.0f\", ($ACTIVE_TOKENS * 100.0 / $CONTEXT_LIMIT)}")

# Remaining tokens until the window is full (shown in Σ)
REMAINING=$(( CONTEXT_LIMIT - ACTIVE_TOKENS ))
(( REMAINING < 0 )) && REMAINING=0
REMAINING_FMT=$(format_tokens "$REMAINING")

# Build context display string
# Shows: Cumulative tokens (billing) | Active context (includes cache)
# Active context represents TOTAL accumulated conversation for next message
# Cache (shown in 📦) is part of active context that's reused from prompt cache
# Handle temporary null/zero values after /clear
if [[ "$USED_PERCENTAGE" == "null" ]] || [[ -z "$USED_PERCENTAGE" ]]; then
    # Immediately after /clear: used_percentage may be null for ~10-40 seconds
    # Show 0% active until Claude Code sends real data
    ACTIVE_COLOR=$GREEN
    ACTIVE_TOKENS=0
    ACTIVE_TOKENS_FMT="0"
    ACTIVE_PERCENT="0.0"
elif [[ $ACTIVE_TOKENS -eq 0 ]]; then
    # Active context is 0 (only system prompt)
    ACTIVE_COLOR=$GREEN
    ACTIVE_TOKENS_FMT="0"
    ACTIVE_PERCENT="0.0"
else
    # Color active context based on its percentage (not cumulative)
    # Use integer comparison for awk output (format: "12.5")
    ACTIVE_PERCENT_INT=${ACTIVE_PERCENT%.*}
    if [[ -z "$ACTIVE_PERCENT_INT" ]]; then
        ACTIVE_PERCENT_INT=0
    fi

    if [[ $ACTIVE_PERCENT_INT -lt 50 ]]; then
        ACTIVE_COLOR=$GREEN
    elif [[ $ACTIVE_PERCENT_INT -lt 75 ]]; then
        ACTIVE_COLOR=$YELLOW
    else
        ACTIVE_COLOR=$RED
    fi
fi

# CRITICAL: Clean ALL variables from newlines BEFORE assembly
# Problem: Newlines appear in multiple places, not just format_tokens
TOTAL_TOKENS_FMT=$(printf '%s' "$TOTAL_TOKENS_FMT" | tr -d '\n\r')
ACTIVE_TOKENS_FMT=$(printf '%s' "$ACTIVE_TOKENS_FMT" | tr -d '\n\r')
EFFECTIVE_PERCENT=$(printf '%s' "$EFFECTIVE_PERCENT" | tr -d '\n\r')
CACHE_FMT=$(printf '%s' "${CACHE_FMT:-}" | tr -d '\n\r')

# Σ = remaining tokens until the window is full; 📊 = active context + % of full window
# Format: Σ 680K ↓ | 📊 320K (32%)
if [[ $ACTIVE_TOKENS -gt 0 ]]; then
    if [[ $ACTIVE_TOKENS -gt $CONTEXT_LIMIT ]]; then
        CONTEXT_DISPLAY="Σ ${REMAINING_FMT} ↓ | ${ACTIVE_COLOR}📊 ${ACTIVE_TOKENS_FMT} (${EFFECTIVE_PERCENT}%)${RESET} ⚠️"
    else
        CONTEXT_DISPLAY="Σ ${REMAINING_FMT} ↓ | ${ACTIVE_COLOR}📊 ${ACTIVE_TOKENS_FMT} (${EFFECTIVE_PERCENT}%)${RESET}"
    fi
else
    # Zero active tokens (after /clear)
    CONTEXT_DISPLAY="Σ ${REMAINING_FMT} ↓ | ${ACTIVE_COLOR}📊 0 (0%)${RESET}"
fi

# CRITICAL: Clean CONTEXT_DISPLAY immediately after assembly
# Newlines appear during string concatenation, not from variables
CONTEXT_DISPLAY=$(printf '%s' "$CONTEXT_DISPLAY" | tr -d '\n\r' | tr -s ' ')

# When router active and CCR API returned model info: override MODEL with actual routed model
# SESSION_DATA.model is always the Claude model name (what CCR proxies as) — not useful in router mode
if [[ -n "${_CCR_DEFAULT_MODEL:-}" ]]; then
    MODEL=$(format_ccr_model "$_CCR_DEFAULT_MODEL")
fi

# Build status line string based on display mode
# Collect entire string first for atomic output to prevent system message injection
# CRITICAL: Remove any newlines from components to prevent line wrapping
# Clean all variables before assembly
TOTAL_TOKENS_FMT=$(echo "$TOTAL_TOKENS_FMT" | tr -d '\n\r')
ACTIVE_TOKENS_FMT=$(echo "$ACTIVE_TOKENS_FMT" | tr -d '\n\r')
CACHE_FMT=$(echo "${CACHE_FMT:-}" | tr -d '\n\r')
MODEL=$(echo "$MODEL" | tr -d '\n\r')
COST=$(echo "$COST" | tr -d '\n\r')
RL_DISPLAY=$(printf '%s' "${RL_DISPLAY:-}" | tr -d '\n\r')

case "$DISPLAY_MODE" in
    full)
        # Full mode: все компоненты, модель в читаемом виде
        MODEL_SHORT=$(shorten_model_name "$MODEL")
        STATUS_LINE="${CONTEXT_DISPLAY}${CACHE_DISPLAY} | ${BLUE}${MODEL_SHORT}${RESET} | \$${COST}${PROVIDER_ICON}${STREAMING_ICON}${MICROVM_ICON}${RL_DISPLAY}${ROUTER_ICON}${PII_ICON}${SECURITY_ICON}${CAVEMAN_ICON}${SESSION_LINK}${MEMORY_LINK}${GIT_INFO} |${PROXY_ICON}"
        ;;

    compact)
        # Compact mode: MINIMAL components for 60-149 cols terminals
        # Remove: router, proxy, session link, git info
        # Keep: tokens, cache, model, cost, rate limit, memory link, pii icon, microvm
        MODEL_SHORT=$(shorten_model_name "$MODEL")
        STATUS_LINE="${CONTEXT_DISPLAY}${CACHE_DISPLAY} | ${BLUE}${MODEL_SHORT}${RESET} | \$${COST}${RL_DISPLAY}${MICROVM_ICON}${PII_ICON}${SECURITY_ICON}${CAVEMAN_ICON}${MEMORY_LINK}"
        ;;

    minimal)
        # Minimal mode: только критичное (tokens, cache, model, cost) + shields if active
        MODEL_SHORT=$(shorten_model_name "$MODEL")
        _PII_MINIMAL=""
        [[ "${ICLAUDE_PII_ACTIVE:-0}" == "1" ]] && _PII_MINIMAL=" 🛡"
        _MICROVM_MINIMAL=""
        if [[ "${ICLAUDE_MICROVM_ACTIVE:-0}" == "1" ]]; then
            [[ "${MICRO_VM_WORKSPACE_MODE:-full}" == "isolated" ]] \
                && _MICROVM_MINIMAL=" ⚡🔐" || _MICROVM_MINIMAL=" ⚡"
        fi
        STATUS_LINE="${CONTEXT_DISPLAY}${CACHE_DISPLAY} | ${BLUE}${MODEL_SHORT}${RESET} | \$${COST}${_PII_MINIMAL}${_MICROVM_MINIMAL}${SECURITY_ICON}"
        ;;
esac

# CRITICAL FIX: Clean STATUS_LINE from embedded newlines
# With real ANSI codes ($'\033[...'), don't strip them with sed
# Only clean newlines and extra spaces for safety
STATUS_LINE=$(printf '%s' "$STATUS_LINE" | tr -d '\n\r' | tr -s ' ')

# Smart handling: wait for system messages during session startup period
# System messages can appear multiple times in first ~30 seconds
# SESSION_ID and PROJECT_DIR already parsed above (after active context parsing)
SESSION_START_TIME_FILE="/tmp/claude-statusline-start-time-${SESSION_ID}"
SESSION_READY_MARKER="/tmp/claude-statusline-ready-${SESSION_ID}"

# Track session start time (first script invocation)
if [[ ! -f "$SESSION_START_TIME_FILE" ]]; then
    date +%s > "$SESSION_START_TIME_FILE" 2>/dev/null
fi

# Calculate session age
SESSION_START_TIME=$(cat "$SESSION_START_TIME_FILE" 2>/dev/null || echo 0)
CURRENT_TIME=$(date +%s)
SESSION_AGE=$((CURRENT_TIME - SESSION_START_TIME))

# Phase 1: Startup guard - wait 30 seconds for system messages to clear
# Only for NEW sessions (TOTAL_TOKENS == 0, no user messages yet)
# After 30 seconds or after first message (TOTAL_TOKENS > 0) - show normally
# This guarantees statusline appears AFTER system messages (npm installer notice etc.)
if [[ $TOTAL_TOKENS -eq 0 ]] && [[ $SESSION_AGE -lt 30 ]]; then
    exit 0  # Silent exit - statusline will appear after 30s or first message
fi

# Phase 3: After stability confirmed (or check skipped for established sessions) - normal output
# Debug: Log terminal width and display mode
if [[ "${DEBUG_STATUSLINE:-0}" == "1" ]]; then
    echo "=== STATUSLINE OUTPUT DEBUG ===" >> /tmp/claude-statusline-debug.log
    echo "TERM_WIDTH: $TERM_WIDTH" >> /tmp/claude-statusline-debug.log
    echo "DISPLAY_MODE: $DISPLAY_MODE" >> /tmp/claude-statusline-debug.log
    echo "RAW STATUS_LINE:" >> /tmp/claude-statusline-debug.log
    echo "$STATUS_LINE" >> /tmp/claude-statusline-debug.log
    echo "STATUS_LINE length: ${#STATUS_LINE}" >> /tmp/claude-statusline-debug.log
    echo "---" >> /tmp/claude-statusline-debug.log
fi

# Phase 3: Output statusline
# Записываем в кэш (атомарно: tmp + mv) перед выводом
if [[ "$_SL_WRITE_CACHE" == "1" ]]; then
    printf '%s\n' "$STATUS_LINE" > "${_SL_CACHE_FILE}.tmp" 2>/dev/null \
        && mv "${_SL_CACHE_FILE}.tmp" "$_SL_CACHE_FILE" 2>/dev/null
fi

printf '%s\n' "$STATUS_LINE"
