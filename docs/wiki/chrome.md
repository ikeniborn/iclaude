# Chrome

## Overview

The Chrome module (`lib/chrome/detection.sh`) detects whether the Claude-in-Chrome browser integration can run. Integration is disabled by default and gated on a paid plan, the Chrome extension, and a recent CLI. It exposes three guarded detection functions, is toggled by `--chrome`/`--no-chrome` and the `ICLAUDE_USE_CHROME` config var, degrades gracefully when prerequisites are missing, and is stripped under microVM.

## Prerequisites

Chrome integration lets Claude Code drive a Chrome session via the Claude-in-Chrome extension. The extension connects to the CLI over a local IPC port, so the CLI must run on the same host as the browser. It requires a paid Claude plan, the Chrome extension v1.0.36+, and Claude Code CLI v2.0.73+. These version requirements are external prerequisites — they are documented but not enforced by the bash code; iclaude only verifies that Chrome is running and that the extension manifest is present (see [[chrome#warn_chrome_integration]]).

## Module loading

`detection.sh` is the only file under `lib/chrome/`. It is sourced by `iclaude.sh` at startup, guarded by `[[ -d "$LIB_DIR/chrome" ]]`. Every function is wrapped in an `if ! declare -F <name>` guard so re-sourcing the file does not redefine the functions. See [[architecture]] for the full module list.

## is_chrome_running

Checks whether a Chrome process is live by scanning `ps aux` for `/opt/google/chrome/chrome` or `/usr/bin/chromium`, excluding `grep` and `crashpad` helper lines. Returns 0 if Chrome is running, 1 otherwise.

## is_claude_chrome_extension_installed

Detects the installed extension by scanning the Google Chrome profile root (`$HOME/.config/google-chrome`) and the Chromium profile root (`$HOME/.config/chromium`). In each existing directory it runs `find ... -path "*/Extensions/*/manifest.json" -print0` piped to `xargs -0 grep -l "Claude in Chrome\|claude.*chrome"`. The null-delimited pipeline handles profile names containing spaces. Returns 0 if any matching manifest is found in either browser, 1 otherwise.

## warn_chrome_integration

The primary entry point used before launch. It runs `is_chrome_running` and `is_claude_chrome_extension_installed`, then prints actionable guidance on the first failing check:

- Chrome not running: warns and advises starting Chrome.
- Extension not detected: warns and prints the Chrome Web Store URL for the Claude-in-Chrome extension (ID `hgjbefmfenopoenbhdcfhclblnnfifhh`).

Returns 0 only when both checks pass.

## Enabling and flag handling

`USE_CHROME` defaults to `false` in `iclaude.sh`. It is set to `true` either by `ICLAUDE_USE_CHROME=true` in `.claude_config` (parsed before argument parsing) or by the `--chrome` flag; `--no-chrome` forces it back to `false`, so a CLI flag overrides the config value. See [[command#Argument Parsing]] and [[config]].

```bash
./iclaude.sh --chrome     # enable
./iclaude.sh --no-chrome  # disable explicitly
```

When `USE_CHROME == true`, iclaude calls `warn_chrome_integration` (in both the no-proxy and proxied launch paths). Only if it passes is `--chrome` appended to the Claude arguments. If it fails, iclaude prints "Chrome integration disabled (extension not detected)" and launches without browser automation rather than erroring — graceful degradation. See [[launcher]].

## microVM stripping

When Claude runs inside a microVM, the `--chrome` flag (along with `--ide`) is removed from the forwarded argument list in `lib/launcher/launch.sh` before the SSH handoff. The extension IPC port lives on the host network namespace and the guest cannot reach it without SSH reverse port forwarding (future work). See [[sandbox]] and [[launcher#microVM Workspace Sync]].
