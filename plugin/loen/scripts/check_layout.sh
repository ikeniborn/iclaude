#!/usr/bin/env bash
# loen layout validator (deterministic net). Every file under docs/loen/<R>/ must match a
# canonical path — catches artifacts written via Bash that bypass the PreToolUse hook.
# Usage: check_layout.sh [run-dir]   (default: resolve docs/loen/current)
set -euo pipefail
run="${1:-}"
if [[ -z "$run" ]]; then
  [[ -L docs/loen/current ]] || { echo "check_layout: no docs/loen/current" >&2; exit 0; }
  run="docs/loen/$(basename "$(readlink docs/loen/current)")"
fi
R="$(basename "$run")"
[[ "$R" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+$ ]] || { echo "check_layout: bad run-id '$R'" >&2; exit 1; }
rc=0
while IFS= read -r f; do
  rel="${f#"$run"/}"
  case "$rel" in
    loop.yaml|plan.md|state.md|pr-summary.md|report.html|experiments.jsonl) ;;
    iterations/iter-[0-9][0-9]/diff.patch) ;;
    iterations/iter-[0-9][0-9]/gates.log) ;;
    iterations/iter-[0-9][0-9]/verifier.md) ;;
    iterations/iter-[0-9][0-9]/metrics.jsonl) ;;
    *) echo "check_layout: non-canonical artifact: $f" >&2; rc=1 ;;
  esac
done < <(find "$run" -type f 2>/dev/null)
[[ $rc -eq 0 ]] && echo "check_layout: OK ($R)"
exit $rc
