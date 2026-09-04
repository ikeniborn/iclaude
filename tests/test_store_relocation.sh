#!/usr/bin/env bash
# Unit tests for S3: migrate_isolated_store — the one-way relocation of a
# pre-existing shared store out of the vendored nvm tree into the repository root.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

INFOS=""; ERRORS=""
print_info()    { INFOS+="$*"$'\n'; }
print_warning() { :; }
print_error()   { ERRORS+="$*"$'\n'; }
print_success() { :; }

source "$ROOT/lib/config/isolated.sh"

PASS=0; FAIL=0
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }
assert_true() { if eval "$1"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$2]"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Build a legacy layout: a store with recognisable content inside the nvm tree.
new_case() {
  local case_dir="$TMP/$1"
  rm -rf "$case_dir"
  mkdir -p "$case_dir/.nvm-isolated/.claude-isolated/plugins"
  echo 'SECRET-TOKEN' > "$case_dir/.nvm-isolated/.claude-isolated/.credentials.json"
  echo '{"model":"opus"}' > "$case_dir/.nvm-isolated/.claude-isolated/settings.json"
  printf '%s' "$case_dir"
}

# --- happy path: legacy store present, target absent → renamed ---
c="$(new_case relocate)"
ISOLATED_NVM_DIR="$c/.nvm-isolated" ISOLATED_CONFIG_DIR="$c/.claude-isolated" migrate_isolated_store
assert_eq "$?" "0" "relocate: returns success"
assert_true '[[ ! -e "$c/.nvm-isolated/.claude-isolated" ]]' "relocate: legacy path is gone"
assert_true '[[ -d "$c/.claude-isolated" ]]' "relocate: store exists at the new path"
assert_eq "$(cat "$c/.claude-isolated/.credentials.json")" "SECRET-TOKEN" "relocate: credentials preserved"
assert_eq "$(cat "$c/.claude-isolated/settings.json")" '{"model":"opus"}' "relocate: settings preserved"
assert_true '[[ -d "$c/.claude-isolated/plugins" ]]' "relocate: subdirectories preserved"
assert_true '[[ -d "$c/.nvm-isolated" ]]' "relocate: the nvm tree itself is untouched"

# --- idempotent: a second call has nothing to do ---
ISOLATED_NVM_DIR="$c/.nvm-isolated" ISOLATED_CONFIG_DIR="$c/.claude-isolated" migrate_isolated_store
assert_eq "$?" "0" "idempotent: second call succeeds"
assert_eq "$(cat "$c/.claude-isolated/.credentials.json")" "SECRET-TOKEN" "idempotent: store untouched"

# --- the point of the relocation: --isolated-clean deletes ISOLATED_NVM_DIR, and the
#     store is no longer inside it. cleanup_isolated_nvm prompts, so the test performs
#     the one destructive step that function performs.
rm -rf "$c/.nvm-isolated"
assert_true '[[ ! -e "$c/.nvm-isolated" ]]' "nvm removal: the nvm tree is gone"
assert_true '[[ -d "$c/.claude-isolated" ]]' "nvm removal: the store survives"
assert_eq "$(cat "$c/.claude-isolated/.credentials.json")" "SECRET-TOKEN" "nvm removal: the login survives"
assert_eq "$(cat "$c/.claude-isolated/settings.json")" '{"model":"opus"}' "nvm removal: settings survive"

# --- nothing to relocate: no legacy store ---
c="$(new_case fresh)"
rm -rf "$c/.nvm-isolated/.claude-isolated"
ISOLATED_NVM_DIR="$c/.nvm-isolated" ISOLATED_CONFIG_DIR="$c/.claude-isolated" migrate_isolated_store
assert_eq "$?" "0" "fresh install: no-op succeeds"
assert_true '[[ ! -e "$c/.claude-isolated" ]]' "fresh install: creates nothing"

# --- ambiguous: both stores exist → refuse, move nothing ---
c="$(new_case ambiguous)"
mkdir -p "$c/.claude-isolated"
echo 'NEWER-TOKEN' > "$c/.claude-isolated/.credentials.json"
ERRORS=""
ISOLATED_NVM_DIR="$c/.nvm-isolated" ISOLATED_CONFIG_DIR="$c/.claude-isolated" migrate_isolated_store
assert_eq "$?" "1" "ambiguous: refuses"
assert_eq "$(cat "$c/.nvm-isolated/.claude-isolated/.credentials.json")" "SECRET-TOKEN" "ambiguous: legacy store intact"
assert_eq "$(cat "$c/.claude-isolated/.credentials.json")" "NEWER-TOKEN" "ambiguous: new store intact"
assert_true '[[ "$ERRORS" == *"Two shared stores present"* ]]' "ambiguous: names both stores in the error"

# --- cross-filesystem: refuse rather than turn the rename into a copy ---
# stat() is shadowed so the two paths report different device ids.
c="$(new_case crossfs)"
stat() { if [[ "$3" == *".claude-isolated" ]]; then echo 111; else echo 222; fi; }
ERRORS=""
ISOLATED_NVM_DIR="$c/.nvm-isolated" ISOLATED_CONFIG_DIR="$c/.claude-isolated" migrate_isolated_store
assert_eq "$?" "1" "cross-fs: refuses"
unset -f stat
assert_true '[[ -d "$c/.nvm-isolated/.claude-isolated" ]]' "cross-fs: legacy store left in place"
assert_true '[[ ! -e "$c/.claude-isolated" ]]' "cross-fs: nothing created at the new path"
assert_true '[[ "$ERRORS" == *"another filesystem"* ]]' "cross-fs: explains why it refused"

# --- a plain file at the target is ambiguous too, not something to overwrite ---
c="$(new_case filetarget)"
echo 'not a store' > "$c/.claude-isolated"
ISOLATED_NVM_DIR="$c/.nvm-isolated" ISOLATED_CONFIG_DIR="$c/.claude-isolated" migrate_isolated_store
assert_eq "$?" "1" "file target: refuses"
assert_eq "$(cat "$c/.claude-isolated")" "not a store" "file target: file left untouched"
assert_true '[[ -d "$c/.nvm-isolated/.claude-isolated" ]]' "file target: legacy store left in place"

echo "store-relocation: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
