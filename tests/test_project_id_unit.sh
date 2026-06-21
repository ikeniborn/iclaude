#!/usr/bin/env bash
# L1 — unit tests for _derive_project_id / _init_project_id (lib/launcher/launch.sh).
# No bats: mirrors the awk _extract + assert_eq harness from test_pii_dnat_unit.sh.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Extract a single function from launch.sh without sourcing the whole module
# (avoids pulling in launch_claude's dependencies). Matches "name() {" ... "}" at col 1.
_extract() {
    awk -v fn="$1" '
        $0 ~ "^"fn"\\(\\)" { in_fn=1 }
        in_fn { print }
        in_fn && /^}/ { in_fn=0 }
    ' "$ROOT/lib/launcher/launch.sh"
}
eval "$(_extract _derive_project_id)"

PASS=0; FAIL=0
assert_eq() {
    if [[ "$1" == "$2" ]]; then PASS=$((PASS + 1))
    else FAIL=$((FAIL + 1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi
}

# Non-git dir → basename verbatim
PARENT=$(mktemp -d); mkdir -p "$PARENT/minipc"
assert_eq "$(_derive_project_id "$PARENT/minipc")" "minipc" "non-git basename"
rm -rf "$PARENT"

# Uppercase + spaces → lowercased, spaces collapsed to '-'
PARENT=$(mktemp -d); mkdir -p "$PARENT/My Project"
assert_eq "$(_derive_project_id "$PARENT/My Project")" "my-project" "spaces+case sanitized"
rm -rf "$PARENT"

# Exotic chars collapse to single '-' and trim from both ends
PARENT=$(mktemp -d); mkdir -p "$PARENT/@@@weird@@@"
assert_eq "$(_derive_project_id "$PARENT/@@@weird@@@")" "weird" "exotic collapse+trim"
rm -rf "$PARENT"

# Git repo → toplevel basename even when called from a subdirectory
PARENT=$(mktemp -d); git -C "$PARENT" init -q myrepo >/dev/null 2>&1 || git init -q "$PARENT/myrepo"
mkdir -p "$PARENT/myrepo/sub"
assert_eq "$(_derive_project_id "$PARENT/myrepo/sub")" "myrepo" "git toplevel from subdir"
rm -rf "$PARENT"

# Sanitization yields empty → "unknown"
PARENT=$(mktemp -d); mkdir -p "$PARENT/@@@"
assert_eq "$(_derive_project_id "$PARENT/@@@")" "unknown" "empty-after-sanitize fallback"
rm -rf "$PARENT"

echo "L1 project_id (derive): PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
