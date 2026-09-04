#!/usr/bin/env bash
# Regression: detect_real_context_window() must know the Claude 5 family —
# Fable/Mythos/Sonnet 5 have a 1M input window (Claude Code still reports
# context_window_size=200000). Haiku stays at 200K. Observed bug: a Fable
# session rendered "Σ 0 ↓ | 📊 228K (114%) ⚠️" against the false 200K window.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
SL="$repo_root/.claude-isolated/scripts/claude-statusline.sh"

# run_sl <display_name> <total_input> <cache_read> <cache_creation> <input_tokens>
# Pipes a synthetic Claude Code statusline payload into the script.
# ICLAUDE_SL_NO_CACHE=1 — bypass the /tmp result cache (no stale output, no bg fork).
# STATUSLINE_ADAPTIVE=0 — force full display mode regardless of terminal width.
run_sl() {
    ICLAUDE_SL_NO_CACHE=1 STATUSLINE_ADAPTIVE=0 bash "$SL" <<EOF
{"session_id":"sl-ctx-test","transcript_path":"","cwd":"/tmp",
 "workspace":{"project_dir":"/tmp"},
 "model":{"display_name":"$1"},
 "cost":{"total_cost_usd":0},
 "context_window":{"total_input_tokens":$2,"total_output_tokens":1000,
   "context_window_size":200000,"used_percentage":50,
   "current_usage":{"input_tokens":$5,"cache_read_input_tokens":$3,"cache_creation_input_tokens":$4}}}
EOF
}

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- window mapping (spec §2) ---

# Fable 5 = 1M: 228K active → 23%, 772K remaining, no overflow warning
out="$(run_sl "Fable 5" 228000 228000 448 0)"
[[ "$out" == *"(23%)"* ]]  || fail "Fable: expected (23%) of 1M window, got: $out"
[[ "$out" != *"⚠️"* ]]     || fail "Fable: unexpected overflow warning: $out"
[[ "$out" == *"772K"* ]]   || fail "Fable: expected 772K remaining, got: $out"

# Mythos 5 = 1M (same Claude 5 root cause)
out="$(run_sl "Mythos 5" 228000 228000 448 0)"
[[ "$out" == *"(23%)"* ]]  || fail "Mythos: expected (23%) of 1M window, got: $out"

# Sonnet 5 = 1M (outer *sonnet* branch matches but no 4.x version pattern)
out="$(run_sl "Sonnet 5" 100000 100000 0 0)"
[[ "$out" == *"(10%)"* ]]  || fail "Sonnet 5: expected (10%) of 1M window, got: $out"

# Opus 4.8 = 1M (regression: already worked before the fix)
out="$(run_sl "Opus4.8" 459000 457000 2000 0)"
[[ "$out" == *"(46%)"* ]]  || fail "Opus4.8: expected (46%) of 1M window, got: $out"

# Haiku 4.5 = 200K (regression: must NOT become 1M)
out="$(run_sl "Haiku 4.5" 100000 100000 0 0)"
[[ "$out" == *"(50%)"* ]]  || fail "Haiku: expected (50%) of 200K window, got: $out"

# Sonnet 3.5 = 200K (glob must not false-match "5" later in the name)
out="$(run_sl "Sonnet 3.5" 100000 100000 0 0)"
[[ "$out" == *"(50%)"* ]]  || fail "Sonnet 3.5: expected (50%) of 200K window, got: $out"

# --- cache hit-rate floor (spec §3) ---

# 457000/(457000+2000) = 99.56% → must render 99% (floor), not 100% (round)
out="$(run_sl "Opus4.8" 459000 457000 2000 0)"
[[ "$out" == *"📦 99%"* ]]  || fail "hit-rate floor: expected 📦 99%, got: $out"

# Fully cached request (creation=0, uncached input=0) → exactly 100%
out="$(run_sl "Opus4.8" 457000 457000 0 0)"
[[ "$out" == *"📦 100%"* ]] || fail "hit-rate full: expected 📦 100%, got: $out"

echo "PASS test_statusline_context_window.sh"
