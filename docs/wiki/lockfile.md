# Lockfile

## Overview

The lockfile (`$ISOLATED_LOCKFILE` = `.nvm-isolated-lockfile.json` at repo root) pins exact versions of every isolated-environment component for reproducible installs. `Save` snapshots state to JSON, `Install from Lockfile` restores it, and `Hash Tracking` detects when a `git pull` changed the pinned versions. See [[update#Isolated Update]] and [[nvm]].

## Save

`save_isolated_lockfile` (in `lib/lockfile/save.sh`) sources NVM, snapshots the currently-installed state, and writes it as JSON via `jq -n`. `$ISOLATED_LOCKFILE` and `$LOCKFILE_HASH_FILE` are defined in [[core#Environment Initialization]] (`lib/core/init.sh`).

Claude Code version detection runs in order (most reliable first):
1. `node cli.js --version` from the package path under `npm-global/lib/node_modules/@anthropic-ai/claude-code/` — works even with broken symlinks.
2. `claude --version` via `PATH` if the symlink is intact.
3. Parse `"version"` from that package's `package.json` as last resort; `"unknown"` if all fail.

LSP server versions (`pyright`, `vtsls`, `typescript-language-server`) are detected by running each binary `--version`, checking both `PATH` and `$NPM_CONFIG_PREFIX/bin` directly. LSP plugin versions come from `claude plugin list`, scanning four marketplace-qualified plugins (`pyright-lsp@claude-plugins-official`, `typescript-lsp@claude-plugins-official`, `gopls-lsp@claude-plugins-official`, `rust-analyzer-lsp@claude-plugins-official`) and recording only those reporting `enabled`. See [[lsp#Status]].

Additional fields captured in the JSON:
- `nodeVersion`, `nvmVersion` — from `node --version` and `nvm --version`.
- `routerVersion` — `$ccr_cmd --version` (`"not installed"` if no router path). See [[router]].
- `gsdVersion` — read from `$CLAUDE_CONFIG_DIR/.gsd-version` (offline/instant); falls back to `npm view get-shit-done-cc version`; `"not installed"` when GSD is absent. See [[gsd]].
- `statusLineEnabled` (boolean), `statusLineScript` — from `detect_statusline`. See [[statusline]].
- `ohMyPoshVersion`, `ohMyPoshPlatform`, `ohMyPoshInstalledAt` — from `detect_ohmyposh` / `get_ohmyposh_path`. See [[ohmyposh]].
- `installedAt` — UTC timestamp (`date -u`).

After writing, the file is `chmod 644`, its content is echoed for verification, a warning is printed if the Claude version is `unknown`, and `update_lockfile_hash` is called so the stored hash stays in sync. Note: there is no `latVersion` field — lat.md was replaced by [[iwiki]] and is not tracked in the lockfile.

## Install from Lockfile

`install_from_lockfile` (in `lib/lockfile/install.sh`) reads the lockfile and reinstalls every pinned component in order. Most fields are parsed with `grep -oP`; `jq` is used for GSD and LSP fields.

1. **NVM** — runs `install_isolated_nvm` if `nvm.sh` is absent, then `setup_isolated_nvm`. See [[nvm#Installation]].
2. **Node.js** — `nvm install <nodeVersion>` then `nvm use` (the `v` prefix is stripped; defaults to `18` if the field is missing).
3. **Claude Code** — `npm install -g @anthropic-ai/claude-code@<claudeCodeVersion>`; installs latest when the version is absent or `"unknown"`.
4. **Router** — `npm install -g @musistudio/claude-code-router@<routerVersion>` when set and not `"not installed"`/`"unknown"` (failure is non-critical).
5. **GSD** — `npx get-shit-done-cc@<gsdVersion> --global` with `CLAUDE_CONFIG_DIR` forwarded, writing a `.gsd-version` marker on success (skipped if `"not installed"`/`"unknown"`; failure non-critical).
6. **LSP servers** — for each `lspServers` key: `pyright` → `pyright@<v>`, `vtsls` → `@vtsls/language-server@<v>`, `typescript-language-server` → `typescript-language-server@<v>`.
7. **LSP plugins** — for each `lspPlugins` key: `claude <cli> plugin install <plugin> -s project` (run from `$SCRIPT_DIR`, handling both binary and `node cli.js` invocation forms).

Steps 6–7 require `jq`; a missing `jq` prints a warning and skips LSP installation. On completion, `update_lockfile_hash` is called (if defined) to mark the environment as applied. See [[lsp#Installation]].

## Hash Tracking

Three functions in `lib/lockfile/save.sh` maintain a hash of the lockfile so the launcher can detect a `git pull` that changed pinned versions without the user running `--install-from-lockfile`.

`compute_lockfile_hash` hashes `$ISOLATED_LOCKFILE` with `sha256sum` (Linux), `shasum -a 256` (macOS), or `md5sum` (fallback).

`update_lockfile_hash` writes the hash to `$LOCKFILE_HASH_FILE` (`.nvm-isolated/.claude-isolated/.last-lockfile-hash`), creating the parent directory if needed. It is called automatically after every save or install.

`check_lockfile_changes` is called at launch and compares the current hash to the stored one:
- **No lockfile** or **empty hash** → returns silently.
- **No stored hash** (first run) → initialises by writing the current hash, returns.
- **Hashes match** → returns immediately.
- **Hashes differ** → reads `claudeCodeVersion` from the lockfile and compares it to the real on-disk binary. The binary checked is `npm-global/bin/claude`, falling back to the native `…/@anthropic-ai/claude-code/bin/claude.exe`. If the installed version already matches the lockfile, the hash is refreshed and it returns without warning. Otherwise it warns: in interactive mode it prompts `[y/N]` to run `install_from_lockfile` now; in non-interactive mode (CI/GUI) it prints the warning only. Launch is never blocked.

The lockfile-version check (not `package.json`) is deliberate: `package.json` is git-tracked and bumped by the pull, so the native binary's `--version` is the authoritative "what is installed" signal. See [[update#Post-Merge Refresh]] for the complementary git hook that fires after `git pull`.
