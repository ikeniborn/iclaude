# Command Module

The command module is the CLI front-end of iclaude: it prints the `--help` text, parses command-line arguments, and routes parsed commands to their handlers. It is the last module sourced (Phase 14 — see [[architecture#Phase and Sourcing Order]] and [[architecture#Command Dispatch]]).

## Usage / Help Text

`usage.sh` defines `show_usage`, which `cat`s a comprehensive help block to stdout listing every CLI option, examples, and configuration notes. It is invoked by `-h` / `--help` and always returns `0`.

The text is grouped into sections: `OPTIONS`, `EXAMPLES`, `ISOLATED ENVIRONMENT`, `SYSTEM INSTALLATION`, `ISOLATED CONFIGURATION`, `ROUTER INTEGRATION`, `PII PROXY (MASKING)`, `PROXY URL FORMAT`, `CONFIGURATION`, `AUTHENTICATION`, `ENVIRONMENT`, `NO_PROXY CONFIGURATION`, `GIT PROXY`, and `INSTALLATION`, plus an `Oh My Posh Commands` block. The heredoc interpolates the globals `CREDENTIALS_FILE` and `GIT_BACKUP_FILE` so the printed paths reflect the active configuration.

Documented flags span every feature area, including `--proxy` / `--proxy-ca` / `--proxy-insecure` ([[proxy]]), `--router` ([[router]]), `--pii-proxy` ([[pii-proxy]]), `--install-graphify` / `--graphify` ([[graphify]]), `--install-iwiki` ([[iwiki]]), `--install-lsp` / `--check-lsp` ([[lsp]]), `--install-microvm` / `--sandbox-microvm` ([[sandbox]]), `--install-caveman` ([[caveman]]), `--install-posh` ([[ohmyposh]]), the `--*-isolated` and `--*-config` environment commands ([[nvm]], [[config]]), `--refresh-token` ([[oauth]]), `--update` / `--check-update` / `--install-from-lockfile` ([[update]], [[lockfile]]), and `--model`. The function is guarded by a `declare -F` check so a prior definition is not overwritten.

## Argument Parsing

`parse.sh` defines `parse_cli_arguments`, intended to parse `$@` and set the global flags that drive the rest of the launch (e.g. `test_mode`, `skip_test`, `show_password`, `proxy_url`).

This is currently a thin wrapper: the function is a stub that returns `0`, and the actual `case`-based argument parsing still lives in `main()` in the legacy entry point. Per the in-file design notes, Phase 14 establishes the modular structure while the parsing logic itself is deferred to a later (Phase 15+) extraction. Like the other functions in this module, it is wrapped in a `declare -F` guard.

## Command Dispatch

`dispatch.sh` defines `dispatch_command`, intended to route the parsed command to its handler using the global flags set during parsing, returning `0` on success or `1` on failure.

It is also a stub returning `0`; dispatch logic remains in `main()` in the legacy code. The documented (to-be-extracted) responsibilities are: checking OAuth token expiration, adding launch flags such as `--dangerously-skip-permissions` and `--chrome`, and launching Claude Code — the work performed by the [[launcher]]. The `declare -F` guard prevents redefinition when an implementation is already present.

See also: [[architecture#Command Dispatch]], [[launcher]], [[core]], [[config]]
