# validation

> **Module:** `core` | **File:** `lib/core/validation.sh`

Validation Module
Description: Utility functions for validating dependencies, files, and other preconditions

---

### `validate_dependency`

Validate that a command exists on the system

**Arguments:**

- `  $1 - Command name (e.g., "jq", "git", "node")`
- `  $2 - Installation hint (optional, e.g., "Install with: sudo apt install jq")`

**Returns:**

-   0 - Command exists
-   1 - Command not found

**Example:**

```bash
  validate_dependency "jq" "Install with: sudo apt install jq" || return 1
```

### `validate_file_exists`

Validate that a file exists

**Arguments:**

- `  $1 - File path`

**Returns:**

-   0 - File exists
-   1 - File not found

### `validate_directory_exists`

Validate that a directory exists

**Arguments:**

- `  $1 - Directory path`

**Returns:**

-   0 - Directory exists
-   1 - Directory not found

