# git

> **Module:** `loop` | **File:** `lib/loop/git.sh`

lib/loop/git.sh
Loop Mode - Git Integration
Part of Phase 12: Loop Mode extraction from iclaude-legacy.sh
Contains git commit and push operations after task completion

---

### `git_commit_task_changes`

Git commit task changes Commits changes after successful task execution with optional auto-push

**Arguments:**

- `  $1 - Task ID`

**Returns:**

-   0 - Changes committed successfully or no git config
-   1 - Commit or push failed

