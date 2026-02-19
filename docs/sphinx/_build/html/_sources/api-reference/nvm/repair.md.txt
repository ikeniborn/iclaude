# repair

> **Module:** `nvm` | **File:** `lib/nvm/repair.sh`

NVM Repair Module
Description: Repair symlinks and permissions after git clone or repository moves

---

### `repair_isolated_environment`

Repair isolated environment Fixes broken symlinks and permissions after git clone

**Returns:**

-   0 - success (all repairs successful)
-   1 - errors found that couldn't be fixed
- Side effects:
-   - Recreates npm/npx/corepack symlinks
-   - Recreates Claude Code symlink
-   - Fixes file permissions

### `create_npm_symlinks`

Create npm/npx/corepack symlinks

**Arguments:**

- `  $1 - Node.js version directory (e.g., /path/to/.nvm-isolated/versions/node/v18.20.8)`

**Returns:**

-   0 - success
-   1 - errors found

### `create_claude_symlink`

Create Claude Code symlink

**Returns:**

-   0 - success
-   1 - error

