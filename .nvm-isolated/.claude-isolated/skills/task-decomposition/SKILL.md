---
name: Task Decomposition
description: Автоматизация разбиения задачи на 2-5 логических фаз с генерацией master plan и individual phase files
version: 1.2.0
tags: [phase-based, decomposition, planning, master-plan, workflow]
dependencies: [thinking-framework, structured-planning, approval-gates, error-handling]
user-invocable: false
agent: Plan
changelog:
  - version: 1.2.0
    date: 2026-01-25
    changes:
      - "Удалён author field (cleanup)"
  - version: 1.1.0
    date: 2026-01-25
    changes:
      - "Централизация: Thinking templates → @shared:THINKING-PATTERNS.md"
      - "Централизация: Task structure → @shared:TASK-STRUCTURE.md"
      - "Добавлено: 6 полных примеров multi-phase decomposition (auth system, e-commerce, API migration, UI redesign, third-party integration, caching layer)"
      - "Обновлено: References используют @shared: syntax вместо устаревших \"Шаблон N\""
  - version: 1.0.0
    date: 2025-XX-XX
    changes:
      - "Initial release: Multi-phase task decomposition"
---

# Task Decomposition v1.1

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

---

## References

### Thinking Framework
@shared:THINKING-PATTERNS.md#analysis

**Skill-specific usage:**
- Используй **analysis thinking** для decomposition reasoning
- Обоснуй количество фаз (2-5)
- Map acceptance criteria к фазам
- Определи dependencies между фазами

### Task Structure
@shared:TASK-STRUCTURE.md#task-decomposition
@shared:TASK-STRUCTURE.md#phase-metadata

**Skill-specific schemas:**
- `task_decomposition` JSON для multi-phase planning
- `phase_metadata` JSON для individual phases

### Git Conventions
@shared:GIT-CONVENTIONS.md#commit-message-format

**Skill-specific usage:**
- Каждая фаза = отдельный commit
- commit_message генерируется для каждой фазы

---

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
1. THINKING: Decomposition Analysis
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
- **thinking-framework**: Analysis thinking для decomposition reasoning
- **structured-planning**: Task Decomposition JSON, Phase Metadata JSON schemas
- **approval-gates**: Получение подтверждения плана перед созданием phase files
- **error-handling**: DECOMPOSITION_FAILED, FILE_CREATE_FAILED

---

## Domain-Specific Examples

### Example 1: Authentication System (3 Phases)

**Situation:** Add JWT authentication with refresh tokens

**Input:**
- Task: "Implement JWT authentication system with login, refresh, logout endpoints"
- Complexity: complex (database + backend + frontend)
- Estimated total: 18 steps

**Decomposition Thinking:**

```xml
<thinking type="analysis">
ЗАДАЧА: Add JWT authentication system
СЛОЖНОСТЬ: Complex (затрагивает database, backend API, frontend)

КОМПОНЕНТЫ:
- Database: User model, RefreshToken model (2 tables + migrations)
- Backend: JWTService, auth endpoints (login, refresh, logout)
- Frontend: Auth interceptor, login form, token storage

ДЕКОМПОЗИЦИЯ:
Критерий разделения: По архитектурным слоям (database → backend → frontend)
Количество фаз: 3

ОБОСНОВАНИЕ: Каждый слой независимо тестируется. Database schema нужен для backend. Backend API нужен для frontend.

ФАЗЫ:
Phase 1: Database Models
  - User model с password hashing
  - RefreshToken model
  - Migrations
  - Provides: Database schema для auth

Phase 2: Backend API + JWT Logic
  - JWTService (generate, validate tokens)
  - Login endpoint (email/password → tokens)
  - Refresh endpoint (refresh_token → new access_token)
  - Logout endpoint (invalidate refresh_token)
  - JWT middleware для protected routes
  - Provides: Working auth API

Phase 3: Frontend Integration
  - Auth interceptor (add Authorization header)
  - Login form component
  - Token storage (localStorage)
  - Protected route handling
  - Provides: End-to-end auth flow

ACCEPTANCE CRITERIA MAPPING:
AC1 (User registration) → Phase 1 (User model) + Phase 2 (register endpoint)
AC2 (JWT authentication) → Phase 2 (JWT logic)
AC3 (Refresh tokens) → Phase 1 (RefreshToken model) + Phase 2 (refresh endpoint)
AC4 (Frontend login) → Phase 3 (frontend integration)

ВЫВОДЫ: 3 фазы оптимально. Linear dependency chain (1→2→3). Each phase testable independently.
</thinking>
```

**Task Decomposition JSON:**

```json
{
  "task_decomposition": {
    "task_name": "Add JWT Authentication System",
    "task_slug": "add-jwt-auth",
    "complexity": "complex",
    "total_phases": 3,
    "decomposition_rationale": "Authentication system splits cleanly into 3 layers: database schema (User, RefreshToken), backend API (JWTService, endpoints), frontend integration (interceptor, login UI). Each layer independently testable.",
    "phases": [
      {
        "phase_number": 1,
        "phase_name": "Database Models + Migrations",
        "phase_slug": "database-models",
        "goal": "Create User and RefreshToken database models with migrations",
        "estimated_steps": 5,
        "dependencies": [],
        "provides_for_next": ["User model", "RefreshToken model"],
        "acceptance_criteria_covered": ["AC1: User registration (partial)"]
      },
      {
        "phase_number": 2,
        "phase_name": "Backend API + JWT Logic",
        "phase_slug": "backend-api",
        "goal": "Implement login, refresh, logout endpoints with JWT authentication",
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
        "goal": "Integrate auth API in frontend (interceptor, login form)",
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

**Master Plan:** `plans/master-plan-add-jwt-auth.md`

```markdown
# Master Plan: Add JWT Authentication System

**Created:** 2026-01-25
**Status:** Planning Complete
**Branch:** feature/add-jwt-auth

---

## Overview

Add JWT-based authentication system with refresh token mechanism. Task split into 3 phases for sequential implementation by architectural layers.

---

## Phases Overview

### Phase 1: Database Models + Migrations
- **Goal:** Create User and RefreshToken database models
- **Dependencies:** None
- **Provides:** Database schema
- **Acceptance Criteria:** AC1 (partial)
- **File:** `plans/phase-1-database-models.md`
- **Estimated Steps:** 5

### Phase 2: Backend API + JWT Logic
- **Goal:** Implement login, refresh, logout endpoints
- **Dependencies:** User model, RefreshToken model (Phase 1)
- **Provides:** Working auth endpoints
- **Acceptance Criteria:** AC1 (complete), AC2, AC3
- **File:** `plans/phase-2-backend-api.md`
- **Estimated Steps:** 7

### Phase 3: Frontend Integration
- **Goal:** Integrate auth API in frontend
- **Dependencies:** Working auth endpoints (Phase 2)
- **Provides:** Full auth flow
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

**Execution Order:** Sequential (1 → 2 → 3)

---

## Acceptance Criteria Mapping

| Criterion | Phase | Status |
|-----------|-------|--------|
| AC1: User registration | Phase 1 + Phase 2 | Pending |
| AC2: JWT authentication | Phase 2 | Pending |
| AC3: Refresh tokens | Phase 1 + Phase 2 | Pending |
| AC4: Frontend login | Phase 3 | Pending |
```

**Result:** 3 phases, linear dependency, 18 total steps.

---

### Example 2: E-Commerce Order System (4 Phases)

**Situation:** Build complete order management system

**Input:**
- Task: "Create order system with cart, checkout, payment, and order tracking"
- Complexity: complex (multiple features, payment integration)
- Estimated total: 24 steps

**Decomposition Thinking:**

```xml
<thinking type="analysis">
ЗАДАЧА: E-commerce order management system
СЛОЖНОСТЬ: Complex (4 major features, payment gateway integration)

КОМПОНЕНТЫ:
- Shopping cart (add/remove items, update quantities)
- Checkout flow (shipping info, payment method selection)
- Payment processing (Stripe integration, webhook handling)
- Order tracking (status updates, order history)

ДЕКОМПОЗИЦИЯ:
Критерий разделения: По user journey stages (cart → checkout → payment → tracking)
Количество фаз: 4

ОБОСНОВАНИЕ: Each stage independently valuable. Cart functional without payment. Checkout without payment = "save order". Payment adds monetization. Tracking enhances UX.

ФАЗЫ:
Phase 1: Shopping Cart
  - Cart model (user_id, items[], total)
  - Add/remove/update cart items
  - Cart persistence (save to database)
  - Provides: Working cart functionality

Phase 2: Checkout Flow
  - Order model (user_id, status, shipping_address)
  - Checkout API (create order from cart)
  - Shipping address validation
  - Provides: Order creation without payment

Phase 3: Payment Integration
  - Stripe integration (create payment intent)
  - Webhook handler (payment confirmation)
  - Order status update (pending → paid)
  - Provides: Monetization capability

Phase 4: Order Tracking
  - Order status tracking (processing, shipped, delivered)
  - Order history endpoint
  - Email notifications on status change
  - Provides: Customer visibility

ACCEPTANCE CRITERIA MAPPING:
AC1 (Add items to cart) → Phase 1
AC2 (Checkout with shipping) → Phase 2
AC3 (Payment processing) → Phase 3
AC4 (Order status tracking) → Phase 4

ВЫВОДЫ: 4 фазы optimal. Each phase delivers incremental value. Dependencies: 1→2→3→4 (linear).
</thinking>
```

**Task Decomposition JSON:**

```json
{
  "task_decomposition": {
    "task_name": "Build E-Commerce Order System",
    "task_slug": "ecommerce-order-system",
    "complexity": "complex",
    "total_phases": 4,
    "decomposition_rationale": "Order system follows natural user journey: cart → checkout → payment → tracking. Each stage independently valuable and testable.",
    "phases": [
      {
        "phase_number": 1,
        "phase_name": "Shopping Cart",
        "phase_slug": "shopping-cart",
        "goal": "Implement cart functionality (add, remove, update items)",
        "estimated_steps": 6,
        "dependencies": [],
        "provides_for_next": ["Cart model with items"],
        "acceptance_criteria_covered": ["AC1: Add items to cart"]
      },
      {
        "phase_number": 2,
        "phase_name": "Checkout Flow",
        "phase_slug": "checkout-flow",
        "goal": "Create order from cart with shipping validation",
        "estimated_steps": 6,
        "dependencies": ["Cart model with items"],
        "provides_for_next": ["Order model"],
        "acceptance_criteria_covered": ["AC2: Checkout with shipping"]
      },
      {
        "phase_number": 3,
        "phase_name": "Payment Integration",
        "phase_slug": "payment-integration",
        "goal": "Integrate Stripe payment processing",
        "estimated_steps": 7,
        "dependencies": ["Order model"],
        "provides_for_next": ["Payment confirmation"],
        "acceptance_criteria_covered": ["AC3: Payment processing"]
      },
      {
        "phase_number": 4,
        "phase_name": "Order Tracking",
        "phase_slug": "order-tracking",
        "goal": "Add order status tracking and history",
        "estimated_steps": 5,
        "dependencies": ["Payment confirmation"],
        "provides_for_next": [],
        "acceptance_criteria_covered": ["AC4: Order status tracking"]
      }
    ],
    "branch_strategy": {
      "base_branch": "master",
      "feature_branch": "feature/ecommerce-order-system",
      "branch_per_phase": false
    },
    "execution_order": [1, 2, 3, 4],
    "parallel_phases": []
  }
}
```

**Result:** 4 phases, linear dependency (1→2→3→4), 24 total steps.

---

### Example 3: API Versioning Migration (3 Phases)

**Situation:** Migrate API from v1 to v2 with backward compatibility

**Input:**
- Task: "Introduce API v2 with new response format, maintain v1 for 6 months"
- Complexity: complex (breaking changes, dual support)
- Estimated total: 16 steps

**Decomposition Thinking:**

```xml
<thinking type="analysis">
ЗАДАЧА: API versioning migration (v1 → v2)
СЛОЖНОСТЬ: Complex (breaking changes, backward compatibility required)

КОМПОНЕНТЫ:
- API v2 endpoints (new response format)
- Dual version support (v1 + v2 live simultaneously)
- Client migration guide + deprecation warnings

ДЕКОМПОЗИЦИЯ:
Критерий разделения: По migration stages (implement v2 → enable dual support → deprecate v1)
Количество фаз: 3

ОБОСНОВАНИЕ: Can't break v1 clients. Must run both versions parallel. Gradual migration path.

ФАЗЫ:
Phase 1: Implement API v2
  - Create v2 endpoints (/api/v2/*)
  - New response format (nested objects, pagination)
  - Unit tests для v2
  - Provides: Working v2 endpoints (not public yet)

Phase 2: Enable Dual Version Support
  - Routing logic (Accept-Version header or URL path)
  - v1 endpoints unchanged (backward compatible)
  - v2 endpoints live (opt-in for early adopters)
  - Load testing (ensure no performance degradation)
  - Provides: Both v1 and v2 available

Phase 3: Deprecation Warnings + Migration Guide
  - Add deprecation warnings to v1 responses (X-API-Deprecated header)
  - Migration guide documentation
  - Client SDK updates (support both versions)
  - Provides: Migration path for clients

ACCEPTANCE CRITERIA MAPPING:
AC1 (v2 endpoints functional) → Phase 1
AC2 (Both versions work) → Phase 2
AC3 (Deprecation warnings) → Phase 3

ВЫВОДЫ: 3 фазы optimal. Phase 1 implemented first (safe, no breaking). Phase 2 enables dual support. Phase 3 prepares for v1 sunset.
</thinking>
```

**Result:** 3 phases, backend-only changes, 16 total steps.

---

### Example 4: UI Redesign with Component Library (3 Phases)

**Situation:** Redesign UI using new component library

**Input:**
- Task: "Migrate from custom CSS to Chakra UI component library across all pages"
- Complexity: complex (25+ components affected)
- Estimated total: 18 steps

**Decomposition Thinking:**

```xml
<thinking type="analysis">
ЗАДАЧА: UI redesign with Chakra UI migration
СЛОЖНОСТЬ: Complex (25+ components, design system change)

КОМПОНЕНТЫ:
- Component library setup (Chakra UI installation, theme)
- Core components migration (Button, Input, Card - used everywhere)
- Page-level migration (Dashboard, Settings, Profile pages)

ДЕКОМПОЗИЦИЯ:
Критерий разделения: По dependency layers (setup → core components → pages)
Количество фаз: 3

ОБОСНОВАНИЕ: Must setup library first. Core components used by pages (can't migrate pages without core). Pages can be migrated incrementally.

ФАЗЫ:
Phase 1: Setup Component Library
  - Install Chakra UI + dependencies
  - Create custom theme (colors, typography, spacing)
  - Setup ChakraProvider in root
  - Provides: Chakra UI ready to use

Phase 2: Migrate Core Components
  - Button component (replace custom CSS → Chakra Button)
  - Input component (replace → Chakra Input)
  - Card component (replace → Chakra Box with styling)
  - Modal component (replace → Chakra Modal)
  - Provides: Core components using Chakra

Phase 3: Migrate Pages
  - Dashboard page (use new core components)
  - Settings page
  - Profile page
  - Remove custom CSS files
  - Provides: Full UI redesigned

ACCEPTANCE CRITERIA MAPPING:
AC1 (Chakra UI setup) → Phase 1
AC2 (Core components migrated) → Phase 2
AC3 (All pages redesigned) → Phase 3

ВЫВОДЫ: 3 фазы frontend-focused. Linear dependency (1→2→3). Incremental migration reduces risk.
</thinking>
```

**Result:** 3 phases, frontend-heavy, 18 total steps.

---

### Example 5: Third-Party API Integration (2 Phases)

**Situation:** Integrate Stripe payment gateway

**Input:**
- Task: "Add Stripe payment processing to checkout flow"
- Complexity: standard (external integration, webhook handling)
- Estimated total: 10 steps

**Decomposition Thinking:**

```xml
<thinking type="analysis">
ЗАДАЧА: Stripe payment integration
СЛОЖНОСТЬ: Standard (external API integration)

КОМПОНЕНТЫ:
- Stripe SDK setup + payment flow (create payment intent, confirm)
- Webhook handling (payment success/failure events)

ДЕКОМПОЗИЦИЯ:
Критерий разделения: По integration stages (payment flow → event handling)
Количество фаз: 2

ОБОСНОВАНИЕ: Payment flow can work without webhooks (polling alternative). Webhooks enhance reliability but not required for MVP.

ФАЗЫ:
Phase 1: Payment Flow Implementation
  - Install Stripe SDK
  - Create payment intent API
  - Payment confirmation flow
  - Test with Stripe test cards
  - Provides: Working payment processing

Phase 2: Webhook Integration
  - Setup webhook endpoint (/webhooks/stripe)
  - Verify webhook signatures
  - Handle payment_intent.succeeded event
  - Handle payment_intent.payment_failed event
  - Provides: Reliable payment confirmation

ACCEPTANCE CRITERIA MAPPING:
AC1 (Payment processing) → Phase 1
AC2 (Webhook handling) → Phase 2

ВЫВОДЫ: 2 фазы minimal. Phase 1 delivers core value. Phase 2 adds production reliability.
</thinking>
```

**Result:** 2 phases, minimal decomposition, 10 total steps.

---

### Example 6: Caching Layer Addition (3 Phases)

**Situation:** Add Redis caching to improve performance

**Input:**
- Task: "Implement Redis caching for frequently accessed data (users, posts, analytics)"
- Complexity: complex (multiple cache strategies)
- Estimated total: 15 steps

**Decomposition Thinking:**

```xml
<thinking type="analysis">
ЗАДАЧА: Redis caching layer
СЛОЖНОСТЬ: Complex (different cache strategies per data type)

КОМПОНЕНТЫ:
- Redis setup + connection pooling
- User data caching (cache-aside pattern)
- Post data caching (write-through pattern)
- Analytics caching (TTL-based expiration)

ДЕКОМПОЗИЦИЯ:
Критерий разделения: По data types (infrastructure → users → posts/analytics)
Количество фаз: 3

ОБОСНОВАНИЕ: Infrastructure first (Redis setup). Then user cache (highest ROI, simple cache-aside). Then posts + analytics (more complex strategies).

ФАЗЫ:
Phase 1: Redis Infrastructure
  - Install Redis + client library
  - Connection pooling configuration
  - Basic get/set operations
  - Health check endpoint
  - Provides: Redis ready for caching

Phase 2: User Data Caching
  - Cache-aside pattern для getUserById
  - Cache invalidation on user update
  - TTL: 5 minutes
  - Provides: User data cached (70% queries cached)

Phase 3: Posts + Analytics Caching
  - Write-through для createPost (cache on write)
  - Analytics aggregation caching (TTL: 1 hour)
  - Cache warming on server start
  - Provides: Full caching coverage

ACCEPTANCE CRITERIA MAPPING:
AC1 (Redis setup) → Phase 1
AC2 (User data cached) → Phase 2
AC3 (Posts + analytics cached) → Phase 3

ВЫВОДЫ: 3 фазы performance-focused. Each phase reduces load incrementally. Dependencies: 1→2→3.
</thinking>
```

**Result:** 3 phases, infrastructure → incremental caching, 15 total steps.

---

## Шаблоны

### Шаблон 1: Decomposition Thinking (ОБЯЗАТЕЛЬНО)

**[CRITICAL] Thinking перед decomposition - обязателен!**

Используй @shared:THINKING-PATTERNS.md#analysis для decomposition reasoning.

**Exit Conditions:**
- ✓ Thinking завершен
- ✓ Количество фаз определено (2-5)
- ✓ Acceptance criteria mapped к фазам

**Violation Action:**
- Нет явных фаз → DECOMPOSITION_FAILED (error-handling) → STOP, используй task-lite-template
- Слишком много фаз (> 5) → Пересмотреть decomposition strategy
- Слишком мало фаз (< 2) → Используй task-lite-template

---

### Шаблон 2: Task Decomposition JSON

Используй @shared:TASK-STRUCTURE.md#task-decomposition для schema reference.

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
- Schema validation failed → JSON_SCHEMA_VALIDATION_ERROR → RETRY (max 1)
- total_phases < 2 или > 5 → DECOMPOSITION_FAILED → STOP

---

### Шаблон 3: Master Plan Generation

Используй @shared:TASK-STRUCTURE.md#master-plan для structure reference.

**Master Plan File:** `plans/master-plan-{task_slug}.md`

**Содержимое:**
```markdown
# Master Plan: {Task Name}

**Created:** {Date}
**Status:** Planning Complete
**Branch:** {feature_branch}

---

## Overview

{1-3 paragraph summary}

---

## Phases Overview

### Phase 1: {Name}
- **Goal:** {goal}
- **Dependencies:** {dependencies or "None"}
- **Provides:** {provides_for_next}
- **Acceptance Criteria:** {AC covered}
- **File:** `plans/phase-1-{slug}.md`
- **Estimated Steps:** {N}

[Repeat for each phase]

---

## Dependency Graph

```
Phase 1 → Phase 2 → Phase 3
```

**Execution Order:** {execution_order}

---

## Acceptance Criteria Mapping

| Criterion | Phase | Status |
|-----------|-------|--------|
| AC1 | Phase N | Pending |

---

## Branch Strategy

- **Base Branch:** {base_branch}
- **Feature Branch:** {feature_branch}
- **Branch per Phase:** {yes/no}

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
- File creation failed → FILE_CREATE_FAILED → STOP

---

### Шаблон 4: Phase File Generation

Используй @shared:TASK-STRUCTURE.md#phase-metadata для structure reference.

**Для каждой фазы:** Создать `plans/phase-{N}-{phase_slug}.md`

**Phase File Содержимое:**
```markdown
# Phase {N}: {Phase Name}

**Phase:** {N}/{total_phases}
**Goal:** {goal}
**Branch:** {feature_branch}
**Dependencies:** {dependencies}

---

## Phase Metadata (JSON)

```json
{
  "phase_metadata": {
    "phase_number": N,
    "phase_name": "{name}",
    "total_phases": {total},
    "goal": "{goal}",
    "context": {
      "branch_name": "{feature_branch}",
      "base_branch": "{base}",
      "previous_changes_summary": "{summary from Phase N-1}",
      "dependencies": ["{dep1}", "{dep2}"]
    },
    "steps": [
      {
        "step_number": 1,
        "description": "{description}",
        "actions": ["{action1}", "{action2}"],
        "validation": "{validation_command}"
      }
    ],
    "completion_criteria": [
      "{criterion1}",
      "{criterion2}"
    ],
    "commit_message": {
      "type": "{feat/fix/refactor}",
      "summary": "{summary}",
      "body": "{body}"
    },
    "risks": [
      "{risk1}",
      "{risk2}"
    ],
    "validation": {
      "syntax_check_required": true,
      "files_to_check": ["{file1}"]
    }
  }
}
```

---

## Execution

Для выполнения этой фазы:
```
"Выполни Phase {N} из plans/phase-{N}-{slug}.md"
```

---

## Next Phase

После завершения Phase {N}:
→ Phase {N+1}: {Next Phase Name}
  File: plans/phase-{N+1}-{slug}.md
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
- File creation failed → FILE_CREATE_FAILED → STOP
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

TASK: {Task Name}
COMPLEXITY: {complexity}

DECOMPOSITION:
- Total Phases: {N}
- Total Steps: ~{total_steps}
- Branch: {feature_branch}

PHASES:
1. {Phase 1 Name} ({steps} steps)
   Dependencies: {dependencies or "None"}
   Provides: {provides_for_next}

2. {Phase 2 Name} ({steps} steps)
   Dependencies: {dependencies}
   Provides: {provides_for_next}

[Continue for each phase]

ACCEPTANCE CRITERIA COVERAGE:
- AC1: {description} → Phase {N} ✓
- AC2: {description} → Phase {N} ✓

FILES TO CREATE:
- plans/master-plan-{slug}.md
- plans/phase-1-{slug}.md
- plans/phase-2-{slug}.md

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
- approved = false → APPROVAL_REJECTED → STOP
- Requested modifications → Вернуться к Decomposition Thinking, исправить, RETRY

---

## Проверочный чеклист

После завершения task decomposition проверь:

**Thinking:**
- [ ] Decomposition analysis завершен
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

- **thinking-framework**: Analysis thinking для decomposition
- **structured-planning**: Task Decomposition JSON, Phase Metadata JSON schemas
- **approval-gates**: Запрос подтверждения плана
- **error-handling**: DECOMPOSITION_FAILED, FILE_CREATE_FAILED
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

**Q: Можно ли пропустить Master Plan и создать только phase files?**

A: НЕТ! Master Plan **обязателен** потому что:
- Дает overview всех фаз (big picture)
- Показывает dependency graph (execution order понятен)
- Maps acceptance criteria к фазам
- Служит reference во время execution (к какой фазе относится AC X?)

Phase files - детализация, Master Plan - overview.

**Q: Что если Decomposition Thinking показал что задача simple (1 фаза)?**

A: Используй **task-lite-template** вместо task decomposition! Decomposition overhead не окупится для simple tasks.

Decomposition thinking может заключить:
```xml
<thinking type="analysis">
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

---

**License:** MIT
**Support:** См. @shared:THINKING-PATTERNS.md, @shared:TASK-STRUCTURE.md для детальной документации

🤖 Generated with Claude Code
