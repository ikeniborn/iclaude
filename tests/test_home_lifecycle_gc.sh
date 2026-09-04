#!/usr/bin/env bash
# Unit tests for S7 home lifecycle: list_claude_homes, clean_claude_homes,
# clean_claude_home (lib/config/isolated.sh).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

print_info()    { :; }
print_warning() { :; }
print_error()   { :; }

source "$ROOT/lib/config/env-map.sh"
source "$ROOT/lib/config/isolated.sh"

PASS=0; FAIL=0
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }
assert_true() { if eval "$1"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$2]"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export ISOLATED_HOMES_DIR="$TMP/homes"

mk_home() { # $1=id $2=root ("" = no marker)
  mkdir -p "$ISOLATED_HOMES_DIR/$1"
  [[ -n "$2" ]] && printf '{\n  "project_root": "%s",\n  "created": "2026-09-04T00:00:00Z",\n  "schema": 1\n}\n' "$2" > "$ISOLATED_HOMES_DIR/$1/home.json"
  echo data > "$ISOLATED_HOMES_DIR/$1/file"
}

mkdir -p "$TMP/live-root"
mk_home "live-aaaaaaaaaaaa"   "$TMP/live-root"
mk_home "orphan-bbbbbbbbbbbb" "$TMP/gone-root"
mk_home "nomark-cccccccccccc" ""

# --- list: live, orphan, unknown all reported with correct marks ---
out="$(list_claude_homes)"
assert_true 'grep -q "live-aaaaaaaaaaaa" <<<"$out"' "list: live home listed"
assert_true 'grep "live-aaaaaaaaaaaa" <<<"$out" | grep -vq orphan' "list: live not marked orphan"
assert_true 'grep "orphan-bbbbbbbbbbbb" <<<"$out" | grep -q orphan' "list: orphan marked"
assert_true 'grep "nomark-cccccccccccc" <<<"$out" | grep -q unknown' "list: marker-less shown unknown"
assert_true 'grep -q "$TMP/live-root" <<<"$out"' "list: project root shown"

# --- clean-homes without confirmation: nothing removed ---
clean_claude_homes </dev/null >/dev/null 2>&1
assert_true '[[ -d "$ISOLATED_HOMES_DIR/orphan-bbbbbbbbbbbb" ]]' "clean: no confirmation removes nothing"

# --- clean-homes with ICLAUDE_ASSUME_YES: only orphans removed ---
ICLAUDE_ASSUME_YES=1 clean_claude_homes >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "clean: exit 0"
assert_true '[[ ! -d "$ISOLATED_HOMES_DIR/orphan-bbbbbbbbbbbb" ]]' "clean: orphan removed"
assert_true '[[ -d "$ISOLATED_HOMES_DIR/live-aaaaaaaaaaaa" ]]' "clean: live untouched"
assert_true '[[ -d "$ISOLATED_HOMES_DIR/nomark-cccccccccccc" ]]' "clean: unknown never touched"

# --- clean-home <id>: removes exactly the named home ---
ICLAUDE_ASSUME_YES=1 clean_claude_home "nomark-cccccccccccc" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "clean-home: exit 0"
assert_true '[[ ! -d "$ISOLATED_HOMES_DIR/nomark-cccccccccccc" ]]' "clean-home: named home removed"
assert_true '[[ -d "$ISOLATED_HOMES_DIR/live-aaaaaaaaaaaa" ]]' "clean-home: others untouched"

# --- clean-home unknown id: error, nothing removed ---
ICLAUDE_ASSUME_YES=1 clean_claude_home "no-such-home" >/dev/null 2>&1; rc=$?
assert_true '[[ "$rc" != "0" ]]' "clean-home: unknown id errors"
assert_true '[[ -d "$ISOLATED_HOMES_DIR/live-aaaaaaaaaaaa" ]]' "clean-home: unknown id removes nothing"

# --- empty homes dir: list and clean are calm no-ops ---
rm -rf "$ISOLATED_HOMES_DIR"
list_claude_homes >/dev/null 2>&1; assert_eq "$?" "0" "list: missing dir no-op"
ICLAUDE_ASSUME_YES=1 clean_claude_homes >/dev/null 2>&1; assert_eq "$?" "0" "clean: missing dir no-op"

echo "home-lifecycle-gc: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
