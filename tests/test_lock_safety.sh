#!/usr/bin/env bash
# Unit + concurrency tests for S6: iclaude_with_lock helper and the locked
# wrappers around home population and store lockfile writes.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

WARNINGS=""
print_info()    { :; }
print_warning() { WARNINGS+="$*"$'\n'; }
print_error()   { :; }

source "$ROOT/lib/core/lock.sh"
source "$ROOT/lib/config/env-map.sh"
source "$ROOT/lib/config/isolated.sh"

PASS=0; FAIL=0
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }
assert_true() { if eval "$1"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$2]"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- helper: basic execution + exit-code propagation ---
iclaude_with_lock "$TMP/basic.lock" 5 true; assert_eq "$?" "0" "lock: exit 0 propagated"
iclaude_with_lock "$TMP/basic.lock" 5 bash -c 'exit 7'; assert_eq "$?" "7" "lock: exit code propagated"

# --- helper: mutual exclusion — parallel increments lose nothing ---
COUNTER="$TMP/counter"; echo 0 > "$COUNTER"
incr_loop() {
  local i
  for i in $(seq 1 50); do
    bash -c '
      source "'"$ROOT"'/lib/core/lock.sh"
      print_warning(){ :; }; print_info(){ :; }
      iclaude_with_lock "'"$TMP"'/counter.lock" 10 bash -c '\''
        v=$(cat "'"$COUNTER"'"); echo $((v+1)) > "'"$COUNTER"'"
      '\''
    '
  done
}
incr_loop & incr_loop &
wait
assert_eq "$(cat "$COUNTER")" "100" "lock: no lost increments under contention"

# --- helper: timeout is fail-soft — command still runs, warning logged ---
(
  exec 8>"$TMP/busy.lock"
  flock 8
  sleep 3 &
  HOLDER=$!
  # While held elsewhere, a 1-second-timeout caller must still run its command.
  out="$(
    source "$ROOT/lib/core/lock.sh"
    W=""
    print_warning(){ W+="x"; }; print_info(){ :; }
    iclaude_with_lock "$TMP/busy.lock" 1 printf ran
    printf ':%s' "$W"
  )"
  kill "$HOLDER" 2>/dev/null
  [[ "$out" == "ran:x" ]] && exit 0 || { echo "got '$out'"; exit 1; }
) && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL [lock: timeout fail-soft runs command + warns]"; }

# --- home population under lock: concurrent setups stay consistent ---
STORE="$TMP/store"; mkdir -p "$STORE/skills"
echo '{"hooks": {}, "model": "opus"}' > "$STORE/settings.json"
mkdir -p "$TMP/projL"; git -C "$TMP/projL" init -q
run_setup() {
  ( cd "$TMP/projL" && \
    ISOLATED_HOMES_DIR="$TMP/homes" ISOLATED_CONFIG_DIR="$STORE" \
    setup_claude_home >/dev/null 2>&1 )
}
run_setup & run_setup &
wait
rc=0
HOMEL="$TMP/homes/$(resolve_claude_home_id "$(cd "$TMP/projL" && pwd -P)")"
assert_true '[[ -f "$HOMEL/home.json" ]]' "concurrent: marker exists"
assert_eq "$(jq -r '.schema' "$HOMEL/home.json" 2>/dev/null)" "1" "concurrent: marker valid JSON"
assert_eq "$(jq -r '.model' "$HOMEL/settings.json" 2>/dev/null)" "opus" "concurrent: settings valid JSON"
assert_eq "$(readlink "$HOMEL/skills")" "$STORE/skills" "concurrent: skills link intact"

# --- store hash writes under lock: parallel writers leave one valid line ---
export ISOLATED_NVM_DIR="$TMP/nvm"; mkdir -p "$TMP/nvm"
export LOCKFILE_HASH_FILE="$TMP/nvm/.claude-isolated/.last-lockfile-hash"
export ISOLATED_LOCKFILE="$TMP/lock.json"; echo '{"nodeVersion":"22"}' > "$ISOLATED_LOCKFILE"
# update_lockfile_hash comes from lib/lockfile/save.sh — extract the wrapper
# and its unlocked body, with a stub for compute_lockfile_hash.
compute_lockfile_hash() { sha256sum "$ISOLATED_LOCKFILE" | cut -d' ' -f1; }
eval "$(awk '/^_update_lockfile_hash_unlocked\(\)/,/^}/' "$ROOT/lib/lockfile/save.sh")"
eval "$(awk '/^update_lockfile_hash\(\)/,/^}/' "$ROOT/lib/lockfile/save.sh")"
update_lockfile_hash & update_lockfile_hash & update_lockfile_hash &
wait
assert_eq "$(wc -l < "$LOCKFILE_HASH_FILE")" "1" "store: hash file single line after parallel writes"
assert_true '[[ "$(cat "$LOCKFILE_HASH_FILE")" =~ ^[0-9a-f]{64}$ ]]' "store: hash content valid"

# --- wrappers exist: public names delegate to _unlocked bodies ---
assert_true 'declare -f _save_isolated_lockfile_unlocked >/dev/null || grep -q "_save_isolated_lockfile_unlocked" "$ROOT/lib/lockfile/save.sh"' "wrapper: save_isolated_lockfile wrapped"
assert_true 'grep -q "_install_npm_package_with_lockfile_unlocked" "$ROOT/lib/nvm/install.sh"' "wrapper: npm install wrapped"

# --- no flock → degrade with warning, still runs ---
out="$(
  source "$ROOT/lib/core/lock.sh"
  W=""
  print_warning(){ W+="x"; }; print_info(){ :; }
  ICLAUDE_FLOCK_BIN=/nonexistent-flock iclaude_with_lock "$TMP/nof.lock" 1 printf ok
  printf ':%s' "$W"
)"
assert_eq "$out" "ok:x" "lock: missing flock degrades with warning"

echo "lock-safety: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
