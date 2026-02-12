# Loop Mode Modules (Phase 11-13)

## Overview

Loop Mode enables sequential and parallel execution of Claude Code tasks defined in Markdown files. Phase 11 focuses on task loading and parsing.

**Phase 11 Status:** ✅ COMPLETE (Task Loading)
**Phase 12 Status:** 🔜 PLANNED (Sequential Execution)
**Phase 13 Status:** 🔜 PLANNED (Parallel Execution)

---

## Phase 11: Task Loading (COMPLETE ✅)

### Extracted Functions: 5
- `load_markdown_task()` - Parse single task from Markdown
- `load_all_tasks()` - Parse multiple tasks from file
- `validate_task_file_format()` - Validate Markdown structure
- `save_loop_state()` - Persist execution state
- `load_loop_state()` - Restore execution state

### Lines of Code: 354
- parser.sh: 202 lines (2 functions)
- validator.sh: 68 lines (1 function)
- state.sh: 84 lines (2 functions)

### Risk Level: MEDIUM
- Task parsing: LOW risk (text processing)
- State persistence: MEDIUM risk (file I/O, JSON handling)

---

## Module: parser.sh

**Purpose:** Load and parse task definitions from Markdown files

### Global Variables (Required)

**IMPORTANT:** These associative arrays must be declared in main scope BEFORE loading parser.sh:

```bash
declare -A TASK_NAME                # Task display names
declare -A TASK_DESCRIPTION         # Task descriptions
declare -A TASK_COMPLETION_PROMISE  # Exit conditions
declare -A TASK_VALIDATION_COMMAND  # Verification commands
declare -A TASK_MAX_ITERATIONS      # Retry limits
declare -A TASK_GIT_BRANCH          # Git branch names
declare -A TASK_GIT_COMMIT_MSG      # Commit messages
declare -A TASK_GIT_AUTO_PUSH       # Auto-push flags
declare -A TASK_PARALLEL_GROUP      # Parallel group IDs
declare -a TASKS                    # Task IDs array
declare -a COMPLETED_TASKS          # Completed task IDs
CURRENT_TASK=""                     # Currently executing task
CURRENT_ITERATION=0                 # Current iteration number
```

### Functions

#### `load_markdown_task(task_file, task_index)`

Parses a single task from Markdown format and populates global variables.

**Arguments:**
- `$1` - Path to `.md` file
- `$2` - Task index (default: 0)

**Returns:**
- `0` - Success
- `1` - File not found or parse error

**Markdown Format:**
```markdown
# Task: Task name

## Description
Task description text (multi-line supported)

## Completion Promise
Exit condition (e.g., "All tests pass")

## Validation Command
npm test

## Max Iterations
5

## Git Config (optional)
Branch: feature/task-name
Commit message: feat: implement task
Auto-push: true
Group: 1  (for parallel mode)
```

**Example:**
```bash
load_markdown_task "examples/test-loop-simple.md" 0
echo "Task: ${TASK_NAME[task_0]}"
echo "Validation: ${TASK_VALIDATION_COMMAND[task_0]}"
```

**Task ID Format:** `task_<index>` (e.g., `task_0`, `task_1`)

#### `load_all_tasks(task_file)`

Loads all tasks from a file containing multiple `# Task:` sections.

**Arguments:**
- `$1` - Path to `.md` file

**Returns:**
- `0` - At least one task loaded
- `1` - No tasks found or validation failed

**Workflow:**
1. Validates file format via `validate_task_file_format()`
2. Counts `# Task:` headers
3. Extracts each task section to temp file
4. Calls `load_markdown_task()` for each section
5. Populates `TASKS` array with task IDs

**Example:**
```bash
load_all_tasks "examples/multi-task.md"
echo "Loaded ${#TASKS[@]} tasks"
for task_id in "${TASKS[@]}"; do
    echo "  - ${TASK_NAME[$task_id]}"
done
```

**Multi-Task Format:**
```markdown
# Task: First task
## Description
...

# Task: Second task
## Description
...
```

---

## Module: validator.sh

**Purpose:** Validate task file structure before parsing

### Functions

#### `validate_task_file_format(task_file)`

Checks Markdown file for required sections.

**Arguments:**
- `$1` - Path to `.md` file

**Returns:**
- `0` - Valid format
- `1` - Invalid or user rejected

**Required Sections:**
- `# Task:` header (at least one)
- `## Description` section
- `## Completion Promise` section
- `## Validation Command` section

**Interactive Prompts:**
- If missing optional sections → asks user to continue
- User can reject validation (returns 1)

**Example:**
```bash
if validate_task_file_format "task.md"; then
    echo "✓ Valid task file"
    load_all_tasks "task.md"
else
    echo "✗ Invalid format"
fi
```

**Error Messages:**
```
❌ Invalid task file format

Expected format:
  # Task: Task name
  ## Description
  ## Completion Promise
  ## Validation Command
```

---

## Module: state.sh

**Purpose:** Persist loop execution state for crash recovery

### Functions

#### `save_loop_state()`

Saves current execution state to JSON file.

**Arguments:** None (reads global variables)

**Returns:** `0` (always succeeds)

**Globals Used:**
- `CURRENT_TASK` - Currently executing task ID
- `CURRENT_ITERATION` - Current iteration number
- `COMPLETED_TASKS` - Array of completed task IDs

**State File:** `/tmp/iclaude-loop-state-$$.json`

**Format:**
```json
{
  "timestamp": "2026-02-12T14:30:52+00:00",
  "current_task": "task_0",
  "iteration": 3,
  "completed_tasks": ["task_1", "task_2"]
}
```

**Example:**
```bash
CURRENT_TASK="task_0"
CURRENT_ITERATION=3
COMPLETED_TASKS=("task_1" "task_2")

save_loop_state
cat "/tmp/iclaude-loop-state-$$.json"
```

#### `load_loop_state()`

Restores execution state from JSON file.

**Arguments:** None (sets global variables)

**Returns:**
- `0` - State loaded successfully
- `1` - No state file or `jq` unavailable

**Globals Set:**
- `CURRENT_TASK`
- `CURRENT_ITERATION`
- `COMPLETED_TASKS` (array)

**Dependencies:** Requires `jq` for JSON parsing

**Example:**
```bash
# After crash, restore state
if load_loop_state; then
    echo "✓ Resumed from: $CURRENT_TASK (iteration $CURRENT_ITERATION)"
    echo "✓ Already completed: ${COMPLETED_TASKS[*]}"
else
    echo "⚠ No previous state found, starting fresh"
fi
```

**Use Case:** Recovery after interruption (Ctrl+C, system crash, SSH disconnect)

---

## Integration with iclaude.sh

### Loading (iclaude.sh:159-166)

```bash
#######################################
# Load Loop Mode modules (Phase 11)
#######################################
if [[ -d "$LIB_DIR/loop" ]]; then
    source "${LIB_DIR}/loop/validator.sh"
    source "${LIB_DIR}/loop/parser.sh"
    source "${LIB_DIR}/loop/state.sh"
fi
```

**Load Order:**
1. validator.sh (no dependencies)
2. parser.sh (depends on validator)
3. state.sh (independent)

### Guard Pattern (iclaude-legacy.sh)

All 5 functions use guard pattern:

```bash
if ! declare -F load_markdown_task &>/dev/null; then
load_markdown_task() {
    # Implementation
}
fi
```

**Guard Count:** 88 total (5 added in Phase 11)

---

## CLI Commands

### Loop Mode (Future - Phase 12-13)

```bash
# Sequential execution (Phase 12)
./iclaude.sh --loop task.md

# Parallel execution (Phase 13)
./iclaude.sh --loop-parallel task.md --max-parallel 3

# Validate task file only
./iclaude.sh --loop task.md --validate-only
```

**Phase 11 Status:** Task loading implemented ✅
**Phase 12 Status:** Sequential executor not yet implemented 🔜
**Phase 13 Status:** Parallel executor not yet implemented 🔜

---

## Testing

### Phase 11 Test Coverage

**parser.sh:**
- ✅ Parses task name from `# Task:` line
- ✅ Extracts multi-line description
- ✅ Loads completion promise and validation command
- ✅ Parses max iterations (default: 5)
- ✅ Extracts optional Git config
- ✅ Loads multiple tasks from single file

**validator.sh:**
- ✅ Detects missing `# Task:` header
- ✅ Checks for required sections
- ✅ Prompts user if sections missing
- ✅ Validates file readability

**state.sh:**
- ✅ Saves state to JSON file
- ✅ Restores state from JSON file
- ✅ Handles empty arrays correctly
- ✅ Returns error if `jq` unavailable

### Test Files

**examples/test-loop-simple.md:**
```markdown
# Task: Test Simple Execution

## Description
Test task that succeeds on first iteration.

## Completion Promise
Echo command succeeds

## Validation Command
echo "success"

## Max Iterations
1
```

**examples/test-loop-retry.md:**
```markdown
# Task: Test Retry Logic

## Description
Test exponential backoff with retries.

## Completion Promise
Counter reaches 3

## Validation Command
test -f /tmp/counter && [ $(cat /tmp/counter) -ge 3 ]

## Max Iterations
5
```

### Regression Tests

```bash
# Test task parsing
bash -c '
source lib/core/logging.sh
source lib/loop/validator.sh
source lib/loop/parser.sh

declare -A TASK_NAME TASK_DESCRIPTION TASK_COMPLETION_PROMISE
declare -A TASK_VALIDATION_COMMAND TASK_MAX_ITERATIONS
declare -a TASKS

load_markdown_task "examples/test-loop-simple.md" 0
echo "Task: ${TASK_NAME[task_0]}"
'

# Test state persistence
bash -c '
source lib/core/logging.sh
source lib/loop/state.sh

CURRENT_TASK="task_0"
CURRENT_ITERATION=3
COMPLETED_TASKS=("task_1")

save_loop_state
load_loop_state
echo "Restored: $CURRENT_TASK at iteration $CURRENT_ITERATION"
'
```

---

## Next Steps

### Phase 12: Sequential Execution (10-14 hours)

**Modules to create:**
- `lib/loop/executor.sh` - Main sequential orchestrator
- `lib/loop/retry.sh` - Exponential backoff logic
- `lib/loop/git.sh` - Git commit/push operations

**Functions to extract (5):**
- `execute_sequential_mode()` - Main loop
- `execute_single_iteration()` - One iteration
- `invoke_claude_iteration()` - Launch Claude Code
- `verify_completion_promise()` - Check validation
- `retry_task_with_backoff()` - Exponential backoff

**Key Features:**
- Retry logic with exponential backoff (2s → 60s cap)
- Completion promise verification
- Git commit after success
- State persistence after each iteration

### Phase 13: Parallel Execution (14-20 hours) ⚠️ HIGH RISK

**Modules to create:**
- `lib/loop/parallel.sh` - Parallel orchestrator
- `lib/loop/worktree.sh` - Git worktree management + **AI merge**

**Functions to extract (7):**
- `execute_parallel_mode()` - Main parallel loop
- `execute_parallel_group()` - Execute group of tasks
- `execute_task_with_retry()` - Task wrapper
- `create_task_worktree()` - Create isolated worktree
- `cleanup_worktree()` - Remove worktree
- `merge_worktree_changes()` - Merge to main
- `resolve_merge_conflicts_ai()` - **AI-powered conflict resolution** ⚠️

**Critical Risk Area:** `resolve_merge_conflicts_ai()`
- AI output may contain conflict markers → Validate before commit
- File corruption → Backup via git stash
- Infinite retry → Max 3 attempts
- Human confirmation → `--parallel-require-approval` flag
- Dry-run mode → `--parallel-dry-run` flag

**Estimated Completion:** Phase 13 (90%+ modularization)

---

## Known Limitations

### Phase 11 (Current)

1. **Global State Required:**
   - Associative arrays must be declared before loading modules
   - Cannot be declared within modules (bash limitation)
   - Documented in parser.sh header

2. **No Task Execution:**
   - Phase 11 only loads tasks, does not execute
   - Execution requires Phase 12-13 modules

3. **jq Dependency:**
   - `load_loop_state()` requires `jq` for JSON parsing
   - Returns error if `jq` unavailable

### Future Phases

**Phase 12:**
- No parallel execution (sequential only)
- No worktree isolation

**Phase 13:**
- AI merge conflict resolution (experimental)
- Requires human approval for safety

---

## Troubleshooting

### Task Parsing Issues

**Problem:** "Task name not found in file"
```bash
# Check file format
grep "^# Task:" task.md

# Expected output:
# Task: My Task Name
```

**Solution:** Ensure `# Task:` header is present on its own line.

### State Loading Issues

**Problem:** "jq not installed - cannot load state"
```bash
# Install jq
sudo apt-get install jq  # Debian/Ubuntu
brew install jq          # macOS
```

**Problem:** State file not found
```bash
# Check if state file exists
ls -l /tmp/iclaude-loop-state-*.json

# State uses PID in filename, won't persist across sessions
```

### Validation Issues

**Problem:** "Missing sections: Completion Promise"
```bash
# Add required section to task.md:
## Completion Promise
Tests pass
```

User can choose to continue if non-critical sections missing.

---

## Architecture Notes

### Why Separate Modules?

**parser.sh + validator.sh:**
- Parser focuses on extraction logic
- Validator focuses on format checking
- Clear separation of concerns

**state.sh:**
- Independent from task loading
- Can be used by executor modules (Phase 12-13)
- Crash recovery mechanism

### Design Decisions

1. **Task ID Format:** `task_<index>`
   - Predictable naming
   - Supports multiple tasks in one file

2. **Temp Files for Multi-Task:**
   - Each task section extracted to `/tmp/iclaude-task-<index>-$$.md`
   - Allows reuse of single-task parser

3. **State File Location:** `/tmp/iclaude-loop-state-$$.json`
   - Per-process isolation (uses `$$` PID)
   - Automatic cleanup on reboot
   - Trade-off: Won't survive system restart

4. **JSON State Format:**
   - Human-readable for debugging
   - Easy to modify manually if needed
   - Requires `jq` for parsing

---

## Future Enhancements

### Phase 14: Command Handling

**After Phase 11-13 extraction:**
- Extract `show_usage()` (308 lines)
- Extract `main()` argument parsing (380 lines)
- Extract `dispatch_command()` (220 lines)

### Phase 15: Final Cleanup

**Remove iclaude-legacy.sh:**
- All 129 functions extracted
- 100% modular architecture
- Release v4.0

**Estimated Timeline:**
- Phase 12: 10-14 hours
- Phase 13: 14-20 hours
- Phase 14: 8-11 hours
- Phase 15: 3-5 hours
- **Total:** 35-50 hours to 100% completion
