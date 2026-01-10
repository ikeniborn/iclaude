# Task Execution v7.0

**Назначение:** Адаптивный workflow с SGR + Structured Output и lazy-loading skills + ralph-loop plugin integration

---

## Задачи

[User input секция - вставляется пользователем]

Явное описание режима если требуется:
**Режим выполнения:** ralph-loop
**Completion promise:** "COMPILED SUCCESSFULLY"
**Max iterations:** 20
**Validation command:** npm run build

**CORE REQUIREMENTS:**

1. **📚 Pre-flight:** Изучить `/docs/architecture` перед началом изменений
2. **📝 Logging:** Всегда добавлять полное логирование (frontend/backend)
3. **🔍 Self-review:** После подготовки плана проанализировать результаты повторно
4. **💡 Best practices:** Применять эффективные паттерны разработки
5. **❓ Clarification:** При планировании задавать вопросы для уточнения
6. **📖 Documentation:** После всех изменений актуализировать `/docs/architecture`
7. **💾 Finalization:** По завершению обязательно коммит и пуш

---

## Execution Flow

### Data Flow
```
PHASE 0 → @skill:context-awareness → {project_context}
        → @skill:adaptive-workflow → {complexity}
        ↓
PHASE 1 → @skill:thinking-framework (analysis/decision)
        → @skill:structured-planning → {task_plan}
        ↓
PHASE 2 → @skill:approval-gates [if standard/complex] → {approval}
        ↓
PHASE 3 → [MODE SELECTION]
        ├─ Standard: Execute + @skill:code-review
        └─ Ralph-Loop: /ralph-loop + validation loop
        ↓
PHASE 4 → @skill:validation-framework → {validation_results}
        → @skill:error-handling [on errors]
        ↓
PHASE 5 → @skill:git-workflow → {git_result} + summary
```

---

## Phase Details

### PHASE 0: Context & Complexity

**Skills:**
- `@skill:context-awareness` → Detect project language, framework, PRD
- `@skill:adaptive-workflow` → Determine complexity (minimal|standard|complex)

**Complexity determines:** Which templates to use, which phases to skip, which mode to recommend

---

### PHASE 1: Analysis & Planning (COT)

**Thinking:**
- `@skill:thinking-framework → @template:analysis` - For task analysis
- `@skill:thinking-framework → @template:decision` - If multiple approaches exist
- `@skill:thinking-framework → @template:risk` - For breaking changes

**Planning:**
- `@skill:structured-planning → @template:task-plan-lite` [minimal complexity]
- `@skill:structured-planning → @template:task-plan` [standard/complex complexity]

**Output:** {task_plan, execution_mode_recommendation}

---

### PHASE 2: Approval

**Conditional:** Skip for minimal complexity

**Skill:** `@skill:approval-gates → @template:approval-lite` [standard] or `@template:approval-full` [complex]

**Response handling:** yes → proceed | no → stop | modify → return to Phase 1

---

### PHASE 3: Execution

**Mode Selection Criteria:**

Use **ralph-loop** when ALL conditions met:
- ✓ Automatic validation available (tests/build/lint)
- ✓ Multiple iterations expected (>2 refinement cycles)
- ✓ Clear completion promise detectable in validation output
- ✓ Complexity = complex OR execution_steps > 5

Otherwise use **standard execution**.

---

**Mode A: Standard Execution** (default)

1. Execute task_plan.execution_steps sequentially
2. Run syntax validation using project_context.syntax_command
3. `@skill:code-review` [if complexity != minimal]

**Output:** {execution_results}

---

**Mode B: Ralph-Loop Execution** (conditional)

**Setup:**
1. Confirm with user: "This task benefits from ralph-loop. Proceed?"
2. Define completion promise from validation output
3. Set max iterations (20-50 based on complexity)

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
│  ├─ Found → Claude outputs promise text → EXIT LOOP
│  └─ Not found → Continue (Claude self-corrects from previous work)
└─ Repeat until promise found or max iterations
```

**Exit Conditions:**
- Completion promise detected → Success
- Max iterations reached → Report progress
- Manual cancellation via `/cancel-ralph`

**Output:** {execution_results, iteration_count}

---

### PHASE 4: Validation

**Skills:**
- `@skill:validation-framework → @template:validation-lite` [minimal]
- `@skill:validation-framework → @template:validation-full` [standard/complex]

**On FAILED:**
- `@skill:error-handling` (retry max 2, see skill for error type actions)
- `@skill:rollback-recovery` (if retries exhausted)

**Output:** {validation_results} → PASSED/FAILED

---

### PHASE 5: Finalization

**Skills:**
- `@skill:git-workflow → @template:commit` - Conventional Commits format
- `@skill:git-workflow → @template:task-summary` - User-facing summary

**Output:** {git_result} + formatted summary

---

## Key Principles

**SGR (Structured Generation & Reasoning):**
- Thinking (hidden COT) → Structured Output (JSON) → Execute → Validate → Commit
- Each phase produces structured data for next phase

**Adaptive Workflow:**
- Complexity drives workflow mode (minimal=lite, standard=full, complex=phase-based)
- Auto-skip unnecessary phases based on complexity

**Lazy Loading:**
- minimal: 7 skills (~300 lines loaded from skills)
- standard: 9 skills (~400 lines)
- complex: 10 skills (~500 lines)

**Data Flow:**
- PHASE N output → PHASE N+1 input
- Dependencies: validation uses task_plan.acceptance_criteria
- Error handling uses retry counts from error-handling skill

---

## Ralph-Loop Quick Reference

**When to use:** Tasks with automatic validation and iterative refinement

**Example scenarios:**
- Fix all TypeScript compilation errors → Promise: "COMPILED SUCCESSFULLY"
- Refactor codebase to pass ESLint → Promise: "0 errors, 0 warnings"
- Fix all failing tests → Promise: "All tests passed"

**NOT recommended for:**
- Single-pass tasks (create endpoint, add feature)
- Tasks requiring manual verification
- Tasks without clear validation output

**How it works:**
1. Execute task → Run validation → Check output for promise
2. If promise NOT found → Continue next iteration (Claude sees previous work and self-corrects)
3. If promise FOUND → Claude outputs promise text directly → Plugin exits loop
4. Max iterations → Stop and report how far we got

**Important:** Claude outputs completion promise text directly (not wrapped in tags) when condition is TRUE.

---

## Skills Quick Reference

All detailed logic, templates, schemas, and examples are in skills:

| Phase | Skill | Purpose |
|-------|-------|---------|
| 0 | context-awareness | Detect project context |
| 0 | adaptive-workflow | Determine complexity |
| 1 | thinking-framework | COT reasoning (3 templates) |
| 1 | structured-planning | Create task plan (JSON) |
| 2 | approval-gates | User approval [conditional] |
| 3 | ralph-loop | Iterative execution [plugin] |
| 3 | code-review | Quality checks [conditional] |
| 4 | validation-framework | Verify acceptance criteria |
| 4 | error-handling | Handle failures with retries |
| 4 | rollback-recovery | Rollback on exhausted retries |
| 5 | git-workflow | Commit + summary |

**Note:** All error types, retry logic, templates, and schemas are defined in their respective skills. This template provides only the orchestration flow.

---
