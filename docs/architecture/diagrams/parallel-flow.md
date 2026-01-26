# Parallel Execution Flow

**Generated:** 2026-01-25

This diagram shows the parallel task execution flow with git worktree isolation.

```mermaid
sequenceDiagram
    participant User
    participant ArgParser as Argument Parser
    participant TaskParser as Task Parser
    participant ParExec as Parallel Executor
    participant WorktreeM as Worktree Manager
    participant ClaudeInv as Claude Invoker
    participant AIResolver as AI Conflict Resolver

    User->>ArgParser: ./iclaude.sh --loop-parallel tasks.md
    ArgParser->>TaskParser: load_all_tasks(tasks.md)
    TaskParser-->>ParExec: TASKS[] array grouped by PARALLEL_GROUP
    
    Note over ParExec: Group 1: 2 parallel tasks
    
    ParExec->>WorktreeM: create_task_worktree(task-1)
    WorktreeM->>WorktreeM: git worktree add .git/worktrees/loop-task-1
    WorktreeM-->>ParExec: worktree_path_1
    
    ParExec->>WorktreeM: create_task_worktree(task-2)
    WorktreeM->>WorktreeM: git worktree add .git/worktrees/loop-task-2
    WorktreeM-->>ParExec: worktree_path_2
    
    par Task 1 (background)
        ParExec->>ClaudeInv: Execute in worktree_1
        ClaudeInv->>External: Claude Code (task-1)
        External-->>ClaudeInv: Changes in worktree_1
    and Task 2 (background)
        ParExec->>ClaudeInv: Execute in worktree_2
        ClaudeInv->>External: Claude Code (task-2)
        External-->>ClaudeInv: Changes in worktree_2
    end
    
    ParExec->>ParExec: wait for all background jobs
    
    ParExec->>WorktreeM: merge_worktree_changes(worktree_1)
    WorktreeM->>WorktreeM: git merge changes from worktree_1
    
    alt No Conflicts
        WorktreeM-->>ParExec: Merge success
    else Conflicts Detected
        WorktreeM->>AIResolver: resolve_merge_conflicts_ai()
        AIResolver->>AIResolver: Read conflicted files
        AIResolver->>AIResolver: Build resolution prompt
        AIResolver->>ClaudeInv: Invoke Claude for resolution
        ClaudeInv->>External: Claude Code (conflict resolution)
        External-->>AIResolver: Resolved files
        AIResolver->>AIResolver: Verify no conflict markers
        AIResolver->>WorktreeM: Stage resolved files
        WorktreeM-->>ParExec: Conflict resolved
    end
    
    ParExec->>WorktreeM: merge_worktree_changes(worktree_2)
    WorktreeM->>WorktreeM: git merge changes from worktree_2
    WorktreeM-->>ParExec: Merge success
    
    ParExec->>WorktreeM: cleanup_worktree(task-1)
    WorktreeM->>WorktreeM: git worktree remove .git/worktrees/loop-task-1
    
    ParExec->>WorktreeM: cleanup_worktree(task-2)
    WorktreeM->>WorktreeM: git worktree remove .git/worktrees/loop-task-2
    
    Note over ParExec: Group 0: Sequential tasks
    ParExec->>ParExec: Execute sequential tasks
    
    ParExec-->>User: ✅ All tasks completed
```

## Parallel Execution Phases

1. **Task Loading:** Parse multiple "# Task:" sections from Markdown
2. **Grouping:** Group tasks by PARALLEL_GROUP field (0 = sequential, 1+ = parallel)
3. **Worktree Creation:** Create isolated git worktrees for each parallel task
4. **Background Execution:** Spawn Claude Code in background (max 5 parallel)
5. **Synchronization:** Wait for all background jobs to complete
6. **Merging:** Merge changes from worktrees back to main working tree
7. **Conflict Resolution:** AI-assisted resolution if merge conflicts detected
8. **Cleanup:** Remove temporary worktrees after successful merge
9. **Sequential Tasks:** Execute Group 0 tasks sequentially after parallel group
10. **Exit:** Return 0 (success), 2 (partial), or 4 (unresolved conflicts)

## Worktree Structure

```
project/
├── .git/
│   └── worktrees/
│       ├── loop-task-1-1738012345/
│       │   ├── HEAD
│       │   └── gitdir
│       └── loop-task-2-1738012346/
│           ├── HEAD
│           └── gitdir
├── (main working tree)
└── task-1/ (worktree 1)
    └── task-2/ (worktree 2)
```

## AI Conflict Resolution

When merge conflicts occur:
1. Detect conflicts: `git diff --name-only --diff-filter=U`
2. Read conflicted file with markers
3. Build prompt: "Resolve git conflict in {file}..."
4. Invoke Claude Code to generate resolved content
5. Verify no markers remain: `! grep -E "^<<<<<<<|^=======|^>>>>>>>" file`
6. Stage resolved file: `git add file`
7. Complete merge: `git commit --no-edit`
