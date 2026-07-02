#!/usr/bin/env bash
# guard_protected.sh must fail (exit 1) when the git diff touches a protected path,
# and pass (exit 0) when it does not.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$repo_root/plugin/loen/scripts/guard_protected.sh"
[[ -f "$guard" ]] || { echo "FAIL: missing $guard" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q
git config user.email t@t; git config user.name t
mkdir -p datasets src
echo "seed" > src/app.py
git add -A; git commit -qm seed
cat > loop.yaml <<'YAML'
protected_scope:
  - datasets/*
  - src/frozen.py
mutable_scope:
  - src/*
YAML

# clean-ish change (only mutable) -> exit 0
echo "change" >> src/app.py
git add -A
if bash "$guard" loop.yaml; then :; else echo "FAIL: guard blocked a clean diff" >&2; exit 1; fi

# protected change -> exit 1
echo "raw" > datasets/raw.csv
git add -A
if bash "$guard" loop.yaml; then echo "FAIL: guard allowed a protected change" >&2; exit 1; fi

echo "PASS test_loen_guard.sh"
