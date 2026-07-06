#!/usr/bin/env bash
# Verifies the iclaude.sh persistent-settings grep block fires on ICLAUDE_* names,
# and still fires for a legacy file once migrate_legacy_config has run first.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
print_info(){ :; }; print_warning(){ :; }
source "$ROOT/lib/config/env-map.sh"

PASS=0; FAIL=0
assert_eq(){ if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }

# Replicate the grep used by iclaude.sh for one toggle.
toggle_on() {  # $1=config-file $2=ICLAUDE_name
  grep -qE "^[[:space:]]*(export[[:space:]]+)?$2[[:space:]]*=[[:space:]]*[\"']?true[\"']?" "$1" && echo true || echo false
}

TD=$(mktemp -d)

# ICLAUDE_-named file → toggle matches.
printf 'ICLAUDE_USE_PII_PROXY=true\n' > "$TD/.claude_config"
assert_eq "$(toggle_on "$TD/.claude_config" ICLAUDE_USE_PII_PROXY)" "true" "ICLAUDE_ toggle matches"

# Legacy file → does NOT match ICLAUDE_ pattern until migrated...
printf 'USE_PII_PROXY=true\n' > "$TD/.claude_config"
assert_eq "$(toggle_on "$TD/.claude_config" ICLAUDE_USE_PII_PROXY)" "false" "legacy not matched pre-migration"
# ...then migrate, then it matches (ordering guarantee).
CREDENTIALS_FILE="$TD/.claude_config" migrate_legacy_config
assert_eq "$(toggle_on "$TD/.claude_config" ICLAUDE_USE_PII_PROXY)" "true" "matches after migration"

rm -rf "$TD"
echo "toggles: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
