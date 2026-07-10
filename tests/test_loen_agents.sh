#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
a="$repo_root/plugin/loen/agents"
for role in explorer planner verifier reviewer researcher; do
  [[ -f "$a/$role.md" ]] || { echo "FAIL: missing agent $role" >&2; exit 1; }
  head -20 "$a/$role.md" | grep -qi "^name:" || { echo "FAIL: $role no name" >&2; exit 1; }
  head -20 "$a/$role.md" | grep -qi "^tools:" || { echo "FAIL: $role no tools" >&2; exit 1; }
done
# reviewer, researcher, explorer, planner must be read-only (no edit tools)
for role in reviewer researcher explorer planner; do
  if head -20 "$a/$role.md" | grep -i "^tools:" | grep -qE "Write|Edit|MultiEdit"; then
    echo "FAIL: $role must be read-only" >&2; exit 1; fi
done
echo "PASS test_loen_agents.sh"
