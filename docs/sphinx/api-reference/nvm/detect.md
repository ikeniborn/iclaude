# detect

> **Module:** `nvm` | **File:** `lib/nvm/detect.sh`

NVM Detection Module
Description: Detect NVM installation and locate Claude Code binary

---

### `detect_nvm`

Detect if NVM is available

**Arguments:**

- `  $1 - skip_isolated (optional): "true" to skip isolated environment check`

**Returns:**

-   0 - NVM is available
-   1 - NVM not found
- Priority order:
-   1. Isolated environment (.nvm-isolated/)
-   2. System NVM ($NVM_DIR/nvm.sh)
-   3. npm/node in PATH from NVM

### `get_nvm_claude_path`

Get Claude Code path from NVM environment

**Returns:**

-   Claude Code binary path on stdout
-   Exit code: 0 on success, 1 if not found
- Search order:
-   1. Standard 'claude' binary in NVM bin/
-   2. Temporary '.claude-*' binaries (sorted by mtime, newest first)
-   3. cli.js in standard claude-code/ folder
-   4. cli.js in temporary .claude-code-* folders

### `get_cli_version`

Get Claude Code CLI version

**Arguments:**

- `  $1 - CLI path (e.g., "/path/to/claude" or "node /path/to/cli.js")`

**Returns:**

-   Version string on stdout (e.g., "2.1.7")
-   Exit code: 0 on success, 1 if version not found

