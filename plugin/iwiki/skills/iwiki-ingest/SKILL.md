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
   One `##` section per concept; lead each section with a ≤250-char paragraph.
   Cross-link related pages with `[[file#Heading]]`.
3. Write/update the page (Write/Edit tool). Show the user the diff.
4. Refresh the index (run from the current project root):
   ```bash
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
6. Report which page changed and the index size (warn if over the 8 MB cap).

## Stop rule

If the engine prints `HALT:`, report it and stop.
