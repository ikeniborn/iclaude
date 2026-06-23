# OAuth Module

## Overview

The OAuth module is a single file: `lib/oauth/token.sh`. It inspects Claude Code's `.credentials.json`, warns on near/past expiry, proactively auto-refreshes tokens within a 7-day window, and generates long-lived tokens via `claude setup-token`. Invoked at launch, on status checks, and via `--refresh-token`.

## Token Storage

OAuth tokens live in `.credentials.json` files managed by Claude Code itself, not by this module. Two locations are checked, isolated first:

| Context | Path |
|---------|------|
| Isolated environment | `$ISOLATED_NVM_DIR/.claude-isolated/.credentials.json` |
| System installation | `$HOME/.claude/.credentials.json` |

The relevant field is `.claudeAiOauth.expiresAt`, read with `jq -r '.claudeAiOauth.expiresAt // 0'`. The full path is used deliberately (a code comment marks it CRITICAL) to avoid matching `.mcpOAuth.*.expiresAt` entries for MCP server tokens. The stored value is a Unix timestamp in milliseconds.

`TOKEN_REFRESH_THRESHOLD` (604800 s = 7 days) is set and exported by [[core#Environment Initialization]] (`lib/core/init.sh`); [[proxy#Configuration Entry Point]] re-exports it so subprocesses inherit it.

## Token Expiration Check

`check_token_expiration()` is informational and never refreshes. It iterates over both credentials files that exist (system + isolated), extracts `expiresAt` (ms), converts to seconds, and compares against `date +%s`. With no credentials files it returns 0. Return codes (most-critical wins):

- `0` — all tokens valid
- `1` — at least one token is expired
- `2` — at least one token expires within 1 hour (`warn_threshold` hardcoded to 3600 s)

It is called during startup/status flows in `iclaude.sh` (e.g. `--check-isolated` and the default launch path), where it prints per-file warnings with human-readable expiry timestamps.

## Automatic Token Refresh

`check_oauth_token()` is the primary pre-launch guard, called by `launch_claude()` in [[launcher#Pre-launch Steps]] before starting Claude Code. It selects the credentials file from its `skip_isolated` argument (`"false"` default → isolated when `$ISOLATED_NVM_DIR` is a directory, else system). Behavior:

- If `CLAUDE_CODE_OAUTH_TOKEN` is set in the environment, the check is skipped entirely (return 0) — Claude Code uses the injected token directly.
- If the credentials file is missing, or `jq` is unavailable, or `expiresAt` is absent / non-numeric, it warns and returns 0 (never blocks launch).
- When `time_remaining_sec <= TOKEN_REFRESH_THRESHOLD` (7 days, includes already-expired), it calls `refresh_oauth_token()`. Success → return 0; failure → print a `/login` hint and return 1, **without** deleting the credentials file (the embedded `refreshToken` may still work for Claude Code at startup).
- If valid but within 1 hour of expiry, it prints a display-only warning and returns 0.

`CLAUDE_CODE_OAUTH_TOKEN` can be supplied via the user config loaded in [[nvm#Environment Setup]].

## Token Refresh via setup-token

`refresh_oauth_token()` generates a fresh long-lived token (valid ~1 year). It locates the Claude Code binary via `detect_nvm()` + `get_nvm_claude_path()` (see [[nvm#Claude Binary Detection]]), preferring the isolated binary when `skip_isolated=false`, then falling back to `which claude`. If no binary is found it prints an error and returns 1. Otherwise it runs:

```
claude setup-token
```

This opens a browser-based OAuth flow and writes the new token to the credentials file. The function is also invoked directly by the `--refresh-token` CLI command (see [[command#Command Dispatch]]), which first runs `setup_isolated_nvm` when targeting the isolated environment.

## Dependency Validation

`validate_jq_installed()` delegates to `validate_dependency("jq", ...)` in `lib/core/validation.sh` (see [[core#Validation]]). It runs before any `jq` invocation in `check_oauth_token()`; if `jq` is absent, token checking is skipped with a warning rather than aborting launch.

## OAuth vs API Key

This module manages OAuth tokens (`sk-ant-oat01-...`), the default auth for interactive Claude Code. It does **not** handle real API keys (`sk-ant-api03-...`), which are required by Claude Code Router and stored separately in config. See [[router#API Key Requirement]] and [[proxy#Connectivity Test]] (the proxy must be reachable for both the OAuth browser flow and API calls made with the token).
