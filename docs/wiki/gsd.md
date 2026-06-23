# GSD Module

## Overview

The GSD module (`lib/gsd/`) installs and reports on the GSD ("Get Shit Done") meta-prompting / spec-driven development framework inside the iclaude isolated environment. GSD ships as the npm package `get-shit-done-cc`, installing `gsd-*` skills under `$CLAUDE_CONFIG_DIR/skills/`. Covers detection, installation, status, and lockfile integration.

## Detection

`detect_gsd()` (`lib/gsd/detect.sh`) returns 0 when GSD skills are present, 1 otherwise. It checks that `${CLAUDE_CONFIG_DIR}/skills` exists, then uses `find` with `-maxdepth 1 -type d -name 'gsd-*'` to locate at least one installed skill directory. Installation state is derived purely from the presence of these `gsd-*` skill dirs.

## Installation

`install_gsd()` (`lib/gsd/install.sh`) is triggered by `./iclaude.sh --install-gsd`. It requires the isolated environment (`$ISOLATED_NVM_DIR`) — aborting with a hint to run `--isolated-install` first — and calls `setup_isolated_nvm` to prepare the toolchain (see [[nvm]]). The command rejects `--system`: GSD is isolated-only. On success it triggers `save_isolated_lockfile` (see [[lockfile]]).

Steps:

1. **Force reset** (optional): `install_gsd --force` removes existing `gsd-*` skill dirs and the `${CLAUDE_CONFIG_DIR}/.gsd-version` marker before reinstalling.
2. **Install**: runs `CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" npx get-shit-done-cc@latest --global`, forwarding the isolated config dir so skills land in the isolated environment. A non-zero exit returns failure.
3. **Record version**: queries `npm view get-shit-done-cc version` (npm cache is warm from the preceding `npx` install) and writes the result to `${CLAUDE_CONFIG_DIR}/.gsd-version`, falling back to `unknown`.

After install, the command prints next-step hints (`--check-gsd`, and run `/gsd` in a Claude Code session).

`update_gsd_if_installed()` is a no-op when `detect_gsd` reports GSD absent; otherwise it re-runs `install_gsd`, treating a failure as non-critical (warning only). This makes GSD update safe to call unconditionally from the update flow (see [[update]]).

## Status Reporting

`check_gsd_status()` (`lib/gsd/status.sh`) is triggered by `./iclaude.sh --check-gsd`. When `detect_gsd` reports GSD absent, it prints a not-installed warning and the `--install-gsd` hint. When installed, it reports:

- **Version** — read from the `${CLAUDE_CONFIG_DIR}/.gsd-version` marker (whitespace stripped); `unknown (marker absent)` if the marker is missing.
- **Installed skills** — each `gsd-*` directory under `${CLAUDE_CONFIG_DIR}/skills`, listed by basename in sorted order.

## Command Wiring

`--install-gsd` and `--check-gsd` are dispatched in `iclaude.sh`. `--install-gsd` blocks `--system` (prints an error and exits 1), consumes an optional trailing `--force`, sources the iclaude config, then calls `install_gsd`; on exit code 0 it runs `save_isolated_lockfile` and propagates the install's return code. `--check-gsd` simply calls `check_gsd_status` and exits 0. See [[command#Argument Parsing]].

## Lockfile Integration

The `.gsd-version` marker is the source of the `gsdVersion` field in the isolated lockfile. On save (`lib/lockfile/save.sh`), `gsdVersion` defaults to `not installed`; when `detect_gsd` succeeds it is read from `$CLAUDE_CONFIG_DIR/.gsd-version` (falling back to `npm view get-shit-done-cc version`). On restore (`lib/lockfile/install.sh`), values other than `not installed`/`unknown` are reinstalled via `npx get-shit-done-cc@<gsdVersion> --global` directly (not `install_gsd`, for quiet output; stale `gsd-*` dirs are safe since npx overwrites them), re-writing the marker on success and warning non-critically on failure. See [[lockfile]].

See also: [[lockfile]], [[nvm]], [[update]], [[command#Argument Parsing]]
