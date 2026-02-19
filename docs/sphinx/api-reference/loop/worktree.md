# worktree

> **Module:** `loop` | **File:** `lib/loop/worktree.sh`

lib/loop/worktree.sh
Loop Mode - Git Worktree Management + AI Merge Conflict Resolution
Part of Phase 13: Loop Mode extraction from iclaude-legacy.sh
⚠️ HIGH RISK: Contains AI-powered merge conflict resolution
IMPORTANT SAFETY NOTES:
- resolve_merge_conflicts_ai() uses AI to modify code - requires careful validation
- Always backup before merge (use git stash)
- Validate AI output for conflict markers
- Recommend --parallel-dry-run for testing
- Recommend --parallel-require-approval for production

---

### `create_task_worktree`

Create git worktree for task isolation Creates isolated worktree with unique branch for parallel execution

**Arguments:**

- `  $1 - Task ID (e.g., "task_0")`

**Returns:**

-   0 - Worktree created successfully
-   1 - Creation failed

### `cleanup_worktree`

Cleanup git worktree after task completion Attempts graceful removal, falls back to force, then manual cleanup

**Arguments:**

- `  $1 - Task ID`

**Returns:**

-   0 - Worktree removed successfully (always succeeds)

### `merge_worktree_changes`

Merge worktree changes back to main branch Attempts merge with patience strategy, invokes AI if conflicts detected

**Arguments:**

- `  $1 - Task ID`

**Returns:**

-   0 - Merge successful
-   1 - Merge failed (conflicts unresolved)

### `resolve_merge_conflicts_ai`

Resolve merge conflicts using AI (⚠️ HIGHEST RISK FUNCTION) Uses Claude to intelligently resolve git merge conflicts

**Arguments:**

- `  $1 - Task ID`

**Returns:**

-   0 - Conflicts resolved and committed
-   1 - Resolution failed (markers present or AI error)

