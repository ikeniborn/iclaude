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

## Engine invocation (read first)

The engine is a **Python module, not a binary on `PATH`** — do not treat it as a
shell command (probing with `command -v` or `--help` will fail). The launcher
exports `IWIKI_ENGINE_DIR`; resolve `$ENG` /
`$UV` once with the block below (it falls back to the in-repo / newest-cached
engine and exits loud if none is found), then reuse them in the steps:

```bash
ENG="${IWIKI_ENGINE_DIR:-}"
[ -f "$ENG/pyproject.toml" ] || ENG="plugin/iwiki/engine"
[ -f "$ENG/pyproject.toml" ] || ENG="$(ls -d "$CLAUDE_CONFIG_DIR"/plugins/cache/*/iwiki/*/engine 2>/dev/null | sort -V | tail -1)"
[ -f "$ENG/pyproject.toml" ] || { echo "iwiki: engine not found — run ./iclaude.sh --install-iwiki" >&2; exit 1; }
UV="${UV_BIN:-}"; [ -x "$UV" ] || UV="$(command -v uv)"; [ -x "$UV" ] || UV="$CLAUDE_CONFIG_DIR/../bin/uv"
# Run from the project root (relative --wiki-dir resolves against it):
"$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki <cmd>
```

## Steps

1. Run the engine search from the **current project root**:
   ```bash
   [ -d docs/wiki ] || { echo "iwiki: no docs/wiki/ here — run /iwiki-init to create one."; exit 0; }
   # $ENG / $UV from "Engine invocation" above:
   "$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki search "<the user's question>"
   ```
   This prints JSON: `[{id, file, heading, chunk, score}, ...]`.
2. If the result is empty, tell the user no relevant section was found and stop.
3. Read the top matching sections from their `file` (use the Read tool). Use the
   `heading` to locate the `##` section within the file.
4. For the best match, also fetch related articles:
   ```bash
   # $ENG / $UV from "Engine invocation" above (re-run that block if in a fresh shell).
   "$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki related "<top result id>"
   ```
   Read the `vector` neighbours; if empty, follow the `graph` files.
5. Answer the question grounded in what you read. Cite sources as
   `[[file#Heading]]` wiki-links. List related articles separately.

## Stop rule

If the engine exits with `HALT:` (missing IWIKI_LLM_* or unreachable backend),
report the message and stop — do not fabricate an answer.
