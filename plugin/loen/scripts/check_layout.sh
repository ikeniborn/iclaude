#!/usr/bin/env bash
# loen layout validator (deterministic net). Every file under docs/loen/<topic>/ must match a
# canonical path — catches artifacts written via Bash that bypass the PreToolUse hook.
# Usage: check_layout.sh [topic-dir]   (default: resolve the docs/loen/current pointer)
set -euo pipefail
run="${1:-}"
if [[ -z "$run" ]]; then
  [[ -f docs/loen/current ]] || { echo "check_layout: no docs/loen/current" >&2; exit 0; }
  run="docs/loen/$(head -n1 docs/loen/current | tr -d '[:space:]')"
fi
R="$(basename "$run")"
[[ "$R" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "check_layout: bad topic slug '$R'" >&2; exit 1; }
rc=0
while IFS= read -r f; do
  rel="${f#"$run"/}"
  case "$rel" in
    [1-7]_*.md) ;;
    loop.yaml|handoff.md|audit.html|attempts.jsonl|experiments.jsonl|pr-summary.md) ;;
    evidence/*) ;;
    *) echo "check_layout: non-canonical artifact: $f" >&2; rc=1 ;;
  esac
done < <(find "$run" -type f 2>/dev/null)
[[ $rc -eq 0 ]] && echo "check_layout: OK ($R)"
exit $rc
