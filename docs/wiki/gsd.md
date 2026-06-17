# GSD Module

The GSD module (`lib/gsd/`) installs and reports on the GSD ("Get Shit Done") meta-prompting / spec-driven development framework inside the iclaude isolated environment. GSD is distributed as the npm package `get-shit-done-cc` and installs its skills as `gsd-*` directories under `$CLAUDE_CONFIG_DIR/skills/`.

## Detection

`detect_gsd()` (`lib/gsd/detect.sh`) returns 0 when GSD skills are present, 1 otherwise. It checks that `${CLAUDE_CONFIG_DIR}/skills` exists, then uses `find` with `-maxdepth 1 -type d -name 'gsd-*'` to locate at least one installed skill directory. Detected installation state is derived purely from the presence of these `gsd-*` skill dirs.

## Installation

`install_gsd()` (`lib/gsd/install.sh`) is triggered by `./iclaude.sh --install-gsd`. It requires the isolated environment (`$ISOLATED_NVM_DIR`) — aborting with an error to run `--isolated-install` first — and calls `setup_isolated_nvm` to prepare the toolchain (see [[nvm]]).

Steps:

1. **Force reset** (optional): with `--force`, removes existing `gsd-*` skill dirs and the `${CLAUDE_CONFIG_DIR}/.gsd-version` marker before reinstalling.
2. **Install**: runs `CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" npx get-shit-done-cc@latest --global`, forwarding the isolated config dir so skills land in the isolated environment. A non-zero exit returns failure.
3. **Record version**: queries `npm view get-shit-done-cc version` (npm cache is warm from the preceding `npx` install) and writes the result to `${CLAUDE_CONFIG_DIR}/.gsd-version`, falling back to `unknown`.

`update_gsd_if_installed()` is a no-op when `detect_gsd` reports GSD absent; otherwise it re-runs `install_gsd`, treating a failure as non-critical (warning only). This makes GSD update safe to call unconditionally from the update flow (see [[update]]).

## Status Reporting

`check_gsd_status()` (`lib/gsd/status.sh`) is triggered by `./iclaude.sh --check-gsd`. When `detect_gsd` reports GSD absent, it prints a not-installed warning and the `--install-gsd` hint. When installed, it reports:

- **Version** — read from the `${CLAUDE_CONFIG_DIR}/.gsd-version` marker (whitespace stripped); `unknown (marker absent)` if the marker is missing.
- **Installed skills** — each `gsd-*` directory under `${CLAUDE_CONFIG_DIR}/skills`, listed by basename in sorted order.

## Lockfile Integration

The `.gsd-version` marker written by `install_gsd` is the source of the `gsdVersion` field in the isolated lockfile. On save, `gsdVersion` is read from `$CLAUDE_CONFIG_DIR/.gsd-version` (falling back to `npm view get-shit-done-cc version`); on restore, GSD is reinstalled via `npx get-shit-done-cc@<gsdVersion> --global` with `CLAUDE_CONFIG_DIR` forwarded, re-writing the marker on success. See [[lockfile]].

See also: [[lockfile]], [[nvm]], [[update]], [[graphify]]
