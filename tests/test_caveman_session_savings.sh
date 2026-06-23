#!/usr/bin/env bash
# Tests for session-scoped caveman statusline savings.
# Run: bash tests/test_caveman_session_savings.sh
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.nvm-isolated/.claude-isolated/hooks"
STATUSLINE="$REPO_ROOT/.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh"
STATS="$HOOKS_DIR/caveman-stats.js"

FAILED=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILED=1; }
assert_eq() { # desc expected actual
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1"; echo "    expected: [$2]"; echo "    actual:   [$3]"; fi
}
assert_contains() { # desc haystack needle
  if [[ "$2" == *"$3"* ]]; then pass "$1"; else fail "$1"; echo "    missing [$3] in: [$2]"; fi
}
assert_not_contains() { # desc haystack needle
  if [[ "$2" != *"$3"* ]]; then pass "$1"; else fail "$1"; echo "    unexpected [$3] in: [$2]"; fi
}

# ---- Task 1: per-session composed suffix + cumulative-only global ----
t1_session_suffix() {
  echo "[t1] per-session composed suffix"
  local cc; cc="$(mktemp -d)"
  trap 'rm -rf "$cc"' RETURN

  # caveman active in 'full' mode (ratio 0.65)
  printf 'full' > "$cc/.caveman-active"
  # pre-seed history with a prior session worth 110.0M saved tokens
  printf '%s\n' '{"ts":1,"session_id":"old-session","mode":"full","model":"claude-opus-4-8","output_tokens":59230000,"est_saved_tokens":110000000,"est_saved_usd":0}' > "$cc/.caveman-history.jsonl"
  # synthetic session: 35000 output tokens, opus → est_saved = round(35000/0.35)-35000 = 65000
  printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"output_tokens":35000}}}' > "$cc/sess-A.jsonl"

  CLAUDE_CONFIG_DIR="$cc" node "$STATS" --session-file "$cc/sess-A.jsonl" >/dev/null 2>&1

  local per glob
  per="$(cat "$cc/.caveman-statusline-suffix-sess-A" 2>/dev/null)"
  glob="$(cat "$cc/.caveman-statusline-suffix" 2>/dev/null)"
  # cumulative = 110000000 + 65000 = 110065000 → humanizeTokens → "110.1M"
  assert_eq "t1 per-session = session · cumulative" "⛏ 65.0k · Σ110.1M" "$per"
  assert_eq "t1 global = cumulative-only"           "⛏ Σ110.1M"        "$glob"

  # concurrency (spec success criterion #3): a second session writes its OWN
  # per-session file; the first session's file is left untouched.
  printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"output_tokens":350000}}}' > "$cc/sess-C.jsonl"
  CLAUDE_CONFIG_DIR="$cc" node "$STATS" --session-file "$cc/sess-C.jsonl" >/dev/null 2>&1
  # sess-C est_saved = round(350000/0.35)-350000 = 650000 → "650.0k"
  # cumulative now = 110000000 + 65000 + 650000 = 110715000 → "110.7M"
  assert_eq "t1 concurrent session has its own file" "⛏ 650.0k · Σ110.7M" "$(cat "$cc/.caveman-statusline-suffix-sess-C" 2>/dev/null)"
  assert_eq "t1 first session file untouched by 2nd" "⛏ 65.0k · Σ110.1M"  "$(cat "$cc/.caveman-statusline-suffix-sess-A" 2>/dev/null)"
}

t1_session_suffix

echo
[[ $FAILED -eq 0 ]] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $FAILED
