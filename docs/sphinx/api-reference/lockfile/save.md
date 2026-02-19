# save

> **Module:** `lockfile` | **File:** `lib/lockfile/save.sh`

Lockfile Save Module
Description: Save current installation state to lockfile for reproducibility

---

### `save_isolated_lockfile`

Save isolated environment versions to lockfile Captures: Node.js, Claude Code, Router, GH CLI, LSP servers, LSP plugins, Sandbox, StatusLine, Oh-My-Posh

**Returns:**

-   0 - success
-   1 - error

**Example:**

```bash
  save_isolated_lockfile || return 1
```

