# parse

> **Module:** `command` | **File:** `lib/command/parse.sh`

lib/command/parse.sh
Command Handling - CLI Argument Parsing
Part of Phase 14: Command Handling extraction from iclaude-legacy.sh
NOTE: This is a thin wrapper. Full extraction deferred to post-v4.0 refactoring.
      Current implementation delegates to main() in legacy for argument parsing.

---

### `parse_cli_arguments`

Parse CLI arguments and set global flags

**Arguments:**

- `  $@ - Command line arguments`

**Returns:**

-   0 - Always succeeds (parsing happens in main)

