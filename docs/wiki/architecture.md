# iclaude Core Architecture

## Overview

iclaude (version 4.0) is a fully modular bash wrapper around Claude Code. It assembles feature capabilities by sourcing independent modules from `lib/` in a defined phase order, then executes an inline main body that parses CLI arguments, reads the credentials file, configures optional subsystems, and hands off to `launch_claude`. There is no single `main()` function — the top-level script body is Phase 15.

## Entry Point

`iclaude.sh` is the sole entry point. It begins by resolving its own absolute path through symlinks using `BASH_SOURCE[0]` and a `readlink` loop, then derives `LIB_DIR="${SCRIPT_DIR}/lib"`. All subsequent behaviour is driven by sourcing modules from that directory. The script runs under `set -euo pipefail`, so any sourced module that exits non-zero aborts the entire process.

After all modules are sourced, the script's inline Phase 15 body (lines 224–1018) performs:

1. Variable initialisation (flags, `claude_args` array, `model_value`, etc.).
2. Persistent-settings load from `CREDENTIALS_FILE` (`.claude_config`) via `grep` regex patterns.
3. `GRAPHIFY_OUT` default resolution.
4. `while [[ $# -gt 0 ]]` argument-parsing loop (`case` on `$1`).
5. Optional telemetry module load (`lib/telemetry/otel.sh`).
6. Subsystem activation: Graphify rebuild, lat.md MCP injection, isolated-config setup.
7. Proxy acquisition, validation, and test.
8. Final pre-launch flag assembly (`--dangerously-skip-permissions`, `--chrome`, `--model`).
9. `launch_claude "$use_system" "${claude_args[@]}"` — delegates to `lib/launcher/launch.sh`.

## Phase and Sourcing Order

Modules are sourced conditionally (`if [[ -d "$LIB_DIR/<name>" ]]`) so the script degrades gracefully when optional subsystems are absent. The load sequence is:

| Phase | Directory | Files sourced |
|-------|-----------|---------------|
| 0 | `core/` | `init.sh`, `logging.sh`, `validation.sh`, `json.sh`, `remaining.sh` |
| 2 | `proxy/` | `validate.sh`, `credentials.sh`, `configure.sh`, `git.sh` |
| 3 | `nvm/` | `detect.sh`, `setup.sh`, `install.sh`, `claude.sh`, `repair.sh`, `cleanup.sh` |
| 4 | `lockfile/` | `save.sh`, `install.sh` |
| 5 | `config/` | `isolated.sh`, `export.sh`, `status.sh` |
| 6 | `oauth/` | `token.sh` |
| 7 | `router/` | `detect.sh`, `install.sh`, `status.sh` |
| — | `pii-proxy/` | `detect.sh`, `install.sh`, `status.sh` |
| 8.0 | `graphify/` | `detect.sh`, `install.sh`, `status.sh` |
| 8.0.1 | `iwiki/` | `detect.sh`, `install.sh` |
| 8.5 | `lat/` | `detect.sh`, `install.sh`, `mcp.sh`, `check.sh` |
| 8.1 | `lsp/` | `install.sh`, `repair.sh`, `status.sh` |
| 8.2 | `statusline/` | `detect.sh`, `install.sh`, `status.sh` |
| 8.3 | `ohmyposh/` | `detect.sh`, `install.sh`, `status.sh` |
| 8.4 | `caveman/` | `install.sh` |
| 8.5 | `gsd/` | `detect.sh`, `install.sh`, `status.sh` |
| 9.1 | `sandbox/` | `detect.sh`, `install.sh`, `status.sh`, `microvm.sh` |
| 9.5 | `update/` | `isolated.sh`, `cleanup.sh`, `update.sh` |
| 9.6 | `launcher/` | `launch.sh` |
| 14 | `command/` | `usage.sh`, `parse.sh`, `dispatch.sh` |
| — | `chrome/` | `detection.sh` |

After Phase 14, Phase 15 (the inline main body) runs. `lib/telemetry/otel.sh` is loaded inside Phase 15, after argument parsing.

## Command Dispatch

All CLI argument dispatch is implemented directly in the Phase 15 `while`/`case` loop in `iclaude.sh`, not in `lib/command/dispatch.sh`. The two stubs in `lib/command/` — `parse_cli_arguments()` and `dispatch_command()` — are explicit placeholders marked for a post-v4.0 extraction; they are sourced but never called.

The dispatch pattern is:
- Flags that perform a one-shot operation (e.g. `--isolated-install`, `--check-router`, `--lat-check`) call their module function and `exit $?` immediately.
- Flags that modify launch behaviour (e.g. `--router`, `--pii-proxy`, `--graphify`, `--model`) set a boolean or string variable and `shift`, deferring actual activation to later in Phase 15.
- `--` separates iclaude flags from raw Claude Code arguments: everything after `--` is pushed into `claude_args` verbatim.
- Unrecognised arguments are appended to `claude_args` via the `*` branch, allowing pass-through to Claude Code.

Help text is provided by `show_usage()` in `lib/command/usage.sh`, called on `-h`/`--help` with immediate `exit 0`.

## Core Utilities

The five files in `lib/core/` are always sourced first (Phase 0) and provide the foundation all other modules depend on.

**`init.sh` — `init_environment()`**: Sets and exports all global constants immediately after sourcing. Key exports include `LAUNCH_DIR` (the user's `$PWD` at invocation, preserved before any `cd`), `SCRIPT_DIR`, `CREDENTIALS_FILE` (`.claude_config`), `ISOLATED_NVM_DIR` (`.nvm-isolated/`), `CLAUDE_CONFIG_DIR` (`.nvm-isolated/.claude-isolated/`), `ISOLATED_LOCKFILE` (`.nvm-isolated-lockfile.json`), and per-session state for PII proxy (`PII_PROXY_PID_FILE`), Graphify (`GRAPHIFY_UV_BIN`, `GRAPHIFY_TOOL_DIR`), CCR router (`CCR_HOST`, `CCR_PORT`), and microVM (`MICRO_VM_*`). A unique `ICLAUDE_SESSION_ID` (random hex) is generated per process to prevent port and PID file collisions between parallel sessions.

**`logging.sh`**: Four thin wrappers over `echo -e` that prepend ANSI-coloured symbols: `print_info` (blue ℹ), `print_success` (green ✓), `print_warning` (yellow ⚠), `print_error` (red ✗). All module output goes through these.

**`validation.sh`**: Three guard functions — `validate_dependency` (checks `command -v`), `validate_file_exists`, `validate_directory_exists` — each calling `print_error` and returning 1 on failure. Used throughout modules before operating on external tools or paths.

**`json.sh`**: Lockfile access via `jq`. `get_lockfile_field` reads a dotted path from `ISOLATED_LOCKFILE`, returning `"unknown"` for missing/null values. `set_lockfile_field` writes a value via a `mktemp` + atomic `mv` to avoid partial writes. `get_lockfile_object` reads a nested object, returning `{}` on absence. All three call `validate_dependency "jq"` before use. See [[lockfile#Lockfile Management]] for how the lockfile is populated.

**`remaining.sh`**: Legacy utility functions that were not extracted into dedicated modules during the v4.0 refactoring. Each function is guarded by `if ! declare -F <name> &>/dev/null` to allow a module to override it. Contains: `install_nodejs`, `install_claude_code`, `get_claude_version`, `check_update`, `check_dependencies`, `install_script`, `uninstall_script`, `create_symlink_only`, `uninstall_symlink_only`. The symlink commands install `iclaude` to `/usr/local/bin/iclaude` and require `sudo`.

## Isolated Environment

The isolated environment lives in `.nvm-isolated/` and provides a self-contained Node.js + Claude Code installation that does not interact with the system's global npm. `ISOLATED_NVM_DIR` and `ISOLATED_CONFIG_DIR` (`.nvm-isolated/.claude-isolated/`) are set by `init_environment()` and used by nearly every module. `CLAUDE_CONFIG_DIR` is initialised to `ISOLATED_CONFIG_DIR` and exported before Claude launches, redirecting all Claude Code configuration (credentials, settings, hooks) away from `~/.claude`. See [[nvm#Isolated Environment]] for install, repair, and detection details.

## Configuration File

The credentials/config file is `.claude_config` (formerly `.claude_proxy_credentials` — auto-migrated on first run). `init_environment()` sets `CREDENTIALS_FILE` to this path; Phase 15 reads it with `grep` regex patterns to load persistent flags (`USE_PII_PROXY`, `MICRO_VM_ENABLED`, `GRAPHIFY_OUT`, `GRAPHIFY_EXTRA_ARGS`, `NO_ATTRIBUTION_HEADER`, `USE_CHROME`, `CLAUDE_CODE_SKIP_PERMISSIONS`) before argument parsing, so CLI flags can override them. The file is chmod 600 and excluded from git. See [[config#Credentials File]] for the full variable reference.
