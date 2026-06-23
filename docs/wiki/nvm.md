# NVM Module

## Overview

The nvm module (`lib/nvm/`) manages a self-contained Node.js environment under `.nvm-isolated/`. Across six files — `setup.sh`, `detect.sh`, `install.sh`, `repair.sh`, `claude.sh`, `cleanup.sh` — it activates the isolated env, detects the Claude Code binary, and handles install, repair, and cleanup.

## Isolated Environment Overview

All Node.js tooling runs in `.nvm-isolated/` (exported as `ISOLATED_NVM_DIR` by `lib/core/init.sh`), isolating it from any system NVM or Node install. The global npm prefix is `$ISOLATED_NVM_DIR/npm-global` (`NPM_CONFIG_PREFIX`). Claude's config dir is `$ISOLATED_NVM_DIR/.claude-isolated` (`ISOLATED_CONFIG_DIR`, re-exported as `CLAUDE_CONFIG_DIR` before launch).

See also: [[architecture#Isolated Environment]].

## Environment Setup

`setup_isolated_nvm()` in `lib/nvm/setup.sh` activates the isolated environment for the current shell. It exports `NVM_DIR` (set to `ISOLATED_NVM_DIR`), `NPM_CONFIG_PREFIX` (`$NVM_DIR/npm-global`), and `ISOLATED_CONFIG_DIR`, then prepends `$NPM_CONFIG_PREFIX/bin` and the active Node.js `bin/` to `PATH`. The Node.js version directory is selected by listing all `versions/node/v*` entries and applying `LC_ALL=C sort | tail -1`, so the highest version wins deterministically regardless of filesystem order (find output is non-deterministic on ext4/CI). If no `bin/` is found, it falls back to adding only `$NPM_CONFIG_PREFIX/bin` and warns. It then exports `CLAUDE_CODE_ENABLE_TASKS` (default `true`), calls `load_claude_config()` (defined in `lib/config/isolated.sh`) to apply saved config, and silently runs `repair_plugin_paths "quiet"` if that function is defined.

See also: [[config#Isolated Config Directory]], [[proxy#Credentials File]].

## NVM and Node.js Detection

`detect_nvm()` in `lib/nvm/detect.sh` checks for a usable Node.js environment in three-priority order:

1. **Isolated environment** — if `USE_ISOLATED_BY_DEFAULT=true`, `$ISOLATED_NVM_DIR` exists, and `.nvm-isolated/nvm.sh` is non-empty, calls `setup_isolated_nvm()` and returns.
2. **System NVM** — `$NVM_DIR` is set and `$NVM_DIR/nvm.sh` is non-empty.
3. **PATH-based** — `npm` or `node` in `PATH` resolves to a path containing `.nvm`.

The optional first argument `skip_isolated` (`"true"`) bypasses step 1, forcing the system NVM. This is used by the OAuth module when refreshing tokens outside the isolated environment.

## Claude Binary Detection

`get_nvm_claude_path()` in `lib/nvm/detect.sh` locates the Claude Code binary. It first prefers the **isolated install** — `$NPM_CONFIG_PREFIX` (falling back to `$ISOLATED_NVM_DIR/npm-global`), checking `bin/claude`, then `lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe`, then that package's `cli.js`. This guarantees the lockfile-pinned isolated binary wins over an inherited ambient `$NVM_DIR` (e.g. the user's `~/.nvm` loaded from `.bashrc`), which may hold an older Claude — or a stale `.claude-code-*` temp folder from an aborted npm install — that lacks newer flags like `plugin install --scope` and breaks iwiki plugin registration.

Only if the isolated binary is not found (e.g. during first-time bootstrap) does it fall back to two ambient contexts — the current `nvm current` version directory and the `npm prefix -g` path (both gated on the path containing `.nvm`) — applying the same priority order in each:

1. `bin/claude` (standard symlink)
2. `bin/.claude-*` (temporary binaries, newest by mtime via `ls -t`)
3. `node_modules/@anthropic-ai/claude-code/bin/claude.exe` (native binary, v2.1.114+)
4. `node_modules/@anthropic-ai/claude-code/cli.js` (legacy Node.js entry point)
5. `node_modules/@anthropic-ai/.claude-code-*/cli.js` (temporary install folders, newest by mtime via `find -printf '%T@' | sort -rn`)

The return value is either a bare path (native binary and symlink cases) or the string `node /path/to/cli.js` (legacy cases). Callers must handle both forms.

`get_cli_version()` extracts the `version` field (via `grep -oP`) from the `package.json` adjacent to `cli.js` or `claude.exe`, accepting either return form; it echoes `unknown` and returns 1 when the file or field is missing.

## Installation

`lib/nvm/install.sh` provides three functions:

- **`install_isolated_nvm()`** — downloads NVM v0.39.7 from the upstream install script via `curl` and runs it with `NVM_DIR` set to the isolated directory. If `CREDENTIALS_FILE` exists, it sources it (`source_iclaude_config`) and, when `PROXY_URL` is set, exports `HTTPS_PROXY`/`HTTP_PROXY` plus a default `NO_PROXY` (localhost + common git hosts) for the download. It uses `--cacert "$PROXY_CA"` in secure mode or `-k` in insecure mode, and unsets the lowercase proxy variables before `curl` to avoid conflicts.
- **`install_isolated_nodejs()`** — installs a Node.js version (default `20`) via `nvm install` then `nvm use`. Requires NVM to be installed first; skips reinstall if the version is already present.
- **`install_npm_package_with_lockfile()`** — generic installer shared by all package paths (Claude, router, LSP servers, etc.). Takes a package name, a lockfile field name (e.g. `"claudeCodeVersion"`), and an optional version specifier (default `latest`). After `npm install -g`, it reads the installed version via `npm list -g --json | jq` and writes it to `ISOLATED_LOCKFILE` using `set_lockfile_field()` from `lib/core/json.sh` (with a manual `jq` fallback if that function is absent).

See also: [[lockfile#Save]], [[proxy#Configuration Entry Point]].

## Claude Code Installation

`install_isolated_claude()` in `lib/nvm/claude.sh` is a thin wrapper around `install_npm_package_with_lockfile "@anthropic-ai/claude-code" "claudeCodeVersion"`.

`cleanup_old_claude_installations()` removes leftover `.claude-code-*` temporary directories under `versions/node/.../@anthropic-ai/` and stale `.claude-*` binaries in the npm-global bin directory — artifacts npm leaves during install or update.

## Repair

`repair_isolated_environment()` in `lib/nvm/repair.sh` is invoked via `./iclaude.sh --repair-isolated`. It is the recommended first step after `git clone` because the native binary (`bin/claude.exe`, ~237 MB) is excluded from git. It first locates the Node.js version directory (same `LC_ALL=C sort | tail -1` selection as setup), then runs:

1. **`create_npm_symlinks()`** — recreates the `npm`, `npx`, and `corepack` symlinks inside the Node.js version `bin/` directory.
2. **`create_claude_symlink()`** — verifies or recreates `$ISOLATED_NVM_DIR/npm-global/bin/claude` pointing to the native binary. If `claude.exe` is missing it creates `bin/` and runs `node install.cjs` (the package's postinstall). If still missing, it installs the platform-specific package `@anthropic-ai/claude-code-<os>-<arch>` at the matching `package.json` version (arch normalized: `x86_64`→`x64`, `aarch64`/`arm64`→`arm64`) and re-runs the postinstall.
3. **`repair_settings_paths()`** — migrates legacy absolute paths and `$CLAUDE_PROJECT_DIR/.nvm-isolated/.claude-isolated` paths in `settings.json` to the portable `$CLAUDE_CONFIG_DIR` form, then chmods the file `600`.
4. **`repair_plugin_paths()`** (if defined) — repairs plugin registry files (e.g. recreates `known_marketplaces.json` if removed).
5. **`repair_vendor_permissions()`** — restores the execute bit on `rg` and `*.node` binaries in `vendor/` (git strips `+x`). Skips silently when `vendor/` is absent (native binary format, v2.1.114+, bundles ripgrep internally).
6. **`configure_git_hooks()`** — sets `core.hooksPath=.githooks` so the tracked `post-merge` hook runs after `git pull`.
7. **`install_plugins_from_manifest()`** (if defined) — reinstalls plugins listed in `plugins-manifest.json`.

After the summary it also warns when the PII proxy venv is missing (not tracked in git), prompting `--install-pii-proxy`.

See also: [[update#Post-Merge Refresh]], [[pii-proxy#Installation]].

## Cleanup

`cleanup_isolated_nvm()` in `lib/nvm/cleanup.sh` deletes the entire `$ISOLATED_NVM_DIR` tree after an interactive `y/N` confirmation (showing the directory size). The `ISOLATED_LOCKFILE` (`.nvm-isolated-lockfile.json`) is preserved so the environment can be reinstalled at the same pinned versions via `./iclaude.sh --install-from-lockfile`.

---

See also: [[architecture#Isolated Environment]], [[lockfile]], [[oauth#Automatic Token Refresh]] (uses `get_nvm_claude_path` to call `claude setup-token`), [[update#Update Flow]].
