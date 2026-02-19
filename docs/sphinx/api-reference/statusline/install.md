# install

> **Module:** `statusline` | **File:** `lib/statusline/install.sh`

Statusline installation module
Provides functions for installing and configuring statusline script

---

### `configure_statusline_in_settings`

Configure statusLine in settings.json Updates Claude Code settings to enable custom status line script

**Arguments:**

- `  $1 - absolute path to statusline script`

**Returns:**

-   0 - success
-   1 - error

### `install_statusline_script`

Install statusline script for Claude Code Creates claude-statusline.sh and configures settings.json

**Returns:**

-   0 - success
-   1 - error

