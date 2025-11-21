# Task Planning Template v3.0 (Skills-Based)

## Назначение

**ТОЛЬКО планирование** - разбиение задачи на 2-5 логических фаз с генерацией master plan и phase files.

**БЕЗ ВЫПОЛНЕНИЯ** - этот template создает план, но НЕ выполняет фазы, НЕ изменяет код.

**Результат:** Master plan + phase-1.md, phase-2.md, ..., phase-N.md в `plans/`

---

## Конфигурация

- **Режим:** Планирование (decomposition only)
- **Skills:** task-decomposition, thinking-framework, structured-planning, approval-gates, error-handling
- **Structured Output:** JSON validation для task_decomposition, phase_metadata
- **Результат:** Master plan + N phase files (2-5 фаз)

---

## Принципы

1. **Automated Decomposition** - task-decomposition skill автоматизирует разбиение
2. **2-5 Phases Optimal** - не слишком мелко, не слишком крупно
3. **Low Coupling** - фазы минимально зависят друг от друга
4. **Explicit Dependencies** - dependency graph между фазами
5. **Approval Gate** - запрос подтверждения плана перед созданием files
6. **NO EXECUTION** - этот template ОСТАНАВЛИВАЕТСЯ после создания планов

---

## Workflow Overview

Этот template использует **task-decomposition skill** (`.claude/skills/task-decomposition/SKILL.md`) для автоматизации планирования.

```
1. THINKING: Decomposition Thinking (ОБЯЗАТЕЛЬНО)
   └─ thinking-framework Шаблон 6

2. TASK DECOMPOSITION JSON
   ├─ Создать structured JSON с phases[]
   └─ structured-planning Шаблон 8-9

3. MASTER PLAN GENERATION
   ├─ Создать plans/master-plan-{task-slug}.md
   └─ structured-planning Шаблон 10

4. PHASE FILE GENERATION
   ├─ Для каждой фазы: plans/phase-N-slug.md
   ├─ Phase metadata JSON with full details
   └─ structured-planning Шаблон 11

5. APPROVAL GATE (BLOCKING)
   ├─ Показать plan пользователю
   ├─ Запросить подтверждение
   └─ approval-gates skill
```

**Skill Dependencies:**
- **task-decomposition** (main orchestrator)
- **thinking-framework** (Decomposition Thinking - Шаблон 6, Phase Planning - Шаблон 8)
- **structured-planning** (Task Decomposition JSON - Шаблон 8-9, Master Plan - Шаблон 10, Phase File - Шаблон 11)
- **approval-gates** (Получение подтверждения плана)
- **error-handling** (DECOMPOSITION_FAILED - Шаблон 14, FILE_CREATE_FAILED - Шаблон 15)

---

## Входные данные

**Формат запроса:**

```
Разбей задачу на фазы: Добавить систему аутентификации с JWT и refresh tokens
```

ИЛИ

```
Создай multi-phase plan для задачи: Реализовать OrderService с async processing
```

**Task Requirements:**
- Задача должна быть complex (>10 steps, >5 файлов)
- Должны быть логические фазы с dependencies
- Acceptance criteria должны быть идентифицированы

**Когда НЕ использовать:**
- Simple tasks (<5 steps, один компонент) → используй **task-lite-template-v3.md**
- Bug fixes (обычно single-phase) → используй **task-lite-template-v3.md**

---

## Процесс планирования

### THINKING: Decomposition Thinking (ОБЯЗАТЕЛЬНО)

**[CRITICAL] Используй thinking-framework Шаблон 6: Decomposition Thinking**

```xml
<thinking>
ЗАДАЧА: [описание задачи от пользователя]
СЛОЖНОСТЬ: [simple/medium/complex]

ДЕКОМПОЗИЦИЯ:
Почему многофазная: [обоснование разбиения на фазы]
Количество фаз: [2-5]
Критерий разделения: [по функциональности / компонентам / слоям]

ФАЗЫ:
Phase 1: [название] - [цель]
  Почему первой: [обоснование порядка]
  Зависимости: [от чего зависит]
  Estimated steps: [3-7]

Phase 2: [название] - [цель]
  Почему после Phase 1: [обоснование]
  Зависимости: [Phase 1 outputs]
  Estimated steps: [3-7]

[... остальные фазы]

ACCEPTANCE CRITERIA MAPPING:
AC1 → Phase [N]
AC2 → Phase [N]
[...]

RISKS:
- [Risk 1] → Митигация: [как избежать]
- [Risk 2] → Митигация: [как избежать]

ВАЛИДАЦИЯ:
- Каждая фаза логически завершена
- Фазы минимально связаны (low coupling)
- Acceptance criteria полностью покрыты
- Нет dependency cycles
</thinking>
```

**Exit Conditions:**
- ✓ Thinking завершен
- ✓ Количество фаз определено (2-5)
- ✓ Acceptance criteria mapped

**Violation Action:** Используй **error-handling Шаблон 14: DECOMPOSITION_FAILED** → STOP

---

### TASK DECOMPOSITION JSON

Используй **task-decomposition Шаблон 2** + **structured-planning Шаблон 8-9**

**ОБЯЗАТЕЛЬНО вывести JSON:**

```json
{
  "task_decomposition": {
    "task_name": "Add JWT Authentication System",
    "task_slug": "add-jwt-auth",
    "complexity": "complex",
    "total_phases": 3,
    "decomposition_rationale": "Система аутентификации состоит из 3 независимых слоев: database schema, backend API, frontend integration. Каждый слой можно реализовать и протестировать отдельно.",
    "phases": [
      {
        "phase_number": 1,
        "phase_name": "Database Models + Migrations",
        "phase_slug": "database-models",
        "goal": "Создать User и RefreshToken database models с migrations",
        "estimated_steps": 5,
        "dependencies": [],
        "provides_for_next": ["User model", "RefreshToken model"],
        "acceptance_criteria_covered": ["AC1: User registration (partial)"]
      },
      {
        "phase_number": 2,
        "phase_name": "Backend API + JWT Logic",
        "phase_slug": "backend-api",
        "goal": "Реализовать login, refresh, logout endpoints с JWT authentication",
        "estimated_steps": 7,
        "dependencies": ["User model", "RefreshToken model"],
        "provides_for_next": ["Working auth endpoints"],
        "acceptance_criteria_covered": [
          "AC1: User registration (complete)",
          "AC2: JWT authentication",
          "AC3: Refresh tokens"
        ]
      },
      {
        "phase_number": 3,
        "phase_name": "Frontend Integration",
        "phase_slug": "frontend-integration",
        "goal": "Интегрировать auth API в frontend (auth interceptor, login form)",
        "estimated_steps": 6,
        "dependencies": ["Working auth endpoints"],
        "provides_for_next": [],
        "acceptance_criteria_covered": ["AC4: Frontend login"]
      }
    ],
    "branch_strategy": {
      "base_branch": "master",
      "feature_branch": "feature/add-jwt-auth",
      "branch_per_phase": false
    },
    "execution_order": [1, 2, 3],
    "parallel_phases": []
  }
}
```

**JSON Schema Validation:**
- ✓ total_phases = 2-5 (enforced)
- ✓ Each phase has 3-7 estimated_steps (recommended)
- ✓ phase_slug: lowercase-hyphenated
- ✓ dependencies referenced phases exist
- ✓ No dependency cycles

**Exit Conditions:**
- ✓ JSON Schema validation PASSED
- ✓ 2-5 phases определены

**Violation Action:** Используй **error-handling Шаблон 2: JSON_SCHEMA_VALIDATION_ERROR** → RETRY (max 1)

---

### MASTER PLAN GENERATION

Используй **task-decomposition Шаблон 3** + **structured-planning Шаблон 10**

**Создать файл:** `plans/master-plan-{task_slug}.md`

**Содержимое (сокращенный пример):**

```markdown
# Master Plan: Add JWT Authentication System

**Created:** 2025-11-20
**Status:** Planning Complete
**Branch:** feature/add-jwt-auth

---

## Overview

Добавление системы аутентификации с JWT tokens и refresh token механизмом. Задача разбита на 3 фазы для последовательной реализации по архитектурным слоям.

---

## Phases Overview

### Phase 1: Database Models + Migrations
- **Goal:** Создать User и RefreshToken database models с migrations
- **Dependencies:** Нет
- **Provides:** User model, RefreshToken model
- **File:** `plans/phase-1-database-models.md`
- **Estimated Steps:** 5

### Phase 2: Backend API + JWT Logic
- **Goal:** Реализовать login, refresh, logout endpoints с JWT authentication
- **Dependencies:** User model, RefreshToken model (Phase 1)
- **Provides:** Working auth endpoints
- **File:** `plans/phase-2-backend-api.md`
- **Estimated Steps:** 7

### Phase 3: Frontend Integration
- **Goal:** Интегрировать auth API в frontend
- **Dependencies:** Working auth endpoints (Phase 2)
- **File:** `plans/phase-3-frontend-integration.md`
- **Estimated Steps:** 6

---

## Dependency Graph

```
Phase 1 (Database)
    ↓
    └─→ Phase 2 (Backend API)
            ↓
            └─→ Phase 3 (Frontend)
```

**Execution Order:** 1 → 2 → 3 (sequential)

---

## Acceptance Criteria Mapping

| Criterion | Phase | Status |
|-----------|-------|--------|
| AC1: User registration | Phase 1 + Phase 2 | Pending |
| AC2: JWT authentication | Phase 2 | Pending |
| AC3: Refresh tokens | Phase 1 + Phase 2 | Pending |
| AC4: Frontend login | Phase 3 | Pending |

---

## Execution Instructions

```bash
# Phase 1
"Выполни Phase 1 из plans/phase-1-database-models.md"

# После завершения Phase 1:
"Выполни Phase 2 из plans/phase-2-backend-api.md"

# После завершения Phase 2:
"Выполни Phase 3 из plans/phase-3-frontend-integration.md"
```

---

## Risks

1. RefreshToken schema может потребовать изменений в Phase 2
   - **Митигация:** Тщательный review schema в Phase 1

2. JWT logic может требовать дополнительные поля в User model
   - **Митигация:** Добавить nullable fields в Phase 1
```

**Exit Conditions:**
- ✓ Master plan file создан в `plans/master-plan-{task_slug}.md`
- ✓ Все секции заполнены

**Violation Action:** Используй **error-handling Шаблон 15: FILE_CREATE_FAILED** → STOP

---

### PHASE FILE GENERATION

Используй **task-decomposition Шаблон 4** + **structured-planning Шаблон 11**

**Для каждой фазы:** Создать `plans/phase-{N}-{phase_slug}.md`

**Thinking (ОБЯЗАТЕЛЬНО) для каждого phase file:**

Используй **thinking-framework Шаблон 8: Phase Planning Thinking**

```xml
<thinking>
PHASE NUMBER: 2/3
PHASE NAME: Backend API + JWT Logic

SCOPE:
[Что входит в эту фазу]

STEPS BREAKDOWN (3-7 steps):
Step 1: [description] - [actions]
Step 2: [description] - [actions]
[...]

COMPLETION CRITERIA (минимум 1):
- [Criterion 1]
- [Criterion 2]

COMMIT MESSAGE:
Type: [feat/fix/refactor]
Summary: [краткое описание]
Body: [детали изменений]

RISKS (минимум 1):
- [Risk 1]
- [Risk 2]

VALIDATION:
Syntax check required: [yes/no]
Files to check: [list]
</thinking>
```

**Phase File Content (сокращенный пример):**

```markdown
# Phase 2: Backend API + JWT Logic

**Phase:** 2/3
**Goal:** Реализовать login, refresh, logout endpoints с JWT authentication
**Branch:** feature/add-jwt-auth
**Dependencies:** User model, RefreshToken model (Phase 1)

---

## Phase Metadata (JSON)

```json
{
  "phase_metadata": {
    "phase_number": 2,
    "phase_name": "Backend API + JWT Logic",
    "total_phases": 3,
    "goal": "Реализовать login, refresh, logout endpoints с JWT authentication",
    "context": {
      "branch_name": "feature/add-jwt-auth",
      "base_branch": "master",
      "previous_changes_summary": "Phase 1 создал User и RefreshToken models с migrations",
      "dependencies": ["User model", "RefreshToken model"]
    },
    "steps": [
      {
        "step_number": 1,
        "description": "Создать JWTService для генерации и валидации токенов",
        "actions": [
          "Создать backend/app/services/jwt_service.py",
          "Реализовать generate_token() method",
          "Реализовать validate_token() method"
        ],
        "validation": "python -m pytest tests/services/test_jwt_service.py"
      },
      {
        "step_number": 2,
        "description": "Реализовать POST /auth/login endpoint",
        "actions": [
          "Создать backend/app/api/v1/endpoints/auth.py",
          "Реализовать login endpoint",
          "Добавить password hashing validation"
        ],
        "validation": "curl -X POST http://localhost:8000/api/v1/auth/login -d '{\"email\":\"test@test.com\",\"password\":\"test123\"}'"
      }
    ],
    "completion_criteria": [
      "POST /auth/login возвращает access_token и refresh_token",
      "POST /auth/refresh генерирует новый access_token",
      "POST /auth/logout invalidates refresh_token"
    ],
    "commit_message": {
      "type": "feat",
      "summary": "add JWT authentication endpoints",
      "body": "- Implement JWTService\n- Add login, refresh, logout endpoints\n- Add JWT middleware"
    },
    "risks": [
      "JWT SECRET_KEY может быть hardcoded",
      "Password hashing может быть слабым"
    ],
    "validation": {
      "syntax_check_required": true,
      "files_to_check": [
        "backend/app/services/jwt_service.py",
        "backend/app/api/v1/endpoints/auth.py"
      ]
    }
  }
}
```

---

## Execution

Для выполнения этой фазы:
```
"Выполни Phase 2 из plans/phase-2-backend-api.md"
```

---

## Next Phase

После завершения Phase 2:
→ Phase 3: Frontend Integration
  File: plans/phase-3-frontend-integration.md
```

**Slug Generation Rules:**
- Lowercase only
- Spaces → hyphens (-)
- Remove special characters
- Max 50 characters

**Exit Conditions:**
- ✓ Phase file создан для каждой фазы
- ✓ phase_metadata JSON валиден (3-7 steps)
- ✓ Все обязательные секции присутствуют

**Violation Action:** Используй **error-handling Шаблон 15: FILE_CREATE_FAILED** → STOP

---

### APPROVAL GATE (BLOCKING)

**[MANDATORY] Используй approval-gates skill**

**Approval Gate Message:**

```
═══════════════════════════════════════════════════════════
           📋 PLAN APPROVAL REQUIRED
═══════════════════════════════════════════════════════════

TASK: Add JWT Authentication System
COMPLEXITY: Complex

DECOMPOSITION:
- Total Phases: 3
- Total Steps: ~18 (5 + 7 + 6)
- Branch: feature/add-jwt-auth

PHASES:
1. Database Models + Migrations (5 steps)
   Dependencies: None
   Provides: User model, RefreshToken model

2. Backend API + JWT Logic (7 steps)
   Dependencies: Phase 1 (database models)
   Provides: Working auth endpoints

3. Frontend Integration (6 steps)
   Dependencies: Phase 2 (backend API)
   Provides: Full auth flow

ACCEPTANCE CRITERIA COVERAGE:
- AC1: User registration → Phase 1 + Phase 2 ✓
- AC2: JWT authentication → Phase 2 ✓
- AC3: Refresh tokens → Phase 1 + Phase 2 ✓
- AC4: Frontend login → Phase 3 ✓

FILES TO CREATE:
- plans/master-plan-add-jwt-auth.md
- plans/phase-1-database-models.md
- plans/phase-2-backend-api.md
- plans/phase-3-frontend-integration.md

═══════════════════════════════════════════════════════════

❓ Approve plan?
   [yes] - Create plan files and proceed
   [no] - Cancel decomposition
   [modify] - Request changes to plan

═══════════════════════════════════════════════════════════
```

**Approval JSON:**

```json
{
  "approval": {
    "approved": true,
    "requested_modifications": [],
    "can_proceed_to_file_generation": true
  }
}
```

**Exit Conditions:**
- ✓ approval.approved = true
- ✓ can_proceed_to_file_generation = true

**Violation Action:** Используй **error-handling Шаблон 5: APPROVAL_REJECTED** → STOP

---

## ⚠️ КРИТИЧНО: ОСТАНОВКА ПОСЛЕ ПЛАНИРОВАНИЯ

**После создания всех файлов - ОСТАНОВИТЬСЯ!**

НЕ выполнять Phase 1 автоматически!
НЕ создавать git ветку!
НЕ изменять код!

**Final Output:**

```
═══════════════════════════════════════════════════════════
        ✅ ПЛАНИРОВАНИЕ ЗАВЕРШЕНО
═══════════════════════════════════════════════════════════

СОЗДАНЫ ФАЙЛЫ:
- plans/master-plan-add-jwt-auth.md
- plans/phase-1-database-models.md
- plans/phase-2-backend-api.md
- plans/phase-3-frontend-integration.md

СЛЕДУЮЩИЕ ШАГИ:

1. Review планы (проверьте master plan и phase files)

2. Начать выполнение Phase 1:
   "Выполни Phase 1 из plans/phase-1-database-models.md"

3. После завершения Phase 1:
   "Выполни Phase 2 из plans/phase-2-backend-api.md"

4. После завершения Phase 2:
   "Выполни Phase 3 из plans/phase-3-frontend-integration.md"

ВАЖНО: Каждая фаза = отдельный commit. Можно rollback любую фазу.

═══════════════════════════════════════════════════════════
```

---

## Skills Reference

### Required Skills

1. **task-decomposition** (`.claude/skills/task-decomposition/SKILL.md`)
   - Шаблон 1: Decomposition Thinking (ОБЯЗАТЕЛЬНО)
   - Шаблон 2: Task Decomposition JSON
   - Шаблон 3: Master Plan Generation
   - Шаблон 4: Phase File Generation
   - Шаблон 5: Approval Gate (BLOCKING)

2. **thinking-framework** (`.claude/skills/thinking-framework/SKILL.md`)
   - Шаблон 6: Decomposition Thinking
   - Шаблон 8: Phase Planning Thinking

3. **structured-planning** (`.claude/skills/structured-planning/SKILL.md`)
   - Шаблон 8: Task Decomposition JSON
   - Шаблон 9: JSON Schema Validation
   - Шаблон 10: Master Plan Generation
   - Шаблон 11: Phase File Generation

4. **approval-gates** (`.claude/skills/approval-gates/SKILL.md`)
   - Получение подтверждения плана перед созданием files

5. **error-handling** (`.claude/skills/error-handling/SKILL.md`)
   - Шаблон 2: JSON_SCHEMA_VALIDATION_ERROR
   - Шаблон 5: APPROVAL_REJECTED
   - Шаблон 14: DECOMPOSITION_FAILED
   - Шаблон 15: FILE_CREATE_FAILED

---

## FAQ

**Q: Как определить что задача требует decomposition?**

A: Критерии:
- **Размер:** > 10 steps, затрагивает > 5 файлов
- **Логические этапы:** Можно разделить на independent parts
- **Время:** Выполнение займет > 3 часов
- **Компоненты:** Затрагивает multiple слоев (database, API, frontend)

Если НЕ подходит → используй **task-lite-template-v3.md**

**Q: Почему ограничение 2-5 фаз?**

A:
- **< 2 фазы:** Используй task-lite (single-phase)
- **2-5 фаз:** Optimal balance
- **> 5 фаз:** Слишком мелко, split на 2 отдельные задачи

**Q: Можно ли изменить plan после approval?**

A: ДА, но с ограничениями:
- **До выполнения:** Можно модифицировать phase files
- **Во время Phase N:** Можно изменить Phase N+1, N+2, ... (еще не started)
- **После commit Phase N:** НЕ ИЗМЕНЯТЬ (уже в git history)

**Q: Phase Planning Thinking обязателен для КАЖДОЙ фазы?**

A: ДА! Без thinking можем создать несбалансированные фазы (Phase 1: 2 steps, Phase 2: 12 steps).

**Q: Acceptance criteria должны быть равномерно распределены?**

A: НЕТ! Распределяются по **логике**, не по количеству. Важно чтобы ВСЕ AC были покрыты.

**Q: Что если dependency cycle?**

A: Это ОШИБКА decomposition! Dependencies должны быть acyclic. Пересмотреть критерий разделения.

**Q: Branch per phase или одна feature branch?**

A: **Рекомендуется:** Одна feature branch для всех фаз. Atomic commits сохраняются (каждая фаза = commit), можно rollback через git revert.

**Q: Можно ли пропустить Master Plan?**

A: НЕТ! Master Plan **обязателен**:
- Дает overview всех фаз (big picture)
- Показывает dependency graph
- Maps acceptance criteria к фазам
- Служит reference во время execution

---

## Проверочный чеклист

После завершения task planning:

**Thinking:**
- [ ] Decomposition Thinking завершен
- [ ] Количество фаз обосновано (2-5)
- [ ] Acceptance criteria mapped к фазам
- [ ] Риски идентифицированы

**Task Decomposition JSON:**
- [ ] JSON Schema validation PASSED
- [ ] total_phases = 2-5
- [ ] phases[] содержит {total_phases} элементов
- [ ] Каждая фаза имеет 3-7 estimated_steps
- [ ] phase_slug: lowercase-hyphenated
- [ ] dependencies правильно указаны
- [ ] Нет dependency cycles

**Master Plan:**
- [ ] Master plan file создан
- [ ] Все секции заполнены
- [ ] Dependency graph правильный
- [ ] Execution instructions понятны

**Phase Files:**
- [ ] Phase file создан для КАЖДОЙ фазы
- [ ] phase_metadata JSON валиден (3-7 steps)
- [ ] completion_criteria не пусто
- [ ] commit_message type правильный
- [ ] risks идентифицированы

**Approval:**
- [ ] Approval gate показан пользователю
- [ ] approval.approved = true
- [ ] can_proceed_to_file_generation = true

**Files Created:**
- [ ] plans/master-plan-{task_slug}.md
- [ ] plans/phase-1-{slug}.md
- [ ] plans/phase-2-{slug}.md
- [ ] ... (для каждой фазы)

**Stopping:**
- [ ] НЕ выполняется Phase 1 автоматически
- [ ] НЕ создается git ветка
- [ ] НЕ изменяется код

---

## Связанные Templates

- **task-execution-template-v3.md** - для выполнения каждой фазы
- **task-lite-template-v3.md** - для простых задач (single-phase)
