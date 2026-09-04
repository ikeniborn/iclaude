#!/usr/bin/env bash
# Unit tests for S5: first-launch migration (migrate_home_from_store) and the
# per-project default flip in setup_isolated_config.
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

# Project and store fixtures.
mkdir -p "$TMP/projM"; git -C "$TMP/projM" init -q
PROJ="$(cd "$TMP/projM" && pwd -P)"
MANGLED="$(printf '%s' "$PROJ" | sed -E 's/[^a-zA-Z0-9]/-/g')"

STORE="$TMP/store"; mkdir -p "$STORE"
cat > "$STORE/.claude.json" <<EOF
{
  "hasCompletedOnboarding": true,
  "firstStartTime": "2026-01-01",
  "projects": {
    "$PROJ": {"allowedTools": ["Bash"], "history": []},
    "/some/other/project": {"allowedTools": []}
  },
  "githubRepoPaths": {
    "me/mine": ["$PROJ", "$PROJ/.git/worktrees/wt"],
    "me/other": ["/some/other/project"],
    "me/lookalike": ["${PROJ}-dev-branch"]
  }
}
EOF
mkdir -p "$STORE/projects/$MANGLED" "$STORE/projects/-some-other-project"
echo '{"line":1}' > "$STORE/projects/$MANGLED/session-1.jsonl"
echo '{"other":1}' > "$STORE/projects/-some-other-project/s.jsonl"
printf '%s\n%s\n' \
  "{\"display\":\"mine\",\"project\":\"$PROJ\"}" \
  '{"display":"other","project":"/some/other/project"}' > "$STORE/history.jsonl"

STORE_SNAPSHOT="$(find "$STORE" -type f -exec sha256sum {} \; | sort | sha256sum)"

HOME_DIR="$TMP/home"; mkdir -p "$HOME_DIR"

# --- migration: .claude.json reduced to this project's entry ---
( cd "$TMP/projM" && migrate_home_from_store "$HOME_DIR" "$STORE" "$PROJ" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "0" "migrate: exit 0"
assert_true '[[ -f "$HOME_DIR/.claude.json" ]]' "migrate: .claude.json created"
assert_eq "$(jq -r '.hasCompletedOnboarding' "$HOME_DIR/.claude.json")" "true" "migrate: global keys carried"
assert_eq "$(jq -r '.projects | keys | length' "$HOME_DIR/.claude.json")" "1" "migrate: only own project entry"
assert_eq "$(jq -r ".projects[\"$PROJ\"].allowedTools[0]" "$HOME_DIR/.claude.json")" "Bash" "migrate: own entry content"

# --- migration: githubRepoPaths reduced to repositories under this root ---
assert_eq "$(jq -r '.githubRepoPaths | keys | join(",")' "$HOME_DIR/.claude.json")" "me/mine" "migrate: only own repository kept"
assert_eq "$(jq -r '.githubRepoPaths["me/mine"] | length' "$HOME_DIR/.claude.json")" "2" "migrate: own repository keeps all its checkouts"

# --- migration: transcripts copied, foreign ones not ---
assert_true '[[ -f "$HOME_DIR/projects/$MANGLED/session-1.jsonl" ]]' "migrate: own transcripts copied"
assert_true '[[ ! -e "$HOME_DIR/projects/-some-other-project" ]]' "migrate: foreign transcripts not copied"

# --- migration: history filtered by project ---
assert_eq "$(wc -l < "$HOME_DIR/history.jsonl")" "1" "migrate: history filtered"
assert_eq "$(jq -r '.display' "$HOME_DIR/history.jsonl")" "mine" "migrate: own history entry"

# --- migration: idempotent — existing .claude.json blocks re-migration ---
echo '{"custom": true}' > "$HOME_DIR/.claude.json"
( cd "$TMP/projM" && migrate_home_from_store "$HOME_DIR" "$STORE" "$PROJ" >/dev/null 2>&1 )
assert_eq "$(jq -r '.custom' "$HOME_DIR/.claude.json")" "true" "migrate: existing state never overwritten"

# --- migration: store byte-identical ---
assert_eq "$(find "$STORE" -type f -exec sha256sum {} \; | sort | sha256sum)" "$STORE_SNAPSHOT" "migrate: store unmutated"

# --- migration: store without .claude.json → fresh home, exit 0 ---
EMPTY="$TMP/empty-store"; mkdir -p "$EMPTY"
H2="$TMP/home2"; mkdir -p "$H2"
( cd "$TMP/projM" && migrate_home_from_store "$H2" "$EMPTY" "$PROJ" >/dev/null 2>&1 ); rc=$?
assert_eq "$rc" "0" "migrate: empty store exit 0"
assert_true '[[ ! -e "$H2/.claude.json" ]]' "migrate: nothing invented from empty store"

# --- migration: a store without githubRepoPaths does not gain the key ---
NOREPO="$TMP/norepo-store"; mkdir -p "$NOREPO"
echo '{"hasCompletedOnboarding": true}' > "$NOREPO/.claude.json"
H3="$TMP/home3"; mkdir -p "$H3"
( cd "$TMP/projM" && migrate_home_from_store "$H3" "$NOREPO" "$PROJ" >/dev/null 2>&1 )
assert_eq "$(jq -r 'has("githubRepoPaths")' "$H3/.claude.json")" "false" "migrate: absent githubRepoPaths stays absent"

# --- default flip: unset mode now resolves per-project ---
out="$(
  cd "$TMP/projM" || exit 1
  unset ICLAUDE_HOME_MODE
  ISOLATED_NVM_DIR="$TMP/nvm" ISOLATED_HOMES_DIR="$TMP/homes" ISOLATED_CONFIG_DIR="$STORE" \
    setup_isolated_config >/dev/null 2>&1 || exit 1
  printf '%s' "$CLAUDE_CONFIG_DIR"
)"
assert_true '[[ "$out" == "$TMP/homes/"* ]]' "flip: unset mode defaults to per-project"

# --- default flip: migration ran on the way ---
assert_eq "$(jq -r '.projects | keys | length' "$out/.claude.json" 2>/dev/null)" "1" "flip: home migrated on first default launch"

# --- escape hatch: shared restores old behavior exactly ---
# Shared mode points at the store named by ISOLATED_CONFIG_DIR; it no longer
# derives a path of its own under the nvm tree.
out="$(
  export ICLAUDE_HOME_MODE=shared
  ISOLATED_NVM_DIR="$TMP/nvm" ISOLATED_CONFIG_DIR="$STORE" \
    ISOLATED_HOMES_DIR="$TMP/homes" setup_isolated_config >/dev/null 2>&1 || exit 1
  printf '%s' "$CLAUDE_CONFIG_DIR"
)"
assert_eq "$out" "$STORE" "flip: shared escape hatch works"

echo "home-migration: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
