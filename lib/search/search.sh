#!/usr/bin/env bash
# One-session search arguments; all persistent settings remain read-only.
search_prepare_launch() {
    local routed="$1" microvm="$2" router_config="$3"
    shift 3
    SEARCH_LAUNCH_ARGS=()
    if [[ "${SEARCH_ENV_ACTIVE:-false}" == true ]]; then
        if [[ "$SEARCH_OLD_URL_SET" == x ]]; then export FRAMEWORK_WEBSEARCH_URL="$SEARCH_OLD_URL"; else unset FRAMEWORK_WEBSEARCH_URL; fi
        if [[ "$SEARCH_OLD_TOKEN_SET" == x ]]; then export FRAMEWORK_WEBSEARCH_TOKEN="$SEARCH_OLD_TOKEN"; else unset FRAMEWORK_WEBSEARCH_TOKEN; fi
        SEARCH_ENV_ACTIVE=false
    fi
    local selected="${ICLAUDE_SEARCH_MODE:-inherit}"
    if [[ "$routed" == true ]]; then
        selected="${ICLAUDE_ROUTER_SEARCH_MODE:-inherit}"
    fi
    if [[ "$selected" == inherit && ( "$routed" != true || -z "${ICLAUDE_SEARCH_ROUTE_MODES:-}" || "${ICLAUDE_SEARCH_ROUTE_MODES:-}" == '{}' ) ]]; then
        return 0
    fi
    local output mode
    output=$(mktemp) || return 1
    if ! python3 "${LIB_DIR}/search/policy.py" "$routed" "$microvm" "$router_config" "$@" >"$output"; then
        rm -f "$output"
        return 1
    fi
    local -a values=()
    mapfile -d '' -t values <"$output"
    rm -f "$output"
    mode="${values[0]}"
    SEARCH_LAUNCH_ARGS=("${values[@]:1}")
    if [[ "$mode" == framework ]]; then
        local key="$ICLAUDE_SEARCH_API_ENV_KEY"
        SEARCH_OLD_URL_SET="${FRAMEWORK_WEBSEARCH_URL+x}"
        SEARCH_OLD_TOKEN_SET="${FRAMEWORK_WEBSEARCH_TOKEN+x}"
        SEARCH_OLD_URL="${FRAMEWORK_WEBSEARCH_URL:-}"
        SEARCH_OLD_TOKEN="${FRAMEWORK_WEBSEARCH_TOKEN:-}"
        SEARCH_ENV_ACTIVE=true
        export FRAMEWORK_WEBSEARCH_URL="$ICLAUDE_SEARCH_API_URL"
        export FRAMEWORK_WEBSEARCH_TOKEN="${!key}"
    fi
}
