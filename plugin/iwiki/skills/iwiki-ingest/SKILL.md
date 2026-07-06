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
and the embedding engine ships inside this plugin
(resolved via `IWIKI_ENGINE_DIR` — see **Engine invocation** above).
You do NOT need iclaude's `lib/` — only the plugin and `IWIKI_LLM_*` config.

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
   - One `##` section per concept; lead each section with a ≤250-char paragraph stating
     **what the section covers and why it matters** (intent, not just mechanics) — a wiki
     documents the *what and the why*. This lead doubles as the section summary that binds
     the section's chunks.
   - Prefer a **standard section name** where one fits, instead of an ad-hoc heading — a
     familiar name is a signal, a creative name is noise. Pick the applicable subset;
     never force-fit a section that does not apply: `## Purpose` (why it exists),
     `## Interface` / `## API` (public surface — functions, types, flags), `## Dependencies`,
     `## Data flow`, `## Errors` (failure modes), `## Usage` (how to invoke).
   - Wrap every code symbol — function name, file path, CLI flag, command, config key —
     in backticks, never bare prose. Precise references read cleanly and tokenize cleanly
     for the embedding index.
   Cross-link related pages with `[[file#Heading]]`.
3. Write/update the page (Write/Edit tool). Show the user the diff.
4. Refresh the index (run from the current project root):
   ```bash
   [ -d docs/wiki ] || { echo "iwiki: no docs/wiki/ here — run /iwiki-init to create one."; exit 0; }
   # $ENG / $UV from "Engine invocation" above:
   "$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki index
   ```
   Expected: `indexed: N chunks (... reused, ... embedded), <bytes>`.
5. Append an operation record to `docs/wiki/.iwiki/log.jsonl`:
   ```bash
   printf '{"op":"ingest","source":"<src>","page":"<page>","date":"<YYYY-MM-DD>","src_hash":"%s"}\n' \
     "$(sha256sum '<src>' | cut -c1-16)" \
     >> docs/wiki/.iwiki/log.jsonl
   ```
   Substitute `<src>` (same path in both the `source` field and the `sha256sum`
   argument), `<page>`, and `<YYYY-MM-DD>` literally; `src_hash` is filled by the
   shell. Canonical log record: `{op, source, page, date, src_hash}` (`note`
   optional). `src_hash` is the sha256 of the source's raw bytes, first 16 hex
   chars — `lint`'s stale check prefers it over mtime. Use exactly these keys;
   do not introduce alternatives (e.g. `scope`).
6. Report which page changed and the index size (warn if over the 8 MB cap).

## Stop rule

If the engine prints `HALT:`, report it and stop.
