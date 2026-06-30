---
name: iwiki-lint
description: >-
  Report documentation health over docs/wiki/: broken [[refs]], orphan pages,
  stale pages, and gaps (source with no wiki page). Report-only — makes no edits.
---

# iwiki-lint

Report `docs/wiki/` health by calling the engine's deterministic `lint` check.
Makes NO edits. The engine ships with this plugin, so this works in any project.

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

1. Run the engine `lint` from the current project root:
   ```bash
   # $ENG / $UV from "Engine invocation" above:
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
