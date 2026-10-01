#!/usr/bin/env bash
# Subscription-only snapshots. Never use convenience fail-soft locks for auth.

_oauth_error() {
    print_error "Authentication state conflict or write failure; originals retained. Review common and project login before retrying."
    return 1
}

_oauth_json() {
    local file="$1"
    if [[ -f "$file" ]]; then
        jq -ce 'select(type == "object")' "$file" 2>/dev/null
    elif [[ -e "$file" || -L "$file" ]]; then
        return 1
    else
        printf '{}\n'
    fi
}

_oauth_state() {
    local credentials metadata
    credentials=$(_oauth_json "$1/.credentials.json") || return 1
    metadata=$(_oauth_json "$1/.claude.json") || return 1
    jq -cnS --argjson credentials "$credentials" --argjson metadata "$metadata" '
        {subscription: ($credentials.claudeAiOauth // null),
         account: ($metadata | with_entries(select(.key == "oauthAccount" or
             .key == "hasCompletedOnboarding" or .key == "lastOnboardingVersion")))}'
}

_oauth_valid_state() {
    jq -e '.subscription.accessToken | type == "string" and length > 0' <<< "$1" >/dev/null 2>&1 &&
        jq -e '(.account.oauthAccount.accountUuid // .account.oauthAccount.emailAddress) |
            type == "string" and length > 0' <<< "$1" >/dev/null 2>&1
}

_oauth_identity() {
    jq -r '.account.oauthAccount.accountUuid // .account.oauthAccount.emailAddress // empty' <<< "$1"
}

_oauth_check_paths() {
    local store="$1" home="$2"
    [[ -d "$store" && -d "$home" ]] || return 1
    [[ ! -L "$store/.credentials.json" && ! -L "$store/.claude.json" ]] || return 1
    [[ ! -L "$home/.claude.json" && ! -L "$home/.iclaude-auth-baseline.json" ]] || return 1
    [[ ! -e "$store/.iclaude-auth-recovery" && ! -e "$home/.iclaude-auth-recovery" ]] || return 1
    if [[ -L "$home/.credentials.json" ]]; then
        [[ "$(readlink -f "$home/.credentials.json")" == "$(readlink -f "$store/.credentials.json")" ]] || return 1
    fi
}

# Caller owns store lock. Take home read lock first; upgrade only for actual writes.
_oauth_locked() (
    local store="$1" home="$2" action="$3" store_fd home_fd
    umask 077
    command -v flock >/dev/null 2>&1 || { _oauth_error; return 1; }
    _oauth_check_paths "$store" "$home" || { _oauth_error; return 1; }
    [[ ! -L "$store/.iclaude-auth.lock" && ! -L "$home/.iclaude-auth.lock" ]] || return 1
    exec {store_fd}>"$store/.iclaude-auth.lock" || return 1
    flock -x -w 30 "$store_fd" || { _oauth_error; return 1; }
    exec {home_fd}>"$home/.iclaude-auth.lock" || return 1
    flock -s -w 30 "$home_fd" || { _oauth_error; return 1; }
    # Validate again after waiting: another writer may have marked recovery.
    _oauth_check_paths "$store" "$home" || { _oauth_error; return 1; }
    "$action" "$store" "$home" "$home_fd"
)

# Staging directory remains as private retained backup/recovery evidence.
_oauth_replace_pair() {
    local destination="$1" state="$2" stage credentials metadata name failed=0 replace_credentials=true
    stage=$(mktemp -d "$destination/.iclaude-auth-backup.XXXXXXXX") || return 1
    credentials=$(_oauth_json "$destination/.credentials.json") || return 1
    metadata=$(_oauth_json "$destination/.claude.json") || return 1
    if [[ ! -L "$destination/.credentials.json" &&
        "$(jq -cS '.claudeAiOauth' <<< "$credentials")" == "$(jq -cS '.subscription' <<< "$state")" ]]; then
        replace_credentials=false
    fi
    jq -n --argjson original "$credentials" --argjson state "$state" \
        '$original + {claudeAiOauth: $state.subscription}' > "$stage/new-credentials" || return 1
    jq -n --argjson original "$metadata" --argjson state "$state" \
        '($original | del(.oauthAccount, .hasCompletedOnboarding, .lastOnboardingVersion)) + $state.account' \
        > "$stage/new-metadata" || return 1
    chmod 600 "$stage/new-credentials" "$stage/new-metadata" || return 1
    for name in .credentials.json .claude.json; do
        if [[ -e "$destination/$name" || -L "$destination/$name" ]]; then
            cp -Pp "$destination/$name" "$stage/$name" || return 1
            [[ -L "$stage/$name" ]] || chmod 600 "$stage/$name" || return 1
        fi
    done
    if { [[ "$replace_credentials" == false ]] || mv "$stage/new-credentials" "$destination/.credentials.json"; } &&
        mv "$stage/new-metadata" "$destination/.claude.json"; then
        return 0
    fi
    for name in .credentials.json .claude.json; do
        if [[ -e "$stage/$name" || -L "$stage/$name" ]]; then
            cp -Pp "$stage/$name" "$stage/restore" &&
                mv "$stage/restore" "$destination/$name" || failed=1
        else
            rm -f "$destination/$name" || failed=1
        fi
    done
    if [[ "$failed" == 1 ]]; then
        printf 'Manual recovery required; retained backup: %s\n' "$stage" > "$destination/.iclaude-auth-recovery"
    fi
    return 1
}

_oauth_baseline() {
    local home="$1" state="$2" temporary fingerprint
    temporary=$(mktemp "$home/.iclaude-auth-baseline.XXXXXXXX") || return 1
    fingerprint=$(printf '%s' "$state" | sha256sum | cut -d ' ' -f 1) || return 1
    jq -n --argjson state "$state" --arg fingerprint "$fingerprint" \
        '{version: 1, state: $state, fingerprint: $fingerprint}' > "$temporary" || return 1
    chmod 600 "$temporary" && mv "$temporary" "$home/.iclaude-auth-baseline.json"
}

_oauth_sync_locked() {
    local store="$1" home="$2" home_fd="$3" exclusive="${4:-false}" common current baseline subscription
    common=$(_oauth_state "$store") || { _oauth_error; return 1; }
    current=$(_oauth_state "$home") || { _oauth_error; return 1; }
    _oauth_valid_state "$common" || { _oauth_error; return 1; }
    if [[ "$exclusive" == false ]]; then
        if [[ -f "$home/.iclaude-auth-baseline.json" ]]; then
            baseline=$(jq -ceS 'select(.version == 1) | .state | select(type == "object")' \
                "$home/.iclaude-auth-baseline.json" 2>/dev/null) || { _oauth_error; return 1; }
            [[ "$current" == "$common" && "$common" == "$baseline" ]] && return 0
        fi
        flock -x -w 30 "$home_fd" || { _oauth_error; return 1; }
        # Native readers can modify credentials while we wait to upgrade.
        # Never publish/replace from the stale observation made under a reader lock.
        _oauth_sync_locked "$store" "$home" "$home_fd" true
        return
    fi

    if [[ ! -f "$home/.iclaude-auth-baseline.json" ]]; then
        subscription=$(jq -cS '.subscription' <<< "$current")
        # Existing equal subscription may be adopted, but never a different account.
        if [[ "$subscription" != null && "$subscription" != "$(jq -cS '.subscription' <<< "$common")" ]]; then
            _oauth_error; return 1
        fi
        if [[ -n "$(_oauth_identity "$current")" && "$(_oauth_identity "$current")" != "$(_oauth_identity "$common")" ]]; then
            _oauth_error; return 1
        fi
        if [[ "$current" != "$common" || -L "$home/.credentials.json" ]]; then
            _oauth_replace_pair "$home" "$common" || { _oauth_error; return 1; }
        fi
        _oauth_baseline "$home" "$common"
        return
    fi

    baseline=$(jq -ceS 'select(.version == 1) | .state | select(type == "object")' \
        "$home/.iclaude-auth-baseline.json" 2>/dev/null) || { _oauth_error; return 1; }
    _oauth_valid_state "$current" && _oauth_valid_state "$baseline" || { _oauth_error; return 1; }
    [[ "$(_oauth_identity "$common")" == "$(_oauth_identity "$baseline")" &&
       "$(_oauth_identity "$current")" == "$(_oauth_identity "$baseline")" ]] || { _oauth_error; return 1; }
    if [[ "$current" == "$common" && "$common" == "$baseline" ]]; then
        return 0
    fi
    if [[ "$current" == "$common" ]]; then
        _oauth_baseline "$home" "$common"
    elif [[ "$current" == "$baseline" ]]; then
        _oauth_replace_pair "$home" "$common" && _oauth_baseline "$home" "$common" || { _oauth_error; return 1; }
    elif [[ "$common" == "$baseline" ]]; then
        _oauth_replace_pair "$store" "$current" && _oauth_baseline "$home" "$current" || { _oauth_error; return 1; }
    else
        _oauth_error
    fi
}

oauth_prepare_home() {
    [[ "$1" != "$2" ]] || return 1
    _oauth_locked "$1" "$2" _oauth_sync_locked
}

oauth_reconcile_home() {
    oauth_prepare_home "$@"
}

oauth_select_source() {
    local directory="${2:-$1}"
    # Presence is source selection, not a claim that the server accepts this token.
    if [[ -f "$directory/.credentials.json" ]] && jq -e \
        '.claudeAiOauth.refreshToken | type == "string" and length > 0' \
        "$directory/.credentials.json" >/dev/null 2>&1; then
        unset CLAUDE_CODE_OAUTH_TOKEN
    fi
}

_oauth_login_requested() {
    local previous="" argument
    shift
    for argument in "$@"; do
        [[ "$previous" == auth && "$argument" == login ]] && return 0
        previous="$argument"
    done
    return 1
}

_oauth_wait_native() {
    local child status=0 old_traps
    old_traps=$(trap -p TERM INT HUP)
    "$@" <&0 &
    child=$!
    trap 'kill -TERM "$child" 2>/dev/null || true' TERM
    trap 'kill -INT "$child" 2>/dev/null || true' INT
    trap 'kill -HUP "$child" 2>/dev/null || true' HUP
    while true; do
        wait "$child" && status=0 || status=$?
        # A trapped signal interrupts wait before the child necessarily exits.
        kill -0 "$child" 2>/dev/null || break
    done
    trap - TERM INT HUP
    [[ -z "$old_traps" ]] || eval "$old_traps"
    return "$status"
}

oauth_run_common() {
    _oauth_wait_native _oauth_common_impl "$@"
}

_oauth_common_impl() {
    local store="$1" descriptor
    shift
    umask 077
    command -v flock >/dev/null 2>&1 || { _oauth_error; return 1; }
    [[ -d "$store" && ! -L "$store/.iclaude-auth.lock" &&
        ! -L "$store/.credentials.json" && ! -L "$store/.claude.json" &&
        ! -e "$store/.iclaude-auth-recovery" ]] || { _oauth_error; return 1; }
    exec {descriptor}>"$store/.iclaude-auth.lock" || return 1
    flock -x -w 30 "$descriptor" || { _oauth_error; return 1; }
    export CLAUDE_CONFIG_DIR="$store"
    if _oauth_login_requested "$@"; then unset CLAUDE_CODE_OAUTH_TOKEN; else oauth_select_source "$store" "$store"; fi
    _oauth_wait_native "$@"
}

_oauth_detach_project_locked() {
    local store="$1" home="$2" descriptor="$3" stage
    [[ -L "$home/.credentials.json" ]] || return 0
    flock -x -w 30 "$descriptor" || { _oauth_error; return 1; }
    _oauth_check_paths "$store" "$home" || { _oauth_error; return 1; }
    stage=$(mktemp -d "$home/.iclaude-auth-backup.XXXXXXXX") || return 1
    cp -Pp "$home/.credentials.json" "$stage/.credentials.json" &&
        cp -Lp "$home/.credentials.json" "$stage/local-credentials" &&
        chmod 600 "$stage/local-credentials" &&
        mv "$stage/local-credentials" "$home/.credentials.json"
}

_oauth_setup_complete() {
    [[ -f "$1/.claude.json" ]] && jq -e '.hasCompletedOnboarding == true' \
        "$1/.claude.json" >/dev/null 2>&1
}

_oauth_read_common_state() (
    local store="$1" descriptor
    umask 077
    [[ ! -L "$store/.iclaude-auth.lock" && ! -e "$store/.iclaude-auth-recovery" ]] || return 1
    exec {descriptor}>"$store/.iclaude-auth.lock" || return 1
    flock -s -w 30 "$descriptor" || return 1
    _oauth_state "$store"
)

oauth_run_session() {
    _oauth_wait_native _oauth_session_impl "$@"
}

_oauth_session_impl() {
    local store="$1" home="$2" descriptor status=0 state
    shift 2
    umask 077
    [[ -d "$store" && -d "$home" ]] || { _oauth_error; return 1; }
    command -v flock >/dev/null 2>&1 || { _oauth_error; return 1; }

    if [[ "${ICLAUDE_AUTH_MODE:-shared}" == project ]]; then
        if [[ "$home" == "$store" ]]; then
            print_error "Project auth requires a separate project config directory, not --shared-config."
            return 1
        fi
        if [[ -L "$home/.credentials.json" ]]; then
            _oauth_locked "$store" "$home" _oauth_detach_project_locked || return 1
        fi
        [[ ! -L "$home/.claude.json" && ! -L "$home/.iclaude-auth.lock" &&
            ! -e "$home/.iclaude-auth-recovery" ]] || { _oauth_error; return 1; }
        exec {descriptor}>"$home/.iclaude-auth.lock" || return 1
        flock -x -w 30 "$descriptor" || { _oauth_error; return 1; }
        export CLAUDE_CONFIG_DIR="$home"
        oauth_select_source "$home" "$home"
        _oauth_login_requested "$@" && unset CLAUDE_CODE_OAUTH_TOKEN
        _oauth_wait_native "$@"
        return
    fi

    if _oauth_login_requested "$@"; then
        oauth_run_common "$store" "$@"
        return
    fi

    state=$(_oauth_read_common_state "$store") || { _oauth_error; return 1; }
    if ! jq -e '.account.hasCompletedOnboarding == true' <<< "$state" >/dev/null ||
        { ! _oauth_valid_state "$state" && [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; }; then
        if [[ ! -t 0 || ! -t 1 ]]; then
            print_error "Common Claude setup required. Start iclaude interactively to complete login and onboarding once."
            return 1
        fi
        # Native interactive setup, not setup-token and never fabricated metadata.
        # Suppress legacy tokens for this one setup invocation.
        local -a setup_command=( "${@:1:${OAUTH_NATIVE_COMMAND_COUNT:-1}}" )
        (unset CLAUDE_CODE_OAUTH_TOKEN; oauth_run_common "$store" "${setup_command[@]}") || return $?
        state=$(_oauth_read_common_state "$store") || { _oauth_error; return 1; }
        jq -e '.account.hasCompletedOnboarding == true' <<< "$state" >/dev/null &&
            _oauth_valid_state "$state" || { _oauth_error; return 1; }
    fi

    if [[ "$home" == "$store" ]]; then
        oauth_run_common "$store" "$@"
        return
    fi

    if ! _oauth_valid_state "$state"; then
        # Legacy environment-token mode: no fabricated native login or CAS baseline.
        # Home onboarding must come from existing native setup, not inferred access.
        _oauth_setup_complete "$home" || { _oauth_error; return 1; }
        export CLAUDE_CONFIG_DIR="$home"
        _oauth_wait_native "$@"
        return
    fi

    oauth_prepare_home "$store" "$home" || return 1
    exec {descriptor}>"$home/.iclaude-auth.lock" || return 1
    flock -s -w 30 "$descriptor" || { _oauth_error; return 1; }
    export CLAUDE_CONFIG_DIR="$home"
    oauth_select_source "$store" "$home"
    _oauth_wait_native "$@" || status=$?
    exec {descriptor}>&-
    if ! oauth_reconcile_home "$store" "$home"; then
        [[ "$status" != 0 ]] || status=73
    fi
    return "$status"
}
