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
- **User scope** means the plugin is enabled in every project, not just iclaude: the skills run the bundled engine (`$CLAUDE_PLUGIN_ROOT/engine`) against each project's own `docs/wiki/`.

See also: [[graphify]], [[nvm]], [[config]], [[launcher]]
