#!/usr/bin/env python3
"""Auto-bump the patch version of every marketplace plugin whose source files
changed in a push range.

Called by .githooks/pre-push on a push to `dev`, alongside the VERSION bump.
For each plugin in `.claude-plugin/marketplace.json` whose `source` directory
has a changed file in `<remote_sha>..<local_sha>`, bumps the patch in BOTH the
marketplace entry and `<source>/.claude-plugin/plugin.json` (lockstep — the
sync guard requires them equal) and `git add`s the two files. The pre-push hook
makes the commit, so this script only edits + stages.

Minor/major bumps stay manual: edit both versions by hand when intended.

Stdlib only (python3) — no jq — matching the repo's other git hooks. Prints one
`name old -> new` line per bumped plugin to stdout; silent + exit 0 when nothing
changed, on an unknown range, or on any soft failure (never blocks the push).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys


def _changed_files(repo: str, base: str, head: str) -> list[str]:
    """Repo-relative paths changed in base..head. Empty on any failure or when
    base is the all-zero sha (a brand-new remote branch — no range to diff)."""
    if not base or set(base) == {"0"}:
        return []
    try:
        p = subprocess.run(
            ["git", "-C", repo, "diff", "--name-only", f"{base}..{head}"],
            capture_output=True, text=True, timeout=10)
        if p.returncode != 0:
            return []
        return [ln for ln in p.stdout.splitlines() if ln.strip()]
    except Exception:
        return []


def _bump_patch(version: str) -> str | None:
    parts = version.split(".")
    if len(parts) != 3 or not all(t.isdigit() for t in parts):
        return None
    major, minor, patch = parts
    return f"{major}.{minor}.{int(patch) + 1}"


def _rewrite_version(path: str, old: str, new: str) -> bool:
    """Replace the `"version": "<old>"` literal in a JSON file via raw text, so
    layout is preserved (plugin.json has a top-level version; marketplace.json
    has one per plugin entry). Refuses unless the literal occurs exactly once,
    so an ambiguous match (two plugins sharing a version) is a safe no-op rather
    than a wrong edit."""
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        needle = f'"version": "{old}"'
        if text.count(needle) != 1:
            return False
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text.replace(needle, f'"version": "{new}"', 1))
        return True
    except Exception:
        return False


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        return 0
    repo, base, head = argv[0], argv[1], argv[2]
    market_path = os.path.join(repo, ".claude-plugin", "marketplace.json")
    if not os.path.isfile(market_path):
        return 0

    changed = _changed_files(repo, base, head)
    if not changed:
        return 0

    try:
        with open(market_path, encoding="utf-8") as fh:
            market = json.load(fh)
    except Exception:
        return 0

    staged: list[str] = []
    for entry in market.get("plugins", []):
        source = entry.get("source", "")
        if not isinstance(source, str) or not source.startswith("."):
            continue
        prefix = source.lstrip("./").rstrip("/") + "/"
        if not any(f.startswith(prefix) for f in changed):
            continue
        manifest = os.path.join(repo, source, ".claude-plugin", "plugin.json")
        if not os.path.isfile(manifest):
            continue
        cur = entry.get("version")
        new = _bump_patch(cur) if isinstance(cur, str) else None
        if not new:
            continue
        # Bump the manifest first; only touch the marketplace entry if it lands.
        # The manifest's version equals `cur` (the sync guard keeps them equal).
        if not _rewrite_version(manifest, cur, new):
            continue
        if not _rewrite_version(market_path, cur, new):
            continue
        try:
            subprocess.run(["git", "-C", repo, "add", manifest, market_path],
                           capture_output=True, timeout=10)
        except Exception:
            pass
        name = entry.get("name", "<unnamed>")
        print(f"{name} {cur} -> {new}")
        staged.append(name)
        # Re-read marketplace so a second plugin sees the staged edit.
        try:
            with open(market_path, encoding="utf-8") as fh:
                market = json.load(fh)
        except Exception:
            break

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
