# detect

> **Module:** `router` | **File:** `lib/router/detect.sh`

Router detection module
Provides functions for detecting Claude Code Router installation

---

### `detect_router`

Detect if Claude Code Router is available Checks if router.json exists and ccr binary is installed

**Arguments:**

- `  $1 - skip_isolated (optional): "true" to skip isolated environment`

**Returns:**

-   0 - Router available (config + binary)
-   1 - Router not available

### `get_router_path`

Get path to ccr binary

**Arguments:**

- `  $1 - skip_isolated (optional): "true" to skip isolated environment`

**Returns:**

-   ccr binary path or empty string

