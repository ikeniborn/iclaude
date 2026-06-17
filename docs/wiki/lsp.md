# LSP Integration

Language Server Protocol support for Claude Code: installs server binaries and Claude Code plugins for TypeScript and Python, repairs plugin registry paths after project moves, and reports installation status with lockfile tracking.

## Installation

`install_isolated_lsp_servers` (in `lib/lsp/install.sh`) installs LSP server npm packages and the corresponding Claude Code plugins. It accepts a list of language names (`typescript`, `python`, `go`, `rust`); with no arguments it defaults to `typescript` and `python`.

For TypeScript, it installs `@vtsls/language-server` via `npm install -g`, then checks whether `typescript-lsp@claude-plugins-official` is already installed and enabled for the project (via `claude plugin list`). Depending on that check it calls `claude plugin install` or `claude plugin enable` with `-s project` scope. For Python the same pattern applies with `pyright` (npm) and `pyright-lsp@claude-plugins-official` (plugin). Go and Rust are handled informatively — the function prints the manual install commands because those runtimes are not managed by npm. After all servers are processed the function calls `save_isolated_lockfile` (see [[lockfile#Save]]) so the new versions are tracked immediately.

The installer handles both invocation styles of Claude Code: the native binary path and the legacy `node cli.js` path, branching on whether `claude_path` starts with `node `.

## Plugin Manifest

`install_plugins_from_manifest` (in `lib/lsp/repair.sh`) reads `$ISOLATED_CONFIG_DIR/plugins-manifest.json` and installs any plugins listed there that are not yet present. It obtains the list of already-installed plugins once with `claude plugin list`, then iterates the manifest, calling `claude plugin install <name>@<marketplace> -s project` for each missing entry. A summary line reports how many were already installed, newly installed, or failed.

This function is called during `--repair-isolated` so that any plugins declared in the manifest are present after a `git clone` even before `--install-lsp` is invoked manually. See [[nvm#Repair]] for the broader repair flow.

## Path Repair

`repair_plugin_paths` (in `lib/lsp/repair.sh`) fixes stale absolute paths that appear in two plugin registry files after a project is moved or cloned to a different directory.

`known_marketplaces.json` stores the `installLocation` of each marketplace. The function reads the stored path for `claude-plugins-official` and, if it differs from the path computed from `$SCRIPT_DIR`, rewrites the field with `jq`. If `known_marketplaces.json` is missing but the `marketplaces/` directory exists (e.g., after `git rm` deleted the file), the function recreates the JSON from the on-disk directories, pulling the canonical marketplace name from `.claude-plugin/marketplace.json` and the GitHub remote from the local `.git` remote.

`installed_plugins.json` (version-2 format: `{ version: 2, plugins: { "name@marketplace": [{ installPath, projectPath }] } }`) is fixed by finding the first `installPath` that does not contain `$SCRIPT_DIR`, extracting the old project root prefix via `sed`, and replacing every occurrence using `jq`'s `split/join` idiom.

An optional `"quiet"` argument suppresses all printed output; the function returns 0 in all cases.

## Status

`check_lsp_status` (in `lib/lsp/status.sh`) prints a status panel covering:

- **TypeScript LSP binary** — checks `vtsls` or `typescript-language-server` on `PATH`; reports version.
- **Python LSP binary** — checks `pyright` on `PATH`; reports version.
- **Claude Code plugins** — calls `claude plugin list` and parses the output for `typescript-lsp@claude-plugins-official` and `pyright-lsp@claude-plugins-official`, reporting version and enabled/disabled state. Reads the plugin registry from `$ISOLATED_NVM_DIR/.claude-isolated/plugins/installed_plugins.json`.
- **Lockfile tracking** — reads `.nvm-isolated-lockfile.json` (see [[lockfile#Save]]) and displays the `lspServers` and `lspPlugins` objects.

`jq` is required for lockfile display; the function warns and continues without it.
