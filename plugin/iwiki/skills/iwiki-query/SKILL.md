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

1. Run the engine search (from the project root):
   ```bash
   source lib/iwiki/detect.sh
   iwiki_engine_run --wiki-dir docs/wiki search "<the user's question>"
   ```
   This prints JSON: `[{id, file, heading, chunk, score}, ...]`.
2. If the result is empty, tell the user no relevant section was found and stop.
3. Read the top matching sections from their `file` (use the Read tool). Use the
   `heading` to locate the `##` section within the file.
4. For the best match, also fetch related articles:
   ```bash
   iwiki_engine_run --wiki-dir docs/wiki related "<top result id>"
   ```
   Read the `vector` neighbours; if empty, follow the `graph` files.
5. Answer the question grounded in what you read. Cite sources as
   `[[file#Heading]]` wiki-links. List related articles separately.

## Stop rule

If the engine exits with `HALT:` (missing IWIKI_LLM_* or unreachable backend),
report the message and stop — do not fabricate an answer.
