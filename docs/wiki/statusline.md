# Statusline

## Overview

The statusline module (`lib/statusline/`) provides a custom status bar for Claude Code. The bar is driven by `claude-statusline.sh`, a shell script installed at `$ISOLATED_CONFIG_DIR/scripts/claude-statusline.sh` and wired into Claude Code via the `statusLine` key in `settings.json`.

## Detection

`detect_statusline()` (`lib/statusline/detect.sh`) checks whether the script exists and is executable at `$ISOLATED_CONFIG_DIR/scripts/claude-statusline.sh`. It calls `setup_isolated_nvm` internally (suppressing output) to ensure `ISOLATED_CONFIG_DIR` is resolved before the path check. Returns 0 if ready, 1 otherwise.

## Installation

`install_statusline_script()` (`lib/statusline/install.sh`) is triggered by `./iclaude.sh --install-statusline`. It:

1. Resolves `$ISOLATED_CONFIG_DIR/scripts/` and ensures the directory exists.
2. Verifies the pre-authored `claude-statusline.sh` file is present at that path (it is not generated inline — it must exist already from the repository or a prior step).
3. Sets the file executable with `chmod +x`.
4. Calls `configure_statusline_in_settings()` to write the `statusLine` block into `settings.json`.
5. Calls `save_isolated_lockfile` to record the change.

`configure_statusline_in_settings()` uses `jq` to merge the following structure into `settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "$CLAUDE_CONFIG_DIR/scripts/claude-statusline.sh",
    "padding": 1
  }
}
```

The `command` value uses the literal string `$CLAUDE_CONFIG_DIR/scripts/claude-statusline.sh` (not expanded at install time). `$CLAUDE_CONFIG_DIR` is exported by `iclaude.sh` before launch and inherited by the statusLine subprocess, ensuring the path resolves correctly regardless of the working directory. `jq` is a required dependency; the function returns 1 if it is absent. The settings file is chmod 600 after writing.

## Status Check

`check_statusline_status()` (`lib/statusline/status.sh`) is triggered by `./iclaude.sh --check-statusline`. It reports:

- Whether `claude-statusline.sh` exists and is executable.
- The `statusLine.command` and `statusLine.refresh` values read from `settings.json` via `jq`.
- The list of data sources surfaced by the script: session info (tokens, model, cost), proxy status (from `.claude_config`), router status (from `router.json`), and git branch.
- The full capability list: context usage (tokens + percentage), model name, session cost (USD), proxy indicator, router indicator with provider name, git branch and uncommitted changes.

If `jq` is not installed, it prints a note and skips the `settings.json` inspection.

## Data Sources and Capabilities

The statusline script (not part of this module's source files, but configured by it) reads session metadata from the Claude Code environment and displays:

- Context usage: tokens consumed and percentage of limit.
- Cache metrics: cached token counts (when available).
- Session links: references to the active session.
- PII proxy indicator: shown when `ICLAUDE_PII_ACTIVE=1` is set by [[launcher#PII Proxy Lifecycle Functions]].
- Router indicator: suppressed when `ICLAUDE_ROUTER_ACTIVE=1` is set (CCR handles routing display itself).

See [[config]] for the `statusLine` settings key, and [[architecture]] for the module load order that ensures `ISOLATED_CONFIG_DIR` is set before statusline functions are called. See [[ohmyposh]] for the optional Oh My Posh prompt theme, an alternative prompt renderer.
