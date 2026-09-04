#!/usr/bin/env bash
# Tests that activation hooks read/write the active flag in .caveman/ and that
# SessionStart migrates legacy root artifacts.
# Run: bash tests/test_caveman_activation_paths.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.claude-isolated/hooks"

FAILED=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILED=1; }
assert_eq() { if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1"; echo "    expected: [$2]"; echo "    actual:   [$3]"; fi; }

# ---- activate writes .caveman/active and migrates legacy ----
t_activate() {
  echo "[activate] SessionStart writes .caveman/active + migrates legacy"
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  # legacy artifacts present in root before upgrade
  printf 'LIFE' > "$cc/.caveman-history.jsonl"
  printf 'x'    > "$cc/.caveman-statusline-suffix-old"

  CLAUDE_CONFIG_DIR="$cc" CAVEMAN_DEFAULT_MODE=full node "$HOOKS_DIR/caveman-activate.js" >/dev/null 2>&1

  assert_eq "active flag written in .caveman/" "full" "$(cat "$cc/.caveman/active" 2>/dev/null)"
  assert_eq "legacy history migrated"          "LIFE" "$(cat "$cc/.caveman/history.jsonl" 2>/dev/null)"
  [[ -e "$cc/.caveman-history.jsonl" ]]          && fail "legacy history removed from root" || pass "legacy history removed from root"
  [[ -e "$cc/.caveman-statusline-suffix-old" ]]  && fail "legacy per-session removed"        || pass "legacy per-session removed"
  [[ -e "$cc/.caveman-active" ]]                 && fail "no legacy active in root"          || pass "no legacy active in root"
}
t_activate

# ---- off-mode SessionStart creates no .caveman/ dir ----
t_activate_off() {
  echo "[activate] off-mode SessionStart creates no .caveman/ dir"
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  # legacy flag present from before the .caveman/ migration existed
  printf 'full' > "$cc/.caveman-active"

  CLAUDE_CONFIG_DIR="$cc" CAVEMAN_DEFAULT_MODE=off node "$HOOKS_DIR/caveman-activate.js" >/dev/null 2>&1

  [[ -d "$cc/.caveman" ]]        && fail "off-mode creates no .caveman/ dir"   || pass "off-mode creates no .caveman/ dir"
  [[ -e "$cc/.caveman-active" ]] && fail "off-mode removes legacy root flag"   || pass "off-mode removes legacy root flag"
}
t_activate_off

# ---- mode-tracker reads .caveman/active for reinforcement ----
t_tracker() {
  echo "[tracker] UserPromptSubmit reinforcement reads .caveman/active"
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  mkdir -p "$cc/.caveman"
  printf 'full' > "$cc/.caveman/active"

  local out
  out="$(printf '%s' '{"prompt":"hello"}' | CLAUDE_CONFIG_DIR="$cc" node "$HOOKS_DIR/caveman-mode-tracker.js" 2>/dev/null)"
  [[ "$out" == *"CAVEMAN MODE ACTIVE"* ]] && pass "tracker emits reinforcement from .caveman/active" || fail "tracker emits reinforcement from .caveman/active"
}
t_tracker

# ---- mode-tracker /caveman off deletes .caveman/active ----
t_tracker_off() {
  echo "[tracker] /caveman off removes .caveman/active"
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  mkdir -p "$cc/.caveman"
  printf 'full' > "$cc/.caveman/active"

  printf '%s' '{"prompt":"/caveman off"}' | CLAUDE_CONFIG_DIR="$cc" node "$HOOKS_DIR/caveman-mode-tracker.js" >/dev/null 2>&1
  [[ -e "$cc/.caveman/active" ]] && fail "active flag removed on /caveman off" || pass "active flag removed on /caveman off"
}
t_tracker_off

echo
[[ $FAILED -eq 0 ]] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $FAILED
