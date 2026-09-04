#!/usr/bin/env bash
# Tests the SessionEnd cleanup hook: deletes this session's suffix file + prunes.
# Run: bash tests/test_caveman_cleanup.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLEANUP="$REPO_ROOT/.claude-isolated/hooks/caveman-cleanup.js"

FAILED=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILED=1; }

t_cleanup() {
  echo "[cleanup] SessionEnd deletes own suffix, prunes stale, keeps others"
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  mkdir -p "$cc/.caveman"
  local sid="sess-END"
  printf 'x' > "$cc/.caveman/suffix-$sid"           # this session's file → deleted
  printf 'x' > "$cc/.caveman/suffix-other"          # another live session → kept
  touch -d '4 days ago' "$cc/.caveman/suffix-other"
  printf 'x' > "$cc/.caveman/suffix-zombie"         # stale → pruned
  touch -d '6 days ago' "$cc/.caveman/suffix-zombie"

  printf '%s' "{\"transcript_path\":\"$cc/projects/foo/$sid.jsonl\"}" \
    | CLAUDE_CONFIG_DIR="$cc" node "$CLEANUP" >/dev/null 2>&1

  [[ -e "$cc/.caveman/suffix-$sid" ]]    && fail "own suffix deleted"          || pass "own suffix deleted"
  [[ -e "$cc/.caveman/suffix-zombie" ]]  && fail "stale (6d) suffix pruned"    || pass "stale (6d) suffix pruned"
  [[ -e "$cc/.caveman/suffix-other" ]]   && pass "recent other session kept"   || fail "recent other session kept"
}
t_cleanup

# Missing transcript_path must not throw and must not delete anything wrongly.
t_no_transcript() {
  echo "[cleanup] no transcript_path → no crash, prune still runs"
  local cc; cc="$(mktemp -d)"; trap 'rm -rf "$cc"' RETURN
  mkdir -p "$cc/.caveman"
  printf 'x' > "$cc/.caveman/suffix-keep"; touch -d '1 day ago' "$cc/.caveman/suffix-keep"
  printf '%s' '{}' | CLAUDE_CONFIG_DIR="$cc" node "$CLEANUP" >/dev/null 2>&1
  local rc=$?
  [[ $rc -eq 0 ]] && pass "exit 0 on empty input" || fail "exit 0 on empty input"
  [[ -e "$cc/.caveman/suffix-keep" ]] && pass "recent file kept" || fail "recent file kept"
}
t_no_transcript

echo
[[ $FAILED -eq 0 ]] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $FAILED
