# Core Module

The core module lives in `lib/core/` across five files: `init.sh`, `logging.sh`, `validation.sh`, `json.sh`, and `remaining.sh`. It defines all global environment variables, colored output helpers, dependency/file validators, lockfile JSON accessors, and a set of legacy installation/update utilities sourced first in the launch sequence (Phase 0).

## Environment Initialization

`init_environment()` in `init.sh` is the single entry point that resolves paths and exports every global the rest of the wrapper depends on. It runs before any feature module and seeds the isolated-environment layout described in [[architecture#Isolated Environment]].

`resolve_script_directory()` walks `BASH_SOURCE` through any symlinks to compute the real script location. `init_environment()` then sets and exports:

- `LAUNCH_DIR` — the user's `$PWD` captured before any `cd`.
- `SCRIPT_DIR` — resolved project root.
- `ICLAUDE_VERSION` — read from the `VERSION` file, defaulting to `dev`.
- `CONFIG_FILE` / `CREDENTIALS_FILE` — `.claude_config` at project root. A legacy `.claude_proxy_credentials` is auto-migrated to `.claude_config` on first run.
- `GIT_BACKUP_FILE` — `.claude_git_proxy_backup`.
- `ISOLATED_NVM_DIR` — `.nvm-isolated/`.
- `ISOLATED_CONFIG_DIR` / `CLAUDE_CONFIG_DIR` — `.nvm-isolated/.claude-isolated/`.
- `ISOLATED_LOCKFILE` — `.nvm-isolated-lockfile.json`.
- `LOCKFILE_HASH_FILE` — stored hash path under the isolated config dir.
- `USE_ISOLATED_BY_DEFAULT` (`true`) and `TOKEN_REFRESH_THRESHOLD` (`604800`, 7 days).

See [[nvm#Isolated Environment Overview]] and [[config]] for how these paths are consumed.

## Per-Session Isolation

`ICLAUDE_SESSION_ID` is a unique per-session identifier (6 random bytes from `/dev/urandom`, with a `RANDOM`-based fallback) used to scope PID and port files so parallel `iclaude` sessions do not collide. It is inherited if already set, so subshells of the same session share one ID.

This ID is woven into per-session state filenames such as `PII_PROXY_PID_FILE` (`${PII_PROXY_PID_DIR}/${ICLAUDE_SESSION_ID}.pid`).

## Feature Variable Exports

Beyond the core paths, `init_environment()` initializes and exports the variable sets consumed by individual feature modules, each honoring an existing value or a default. These are grouped by feature.

- **PII proxy** — `PII_PROXY_PORT` (`0` = auto-select), `PII_PROXY_PORT_MIN` (`20000`), `PII_PROXY_PORT_MAX` (`40000`), `PII_PROXY_VENV`, `PII_PROXY_LOG_DIR`, `PII_PROXY_PID_DIR`, `PII_PROXY_PID_FILE`, `PII_PROXY_SERVER_SCRIPT`. See [[pii-proxy]].
- **Graphify** — `GRAPHIFY_UV_BIN`, `GRAPHIFY_TOOL_DIR`, `GRAPHIFY_PYTHON_DIR`, `GRAPHIFY_EXTRA_ARGS`. See [[graphify]].
- **CCR (Claude Code Router)** — `CCR_PID`, `CCR_SESSION_OWNED` (`false`), `CCR_HOST` (`127.0.0.1`), `CCR_PORT` (`3456`). See [[router]].
- **microVM (Firecracker)** — `MICRO_VM_ENABLED`, `MICRO_VM_BACKEND` (`firecracker`), `MICRO_VM_VCPU`, `MICRO_VM_MEM_MB`, networking (`MICRO_VM_NET_*`), snapshot (`MICRO_VM_SNAPSHOT_*`), image paths (`MICRO_VM_ROOTFS_PATH`, `MICRO_VM_KERNEL_PATH`, `MICRO_VM_BIN_PATH`), and per-session state (`MICRO_VM_PID`, `MICRO_VM_SOCKET`, `MICRO_VM_SESSION_OWNED`, `VIRTIOFSD_PID_NVM`, `VIRTIOFSD_PID_WORKSPACE`). See [[sandbox]].

## Color Constants and Logging

`init.sh` defines and exports the ANSI color codes `RED`, `GREEN`, `YELLOW`, `BLUE`, and `NC` (no color). `logging.sh` builds four print helpers on top of them, each taking a single message argument and always returning `0`.

- `print_info` — blue `ℹ` prefix.
- `print_success` — green `✓` prefix.
- `print_warning` — yellow `⚠` prefix.
- `print_error` — red `✗` prefix.

These helpers are used throughout every `lib/` module for user-facing output.

## Validation

`validation.sh` provides three precondition checks. Each prints an error via `print_error` and returns `1` on failure, `0` on success.

- `validate_dependency <cmd> [install_hint]` — verifies a command exists via `command -v`; prints the optional install hint when missing.
- `validate_file_exists <path>` — checks `-f`.
- `validate_directory_exists <path>` — checks `-d`.

## Lockfile JSON Access

`json.sh` wraps `jq` to read and write the isolated environment's lockfile at `$ISOLATED_LOCKFILE`. Each function validates that `jq` is installed before proceeding. See [[lockfile]] for the lockfile's fields and lifecycle.

- `get_lockfile_field <path>` — reads a scalar via `jq -r ".<path> // \"unknown\""`; prints `unknown` and returns `1` when the lockfile is missing or the value is null/empty.
- `set_lockfile_field <path> <value>` — writes a value, creating `{}` if the lockfile is absent, then commits atomically via a `mktemp` file and `mv`.
- `get_lockfile_object <path>` — reads a nested object via `jq -r ".<path> // {}"`, printing `{}` on missing file or null.

## Legacy Utilities

`remaining.sh` holds utility functions carried over from the pre-modular script (extracted in Phase 15). Each is guarded by `declare -F ... &>/dev/null` so it is only defined if not already present. They operate on the system (non-isolated) Node/Claude install and the global symlink.

- `install_nodejs`, `install_claude_code` — system Node.js (NodeSource setup) and global Claude Code installs.
- `get_claude_version`, `check_update`, `check_dependencies` — version detection and an npm-based update check; rely on `detect_nvm` and `get_nvm_claude_path` from [[nvm]].
- `install_script`, `uninstall_script`, `create_symlink_only`, `uninstall_symlink_only` — manage the `/usr/local/bin/iclaude` symlink (require `sudo`). `create_symlink_only` requires the isolated environment to already exist.

See [[update]] for the modern isolated update flow that supersedes `check_update`.

See also: [[architecture#Isolated Environment]], [[nvm]], [[lockfile]], [[config]].
