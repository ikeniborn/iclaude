# launch

> **Module:** `launcher` | **File:** `lib/launcher/launch.sh`

Launcher module
Provides function for launching Claude Code with router and binary detection

---

### `launch_claude`

Launch Claude Code Detects and launches Claude Code binary (native or via router)

**Arguments:**

- `  $1 - skip_isolated (optional): "true" to skip isolated environment`
- `  $@ - Additional arguments passed to Claude Code`

**Returns:**

-   Does not return (uses exec)

