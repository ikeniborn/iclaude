---
name: iwiki-init
description: >-
  Bootstrap a project's docs/wiki/ from scratch — scan the source tree, generate
  one wiki page per major area, build the embedding index, and lint. Use for a
  brand-new wiki (empty or missing docs/wiki/). GUARDED: shows the area plan and
  a diff before writing; sending source to the embedding API is consented egress.
---

# iwiki-init

One-shot bootstrap of `docs/wiki/` for the **current project**. This is a batch
`iwiki-ingest`: it scans the source tree, generates a wiki page per area, then
indexes everything. Works in any project — the engine ships with this plugin
(`${CLAUDE_PLUGIN_ROOT}/engine`) and writes to the current project's `docs/wiki/`.

## Guardrails (autonomy zone: guarded)

- Present the **area → page plan** and get the user's go-ahead BEFORE generating.
  Generating pages sends source content to the embedding API (consented egress).
- NEVER overwrite a non-empty existing wiki page without showing its diff and
  asking. If `docs/wiki/` already has content, prefer `/iwiki-ingest` per page.
- The engine reads only `docs/wiki/` + the scanned source; never `.env`/secrets.

## Steps

1. **Detect source areas.** Inspect the project root and pick the major areas to
   document. Heuristics (use what exists):
   - Entry points at root: `main.*`, `index.*`, `app.*`, `*.sh` launcher, `cli.*`.
   - Source dirs: each immediate subdir of `src/`, `lib/`, `app/`, `packages/`,
     `cmd/`, `internal/` is one area → one page.
   - Skip: `node_modules`, `.git`, `dist`, `build`, `vendor`, `.venv`, `docs/wiki`.
   Build a mapping `area (source path) → docs/wiki/<slug>.md`. Add an
   `architecture.md` for the top-level entry points + overall structure.

2. **Show the plan, get consent.** Print the full `area → page` table and the
   page count. Ask the user to confirm (this is the egress consent gate). Stop if
   they decline.

3. **Generate each page.** For every area, follow the `iwiki-ingest` authoring
   rules: read the real source, write `docs/wiki/<slug>.md` as `# Title` + a first
   `## Overview` section (≈≤400-char summary of all the page's sections, authored by
   you) + one `##` section per concept, each led by a ≤250-char paragraph. Use **only
   `##`** — never `###` or deeper, and no content before the first `##` except the
   `# Title`. Cross-link related pages with `[[<page>#<Heading>]]`. English prose.
   Accurate to the code — do not invent. Show a brief diff/summary per page as you go.

4. **Build the index** (from the project root):
   ```bash
   # CLAUDE_PLUGIN_ROOT is set for hooks but NOT in the Bash tool — fall back to
   # the in-repo engine, then the newest cached one.
   ENG="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/engine}"
   [ -f "$ENG/pyproject.toml" ] || ENG="plugin/iwiki/engine"
   [ -f "$ENG/pyproject.toml" ] || ENG="$(ls -d "$CLAUDE_CONFIG_DIR"/plugins/cache/*/iwiki/*/engine 2>/dev/null | sort -V | tail -1)"
   UV="${UV_BIN:-}"; [ -x "$UV" ] || UV="$(command -v uv)"; [ -x "$UV" ] || UV="$CLAUDE_CONFIG_DIR/../bin/uv"
   "$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki index
   ```
   Expected: `indexed: N chunks (... reused, ... embedded), <bytes>` (warn if over
   the 8 MB cap).

5. **Log the bootstrap.** Append one record per generated page to
   `docs/wiki/.iwiki/log.jsonl`:
   ```bash
   printf '{"op":"init","source":"<src>","page":"<page>","date":"<YYYY-MM-DD>","src_hash":"%s"}\n' \
     "$(sha256sum '<src>' | cut -c1-16)" \
     >> docs/wiki/.iwiki/log.jsonl
   ```
   Substitute `<src>` (same path in both the `source` field and the `sha256sum`
   argument), `<page>`, and `<YYYY-MM-DD>` literally; `src_hash` is filled by the
   shell. Canonical log record: `{op, source, page, date, src_hash}` (`note`
   optional). `src_hash` is the sha256 of the source's raw bytes, first 16 hex
   chars — `lint`'s stale check prefers it over mtime. Use exactly these keys;
   do not introduce alternatives (e.g. `scope`).

6. **Lint + summarize.** Invoke the `iwiki:iwiki-lint` skill (or run the checks)
   and report: pages created, chunk count, index size, and any gaps (source areas
   left without a page).

## Stop rule

If the engine prints `HALT:` (missing `IWIKI_LLM_*` or unreachable backend),
report it and stop — do not fabricate pages.
