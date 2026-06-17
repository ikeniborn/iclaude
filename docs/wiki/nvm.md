# NVM Module

The nvm module lives in `lib/nvm/` across six files: `setup.sh`, `detect.sh`, `install.sh`, `repair.sh`, `claude.sh`, and `cleanup.sh`. It manages an isolated Node.js environment under `.nvm-isolated/`, detects and locates the Claude Code binary, and handles installation, repair, and cleanup.

## Isolated Environment Overview

All Node.js tooling runs in a self-contained directory at `.nvm-isolated/` (exported as `ISOLATED_NVM_DIR` by `lib/core/init.sh`). This prevents interference with any system-level NVM or Node installation. The global npm prefix is set to `$ISOLATED_NVM_DIR/npm-global` (exported as `NPM_CONFIG_PREFIX`). Claude Code's config directory is `$ISOLATED_NVM_DIR/.claude-isolated` (exported as `ISOLATED_CONFIG_DIR` and, before Claude launches, re-exported as `CLAUDE_CONFIG_DIR`).

See also: [[architecture#Isolated Environment]].

## Environment Setup

`setup_isolated_nvm()` in `lib/nvm/setup.sh` activates the isolated environment for the current shell session. It exports `NVM_DIR`, `NPM_CONFIG_PREFIX`, and `ISOLATED_CONFIG_DIR`, then prepends `$NPM_CONFIG_PREFIX/bin` and the active Node.js `bin/` directory to `PATH`. The Node.js version directory is selected by sorting all `versions/node/v*` entries with `LC_ALL=C sort | tail -1` so the highest version wins deterministically across filesystems. After configuring `PATH`, it exports `CLAUDE_CODE_ENABLE_TASKS` (default `true`) and calls `load_claude_config()` from `lib/proxy/credentials.sh` to apply any saved proxy settings. It also silently calls `repair_plugin_paths()` if that function is defined.

See also: [[proxy#Credentials File]] (for `load_claude_config`).

## NVM and Node.js Detection

`detect_nvm()` in `lib/nvm/detect.sh` checks for a usable Node.js environment in three-priority order:

1. **Isolated environment** — if `USE_ISOLATED_BY_DEFAULT=true` and `.nvm-isolated/nvm.sh` exists, calls `setup_isolated_nvm()` and returns.
2. **System NVM** — checks `$NVM_DIR/nvm.sh`.
3. **PATH-based** — checks whether `npm` or `node` in `PATH` resolve to a path containing `.nvm`.

The optional `skip_isolated` argument (`"true"`) bypasses step 1, forcing use of the system NVM. This is used by the OAuth module when refreshing tokens without the isolated environment.

## Claude Binary Detection

`get_nvm_claude_path()` in `lib/nvm/detect.sh` locates the Claude Code binary. It first prefers the **isolated install** — `$NPM_CONFIG_PREFIX` (falling back to `$ISOLATED_NVM_DIR/npm-global`), checking `bin/claude`, then `lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe`, then that package's `cli.js`. This guarantees the lockfile-pinned isolated binary always wins over an inherited ambient `$NVM_DIR` (e.g. the user's `~/.nvm` loaded from `.bashrc`), which may hold an older Claude — or a stale `.claude-code-*` temp folder from an aborted npm install — that lacks newer flags like `plugin install --scope` and breaks iwiki plugin registration.

Only if the isolated binary is not found (e.g. during first-time bootstrap before install) does it fall back to searching two ambient contexts — the current `nvm current` version directory and the `npm prefix -g` path — applying the same priority order in each:

1. `bin/claude` (standard symlink)
2. `bin/.claude-*` (temporary binaries, newest by mtime)
3. `node_modules/@anthropic-ai/claude-code/bin/claude.exe` (native binary, v2.1.114+)
4. `node_modules/@anthropic-ai/claude-code/cli.js` (legacy Node.js entry point)
5. `node_modules/@anthropic-ai/.claude-code-*/cli.js` (temporary install folders, newest by mtime)

The return value is either a bare path (for native binary and symlink cases) or the string `node /path/to/cli.js` (for legacy cases). Callers must handle both forms.

`get_cli_version()` extracts the version string from `package.json` adjacent to `cli.js` or `claude.exe`.

## Installation

`lib/nvm/install.sh` provides three functions:

- **`install_isolated_nvm()`** — downloads NVM v0.39.7 from the upstream install script via `curl` and runs it with `NVM_DIR` set to the isolated directory. If a proxy is configured in `CREDENTIALS_FILE`, it sources that file and sets `HTTPS_PROXY`/`HTTP_PROXY` before the download. Uses `--cacert` in secure mode or `-k` in insecure mode.
- **`install_isolated_nodejs()`** — installs a specified Node.js version (default 20) via `nvm install` and activates it with `nvm use`.
- **`install_npm_package_with_lockfile()`** — generic installer used by all package installation paths (`install_isolated_claude`, router, LSP servers, etc.). Accepts a package name, a lockfile field name (e.g., `"claudeCodeVersion"`), and an optional version specifier. After `npm install -g`, it reads the installed version via `npm list -g --json` and writes it to `ISOLATED_LOCKFILE` using `set_lockfile_field()` from `lib/core/json.sh`.

## Claude Code Installation

`install_isolated_claude()` in `lib/nvm/claude.sh` is a thin wrapper around `install_npm_package_with_lockfile "@anthropic-ai/claude-code" "claudeCodeVersion"`.

`cleanup_old_claude_installations()` removes leftover `.claude-code-*` temporary directories under `node_modules/@anthropic-ai/` and stale `.claude-*` binaries in the npm-global bin directory. These are artifacts left by npm during install or update.

## Repair

`repair_isolated_environment()` in `lib/nvm/repair.sh` is invoked via `./iclaude.sh --repair-isolated`. It is the recommended first step after `git clone` because the native binary (`bin/claude.exe`, ~237 MB) is excluded from git. The repair sequence:

1. **`create_npm_symlinks()`** — recreates `npm`, `npx`, and `corepack` symlinks inside the Node.js version `bin/` directory.
2. **`create_claude_symlink()`** — verifies or recreates `$ISOLATED_NVM_DIR/npm-global/bin/claude` pointing to the native binary. If `claude.exe` is missing it runs `node install.cjs` (the package's own postinstall script). If that also fails, it installs the platform-specific package `@anthropic-ai/claude-code-<os>-<arch>` at the matching version and re-runs the postinstall.
3. **`repair_settings_paths()`** — migrates legacy absolute paths and `$CLAUDE_PROJECT_DIR`-based paths in `settings.json` to the portable `$CLAUDE_CONFIG_DIR` form.
4. **`repair_vendor_permissions()`** — restores the execute bit on `rg` and `*.node` binaries in the `vendor/` directory (git strips `+x`). Skips silently if `vendor/` does not exist (native binary format, v2.1.114+, bundles ripgrep internally).
5. **`configure_git_hooks()`** — sets `core.hooksPath=.githooks` so the tracked `post-merge` hook runs after `git pull`.

## Cleanup

`cleanup_isolated_nvm()` in `lib/nvm/cleanup.sh` deletes the entire `$ISOLATED_NVM_DIR` tree after an interactive confirmation prompt. The `ISOLATED_LOCKFILE` (`.nvm-isolated-lockfile.json`) is preserved so the environment can be reinstalled at the same pinned versions via `./iclaude.sh --install-from-lockfile`.

---

See also: [[architecture#Isolated Environment]], [[lockfile]], [[proxy#Configuration Entry Point]] (proxy used during NVM install), [[oauth#Automatic Token Refresh]] (uses `get_nvm_claude_path` to call `claude setup-token`).
