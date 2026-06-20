---
name: iwiki-lint
description: >-
  Report documentation health over docs/wiki/: broken [[refs]], orphan pages,
  stale pages, and gaps (source with no wiki page). Report-only — makes no edits.
---

# iwiki-lint

Report `docs/wiki/` health by calling the engine's deterministic `lint` check.
Makes NO edits. The engine ships with this plugin, so this works in any project.

## Steps

1. Run the engine `lint` from the current project root:
   ```bash
   # CLAUDE_PLUGIN_ROOT is set for hooks but NOT in the Bash tool — fall back to
   # the in-repo engine, then the newest cached one.
   ENG="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/engine}"
   [ -f "$ENG/pyproject.toml" ] || ENG="plugin/iwiki/engine"
   [ -f "$ENG/pyproject.toml" ] || ENG="$(ls -d "$CLAUDE_CONFIG_DIR"/plugins/cache/*/iwiki/*/engine 2>/dev/null | sort -V | tail -1)"
   UV="${UV_BIN:-}"; [ -x "$UV" ] || UV="$(command -v uv)"; [ -x "$UV" ] || UV="$CLAUDE_CONFIG_DIR/../bin/uv"
   "$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki lint
   ```
   This prints one JSON object. It always exits 0 (a real config/engine failure
   prints `HALT:` — see the Stop rule).

2. **If `wiki_present` is `false`:** print one line —
   "No `docs/wiki/` here yet — run `/iwiki-init` to bootstrap one." — and stop.

3. **Otherwise** format a markdown report from the JSON, grouped by category, each
   with its `page` / `ref` reference:
   - **Broken links** — every `{page, ref}` in `broken`.
   - **Orphans** — every path in `orphans`.
   - **Stale** — every `{page, source}` in `stale` (source changed after ingest).
   End with a one-line summary count per category.

4. **Gaps (advisory, only when `wiki_present` is true).** Optionally note source
   areas with no wiki page. Bound the scan to the set `iwiki-init` uses — immediate
   subdirs of `src/` / `lib/` / `app/` / `packages/` / `cmd/` / `internal/` plus root entry-point
   scripts (`*.sh`, `main.*`, `index.*`, `app.*`, `cli.*`) that exist. List
   candidates only; do not treat them as errors.

## Stop rule

If the engine prints `HALT:` (missing `IWIKI_LLM_*` is not needed for `lint`, but a
genuine engine error may still surface), report it and stop.
