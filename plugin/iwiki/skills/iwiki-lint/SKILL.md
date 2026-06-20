---
name: iwiki-lint
description: >-
  Report documentation health over docs/wiki/: broken [[refs]], orphan pages,
  stale pages, and gaps (source with no wiki page). Report-only — makes no edits.
---

# iwiki-lint

Scan `docs/wiki/` and produce a health report. Make NO edits.

## Checks

1. **Broken links** — for every `[[target#Heading]]`, confirm the target file and
   `## Heading` exist. List the misses.
2. **Orphans** — wiki pages no other page links to.
3. **Stale** — run the engine `status` (from the current project root; the engine
   ships with this plugin, so it works in any project):
   ```bash
   # CLAUDE_PLUGIN_ROOT is set for hooks but NOT in the Bash tool — fall back to
   # the in-repo engine, then the newest cached one.
   ENG="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/engine}"
   [ -f "$ENG/pyproject.toml" ] || ENG="plugin/iwiki/engine"
   [ -f "$ENG/pyproject.toml" ] || ENG="$(ls -d "$CLAUDE_CONFIG_DIR"/plugins/cache/*/iwiki/*/engine 2>/dev/null | sort -V | tail -1)"
   UV="${UV_BIN:-}"; [ -x "$UV" ] || UV="$(command -v uv)"; [ -x "$UV" ] || UV="$CLAUDE_CONFIG_DIR/../bin/uv"
   "$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki status
   ```
   Cross-check against `docs/wiki/.iwiki/log.jsonl` to flag pages whose source
   changed after the last ingest (heuristic — list candidates, do not auto-fix).
4. **Gaps** — top-level source areas (`lib/`, `iclaude.sh`) with no wiki page.

## Steps

1. Read all `docs/wiki/**/*.md`.
2. Run each check above.
3. Print a markdown report grouped by check, with `file#Heading` references.
   End with a one-line summary count per category.
