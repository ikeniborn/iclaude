#!/usr/bin/env bash
# Unit tests for S5: after the store moved to the repository root, .gitignore must
# publish exactly the same asset set as before and keep every runtime path — above
# all the credentials — out of git.
#
# git check-ignore answers from the patterns alone, so the paths need not exist.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

PASS=0; FAIL=0
ignored()   { if git check-ignore -q "$1"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [must be ignored]: $1"; fi; }
trackable() { if git check-ignore -q "$1"; then FAIL=$((FAIL+1)); echo "FAIL [must be trackable]: $1"; else PASS=$((PASS+1)); fi; }
assert_eq() { if [[ "$1" == "$2" ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$3]: got '$1' expected '$2'"; fi; }
assert_true() { if eval "$1"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL [$2]"; fi; }

# --- runtime state and secrets never reach git ---
ignored .claude-isolated/.credentials.json
ignored .claude-isolated/.claude.json
ignored .claude-isolated/history.jsonl
ignored .claude-isolated/projects/proj/session.jsonl
ignored .claude-isolated/session-env/sess
ignored .claude-isolated/shell-snapshots/snap.sh
ignored .claude-isolated/file-history/entry
ignored .claude-isolated/ssh/microvm
ignored .claude-isolated/backups/settings.json
ignored .claude-isolated/logs/launch.log

# --- generated binaries and caches ---
ignored .claude-isolated/bin/nvm.img
ignored .claude-isolated/bin/rootfs.ext4
ignored .claude-isolated/pii-proxy-venv/lib/pyvenv.cfg
ignored .claude-isolated/plugins/cache/entry
ignored .claude-isolated/plugins/marketplaces/m
ignored .claude-isolated/plugins/installed_plugins.json
ignored .claude-isolated/plugins/known_marketplaces.json
ignored .claude-isolated/plugins/.last_inuse_sweep
ignored .claude-isolated/hooks/__pycache__/chain-gate.pyc
ignored .claude-isolated/mcp/iwiki.runtime.json
ignored .claude-isolated/.claude-code-router/config.json

# --- the published asset set stays publishable ---
trackable .claude-isolated/settings.json
trackable .claude-isolated/CLAUDE.md
trackable .claude-isolated/router.json
trackable .claude-isolated/router.json.example
trackable .claude-isolated/plugins-manifest.json
trackable .claude-isolated/plugins/blocklist.json
trackable .claude-isolated/skills/demo/SKILL.md
trackable .claude-isolated/hooks/chain-gate.py
trackable .claude-isolated/mcp/iwiki.json
trackable .claude-isolated/scripts/claude-statusline.sh
trackable .claude-isolated/themes/claude-statusline.omp.json
trackable .claude-isolated/.claude-code-router/plugins/x-project-id.js

# --- the store is out of the nvm tree, in git as well as on disk ---
assert_eq "$(git ls-files '.nvm-isolated/.claude-isolated' | wc -l)" "0" \
  "layout: nothing tracked under the legacy path"
assert_true '[[ "$(git ls-files .claude-isolated | wc -l)" -gt 0 ]]' \
  "layout: the store is tracked at the repository root"
assert_true '! grep -q "nvm-isolated/\.claude-isolated" "$ROOT/.gitignore"' \
  "layout: .gitignore carries no legacy store pattern"

echo "store-gitignore: PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" == "0" ]]
