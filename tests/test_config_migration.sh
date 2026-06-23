#!/usr/bin/env bash
# Unit tests for _config_is_legacy + migrate_legacy_config (lib/config/env-map.sh).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
print_info()    { echo "INFO: $*"; }
print_warning() { echo "WARN: $*"; }
source "$ROOT/lib/config/env-map.sh"

PASS=0; FAIL=0
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }
assert_file_contains() { if grep -qF "$2" "$1"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: '$2' not in $1"; fi; }
assert_file_missing_line() { if grep -qF "$2" "$1"; then FAIL=$((FAIL+1)); echo "FAIL [$3]: unexpected '$2' in $1"; else PASS=$((PASS+1)); fi; }

TD=$(mktemp -d)

# --- legacy file with export + bare + a comment + an already-prefixed var ---
cat > "$TD/.claude_config" <<'EOF'
# a comment with FOO=bar inside prose
export DEEPSEEK_API_KEY=sk-123
PROXY_URL=https://h:8118
ICLAUDE_CHAT_LANG=Russian
EOF

CREDENTIALS_FILE="$TD/.claude_config"
_config_is_legacy "$CREDENTIALS_FILE" && r=0 || r=1
assert_eq "$r" "0" "detect: legacy true"

migrate_legacy_config
assert_file_contains "$TD/.claude_config" "ICLAUDE_DEEPSEEK_API_KEY=sk-123" "migrate: export renamed + de-exported"
assert_file_missing_line "$TD/.claude_config" "export DEEPSEEK_API_KEY" "migrate: export keyword gone"
assert_file_contains "$TD/.claude_config" "ICLAUDE_PROXY_URL=https://h:8118" "migrate: bare renamed"
assert_file_contains "$TD/.claude_config" "ICLAUDE_CHAT_LANG=Russian" "migrate: already-prefixed kept"
assert_file_missing_line "$TD/.claude_config" "ICLAUDE_ICLAUDE_CHAT_LANG" "migrate: no double prefix"
assert_file_contains "$TD/.claude_config" "# a comment with FOO=bar inside prose" "migrate: comment untouched"
assert_eq "$(test -f "$TD/.claude_config.bak" && echo yes)" "yes" "migrate: .bak created"

# --- idempotency: second run is a no-op ---
_config_is_legacy "$CREDENTIALS_FILE" && r=0 || r=1
assert_eq "$r" "1" "detect: migrated file not legacy"
cp "$TD/.claude_config" "$TD/snapshot"
migrate_legacy_config
assert_eq "$(diff -q "$TD/.claude_config" "$TD/snapshot" >/dev/null && echo same)" "same" "migrate: idempotent no-op"

rm -rf "$TD"
echo "migration: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
