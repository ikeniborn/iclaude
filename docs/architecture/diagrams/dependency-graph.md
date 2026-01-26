# Loop Mode Component Dependency Graph

**Generated:** 2026-01-25
**Version:** 1.0.0

This diagram visualizes the dependencies between loop mode components in iclaude.sh.

## Component Dependency Graph

```mermaid
graph TD
    %% Components
    ArgParser["Argument Parser<br/>iclaude.sh:5092-5150"]
    TaskParser["Task Parser<br/>iclaude.sh:2180-2350"]
    SeqExec["Sequential Executor<br/>iclaude.sh:2500-2650"]
    ParExec["Parallel Executor<br/>iclaude.sh:2650-2850"]
    WorktreeM["Worktree Manager<br/>iclaude.sh:2350-2500"]
    AIResolver["AI Conflict Resolver<br/>iclaude.sh:2400-2480"]
    ClaudeInv["Claude Invoker<br/>iclaude.sh:2280-2350"]
    CompVerify["Completion Verifier<br/>iclaude.sh:2220-2280"]
    GitInt["Git Integrator<br/>iclaude.sh:2480-2550"]
    StateM["State Manager<br/>iclaude.sh:2550-2650"]

    %% Dependencies
    ArgParser -->|routes to| SeqExec
    ArgParser -->|routes to| ParExec
    SeqExec -->|loads| TaskParser
    SeqExec -->|executes| ClaudeInv
    SeqExec -->|verifies| CompVerify
    SeqExec -->|commits| GitInt
    SeqExec -->|saves| StateM
    ParExec -->|loads| TaskParser
    ParExec -->|creates| WorktreeM
    ParExec -->|executes| ClaudeInv
    ParExec -->|saves| StateM
    WorktreeM -->|resolves| AIResolver
    AIResolver -->|invokes| ClaudeInv

    %% Styling
    classDef inputLayer fill:#e1f5ff,stroke:#0288d1,stroke-width:2px
    classDef executionLayer fill:#fff4e1,stroke:#f57c00,stroke-width:2px
    classDef aiLayer fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef infraLayer fill:#e1ffe1,stroke:#388e3c,stroke-width:2px
    classDef validationLayer fill:#ffe1e1,stroke:#d32f2f,stroke-width:2px

    class ArgParser,TaskParser inputLayer
    class SeqExec,ParExec executionLayer
    class ClaudeInv,AIResolver aiLayer
    class WorktreeM,GitInt,StateM infraLayer
    class CompVerify validationLayer
```
