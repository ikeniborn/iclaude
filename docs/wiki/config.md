# Configuration

## Overview

Configuration management for the isolated Claude Code environment: sets up the project-local `CLAUDE_CONFIG_DIR`, loads `.claude_config` through a single env-map chokepoint (`ICLAUDE_*` → canonical names), auto-migrates legacy configs, suppresses Claude Code auto-updates, provides export/import backup, and reports config-directory and isolated-NVM status. See [[architecture]] for the startup sequence.

## Isolated Config Directory

`setup_isolated_config` (in `lib/config/isolated.sh`) creates `.nvm-isolated/.claude-isolated/` if it does not exist and then exports `CLAUDE_CONFIG_DIR` pointing at that path. This export is the primary isolation mechanism: Claude Code and all hooks read `CLAUDE_CONFIG_DIR` to locate their state, so pointing it at a project-local directory prevents cross-project state bleed without kernel-level sandboxing.

The path is `${ISOLATED_NVM_DIR}/.claude-isolated`; `ISOLATED_NVM_DIR` is set by `lib/core/init.sh` ([[core]]) and there is no configurable override.

## Auto-Update Suppression

`disable_auto_updates` (in `lib/config/isolated.sh`) sets `autoUpdates: false` in `$CLAUDE_CONFIG_DIR/.claude.json`. It accepts an optional config-dir argument (default `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`), reads the current value with `jq`, and only patches when it is literally `"true"` — writing through a `.tmp.$$` temp file, then `mv` plus `chmod 600`. It silently returns 0 when `jq` is missing or `.claude.json` does not yet exist (Claude Code creates it on first launch).

This keeps Claude Code from updating itself; version management is delegated to `--update` / `--install-from-lockfile` (see [[update]] and [[lockfile]]).

## Environment Variable Export

Every variable in `.claude_config` uses a single `ICLAUDE_` prefix and is a bare assignment (no `export`). `lib/config/env-map.sh` is the single config-load chokepoint: `source_iclaude_config` sources `$CREDENTIALS_FILE` (returning early if the file is absent), then `apply_iclaude_env_map` translates each set `ICLAUDE_*` into the canonical name built-in tools read — e.g. `ICLAUDE_ANTHROPIC_API_KEY` → `ANTHROPIC_API_KEY`, `ICLAUDE_PROXY_URL` → `PROXY_URL`, `ICLAUDE_DEEPSEEK_API_KEY` → `DEEPSEEK_API_KEY`. It is idempotent — safe to call repeatedly.

Translation rules (`apply_iclaude_env_map` sweeps `${!ICLAUDE_@}`):

- Most `ICLAUDE_X` → `export X` (de-prefix), exported only when non-empty, so unset keys never override the existing environment.
- A native denylist (`_ICLAUDE_NATIVE_LIST`: `ICLAUDE_CHAT_LANG`, `ICLAUDE_DOC_LANG`, `ICLAUDE_NO_TELEMETRY`, `ICLAUDE_NO_AUTO_UPDATE`, plus runtime `ICLAUDE_PII_ACTIVE` / `ICLAUDE_PII_MASKING_LEVEL` / `ICLAUDE_PII_ACTIVE_PORT` / `ICLAUDE_PII_LOG_PATH`) is exported verbatim, never de-prefixed — hooks and the statusline read these under the `ICLAUDE_` name (see [[caveman]], [[pii-proxy]], [[statusline]]). The array names deliberately avoid the `ICLAUDE_` prefix so the sweep never mistakes them for config vars.
- An allow-empty set (`_ICLAUDE_ALLOW_EMPTY_LIST`: `ICLAUDE_PII_PROXY_MASK_TOKEN`) is exported even when set-but-empty (tested with `${!v+x}`), preserving the "empty token = no masking" semantic.

Every config-load site routes through `source_iclaude_config` — callers across `lib/` (caveman, proxy, nvm, sandbox) and the `iclaude.sh` install paths use it directly or via the `load_claude_config` wrapper. `load_claude_config` (in `lib/config/isolated.sh`) is a thin delegate kept for existing callers (`lib/nvm/setup.sh`, `lib/sandbox/status.sh`). Internal lib code still reads canonical names (`PROXY_URL`, `MICRO_VM_*`, see [[sandbox]]); the translation re-creates them, so consumers need no change.

## Parse-Time Toggles

`iclaude.sh` reads five boolean toggles by `grep` on the raw config file **before** any `source`, to seed CLI-equivalent flags: `ICLAUDE_USE_PII_PROXY`, `ICLAUDE_MICRO_VM_ENABLED`, `ICLAUDE_NO_ATTRIBUTION_HEADER`, `ICLAUDE_USE_CHROME`, `ICLAUDE_CLAUDE_CODE_SKIP_PERMISSIONS`. Each pattern matches `name=true` with optional `export `, whitespace, and single/double quotes, and only `=true` flips the flag. CLI flags parsed afterwards override these defaults. The greps match the `ICLAUDE_` names directly, since a pre-source grep cannot benefit from the translation layer.

## Legacy Auto-Migration

`migrate_legacy_config` (in `lib/config/env-map.sh`) runs once at boot from `iclaude.sh` — after `init_environment` sets `CREDENTIALS_FILE`, before both the parse-time grep block and any config source. `_config_is_legacy` flags a file containing any `export ` line or any active assignment whose name does not start with `ICLAUDE_`. Such a file is rewritten in place by `awk`: active assignments gain the `ICLAUDE_` prefix and lose `export`, while comments, prose, and indentation are preserved. A chmod-600 `.claude_config.bak` backup is written first (`cp -p`), the rewrite goes through a temp file + `mv` + `chmod 600`, and the operation is idempotent — once migrated, the file is no longer detected as legacy. Backup or rewrite failure leaves the original intact with a warning.

## Backup and Restore

`export_config` and `import_config` (in `lib/config/export.sh`) copy the config directory wholesale using `cp -r`.

`export_config <dest>` requires a destination, reads `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, errors if that source directory is missing, then copies its contents into the destination (creating it via `mkdir -p`). It prints size and location on success.

`import_config <src>` requires an existing source, copies from it into `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, and prompts `y/N` for confirmation if the target already exists (declining cancels). After copying it enforces `chmod 600` on `.credentials.json` when that file is present.

## Status Reporting

`check_config_status` (in `lib/config/status.sh`, behind `--check-isolated` and config-status commands — see [[command]]) prints the current `CLAUDE_CONFIG_DIR` path, directory size, presence and size of key files (`.credentials.json`, `history.jsonl`, `settings.json`), and presence, size, and item count of key subdirectories (`projects`, `session-env`, `file-history`, `todos`). It classifies the config type: `SHARED` when the path equals `$HOME/.claude`, `ISOLATED` when it contains `.nvm-isolated/.claude-isolated`, or `CUSTOM` otherwise. If the directory does not exist yet it reports that it will be created on first run.

## Isolated Environment Status

`check_isolated_status` (in `lib/config/status.sh`) shows the broader isolated environment: NVM installation path and size, Node.js and npm versions, Claude Code version (read from the binary at `$ISOLATED_NVM_DIR/npm-global/bin/claude` to avoid PATH conflicts with a system NVM), symlink health for `npm`, `npx`, `corepack`, and `claude`, and the full lockfile content (formatted via `jq` if available, else `cat`). Broken or missing symlinks are counted and direct the user to `--repair-isolated`. It then calls `show_native_installer_info` to emit an informational note when the installed Claude Code version is 2.1.0 or newer (parsed from the package's `package.json`), since Anthropic recommends the native installer for that generation — npm installs keep working, so no action is required. See [[nvm]] for the symlink repair flow and [[lockfile]] for lockfile details.
