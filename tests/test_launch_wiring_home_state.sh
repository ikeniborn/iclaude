#!/usr/bin/env bash
# Unit + integration tests for S4 launch wiring: home-scoped session-env GC
# (cleanup_stale_session_env) and two-project home disjointness.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

print_info()    { :; }
print_warning() { :; }
print_error()   { :; }

source "$ROOT/lib/config/env-map.sh"
source "$ROOT/lib/config/isolated.sh"
# cleanup_stale_session_env lives in the launcher; source only that function to
# avoid pulling the whole launch pipeline into a unit test.
eval "$(awk '/^cleanup_stale_session_env\(\)/,/^}/' "$ROOT/lib/launcher/launch.sh")"

PASS=0; FAIL=0
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }
assert_true() { if eval "$1"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$2]"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mk_stale() { mkdir -p "$1"; touch -d "60 days ago" "$1"; }

# --- GC scoped to the active CLAUDE_CONFIG_DIR (per-project home) ---
STORE="$TMP/store"; HOMEA="$TMP/homeA"
mk_stale "$STORE/session-env/dead-store-session"
mk_stale "$HOMEA/session-env/dead-home-session"
(
  export CLAUDE_CONFIG_DIR="$HOMEA" ISOLATED_CONFIG_DIR="$STORE"
  cleanup_stale_session_env >/dev/null 2>&1
)
assert_true '[[ ! -d "$HOMEA/session-env/dead-home-session" ]]' "gc: stale home session pruned"
assert_true '[[ -d "$STORE/session-env/dead-store-session" ]]' "gc: store session untouched when home active"

# --- GC in shared mode: CLAUDE_CONFIG_DIR == store, behaves as today ---
(
  export CLAUDE_CONFIG_DIR="$STORE" ISOLATED_CONFIG_DIR="$STORE"
  cleanup_stale_session_env >/dev/null 2>&1
)
assert_true '[[ ! -d "$STORE/session-env/dead-store-session" ]]' "gc: shared mode prunes store as before"

# --- GC: fresh dirs survive ---
mkdir -p "$HOMEA/session-env/live-session"; touch "$HOMEA/session-env/live-session"
(
  export CLAUDE_CONFIG_DIR="$HOMEA" ISOLATED_CONFIG_DIR="$STORE"
  cleanup_stale_session_env >/dev/null 2>&1
)
assert_true '[[ -d "$HOMEA/session-env/live-session" ]]' "gc: fresh session survives"

# --- GC: unset dirs → no-op, exit 0 ---
out="$(
  unset CLAUDE_CONFIG_DIR ISOLATED_CONFIG_DIR
  cleanup_stale_session_env >/dev/null 2>&1; echo $?
)"
assert_eq "$out" "0" "gc: unset dirs no-op"

# --- integration: two projects → disjoint homes, shared assets in both ---
FSTORE="$TMP/fullstore"
mkdir -p "$FSTORE/skills/demo" "$FSTORE/hooks"
echo '{"hooks": {}, "model": "opus"}' > "$FSTORE/settings.json"
mkdir -p "$TMP/projX" "$TMP/projY"
git -C "$TMP/projX" init -q; git -C "$TMP/projY" init -q

home_of() {
  ( cd "$1" && ISOLATED_HOMES_DIR="$TMP/homes" ISOLATED_CONFIG_DIR="$FSTORE" \
      setup_claude_home >/dev/null 2>&1 && printf '%s' "$CLAUDE_CONFIG_DIR" )
}
HX="$(home_of "$TMP/projX")"; HY="$(home_of "$TMP/projY")"
assert_true '[[ -n "$HX" && -n "$HY" && "$HX" != "$HY" ]]' "integration: disjoint homes"
assert_eq "$(jq -r '.project_root' "$HX/home.json")" "$(cd "$TMP/projX" && pwd -P)" "integration: marker X"
assert_eq "$(jq -r '.project_root' "$HY/home.json")" "$(cd "$TMP/projY" && pwd -P)" "integration: marker Y"
assert_eq "$(readlink "$HX/skills")" "$FSTORE/skills" "integration: shared skills in X"
assert_eq "$(readlink "$HY/skills")" "$FSTORE/skills" "integration: shared skills in Y"
assert_true '[[ -f "$HX/settings.json" && -f "$HY/settings.json" && ! -L "$HX/settings.json" ]]' "integration: per-home settings copies"

# Per-home state roots are disjoint: session-env in X invisible in Y.
mkdir -p "$HX/session-env/sx"
assert_true '[[ ! -e "$HY/session-env/sx" ]]' "integration: session state disjoint"

echo "launch-wiring-home-state: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
