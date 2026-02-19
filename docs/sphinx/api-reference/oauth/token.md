# token

> **Module:** `oauth` | **File:** `lib/oauth/token.sh`

OAuth Token Module
Description: OAuth token validation, expiration checking, and automatic refresh

---

### `check_token_expiration`

Check token expiration across all credentials files Checks system and isolated credentials for expiring/expired tokens

**Returns:**

-   0 - All tokens valid
-   1 - Token expired
-   2 - Token expiring soon (< 1 hour)

**Example:**

```bash
  check_token_expiration || echo "Token issues detected"
```

### `check_oauth_token`

Check OAuth token and refresh if needed Automatically refreshes tokens expiring within TOKEN_REFRESH_THRESHOLD (7 days default)

**Arguments:**

- `  $1 - skip_isolated (optional): "false" (default) or "true" to use system config`

**Returns:**

-   0 - Token valid or refreshed successfully
-   1 - Token expired and refresh failed

**Example:**

```bash
  check_oauth_token || echo "Token refresh failed"
```

### `refresh_oauth_token`

Refresh OAuth token using setup-token Uses 'claude setup-token' to generate a long-lived token (~1 year)

**Arguments:**

- `  $1 - skip_isolated (optional): "false" (default) or "true" to use system config`

**Returns:**

-   0 - Token refreshed successfully
-   1 - Failed to refresh token

**Example:**

```bash
  refresh_oauth_token || echo "Token refresh failed"
```

### `validate_jq_installed`

Validate that jq is installed Required for parsing JSON credentials file

**Returns:**

-   0 - jq is installed
-   1 - jq is not installed

**Example:**

```bash
  validate_jq_installed || echo "jq not found"
```

