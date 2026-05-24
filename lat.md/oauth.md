# OAuth

OAuth token management for Claude Code. `check_oauth_token()` in `lib/oauth/token.sh` runs before every launch to detect and refresh expiring tokens.

## Refresh Threshold

`TOKEN_REFRESH_THRESHOLD=604800` (7 days). Token is refreshed if it expires within 7 days of the current time.

## Token Types

| Prefix | Type | Notes |
|--------|------|-------|
| `sk-ant-api03-...` | Real API key | No expiry; works with CCR |
| `sk-ant-oat01-...` | OAuth token | Has expiry; requires refresh; does NOT work with CCR |

## Token Location

Stored in `$CLAUDE_CONFIG_DIR` (isolated config dir). Claude Code manages the token file; `check_oauth_token()` reads it to detect upcoming expiry.

## Refresh Behavior

If token expiry is within `TOKEN_REFRESH_THRESHOLD`, the wrapper attempts a token refresh before launching Claude. If refresh fails, launch continues with the existing token (warn, don't abort) — Claude itself will handle expired tokens.
