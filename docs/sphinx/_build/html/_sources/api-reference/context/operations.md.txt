# operations

> **Module:** `context` | **File:** `lib/context/operations.sh`

lib/context/operations.sh
Context Management - CRUD Operations
Part of Phase 10: Context Management extraction from iclaude-legacy.sh
Contains 6 context operation functions (export/import/sync/clean/backup/status)

---

### `context_cmd_export`

Export context to archive Creates tar.gz with memory + filtered history

**Arguments:**

- `  $1 - Project path (default: pwd)`

**Returns:**

-   0 on success, 1 on failure
- Outputs:
-   Archive path and instructions

### `context_cmd_import`

Import context from archive Extracts memory + history to current project

**Arguments:**

- `  $1 - Archive file path`
- `  $2 - Target project path (default: pwd)`

**Returns:**

-   0 on success, 1 on failure
- Outputs:
-   Import progress and confirmation

### `context_cmd_sync`

Sync context between main repo and worktrees Bidirectional sync via shared directory

**Arguments:**

- `  $1 - Direction: "pull" or "push" (default: pull)`
- `  $2 - Project path (default: pwd)`

**Returns:**

-   0 on success
- Outputs:
-   Sync progress

### `context_cmd_clean`

Clean old context data Removes old sessions and trims history

**Arguments:**

- `  $1 - Days threshold (default: CONTEXT_CLEANUP_DAYS)`

**Returns:**

-   0 on success
- Outputs:
-   Cleanup progress

### `context_cmd_backup`

Backup context data Creates timestamped backup of history + projects

**Arguments:**

- `  $1 - Backup mode: "manual", "daily", "weekly" (default: manual)`

**Returns:**

-   0 on success
- Outputs:
-   Backup location and size

### `context_cmd_status`

Show context status Displays memory, history, sessions, worktree info

**Arguments:**

- `  $1 - Project path (default: pwd)`

**Returns:**

-   0 on success
- Outputs:
-   Detailed context status

### `list_sessions_cmd`

list_sessions_cmd Lists all active Claude Code sessions with metadata

**Arguments:**

- `  none`

**Returns:**

-   0 on success
- Outputs:
-   Table of sessions with date, slug, branch, project

