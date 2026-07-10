#!/usr/bin/env bash
# loen protected-path guard (defense-in-depth; runs inside quality_gates).
# Reads protected_scope globs from the active loop.yaml and fails if `git diff` touches any.
# Usage: guard_protected.sh [path/to/loop.yaml]   (default: resolve via docs/loen/current)
set -euo pipefail

hooks_dir="$(cd "$(dirname "$0")/../hooks" && pwd)"
LOOP_YAML="${1:-}"
if [[ -z "$LOOP_YAML" ]]; then
  if [[ -f docs/loen/current ]]; then
    LOOP_YAML="docs/loen/$(head -n1 docs/loen/current | tr -d '[:space:]')/loop.yaml"
  else
    LOOP_YAML="docs/loen/current/loop.yaml"
  fi
fi
if [[ ! -e "$LOOP_YAML" ]]; then
  echo "guard_protected: no loop.yaml at $LOOP_YAML — nothing to guard" >&2
  exit 0
fi

mapfile -t protected < <(python3 - "$LOOP_YAML" "$hooks_dir" <<'PY'
import sys
sys.path.insert(0, sys.argv[2])
import loen_common as c
pol = c.parse_loop_yaml(open(sys.argv[1], encoding="utf-8").read())
fs = (pol.get("permissions") or {}).get("filesystem") or {}
for g in (fs.get("protected_scope") or pol.get("protected_scope") or []):
    print(g)
PY
)

changed="$(git diff --name-only HEAD 2>/dev/null || true)"
rc=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  for g in "${protected[@]:-}"; do
    [[ -z "$g" ]] && continue
    # shellcheck disable=SC2053
    if [[ "$f" == $g ]]; then
      echo "ERROR: protected path changed: $f (matches '$g')" >&2
      rc=1
    fi
  done
done <<< "$changed"

[[ $rc -eq 0 ]] && echo "guard_protected: OK"
exit $rc
