# iwiki Module

Bash integration that installs and detects the **iwiki documentation-graph engine** plus its in-repo Claude Code plugin. It wraps `uv sync` of the bundled Python engine and registers the `iwiki@iclaude` plugin at user scope. The module lives in `lib/iwiki/` (`detect.sh`, `install.sh`).

## Detection

`detect_iwiki()` reports iwiki as available when `uv` resolves and the engine's `pyproject.toml` exists. It is a precondition check, not a launcher.

- `_iwiki_resolve_uv()` prefers `$GRAPHIFY_UV_BIN` (the uv installed by [[graphify]]) and falls back to `uv` on `PATH`.
- `_iwiki_engine_dir()` resolves to `${SCRIPT_DIR}/plugin/iwiki/engine` — the in-repo engine project.
- `detect_iwiki()` returns success only if both `uv` and `<engine-dir>/pyproject.toml` are present.

## Engine Sync (uv)

`install_iwiki()` (driven by `--install-iwiki`) synchronizes the bundled engine's virtualenv via `uv sync`. It depends on uv, which is provided by [[graphify]] — installation aborts with a hint to run `--install-graphify` if uv is absent.

- Resolves uv via `_iwiki_resolve_uv()`; if missing, prints an error pointing at `--install-graphify` and returns 1.
- Verifies `<engine-dir>/pyproject.toml` exists, then runs `( cd "$dir" && uv sync )`.
- On success, calls `_iwiki_register_plugin()` and reminds the user to set `IWIKI_LLM_BASE_URL` / `IWIKI_LLM_KEY` / `IWIKI_EMBED_MODEL` in `.claude_config` (see [[config]]).

## Engine Runner

`iwiki_engine_run()` invokes the synced engine as a Python module. It stays in the caller's CWD so a relative `--wiki-dir` (e.g. `docs/wiki`) resolves against the project root, while `--project` points uv at the engine's own venv.

- Runs `uv run --project "$(_iwiki_engine_dir)" python3 -m iwiki_engine "$@"`.
- If uv is unresolved, prints `iwiki: uv not found; run ./iclaude.sh --install-iwiki` and returns 1.

## Plugin Registration

`_iwiki_register_plugin()` registers an in-repo marketplace and installs the `iwiki@iclaude` plugin into the isolated plugins dir so Claude Code loads it. It is non-fatal and idempotent — the engine remains usable via the CLI even if any step fails.

- Resolves the Claude binary with `get_nvm_claude_path()` (see [[nvm#Claude Binary Detection]]); skips registration with a warning if the binary or `CLAUDE_CONFIG_DIR` is unset.
- `_iwiki_claude()` dispatches the resolved path, handling both the native binary and the legacy `node cli.js` form, always running from `$SCRIPT_DIR`.
- Adds the marketplace with `plugin marketplace add "$SCRIPT_DIR" --scope user` (unless `iclaude` already appears in `plugin marketplace list`).
- Installs with `plugin install iwiki@iclaude --scope user` (unless `iwiki@iclaude` already appears in `plugin list`).
- When the plugin is already present, refreshes it instead: `plugin marketplace update iclaude` + `plugin update iwiki@iclaude`, so a bumped plugin version (e.g. new bundled hooks) lands in the plugin cache. Restart required to apply.
- **User scope** means the plugin is enabled in every project, not just iclaude: the skills run the bundled engine (`$CLAUDE_PLUGIN_ROOT/engine`) against each project's own `docs/wiki/`.

## Automation Hooks

The plugin bundles three Claude Code hooks (declared in `plugin/iwiki/hooks/hooks.json`, run from `${CLAUDE_PLUGIN_ROOT}/hooks/`) that keep the wiki consulted and current with no manual `/iwiki-*` step. They share `iwiki_common.py` (engine/uv resolution, git diff, project chdir) and are all fail-soft and individually kill-switchable. A hook cannot run a slash command or LLM skill directly, so each either drives the engine CLI deterministically or injects a directive Claude acts on.

- **`iwiki-recall.py` (UserPromptSubmit)** — runs the engine's semantic `search` on the user's prompt and injects the top matching `docs/wiki` sections as context, so relevant docs are present before any task. Skips trivial/slash prompts and an uninitialised wiki; falls back to a one-line `/iwiki-query` nudge on timeout/missing config. Kill switch: `IWIKI_AUTO_QUERY=0`.
- **`iwiki-reindex.py` (PostToolUse: Write/Edit/MultiEdit)** — when a `docs/wiki/*.md` page changes, runs the incremental `index` so semantic search reflects the edit. Triggers only on wiki pages (not the `.iwiki/` index dir), so it never loops. Kill switch: `IWIKI_AUTO_REINDEX=0`.
- **`iwiki-sync.py` (Stop)** — when a turn ends with documentable source changes (uncommitted code a wiki page describes, including subagent edits), blocks the stop once and injects a directive to run [[iwiki]]'s ingest skill on the changed sources plus `/iwiki-lint`. A stamp (`$CLAUDE_CONFIG_DIR/.cache/iwiki-sync.stamp`) records the acted-on change-set so the same set never blocks twice (no loop) and committed work is silent. Kill switch: `IWIKI_AUTO_SYNC=0`.

Because hook installation is bundled in the plugin manifest, enabling `iwiki@iclaude` in any project activates this behaviour there too — paths resolve against `CLAUDE_PROJECT_DIR` / `CLAUDE_PLUGIN_ROOT`.

See also: [[graphify]], [[nvm]], [[config]], [[launcher]]
