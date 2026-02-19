# executor

> **Module:** `loop` | **File:** `lib/loop/executor.sh`

lib/loop/executor.sh
Loop Mode - Sequential Execution Orchestrator
Part of Phase 12: Loop Mode extraction from iclaude-legacy.sh
Contains sequential task execution logic with retry support

---

### `invoke_claude_iteration`

Invoke Claude Code for one iteration Executes Claude with task prompt and logs output

**Arguments:**

- `  $1 - Task ID (e.g., "task_0")`
- `  $2 - Iteration number`

**Returns:**

-   Exit code from Claude Code execution

### `verify_completion_promise`

Verify completion promise is met Executes validation command and checks output

**Arguments:**

- `  $1 - Task ID`

**Returns:**

-   0 - Promise met (task successful)
-   1 - Promise not met (retry needed)

### `execute_single_iteration`

Execute single iteration (no retry logic) Wrapper around invoke_claude_iteration with state tracking

**Arguments:**

- `  $1 - Task ID`
- `  $2 - Iteration number (default: 1)`

**Returns:**

-   0 - Iteration executed (does not verify promise)
-   1 - Execution failed

### `execute_sequential_mode`

Execute tasks in sequential mode Main orchestrator for loop mode sequential execution

**Arguments:**

- `  $1 - Path to task file (.md)`

**Returns:**

-   0 - All tasks completed successfully
-   1 - All tasks failed
-   2 - Partial success (some tasks failed)

