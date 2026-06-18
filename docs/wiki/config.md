# Configuration

Configuration management for the isolated Claude Code environment: sets up the project-local `CLAUDE_CONFIG_DIR`, exports runtime environment variables from the credentials file, provides export/import backup, and reports the status of the config directory and the isolated NVM install. See [[architecture]] for how this fits into the startup sequence.

## Isolated Config Directory

`setup_isolated_config` (in `lib/config/isolated.sh`) creates `.nvm-isolated/.claude-isolated/` if it does not exist and then exports `CLAUDE_CONFIG_DIR` pointing at that path. This export is the primary isolation mechanism: Claude Code and all hooks read `CLAUDE_CONFIG_DIR` to locate their state, so pointing it at a project-local directory prevents cross-project state bleed without kernel-level sandboxing.

`ISOLATED_NVM_DIR` (set by `lib/core/init.sh`) drives the path; no configurable override exists.

## Auto-Update Suppression

`disable_auto_updates` (in `lib/config/isolated.sh`) sets `autoUpdates: false` in `$CLAUDE_CONFIG_DIR/.claude.json`. It uses `jq` to patch the file in place via a temporary file and only writes when the current value is `"true"`, leaving the file untouched otherwise. The function silently returns 0 if `jq` is not available or the file does not yet exist — Claude Code creates it on first launch.

This prevents Claude Code from updating itself; version management is delegated to `--update` / `--install-from-lockfile` (see [[update]] and [[lockfile]]).

## Environment Variable Export

`load_claude_config` (in `lib/config/isolated.sh`) sources `$CREDENTIALS_FILE` (`.claude_config` by default) and then conditionally exports every supported runtime variable. The full list covers:

- **Model selection**: `ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL`, `CLAUDE_CODE_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL`
- **Runtime limits**: `CLAUDE_CODE_MAX_OUTPUT_TOKENS`, `CLAUDE_CODE_EFFORT_LEVEL`, `CLAUDE_CODE_SESSION_TIMEOUT`
- **Feature flags**: `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`, `CLAUDE_CODE_DISABLE_1M_CONTEXT`, `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS`, `CLAUDE_CODE_ENABLE_TASKS`, `CLAUDE_CODE_NO_CHROME`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`, `CLAUDE_CODE_OAUTH_TOKEN`
- **PII proxy**: `PII_PROXY_MASKING_LEVEL`, `PII_PROXY_ENABLE_FALLBACK`, `PII_PROXY_LOG_LEVEL`, `PII_PROXY_MASK_TOKEN` (see [[pii-proxy]])
- **microVM**: `MICRO_VM_ENABLED`, `MICRO_VM_BACKEND`, `MICRO_VM_VCPU`, `MICRO_VM_MEM_MB`, and nine additional `MICRO_VM_*` variables (see [[sandbox]])
- **Language**: `ICLAUDE_CHAT_LANG`, `ICLAUDE_DOC_LANG` — conversation and documentation languages read by the caveman hooks (see [[caveman#Language Resolution]])

Only variables that are non-empty (or, for `PII_PROXY_MASK_TOKEN`, set at all via `+x`) are exported, so unset keys in `.claude_config` do not override existing environment values.

## Backup and Restore

`export_config` and `import_config` (in `lib/config/export.sh`) copy the config directory wholesale using `cp -r`.

`export_config <dest>` reads `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` and copies its contents into the destination directory, creating it if needed. It prints size and location on success.

`import_config <src>` copies from the source into `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, prompting for confirmation if the target already exists. After copying it enforces `chmod 600` on `.credentials.json` if that file is present.

## Status Reporting

`check_config_status` (in `lib/config/status.sh`) prints the current `CLAUDE_CONFIG_DIR` path, directory size, presence of key files (`.credentials.json`, `history.jsonl`, `settings.json`), and presence of key subdirectories (`projects`, `session-env`, `file-history`, `todos`). It also classifies the config type: `SHARED` when the path equals `$HOME/.claude`, `ISOLATED` when it contains `.nvm-isolated/.claude-isolated`, or `CUSTOM` otherwise.

`check_isolated_status` (in `lib/config/status.sh`) shows the broader isolated environment: NVM installation path and size, Node.js and npm versions, Claude Code version (read from the binary at `$ISOLATED_NVM_DIR/npm-global/bin/claude`), symlink health for `npm`, `npx`, `corepack`, and `claude`, and full lockfile content (via `jq` if available). It delegates to `show_native_installer_info` to emit an informational note when the installed Claude Code version is 2.1.0 or newer, since Anthropic recommends the native installer for that generation. Symlink issues direct the user to `--repair-isolated`. See also [[nvm]] for the symlink repair flow and [[lockfile]] for lockfile details.
