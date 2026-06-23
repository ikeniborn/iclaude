# Chrome

## Overview

The Chrome module (`lib/chrome/detection.sh`) provides detection utilities for Chrome browser integration. Chrome integration is **disabled by default** and requires a paid Claude plan, Chrome extension v1.0.36+, and Claude Code CLI v2.0.73+. Enabling it without these prerequisites causes startup errors. Chrome integration allows Claude Code to control a Chrome browser session via the Claude-in-Chrome extension. The extension connects to the CLI over a local IPC port; the CLI must be running on the same host. When `--chrome` is passed to `iclaude.sh`, the Chrome detection functions are called to verify prerequisites before launch. The flag `--no-chrome` disables the feature explicitly.

Note: when Claude runs inside a microVM, the `--chrome` flag is stripped by [[launcher#microVM Workspace Sync]] because the extension IPC port is on the host network namespace and the guest cannot reach it without SSH reverse port forwarding.

## is_chrome_running

Checks whether a Chrome browser process is currently running by scanning `ps aux` for `/opt/google/chrome/chrome` or `/usr/bin/chromium`, excluding `grep` and `crashpad` helper processes. Returns 0 if Chrome is running, 1 otherwise.

Each function is guarded with `declare -F` to prevent redefinition if the file is sourced more than once.

## is_claude_chrome_extension_installed

Scans the Google Chrome profile directory (`$HOME/.config/google-chrome`) and the Chromium profile directory (`$HOME/.config/chromium`) for extension manifest files containing `Claude in Chrome` or `claude.*chrome`. The scan uses `find` with null-delimited output piped to `xargs -0 grep -l` to handle profile directory names that may contain spaces. Returns 0 if a matching manifest is found in either browser, 1 otherwise.

## warn_chrome_integration

Calls `is_chrome_running` and `is_claude_chrome_extension_installed` and prints actionable warnings if either check fails:

- If Chrome is not running: advises the user to start Chrome.
- If the extension is not detected: prints the Chrome Web Store URL for the Claude-in-Chrome extension (`hgjbefmfenopoenbhdcfhclblnnfifhh`).

Returns 0 only when both checks pass. This function is the primary entry point used by the command dispatch layer before attempting to pass `--chrome` to the Claude binary.

## Enabling Chrome Integration

```bash
./iclaude.sh --chrome     # enable
./iclaude.sh --no-chrome  # disable explicitly
```

See [[architecture]] for the full list of modules and [[launcher]] for how the `--chrome` flag is forwarded (or stripped in microVM mode).
