#!/usr/bin/env bash
# Unit tests for S8 binary integrity pinning: record_claude_binary_hash and
# verify_claude_binary_hash (lib/lockfile/save.sh).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WARNINGS=""
print_info()    { :; }
print_warning() { WARNINGS+="$*"$'\n'; }
print_error()   { :; }
validate_dependency() { command -v "$1" &>/dev/null; }

source "$ROOT/lib/core/json.sh" 2>/dev/null || true
# Extract just the S8 functions from save.sh (sourcing it whole drags nvm deps).
eval "$(awk '/^_resolve_claude_binary_file\(\)/,/^}/' "$ROOT/lib/lockfile/save.sh")"
eval "$(awk '/^record_claude_binary_hash\(\)/,/^}/' "$ROOT/lib/lockfile/save.sh")"
eval "$(awk '/^verify_claude_binary_hash\(\)/,/^}/' "$ROOT/lib/lockfile/save.sh")"

PASS=0; FAIL=0
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }
assert_true() { if eval "$1"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$2]"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export ISOLATED_NVM_DIR="$TMP/nvm"
export ISOLATED_LOCKFILE="$TMP/lockfile.json"
echo '{"claudeCodeVersion":"2.1.252"}' > "$ISOLATED_LOCKFILE"

# Fixture: native binary behind the npm-global symlink layout.
mkdir -p "$TMP/nvm/npm-global/bin" "$TMP/nvm/npm-global/lib/real"
printf 'BINARYCONTENT-v1' > "$TMP/nvm/npm-global/lib/real/claude-native"
chmod +x "$TMP/nvm/npm-global/lib/real/claude-native"
ln -s "../lib/real/claude-native" "$TMP/nvm/npm-global/bin/claude"

want="$(sha256sum "$TMP/nvm/npm-global/lib/real/claude-native" | cut -d' ' -f1)"

# --- resolve: follows the bin/claude symlink ---
assert_eq "$(_resolve_claude_binary_file)" "$(readlink -f "$TMP/nvm/npm-global/bin/claude")" "resolve: bin/claude target"

# --- record: writes claudeBinarySha256 of the resolved binary ---
record_claude_binary_hash; rc=$?
assert_eq "$rc" "0" "record: exit 0"
assert_eq "$(jq -r '.claudeBinarySha256' "$ISOLATED_LOCKFILE")" "$want" "record: hash matches binary"
assert_eq "$(jq -r '.claudeCodeVersion' "$ISOLATED_LOCKFILE")" "2.1.252" "record: other fields intact"

# --- verify: match is quiet, exit 0 ---
WARNINGS=""
verify_claude_binary_hash; rc=$?
assert_eq "$rc" "0" "verify: match exit 0"
assert_eq "$WARNINGS" "" "verify: match is quiet"

# --- verify: tampered binary warns, still exit 0 ---
printf 'TAMPERED' > "$TMP/nvm/npm-global/lib/real/claude-native"
WARNINGS=""
verify_claude_binary_hash; rc=$?
assert_eq "$rc" "0" "verify: mismatch exit 0"
assert_true '[[ "$WARNINGS" == *mismatch* || "$WARNINGS" == *"does not match"* ]]' "verify: mismatch warns"
assert_true '[[ "$WARNINGS" == *install-from-lockfile* || "$WARNINGS" == *update* ]]' "verify: repair hint present"

# --- verify: absent recorded hash is silent ---
echo '{"claudeCodeVersion":"2.1.252"}' > "$ISOLATED_LOCKFILE"
WARNINGS=""
verify_claude_binary_hash; rc=$?
assert_eq "$rc:$WARNINGS" "0:" "verify: absent hash silent"

# --- verify: missing binary is a calm no-op ---
echo "{\"claudeBinarySha256\":\"$want\"}" > "$ISOLATED_LOCKFILE"
rm -rf "$TMP/nvm/npm-global"
WARNINGS=""
verify_claude_binary_hash; rc=$?
assert_eq "$rc" "0" "verify: missing binary exit 0"

# --- record: missing binary records nothing, exit 0 ---
echo '{"claudeCodeVersion":"2.1.252"}' > "$ISOLATED_LOCKFILE"
record_claude_binary_hash; rc=$?
assert_eq "$rc" "0" "record: missing binary exit 0"
assert_eq "$(jq -r 'has("claudeBinarySha256")' "$ISOLATED_LOCKFILE")" "false" "record: nothing recorded without binary"

# --- wiring: chokepoint records only for the claude package ---
assert_true 'grep -q "record_claude_binary_hash" "$ROOT/lib/nvm/install.sh"' "wiring: chokepoint calls record"
assert_true 'grep -B3 "record_claude_binary_hash" "$ROOT/lib/nvm/install.sh" | grep -q "@anthropic-ai/claude-code"' "wiring: guarded to claude package"
assert_true 'grep -q "verify_claude_binary_hash" "$ROOT/iclaude.sh"' "wiring: startup verify wired"

echo "binary-integrity: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
