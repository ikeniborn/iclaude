# install

> **Module:** `ohmyposh` | **File:** `lib/ohmyposh/install.sh`

Oh-My-Posh installation module
Provides function for installing Oh-My-Posh in isolated environment

---

### `install_isolated_ohmyposh`

Install Oh My Posh in isolated environment (pre-bundled or auto-downloaded) Uses pre-bundled platform-specific binary from git repository. If binary is missing, automatically downloads the latest version from GitHub.

**Arguments:**

- `  [--insecure] - disable TLS verification for download (corporate proxy)`

**Returns:**

-   0 - success
-   1 - error

