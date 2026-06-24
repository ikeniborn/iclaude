#!/usr/bin/env bash
# Guard: every plugin listed in .claude-plugin/marketplace.json must declare the
# same version as its own <source>/.claude-plugin/plugin.json.
#
# Why: Claude Code caches user-scope plugins under cache/<market>/<plugin>/<version>/
# and only refreshes when the version changes. If the marketplace entry and the
# plugin manifest drift (e.g. plugin.json bumped to 0.6.0 while marketplace stayed
# 0.4.1), `plugin update` can never resync the cache, so hook/skill fixes never
# reach other projects. This check fails the push before that drift ships.
#
# Stdlib only (python3) — no jq dependency, matching the repo's other git hooks.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

python3 - "$REPO_ROOT" <<'PY'
import json, os, sys

repo = sys.argv[1]
market_path = os.path.join(repo, ".claude-plugin", "marketplace.json")
if not os.path.isfile(market_path):
    sys.exit(0)  # no marketplace -> nothing to check

with open(market_path) as fh:
    market = json.load(fh)

problems = []
for entry in market.get("plugins", []):
    name = entry.get("name", "<unnamed>")
    market_ver = entry.get("version")
    source = entry.get("source", "")
    # Only local directory sources have an on-disk plugin.json to compare.
    if not isinstance(source, str) or not source.startswith("."):
        continue
    manifest = os.path.join(repo, source, ".claude-plugin", "plugin.json")
    if not os.path.isfile(manifest):
        problems.append(f"{name}: marketplace source '{source}' has no .claude-plugin/plugin.json")
        continue
    with open(manifest) as fh:
        plugin_ver = json.load(fh).get("version")
    if market_ver != plugin_ver:
        problems.append(
            f"{name}: marketplace.json version '{market_ver}' != "
            f"{source}/.claude-plugin/plugin.json version '{plugin_ver}'"
        )

if problems:
    sys.stderr.write("ERROR: plugin version mismatch (cache will not resync):\n")
    for p in problems:
        sys.stderr.write(f"  - {p}\n")
    sys.stderr.write("Bump both versions in lockstep, then retry.\n")
    sys.exit(1)
PY
