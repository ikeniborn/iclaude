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
3. **Stale** — run `iwiki_engine_run --wiki-dir docs/wiki status`; cross-check
   against `docs/wiki/.iwiki/log.jsonl` to flag pages whose source changed after
   the last ingest (heuristic — list candidates, do not auto-fix).
4. **Gaps** — top-level source areas (`lib/`, `iclaude.sh`) with no wiki page.

## Steps

1. Read all `docs/wiki/**/*.md`.
2. Run each check above.
3. Print a markdown report grouped by check, with `file#Heading` references.
   End with a one-line summary count per category.
