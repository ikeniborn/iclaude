#!/usr/bin/env bash
# check_layout.sh must accept a canonical docs/loen/<topic>/ tree and reject non-canonical files.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
chk="$repo_root/plugin/loen/scripts/check_layout.sh"
[[ -f "$chk" ]] || { echo "FAIL: missing $chk" >&2; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT; cd "$tmp"
topic="my-topic"; run="docs/loen/$topic"
mkdir -p "$run/evidence"
for f in 1_goal 2_context 3_plan 4_act 5_check 6_reflect 7_result; do : > "$run/$f.md"; done
: > "$run/loop.yaml"; : > "$run/attempts.jsonl"; : > "$run/audit.html"; : > "$run/handoff.md"
: > "$run/evidence/verifier-verdict.md"
bash "$chk" "$run" || { echo "FAIL: rejected a canonical topic layout" >&2; exit 1; }
: > "$run/experiments.jsonl"   # research stream (canonical)
bash "$chk" "$run" || { echo "FAIL: rejected canonical experiments.jsonl" >&2; exit 1; }
: > "$run/scratch.txt"   # non-canonical
if bash "$chk" "$run"; then echo "FAIL: accepted a non-canonical artifact" >&2; exit 1; fi
echo "PASS test_loen_layout.sh"
