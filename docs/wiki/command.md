# Command Module

## Overview

The command module is the CLI front-end of iclaude: it prints the `--help` text, and provides placeholder hooks for argument parsing and command dispatch. It is the last module sourced (Phase 14 — see [[architecture#Phase and Sourcing Order]] and [[architecture#Command Dispatch]]). Covers usage/help text, the parse stub, and the dispatch stub.

## Usage / Help Text

`usage.sh` defines `show_usage`, which `cat`s a comprehensive help heredoc to stdout listing every CLI option, examples, and configuration notes. It always returns `0` and is wrapped in a `declare -F` guard so a prior definition is not overwritten. It is invoked directly by the `-h` / `--help` case in `main()` (in `iclaude.sh`), which then `exit 0`s — not via the parse/dispatch stubs.

The heredoc is grouped into sections: `OPTIONS` (plus an `Oh My Posh Commands` block), `EXAMPLES`, `ISOLATED ENVIRONMENT`, `SYSTEM INSTALLATION`, `ISOLATED CONFIGURATION`, `ROUTER INTEGRATION`, `PII PROXY (MASKING)`, `PROXY URL FORMAT`, `CONFIGURATION`, `AUTHENTICATION`, `ENVIRONMENT`, `NO_PROXY CONFIGURATION`, `GIT PROXY`, and `INSTALLATION`. The heredoc is unquoted, so it interpolates the globals `CREDENTIALS_FILE` and `GIT_BACKUP_FILE` (and `$0`) into the printed paths and examples.

The `OPTIONS` block documents flags across every feature area: proxy flags `--proxy` / `--proxy-ca` / `--proxy-insecure` / `--no-proxy` / `--restore-git-proxy` ([[proxy]]); install/symlink commands `--install` / `--uninstall` / `--create-symlink` / `--uninstall-symlink` / `--system`; update commands `--update` / `--check-update` / `--install-from-lockfile` ([[update]], [[lockfile]]); isolated-env commands `--isolated-install` / `--isolated-update` / `--check-isolated` / `--cleanup-isolated` / `--repair-isolated` / `--repair-plugins` ([[nvm]]); config-dir commands `--isolated-config` / `--shared-config` / `--check-config` / `--export-config` / `--import-config` ([[config]]); `--refresh-token` ([[oauth]]); router `--install-router` / `--check-router` / `--router` ([[router]]); PII proxy `--install-pii-proxy` / `--check-pii-proxy` / `--pii-proxy` ([[pii-proxy]]); `--install-iwiki` ([[iwiki]]); `--no-attribution-header` (auto-enabled with `--router`); `--chrome` / `--no-chrome` ([[chrome]]); `--model MODEL` (saved to config, examples `claude-opus-4-6` / `claude-sonnet-4-6` / `claude-haiku-3-5`); LSP `--install-lsp [LANGUAGES]` / `--check-lsp` ([[lsp]]); microVM `--install-microvm` / `--check-microvm` / `--sandbox-microvm` ([[sandbox]]); caveman `--install-caveman` / `--uninstall-caveman` / `--check-caveman` ([[caveman]]); Oh My Posh `--install-posh` / `--install-ohmyposh` / `--check-posh` / `--check-ohmyposh` ([[ohmyposh]]); plus operational flags `-t` / `--test`, `--no-test`, `-c` / `--clear`, `--show-password`, `--no-save` (enables `--dangerously-skip-permissions`), and the deprecated `--save`.

## Argument Parsing

`parse.sh` defines `parse_cli_arguments`, intended to parse `$@` and set the global flags that drive the rest of the launch (e.g. `test_mode`, `skip_test`, `show_password`, `proxy_url`).

This is a stub: the function returns `0` and does nothing. The actual `case`-based argument-parsing loop still lives in `main()` in `iclaude.sh`. Per the in-file design notes, Phase 14 established the modular structure while extraction of the parsing logic was deferred to a later (Phase 15+) refactor. Like the other functions in this module, it is wrapped in a `declare -F` guard.

## Command Dispatch

`dispatch.sh` defines `dispatch_command`, intended to route the parsed command to its handler using the global flags set during parsing, returning `0` on success or `1` on failure.

It is also a stub returning `0`; dispatch logic remains in `main()` in the legacy code path. The documented (to-be-extracted) responsibilities are: checking OAuth token expiration, adding launch flags such as `--dangerously-skip-permissions` and `--chrome`, and launching Claude Code — the work currently performed by the [[launcher]]. The `declare -F` guard prevents redefinition when an implementation is already present.

See also: [[architecture#Command Dispatch]], [[launcher#Entry Point]], [[core]], [[config]]
