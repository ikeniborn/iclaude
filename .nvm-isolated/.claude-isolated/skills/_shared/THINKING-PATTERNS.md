# Thinking Patterns Reference

**Version:** 1.0.0
**Last Updated:** 2026-01-25
**Purpose:** Централизованные thinking templates для structured reasoning во всех skills

---

## Overview

Этот документ содержит 3 универсальных thinking templates, используемых для COT (Chain of Thought) reasoning перед принятием решений, планированием и выполнением операций.

**Ключевые принципы:**
- ✅ Thinking - внутренний процесс (НЕ выводится пользователю)
- ✅ 3 универсальных template вместо 8+ specialized
- ✅ XML-based format для structured reasoning
- ✅ Используется ДО генерации structured output

**Кому это нужно:**
- thinking-framework skill (primary owner)
- structured-planning skill (для PHASE 1)
- adaptive-workflow skill (для complexity analysis)
- validation-framework skill (для risk assessment)
- Все skills, требующие decision-making

---

## Template 1: Analysis Thinking

### analysis

### When to Use

- Начало задачи, анализ требований
- Проверка соответствия PRD
- Root cause analysis при debugging
- Перед созданием task plan
- Когда нужно понять "что нужно сделать"

### Structure

```xml
<thinking type="analysis">
ЗАДАЧА: [Краткое описание задачи из user request]
КОНТЕКСТ: [Текущее состояние проекта/кодовой базы]
КОМПОНЕНТЫ: [Затрагиваемые файлы/модули/системы]
PRD: [Релевантные секции PRD, если есть]
ACCEPTANCE CRITERIA: [Критерии успеха задачи]
ВЫВОДЫ: [Что нужно сделать для выполнения задачи]
</thinking>
```

### Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| ЗАДАЧА | ✅ Yes | User request в своих словах (1-2 предложения) |
| КОНТЕКСТ | ✅ Yes | Текущее состояние: какие файлы существуют, что уже реализовано |
| КОМПОНЕНТЫ | ✅ Yes | Список файлов/модулей, которые будут затронуты |
| PRD | ⚠️ Optional | Релевантные секции PRD (если PRD существует) |
| ACCEPTANCE CRITERIA | ✅ Yes | Как понять, что задача выполнена успешно (2-4 пункта) |
| ВЫВОДЫ | ✅ Yes | Actionable выводы: что конкретно нужно сделать |

### Reference Examples

**Example 1: Simple Feature**
```xml
<thinking type="analysis">
ЗАДАЧА: Добавить метод calculate_total в BudgetService для суммирования amounts из budget facts.

КОНТЕКСТ: Проект использует FastAPI + SQLAlchemy. BudgetService уже существует в app/services/budget_service.py и содержит методы get_by_id, create, update. Budget model имеет поле amounts (List[Decimal]).

КОМПОНЕНТЫ:
- app/services/budget_service.py (modify - добавить метод)
- tests/test_budget_service.py (modify - добавить тесты)

PRD: Не применимо (нет PRD для этой задачи)

ACCEPTANCE CRITERIA:
- Метод calculate_total принимает budget_id и возвращает Decimal
- Корректно суммирует amounts (включая negative values)
- Тесты покрывают edge cases (empty array, null values)
- Документация метода добавлена

ВЫВОДЫ: Добавить метод calculate_total с обработкой edge cases. Написать unit-тесты для валидации суммирования с различными сценариями (normal, empty, null).
</thinking>
```

**Example 2: Bug Fix with Root Cause**
```xml
<thinking type="analysis">
ЗАДАЧА: Исправить NullPointerException в OrderValidator при валидации заказа с пустым списком items.

КОНТЕКСТ: OrderValidator.validate() вызывает order.items.forEach() без проверки на null. Ошибка возникает когда создаётся заказ без items через API endpoint POST /orders.

КОМПОНЕНТЫ:
- app/validators/order_validator.py (modify - добавить null check)
- tests/test_order_validator.py (modify - добавить test case)

PRD: Секция "Order Validation Rules" указывает: "Orders without items should be rejected with 400 error"

ACCEPTANCE CRITERIA:
- Null check перед обращением к order.items
- Возврат ValidationError с понятным сообщением
- Тест для edge case (order with items=null)
- Тест для edge case (order with items=[])

ВЫВОДЫ: Добавить early return в validate() с проверкой order.items is None. Выбросить ValidationError("Order must contain at least one item"). Обновить тесты.
</thinking>
```

**Example 3: PRD Alignment Check**
```xml
<thinking type="analysis">
ЗАДАЧА: Реализовать transaction filtering endpoint согласно PRD секции "Transaction Management - Filtering".

КОНТЕКСТ: Существуют endpoints GET /transactions (all) и GET /transactions/{id} (single). PRD требует добавить query parameters для filtering: date_from, date_to, category, amount_min, amount_max.

КОМПОНЕНТЫ:
- app/api/transactions.py (modify - добавить query params)
- app/services/transaction_service.py (modify - добавить filter logic)
- tests/test_transactions_api.py (modify - добавить integration tests)

PRD:
- Секция 4.2 "Transaction Filtering": Query params должны быть optional, AND logic для multiple filters
- Секция 4.3 "Pagination": Results должны быть paginated (limit 50 по умолчанию)
- Секция 6.1 "Error Handling": Invalid date format → 400 error с понятным message

ACCEPTANCE CRITERIA:
- Все 5 query params работают (date_from, date_to, category, amount_min, amount_max)
- Комбинация filters использует AND logic (соответствует PRD)
- Pagination добавлена (limit/offset)
- Error handling для invalid inputs
- Integration tests для всех filter combinations

ВЫВОДЫ: Добавить 5 optional query parameters в endpoint. Реализовать filter logic в TransactionService.filter() с AND logic. Добавить pagination (limit 50 default). Валидация date format и error handling.
</thinking>
```

---

## Template 2: Decision Thinking

### When to Use

- Выбор между несколькими вариантами решения
- Выбор библиотеки/фреймворка
- Technical decision (архитектура, паттерны)
- Trade-off analysis
- Когда несколько подходов возможны

### Structure

```xml
<thinking type="decision">
КОНТЕКСТ: [Ситуация, требующая выбора]
ОПЦИИ:
  1. [Вариант 1] — Плюсы: [...] Минусы: [...]
  2. [Вариант 2] — Плюсы: [...] Минусы: [...]
  3. [Вариант 3] — Плюсы: [...] Минусы: [...] (опционально)
TRADE-OFFS: [Что жертвуем при выборе каждого варианта]
ВЫБОР: [Вариант N]
ОБОСНОВАНИЕ: [Почему именно этот вариант]
</thinking>
```

### Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| КОНТЕКСТ | ✅ Yes | Ситуация/проблема, требующая решения |
| ОПЦИИ | ✅ Yes | Минимум 2 варианта с плюсами/минусами каждого |
| TRADE-OFFS | ✅ Yes | Что теряем при каждом выборе (явные компромиссы) |
| ВЫБОР | ✅ Yes | Номер выбранного варианта (1, 2 или 3) |
| ОБОСНОВАНИЕ | ✅ Yes | Почему этот вариант лучше других в данном контексте |

### Reference Examples

**Example 1: Library Choice**
```xml
<thinking type="decision">
КОНТЕКСТ: Нужно выбрать library для date/time manipulation в Python FastAPI проекте. Требуется: timezone support, date arithmetic, parsing ISO 8601.

ОПЦИИ:
  1. datetime (stdlib) — Плюсы: No dependencies, fast, built-in. Минусы: Complex timezone handling, verbose API
  2. arrow — Плюсы: Human-friendly API, excellent timezone support. Минусы: External dependency, slightly slower
  3. pendulum — Плюсы: Drop-in replacement for datetime, better timezone handling than stdlib. Минусы: Larger dependency, less popular

TRADE-OFFS:
  - datetime: Простота (no deps) vs Удобство (verbose API)
  - arrow: Удобство API vs Зависимость (external package)
  - pendulum: Лучший timezone support vs Популярность (smaller community)

ВЫБОР: Вариант 1 (datetime)

ОБОСНОВАНИЕ: Проект уже использует stdlib везде для консистентности. Timezone handling нужен только для UTC conversion (простой use case). Избегаем дополнительных dependencies без явной выгоды.
</thinking>
```

**Example 2: Architecture Pattern**
```xml
<thinking type="decision">
КОНТЕКСТ: Рефакторинг order validation logic. Сейчас вся логика в одном методе OrderService.validate() (~200 lines). Нужно улучшить testability и maintainability.

ОПЦИИ:
  1. Extract to OrderValidator class (separate class) — Плюсы: Clear SRP, easy to test, reusable. Минусы: One more file, potential over-engineering for simple validations
  2. Split into smaller methods in OrderService — Плюсы: No new files, simpler refactor. Минусы: OrderService becomes god class, mixed responsibilities
  3. Chain of Responsibility pattern (multiple validators) — Плюсы: Extensible, each validator independent. Минусы: Over-engineered for current needs, added complexity

TRADE-OFFS:
  - Вариант 1: Простота (one file) vs Separation of Concerns (clear responsibility)
  - Вариант 2: Minimal changes vs Long-term maintainability
  - Вариант 3: Extensibility vs Complexity (YAGNI)

ВЫБОР: Вариант 1 (OrderValidator class)

ОБОСНОВАНИЕ: Validation - отдельная ответственность, заслуживает отдельного класса. Улучшает testability (можно тестировать validation независимо от service logic). Не over-engineering т.к. validation logic уже достаточно большая (200 lines). Chain of Responsibility (вариант 3) - YAGNI для текущих требований.
</thinking>
```

**Example 3: Error Handling Strategy**
```xml
<thinking type="decision">
КОНТЕКСТ: API endpoint GET /transactions/{id} должен обрабатывать случай "transaction not found". Нужно выбрать strategy для error response.

ОПЦИИ:
  1. Return 404 with error body — Плюсы: RESTful standard, clear semantics. Минусы: Client должен handle 404 status code
  2. Return 200 with null data — Плюсы: No error handling needed on client. Минусы: Не RESTful, client не знает причину (not found vs error)
  3. Return 200 with error field in body — Плюсы: Client всегда получает 200, легко обрабатывать. Минусы: Противоречит HTTP semantics, запутывает API contract

TRADE-OFFS:
  - Вариант 1: RESTful standards vs Client complexity
  - Вариант 2: Client simplicity vs API clarity
  - Вариант 3: Easy client handling vs HTTP semantics violation

ВЫБОР: Вариант 1 (404 with error body)

ОБОСНОВАНИЕ: RESTful API должен использовать HTTP status codes правильно. 404 - standard для "resource not found". Client libraries (axios, fetch) легко обрабатывают error codes. Варианты 2 и 3 нарушают HTTP semantics и создают confusion для API consumers.
</thinking>
```

---

## Template 3: Risk Thinking

### risk

### When to Use

- Перед опасными операциями (database migration, refactoring)
- Breaking changes
- Operations с potential data loss
- Deployments в production
- Когда нужен rollback plan

### Structure

```xml
<thinking type="risk">
ОПЕРАЦИЯ: [Что планируем сделать]
РИСКИ:
  1. [Риск 1] — Вероятность: [High/Medium/Low] Impact: [High/Medium/Low]
     Митигация: [Как снизить риск]
  2. [Риск 2] — Вероятность: [...] Impact: [...]
     Митигация: [...]
  3. [Риск 3] — Вероятность: [...] Impact: [...] (опционально)
     Митигация: [...]
FALLBACK: [Что делать если операция не получится]
ROLLBACK: [Как откатить изменения]
</thinking>
```

### Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| ОПЕРАЦИЯ | ✅ Yes | Описание операции, которую планируем выполнить |
| РИСКИ | ✅ Yes | Минимум 1 риск с вероятностью, impact и митигацией |
| FALLBACK | ✅ Yes | Plan B если операция fails |
| ROLLBACK | ✅ Yes | Как откатить изменения (техническая процедура) |

### Risk Matrix

| Вероятность | Impact | Priority | Action |
|-------------|--------|----------|--------|
| High | High | **CRITICAL** | Must mitigate BEFORE operation |
| High | Medium | **HIGH** | Mitigate or prepare fallback |
| Medium | High | **HIGH** | Mitigate or prepare fallback |
| Medium | Medium | **MEDIUM** | Document and monitor |
| Low | High | **MEDIUM** | Document and monitor |
| Low | Low | **LOW** | Accept risk, no action needed |

### Reference Examples

**Example 1: Database Migration**
```xml
<thinking type="risk">
ОПЕРАЦИЯ: Database migration - добавить column "email_verified" (boolean NOT NULL) в users table с 50K rows. Production database.

РИСКИ:
  1. Migration timeout на большой таблице — Вероятность: Medium Impact: High
     Митигация: Добавить column как nullable сначала, заполнить default values в background job, затем изменить на NOT NULL в отдельной migration

  2. Application downtime во время migration — Вероятность: High Impact: Medium
     Митигация: Use zero-downtime migration strategy: ADD column (nullable) → Deploy code supporting both states → Backfill data → Make NOT NULL

  3. Data loss если migration fails mid-process — Вероятность: Low Impact: High
     Митигация: Full database backup перед migration. Test migration на staging copy first.

FALLBACK: Если migration fails - оставить column как nullable, заполнить default value (false) для существующих rows, продолжить работу.

ROLLBACK:
1. Revert migration (DROP column email_verified)
2. Deploy previous code version
3. Restore from backup если data corruption
Estimated rollback time: 5-10 minutes
</thinking>
```

**Example 2: Major Refactoring**
```xml
<thinking type="risk">
ОПЕРАЦИЯ: Refactor authentication system с session-based на JWT tokens. Breaking change для всех API clients.

РИСКИ:
  1. Existing sessions станут invalid — Вероятность: High Impact: High
     Митигация: Support оба метода (session + JWT) в transition period (2 weeks). Notify users заранее.

  2. Security vulnerability в JWT implementation — Вероятность: Medium Impact: High
     Митигация: Use proven library (PyJWT), follow OWASP guidelines, security audit перед deploy

  3. Mobile apps перестанут работать — Вероятность: High Impact: High
     Митигация: Version API (v1 = sessions, v2 = JWT). Deprecated v1 через 3 months.

FALLBACK: Если JWT implementation имеет issues - rollback к session-based auth, keep transition период открытым дольше.

ROLLBACK:
1. Re-deploy previous version с session-based auth
2. Re-enable session middleware
3. Invalidate все JWT tokens
4. Notify users через API deprecation notice
Estimated rollback time: 15-20 minutes
</thinking>
```

**Example 3: Production Deployment**
```xml
<thinking type="risk">
ОПЕРАЦИЯ: Deploy version 2.0.0 с breaking API changes (authentication + transaction response format changes) в production.

РИСКИ:
  1. API clients (mobile apps) перестанут работать — Вероятность: High Impact: High
     Митигация: API versioning (/api/v1 остаётся, /api/v2 новый format). Deprecated v1 через 6 months.

  2. Database migration fails на production data — Вероятность: Medium Impact: High
     Митигация: Test migration на production snapshot (anonymized). Automated rollback если migration timeout.

  3. Performance degradation с new authentication — Вероятность: Low Impact: Medium
     Митигация: Load testing на staging. Monitor response times first 24h. Auto-rollback если p95 latency > 500ms.

FALLBACK: Blue-green deployment - keep v1.x running parallel, route traffic gradually. Full rollback если critical issues.

ROLLBACK:
1. Switch traffic back к v1.x (blue-green instant switch)
2. Revert database migrations (automated script)
3. Keep v1.x running до фикса v2.0
Estimated rollback time: < 5 minutes (instant traffic switch)
</thinking>
```

---

## When to Use Which Template

### Decision Tree

```
Start
  │
  ├─ Начало задачи / Анализ требований?
  │  └─ YES → Analysis Thinking
  │
  ├─ Несколько вариантов решения?
  │  └─ YES → Decision Thinking
  │
  ├─ Опасная операция / Breaking change?
  │  └─ YES → Risk Thinking
  │
  └─ Простая однозначная задача?
     └─ YES → Thinking OPTIONAL (skip если obvious)
```

### Situation to Template Mapping

| Situation | Template | Why |
|-----------|----------|-----|
| User request: "Add feature X" | **Analysis** | Понять требования, определить acceptance criteria |
| Choice between libraries A и B | **Decision** | Сравнить варианты, выбрать лучший |
| Refactor critical module | **Risk** | Breaking change, нужен rollback plan |
| Bug fix: "Error in function Y" | **Analysis** | Root cause analysis |
| "Which pattern to use?" | **Decision** | Technical decision between approaches |
| Database migration | **Risk** | Potential data loss, need mitigation |
| PRD implementation | **Analysis** | Check alignment с PRD |
| Несколько API designs | **Decision** | Compare trade-offs |
| Production deployment | **Risk** | High impact operation |

---

## Integration with Skills

### thinking-framework Skill

**Primary owner** этого файла. Предоставляет:
- Templates в `./templates/*.xml`
- Usage guidelines
- Integration examples

**Reference:**
```
@skill:thinking-framework → @template:analysis
@skill:thinking-framework → @template:decision
@skill:thinking-framework → @template:risk
```

### structured-planning Skill

**Uses Analysis Thinking** в PHASE 1:
1. Analysis Thinking для понимания задачи
2. Генерация task_plan на основе ВЫВОДЫ
3. Decision Thinking если несколько подходов

### adaptive-workflow Skill

**Uses Decision Thinking** для выбора complexity level:
```xml
<thinking type="decision">
ОПЦИИ:
  1. minimal — для простых задач
  2. standard — для обычных задач
  3. complex — для сложных многофазных задач
ВЫБОР: ...
</thinking>
```

### validation-framework Skill

**Uses Risk Thinking** перед risky validations:
- Deletion operations
- Schema changes
- Breaking format changes

---

## Best Practices

### ✅ DO

1. **Use thinking BEFORE structured output** - reasoning → decision → output
2. **Be concise but complete** - достаточно деталей для understanding, не more
3. **Include actionable conclusions** - ВЫВОДЫ должны быть executable
4. **Use appropriate template** - см. Decision Tree выше
5. **Document trade-offs explicitly** - показать что рассмотрели alternatives
6. **Include mitigation for HIGH risks** - не игнорировать critical risks
7. **Keep thinking internal** - НЕ выводить пользователю (внутренний процесс)

### ❌ DON'T

1. **Skip thinking for complex tasks** - даже если кажется obvious
2. **Mix templates** - используйте один template на reasoning session
3. **Include thinking in output** - user видит только structured result
4. **Ignore high-probability risks** - всегда нужна mitigation
5. **Skip ROLLBACK for risky operations** - всегда нужен план отката
6. **Over-think simple tasks** - если task obvious, thinking optional
7. **Repeat thinking multiple times** - one thinking session per decision

---

## Nesting Rules

### Can I nest thinkings?

**Yes**, но редко нужно.

**Valid nesting:**
```xml
<thinking type="analysis">
ЗАДАЧА: Implement feature X
КОНТЕКСТ: ...

  <thinking type="decision">
  КОНТЕКСТ: Need to choose library
  ОПЦИИ: ...
  ВЫБОР: Library A
  </thinking>

ВЫВОДЫ: Use Library A, implement feature with ...
</thinking>
```

**When to nest:**
- Decision needed WITHIN analysis
- Risk assessment WITHIN decision

**When NOT to nest:**
- Sequential thinkings (just use separate blocks)
- Unrelated decisions (separate thinking blocks)

**Recommendation:** Avoid nesting unless clearly nested dependency. Prefer sequential thinking blocks for clarity.

---

## References

### Internal Resources

- **thinking-framework SKILL.md:** `@skill:thinking-framework`
- **Templates:** `@skill:thinking-framework/templates/*.xml`
- **Examples:** `@skill:thinking-framework/examples/*.md`

### Integration in Other Skills

- **structured-planning:** Uses analysis + decision
- **adaptive-workflow:** Uses decision для complexity
- **validation-framework:** Uses risk для dangerous validations
- **error-handling:** Uses analysis для root cause

---

## Version History

### v1.0.0 (2026-01-25)

- ✅ Initial release
- ✅ 3 universal templates (analysis, decision, risk)
- ✅ 9 reference examples (3 per template)
- ✅ Decision tree для template selection
- ✅ Integration guidelines
- ✅ Best practices
- ✅ Nesting rules

---

**Автор:** Claude Code Team
**License:** MIT
**Support:** См. thinking-framework/SKILL.md для вопросов по usage
