# Core Module

## Overview

The core module lives in `lib/core/` across five files: `init.sh`, `logging.sh`, `validation.sh`, `json.sh`, and `remaining.sh`. It defines all global environment variables, colored output helpers, dependency/file validators, lockfile JSON accessors, and a set of legacy installation/update utilities sourced first in the launch sequence (Phase 0). Covers environment initialization, per-session isolation, feature variable exports, color/logging helpers, validation, lockfile JSON access, and legacy utilities.

## Environment Initialization

`init_environment()` in `init.sh` is the single entry point that resolves paths and exports every global the rest of the wrapper depends on. It runs before any feature module and seeds the isolated-environment layout described in [[architecture#Isolated Environment]].

`resolve_script_directory()` walks `BASH_SOURCE[1]` (the caller's path) through any symlinks to compute the real script location. `init_environment()` then sets and exports:

- `LAUNCH_DIR` — the user's `$PWD` captured before any `cd`.
- `SCRIPT_DIR` — resolved project root.
- `ICLAUDE_VERSION` — read from the `VERSION` file (whitespace stripped), defaulting to `dev` when missing or empty.
- `CONFIG_FILE` / `CREDENTIALS_FILE` — `.claude_config` at project root (`CREDENTIALS_FILE` is an alias for `CONFIG_FILE`). A legacy `.claude_proxy_credentials` is auto-migrated to `.claude_config` on first run when the new file is absent.
- `GIT_BACKUP_FILE` — `.claude_git_proxy_backup`.
- `ISOLATED_NVM_DIR` — `.nvm-isolated/`.
- `ISOLATED_CONFIG_DIR` / `CLAUDE_CONFIG_DIR` — `.nvm-isolated/.claude-isolated/` (the latter is set equal to the former so hooks read the isolated config dir).
- `ISOLATED_LOCKFILE` — `.nvm-isolated-lockfile.json`.
- `LOCKFILE_HASH_FILE` — `.last-lockfile-hash` under the isolated config dir.
- `USE_ISOLATED_BY_DEFAULT` (`true`) and `TOKEN_REFRESH_THRESHOLD` (`604800`, 7 days).

See [[nvm#Isolated Environment Overview]] and [[config]] for how these paths are consumed.

## Per-Session Isolation

`ICLAUDE_SESSION_ID` is a unique per-session identifier (6 random bytes from `/dev/urandom` via `od`, with a `RANDOM`-based `printf '%012x'` fallback) used to scope PID and port files so parallel `iclaude` sessions do not collide. It is inherited if already set, so subshells of the same session share one ID.

This ID is woven into per-session state filenames such as `PII_PROXY_PID_FILE` (`${PII_PROXY_PID_DIR}/${ICLAUDE_SESSION_ID}.pid`).

## Feature Variable Exports

Beyond the core paths, `init_environment()` initializes and exports the variable sets consumed by individual feature modules, each honoring an existing value (via `${VAR:-default}`) or a default. These are grouped by feature.

- **PII proxy** — `PII_PROXY_PORT` (`0` = auto-select), `PII_PROXY_PORT_MIN` (`20000`), `PII_PROXY_PORT_MAX` (`40000`), `PII_PROXY_VENV`, `PII_PROXY_LOG_DIR`, `PII_PROXY_PID_DIR`, `PII_PROXY_PID_FILE`, `PII_PROXY_SERVER_SCRIPT`. See [[pii-proxy]].
- **uv** — `UV_BIN` (`${ISOLATED_NVM_DIR}/bin/uv`), the isolated uv binary consumed by [[iwiki]].
- **CCR (Claude Code Router)** — `CCR_PID` (empty), `CCR_SESSION_OWNED` (`false`), `CCR_HOST` (`127.0.0.1`), `CCR_PORT` (`3456`). See [[router]].
- **microVM (Firecracker)** — config defaults `MICRO_VM_ENABLED` (`false`), `MICRO_VM_BACKEND` (`firecracker`), `MICRO_VM_VCPU` (`2`), `MICRO_VM_MEM_MB` (`1024`), `MICRO_VM_LOG_LEVEL` (`warn`), `MICRO_VM_PROXY_PASS` (`true`), `MICRO_VM_MOUNT_WORKSPACE` (`true`); networking `MICRO_VM_NET_ENABLED` (`true`), `MICRO_VM_NET_TAP_IFACE` (`tap-iclaude`), `MICRO_VM_NET_HOST_IP` (`172.16.0.1`), `MICRO_VM_NET_GUEST_IP` (`172.16.0.2`); snapshot `MICRO_VM_SNAPSHOT_ENABLED` (`false`), `MICRO_VM_SNAPSHOT_DIR`; image/work paths `MICRO_VM_ROOTFS_PATH` (`bin/rootfs.ext4`), `MICRO_VM_KERNEL_PATH` (`bin/vmlinux`), `MICRO_VM_BIN_PATH` (`bin/firecracker`), `MICRO_VM_WORK_DIR` (`microvm-run`); and per-session state `MICRO_VM_PID`, `MICRO_VM_SOCKET`, `MICRO_VM_SESSION_OWNED` (`false`), `VIRTIOFSD_PID_NVM`, `VIRTIOFSD_PID_WORKSPACE`. See [[sandbox]].

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

`json.sh` wraps `jq` to read and write the isolated environment's lockfile at `$ISOLATED_LOCKFILE`. Each function calls `validate_dependency "jq"` before proceeding. See [[lockfile]] for the lockfile's fields and lifecycle, and [[lockfile#Save]] for write semantics.

- `get_lockfile_field <path>` — reads a scalar via `jq -r ".<path> // \"unknown\""`; prints `unknown` and returns `1` when the lockfile is missing or the value is null/empty.
- `set_lockfile_field <path> <value>` — writes a value, creating `{}` if the lockfile is absent, then commits atomically via a `mktemp` file and `mv`; returns `1` (after cleaning up the temp file) if the `jq` write fails.
- `get_lockfile_object <path>` — reads a nested object via `jq -r ".<path> // {}"`, printing `{}` on missing file or null.

## Legacy Utilities

`remaining.sh` holds utility functions carried over from the pre-modular script (extracted in Phase 15). Each is guarded by `declare -F ... &>/dev/null` so it is only defined if not already present. They operate on the system (non-isolated) Node/Claude install and the global symlink.

- `install_nodejs`, `install_claude_code` — system Node.js (NodeSource `setup_20.x`) and global Claude Code (`npm install -g @anthropic-ai/claude-code`) installs.
- `get_claude_version`, `check_update`, `check_dependencies` — version detection across NVM and system locations, plus an npm-based update check (`npm view ... version`); rely on `detect_nvm` and `get_nvm_claude_path` from [[nvm]].
- `install_script`, `uninstall_script`, `create_symlink_only`, `uninstall_symlink_only` — manage the `/usr/local/bin/iclaude` symlink (require `sudo`/`EUID 0`). `create_symlink_only` requires the isolated environment to already exist and verifies the bundled `cli.js` is present.

See [[update]] for the modern isolated update flow that supersedes `check_update`.

See also: [[architecture#Isolated Environment]], [[architecture#Phase and Sourcing Order]], [[nvm]], [[lockfile]], [[config]].
