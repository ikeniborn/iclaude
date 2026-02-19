# credentials

> **Module:** `proxy` | **File:** `lib/proxy/credentials.sh`

Proxy Credentials Module
Description: Save, load, and manage proxy credentials

---

### `save_credentials`

Save proxy credentials to file

**Arguments:**

- `  $1 - Proxy URL`
- `  $2 - NO_PROXY value (optional, default: localhost,127.0.0.1,...)`

**Returns:**

-   Final proxy URL on stdout (after possible domain-to-IP conversion)
-   Exit code: 0 on success
- Side effects:
-   - Creates CREDENTIALS_FILE with chmod 600
-   - May prompt user for domain-to-IP conversion (for HTTP proxies)

### `load_credentials`

Load credentials from file

**Returns:**

-   "URL|NO_PROXY" on stdout (pipe-separated)
-   Exit code: 0 on success, 1 if file missing or invalid
- Side effects:
-   - Exports PROXY_CA, PROXY_INSECURE
-   - Exports Claude Code configuration variables (DEBUG_STATUSLINE, etc.)

### `clear_credentials`

Clear saved credentials Side effects:   - Deletes CREDENTIALS_FILE

### `prompt_proxy_url`

Prompt user for proxy URL (interactive)

**Returns:**

-   "URL|NO_PROXY" on stdout (pipe-separated)
-   Exit code: 0 on success, 1 on failure
- Side effects:
-   - Prompts user for input if no saved credentials
-   - Validates URL format

