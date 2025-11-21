# Task Planning Template (Multi-Phase) v3.1

**Назначение:** Разбиение сложных задач на 2-5 логических фаз с автоматическим использованием Claude Code Skills.

**Для пользователя:** Просто опишите задачу ниже. Claude автоматически разобьет на фазы, создаст master plan и phase files, запросит подтверждение.

**Результат:** Master plan + phase-1.md, phase-2.md, ..., phase-N.md в `plans/`

---

## 📋 Входные данные

**Опишите задачу, которую нужно разбить на фазы:**

```
[Пользователь описывает задачу здесь. Примеры:]

Добавить систему аутентификации с JWT и refresh tokens
```

**ИЛИ**

```
Реализовать OrderService с async processing и retry mechanism
```

**Когда использовать этот шаблон:**
- Сложные задачи (>10 steps, >5 файлов)
- Несколько логических этапов с зависимостями
- Затрагивает multiple компоненты (database, API, frontend)
- Выполнение займет > 3 часов

**Когда НЕ использовать:**
- Простые задачи (<5 steps, один компонент) → используйте **task-lite-template-v3.1.md**
- Bug fixes (обычно single-phase) → используйте **task-lite-template-v3.1.md**

---

## 🔄 Workflow (выполняется автоматически)

Claude автоматически выполнит следующую последовательность:

### 1️⃣ АНАЛИЗ И ДЕКОМПОЗИЦИЯ

**Что Claude сделает:**
- Проанализирует задачу и определит оптимальное количество фаз (2-5)
- Определит зависимости между фазами
- Распределит acceptance criteria по фазам
- Создаст dependency graph
- Идентифицирует риски

**Пример вывода:**

```
═══════════════════════════════════════════════════════════
              АНАЛИЗ ЗАДАЧИ
═══════════════════════════════════════════════════════════

ЗАДАЧА: Add JWT Authentication System
СЛОЖНОСТЬ: Complex

ДЕКОМПОЗИЦИЯ:
- Количество фаз: 3
- Критерий разделения: Архитектурные слои (database → backend → frontend)
- Обоснование: Каждый слой можно реализовать и протестировать отдельно

ФАЗЫ:

Phase 1: Database Models + Migrations (5 steps)
  Цель: Создать User и RefreshToken models с migrations
  Зависимости: Нет
  Provides: User model, RefreshToken model

Phase 2: Backend API + JWT Logic (7 steps)
  Цель: Реализовать login, refresh, logout endpoints
  Зависимости: User model, RefreshToken model (Phase 1)
  Provides: Working auth endpoints

Phase 3: Frontend Integration (6 steps)
  Цель: Интегрировать auth API в frontend (auth interceptor, login form)
  Зависимости: Working auth endpoints (Phase 2)
  Provides: Full auth flow

ACCEPTANCE CRITERIA MAPPING:
- AC1: User registration → Phase 1 + Phase 2
- AC2: JWT authentication → Phase 2
- AC3: Refresh tokens → Phase 1 + Phase 2
- AC4: Frontend login → Phase 3

RISKS:
- RefreshToken schema может потребовать изменений в Phase 2
  Митигация: Тщательный review schema в Phase 1

═══════════════════════════════════════════════════════════
```

<details>
<summary>Технические детали (для разработчиков)</summary>

**[INTERNAL] Decomposition Thinking**

Используй **thinking-framework Шаблон 6: Decomposition Thinking**

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

**Error:** Используй error-handling Шаблон 14: DECOMPOSITION_FAILED → STOP

</details>

---

### 2️⃣ СОЗДАНИЕ СТРУКТУРИРОВАННОГО ПЛАНА (JSON)

**Что Claude сделает:**
- Создаст структурированный JSON с описанием всех фаз
- Валидирует JSON Schema (2-5 фаз, 3-7 steps на фазу)
- Определит execution order и dependency graph
- Проверит на отсутствие циклических зависимостей

**Пример вывода:**

```
═══════════════════════════════════════════════════════════
          TASK DECOMPOSITION JSON
═══════════════════════════════════════════════════════════

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
        "goal": "Интегрировать auth API в frontend",
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

JSON Schema Validation: ✓ PASSED
- Total phases: 3 (valid: 2-5)
- Each phase: 5-7 steps (recommended: 3-7)
- Phase slugs: lowercase-hyphenated ✓
- Dependencies: valid references ✓
- No dependency cycles ✓

═══════════════════════════════════════════════════════════
```

<details>
<summary>Технические детали (для разработчиков)</summary>

**[INTERNAL] JSON Generation**

Используй **task-decomposition Шаблон 2** + **structured-planning Шаблон 8-9**

**ОБЯЗАТЕЛЬНО вывести JSON с полями:**

```json
{
  "task_decomposition": {
    "task_name": "...",
    "task_slug": "...",
    "complexity": "simple/medium/complex",
    "total_phases": 2-5,
    "decomposition_rationale": "...",
    "phases": [
      {
        "phase_number": 1,
        "phase_name": "...",
        "phase_slug": "lowercase-hyphenated",
        "goal": "...",
        "estimated_steps": 3-7,
        "dependencies": [],
        "provides_for_next": ["..."],
        "acceptance_criteria_covered": ["..."]
      }
    ],
    "branch_strategy": {
      "base_branch": "master",
      "feature_branch": "feature/...",
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

**Error:** Используй error-handling Шаблон 2: JSON_SCHEMA_VALIDATION_ERROR → RETRY (max 1)

</details>

---

### 3️⃣ ГЕНЕРАЦИЯ MASTER PLAN

**Что Claude сделает:**
- Создаст файл `plans/master-plan-{task-slug}.md`
- Включит overview всех фаз
- Добавит dependency graph
- Сделает mapping acceptance criteria к фазам
- Добавит execution instructions
- Идентифицирует риски с митигациями

**Пример вывода:**

```
═══════════════════════════════════════════════════════════
           MASTER PLAN СОЗДАН
═══════════════════════════════════════════════════════════

Файл: plans/master-plan-add-jwt-auth.md

Содержит:
- Overview задачи и rationale декомпозиции
- 3 фазы с dependencies и provides
- Dependency graph (Phase 1 → 2 → 3, sequential)
- Acceptance criteria mapping (4 criteria)
- Execution instructions для каждой фазы
- Risks (2) и митигации

═══════════════════════════════════════════════════════════
```

<details>
<summary>Технические детали и пример Master Plan</summary>

**[INTERNAL] Master Plan Generation**

Используй **task-decomposition Шаблон 3** + **structured-planning Шаблон 10**

**Создать файл:** `plans/master-plan-{task_slug}.md`

**Содержимое (пример):**

```markdown
# Master Plan: Add JWT Authentication System

**Created:** 2025-11-21
**Status:** Planning Complete
**Branch:** feature/add-jwt-auth

---

## Overview

Добавление системы аутентификации с JWT tokens и refresh token механизмом. Задача разбита на 3 фазы для последовательной реализации по архитектурным слоям.

**Decomposition Rationale:**
Система аутентификации состоит из 3 независимых слоев: database schema, backend API, frontend integration. Каждый слой можно реализовать и протестировать отдельно.

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
- **Goal:** Интегрировать auth API в frontend (auth interceptor, login form)
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
**Parallel Phases:** None

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

**Error:** Используй error-handling Шаблон 15: FILE_CREATE_FAILED → STOP

</details>

---

### 4️⃣ ГЕНЕРАЦИЯ PHASE FILES

**Что Claude сделает:**
- Для каждой фазы создаст отдельный файл `plans/phase-{N}-{slug}.md`
- Каждый phase file содержит:
  - Phase metadata (JSON) с полными деталями
  - Детальные execution steps с actions
  - Completion criteria (минимум 1)
  - Commit message template (Conventional Commits)
  - Validation инструкции (syntax checks, tests)
  - Risks с митигациями

**Пример вывода:**

```
═══════════════════════════════════════════════════════════
          PHASE FILES СОЗДАНЫ
═══════════════════════════════════════════════════════════

✓ plans/phase-1-database-models.md (5 steps)
  - User model с полями (email, password_hash, created_at)
  - RefreshToken model с полями (token, user_id, expires_at)
  - Alembic migration
  - Completion criteria: 2

✓ plans/phase-2-backend-api.md (7 steps)
  - JWTService для генерации и валидации токенов
  - POST /auth/login, /auth/refresh, /auth/logout endpoints
  - JWT middleware для protected routes
  - Completion criteria: 3

✓ plans/phase-3-frontend-integration.md (6 steps)
  - Auth interceptor для axios
  - Login form component
  - Token storage в localStorage
  - Completion criteria: 2

Каждый phase file содержит:
- Phase metadata (JSON)
- Execution steps с actions и validation
- Completion criteria
- Commit message template
- Validation commands

═══════════════════════════════════════════════════════════
```

<details>
<summary>Технические детали и пример Phase File</summary>

**[INTERNAL] Phase File Generation**

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

**Phase File Content (пример):**

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
          "Реализовать validate_token() method",
          "Add SECRET_KEY to config"
        ],
        "validation": "python -m pytest tests/services/test_jwt_service.py"
      },
      {
        "step_number": 2,
        "description": "Реализовать POST /auth/login endpoint",
        "actions": [
          "Создать backend/app/api/v1/endpoints/auth.py",
          "Реализовать login endpoint",
          "Добавить password hashing validation",
          "Return access_token и refresh_token"
        ],
        "validation": "curl -X POST http://localhost:8000/api/v1/auth/login -d '{\"email\":\"test@test.com\",\"password\":\"test123\"}'"
      },
      {
        "step_number": 3,
        "description": "Реализовать POST /auth/refresh endpoint",
        "actions": [
          "Реализовать refresh endpoint",
          "Validate refresh_token",
          "Generate new access_token"
        ],
        "validation": "curl -X POST http://localhost:8000/api/v1/auth/refresh -H 'Authorization: Bearer {refresh_token}'"
      },
      {
        "step_number": 4,
        "description": "Реализовать POST /auth/logout endpoint",
        "actions": [
          "Реализовать logout endpoint",
          "Invalidate refresh_token (soft delete)"
        ],
        "validation": "curl -X POST http://localhost:8000/api/v1/auth/logout -H 'Authorization: Bearer {access_token}'"
      },
      {
        "step_number": 5,
        "description": "Добавить JWT middleware для protected routes",
        "actions": [
          "Создать middleware для валидации JWT",
          "Apply к protected routes"
        ],
        "validation": "curl -X GET http://localhost:8000/api/v1/protected -H 'Authorization: Bearer {access_token}'"
      }
    ],
    "completion_criteria": [
      "POST /auth/login возвращает access_token и refresh_token",
      "POST /auth/refresh генерирует новый access_token",
      "POST /auth/logout invalidates refresh_token",
      "Protected routes требуют валидный JWT"
    ],
    "commit_message": {
      "type": "feat",
      "summary": "add JWT authentication endpoints",
      "body": "- Implement JWTService for token generation/validation\n- Add login, refresh, logout endpoints\n- Add JWT middleware for protected routes\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\n\nCo-Authored-By: Claude <noreply@anthropic.com>"
    },
    "risks": [
      "JWT SECRET_KEY может быть hardcoded → Используй environment variables",
      "Password hashing может быть слабым → Используй bcrypt с salt"
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

**Error:** Используй error-handling Шаблон 15: FILE_CREATE_FAILED → STOP

</details>

---

### 5️⃣ APPROVAL GATE (ТРЕБУЕТСЯ ПОДТВЕРЖДЕНИЕ)

**Claude покажет полный план и запросит ваше подтверждение:**

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

**[INTERNAL] ОСТАНОВИТЬСЯ и ждать ответа пользователя!**

<details>
<summary>Технические детали (для разработчиков)</summary>

**[INTERNAL] Approval Gate**

Используй **approval-gates skill**

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

**Error:** Используй error-handling Шаблон 5: APPROVAL_REJECTED → STOP

</details>

---

### 6️⃣ ФИНАЛИЗАЦИЯ (ПОСЛЕ ПОДТВЕРЖДЕНИЯ)

**Что Claude сделает:**
- Создаст все plan files (master plan + phase files)
- Выведет итоговый summary с инструкциями
- **ОСТАНОВИТСЯ** - НЕ будет выполнять Phase 1 автоматически
- НЕ будет создавать git ветку
- НЕ будет изменять код

**Итоговый вывод:**

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

## ⚙️ Конфигурация (для Claude)

<details>
<summary>Внутренние настройки (автоматические)</summary>

- **Режим:** Планирование (decomposition only)
- **Skills:** task-decomposition, thinking-framework, structured-planning, approval-gates, error-handling
- **Thinking:** Enabled (обязательно для decomposition и phase planning)
- **Structured Output:** JSON validation для task_decomposition, phase_metadata
- **Validation:** JSON Schema для 2-5 фаз, 3-7 steps
- **Approval Gate:** Обязательно перед созданием files
- **Результат:** Master plan + N phase files (2-5 фаз)

</details>

---

## ⚠️ КРИТИЧНО: ОСТАНОВКА ПОСЛЕ ПЛАНИРОВАНИЯ

**После создания всех файлов - ОСТАНОВИТЬСЯ!**

Claude НЕ должен:
- ❌ Выполнять Phase 1 автоматически
- ❌ Создавать git ветку
- ❌ Изменять код
- ❌ Делать git commit

Только создание plan files → STOP

---

## 🚨 Error Handling (автоматический)

<details>
<summary>Обработка ошибок (Internal)</summary>

**[INTERNAL] Используй error-handling skill при любых ошибках**

Типовые ошибки:
- **DECOMPOSITION_FAILED** → STOP, показать ошибку пользователю
- **JSON_SCHEMA_VALIDATION_ERROR** → RETRY (max 1), затем STOP
- **FILE_CREATE_FAILED** → STOP
- **APPROVAL_REJECTED** → STOP

Формат error message:
```
🚨 ОШИБКА: {Type}

Проблема: [описание]
Контекст: [где произошло]
Действие: [STOP/RETRY]
```

</details>

---

## 📚 FAQ

**Q: Как определить что задача требует multi-phase планирования?**

A: Критерии:
- **Размер:** > 10 steps, затрагивает > 5 файлов
- **Логические этапы:** Можно разделить на independent parts
- **Время:** Выполнение займет > 3 часов
- **Компоненты:** Затрагивает multiple слои (database, API, frontend)

Если НЕ подходит → используй **task-lite-template-v3.1.md**

**Q: Почему ограничение 2-5 фаз?**

A:
- **< 2 фазы:** Используй task-lite (single-phase)
- **2-5 фаз:** Optimal balance между гранулярностью и overhead
- **> 5 фаз:** Слишком мелко, split на 2 отдельные задачи

**Q: Можно ли изменить plan после approval?**

A: ДА, но с ограничениями:
- **До выполнения:** Можно модифицировать phase files
- **Во время Phase N:** Можно изменить Phase N+1, N+2, ... (еще не started)
- **После commit Phase N:** НЕ ИЗМЕНЯТЬ (уже в git history)

**Q: Что если dependency cycle?**

A: Это ОШИБКА decomposition! Dependencies должны быть acyclic (направленный ациклический граф). Claude пересмотрит критерий разделения.

**Q: Branch per phase или одна feature branch?**

A: **Рекомендуется:** Одна feature branch для всех фаз. Atomic commits сохраняются (каждая фаза = commit), можно rollback через `git revert`.

**Q: Можно ли пропустить Master Plan?**

A: НЕТ! Master Plan **обязателен**:
- Дает overview всех фаз (big picture)
- Показывает dependency graph
- Maps acceptance criteria к фазам
- Служит reference во время execution

**Q: Phase Planning Thinking обязателен для КАЖДОЙ фазы?**

A: ДА! Без thinking можем создать несбалансированные фазы (Phase 1: 2 steps, Phase 2: 12 steps).

**Q: Acceptance criteria должны быть равномерно распределены?**

A: НЕТ! Распределяются по **логике**, не по количеству. Важно чтобы ВСЕ AC были покрыты хотя бы одной фазой.

---

## 📝 Для разработчиков шаблона

<details>
<summary>Технические детали (только для разработчиков Claude Code Skills)</summary>

### Используемые Skills

**Universal Skills:**
1. **task-decomposition** (`.claude/skills/task-decomposition/SKILL.md`) - Main orchestrator
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

### Execution Sequence (строгий порядок)

1. ✓ Decomposition Thinking (thinking-framework Шаблон 6) - ОБЯЗАТЕЛЬНО
2. ✓ Task Decomposition JSON (task-decomposition Шаблон 2 + structured-planning Шаблон 8-9)
3. ✓ JSON Schema Validation (structured-planning Шаблон 9)
4. ✓ Master Plan Generation (task-decomposition Шаблон 3 + structured-planning Шаблон 10)
5. ✓ Phase File Generation для КАЖДОЙ фазы:
   - Phase Planning Thinking (thinking-framework Шаблон 8) - ОБЯЗАТЕЛЬНО для каждой фазы
   - Phase File Creation (task-decomposition Шаблон 4 + structured-planning Шаблон 11)
6. ✓ Approval Gate (approval-gates skill) → BLOCKING, WAIT for user
7. ✓ Finalization (create files) → STOP

### Принципы v3.1

- **User-friendly:** Пользователь видит только задачу и примеры вывода
- **Skills-driven:** Все сложности скрыты в скилах
- **Automatic:** Claude сам выбирает нужные скилы автоматически
- **Transparent:** Workflow понятен через естественный язык + примеры
- **Modular:** Легко добавить новый skill без изменения template
- **Educational:** Пользователь понимает что происходит, не зная про skills

### Size Comparison

| Version | Lines | Token Usage | Notes |
|---------|-------|-------------|-------|
| v2.0 (monolithic) | ~1200 | ~55k | Inline instructions, high token usage |
| v3.0 (skills-based) | 730 | ~15k template + ~20k skills on-demand | Technical, requires skill knowledge |
| v3.1 (user-friendly) | ~850 | ~15k template + ~20k skills on-demand | User-friendly, skills automatic |

**Improvement:**
- 29% fewer lines vs v2.0 (850 vs 1200)
- 70% token savings (35k vs 55k total)
- User-friendly interface (vs technical v3.0)

</details>

---

## 📝 Version

**Template Version:** 3.1 (User-Friendly Skills-Based)
**Дата:** 2025-11-21
**Changelog:**
- v3.1: Переработан для user-friendly интерфейса
  - Добавлена секция "## 📋 Входные данные" для пользователя
  - Скрыты технические детали в `<details>` блоках
  - Workflow описан естественным языком с примерами вывода
  - Skills используются автоматически (под капотом)
  - Примеры JSON, вывода для каждого этапа
  - FAQ расширен для пользователей
- v3.0: Первая skills-based версия
  - Рефакторинг из 1200 строк в 730 строк
  - Вынесены инструкции в 5 специализированных скилов
  - Lazy loading скилов
  - JSON Schema validation

---

## 📖 Связанные Templates

- **[task-execution-template-v3.1.md](task-execution-template-v3.1.md)** - Для выполнения каждой фазы **← РЕКОМЕНДУЕТСЯ**
- **[task-lite-template-v3.1.md](task-lite-template-v3.1.md)** - Для простых задач (single-phase) **← РЕКОМЕНДУЕТСЯ**
- **[task-execution-template-v3.md](task-execution-template-v3.md)** - Legacy версия (требует знания skills)
- **[task-lite-template-v3.md](task-lite-template-v3.md)** - Legacy версия (требует знания skills)
