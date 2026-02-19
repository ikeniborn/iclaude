# dispatch

> **Module:** `command` | **File:** `lib/command/dispatch.sh`

lib/command/dispatch.sh
Command Handling - Command Dispatcher
Part of Phase 14: Command Handling extraction from iclaude-legacy.sh
NOTE: This is a thin wrapper. Full extraction deferred to post-v4.0 refactoring.
      Current implementation delegates to main() in legacy for command dispatch.

---

### `dispatch_command`

Dispatch to appropriate command handler

**Arguments:**

- `  None (uses global flags set by parse_cli_arguments)`

**Returns:**

-   0 - Command executed successfully
-   1 - Command failed

