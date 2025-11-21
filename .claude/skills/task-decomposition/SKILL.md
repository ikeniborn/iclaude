---
name: Task Decomposition
description: Автоматизация разбиения задачи на 2-5 логических фаз с генерацией master plan и individual phase files
version: 1.0.0
author: Claude Code Team
tags: [phase-based, decomposition, planning, master-plan, workflow]
dependencies: [thinking-framework, structured-planning, approval-gates, error-handling]
---

# Task Decomposition

Автоматизация разбиения complex задачи на 2-5 логических фаз. Этот скил создает master plan, генерирует individual phase files (phase-N-slug.md), maps acceptance criteria к фазам, и подготавливает task для sequential phase execution.

## Когда использовать этот скил

Используй этот скил когда:
- Задача слишком большая для одного commit (>10 steps, затрагивает >5 файлов)
- Задача имеет логические этапы с dependencies (database → backend → frontend)
- Acceptance criteria можно разделить по фазам
- Нужна возможность rollback отдельных частей задачи

НЕ используй этот скил для:
- Simple tasks (< 5 steps, один компонент, < 2 часов работы) → используй task-lite-template
- Tasks без явных фаз (монолитные изменения)
- Bug fixes (обычно single-phase)

Скил автоматически вызывается при запросах типа:
- "Разбей задачу на фазы"
- "Создай multi-phase plan для добавления X"
- "Подготовь phase-based execution для задачи Y"

## Контекст проекта

### Философия Task Decomposition

**Принципы:**
- **2-5 phases optimal:** Не слишком мелко (< 2), не слишком крупно (> 5)
- **Low coupling:** Фазы минимально зависят друг от друга
- **High cohesion:** Внутри фазы - логически связанные изменения
- **Atomic commits:** Каждая фаза = отдельный commit, можно rollback
- **Explicit dependencies:** Dependency graph между фазами
- **3-7 steps per phase:** Оптимальная детализация

### Workflow Overview

```
1. THINKING: Decomposition Thinking (Шаблон 6)
   ├─ Анализировать сложность задачи
   ├─ Определить критерий разделения
   ├─ Обосновать количество фаз
   └─ Map acceptance criteria к фазам

2. TASK DECOMPOSITION JSON
   ├─ Создать structured JSON с phases[]
   ├─ Валидировать через JSON Schema
   └─ 2-5 phases, каждая с 3-7 steps

3. MASTER PLAN GENERATION
   ├─ Создать plans/master-plan-{task-name}.md
   ├─ Overview всех фаз
   ├─ Dependency graph
   └─ Execution order

4. PHASE FILE GENERATION
   ├─ Для каждой фазы создать phase-N-slug.md
   ├─ Phase metadata JSON with full details
   ├─ Steps breakdown
   └─ Completion criteria

5. APPROVAL GATE
   ├─ Показать plan пользователю
   ├─ Запросить подтверждение
   └─ [BLOCKING] Ждать ответа
```

### Dependencies

**Required skills:**
- **thinking-framework**: Decomposition Thinking (Шаблон 6), Phase Planning Thinking (Шаблон 8)
- **structured-planning**: Task Decomposition JSON (Шаблон 8-9), Phase Metadata JSON (Шаблон 6-7)
- **approval-gates**: Получение подтверждения плана перед созданием phase files
- **error-handling**: DECOMPOSITION_FAILED (Шаблон 14), FILE_CREATE_FAILED (Шаблон 15)

## Шаблоны

### Шаблон 1: Decomposition Thinking (ОБЯЗАТЕЛЬНО)

**[CRITICAL] Thinking перед decomposition - обязателен!**

Используй thinking-framework skill (Шаблон 6: Decomposition Thinking).

**Thinking блок:**
```xml
<thinking>
ЗАДАЧА: Добавить систему аутентификации с JWT и refresh tokens
СЛОЖНОСТЬ: Complex (затрагивает database, API, middleware, frontend)

ДЕКОМПОЗИЦИЯ:
Почему многофазная: Система аутентификации состоит из 3 независимых компонентов
(database models, backend API, frontend integration). Каждый можно реализовать
и протестировать отдельно.

Количество фаз: 3
Критерий разделения: По архитектурным слоям (database → backend → frontend)

ФАЗЫ:
Phase 1: Database Models + Migrations - создать User, RefreshToken tables
  Почему первой: Backend API требует database schema
  Зависимости: Нет (первая фаза)

Phase 2: Backend API + JWT Logic - реализовать login, refresh, logout endpoints
  Почему после Phase 1: Требует User и RefreshToken models
  Зависимости: Phase 1 (database schema)

Phase 3: Frontend Integration - добавить auth interceptor, login form
  Почему после Phase 2: Требует работающие API endpoints
  Зависимости: Phase 2 (backend API)

ACCEPTANCE CRITERIA MAPPING:
AC1 (User registration) → Phase 1 (User model) + Phase 2 (register endpoint)
AC2 (JWT authentication) → Phase 2 (JWT logic)
AC3 (Refresh tokens) → Phase 1 (RefreshToken model) + Phase 2 (refresh endpoint)
AC4 (Frontend login) → Phase 3 (frontend integration)

РИСКИ:
- Можем неправильно спроектировать RefreshToken schema в Phase 1
  (придется менять в Phase 2) → Митигация: тщательный review schema
- JWT logic может требовать дополнительные поля в User model
  (breaking change в Phase 2) → Митигация: добавить nullable fields в Phase 1

ВАЛИДАЦИЯ:
- Phase 1: migrations apply успешно, tables созданы
- Phase 2: API tests проходят, JWT tokens валидны
- Phase 3: Frontend успешно login/logout
- Каждая фаза имеет отдельный commit
</thinking>
```

**Exit Conditions:**
- ✓ Thinking завершен
- ✓ Количество фаз определено (2-5)
- ✓ Acceptance criteria mapped к фазам

**Violation Action:**
- Нет явных фаз → DECOMPOSITION_FAILED (error-handling Шаблон 14) → STOP, используй task-lite-template
- Слишком много фаз (> 5) → Пересмотреть decomposition strategy
- Слишком мало фаз (< 2) → Используй task-lite-template

---

### Шаблон 2: Task Decomposition JSON

Используй structured-planning skill (Шаблон 8: Task Decomposition JSON, Шаблон 9: JSON Schema).

**Task Decomposition JSON:**
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
- ✓ phases[] length = total_phases
- ✓ phase_number sequential (1, 2, 3, ...)
- ✓ phase_slug: lowercase-hyphenated (no spaces, no underscores)
- ✓ dependencies referenced phases exist
- ✓ acceptance_criteria_covered не пусто для хотя бы одной фазы

**Exit Conditions:**
- ✓ JSON Schema validation PASSED
- ✓ task_decomposition JSON создан
- ✓ 2-5 phases определены

**Violation Action:**
Используй error-handling skill:
- Schema validation failed → JSON_SCHEMA_VALIDATION_ERROR (Шаблон 2) → RETRY (max 1)
- total_phases < 2 или > 5 → DECOMPOSITION_FAILED (Шаблон 14) → STOP

---

### Шаблон 3: Master Plan Generation

Используй structured-planning skill (Шаблон 10: Master Plan Generation).

**Master Plan File:** `plans/master-plan-{task_slug}.md`

**Содержимое:**
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
- **Acceptance Criteria:** AC1 (partial)
- **File:** `plans/phase-1-database-models.md`
- **Estimated Steps:** 5

### Phase 2: Backend API + JWT Logic
- **Goal:** Реализовать login, refresh, logout endpoints с JWT authentication
- **Dependencies:** User model, RefreshToken model (Phase 1)
- **Provides:** Working auth endpoints
- **Acceptance Criteria:** AC1 (complete), AC2, AC3
- **File:** `plans/phase-2-backend-api.md`
- **Estimated Steps:** 7

### Phase 3: Frontend Integration
- **Goal:** Интегрировать auth API в frontend (auth interceptor, login form)
- **Dependencies:** Working auth endpoints (Phase 2)
- **Provides:** Full auth flow working
- **Acceptance Criteria:** AC4
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

**Execution Order:** Строго последовательно (1 → 2 → 3)

---

## Acceptance Criteria Mapping

| Criterion | Phase | Status |
|-----------|-------|--------|
| AC1: User registration | Phase 1 (partial) + Phase 2 (complete) | Pending |
| AC2: JWT authentication | Phase 2 | Pending |
| AC3: Refresh tokens | Phase 1 + Phase 2 | Pending |
| AC4: Frontend login | Phase 3 | Pending |

---

## Branch Strategy

- **Base Branch:** master
- **Feature Branch:** feature/add-jwt-auth
- **Branch per Phase:** No (все фазы в одной feature branch)

---

## Execution Instructions

Для выполнения всех фаз последовательно:

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

---

## Next Steps

1. Review master plan
2. Approve план
3. Execute Phase 1
```

**Exit Conditions:**
- ✓ Master plan file создан в `plans/master-plan-{task_slug}.md`
- ✓ Все секции заполнены (Overview, Phases, Dependencies, AC Mapping, Execution)

**Violation Action:**
Используй error-handling skill:
- File creation failed → FILE_CREATE_FAILED (Шаблон 15) → STOP

---

### Шаблон 4: Phase File Generation

Используй structured-planning skill (Шаблон 11: Phase File Generation).

**Для каждой фазы:** Создать `plans/phase-{N}-{phase_slug}.md`

**Thinking (ОБЯЗАТЕЛЬНО):**
Используй thinking-framework skill (Шаблон 8: Phase Planning Thinking) перед генерацией каждого phase file.

**Phase File Содержимое:**
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
          "Реализовать generate_token() method (принимает user_id, возвращает JWT)",
          "Реализовать validate_token() method (принимает JWT, возвращает user_id или None)"
        ],
        "validation": "python -m pytest tests/services/test_jwt_service.py"
      },
      {
        "step_number": 2,
        "description": "Реализовать POST /auth/login endpoint",
        "actions": [
          "Создать backend/app/api/v1/endpoints/auth.py",
          "Реализовать login endpoint (принимает email/password, возвращает access_token и refresh_token)",
          "Добавить password hashing validation"
        ],
        "validation": "curl -X POST http://localhost:8000/api/v1/auth/login -d '{\"email\":\"test@test.com\",\"password\":\"test123\"}'"
      },
      {
        "step_number": 3,
        "description": "Реализовать POST /auth/refresh endpoint",
        "actions": [
          "Реализовать refresh endpoint в auth.py",
          "Принимает refresh_token, возвращает новый access_token",
          "Валидировать refresh_token через RefreshToken model"
        ],
        "validation": "curl -X POST http://localhost:8000/api/v1/auth/refresh -d '{\"refresh_token\":\"...\"}'"
      },
      {
        "step_number": 4,
        "description": "Реализовать POST /auth/logout endpoint",
        "actions": [
          "Реализовать logout endpoint в auth.py",
          "Invalidate refresh_token (удалить из database)",
          "Возвращает success message"
        ],
        "validation": "curl -X POST http://localhost:8000/api/v1/auth/logout -d '{\"refresh_token\":\"...\"}'"
      },
      {
        "step_number": 5,
        "description": "Добавить JWT middleware для protected endpoints",
        "actions": [
          "Создать backend/app/core/middleware/jwt_middleware.py",
          "Реализовать JWT validation middleware",
          "Применить middleware к protected routes"
        ],
        "validation": "curl -H 'Authorization: Bearer <invalid_token>' http://localhost:8000/api/v1/protected (should return 401)"
      }
    ],
    "completion_criteria": [
      "POST /auth/login возвращает access_token и refresh_token при valid credentials",
      "POST /auth/refresh генерирует новый access_token при valid refresh_token",
      "POST /auth/logout invalidates refresh_token (удаляет из database)",
      "JWT middleware защищает protected endpoints (401 без valid token)"
    ],
    "commit_message": {
      "type": "feat",
      "summary": "add JWT authentication endpoints",
      "body": "- Implement JWTService for token generation/validation\n- Add login, refresh, logout endpoints\n- Add JWT middleware for protected routes\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\n\nCo-Authored-By: Claude <noreply@anthropic.com>"
    },
    "risks": [
      "JWT SECRET_KEY может быть hardcoded (security vulnerability)",
      "Password hashing может быть слабым (bcrypt rounds < 12)",
      "Refresh token replay attacks если не проверяем expiration"
    ],
    "validation": {
      "syntax_check_required": true,
      "files_to_check": [
        "backend/app/services/jwt_service.py",
        "backend/app/api/v1/endpoints/auth.py",
        "backend/app/core/middleware/jwt_middleware.py"
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
- Remove special characters (except hyphens)
- Max 50 characters
- Examples:
  - "Database Models + Migrations" → "database-models"
  - "Backend API & JWT Logic" → "backend-api-jwt-logic"
  - "Frontend Integration (UI)" → "frontend-integration-ui"

**Exit Conditions:**
- ✓ Phase file создан для каждой фазы
- ✓ phase_metadata JSON валиден (3-7 steps)
- ✓ Все обязательные секции присутствуют

**Violation Action:**
Используй error-handling skill:
- File creation failed → FILE_CREATE_FAILED (Шаблон 15) → STOP
- steps[] < 3 или > 7 → Пересмотреть phase breakdown

---

### Шаблон 5: Approval Gate (BLOCKING)

**[MANDATORY] Запрос подтверждения плана перед созданием phase files.**

Используй approval-gates skill.

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

**Violation Action:**
Используй error-handling skill:
- approved = false → APPROVAL_REJECTED (Шаблон 5) → STOP
- Requested modifications → Вернуться к Decomposition Thinking, исправить, RETRY

---

## Проверочный чеклист

После завершения task decomposition проверь:

**Thinking:**
- [ ] Decomposition Thinking завершен (Шаблон 6)
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

**Master Plan:**
- [ ] Master plan file создан (plans/master-plan-{task_slug}.md)
- [ ] Все секции заполнены (Overview, Phases, Dependencies, AC Mapping)
- [ ] Dependency graph правильный
- [ ] Execution instructions понятны

**Phase Files:**
- [ ] Phase file создан для КАЖДОЙ фазы
- [ ] phase_metadata JSON валиден (3-7 steps)
- [ ] completion_criteria не пусто (минимум 1)
- [ ] commit_message type правильный (feat/fix/refactor)
- [ ] risks идентифицированы (минимум 1)

**Approval:**
- [ ] Approval gate показан пользователю
- [ ] approval.approved = true
- [ ] can_proceed_to_file_generation = true

**Files Created:**
- [ ] plans/master-plan-{task_slug}.md
- [ ] plans/phase-1-{slug}.md
- [ ] plans/phase-2-{slug}.md
- [ ] ... (для каждой фазы)

## Связанные скилы

- **thinking-framework**: Decomposition Thinking (Шаблон 6), Phase Planning Thinking (Шаблон 8)
- **structured-planning**: Task Decomposition JSON (Шаблон 8-9), Phase Metadata JSON (Шаблон 6-7), Master Plan (Шаблон 10), Phase File (Шаблон 11)
- **approval-gates**: Запрос подтверждения плана
- **error-handling**: DECOMPOSITION_FAILED (Шаблон 14), FILE_CREATE_FAILED (Шаблон 15)
- **phase-execution**: Использует phase files созданные этим скилом

## Часто задаваемые вопросы

**Q: Как определить что задача требует decomposition?**

A: Используй эти критерии:
- **Размер:** > 10 steps, затрагивает > 5 файлов
- **Логические этапы:** Можно разделить на independent parts с dependencies
- **Время:** Выполнение займет > 3 часов
- **Компоненты:** Затрагивает multiple архитектурных слоев (database, API, frontend)

Если задача НЕ подходит под эти критерии → используй **task-lite-template**, не decomposition.

**Q: Почему ограничение 2-5 фаз?**

A:
- **< 2 фазы:** Не имеет смысла decomposition, используй single-phase (task-lite)
- **2-5 фаз:** Optimal balance (управляемо, не too granular)
- **> 5 фаз:** Слишком мелкое разбиение, теряется atomic commits benefit, увеличивается overhead

Если нужно > 5 фаз → задача слишком большая, split на 2 отдельные задачи.

**Q: Можно ли изменить plan после approval?**

A: ДА, но с ограничениями:
- **До выполнения:** Можно модифицировать phase files (steps, criteria)
- **Во время выполнения Phase N:** Можно изменить Phase N+1, N+2, ... (еще не started)
- **После commit Phase N:** НЕ ИЗМЕНЯТЬ Phase N (уже в git history)

Если нужны major changes после approval → cancel execution, restart decomposition.

**Q: Phase Planning Thinking (Шаблон 8) обязателен для КАЖДОЙ фазы?**

A: ДА! Phase Planning Thinking помогает:
- Определить правильный scope фазы
- Разбить на 3-7 steps (не слишком мелко, не слишком крупно)
- Определить commit message type
- Идентифицировать фазо-специфичные риски

Без thinking можем создать несбалансированные фазы (Phase 1: 2 steps, Phase 2: 12 steps).

**Q: Acceptance criteria должны быть распределены равномерно по фазам?**

A: НЕТ! Acceptance criteria распределяются по **логике**, не по количеству:
- Phase 1 (Database) может не покрывать никаких AC (только инфраструктура)
- Phase 2 (Backend) может покрывать 80% AC (основная функциональность)
- Phase 3 (Frontend) может покрывать оставшиеся 20% AC (UI)

Важно чтобы ВСЕ AC были покрыты хотя бы одной фазой.

**Q: Что если dependency cycle (Phase 2 зависит от Phase 3, Phase 3 от Phase 2)?**

A: Это ОШИБКА decomposition! Dependencies должны быть **acyclic**:
- Phase 1 → Phase 2 → Phase 3 ✓ (linear)
- Phase 1 → Phase 2 + Phase 3 ✓ (parallel)
- Phase 1 → Phase 2 → Phase 1 ✗ (cycle - НЕДОПУСТИМО)

Если есть cycle → пересмотреть decomposition, изменить критерий разделения.

**Q: Branch per phase или одна feature branch для всех фаз?**

A: **Рекомендуется:** Одна feature branch для всех фаз.
- Проще управлять (не нужно merge между фазами)
- Atomic commits сохраняются (каждая фаза = отдельный commit)
- Можно rollback отдельные фазы (git revert commit_hash)

**Branch per phase** только если:
- Фазы выполняются разными людьми
- Нужен separate Code Review для каждой фазы

**Q: Сколько времени займет task decomposition?**

A: Зависит от сложности задачи:
- **Simple multi-phase (2-3 фазы):** 10-15 минут (thinking + JSON + files)
- **Complex multi-phase (4-5 фаз):** 20-30 минут
- **Approval gate:** +5 минут (ждать ответа пользователя)

Это overhead, но он окупается:
- Четкий execution plan
- Возможность rollback отдельных фаз
- Лучшая организация (не потеряешь контекст между фазами)

**Q: Можно ли пропустить Master Plan и создать только phase files?**

A: НЕТ! Master Plan **обязателен** потому что:
- Дает overview всех фаз (big picture)
- Показывает dependency graph (execution order понятен)
- Maps acceptance criteria к фазам
- Служит reference во время execution (к какой фазе относится AC X?)

Phase files - детализация, Master Plan - overview.

**Q: Phase metadata JSON слишком verbose - можно сокращать?**

A: НЕТ! phase_metadata должен содержать ВСЕ информацию для автоматизированного execution:
- context (branch_name, dependencies, previous_changes_summary)
- steps[] (детальные actions + validation)
- completion_criteria[] (как проверим что фаза завершена)
- commit_message (готовый commit message)
- risks, validation (syntax checks)

Это позволяет phase-execution skill выполнить фазу **автономно**, без manual intervention.

**Q: Что если Decomposition Thinking показал что задача simple (1 фаза)?**

A: Используй **task-lite-template** вместо task decomposition! Decomposition overhead не окупится для simple tasks.

Decomposition Thinking может заключить:
```xml
<thinking>
ДЕКОМПОЗИЦИЯ:
Почему многофазная: НЕ МНОГОФАЗНАЯ
  Все изменения в одном компоненте (OrderService)
  Нет dependencies между частями
  Выполняется за 1-2 часа
→ ВЫВОД: Используй task-lite-template
</thinking>
```

**Q: Parallel phases supported?**

A: Теоретически ДА (если нет dependencies), но **НЕ РЕКОМЕНДУЕТСЯ** для single developer:
- Сложнее управлять execution
- Возможны merge conflicts
- Теряется atomic commits benefit

Используй parallel phases только если:
- Multiple developers работают одновременно
- Фазы **действительно** independent (no shared files)
