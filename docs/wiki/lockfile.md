# Lockfile

## Overview

The lockfile (`$ISOLATED_LOCKFILE`, resolved to `.nvm-isolated-lockfile.json` at project root) pins exact versions of every component in the isolated environment so the installation can be reproduced deterministically. It is committed to git. See [[update#Isolated Update]] for how the update flow writes the lockfile, and [[nvm]] for the NVM context in which it operates.

## Save

`save_isolated_lockfile` (in `lib/lockfile/save.sh`) snapshots the currently-installed state and writes it as JSON.

Version detection order for Claude Code:
1. Invoke `node cli.js --version` directly from the known package path (most reliable, works with broken symlinks).
2. Fall back to `claude --version` via `PATH` if the symlink is intact.
3. Fall back to parsing `package.json` under `npm-global/lib/node_modules/@anthropic-ai/claude-code/` as a last resort.

LSP server versions (`pyright`, `vtsls`, `typescript-language-server`) are detected by running each binary with `--version`, checking both `PATH` and `$NPM_CONFIG_PREFIX/bin` directly. LSP plugin versions are read from `claude plugin list` for four known plugins (`pyright-lsp`, `typescript-lsp`, `gopls-lsp`, `rust-analyzer-lsp`), recording only those with status `enabled`.

Additional fields captured:
- `nodeVersion`, `nvmVersion` — Node.js and NVM versions.
- `routerVersion` — Claude Code Router version via `$ccr_cmd --version`.
- `gsdVersion` — read from `$CLAUDE_CONFIG_DIR/.gsd-version` (written by GSD install); falls back to `npm view get-shit-done-cc version`.
- `latVersion` — read from `lat.md`'s `package.json` under `npm-global` (legacy field; lat was replaced by iwiki).
- `statusLineEnabled`, `statusLineScript` — result of `detect_statusline`.
- `ohMyPoshVersion`, `ohMyPoshPlatform`, `ohMyPoshInstalledAt` — Oh My Posh binary version.
- `installedAt` — UTC timestamp.

The JSON is written with `jq -n` (safe, no manual string escaping) and then `chmod 644`. After writing, `update_lockfile_hash` is called so the stored hash stays in sync. See [[lsp#Status]] for the LSP server/plugin fields.

## Install from Lockfile

`install_from_lockfile` (in `lib/lockfile/install.sh`) reads the lockfile and reinstalls every pinned component in order:

1. **NVM** — installs if `nvm.sh` is absent.
2. **Node.js** — runs `nvm install <nodeVersion>` with the version from the lockfile (`v` prefix stripped).
3. **Claude Code** — runs `npm install -g @anthropic-ai/claude-code@<claudeCodeVersion>`. Uses the latest version if `claudeCodeVersion` is absent or `"unknown"`.
4. **Router** — installs `@musistudio/claude-code-router@<routerVersion>` if the field is present and not `"not installed"`.
5. **GSD** — runs `npx get-shit-done-cc@<gsdVersion> --global` with `CLAUDE_CONFIG_DIR` forwarded, writing a `.gsd-version` marker on success.
6. **lat.md** (legacy) — ran `npm install -g lat.md@<latVersion>`; lat was replaced by iwiki (no install step in lockfile restore).
7. **LSP servers** — iterates `lspServers` keys and runs the appropriate `npm install -g <pkg>@<version>`.
8. **LSP plugins** — iterates `lspPlugins` keys and runs `claude plugin install <plugin> -s project`.

`jq` is required for steps 5 onward; missing `jq` causes a warning and skips LSP installation. On completion, `update_lockfile_hash` is called to mark the environment as applied. See [[lsp#Installation]] for the LSP server install details.

## Hash Tracking

Three functions in `lib/lockfile/save.sh` maintain a hash of the lockfile so the launcher can detect when a `git pull` has updated the pinned versions without the user running `--install-from-lockfile`.

`compute_lockfile_hash` computes a SHA-256 hash of `$ISOLATED_LOCKFILE` using `sha256sum` (Linux), `shasum -a 256` (macOS), or `md5sum` as a fallback.

`update_lockfile_hash` writes the hash to `$LOCKFILE_HASH_FILE` (a path under the isolated config directory). It is called automatically after every save or install.

`check_lockfile_changes` is called at launch. It compares the current hash to the stored hash:
- **No stored hash** (first run): silently initialises by writing the current hash and returns.
- **Hashes match**: returns immediately.
- **Hashes differ**: compares `claudeCodeVersion` in the lockfile against the real binary version (`claude --version`). If they already match — e.g., the lockfile was re-saved without changing the binary — it updates the hash and returns without warning. If they differ, it warns the user. In interactive mode it prompts to run `install_from_lockfile` immediately; in non-interactive mode it prints a warning only and does not block launch.

See [[update#Post-Merge Refresh]] for the complementary git hook that triggers after `git pull`.
