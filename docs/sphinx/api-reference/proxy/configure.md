# configure

> **Module:** `proxy` | **File:** `lib/proxy/configure.sh`

Proxy Configuration Module
Description: Configure proxy environment variables and test connectivity

---

### `configure_proxy_from_url`

Configure proxy from URL

**Arguments:**

- `  $1 - Proxy URL`
- `  $2 - NO_PROXY value (optional)`
- `Side effects:`
- `  - Exports HTTPS_PROXY, HTTP_PROXY, NO_PROXY`
- `  - Exports NODE_EXTRA_CA_CERTS or NODE_TLS_REJECT_UNAUTHORIZED`
- `  - May save credentials (if new URL)`
- `  - Configures git to use NO_PROXY`

### `configure_git_no_proxy`

Configure git to use NO_PROXY environment variable Note: We don't modify git config globally anymore (can break other tools) Git automatically respects NO_PROXY environment variable

### `display_proxy_info`

Display proxy configuration

**Arguments:**

- `  $1 - Show password (true/false, default: false)`

### `test_proxy`

Test proxy connectivity

**Returns:**

-   0 - Proxy connection successful
-   1 - Proxy connection failed
- Note: Uses curl with proxy to test connection to google.com

