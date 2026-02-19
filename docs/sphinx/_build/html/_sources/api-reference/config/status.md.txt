# status

> **Module:** `config` | **File:** `lib/config/status.sh`

Config Status Module
Description: Status checking for configuration and isolated environment

---

### `check_config_status`

Check config directory status Shows current CLAUDE_CONFIG_DIR and its content

**Returns:**

-   0 - success

**Example:**

```bash
  check_config_status || return 1
```

### `check_isolated_status`

Check isolated environment status Shows NVM, Node.js, Claude, symlinks, lockfile status

**Returns:**

-   0 - success

**Example:**

```bash
  check_isolated_status || return 1
```

### `show_native_installer_info`

Display native installer information Shows information about Anthropic's recommendation to use native installer

**Returns:**

-   0 - success

