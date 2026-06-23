# LSP Integration

## Overview

Language Server Protocol support for Claude Code: installs LSP server binaries (npm) and Claude Code plugins for TypeScript/Python, repairs plugin-registry paths after a project moves or is cloned, reinstalls manifest-declared plugins, replays LSP entries from the lockfile, and reports installation status.

## Commands

The `lib/lsp/` functions are wired into the CLI dispatcher in `iclaude.sh`. `--install-lsp [LANGUAGES]` calls `install_isolated_lsp_servers` with the collected language list (`typescript`, `python`, `go`, `rust`); with no language it installs the defaults. `--check-lsp` calls `check_lsp_status`. `--install-lsp` is rejected when combined with `--system`. See [[command#Argument Parsing]] and [[launcher#Overview]] for the dispatch flow.

## Installation

`install_isolated_lsp_servers` (in `lib/lsp/install.sh`) installs LSP server npm packages and the matching Claude Code plugins. It takes a list of language names; with no arguments it defaults to `typescript` and `python`. It first runs `setup_isolated_nvm`, sources `nvm.sh`, and resolves the Claude binary via `get_nvm_claude_path` (aborting if Claude is not installed).

For TypeScript it runs `npm install -g @vtsls/language-server`, then uses `claude plugin list` to detect whether `typescript-lsp@claude-plugins-official` is already installed/enabled for the project, and calls `claude plugin install` or `claude plugin enable` with `-s project` scope accordingly. Python follows the same pattern with `pyright` (npm) and `pyright-lsp@claude-plugins-official`. Go and Rust are informational only — the function prints the manual `go install gopls` / `rustup component add rust-analyzer` commands plus the corresponding plugin install line, because those runtimes are not managed by npm. Unknown servers print an error.

After all servers are processed the function runs `hash -r` to clear bash's command cache, then calls `save_isolated_lockfile` (see [[lockfile#Save]]) so the new server and plugin versions are tracked immediately.

The installer handles both Claude Code invocation styles: the native binary path and the legacy `node cli.js` path, branching on whether `claude_path` begins with `node ` (see [[nvm#Claude Binary Detection]]).

## Lockfile Replay

LSP entries persisted by `save_isolated_lockfile` are replayed by `install_from_isolated_lockfile` (in `lib/lockfile/install.sh`), invoked via `--install-from-lockfile`. It reads `lspServers` and reinstalls each pinned version by name (`pyright`, `vtsls`, `typescript-language-server`), then reads `lspPlugins` and runs `claude plugin install <plugin> -s project` for each — again branching on the binary vs. `node cli.js` path. Requires `jq`; without it LSP replay is skipped with a warning. See [[lockfile#Install from Lockfile]].

## Plugin Manifest

`install_plugins_from_manifest` (in `lib/lsp/repair.sh`) reads `$ISOLATED_CONFIG_DIR/plugins-manifest.json` (falling back to `$ISOLATED_NVM_DIR/.claude-isolated/plugins-manifest.json`) and installs any declared plugins not yet present. It requires `jq`, resolves the Claude path, and exports `CLAUDE_CONFIG_DIR` from `ISOLATED_CONFIG_DIR` when not already set (the repair/update flow does not export it). It fetches the installed-plugin list once with `claude plugin list`, then for each `name@marketplace` does a fixed-string match and runs `claude plugin install <name>@<marketplace> -s project` for the missing ones. A summary reports how many were already installed, newly installed, or failed.

It is called during `--repair-isolated` so plugins declared in the manifest are present after a `git clone` even before `--install-lsp` is run manually. See [[nvm#Repair]] for the broader repair flow.

## Path Repair

`repair_plugin_paths` (in `lib/lsp/repair.sh`) fixes stale absolute paths in two plugin-registry files under `$ISOLATED_NVM_DIR/.claude-isolated/plugins/` after a project is moved or cloned. It accepts an optional `"quiet"` argument that suppresses all output, and returns 0 in all cases. It is called non-quietly during `--repair-isolated` and quietly at launch time from `setup_isolated_nvm` (see [[nvm#Environment Setup]]), so paths self-heal on every run.

`known_marketplaces.json` stores each marketplace's `installLocation`. The function reads the stored path for `claude-plugins-official` and, if it differs from the path computed from `$SCRIPT_DIR`, rewrites the field with `jq`. If `known_marketplaces.json` is missing but the `marketplaces/` directory exists (e.g. after `git rm` removed the registry), it recreates the JSON from the on-disk directories — pulling the canonical marketplace name from `.claude-plugin/marketplace.json` and the GitHub `repo` from the local `.git` remote when available.

`installed_plugins.json` (version-2 format: `{ version: 2, plugins: { "name@marketplace": [{ installPath, projectPath }] } }`) is fixed by finding the first `installPath` that does not contain `$SCRIPT_DIR`, extracting the old project-root prefix with `sed` (everything before `/.nvm-isolated`), and replacing every occurrence of it via `jq`'s `split/join` idiom across both `installPath` and `projectPath`.

## Status

`check_lsp_status` (in `lib/lsp/status.sh`) prints a status panel covering:

- **TypeScript LSP binary** — checks `vtsls` or `typescript-language-server` on `PATH`; reports version, else an install hint.
- **Python LSP binary** — checks `pyright` on `PATH`; reports the parsed `X.Y.Z` version, else an install hint.
- **Claude Code plugins** — runs `claude plugin list` (binary or `node cli.js` path) and parses the output for `typescript-lsp@claude-plugins-official` and `pyright-lsp@claude-plugins-official`, reporting version and enabled/disabled state. Falls back to a "not found" warning when the registry file (`$ISOLATED_NVM_DIR/.claude-isolated/plugins/installed_plugins.json`) is absent.
- **Lockfile tracking** — reads `.nvm-isolated-lockfile.json` (see [[lockfile#Save]]) and lists the `lspServers` and `lspPlugins` entries.

`jq` is required for the plugin-registry and lockfile display; the function warns and continues without it.
