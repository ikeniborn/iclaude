# Oh-My-Posh

## Overview

The oh-my-posh module (`lib/ohmyposh/`) manages the oh-my-posh prompt-theming binary inside the iclaude isolated environment. It detects the platform, resolves/installs the binary (pre-bundled or auto-downloaded), and reports status. When present, the installed statusline script uses oh-my-posh to render only the git segment of the Claude Code status bar, with a bash fallback.

## Platform Detection

`detect_ohmyposh_platform()` (`lib/ohmyposh/detect.sh`) maps `uname -s` and `uname -m` to one of four supported identifiers: `linux-amd64` (`Linux`/`x86_64`), `linux-arm64` (`Linux`/`aarch64`|`arm64`), `darwin-amd64` (`Darwin`/`x86_64`), `darwin-arm64` (`Darwin`/`arm64`). Any other combination prints `"unsupported"` and returns exit code 1. The platform string is the suffix for the per-platform binary (`oh-my-posh-<platform>`).

## Binary Resolution

`get_ohmyposh_path()` (`lib/ohmyposh/detect.sh`) resolves the binary in two steps: first it checks `$ISOLATED_NVM_DIR/npm-global/bin/oh-my-posh` (isolated environment, priority, only if `$ISOLATED_NVM_DIR` is a directory), then falls back to `command -v oh-my-posh` (system PATH). It echoes the absolute path or an empty string. `detect_ohmyposh()` wraps this as a boolean (0 = found, 1 = not found).

## Installation

`install_isolated_ohmyposh()` (`lib/ohmyposh/install.sh`) is triggered by `./iclaude.sh --install-posh` (alias `--install-ohmyposh`). The dispatcher rejects `--system` (oh-my-posh is isolated-only) and forwards `--insecure` when the `posh_insecure` flag was set (collected during arg parsing in `iclaude.sh`); `--insecure` passes `-k` to `curl` for corporate proxies with self-signed certs.

Steps: call `setup_isolated_nvm`; resolve the platform via `detect_ohmyposh_platform()` (abort if unsupported). Look for the pre-bundled binary at `$ISOLATED_NVM_DIR/npm-global/bin/oh-my-posh-<platform>`. If missing, fetch the latest tag from the GitHub releases API (`JanDeDobbeleer/oh-my-posh`, parsed with python3) and invoke `scripts/download-ohmyposh-binaries.sh <version>`. Then create the platform-agnostic symlink `oh-my-posh -> oh-my-posh-<platform>`, `chmod +x` both, verify with `"$omp_symlink" --version`, and call `save_isolated_lockfile` (see [[lockfile]]) to record the change. On success it points the user at the theme file `.nvm-isolated/.claude-isolated/themes/claude-statusline.omp.json`.

## Download Script

`scripts/download-ohmyposh-binaries.sh [--insecure] vX.Y.Z` downloads all four platform binaries (`posh-<platform>`) from the `JanDeDobbeleer/oh-my-posh` GitHub release into `.nvm-isolated/npm-global/bin/` as `oh-my-posh-<platform>`, `chmod +x` each, and prints a verify/commit hint. It enforces a strict `vX.Y.Z` version format and `set -e` (any failed download aborts). `--insecure` maps to `curl -k`. `install_isolated_ohmyposh()` calls it automatically for the current platform when the pre-bundled binary is absent; it can also be run manually to refresh all bundled binaries.

## Theme File

The theme lives at `.nvm-isolated/.claude-isolated/themes/claude-statusline.omp.json` — an oh-my-posh v2 schema with a single `prompt` block containing one `git` segment (template ` {{ .HEAD }}{{ if .Working.Changed }} ●{{ end }}`, `fetch_status: true`, empty `branch_icon`). It renders just the branch name plus a `●` dirty marker; it is not a full Powerline prompt. Edit this file directly to customize the rendered git output. It is consumed by the statusline script, not by the lib module.

## Status Check

`check_ohmyposh_status()` (`lib/ohmyposh/status.sh`) is triggered by `./iclaude.sh --check-posh` (alias `--check-ohmyposh`). After `setup_isolated_nvm`, it checks whether `$ISOLATED_NVM_DIR/npm-global/bin/oh-my-posh` exists and is executable; if so it prints the location, the version (`oh-my-posh --version`), and the platform from `detect_ohmyposh_platform()`. If absent, it prints the install command. It always returns 0.

## Integration with Statusline

oh-my-posh is an optional dependency of the installed statusline script (`$CLAUDE_CONFIG_DIR/scripts/claude-statusline.sh`). Inside a git work tree, the script uses oh-my-posh only for the git segment: when `command -v oh-my-posh` succeeds and the theme file exists and is valid JSON, it runs `oh-my-posh print primary --config "$theme_config"` (wrapped in `timeout` when available), strips ANSI codes, and wraps the output in an OSC 8 hyperlink to the remote. If oh-my-posh is unavailable or returns nothing, it falls back to bash git parsing (branch, change count, ahead count). The rest of the status bar (context usage, cache, model, links) is always rendered by the script itself, not by oh-my-posh.

See [[statusline]] for the full status bar, [[lockfile]] for install tracking, and [[architecture]] for the module load order.
