#!/usr/bin/env bash
# Unit tests for the per-home settings.json managed region (lib/config/isolated.sh, S3):
# seed_home_settings (copy-once) + sync_home_settings (managed-keys mirror).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WARNINGS=""
print_info()    { :; }
print_warning() { WARNINGS+="$*"$'\n'; }
print_error()   { :; }

source "$ROOT/lib/config/env-map.sh"
source "$ROOT/lib/config/isolated.sh"

PASS=0; FAIL=0
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }
assert_true() { if eval "$1"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$2]"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

STORE="$TMP/store"; mkdir -p "$STORE"
cat > "$STORE/settings.json" <<'EOF'
{
  "model": "opus",
  "language": "english",
  "permissions": {"allow": ["Bash(ls:*)"]},
  "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "$CLAUDE_CONFIG_DIR/hooks/stop.py"}]}]},
  "enabledPlugins": {"loen@iclaude": true},
  "statusLine": {"type": "command", "command": "$CLAUDE_CONFIG_DIR/scripts/sl.sh"},
  "extraKnownMarketplaces": {"iclaude": {"source": {"source": "directory", "path": "/repo"}}}
}
EOF

HOME_DIR="$TMP/home"; mkdir -p "$HOME_DIR"
S="$HOME_DIR/settings.json"

# --- seed: copy-once, mode 600 ---
seed_home_settings "$HOME_DIR" "$STORE"; rc=$?
assert_eq "$rc" "0" "seed: exit 0"
assert_true '[[ -f "$S" ]]' "seed: file created"
assert_eq "$(stat -c %a "$S")" "600" "seed: mode 600"
assert_eq "$(jq -r '.model' "$S")" "opus" "seed: content copied"

# --- seed: never re-seeds an existing file ---
jq '.model = "sonnet"' "$S" > "$S.tmp" && mv "$S.tmp" "$S"
seed_home_settings "$HOME_DIR" "$STORE"
assert_eq "$(jq -r '.model' "$S")" "sonnet" "seed: existing file untouched"

# --- sync: user keys survive byte-for-byte, managed keys mirrored ---
jq '.permissions.allow = ["Bash(rm:*)"] | .hooks = {} | del(.enabledPlugins)' "$S" > "$S.tmp" && mv "$S.tmp" "$S"
sync_home_settings "$HOME_DIR" "$STORE"; rc=$?
assert_eq "$rc" "0" "sync: exit 0"
assert_eq "$(jq -r '.model' "$S")" "sonnet" "sync: user key model preserved"
assert_eq "$(jq -cr '.permissions.allow' "$S")" '["Bash(rm:*)"]' "sync: user key permissions preserved"
assert_eq "$(jq -r '.hooks.Stop[0].hooks[0].command' "$S")" '$CLAUDE_CONFIG_DIR/hooks/stop.py' "sync: tampered hooks restored"
assert_eq "$(jq -r '.enabledPlugins["loen@iclaude"]' "$S")" "true" "sync: deleted managed key restored"

# --- sync: managed key removed from store disappears from home ---
jq 'del(.statusLine)' "$STORE/settings.json" > "$STORE/s.tmp" && mv "$STORE/s.tmp" "$STORE/settings.json"
sync_home_settings "$HOME_DIR" "$STORE"
assert_eq "$(jq -r 'has("statusLine")' "$S")" "false" "sync: store-removed key removed from home"

# --- sync: idempotent no-op (no rewrite when equal) ---
before_inode="$(stat -c %i "$S")"
sync_home_settings "$HOME_DIR" "$STORE"
assert_eq "$(stat -c %i "$S")" "$before_inode" "sync: unchanged content not rewritten"

# --- sync: store never mutated ---
before="$(sha256sum "$STORE/settings.json")"
jq '.hooks = {"broken": true}' "$S" > "$S.tmp" && mv "$S.tmp" "$S"
sync_home_settings "$HOME_DIR" "$STORE"
assert_eq "$(sha256sum "$STORE/settings.json")" "$before" "sync: store unchanged"

# --- graceful degradation: no store settings.json ---
EMPTY_STORE="$TMP/empty-store"; mkdir -p "$EMPTY_STORE"
H2="$TMP/home2"; mkdir -p "$H2"
WARNINGS=""
seed_home_settings "$H2" "$EMPTY_STORE"; rc1=$?
sync_home_settings "$H2" "$EMPTY_STORE"; rc2=$?
assert_eq "$rc1:$rc2" "0:0" "degrade: store-less seed+sync exit 0"
assert_true '[[ ! -e "$H2/settings.json" ]]' "degrade: nothing created without store file"

# --- graceful degradation: no jq ---
WARNINGS=""
out="$(
  PATH="$TMP/nobin"
  sync_home_settings "$HOME_DIR" "$STORE" >/dev/null 2>&1; echo "$?"
)"
assert_eq "$out" "0" "degrade: jq-less sync exits 0"

# --- integration: setup_claude_home seeds and syncs ---
mkdir -p "$TMP/repoC"; git -C "$TMP/repoC" init -q
out="$(
  cd "$TMP/repoC" || exit 1
  ISOLATED_HOMES_DIR="$TMP/homes" ISOLATED_CONFIG_DIR="$STORE" setup_claude_home >/dev/null 2>&1 || exit 1
  jq -r '.enabledPlugins["loen@iclaude"]' "$CLAUDE_CONFIG_DIR/settings.json"
)"
assert_eq "$out" "true" "integration: setup_claude_home seeds settings"

# --- shared mode: no settings manipulation in shared dir ---
mkdir -p "$TMP/nvm/.claude-isolated"
out="$(
  unset ICLAUDE_HOME_MODE
  ISOLATED_NVM_DIR="$TMP/nvm" setup_isolated_config >/dev/null 2>&1 || exit 1
  [[ -e "$TMP/nvm/.claude-isolated/settings.json" ]] && echo present || echo absent
)"
assert_eq "$out" "absent" "shared: no settings created in shared dir"

echo "settings-managed-region: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
