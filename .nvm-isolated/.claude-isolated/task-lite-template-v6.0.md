# Task Execution v6.0

**Назначение:** Адаптивный workflow с SGR + Structured Output и lazy-loading skills + ralph-loop plugin integration

---

## Задачи

Опишите задачу здесь.

---

## Execution Flow

### Data Flow
```
PHASE 0 → {project_context, complexity}
        ↓
PHASE 1 → {task_plan, execution_mode_recommendation}
        ↓
PHASE 2 → {approval} [conditional]
        ↓
PHASE 3 → [MODE SELECTION]
        ├─ Standard: {execution_results}
        └─ Ralph-Loop: {execution_results, iteration_count}
        ↓
PHASE 4 → {validation_results}
        ↓
PHASE 5 → {git_result}
```

---

### PHASE 0: Context & Complexity

**Skills:**
- `@skill:context-awareness` → {project_context}
- `@skill:adaptive-workflow` → {complexity, workflow_mode}

**Complexity levels:** minimal | standard | complex

---

### PHASE 1: Analysis & Planning (COT)

**Thinking:**
- `@skill:thinking-framework → @template:analysis`
- `@skill:thinking-framework → @template:decision` [if needed]

**Planning:**
- `@skill:structured-planning → @template:task-plan-lite` [minimal]
- `@skill:structured-planning → @template:task-plan` [standard/complex]

**Output:** {task_plan, execution_mode_recommendation}

---

### PHASE 2: Approval

**Conditional:** Skip for minimal complexity

**Skill:** `@skill:approval-gates → @template:approval-lite`

**Output:** {approval} → yes/no/modify

---

### PHASE 3: Execution

**Mode Selection:**

Determine execution mode based on task characteristics:

**Decision Criteria:**
- Has automatic validation? (tests, linting, build)
- Multiple iterations expected? (>2 refinements)
- Completion detectable via validation output?
- Complexity = complex OR execution_steps > 5?

**Mode A: Standard Execution** (default)

**Execute:** task_plan.execution_steps
**Syntax:** project_context.syntax_command
**Review:** `@skill:code-review` [if complexity != minimal]

**Output:** {execution_results}

---

**Mode B: Ralph-Loop Execution** (conditional)

**Trigger Conditions:**
- Automatic validation available (tests/linting/build)
- Multiple iterations expected (refinement task)
- Clear completion promise detectable via validation
- Complexity = complex OR execution_steps > 5

**Setup:**
1. Confirm with user: "This task benefits from ralph-loop. Proceed?"
2. Define completion promise from validation output
3. Set max iterations (default: 20-50 based on complexity)

**Command:**
```bash
/ralph-loop "{task_plan.task_name}" \
  --completion-promise "{promise}" \
  --max-iterations {N}
```

**Loop Workflow:**
```
ITERATION N:
├─ Execute execution_steps[]
├─ Run validation command
├─ Check completion promise in validation output
│  ├─ Found → Claude outputs completion promise text → EXIT LOOP
│  └─ Not found → Continue to next iteration
└─ Claude sees previous work in files/git → Self-corrects
```

**Important:** Claude outputs completion promise text directly (not wrapped in tags) when condition is completely TRUE.

**Exit Conditions:**
- Completion promise detected in validation output
- Max iterations reached
- Manual cancellation via `/cancel-ralph`

**Output:** {execution_results, iteration_count}

---

### PHASE 4: Validation

**Skills:**
- `@skill:validation-framework → @template:validation-lite` [minimal]
- `@skill:validation-framework → @template:validation-full` [standard/complex]

**On FAILED:**
- `@skill:error-handling` (retry max 2)
- `@skill:rollback-recovery` (if exhausted)

**Output:** {validation_results} → PASSED/FAILED

---

### PHASE 5: Finalization

**Skills:**
- `@skill:git-workflow → @template:commit`
- `@skill:git-workflow → @template:task-summary`

**Output:** {git_result} + summary

---

## Error Handling

**Skill:** `@skill:error-handling`

| Error Type | Action | Max Retries | Notes |
|------------|--------|-------------|-------|
| SYNTAX_ERROR | BLOCKING, fix immediately | 2 | |
| VALIDATION_FAILED | RETRY | 2 | |
| PRD_CONFLICT | ASK user | 0 | |
| APPROVAL_REJECTED | STOP | 0 | |
| GIT_FAILED | STOP | 0 | |
| RALPH_MAX_ITERATIONS | STOP, report progress | 0 | Ralph-loop exhausted |
| RALPH_STUCK_LOOP | Cancel ralph, ASK user | 0 | Same error 3+ iterations |

**On retry exhaustion:**
**Skill:** `@skill:rollback-recovery`

---

## Skills & Plugins Reference

| Tool | Type | Phase | Purpose |
|------|------|-------|---------|
| context-awareness | Skill | 0 | Detect project context |
| adaptive-workflow | Skill | 0 | Determine complexity |
| thinking-framework | Skill | 1 | COT reasoning |
| structured-planning | Skill | 1 | Create task plan |
| approval-gates | Skill | 2 | User approval [conditional] |
| ralph-loop | Plugin | 3 | Iterative execution [conditional] |
| code-review | Skill | 3 | Quality checks [conditional] |
| validation-framework | Skill | 4 | Verify acceptance criteria |
| error-handling | Skill | 4 | Handle failures |
| rollback-recovery | Skill | 4 | Rollback on errors |
| git-workflow | Skill | 5 | Commit + summary |

---

## Key Principles

**SGR (Structured Generation & Reasoning):**
- Thinking (hidden COT) → Structured Output (JSON)
- Each phase produces structured data
- Chain: thinking → plan → execute → validate → commit

**Data Flow:**
- PHASE N output → PHASE N+1 input
- Dependencies: validation uses task_plan.acceptance_criteria
- Adaptive: complexity drives workflow mode

**Lazy Loading:**
- minimal: 7 skills (~300 lines from skills)
- standard: 9 skills (~400 lines)
- complex: 10 skills (~500 lines)

---

## Ralph-Loop Integration Examples

### Example 1: Fix TypeScript Errors (Ralph-Loop)

**Task:** "Fix all TypeScript compilation errors"

**Mode Selection:**
- ✓ Automatic validation: `npm run build`
- ✓ Iterations expected: Unknown (could be many)
- ✓ Completion detectable: "Compiled successfully" in output
- ✓ Complexity: standard
- → **Recommend ralph-loop**

**Command:**
```bash
/ralph-loop "Fix all TypeScript compilation errors" \
  --completion-promise "COMPILED SUCCESSFULLY" \
  --max-iterations 20
```

**Loop Behavior:**
```
Iteration 1: Fix 5 errors → npm run build → 12 errors remain → Continue
Iteration 2: Fix 7 errors → npm run build → 5 errors remain → Continue
Iteration 3: Fix 5 errors → npm run build → Success! → Output promise → EXIT
```

---

### Example 2: Add API Endpoint (Standard)

**Task:** "Add GET /api/users endpoint"

**Mode Selection:**
- ✗ Single-pass task (create file, write code, test manually)
- ✗ Manual verification needed
- → **Use standard execution**

**Workflow:**
```
Phase 3: Execute execution_steps
  1. Create endpoint file ✓
  2. Write handler logic ✓
  3. Add route registration ✓
Phase 4: Validation (manual curl test)
```

---

### Example 3: Refactor for ESLint (Ralph-Loop)

**Task:** "Refactor codebase to pass ESLint rules"

**Mode Selection:**
- ✓ Automatic validation: `npm run lint`
- ✓ Iterations expected: Many files to fix
- ✓ Completion detectable: "0 errors, 0 warnings"
- ✓ Complexity: complex
- → **Recommend ralph-loop**

**Command:**
```bash
/ralph-loop "Refactor codebase to pass ESLint rules" \
  --completion-promise "LINT CLEAN" \
  --max-iterations 50
```

---
