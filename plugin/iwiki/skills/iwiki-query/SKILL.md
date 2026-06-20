---
name: iwiki-query
description: >-
  Answer a question from the project's docs/wiki/ using semantic embedding
  search. Use when the user asks "where/how/why" about the project, or when
  CLAUDE.md says to consult the wiki before starting work.
---

# iwiki-query

Answer questions over `docs/wiki/` via the embedding engine. The engine returns
section ids; YOU read those sections and write the answer.

## Steps

1. Run the engine search from the **current project root**. The engine ships
   inside this plugin (`${CLAUDE_PLUGIN_ROOT}/engine`) and searches the current
   project's own `docs/wiki/` — so this works in any project, not just iclaude:
   ```bash
   [ -d docs/wiki ] || { echo "iwiki: no docs/wiki/ here — run /iwiki-init to create one."; exit 0; }
   # CLAUDE_PLUGIN_ROOT is set for hooks but NOT in the Bash tool — fall back to
   # the in-repo engine, then the newest cached one. Reused by step 4 below.
   ENG="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/engine}"
   [ -f "$ENG/pyproject.toml" ] || ENG="plugin/iwiki/engine"
   [ -f "$ENG/pyproject.toml" ] || ENG="$(ls -d "$CLAUDE_CONFIG_DIR"/plugins/cache/*/iwiki/*/engine 2>/dev/null | sort -V | tail -1)"
   UV="${UV_BIN:-}"; [ -x "$UV" ] || UV="$(command -v uv)"; [ -x "$UV" ] || UV="$CLAUDE_CONFIG_DIR/../bin/uv"
   "$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki search "<the user's question>"
   ```
   This prints JSON: `[{id, file, heading, chunk, score}, ...]`.
2. If the result is empty, tell the user no relevant section was found and stop.
3. Read the top matching sections from their `file` (use the Read tool). Use the
   `heading` to locate the `##` section within the file.
4. For the best match, also fetch related articles:
   ```bash
   # Reuses $UV and $ENG resolved in step 1 (re-run that block if in a fresh shell).
   "$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki related "<top result id>"
   ```
   Read the `vector` neighbours; if empty, follow the `graph` files.
5. Answer the question grounded in what you read. Cite sources as
   `[[file#Heading]]` wiki-links. List related articles separately.

## Stop rule

If the engine exits with `HALT:` (missing IWIKI_LLM_* or unreachable backend),
report the message and stop — do not fabricate an answer.
