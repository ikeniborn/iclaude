# OAuth Module

## Overview

The OAuth module is a single file: `lib/oauth/token.sh`. It handles OAuth token inspection, expiration warnings, automatic proactive refresh, and token generation via the `claude setup-token` command.

## Token Storage

OAuth tokens are stored in `.credentials.json` files managed by Claude Code itself. The module reads two locations, checked in this order:

| Context | Path |
|---------|------|
| Isolated environment | `$ISOLATED_NVM_DIR/.claude-isolated/.credentials.json` |
| System installation | `$HOME/.claude/.credentials.json` |

The relevant JSON field is `.claudeAiOauth.expiresAt`, read with `jq -r '.claudeAiOauth.expiresAt // 0'`. The comment in the source explicitly notes the full path `.claudeAiOauth.expiresAt` to avoid accidentally matching `.mcpOAuth.*.expiresAt` entries for MCP server tokens.

The `TOKEN_REFRESH_THRESHOLD` (default 604800 seconds = 7 days) is set by `lib/core/init.sh` and exported before the module loads.

See also: [[proxy#Configuration Entry Point]] (tokens travel through the configured proxy).

## Token Expiration Check

`check_token_expiration()` iterates over both credentials files (system + isolated), extracts `expiresAt` in milliseconds, converts to seconds, and compares against `date +%s`. Return codes:

- `0` — all tokens valid
- `1` — at least one token is expired
- `2` — at least one token expires within 1 hour (warn threshold hardcoded to 3600 s)

This function is used for informational output during startup. It does not attempt a refresh; that is the responsibility of `check_oauth_token()`.

## Automatic Token Refresh

`check_oauth_token()` is the primary pre-launch guard. It selects the correct credentials file (isolated vs. system, controlled by the `skip_isolated` argument), extracts `expiresAt`, and compares against the current time. If `CLAUDE_CODE_OAUTH_TOKEN` is set in the environment, the check is skipped entirely — Claude Code uses the injected token directly.

When the remaining time is at or below `TOKEN_REFRESH_THRESHOLD` (7 days), `check_oauth_token()` calls `refresh_oauth_token()` automatically. If the refresh succeeds the function returns 0. On failure it returns 1, prints a message asking the user to run `/login` inside Claude Code, but does **not** delete the credentials file — the existing `refreshToken` inside it may still be usable by Claude Code at startup.

A `warn_threshold` of 3600 s (1 hour) triggers a display-only warning if the token is valid but close to expiry.

## Token Refresh via `setup-token`

`refresh_oauth_token()` locates the Claude Code binary using `detect_nvm()` and `get_nvm_claude_path()` from `lib/nvm/detect.sh`, then runs:

```
claude setup-token
```

This command opens a browser-based OAuth flow and writes a new long-lived token (approximately 1 year) to the credentials file. The function prefers the isolated environment binary when `skip_isolated=false` (the default) and falls back to `which claude` if `get_nvm_claude_path()` returns nothing.

See also: [[nvm#Claude Binary Detection]] (the binary lookup used here).

## Dependency Validation

`validate_jq_installed()` delegates to `validate_dependency()` in `lib/core/validation.sh`. It is called before any `jq` invocation to produce a clear error message rather than a cryptic `jq: command not found` failure. If `jq` is absent, token checking is skipped with a warning rather than aborting launch.

---

See also: [[nvm#Environment Setup]] (calls `load_claude_config()` which can supply `CLAUDE_CODE_OAUTH_TOKEN`), [[proxy#Connectivity Test]] (proxy must be reachable for the OAuth browser flow and for API calls made with the token).
