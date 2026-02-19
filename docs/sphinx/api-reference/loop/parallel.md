# parallel

> **Module:** `loop` | **File:** `lib/loop/parallel.sh`

lib/loop/parallel.sh
Loop Mode - Parallel Execution Orchestrator
Part of Phase 13: Loop Mode extraction from iclaude-legacy.sh
Contains parallel task execution logic with git worktree isolation

---

### `execute_task_with_retry`

Execute single task with retry logic Helper wrapper for both sequential and parallel execution

**Arguments:**

- `  $1 - Task ID`

**Returns:**

-   0 - Task completed
-   1 - Task failed after retries

### `execute_parallel_group`

Execute parallel group of tasks Executes tasks in parallel with worktree isolation

**Arguments:**

- `  $1 - Space-separated task IDs (e.g., "task_0 task_1 task_2")`
- `  $2 - Max parallel agents (default: 5)`

**Returns:**

-   0 - All tasks in group attempted (check COMPLETED_TASKS for success)

### `execute_parallel_mode`

Execute tasks in parallel mode Main orchestrator for parallel execution with group support

**Arguments:**

- `  $1 - Path to task file (.md)`
- `  $2 - Max parallel agents (default: 5)`

**Returns:**

-   0 - All tasks completed successfully
-   1 - All tasks failed
-   2 - Partial success (some tasks failed)

