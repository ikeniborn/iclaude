# Sequential Execution Flow

**Generated:** 2026-01-25

This diagram shows the sequential task execution flow from user invocation to completion.

```mermaid
sequenceDiagram
    participant User
    participant ArgParser as Argument Parser
    participant TaskParser as Task Parser
    participant SeqExec as Sequential Executor
    participant ClaudeInv as Claude Invoker
    participant CompVerify as Completion Verifier
    participant GitInt as Git Integrator
    participant StateM as State Manager

    User->>ArgParser: ./iclaude.sh --loop task.md
    ArgParser->>TaskParser: load_markdown_task(task.md)
    TaskParser-->>SeqExec: TASK metadata
    
    loop Iterations (max 5)
        SeqExec->>ClaudeInv: invoke_claude_iteration(task, iteration)
        ClaudeInv->>ClaudeInv: Build prompt with context
        ClaudeInv->>External: Execute Claude Code CLI
        External-->>ClaudeInv: Exit code + logs
        ClaudeInv-->>SeqExec: Iteration result
        
        SeqExec->>CompVerify: verify_completion_promise()
        CompVerify->>CompVerify: Run validation command
        CompVerify->>CompVerify: Match regex pattern
        
        alt Promise Met
            CompVerify-->>SeqExec: Success (0)
            SeqExec->>GitInt: git_commit_task_changes()
            GitInt->>GitInt: Create branch
            GitInt->>GitInt: Stage changes
            GitInt->>GitInt: Commit with Co-Authored-By
            GitInt->>GitInt: Optional auto-push
            GitInt-->>SeqExec: Commit SHA
            SeqExec->>StateM: save_loop_state()
            StateM-->>User: ✅ Task completed
        else Promise Not Met
            CompVerify-->>SeqExec: Failure (1)
            SeqExec->>SeqExec: Exponential backoff (2s→4s→8s)
            Note over SeqExec: Wait before retry
        end
    end
    
    alt Max Iterations Reached
        SeqExec-->>User: ❌ Exit code 1 (max iterations)
    end
```

## Flow Steps

1. **User Invocation:** `./iclaude.sh --loop task.md`
2. **Argument Parsing:** Detect `--loop` flag, extract task file path
3. **Task Loading:** Parse Markdown to extract task metadata
4. **Iteration Loop:** Execute up to max iterations (default 5)
   - Invoke Claude Code for task execution
   - Verify completion promise via validation command
   - On success: commit changes and exit
   - On failure: wait (exponential backoff) and retry
5. **Git Integration:** Create branch, commit with Co-Authored-By, optional push
6. **State Persistence:** Save loop state for recovery
7. **Exit:** Return 0 (success) or 1 (max iterations reached)

## Exponential Backoff

| Iteration | Delay Before Retry |
|-----------|-------------------|
| 1 → 2 | 2 seconds |
| 2 → 3 | 4 seconds |
| 3 → 4 | 8 seconds |
| 4 → 5 | 16 seconds |
| 5 → Max | 32 seconds (capped at 60s) |
