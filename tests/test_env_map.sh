#!/usr/bin/env bash
# Unit tests for apply_iclaude_env_map + _in_list (lib/config/env-map.sh).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Stub print_* so the module has no hard dependency on lib/core/logging.sh.
print_info()    { echo "INFO: $*"; }
print_warning() { echo "WARN: $*"; }
print_error()   { echo "ERR: $*"; }

source "$ROOT/lib/config/env-map.sh"

PASS=0; FAIL=0
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }

# Run apply_iclaude_env_map in a subshell with a controlled ICLAUDE_ environment,
# then print the canonical name's value (or the literal "<unset>").
probe() {  # $1=var-to-print  $2..=NAME=VALUE assignments to set first
  local want="$1"; shift
  bash -c '
    print_info(){ :; }; print_warning(){ :; }; print_error(){ :; }
    source "'"$ROOT"'/lib/config/env-map.sh"
    for kv in "$@"; do export "$kv"; done
    apply_iclaude_env_map
    if [[ -n ${'"$want"'+x} ]]; then printf "%s" "${'"$want"'}"; else printf "<unset>"; fi
  ' _ "$@"
}

# Passthrough: de-prefix + export canonical name.
assert_eq "$(probe ANTHROPIC_API_KEY ICLAUDE_ANTHROPIC_API_KEY=sk-x)" "sk-x" "passthrough de-prefix"
# Internal: same de-prefix rule.
assert_eq "$(probe PROXY_URL ICLAUDE_PROXY_URL=https://h:8118)" "https://h:8118" "internal de-prefix"
# Native denylist: must NOT create the de-prefixed name.
assert_eq "$(probe CHAT_LANG ICLAUDE_CHAT_LANG=Russian)" "<unset>" "native not de-prefixed"
# Native denylist: the ICLAUDE_ name itself is still exported.
assert_eq "$(probe ICLAUDE_CHAT_LANG ICLAUDE_CHAT_LANG=Russian)" "Russian" "native kept verbatim"
# Empty (unset-or-empty) value is ignored.
assert_eq "$(probe ANTHROPIC_MODEL ICLAUDE_ANTHROPIC_MODEL=)" "<unset>" "empty ignored"
# Allow-empty var: set-but-empty IS exported.
assert_eq "$(probe PII_PROXY_MASK_TOKEN ICLAUDE_PII_PROXY_MASK_TOKEN=)" "" "allow-empty set-but-empty exported"

# _in_list direct checks
_in_list ICLAUDE_CHAT_LANG "${ICLAUDE_NATIVE[@]}" && r=0 || r=1
assert_eq "$r" "0" "_in_list hit"
_in_list ICLAUDE_PROXY_URL "${ICLAUDE_NATIVE[@]}" && r=0 || r=1
assert_eq "$r" "1" "_in_list miss"

echo "env-map: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
