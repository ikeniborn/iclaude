#!/usr/bin/env bash
# loen protected-path guard (defense-in-depth; runs inside quality_gates).
# Reads protected_scope globs from the active loop.yaml and fails if `git diff` touches any.
# Usage: guard_protected.sh [path/to/loop.yaml]   (default: docs/loen/current/loop.yaml)
set -euo pipefail

LOOP_YAML="${1:-docs/loen/current/loop.yaml}"
if [[ ! -e "$LOOP_YAML" ]]; then
  echo "guard_protected: no loop.yaml at $LOOP_YAML — nothing to guard" >&2
  exit 0
fi

mapfile -t protected < <(python3 - "$LOOP_YAML" <<'PY'
import sys, re
cur = None
for line in open(sys.argv[1], encoding="utf-8"):
    s = line.rstrip("\n")
    if re.match(r"^protected_scope:", s): cur = True; continue
    if re.match(r"^[A-Za-z_]", s): cur = None; continue
    m = re.match(r"^\s*-\s*(.+?)\s*$", s)
    if m and cur:
        print(m.group(1).strip().strip('"').strip("'"))
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
