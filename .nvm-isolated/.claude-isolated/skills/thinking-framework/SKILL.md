---
name: Thinking Framework
description: Структурированный reasoning через 3 универсальных шаблона
version: 2.1.0
tags: [thinking, reasoning, decision-making, analysis, risk-assessment]
dependencies: []
files:
  templates: ./templates/*.xml
  examples: ./examples/*.md
user-invocable: false
changelog:
  - version: 2.1.0
    date: 2026-01-25
    changes:
      - "Централизация: Templates и rules → @shared:THINKING-PATTERNS.md"
      - "Добавлено: 6 полных примеров (PRD analysis, library choice, migration risk, etc.)"
      - "Улучшено: Integration guide для других skills"
---

# Thinking Framework v2.1

Структурированный reasoning через 3 универсальных шаблона (analysis, decision, risk).

## Когда использовать

- **Перед планированием** (PHASE 1) - analysis thinking
- **При выборе между вариантами** - decision thinking
- **Перед рискованными операциями** - risk thinking
- **Всегда когда нужно обосновать решение**

---

## Reference: Thinking Patterns

**Full specification:**
```
@shared:THINKING-PATTERNS.md
```

Централизованная документация содержит:
- 3 universal templates (analysis, decision, risk)
- Field-by-field descriptions
- 9 reference примеров (3 per template)
- Decision tree для template selection
- Nesting rules
- Best practices

**Quick template overview:**

| Template | When | Structure |
|----------|------|-----------|
| **analysis** | Начало задачи, PRD check | ЗАДАЧА → КОНТЕКСТ → КОМПОНЕНТЫ → PRD → CRITERIA → ВЫВОДЫ |
| **decision** | Несколько вариантов | КОНТЕКСТ → ОПЦИИ → TRADE-OFFS → ВЫБОР → ОБОСНОВАНИЕ |
| **risk** | Опасные операции | ОПЕРАЦИЯ → РИСКИ → FALLBACK → ROLLBACK |

См. `@shared:THINKING-PATTERNS.md` для полных templates.

---

## When to Use Which Template

| Situation | Template | Example |
|-----------|----------|---------|
| User request: "Add feature X" | **analysis** | Понять требования, AC |
| Choice between libraries | **decision** | Compare options |
| Database migration | **risk** | Assess risks, plan rollback |
| Bug fix: "Error in Y" | **analysis** | Root cause analysis |
| Multiple API designs | **decision** | Trade-off analysis |
| Refactor critical code | **risk** | Breaking change risk |
| PRD implementation check | **analysis** | Alignment verification |

**Decision tree:** См. `@shared:THINKING-PATTERNS.md#when-to-use-which-template`

---

## Rules

### ✅ When Thinking is Required

1. **Перед началом каждой фазы**
   - PHASE 1: analysis thinking перед planning
   - PHASE 2: decision thinking если несколько approaches
   - PHASE 4: risk thinking если risky validation

2. **Выбор между альтернативами**
   - Несколько библиотек/паттернов
   - Разные implementation strategies

3. **Рискованные операции**
   - Breaking changes
   - Database migrations
   - Production deployments

### ⚠️ When Thinking is Optional

- Простые однозначные задачи (typo fix, add constant)
- Когда решение очевидно (one clear approach)
- Repetitive operations (same pattern as before)

### 🚫 Thinking is NOT Outputted

**IMPORTANT:** Thinking - внутренний процесс Claude. User видит только:
- Structured output (JSON)
- Task plan
- Final result

Thinking НЕ включается в user-facing output.

---

## Domain-Specific Examples

### Example 1: Analysis Thinking - Feature Implementation

**Situation:** User requests "Add transaction filtering endpoint"

**Thinking:**
```xml
<thinking type="analysis">
ЗАДАЧА: Реализовать endpoint GET /transactions с query parameters для фильтрации по дате и категории

КОНТЕКСТ: Проект использует FastAPI + SQLAlchemy. Существуют endpoints:
- GET /transactions (all, without filters)
- GET /transactions/{id} (single)
PRD секция 4.2 "Transaction Filtering" требует: date_from, date_to, category params.

КОМПОНЕНТЫ:
- app/api/transactions.py (modify - добавить query params)
- app/services/transaction_service.py (modify - filter logic)
- tests/test_transactions_api.py (modify - integration tests)

PRD: Секция 4.2 "Transaction Filtering":
- Query params: date_from (ISO), date_to (ISO), category (enum)
- AND logic для multiple filters
- Pagination: limit 50 default
- Error handling: Invalid date → 400 error

ACCEPTANCE CRITERIA:
- Все 3 query params работают
- Комбинация filters использует AND logic
- Pagination добавлена (limit/offset)
- Error handling для invalid inputs
- Integration tests для filter combinations

ВЫВОДЫ: Добавить 3 optional query parameters в endpoint. Реализовать TransactionService.filter() с AND logic. Добавить pagination. Валидация date format через Pydantic. Integration tests для 5+ filter scenarios.
</thinking>
```

**Result:** Thinking → task_plan с 5 execution steps

---

### Example 2: Analysis Thinking - Root Cause (Bug Fix)

**Situation:** "NullPointerException in OrderValidator"

**Thinking:**
```xml
<thinking type="analysis">
ЗАДАЧА: Исправить NullPointerException при валидации заказа с пустым списком items

КОНТЕКСТ: OrderValidator.validate() вызывает order.items.forEach() без проверки на null. Ошибка возникает при создании заказа через POST /orders без items в body.

Stack trace:
  File "app/validators/order_validator.py", line 42, in validate
    for item in order.items:
  AttributeError: 'NoneType' object has no attribute '__iter__'

КОМПОНЕНТЫ:
- app/validators/order_validator.py (modify - добавить null check)
- tests/test_order_validator.py (modify - edge case test)

PRD: Секция "Order Validation Rules": "Orders without items should be rejected with 400 error"

ACCEPTANCE CRITERIA:
- Null check перед обращением к order.items
- Возврат ValidationError("Order must contain at least one item")
- Test для edge case: order with items=None
- Test для edge case: order with items=[]

ВЫВОДЫ: ROOT CAUSE - отсутствие null check перед итерацией. FIX - добавить early return в validate() с проверкой order.items is None. Выбросить ValidationError с понятным message. Добавить 2 edge case tests.
</thinking>
```

**Result:** Thinking → 2-step task plan (fix + tests)

---

### Example 3: Decision Thinking - Library Choice

**Situation:** Выбор library для date manipulation

**Thinking:**
```xml
<thinking type="decision">
КОНТЕКСТ: Нужно выбрать library для date/time operations в Python FastAPI проекте. Требования: timezone support, date arithmetic, parsing ISO 8601.

ОПЦИИ:
  1. datetime (stdlib) —
     Плюсы: No dependencies, fast, built-in, stable API
     Минусы: Complex timezone handling (pytz needed), verbose API for common operations

  2. arrow —
     Плюсы: Human-friendly API ("2 days ago"), excellent timezone support, popular
     Минусы: External dependency (+1 package), slightly slower than datetime

  3. pendulum —
     Плюсы: Drop-in replacement for datetime, better tz than stdlib, immutable
     Минусы: Larger dependency (4MB), less popular than arrow (smaller community)

TRADE-OFFS:
  - datetime: Simplicity (no deps) vs Convenience (verbose API)
  - arrow: Developer experience (nice API) vs Dependencies (external package)
  - pendulum: Best timezone support vs Popularity (smaller community, less SO answers)

ВЫБОР: Вариант 1 (datetime + pytz)

ОБОСНОВАНИЕ: Проект уже использует stdlib везде для consistency (requests, json, pathlib). Timezone handling нужен только для UTC conversion (simple use case). Избегаем дополнительных dependencies без явной выгоды. Human-friendly API от arrow не нужен (только programmatic usage). Trade-off: Verbose API приемлем для простых операций.
</thinking>
```

**Result:** Thinking → использовать datetime в task plan

---

### Example 4: Decision Thinking - Architecture Pattern

**Situation:** Рефакторинг validation logic

**Thinking:**
```xml
<thinking type="decision">
КОНТЕКСТ: OrderService.validate() содержит ~200 lines validation logic. Нужно улучшить testability и maintainability.

ОПЦИИ:
  1. Extract to OrderValidator class (separate class) —
     Плюсы: Clear SRP, easy unit testing, reusable across services
     Минусы: One more file, potential over-engineering for simple validations

  2. Split into smaller methods in OrderService —
     Плюсы: No new files, simpler refactor, less code changes
     Минусы: OrderService becomes god class (mixing business logic + validation), harder to test validation separately

  3. Chain of Responsibility pattern (multiple validators) —
     Плюсы: Highly extensible, each validator independent, easy to add new rules
     Минусы: Over-engineered for current needs (only 5 validation rules), added complexity, harder to understand flow

TRADE-OFFS:
  - Вариант 1: Simplicity (one file) vs Separation of Concerns (clear responsibility)
  - Вариант 2: Minimal code changes vs Long-term maintainability
  - Вариант 3: Extensibility (future-proof) vs Complexity (YAGNI principle)

ВЫБОР: Вариант 1 (OrderValidator class)

ОБОСНОВАНИЕ: Validation - отдельная responsibility, заслуживает отдельного класса (SRP). Улучшает testability - можно unit-тестировать validation без мокирования service dependencies. Не over-engineering т.к. validation logic уже 200 lines (substantial). Chain of Responsibility (вариант 3) - YAGNI, текущие 5 rules не требуют такой гибкости. Вариант 2 делает OrderService god class (anti-pattern).
</thinking>
```

**Result:** Thinking → task plan с extract validator class

---

### Example 5: Risk Thinking - Database Migration

**Situation:** Добавить NOT NULL constraint в production

**Thinking:**
```xml
<thinking type="risk">
ОПЕРАЦИЯ: Database migration - добавить column "email_verified" (boolean NOT NULL) в users table с 50K rows. Production database PostgreSQL 14.

РИСКИ:
  1. Migration timeout на большой таблице —
     Вероятность: Medium
     Impact: High (locks table, blocks all user operations)
     Митигация:
     - Добавить column как nullable сначала
     - Заполнить default values в background job (no table lock)
     - Затем ALTER COLUMN SET NOT NULL в отдельной migration (instant)

  2. Application downtime во время migration —
     Вероятность: High
     Impact: Medium (~30 sec downtime expected)
     Митигация:
     - Zero-downtime strategy: ADD column (nullable) → Deploy code supporting both states → Backfill data → Make NOT NULL
     - Total time: ~5 min, actual downtime: 0 sec

  3. Data loss если migration fails mid-process —
     Вероятность: Low
     Impact: High (50K user records)
     Митигация:
     - Full pg_dump backup перед migration (15 min)
     - Test migration на staging copy first (verify no errors)
     - Use transaction (BEGIN; ...; COMMIT;) для atomicity

FALLBACK: Если migration fails - оставить column как nullable, заполнить default value (false) для existing rows через UPDATE, продолжить работу без NOT NULL constraint.

ROLLBACK:
1. DROP column email_verified (instant, no data loss)
2. Deploy previous code version (30 sec)
3. Restore from pg_dump backup если data corruption (15 min recovery)
Estimated rollback time: 30 seconds (best case) to 20 minutes (full restore)
</thinking>
```

**Result:** Thinking → risk mitigation steps в task plan

---

### Example 6: Risk Thinking - Breaking API Change

**Situation:** Change response format (v1 → v2)

**Thinking:**
```xml
<thinking type="risk">
ОПЕРАЦИЯ: Refactor API response format - изменить GET /transactions response с flat array на nested object с pagination metadata. Breaking change для mobile apps.

РИСКИ:
  1. Mobile apps (iOS/Android) перестанут работать —
     Вероятность: High
     Impact: High (100K+ active users)
     Митигация:
     - API versioning: /api/v1/transactions (old format, deprecated) + /api/v2/transactions (new format)
     - Deprecated v1 через 6 months (notification via in-app banner)
     - Both versions live parallel first 3 months

  2. Third-party integrations break —
     Вероятность: Medium
     Impact: Medium (5 known integrations)
     Митигация:
     - Contact integration partners (2 weeks notice)
     - Provide migration guide with code examples
     - Offer support during transition period

  3. Performance degradation с nested structure —
     Вероятность: Low
     Impact: Medium (response size +15%)
     Митигация:
     - Load testing: verify p95 latency < 200ms
     - Monitor response times first 48h after deploy
     - Auto-rollback если p95 > 500ms

FALLBACK: Если critical issues - keep v1 as default, make v2 opt-in via header (Accept: application/vnd.api.v2+json). Gradual rollout.

ROLLBACK:
1. Switch default version back to v1 (config change, instant)
2. Keep v2 available для early adopters
3. Extend deprecation period на 3 more months
Estimated rollback time: < 5 minutes (config switch)
</thinking>
```

**Result:** Thinking → API versioning strategy в task plan

---

## Integration with Other Skills

### structured-planning

**Uses analysis thinking в PHASE 1:**
```
1. User provides task
2. thinking-framework → analysis thinking (understand requirements)
3. structured-planning → generate task_plan based on ВЫВОДЫ
```

**Uses decision thinking если multiple approaches:**
```
1. analysis thinking reveals 2+ solutions
2. thinking-framework → decision thinking (compare approaches)
3. structured-planning → use selected approach in task_plan
```

### adaptive-workflow

**Uses decision thinking для complexity selection:**
```xml
<thinking type="decision">
ОПЦИИ:
  1. minimal — Simple task (1-2 files, obvious solution)
  2. standard — Normal task (3-5 files, well-defined)
  3. complex — Complex task (6+ files, multiple approaches)
ВЫБОР: standard
</thinking>
```

### validation-framework

**Uses risk thinking перед risky validations:**
- Schema changes (breaking format)
- Deletion operations (data loss risk)
- Production deployments

---

## Best Practices

### ✅ DO

1. **Use thinking BEFORE structured output** - reasoning first, then JSON
2. **Be specific in ВЫВОДЫ/ОБОСНОВАНИЕ** - actionable conclusions
3. **Document trade-offs explicitly** - показать что alternatives рассмотрены
4. **Include mitigation for HIGH risks** - не игнорировать critical risks
5. **Use appropriate template** - см. decision tree выше
6. **Keep thinking concise** - достаточно для decision, не more

### ❌ DON'T

1. **Skip thinking for complex tasks** - даже если кажется obvious
2. **Output thinking to user** - it's internal reasoning process
3. **Mix templates** - используйте один per reasoning session
4. **Ignore high-impact risks** - всегда нужна mitigation
5. **Skip ROLLBACK for risky ops** - всегда нужен plan отката
6. **Over-think simple tasks** - if obvious, thinking optional

---

## Version History

### v2.1.0 (2026-01-25)

- ✅ Centralized templates → `@shared:THINKING-PATTERNS.md`
- ✅ Added 6 complete examples (PRD analysis, bug root cause, library choice, architecture, DB migration, API breaking)
- ✅ Enhanced integration guide (structured-planning, adaptive-workflow, validation-framework)
- ✅ Reduced duplication: Templates specification moved to _shared/

### v2.0.0

- ✅ Consolidated to 3 universal templates (was 8 specialized)
- ✅ Simplified structure (analysis, decision, risk)
- ✅ Added decision tree для template selection

---

**Author:** Claude Code Team
**License:** MIT
**Support:** См. @shared:THINKING-PATTERNS.md для полной документации templates
