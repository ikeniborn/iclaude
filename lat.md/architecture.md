# Architecture

Modular bash wrapper around Claude Code CLI. Entry point `iclaude.sh` sources 21 modules from `lib/` in phase order, then dispatches to `launch_claude()`. No legacy dependencies since v4.0.

## Module Loading Phases

Modules load in fixed phase order to satisfy dependencies. Each phase guards with `[[ -d "$LIB_DIR/module" ]]` so missing modules are skipped gracefully.

| Phase | Module(s) | Purpose |
|-------|-----------|---------|
| 0 | `core/` | init, logging, validation, json, remaining |
| 2 | `proxy/` | validate, credentials, configure, git |
| 3 | `nvm/` | detect, setup, install, claude, repair, cleanup |
| 4 | `lockfile/` | save, install |
| 5 | `config/` | isolated, export, status |
| 6 | `oauth/` | token refresh |
| 7 | `router/` | CCR detect, install, status |
| 8 | `pii-proxy/` | Presidio NLP proxy |
| 8.1 | `sandbox/` | Firecracker microVM |
| — | `statusline/`, `chrome/`, `ohmyposh/`, `lsp/`, `gsd/`, `graphify/`, `lat/`, `telemetry/`, `caveman/` | optional features |
| 14 | `command/` | CLI parse + dispatch |

## Global Variables

Set by `[[lib/core/init.sh#init_environment]]` and exported before any module runs.

Key exports:

- `SCRIPT_DIR` — absolute path to `iclaude.sh` directory (follows symlinks)
- `CREDENTIALS_FILE` — `.claude_config` (secrets: proxy URL, API keys, flags)
- `ISOLATED_NVM_DIR` — `.nvm-isolated/` (isolated Node.js env)
- `CLAUDE_CONFIG_DIR` — `.nvm-isolated/.claude-isolated/` (Claude's config isolation)
- `ICLAUDE_SESSION_ID` — random hex per-session ID, prevents parallel session races
- `ICLAUDE_VERSION` — from `VERSION` file, fallback `"dev"`

## Entry Point

`iclaude.sh` resolves symlinks to find `SCRIPT_DIR`, loads phases in order, calls `init_environment()`, then falls through to `main()` which reads CLI flags and calls `launch_claude()`.

## Claude Binary Detection

`[[lib/nvm/detect.sh#get_nvm_claude_path]]` searches in priority order:

1. `$npm_prefix/bin/claude` symlink (standard)
2. `bin/claude.exe` native binary (v2.1.114+, ~237 MB, excluded from git)
3. `cli.js` via `node` (legacy pre-v2.1.114)
4. System `/usr/local/bin/claude`, `/usr/bin/claude`

If none found: context-aware error (exit 1). See [[lat.md/launch-flow#Binary-Absent Error Handling]].
