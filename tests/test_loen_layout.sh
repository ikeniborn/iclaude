#!/usr/bin/env bash
# check_layout.sh must accept a canonical docs/loen/<R>/ tree and reject any non-canonical file.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
chk="$repo_root/plugin/loen/scripts/check_layout.sh"
[[ -f "$chk" ]] || { echo "FAIL: missing $chk" >&2; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT; cd "$tmp"
R=2026-07-01-demo; run="docs/loen/$R"
mkdir -p "$run/iterations/iter-01"
: > "$run/loop.yaml"; : > "$run/state.md"
: > "$run/iterations/iter-01/diff.patch"; : > "$run/iterations/iter-01/gates.log"
bash "$chk" "$run" || { echo "FAIL: rejected a canonical layout" >&2; exit 1; }
: > "$run/scratch.txt"   # non-canonical
if bash "$chk" "$run"; then echo "FAIL: accepted a non-canonical artifact" >&2; exit 1; fi
echo "PASS test_loen_layout.sh"
