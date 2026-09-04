#!/usr/bin/env bash
# Tests for caveman-paths.js — path builders, migration, prune.
# Run: bash tests/test_caveman_paths.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATHS="$REPO_ROOT/.claude-isolated/hooks/caveman-paths.js"

FAILED=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILED=1; }
assert_eq() { if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1"; echo "    expected: [$2]"; echo "    actual:   [$3]"; fi; }

# ---- path builders ----
t_paths() {
  echo "[paths] builders return .caveman/ paths"
  local out
  out="$(node -e '
    const p = require(process.argv[1]);
    const d = "/tmp/cc";
    console.log(p.cavemanDir(d));
    console.log(p.activeFlag(d));
    console.log(p.history(d));
    console.log(p.baseSuffix(d));
    console.log(p.sessionSuffix(d, "abc"));
    console.log(String(p.MAX_AGE_MS));
    console.log(p.SESSION_SUFFIX_PREFIX);
  ' "$PATHS")"
  assert_eq "cavemanDir"   "/tmp/cc/.caveman"                 "$(sed -n 1p <<<"$out")"
  assert_eq "activeFlag"   "/tmp/cc/.caveman/active"          "$(sed -n 2p <<<"$out")"
  assert_eq "history"      "/tmp/cc/.caveman/history.jsonl"   "$(sed -n 3p <<<"$out")"
  assert_eq "baseSuffix"   "/tmp/cc/.caveman/statusline-suffix" "$(sed -n 4p <<<"$out")"
  assert_eq "sessionSuffix" "/tmp/cc/.caveman/suffix-abc"     "$(sed -n 5p <<<"$out")"
  assert_eq "MAX_AGE_MS 5d" "432000000"                       "$(sed -n 6p <<<"$out")"
  assert_eq "prefix"       "suffix-"                          "$(sed -n 7p <<<"$out")"
  # cavemanDir is pure — must NOT create the dir as a side effect
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  node -e 'require(process.argv[1]).cavemanDir(process.argv[2])' "$PATHS" "$cc"
  [[ -d "$cc/.caveman" ]] && fail "cavemanDir is pure (no mkdir)" || pass "cavemanDir is pure (no mkdir)"
}
t_paths

# ---- migrateLegacy ----
t_migrate() {
  echo "[migrate] legacy root artifacts move into .caveman/"
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  printf 'LIFETIME' > "$cc/.caveman-history.jsonl"
  printf 'BASE'     > "$cc/.caveman-statusline-suffix"
  printf 'full'     > "$cc/.caveman-active"
  printf 'stale1'   > "$cc/.caveman-statusline-suffix-old1"
  printf 'stale2'   > "$cc/.caveman-statusline-suffix-old2"

  node -e 'require(process.argv[1]).migrateLegacy(process.argv[2])' "$PATHS" "$cc"

  assert_eq "history moved (content preserved)" "LIFETIME" "$(cat "$cc/.caveman/history.jsonl" 2>/dev/null)"
  assert_eq "base suffix moved"                 "BASE"     "$(cat "$cc/.caveman/statusline-suffix" 2>/dev/null)"
  assert_eq "active moved"                      "full"     "$(cat "$cc/.caveman/active" 2>/dev/null)"
  [[ -e "$cc/.caveman-history.jsonl" ]]          && fail "legacy history removed"     || pass "legacy history removed"
  [[ -e "$cc/.caveman-statusline-suffix" ]]      && fail "legacy base removed"        || pass "legacy base removed"
  [[ -e "$cc/.caveman-active" ]]                 && fail "legacy active removed"      || pass "legacy active removed"
  [[ -e "$cc/.caveman-statusline-suffix-old1" ]] && fail "legacy per-session1 removed" || pass "legacy per-session1 removed"
  [[ -e "$cc/.caveman-statusline-suffix-old2" ]] && fail "legacy per-session2 removed" || pass "legacy per-session2 removed"

  # idempotent: a second run is a no-op and preserves the new files
  node -e 'require(process.argv[1]).migrateLegacy(process.argv[2])' "$PATHS" "$cc"
  assert_eq "history intact after 2nd run" "LIFETIME" "$(cat "$cc/.caveman/history.jsonl" 2>/dev/null)"

  # dest already exists → legacy dropped, dest NOT overwritten
  printf 'STALE' > "$cc/.caveman-history.jsonl"
  node -e 'require(process.argv[1]).migrateLegacy(process.argv[2])' "$PATHS" "$cc"
  assert_eq "existing dest not overwritten" "LIFETIME" "$(cat "$cc/.caveman/history.jsonl" 2>/dev/null)"
  [[ -e "$cc/.caveman-history.jsonl" ]] && fail "stale legacy dropped when dest exists" || pass "stale legacy dropped when dest exists"
}
t_migrate

# ---- pruneSessionSuffixes ----
t_prune() {
  echo "[prune] removes >5d, keeps <5d, keeps base"
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  mkdir -p "$cc/.caveman"
  printf 'x' > "$cc/.caveman/suffix-old";  touch -d '6 days ago' "$cc/.caveman/suffix-old"
  printf 'x' > "$cc/.caveman/suffix-new";  touch -d '4 days ago' "$cc/.caveman/suffix-new"
  printf 'x' > "$cc/.caveman/statusline-suffix"; touch -d '9 days ago' "$cc/.caveman/statusline-suffix"

  node -e 'require(process.argv[1]).pruneSessionSuffixes(process.argv[2])' "$PATHS" "$cc"

  [[ -e "$cc/.caveman/suffix-old" ]]        && fail "6d suffix pruned"      || pass "6d suffix pruned"
  [[ -e "$cc/.caveman/suffix-new" ]]        && pass "4d suffix kept"        || fail "4d suffix kept"
  [[ -e "$cc/.caveman/statusline-suffix" ]] && pass "base suffix kept"      || fail "base suffix kept"
}
t_prune

echo
[[ $FAILED -eq 0 ]] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $FAILED
