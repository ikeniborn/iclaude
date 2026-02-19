# install

> **Module:** `nvm` | **File:** `lib/nvm/install.sh`

NVM Installation Module
Description: Install NVM, Node.js, and npm packages with lockfile integration

---

### `install_isolated_nvm`

Install NVM to isolated directory

**Returns:**

-   0 - success
-   1 - error
- Side effects:
-   - Creates ISOLATED_NVM_DIR
-   - Downloads and installs NVM v0.39.7
-   - Uses proxy if configured

### `install_isolated_nodejs`

Install Node.js in isolated NVM

**Arguments:**

- `  $1 - Node.js version (default: 18)`

**Returns:**

-   0 - success
-   1 - error

### `install_npm_package_with_lockfile`

Install npm package with automatic lockfile update This function eliminates 6+ duplications across iclaude.sh:   - install_isolated_claude()   - install_isolated_router()   - install_isolated_lsp_servers() (multiple packages)   - install_isolated_gh()   - etc.

**Arguments:**

- `  $1 - npm package name (e.g., "@anthropic-ai/claude-code")`
- `  $2 - lockfile field name (e.g., "claudeCodeVersion")`
- `  $3 - optional version specifier (e.g., "2.1.7" or "latest", default: latest)`

**Returns:**

-   0 - success
-   1 - error
- Side effects:
-   - Installs package globally via npm install -g
-   - Updates lockfile with installed version

**Example:**

```bash
  install_npm_package_with_lockfile "@anthropic-ai/claude-code" "claudeCodeVersion"
  install_npm_package_with_lockfile "@musistudio/claude-code-router" "routerVersion"
  install_npm_package_with_lockfile "pyright" "lspServers.pyright" "1.1.347"
```

