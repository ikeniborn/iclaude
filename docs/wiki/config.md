# Configuration

Configuration management for the isolated Claude Code environment: sets up the project-local `CLAUDE_CONFIG_DIR`, exports runtime environment variables from the credentials file, provides export/import backup, and reports the status of the config directory and the isolated NVM install. See [[architecture]] for how this fits into the startup sequence.

## Isolated Config Directory

`setup_isolated_config` (in `lib/config/isolated.sh`) creates `.nvm-isolated/.claude-isolated/` if it does not exist and then exports `CLAUDE_CONFIG_DIR` pointing at that path. This export is the primary isolation mechanism: Claude Code and all hooks read `CLAUDE_CONFIG_DIR` to locate their state, so pointing it at a project-local directory prevents cross-project state bleed without kernel-level sandboxing.

`ISOLATED_NVM_DIR` (set by `lib/core/init.sh`) drives the path; no configurable override exists.

## Auto-Update Suppression

`disable_auto_updates` (in `lib/config/isolated.sh`) sets `autoUpdates: false` in `$CLAUDE_CONFIG_DIR/.claude.json`. It uses `jq` to patch the file in place via a temporary file and only writes when the current value is `"true"`, leaving the file untouched otherwise. The function silently returns 0 if `jq` is not available or the file does not yet exist — Claude Code creates it on first launch.

This prevents Claude Code from updating itself; version management is delegated to `--update` / `--install-from-lockfile` (see [[update]] and [[lockfile]]).

## Environment Variable Export

Every variable in `.claude_config` uses a single `ICLAUDE_` prefix and is a bare assignment (no `export`). `lib/config/env-map.sh` is the single config-load chokepoint: `source_iclaude_config` sources `$CREDENTIALS_FILE`, then `apply_iclaude_env_map` strips the prefix and exports the canonical name each built-in tool reads — e.g. `ICLAUDE_ANTHROPIC_API_KEY` → `ANTHROPIC_API_KEY`, `ICLAUDE_PROXY_URL` → `PROXY_URL`, `ICLAUDE_DEEPSEEK_API_KEY` → `DEEPSEEK_API_KEY`.

Translation rules:

- Most `ICLAUDE_X` → `export X` (de-prefix), exported only when non-empty, so unset keys do not override the existing environment.
- A native denylist (`_ICLAUDE_NATIVE_LIST`: `ICLAUDE_CHAT_LANG`, `ICLAUDE_DOC_LANG`, `ICLAUDE_NO_TELEMETRY`, `ICLAUDE_NO_AUTO_UPDATE`, and the runtime `ICLAUDE_PII_ACTIVE` / `ICLAUDE_PII_MASKING_LEVEL` / `ICLAUDE_PII_ACTIVE_PORT` / `ICLAUDE_PII_LOG_PATH`) is kept verbatim — hooks and the statusline read these under the `ICLAUDE_` name (see [[caveman#Language Resolution]], [[pii-proxy]]).
- An allow-empty set (`_ICLAUDE_ALLOW_EMPTY_LIST`: `ICLAUDE_PII_PROXY_MASK_TOKEN`) is exported even when set-but-empty, preserving the "empty token = no masking" semantic.

All nine `source "$CREDENTIALS_FILE"` sites (in `lib/` and the `iclaude.sh` install paths) route through `source_iclaude_config`. `load_claude_config` (in `lib/config/isolated.sh`) is now a thin wrapper that delegates to it. Internal lib code still reads canonical names (`PROXY_URL`, `MICRO_VM_*`, see [[sandbox]]) — translation re-creates them, so consumers need no change.

## Parse-Time Toggles

`iclaude.sh` reads five toggles by `grep` on the raw config file **before** any `source`, to seed CLI-equivalent flags: `ICLAUDE_USE_PII_PROXY`, `ICLAUDE_MICRO_VM_ENABLED`, `ICLAUDE_NO_ATTRIBUTION_HEADER`, `ICLAUDE_USE_CHROME`, `ICLAUDE_CLAUDE_CODE_SKIP_PERMISSIONS`. These patterns match the `ICLAUDE_` names directly, since a pre-source grep cannot benefit from the translation layer.

## Legacy Auto-Migration

`migrate_legacy_config` (in `lib/config/env-map.sh`) runs once at boot — after `init_environment` sets `CREDENTIALS_FILE` and before the parse-time grep block. A legacy `.claude_config` (detected by any `export ` line or any non-`ICLAUDE_` active assignment) is rewritten in place: active assignments gain the `ICLAUDE_` prefix and lose `export`, while comments and prose are left untouched. A chmod-600 `.claude_config.bak` backup is written first (via temp file + `mv`), and the rewrite is idempotent — once migrated, the file is no longer detected as legacy.

## Backup and Restore

`export_config` and `import_config` (in `lib/config/export.sh`) copy the config directory wholesale using `cp -r`.

`export_config <dest>` reads `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` and copies its contents into the destination directory, creating it if needed. It prints size and location on success.

`import_config <src>` copies from the source into `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, prompting for confirmation if the target already exists. After copying it enforces `chmod 600` on `.credentials.json` if that file is present.

## Status Reporting

`check_config_status` (in `lib/config/status.sh`) prints the current `CLAUDE_CONFIG_DIR` path, directory size, presence of key files (`.credentials.json`, `history.jsonl`, `settings.json`), and presence of key subdirectories (`projects`, `session-env`, `file-history`, `todos`). It also classifies the config type: `SHARED` when the path equals `$HOME/.claude`, `ISOLATED` when it contains `.nvm-isolated/.claude-isolated`, or `CUSTOM` otherwise.

`check_isolated_status` (in `lib/config/status.sh`) shows the broader isolated environment: NVM installation path and size, Node.js and npm versions, Claude Code version (read from the binary at `$ISOLATED_NVM_DIR/npm-global/bin/claude`), symlink health for `npm`, `npx`, `corepack`, and `claude`, and full lockfile content (via `jq` if available). It delegates to `show_native_installer_info` to emit an informational note when the installed Claude Code version is 2.1.0 or newer, since Anthropic recommends the native installer for that generation. Symlink issues direct the user to `--repair-isolated`. See also [[nvm]] for the symlink repair flow and [[lockfile]] for lockfile details.
