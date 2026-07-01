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
  echo "[t1] per-session composed suffix (in .caveman/)"
  local cc; cc="$(mktemp -d)"
  trap 'rm -rf "$cc"' RETURN
  mkdir -p "$cc/.caveman"

  # caveman active in 'full' mode (ratio 0.65)
  printf 'full' > "$cc/.caveman/active"
  # pre-seed history with a prior session worth 110.0M saved tokens
  printf '%s\n' '{"ts":1,"session_id":"old-session","mode":"full","model":"claude-opus-4-8","output_tokens":59230000,"est_saved_tokens":110000000,"est_saved_usd":0}' > "$cc/.caveman/history.jsonl"
  # synthetic session: 35000 output tokens, opus → est_saved = round(35000/0.35)-35000 = 65000
  printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"output_tokens":35000}}}' > "$cc/sess-A.jsonl"

  CLAUDE_CONFIG_DIR="$cc" node "$STATS" --session-file "$cc/sess-A.jsonl" >/dev/null 2>&1

  local per glob
  per="$(cat "$cc/.caveman/suffix-sess-A" 2>/dev/null)"
  glob="$(cat "$cc/.caveman/statusline-suffix" 2>/dev/null)"
  # cumulative = 110000000 + 65000 = 110065000 → humanizeTokens → "110.1M"
  assert_eq "t1 per-session = session · cumulative" "⛏ 65.0k · Σ110.1M" "$per"
  assert_eq "t1 global = cumulative-only"           "⛏ Σ110.1M"        "$glob"

  # root stays clean — no legacy files leak into the config root
  [[ -e "$cc/.caveman-statusline-suffix-sess-A" ]] && fail "t1 no legacy file in root" || pass "t1 no legacy file in root"
  [[ -e "$cc/.caveman-history.jsonl" ]]            && fail "t1 history not in root"    || pass "t1 history not in root"

  # concurrency: a second session writes its OWN per-session file; first untouched.
  printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"output_tokens":350000}}}' > "$cc/sess-C.jsonl"
  CLAUDE_CONFIG_DIR="$cc" node "$STATS" --session-file "$cc/sess-C.jsonl" >/dev/null 2>&1
  # sess-C est_saved = round(350000/0.35)-350000 = 650000 → "650.0k"
  # cumulative now = 110000000 + 65000 + 650000 = 110715000 → "110.7M"
  assert_eq "t1 concurrent session has its own file" "⛏ 650.0k · Σ110.7M" "$(cat "$cc/.caveman/suffix-sess-C" 2>/dev/null)"
  assert_eq "t1 first session file untouched by 2nd" "⛏ 65.0k · Σ110.1M"  "$(cat "$cc/.caveman/suffix-sess-A" 2>/dev/null)"
}

t1_session_suffix

# ---- Task 2: prune per-session suffix files older than 7 days ----
t2_prune() {
  echo "[t2] prune stale per-session suffix files (>5 days)"
  local cc; cc="$(mktemp -d)"
  trap 'rm -rf "$cc"' RETURN
  mkdir -p "$cc/.caveman"

  printf 'full' > "$cc/.caveman/active"
  printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-4-8","usage":{"output_tokens":35000}}}' > "$cc/sess-B.jsonl"

  # a stale per-session file (6 days old, > 5) that must be pruned
  printf '⛏ 1k · Σ1k' > "$cc/.caveman/suffix-zombie"
  touch -d '6 days ago' "$cc/.caveman/suffix-zombie"
  # a recent per-session file (4 days old, < 5) that must SURVIVE
  printf '⛏ 2k · Σ2k' > "$cc/.caveman/suffix-fresh"
  touch -d '4 days ago' "$cc/.caveman/suffix-fresh"
  # the base file is old but must SURVIVE (no 'suffix-' prefix match)
  printf '⛏ Σ1k' > "$cc/.caveman/statusline-suffix"
  touch -d '9 days ago' "$cc/.caveman/statusline-suffix"

  CLAUDE_CONFIG_DIR="$cc" node "$STATS" --session-file "$cc/sess-B.jsonl" >/dev/null 2>&1

  [[ -e "$cc/.caveman/suffix-zombie" ]]        && fail "t2 stale (6d) per-session file removed" || pass "t2 stale (6d) per-session file removed"
  [[ -e "$cc/.caveman/suffix-fresh" ]]         && pass "t2 recent (4d) per-session file kept"   || fail "t2 recent (4d) per-session file kept"
  [[ -e "$cc/.caveman/statusline-suffix" ]]    && pass "t2 base file survives (not matched)"    || fail "t2 base file survives (not matched)"
  [[ -e "$cc/.caveman/suffix-sess-B" ]]        && pass "t2 current session file present"        || fail "t2 current session file present"
}

t2_prune

# ---- Task 3: statusline per-session-first, global fallback ----
t3_statusline_precedence() {
  echo "[t3] statusline suffix precedence"
  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/scripts"
  cp "$STATUSLINE" "$tmp/scripts/claude-statusline.sh"
  : > "$tmp/settings.json"          # makes the script detect CLAUDE_CONFIG_DIR=$tmp
  printf 'full' > "$tmp/.caveman-active"

  local sid="sid-c3"
  # stdin: native Anthropic session, non-zero tokens (avoids the new-session suppression)
  local stdin_json
  stdin_json='{"session_id":"'"$sid"'","model":{"display_name":"Opus 4.8"},"cost":{"total_cost_usd":0.5},"context_window":{"total_input_tokens":1000,"total_output_tokens":35000,"context_window_size":200000,"current_usage":{"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"input_tokens":0}}}'
  run_sl() { printf '%s' "$stdin_json" | ICLAUDE_SL_NO_CACHE=1 bash "$tmp/scripts/claude-statusline.sh" 2>/dev/null; }

  # Case A: per-session file present → badge uses it
  printf '⛏ 65.0k · Σ110.1M' > "$tmp/.caveman-statusline-suffix-$sid"
  printf '⛏ Σ110.1M'         > "$tmp/.caveman-statusline-suffix"
  local outA; outA="$(run_sl)"
  assert_contains "t3A per-session badge wins" "$outA" "⛏ 65.0k · Σ110.1M"

  # Case B: per-session absent → global fallback
  rm -f "$tmp/.caveman-statusline-suffix-$sid"
  local outB; outB="$(run_sl)"
  assert_contains     "t3B global fallback shown"     "$outB" "⛏ Σ110.1M"
  assert_not_contains "t3B no session number in fallback" "$outB" "65.0k"

  # Case C: both absent → bare pick
  rm -f "$tmp/.caveman-statusline-suffix"
  local outC; outC="$(run_sl)"
  assert_contains     "t3C bare caveman icon" "$outC" "⛏"
  assert_not_contains "t3C no Σ when bare"     "$outC" "⛏ Σ"

  # Case D (spec success criterion #5): caveman inactive → no badge at all
  rm -f "$tmp/.caveman-active"
  printf '⛏ Σ110.1M' > "$tmp/.caveman-statusline-suffix"
  local outD; outD="$(run_sl)"
  assert_not_contains "t3D no caveman badge when inactive" "$outD" "⛏"
}

t3_statusline_precedence

echo
[[ $FAILED -eq 0 ]] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $FAILED
