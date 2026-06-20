# iwiki Module

Bash integration that installs and detects the **iwiki documentation-graph engine** plus its in-repo Claude Code plugin. It wraps `uv sync` of the bundled Python engine and registers the `iwiki@iclaude` plugin at user scope. The module lives in `lib/iwiki/` (`detect.sh`, `install.sh`).

## Detection

`detect_iwiki()` reports iwiki as available when `uv` resolves and the engine's `pyproject.toml` exists. It is a precondition check, not a launcher.

- `_iwiki_resolve_uv()` prefers `$UV_BIN` (the isolated `uv` exported by [[core]]) and falls back to `uv` on `PATH`.
- `_iwiki_engine_dir()` resolves to `${SCRIPT_DIR}/plugin/iwiki/engine` — the in-repo engine project.
- `detect_iwiki()` returns success only if both `uv` and `<engine-dir>/pyproject.toml` are present.

## Engine Sync (uv)

`install_iwiki()` (driven by `--install-iwiki`) synchronizes the bundled engine's virtualenv via `uv sync`. It owns its uv dependency: if neither the isolated nor a system `uv` is found, `_iwiki_bootstrap_uv()` downloads the static binary from the astral-sh GitHub release into `${ISOLATED_NVM_DIR}/bin/uv` (honoring `HTTPS_PROXY`/`HTTP_PROXY`/`PROXY_URL`).

- Resolves uv via `_iwiki_resolve_uv()`; if missing, bootstraps it via `_iwiki_bootstrap_uv()` (returns 1 only if the download fails).
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

The plugin bundles four Claude Code hooks (declared in `plugin/iwiki/hooks/hooks.json`, run from `${CLAUDE_PLUGIN_ROOT}/hooks/`) that keep the wiki consulted and current with no manual `/iwiki-*` step. They share `iwiki_common.py` (engine/uv resolution, git diff, project chdir, and a per-session state file) and are all fail-soft and individually kill-switchable. A hook cannot run a slash command or LLM skill directly, so each either drives the engine CLI deterministically or injects a directive Claude acts on.

Engine/uv resolution is layered and **`CLAUDE_PLUGIN_ROOT`-independent**: `engine_dir()` tries the plugin root (only set for hooks), then the in-repo `plugin/iwiki/engine`, then the **newest** cached plugin version (`engine_dir()` sorts the cache glob by version). The `/iwiki-*` skills' bash steps mirror the same fallback, because `CLAUDE_PLUGIN_ROOT` is *not* exported into the Bash tool — relying on it alone expands to `--project /engine` and fails, so the skills must resolve the engine themselves.

- **`iwiki-bootstrap.py` (SessionStart)** — does two jobs. (1) Snapshots the baseline (`HEAD` + the documentable files already dirty at session start) into the session state **once per session**, keyed by the payload `session_id`. SessionStart can re-fire within one session (resume); the baseline is reset only when the `session_id` is new (or there is no state file yet), so a re-fire never clobbers the Stop hook's nag dedup (`asked_sig`/`count`) — otherwise the Stop nag would re-arm every turn and block forever. An empty/unreadable `HEAD` never overwrites an existing baseline. This lets the Stop nag attribute changes to *this* session's actions and never fire on pre-existing work-in-progress. (2) If the project has documentable source but no `docs/wiki/` (or pages but no index), injects a nudge to run `/iwiki-init` (or rebuild) — the only trigger that surfaces an absent wiki. Filesystem/git only (no embedding call). Kill switch: `IWIKI_AUTO_BOOTSTRAP=0`.
- **`iwiki-recall.py` (UserPromptSubmit)** — runs the engine's semantic `search` on the user's prompt and injects the top matching `docs/wiki` sections as context, so relevant docs are present before any task. Skips trivial/slash prompts and an uninitialised wiki; falls back to a one-line `/iwiki-query` nudge on timeout/missing config. Kill switch: `IWIKI_AUTO_QUERY=0`.
- **`iwiki-reindex.py` (PostToolUse: Write/Edit/MultiEdit)** — cheap bookkeeping, no engine call: records each documentable-source edit into the session `edits` set (the action-attributed signal the Stop nag uses) and flips a `wiki_dirty` flag when a `docs/wiki/*.md` page changes. The actual `index` is deferred and batched once at Stop, so N page edits cost one reindex, not N. Kill switch: `IWIKI_AUTO_REINDEX=0`.
- **`iwiki-sync.py` (Stop)** — runs the batched `index` once if any wiki page changed this session, then nags about undocumented sources. The change-set is the session's own work: `(uncommitted ∪ committed-this-session) − baseline WIP`, plus the recorded `edits` — so it catches code committed before the stop (no commit-evasion) and excludes pre-existing WIP (no false positives). Blocks the stop and injects a directive to run [[iwiki]]'s ingest skill plus `/iwiki-lint`; the same unchanged set re-asks at most `IWIKI_SYNC_MAX_ASK` times (default 2, then yields, so the stop is never wedged), and a `wiki_sig` shift between asks counts as the ingest having happened. State lives in `$CLAUDE_CONFIG_DIR/.cache/iwiki-session.json`. Kill switch: `IWIKI_AUTO_SYNC=0`.

Because hook installation is bundled in the plugin manifest, enabling `iwiki@iclaude` in any project activates this behaviour there too — paths resolve against `CLAUDE_PROJECT_DIR` / `CLAUDE_PLUGIN_ROOT`.

See also: [[core]], [[nvm]], [[config]], [[launcher]]
