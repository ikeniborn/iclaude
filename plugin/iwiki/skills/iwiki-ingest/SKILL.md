---
name: iwiki-ingest
description: >-
  Generate or update a wiki page in docs/wiki/ from a source file or folder,
  then refresh the embedding index. Use when asked to document code, add to the
  wiki, or after changing functionality. GUARDED: always show a diff and log.
---

# iwiki-ingest

Turn source into a wiki page under `docs/wiki/` (markdown + `[[refs]]`), then index it.

Works in **any project**: the wiki is written to the current project's `docs/wiki/`,
and the embedding engine ships inside this plugin (`${CLAUDE_PLUGIN_ROOT}/engine`).
You do NOT need iclaude's `lib/` — only the plugin and `IWIKI_LLM_*` config.

## Guardrails (autonomy zone: guarded)

- ALWAYS show the diff of the wiki page before/after writing.
- Sending source/doc content to the embedding API is a consented egress path —
  proceed only for the explicitly named source path.
- NEVER delete an existing wiki page. If ingest would remove one, STOP and ask.
- The engine reads only `docs/wiki/` + the named source; never `.env`/secrets.

## Steps

1. Read the source path the user named.
2. Decide the target wiki page: `docs/wiki/<topic>.md` (create or update).
   Page structure (REQUIRED — the engine and the section-formation hook depend on it):
   - Use **only `##`** for sections — never `###` or deeper. Deeper headings are not
     indexed as separate units and the validation hook blocks them; flatten them into
     the `##` section's prose.
   - Put **no content before the first `##`** except a single `#` H1 title — text
     before the first `##` is dropped from the index.
   - Lead with `# Title`, then a **first `## Overview` section** that summarizes all of
     the page's sections in ≈≤400 characters. You author this Overview yourself as part
     of writing the page (no separate summarizer). The engine reuses the Overview body
     to give every other section's vectors whole-article context, and the Overview
     section itself is NOT indexed as its own searchable section.
   - One `##` section per concept; lead each section with a ≤250-char paragraph (it
     doubles as the section summary that binds the section's chunks).
   Cross-link related pages with `[[file#Heading]]`.
3. Write/update the page (Write/Edit tool). Show the user the diff.
4. Refresh the index (run from the current project root):
   ```bash
   [ -d docs/wiki ] || { echo "iwiki: no docs/wiki/ here — run /iwiki-init to create one."; exit 0; }
   # Resolve the engine project. CLAUDE_PLUGIN_ROOT is set for hooks but NOT in
   # the Bash tool, so fall back to the in-repo copy, then the newest cached one.
   ENG="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/engine}"
   [ -f "$ENG/pyproject.toml" ] || ENG="plugin/iwiki/engine"
   [ -f "$ENG/pyproject.toml" ] || ENG="$(ls -d "$CLAUDE_CONFIG_DIR"/plugins/cache/*/iwiki/*/engine 2>/dev/null | sort -V | tail -1)"
   UV="${UV_BIN:-}"; [ -x "$UV" ] || UV="$(command -v uv)"; [ -x "$UV" ] || UV="$CLAUDE_CONFIG_DIR/../bin/uv"
   "$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki index
   ```
   Expected: `indexed: N chunks (... reused, ... embedded), <bytes>`.
5. Append an operation record to `docs/wiki/.iwiki/log.jsonl`:
   ```bash
   printf '{"op":"ingest","source":"<src>","page":"<page>","date":"<YYYY-MM-DD>"}\n' \
     >> docs/wiki/.iwiki/log.jsonl
   ```
   Canonical log record: `{op, source, page, date}` (`note` optional). Use exactly
   these keys — `lint`'s stale check reads `source`/`page` and ignores records
   missing them. Do not introduce alternative keys (e.g. `scope`).
6. Report which page changed and the index size (warn if over the 8 MB cap).

## Stop rule

If the engine prints `HALT:`, report it and stop.
