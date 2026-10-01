#!/usr/bin/env bash
# Catch inherited/aliased auth policy, stale reloads and invalid config acceptance.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
print_error() { printf '%s\n' "$*" >&2; }
source "$ROOT/lib/config/env-map.sh"

checks=0
assert_eq() {
    if [[ "$1" != "$2" ]]; then
        printf 'FAIL: %s (got %s; expected %s)\n' "$3" "$1" "$2" >&2
        exit 1
    fi
    checks=$((checks + 1))
}

export ICLAUDE_AUTH_MODE=project AUTH_MODE=project
CREDENTIALS_FILE="$fixture_dir/missing.conf"
source_iclaude_config
assert_eq "$ICLAUDE_AUTH_MODE" shared 'missing config ignores inherited policy'

CREDENTIALS_FILE="$fixture_dir/config"
printf '%s\n' 'ICLAUDE_AUTH_MODE=project' > "$CREDENTIALS_FILE"
source_iclaude_config
assert_eq "$ICLAUDE_AUTH_MODE" project 'config selects project policy'
assert_eq "$(bash -c 'printf "%s" "${ICLAUDE_AUTH_MODE-unset}"')" unset 'policy remains launcher-local'

unset AUTH_MODE
apply_iclaude_env_map
assert_eq "${AUTH_MODE-unset}" unset 'policy has no de-prefixed alias'

printf '%s\n' 'ICLAUDE_AUTH_MODE=shared' > "$CREDENTIALS_FILE"
source_iclaude_config
assert_eq "$ICLAUDE_AUTH_MODE" shared 'config selects shared policy'

printf '%s\n' '# No auth mode configured' 'ICLAUDE_CHAT_LANG=Russian' > "$CREDENTIALS_FILE"
ICLAUDE_AUTH_MODE=project
source_iclaude_config
assert_eq "$ICLAUDE_AUTH_MODE" shared 'reload clears previous project policy'
assert_eq "$ICLAUDE_CHAT_LANG" Russian 'existing native config mapping survives'

export ICLAUDE_HOME_MODE=per-project
use_shared_config=true
source_iclaude_config
assert_eq "$ICLAUDE_AUTH_MODE" shared 'directory mode and shared flag do not select auth'

for value in invalid '' SHARED; do
    printf 'ICLAUDE_AUTH_MODE=%q\n' "$value" > "$CREDENTIALS_FILE"
    if source_iclaude_config 2> "$fixture_dir/error"; then
        printf 'FAIL: invalid policy accepted\n' >&2
        exit 1
    fi
    [[ -s "$fixture_dir/error" ]]
    checks=$((checks + 1))
done

printf '%s\n' 'ICLAUDE_AUTH_MODE=shared' 'ICLAUDE_PROXY_URL=https://fixture.invalid' > "$CREDENTIALS_FILE"
source_iclaude_config
assert_eq "$PROXY_URL" https://fixture.invalid 'ordinary de-prefix mapping survives'

printf '%s\n' 'export ICLAUDE_AUTH_MODE=project' > "$CREDENTIALS_FILE"
source_iclaude_config
assert_eq "$ICLAUDE_AUTH_MODE" project 'legacy exported config selects policy'
assert_eq "$(bash -c 'printf "%s" "${ICLAUDE_AUTH_MODE-unset}"')" unset 'legacy config cannot export policy to child'

: > "$CREDENTIALS_FILE"
source_iclaude_config
assert_eq "$ICLAUDE_AUTH_MODE" shared 'empty config resets legacy policy'

# The shipped example has many empty settings: loading it must not abort set -e.
if ! bash -c '
    set -euo pipefail
    print_error() { printf "%s\n" "$*" >&2; }
    source "$1/lib/config/env-map.sh"
    CREDENTIALS_FILE="$1/.claude_config.example"
    source_iclaude_config
    [[ "$ICLAUDE_AUTH_MODE" == shared ]]
' _ "$ROOT"; then
    printf 'FAIL: example config aborts strict launcher\n' >&2
    exit 1
fi
checks=$((checks + 1))

printf 'oauth-policy: PASS=%s FAIL=0\n' "$checks"
