#!/usr/bin/env bash
# Native boundary doubles avoid browser/network/account access entirely.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
print_error() { printf '%s\n' "$*" >&2; }
source "$ROOT/lib/oauth/persistence.sh"
source "$ROOT/lib/oauth/token.sh"
source "$ROOT/lib/launcher/launch.sh"
declare -F _uses_subscription_auth >/dev/null || { echo 'FAIL: native auth dispatch unavailable'; exit 1; }
_uses_subscription_auth false false
if _uses_subscription_auth true false || _uses_subscription_auth false true; then echo 'FAIL: provider/system flow captured'; exit 1; fi
(
    export ANTHROPIC_API_KEY=fixture-provider
    if _uses_subscription_auth false false; then exit 1; fi
)
declare -F oauth_run_session >/dev/null || { echo 'FAIL: auth session supervisor unavailable'; exit 1; }
store="$tmp/store"
home="$tmp/home"
mkdir "$store" "$home"

# Expiry delegates to native refresh; setup-token is never an automatic renewal.
ISOLATED_CONFIG_DIR="$store"
ISOLATED_NVM_DIR="$tmp/nvm"
mkdir "$ISOLATED_NVM_DIR"
TOKEN_REFRESH_THRESHOLD=604800
validate_jq_installed() { return 0; }
print_info() { :; }
print_warning() { :; }
print_success() { :; }
refresh_oauth_token() { : > "$tmp/unwanted-setup-token"; return 1; }
printf '%s\n' '{"claudeAiOauth":{"accessToken":"fixture-expired","refreshToken":"fixture-refresh","expiresAt":1}}' > "$store/.credentials.json"
unset CLAUDE_CODE_OAUTH_TOKEN
check_oauth_token false
[[ ! -e "$tmp/unwanted-setup-token" ]]
printf '%s\n' '{"claudeAiOauth":{"accessToken":"fixture-native","refreshToken":"fixture-refresh"}}' > "$store/.credentials.json"
printf '%s\n' '{"hasCompletedOnboarding":true,"oauthAccount":{"accountUuid":"fixture-account"}}' > "$store/.claude.json"
native() {
    printf '%s\n' "$CLAUDE_CONFIG_DIR" > "$tmp/selected-home"
    printf '%s\n' "${CLAUDE_CODE_OAUTH_TOKEN-present-not-set}" > "$tmp/token-env"
    return "${native_status:-0}"
}
ICLAUDE_AUTH_MODE=shared
export CLAUDE_CODE_OAUTH_TOKEN=fixture-stale
oauth_run_session "$store" "$home" native
[[ "$(< "$tmp/selected-home")" == "$home" ]]
[[ "$(< "$tmp/token-env")" == present-not-set ]]
[[ "$CLAUDE_CODE_OAUTH_TOKEN" == fixture-stale ]]

native_status=42
if oauth_run_session "$store" "$home" native; then echo 'FAIL: native error hidden'; exit 1; else [[ "$?" == 42 ]]; fi
native_status=0

# Launcher-managed explicit login uses canonical store without --shared-config.
oauth_run_session "$store" "$home" native auth login
[[ "$(< "$tmp/selected-home")" == "$store" ]]
[[ "$(< "$tmp/token-env")" == present-not-set ]]

# Config-only project mode neither routes login to nor writes common store.
ICLAUDE_AUTH_MODE=project
ln -s "$store/.credentials.json" "$tmp/project-link"
project="$tmp/project"
mkdir "$project"
ln -s "$store/.credentials.json" "$project/.credentials.json"
before="$(sha256sum "$store/.credentials.json")"
oauth_run_session "$store" "$project" native auth login
[[ "$(< "$tmp/selected-home")" == "$project" && ! -L "$project/.credentials.json" ]]
[[ "$(sha256sum "$store/.credentials.json")" == "$before" ]]
if oauth_run_session "$store" "$store" native 2> "$tmp/error"; then echo 'FAIL: project login used shared store'; exit 1; fi

# A missing common setup never starts an unattended native process.
ICLAUDE_AUTH_MODE=shared
missing="$tmp/missing"
mkdir "$missing"
rm "$tmp/selected-home"
if oauth_run_session "$missing" "$home" native < /dev/null 2> "$tmp/error"; then echo 'FAIL: unattended setup accepted'; exit 1; fi
[[ ! -e "$tmp/selected-home" ]]

# Native changes are published after exit, before next project's launch.
native_refresh() {
    jq '.claudeAiOauth.accessToken="fixture-renewed"' "$CLAUDE_CONFIG_DIR/.credentials.json" > "$tmp/refreshed"
    mv "$tmp/refreshed" "$CLAUDE_CONFIG_DIR/.credentials.json"
}
oauth_run_session "$store" "$home" native_refresh
[[ "$(jq -r '.claudeAiOauth.accessToken' "$store/.credentials.json")" == fixture-renewed ]]
mkdir "$tmp/second"
oauth_run_session "$store" "$tmp/second" native
[[ "$(jq -r '.claudeAiOauth.accessToken' "$tmp/second/.credentials.json")" == fixture-renewed ]]

# Success must not hide a reconciliation conflict.
native_conflict() {
    jq '.claudeAiOauth.accessToken="fixture-home-conflict"' "$CLAUDE_CONFIG_DIR/.credentials.json" > "$tmp/changed-home"
    mv "$tmp/changed-home" "$CLAUDE_CONFIG_DIR/.credentials.json"
    jq '.claudeAiOauth.accessToken="fixture-store-conflict"' "$store/.credentials.json" > "$tmp/changed-store"
    mv "$tmp/changed-store" "$store/.credentials.json"
}
if oauth_run_session "$store" "$home" native_conflict 2> "$tmp/error"; then echo 'FAIL: publication conflict hidden'; exit 1; else [[ "$?" == 73 ]]; fi

# Fresh fixtures for supervised signal forwarding and actual shared setup routing.
signal_home="$tmp/signal-home"
mkdir "$signal_home"
native_wait() {
    trap 'printf "terminated\n" > "$tmp/terminated"; exit 143' TERM
    : > "$tmp/child-ready"
    while true; do sleep 0.05; done
}
oauth_run_session "$store" "$signal_home" native_wait &
supervisor=$!
while [[ ! -e "$tmp/child-ready" ]]; do sleep 0.01; done
kill -TERM "$supervisor"
if wait "$supervisor"; then echo 'FAIL: terminated session returned success'; exit 1; else [[ "$?" == 143 ]]; fi
[[ -f "$tmp/terminated" ]]

if [[ "${1:-}" == --interactive ]]; then
    setup_store="$tmp/setup-store"
    setup_home="$tmp/setup-home"
    mkdir "$setup_store" "$setup_home"
    setup_native() {
        [[ "$1" == fixture-prefix ]]
        if [[ "$CLAUDE_CONFIG_DIR" == "$setup_store" ]]; then
            [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]
            printf '%s\n' '{"claudeAiOauth":{"accessToken":"fixture-setup","refreshToken":"fixture-refresh"}}' > "$CLAUDE_CONFIG_DIR/.credentials.json"
            printf '%s\n' '{"hasCompletedOnboarding":true,"oauthAccount":{"accountUuid":"fixture-account"}}' > "$CLAUDE_CONFIG_DIR/.claude.json"
        fi
    }
    OAUTH_NATIVE_COMMAND_COUNT=2
    oauth_run_session "$setup_store" "$setup_home" setup_native fixture-prefix
    [[ "$(jq -r '.claudeAiOauth.accessToken' "$setup_home/.credentials.json")" == fixture-setup ]]
fi
printf 'oauth-launch: PASS (native/source/login/conflict/signal assertions)\n'
