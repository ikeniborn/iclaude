# Oh-My-Posh

## Overview

The oh-my-posh module (`lib/ohmyposh/`) manages the oh-my-posh prompt theming binary inside the iclaude isolated environment. When installed, the statusline script picks it up automatically to render the Claude Code status bar with Powerline-style formatting.

## Platform Detection

`detect_ohmyposh_platform()` (`lib/ohmyposh/detect.sh`) maps `uname -s` and `uname -m` to one of four supported platform identifiers: `linux-amd64`, `linux-arm64`, `darwin-amd64`, `darwin-arm64`. Any other combination returns `"unsupported"` with exit code 1. The platform string is used as a suffix when naming the platform-specific binary (`oh-my-posh-<platform>`).

## Binary Resolution

`get_ohmyposh_path()` resolves the oh-my-posh binary in two steps:

1. Checks `$ISOLATED_NVM_DIR/npm-global/bin/oh-my-posh` (isolated environment, priority).
2. Falls back to `command -v oh-my-posh` (system PATH).

Returns the absolute path or an empty string. `detect_ohmyposh()` wraps this as a simple boolean (0 = found, 1 = not found).

## Installation

`install_isolated_ohmyposh()` (`lib/ohmyposh/install.sh`) is triggered by `./iclaude.sh --install-posh`. It accepts an optional `--insecure` flag that passes `-k` to `curl` for corporate proxies with self-signed certificates.

Installation steps:

1. Call `detect_ohmyposh_platform()` to determine the target platform. Abort if unsupported.
2. Look for a pre-bundled binary at `$ISOLATED_NVM_DIR/npm-global/bin/oh-my-posh-<platform>`. If absent, fetch the latest version tag from the GitHub releases API, then invoke `scripts/download-ohmyposh-binaries.sh <version>` to download it.
3. Create a platform-agnostic symlink: `oh-my-posh -> oh-my-posh-<platform>` inside `$ISOLATED_NVM_DIR/npm-global/bin/`.
4. Set `+x` permissions on both the binary and the symlink.
5. Verify the install by running `"$omp_symlink" --version`.
6. Call `save_isolated_lockfile` to record the change.

After installation the statusline script uses oh-my-posh automatically. The theme file is located at `.nvm-isolated/.claude-isolated/themes/claude-statusline.omp.json` and can be edited directly.

## Status Check

`check_ohmyposh_status()` (`lib/ohmyposh/status.sh`) is triggered by `./iclaude.sh --check-posh`. It reports:

- Whether `$ISOLATED_NVM_DIR/npm-global/bin/oh-my-posh` exists and is executable.
- The version string from `oh-my-posh --version`.
- The current platform from `detect_ohmyposh_platform()`.

If the binary is absent, it prints the install command and exits cleanly (returns 0 always).

## Integration with Statusline

oh-my-posh is an optional dependency of the statusline script. When `detect_ohmyposh()` returns 0, the statusline script delegates prompt rendering to the oh-my-posh binary using the bundled theme. When oh-my-posh is absent, the statusline script falls back to plain text output.

See [[statusline]] for the statusline configuration, and [[architecture]] for the module load order.
