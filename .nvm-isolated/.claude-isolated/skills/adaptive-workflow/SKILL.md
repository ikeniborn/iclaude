---
name: Adaptive Workflow
description: Автоматический выбор сложности workflow
version: 2.0.0
tags: [workflow, complexity, adaptation, optimization, task-decomposition]
dependencies: [context-awareness, task-decomposition, phase-execution]
files:
  templates: ./templates/*.json
user-invocable: false
---

# Adaptive Workflow

Автоматическое определение сложности задачи и выбор оптимального workflow.

## Когда использовать

- После context-awareness (Phase 0)
- Для каждой новой задачи

## Уровни сложности

| Level | Критерии | Workflow |
|-------|----------|----------|
| **minimal** | <3 файлов, 1 функция, нет breaking changes | Упрощённый |
| **standard** | 3-5 файлов, 1 компонент | Полный lite |
| **complex** | >5 файлов, несколько компонентов, breaking changes | Phase-based |

## Алгоритм определения

```
1. Подсчитать files_to_change
2. Определить количество компонентов
3. Проверить на breaking changes
4. Оценить estimated_complexity

complexity =
  if files < 3 AND components == 1 AND !breaking_changes:
    "minimal"
  elif files <= 5 AND components <= 2:
    "standard"
  else:
    "complex"
```

## Output

Используй шаблон: `@template:complexity-result`

## Skip Rules

```yaml
minimal:
  skip:
    - approval_gate
    - prd_compliance
    - code_review
    - changelog
  keep:
    - syntax_check
    - basic_validation

standard:
  skip: []
  optional:
    - code_review
    - prd_compliance (if has_prd)

complex:
  skip: []
  required:
    - all phases
    - code_review
    - prd_compliance (if has_prd)
```

## Quick Reference

```json
{
  "complexity_result": {
    "level": "minimal|standard|complex",
    "workflow": "lite|full|phase-based",
    "skip": ["approval_gate", "prd_compliance"],
    "required": ["syntax_check"],
    "reasoning": "why this level"
  }
}
```

---

## Task Decomposition Integration (Complex Tasks)

**Активируется когда:** `complexity_result.level == "complex"`

Когда задача классифицирована как complex, adaptive-workflow автоматически интегрируется с task-decomposition и phase-execution для систематической декомпозиции и пошагового выполнения.

### Workflow для Complex Tasks:

```
adaptive-workflow → complexity = "complex"
  ↓
task-decomposition → разбивает задачу на 2-5 фаз
  ↓
Создаёт:
  - master_plan.json (общий план всех фаз)
  - phase_1.json (детальный план фазы 1)
  - phase_2.json (детальный план фазы 2)
  - ...
  ↓
FOR EACH phase:
  phase-execution → выполняет одну фазу
    ↓
  Checkpoint после завершения фазы
    ↓
  Validation (tests, syntax, build)
    ↓
  IF validation fails:
    → rollback-recovery → откат к checkpoint
  ELSE:
    → Continue to next phase
```

### Алгоритм интеграции:

```python
IF complexity_result.level == "complex":
  1. Invoke task-decomposition skill
     Input: {
       "task_description": user_task,
       "estimated_files": files_count,
       "breaking_changes": has_breaking_changes
     }

  2. task-decomposition returns:
     {
       "master_plan": {...},
       "phases": [
         {"phase_id": 1, "description": "...", "files": [...], "dependencies": []},
         {"phase_id": 2, "description": "...", "files": [...], "dependencies": [1]},
         ...
       ],
       "total_phases": 3
     }

  3. FOR EACH phase in phases:
       a. Invoke phase-execution skill
          Input: {
            "phase_file": "phase_{phase_id}.json",
            "checkpoint_before": true
          }

       b. phase-execution executes:
          - Create checkpoint (rollback point)
          - Execute all actions in phase
          - Run validation (tests, syntax)
          - Update progress

       c. IF phase validation fails:
            → Invoke rollback-recovery
            → Restore checkpoint
            → Report error to user
            → STOP execution
          ELSE:
            → Mark phase as completed
            → Continue to next phase

  4. AFTER all phases completed:
       - Generate final summary
       - Aggregate metrics from all phases
       - Create consolidated commit (optional)
```

### Преимущества декомпозиции:

**1. Checkpoint между фазами:**
- Rollback point после каждой фазы
- Если phase 3 fails → rollback только фазы 3, фазы 1-2 сохранены

**2. Прогресс tracking:**
```
Phase 1/4: Backend API ..................... ✓ COMPLETED
Phase 2/4: Frontend integration ............ ⏳ IN PROGRESS
Phase 3/4: Testing & security .............. ⏸️  PENDING
Phase 4/4: Documentation ................... ⏸️  PENDING
```

**3. Параллельное выполнение независимых фаз:**
```json
{
  "phases": [
    {"phase_id": 1, "dependencies": []},        // No deps → can run first
    {"phase_id": 2, "dependencies": [1]},       // Depends on 1 → run after 1
    {"phase_id": 3, "dependencies": [1]},       // Depends on 1 → can run parallel with 2
    {"phase_id": 4, "dependencies": [2, 3]}     // Depends on 2,3 → run last
  ]
}

Execution order:
  Phase 1 → (Phase 2 || Phase 3) → Phase 4
            ↑ parallel execution ↑
```

**4. Лучшая организация:**
- Каждая фаза имеет чёткую цель
- Isolated changes (легче review)
- Incremental progress (видно продвижение)

### Пример декомпозиции:

**Task:** "Реализовать систему аутентификации с JWT"

**task-decomposition создаёт:**

```json
{
  "master_plan": {
    "task_name": "JWT Authentication System",
    "total_phases": 4,
    "estimated_duration": "4-6 hours"
  },
  "phases": [
    {
      "phase_id": 1,
      "description": "Backend API - JWT endpoints",
      "files": ["src/api/auth.py", "src/middleware/jwt.py"],
      "actions": ["Create login endpoint", "Implement JWT generation"],
      "validation": "pytest tests/test_auth.py",
      "dependencies": []
    },
    {
      "phase_id": 2,
      "description": "Frontend integration - Login form",
      "files": ["frontend/LoginForm.tsx", "frontend/api/auth.ts"],
      "actions": ["Create login form", "Add auth API client"],
      "validation": "npm test",
      "dependencies": [1]
    },
    {
      "phase_id": 3,
      "description": "Testing & security hardening",
      "files": ["tests/integration/test_auth_flow.py"],
      "actions": ["Add integration tests", "Security audit"],
      "validation": "pytest tests/integration/",
      "dependencies": [1, 2]
    },
    {
      "phase_id": 4,
      "description": "Documentation & deployment",
      "files": ["docs/authentication.md", "README.md"],
      "actions": ["Update API docs", "Add deployment guide"],
      "validation": "markdown-lint docs/",
      "dependencies": [3]
    }
  ]
}
```

**Execution flow:**
```
✓ Phase 1: Backend API (20 min) → Checkpoint created
✓ Phase 2: Frontend (25 min) → Checkpoint created
✓ Phase 3: Testing (30 min) → Checkpoint created
✓ Phase 4: Documentation (15 min) → Checkpoint created

Total: 90 minutes, 4 checkpoints, 0 rollbacks
```

### Escalation & Downgrade:

**Escalation (minimal/standard → complex):**
```
# Start: minimal workflow
Task: "Fix email validation"

# During execution: обнаружена complexity
❌ Found: 8 files need changes (was estimated 2)
❌ Found: Breaking API change

🔄 Escalating to COMPLEX workflow...
✓ Switching to task-decomposition
✓ Creating phases for systematic execution
```

**Downgrade (complex → standard):**
```
# Start: complex workflow (user requested)
Task: "Update README documentation"

# Analysis: simpler than expected
✓ Only 1 markdown file
✓ No code changes
✓ No dependencies

🔄 Downgrading to STANDARD workflow...
✓ Skipping task-decomposition (unnecessary overhead)
⏱️  Saving ~1 hour
```

### Backward Compatibility:

- task-decomposition и phase-execution опциональны
- Если skills не установлены → fallback to standard structured-planning
- Без декомпозиции complex tasks выполняются монолитно (как раньше)

---
