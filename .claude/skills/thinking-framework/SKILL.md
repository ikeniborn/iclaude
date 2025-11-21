---
name: Thinking Framework
description: Стандартизированные thinking блоки для структурированного reasoning перед критическими решениями
version: 1.0.0
author: Claude Code Team
tags: [thinking, reasoning, decision-making, analysis, planning]
dependencies: []
---

# Thinking Framework

Автоматизация структурированного reasoning через стандартизированные thinking блоки. Этот скил обеспечивает консистентный подход к анализу задач, принятию технических решений и оценке рисков перед выполнением критических действий.

## Когда использовать этот скил

Используй этот скил когда нужно:
- Проанализировать задачу перед планированием
- Принять техническое решение между альтернативами
- Оценить риски и компромиссы (trade-offs)
- Обосновать выбор подхода
- Выполнить root cause analysis
- Сравнить варианты решения

Скил автоматически вызывается при:
- Actions помеченных `requires_thinking="true"`
- Actions с `validation="critical"`
- Перед началом каждой фазы в workflow
- При выборе между альтернативными подходами
- При принятии важных технических решений

## Контекст проекта

### Философия Thinking Framework

**Принципы:**
- **Explicit reasoning:** Thinking делает процесс принятия решений прозрачным
- **Structured analysis:** Единый формат для всех типов reasoning
- **Risk-aware:** Всегда учитывать "что может пойти не так"
- **Evidence-based:** Решения основаны на analysis, не assumptions
- **Validation-ready:** Thinking включает план проверки результата

### Когда thinking ОБЯЗАТЕЛЕН

**CRITICAL** (FATAL если пропущен):
- Перед началом каждой фазы workflow
- Перед actions с `requires_thinking="true"`
- Перед actions с `validation="critical"`
- При конфликте с PRD
- При выборе между architectural approaches

**RECOMMENDED** (желательно):
- При выборе библиотеки/фреймворка
- При рефакторинге архитектуры
- При работе с legacy code
- При optimization decisions

### Структура thinking блока

```xml
<thinking>
[СЕКЦИЯ 1: Контекст/Анализ]
[СЕКЦИЯ 2: Опции/Варианты]
[СЕКЦИЯ 3: Выбор/Решение]
[СЕКЦИЯ 4: Риски]
[СЕКЦИЯ 5: Проверка]
</thinking>
```

## Шаблоны

### Шаблон 1: PRD Analysis Thinking

**Когда использовать:** Перед планированием задачи, для проверки alignment с PRD.

```xml
<thinking>
ЗАДАЧА: [краткое описание от пользователя]
PRD СЕКЦИИ: [какие секции релевантны]
ACCEPTANCE CRITERIA: [идентифицировать из задачи]
ALIGNMENT: [проверить соответствие задачи PRD]
</thinking>
```

**Пример:**
```xml
<thinking>
ЗАДАЧА: Добавить метод calculate_total в BudgetService
PRD СЕКЦИИ: FR-042 (Расчет общей суммы бюджетных фактов)
ACCEPTANCE CRITERIA:
- Метод принимает list[BudgetFact]
- Возвращает Decimal sum
- Обрабатывает пустой список (returns 0)
ALIGNMENT: Полностью соответствует FR-042, нет конфликтов
</thinking>
```

### Шаблон 2: Root Cause Analysis Thinking

**Когда использовать:** При анализе текущего состояния кодовой базы, определении что нужно изменить.

```xml
<thinking>
КОНТЕКСТ: [текущее состояние кодовой базы]
ROOT CAUSES: [что нужно изменить]
КОМПОНЕНТЫ: [какие файлы/модули затронуты]
СЛОЖНОСТЬ: [оценка объема работы]
</thinking>
```

**Пример:**
```xml
<thinking>
КОНТЕКСТ: BudgetService содержит inline подсчет сумм в нескольких методах
ROOT CAUSES: Дублирование логики суммирования, нарушение DRY
КОМПОНЕНТЫ:
- backend/app/services/budget_service.py (основной)
- backend/app/api/v1/endpoints/budgets.py (использует сервис)
СЛОЖНОСТЬ: Низкая - создание одного метода, рефакторинг 2-3 мест
</thinking>
```

### Шаблон 3: Technical Decision Thinking

**Когда использовать:** При выборе между техническими альтернативами, архитектурными решениями.

```xml
<thinking>
КОНТЕКСТ: [текущая ситуация]
ЗАДАЧА: [что нужно сделать]
ОПЦИИ: [варианты с плюсами/минусами]
ВЫБОР: [вариант N] потому что [обоснование]
РИСКИ: [что может пойти не так]
ПРОВЕРКА: [как валидируем результат]
</thinking>
```

**Пример:**
```xml
<thinking>
КОНТЕКСТ: Нужно хранить user preferences для UI
ЗАДАЧА: Выбрать где хранить (database vs cache vs localStorage)

ОПЦИИ:
1. Database (PostgreSQL)
   + Постоянное хранение, доступно на всех устройствах
   - Дополнительные запросы к DB, latency

2. Redis cache
   + Быстрый доступ, меньше нагрузки на DB
   - Может быть evicted, нужна sync стратегия

3. localStorage (frontend)
   + Нет серверных запросов, instant
   - Только локально, не синхронизируется между устройствами

ВЫБОР: Database (PostgreSQL) потому что user preferences должны быть
доступны на всех устройствах пользователя (laptop, mobile, etc).
Latency не критична для preferences (не real-time feature).

РИСКИ:
- Может увеличить load на DB если много пользователей
- Нужно правильно индексировать user_id

ПРОВЕРКА:
- Query performance test (должен быть < 50ms)
- Проверить что preferences синхронизируются между устройствами
</thinking>
```

### Шаблон 4: Solution Comparison Thinking

**Когда использовать:** При сравнении нескольких вариантов решения с детальным trade-off analysis.

```xml
<thinking>
ПРОБЛЕМА: [что решаем]

ВАРИАНТ 1: [название]
Плюсы: [список]
Минусы: [список]
Сложность: [оценка]

ВАРИАНТ 2: [название]
Плюсы: [список]
Минусы: [список]
Сложность: [оценка]

ВАРИАНТ 3: [название]
Плюсы: [список]
Минусы: [список]
Сложность: [оценка]

ВЫБОР: [вариант N]
ОБОСНОВАНИЕ: [почему именно этот]
TRADE-OFFS: [что жертвуем]
МИТИГАЦИЯ: [как минимизировать минусы]
</thinking>
```

**Пример:**
```xml
<thinking>
ПРОБЛЕМА: Нужно валидировать Order объекты, сейчас валидация размазана по коду

ВАРИАНТ 1: Inline validation в OrderService
Плюсы: Просто, нет дополнительных классов
Минусы: Нарушает SRP, сложно тестировать, дублирование
Сложность: Низкая (1 час)

ВАРИАНТ 2: Отдельный OrderValidator класс
Плюсы: SRP, легко тестировать, переиспользуемый
Минусы: Дополнительный класс, нужно передавать в сервис
Сложность: Средняя (2-3 часа)

ВАРИАНТ 3: Pydantic models с built-in validation
Плюсы: Декларативная валидация, type safety, JSON schema
Минусы: Зависимость от Pydantic, learning curve для команды
Сложность: Высокая (4-5 часов + рефакторинг моделей)

ВЫБОР: Вариант 2 (OrderValidator класс)
ОБОСНОВАНИЕ: Баланс между простотой и maintainability. Pydantic
overengineering для этой задачи, а inline validation нарушает SRP.

TRADE-OFFS: Дополнительный класс (+1 файл), но выигрываем в тестируемости

МИТИГАЦИЯ: Использовать dependency injection для передачи validator в сервис
</thinking>
```

### Шаблон 5: Risk Assessment Thinking

**Когда использовать:** Перед рискованными операциями (refactoring, migration, breaking changes).

```xml
<thinking>
ОПЕРАЦИЯ: [что планируем делать]

РИСКИ:
1. [риск 1]: [вероятность] [impact]
   Митигация: [как предотвратить/минимизировать]

2. [риск 2]: [вероятность] [impact]
   Митигация: [как предотвратить/минимизировать]

FALLBACK PLAN: [что делать если пойдет не так]
ROLLBACK STRATEGY: [как откатить изменения]
TESTING STRATEGY: [как тестируем перед production]
</thinking>
```

**Пример:**
```xml
<thinking>
ОПЕРАЦИЯ: Рефакторинг OrderService - выделение OrderValidator

РИСКИ:
1. Можем сломать существующую валидацию при переносе логики
   Вероятность: Средняя | Impact: Высокий (orders validation critical)
   Митигация: Переносить методы один за другим, syntax check после каждого

2. Циклические импорты если OrderValidator импортирует Order models
   Вероятность: Низкая | Impact: Средний (ломает билд)
   Митигация: Использовать TYPE_CHECKING для импортов типов

3. Existing tests могут fail после рефакторинга
   Вероятность: Средняя | Impact: Средний (нужно обновить tests)
   Митигация: Запустить tests после рефакторинга, обновить mocks

FALLBACK PLAN: Если валидация сломается - откатить commit, исправить, retry
ROLLBACK STRATEGY: Git revert commit, deploy предыдущей версии
TESTING STRATEGY:
- Syntax checks для всех измененных файлов
- Manual testing: создание order, валидация invalid data
</thinking>
```

## Проверочный чеклист

После создания thinking блока проверь:

**Структура:**
- [ ] Thinking блок начинается с `<thinking>` и заканчивается `</thinking>`
- [ ] Секции четко разделены и labeled
- [ ] Каждая секция содержит конкретную информацию (не placeholder)

**Полнота:**
- [ ] КОНТЕКСТ/АНАЛИЗ: Описывает current state
- [ ] ОПЦИИ (если применимо): Минимум 2 варианта с pros/cons
- [ ] ВЫБОР: Четко указан выбранный вариант
- [ ] ОБОСНОВАНИЕ: Объясняет "почему именно этот вариант"
- [ ] РИСКИ: Идентифицированы главные риски (минимум 1)
- [ ] ПРОВЕРКА: План validation результата

**Качество:**
- [ ] Reasoning логичный и последовательный
- [ ] Решение основано на анализе, не assumptions
- [ ] Trade-offs явно указаны
- [ ] Риски реалистичные (не "все сломается")

---

## Phase-Based Thinking

Специальные thinking шаблоны для phase-based workflow. Эти шаблоны используются при работе с multi-phase задачами.

### Когда использовать

Используй phase-based thinking когда:
- Разбиваешь задачу на фазы (task decomposition)
- Анализируешь phase file перед выполнением
- Планируешь конкретную фазу
- Оцениваешь готовность к следующей фазе

### Шаблон 6: Decomposition Thinking

**Когда использовать:** При разбиении задачи на 2-5 логических фаз (task-decomposition skill).

```xml
<thinking>
ЗАДАЧА: [краткое описание задачи]
СЛОЖНОСТЬ: [оценка: simple/medium/complex]

ДЕКОМПОЗИЦИЯ:
Почему многофазная: [обоснование разбиения]
Количество фаз: [2-5]
Критерий разделения: [по функциональности / по компонентам / по зависимостям]

ФАЗЫ:
Phase 1: [название] - [цель]
  Почему первой: [обоснование порядка]
  Зависимости: [от чего зависит]

Phase 2: [название] - [цель]
  Почему после Phase 1: [логическая связь]
  Зависимости: [что требует Phase 1]

[...дополнительные фазы]

ACCEPTANCE CRITERIA MAPPING:
AC1 → Phase [N]
AC2 → Phase [N]
[...]

РИСКИ:
- [риск неправильного разделения]
- [риск dependency проблем между фазами]

ВАЛИДАЦИЯ:
- Каждая фаза логически завершена (имеет commit-able state)
- Фазы минимально связаны (low coupling)
- Acceptance criteria полностью покрыты
</thinking>
```

**Пример:**
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

### Шаблон 7: Phase Analysis Thinking

**Когда использовать:** Перед выполнением конкретной фазы из готового phase file (phase-execution skill).

```xml
<thinking>
PHASE: [Phase N: название]
ЦЕЛЬ: [phase goal из phase_metadata]
КОНТЕКСТ ВЕТКИ: [branch_name, предыдущие изменения]

АНАЛИЗ ГОТОВНОСТИ:
Dependencies resolved: [проверка context.dependencies]
Previous phase completed: [если N > 1, проверить previous_changes_summary]
Branch context valid: [правильная ветка, нет uncommitted changes]

EXECUTION PLAN:
Шаг 1: [описание]
  Сложность: [low/medium/high]
  Риски: [специфичные риски этого шага]

Шаг 2: [описание]
  Сложность: [low/medium/high]
  Риски: [специфичные риски этого шага]

[...дополнительные шаги]

COMPLETION CRITERIA:
- [критерий 1 из phase_metadata.completion_criteria]
- [критерий 2]
- [...]

COMMIT STRATEGY:
Type: [feat/fix/refactor]
Summary: [краткое описание изменений]
Files: [список файлов, которые изменим]

РИСКИ PHASE:
- [главные риски выполнения]
- [возможные проблемы]

VALIDATION PLAN:
- [как проверим что phase completed успешно]
</thinking>
```

**Пример:**
```xml
<thinking>
PHASE: Phase 2: Backend API + JWT Logic
ЦЕЛЬ: Реализовать login, refresh, logout endpoints с JWT authentication
КОНТЕКСТ ВЕТКИ: feature/auth-system, Phase 1 completed (database models created)

АНАЛИЗ ГОТОВНОСТИ:
Dependencies resolved: ✓ Phase 1 completed (User, RefreshToken models exist)
Previous phase completed: ✓ Migrations applied, tables created
Branch context valid: ✓ На ветке feature/auth-system, нет uncommitted changes

EXECUTION PLAN:
Шаг 1: Создать JWTService для генерации/валидации токенов
  Сложность: Medium
  Риски: Неправильная конфигурация SECRET_KEY, слабый algorithm

Шаг 2: Реализовать POST /auth/login endpoint
  Сложность: Medium
  Риски: SQL injection если неправильный query, plaintext password comparison

Шаг 3: Реализовать POST /auth/refresh endpoint
  Сложность: Low
  Риски: Refresh token replay attacks

Шаг 4: Реализовать POST /auth/logout endpoint
  Сложность: Low
  Риски: Logout может не invalidate token на клиенте

COMPLETION CRITERIA:
- POST /auth/login возвращает access_token и refresh_token
- POST /auth/refresh генерирует новый access_token
- POST /auth/logout invalidates refresh_token
- JWT tokens валидируются через middleware

COMMIT STRATEGY:
Type: feat
Summary: add JWT authentication endpoints
Files:
- backend/app/services/jwt_service.py (create)
- backend/app/api/v1/endpoints/auth.py (create)
- backend/app/core/security.py (update)

РИСКИ PHASE:
- JWT SECRET_KEY может быть hardcoded (security vulnerability)
  → Митигация: использовать environment variable
- Password hashing может быть слабым (bcrypt rounds < 12)
  → Митигация: использовать bcrypt с cost factor 12+

VALIDATION PLAN:
- Syntax check всех файлов
- Manual test: login с valid credentials (должен вернуть tokens)
- Manual test: refresh token (должен вернуть новый access token)
- Manual test: logout (refresh token должен стать invalid)
</thinking>
```

### Шаблон 8: Phase Planning Thinking

**Когда использовать:** При планировании конкретной фазы (создание phase file из master plan).

```xml
<thinking>
PHASE NUMBER: [N из M]
PHASE NAME: [название]
MASTER PLAN CONTEXT: [brief summary из master plan]

SCOPE DEFINITION:
Включает: [что входит в эту фазу]
НЕ включает: [что оставляем для других фаз]
Граница: [почему именно такой scope]

STEPS BREAKDOWN:
Нужно: [N-M steps] (phase-based workflow требует 3-7 steps per phase)
Принцип разделения: [по файлам / по функциям / по слоям]

Step 1: [описание]
  Результат: [что получим]
  Validation: [как проверим]

Step 2: [описание]
  Результат: [что получим]
  Validation: [как проверим]

[...дополнительные steps]

DEPENDENCIES:
От предыдущих фаз: [что требуется из Phase N-1]
Для следующих фаз: [что создаем для Phase N+1]

COMMIT MESSAGE:
Type: [feat/fix/refactor]
Summary: [краткое описание]
  Reasoning: [почему именно этот type]

RISKS:
- [риски специфичные для этой фазы]

VALIDATION:
- [как проверим что phase можно считать completed]
</thinking>
```

**Пример:**
```xml
<thinking>
PHASE NUMBER: 2 из 3
PHASE NAME: Backend API + JWT Logic
MASTER PLAN CONTEXT: Система аутентификации, Phase 1 создал database models

SCOPE DEFINITION:
Включает:
- JWT generation/validation logic
- Auth endpoints (login, refresh, logout)
- Middleware для JWT authentication

НЕ включает:
- Frontend integration (Phase 3)
- Password reset (будущая задача)
- OAuth2 providers (будущая задача)

Граница: Backend API полностью работает и testable, но frontend еще не интегрирован

STEPS BREAKDOWN:
Нужно: 5 steps (оптимально для этой фазы)
Принцип разделения: По функциональности (service → endpoints → middleware → tests)

Step 1: Создать JWTService с методами generate_token(), validate_token()
  Результат: Класс JWTService в backend/app/services/jwt_service.py
  Validation: Unit tests для generate/validate

Step 2: Реализовать POST /auth/login endpoint
  Результат: Login endpoint в backend/app/api/v1/endpoints/auth.py
  Validation: curl test с valid credentials

Step 3: Реализовать POST /auth/refresh endpoint
  Результат: Refresh endpoint в том же файле
  Validation: curl test с valid refresh_token

Step 4: Реализовать POST /auth/logout endpoint
  Результат: Logout endpoint
  Validation: curl test, проверить что refresh_token invalidated

Step 5: Добавить JWT middleware для protected endpoints
  Результат: JWTMiddleware в backend/app/core/middleware.py
  Validation: curl protected endpoint без token (401), с valid token (200)

DEPENDENCIES:
От предыдущих фаз: User model, RefreshToken model (из Phase 1)
Для следующих фаз: Работающие auth endpoints для frontend integration (Phase 3)

COMMIT MESSAGE:
Type: feat
Summary: add JWT authentication endpoints
  Reasoning: Новая функциональность (auth system), не bug fix и не refactor

RISKS:
- JWTService может иметь security vulnerabilities (weak SECRET_KEY, wrong algorithm)
- Endpoints могут не обрабатывать edge cases (expired tokens, invalid credentials)
- Middleware может блокировать все requests если misconfigured

VALIDATION:
- Syntax check всех файлов (Python, no syntax errors)
- Manual test: full auth flow (login → access protected endpoint → refresh → logout)
- Check: все completion_criteria выполнены
</thinking>
```

---

## Связанные скилы

- **structured-planning**: использует thinking перед планированием
- **validation-framework**: reasoning о validation strategy
- **error-handling**: thinking при анализе ошибок
- **task-decomposition**: использует Decomposition Thinking (Шаблон 6)
- **phase-execution**: использует Phase Analysis Thinking (Шаблон 7)

## Примеры использования

### Пример 1: PRD Analysis перед планированием

**Контекст:** Пользователь просит "Добавить фильтр по дате в Orders API"

**Claude использует thinking-framework скил:**

```xml
<thinking>
ЗАДАЧА: Добавить фильтр по дате в Orders API (GET /orders)
PRD СЕКЦИИ: FR-055 (Orders Filtering), NFR-003 (API Performance)
ACCEPTANCE CRITERIA:
- Endpoint принимает date_from и date_to query parameters
- Фильтрует orders по created_at >= date_from AND created_at <= date_to
- Работает корректно с timezone (UTC)
- Performance: query должен быть < 200ms для 10K orders
ALIGNMENT: Полностью соответствует FR-055, требует index на created_at (NFR-003)
</thinking>
```

### Пример 2: Technical Decision при выборе библиотеки

**Контекст:** Нужно выбрать библиотеку для date parsing в Python API.

**Claude использует thinking-framework скил:**

```xml
<thinking>
КОНТЕКСТ: Python API получает dates в query params как strings, нужен parsing
ЗАДАЧА: Выбрать библиотеку для date parsing

ОПЦИИ:
1. datetime.strptime (stdlib)
   + Built-in, no dependencies
   + Simple API
   - Не парсит ISO 8601 with timezone auto
   - Нужен explicit format string

2. python-dateutil
   + Парсит множество форматов automatically
   + Хорошо обрабатывает timezones
   - External dependency (minor)
   - Может быть медленнее для strict formats

3. arrow
   + Удобный API, timezone-aware
   + Парсит ISO 8601, relative dates
   - Yet another dependency
   - Overkill для simple date parsing

ВЫБОР: python-dateutil потому что нужен robust parsing ISO 8601 с timezone,
а datetime.strptime требует explicit format (ломается на variations).
Arrow overkill для этой задачи.

РИСКИ:
- python-dateutil может parse ambiguous dates неправильно
- Performance impact если много requests

ПРОВЕРКА:
- Benchmark: parse 1000 ISO dates, должно быть < 100ms total
- Unit tests для edge cases (timezones, invalid formats)
</thinking>
```

## Часто задаваемые вопросы

**Q: Thinking обязателен перед каждым action?**

A: НЕТ! Только перед:
- Actions с `requires_thinking="true"` (ОБЯЗАТЕЛЬНО)
- Actions с `validation="critical"` (ОБЯЗАТЕЛЬНО)
- Началом каждой фазы (РЕКОМЕНДУЕТСЯ)
- Выбором между alternatives (РЕКОМЕНДУЕТСЯ)

**Q: Можно ли сократить thinking блок для простых решений?**

A: ДА, но все обязательные секции должны присутствовать. Для простых решений можно сокращать ОПЦИИ секцию (1-2 варианта) и РИСКИ (1-2 главных риска).

**Q: Что если нет альтернативных вариантов (только 1 очевидное решение)?**

A: Все равно используй thinking, но сфокусируйся на:
- КОНТЕКСТ: Почему именно это решение очевидно
- РИСКИ: Что может пойти не так
- ПРОВЕРКА: Как валидируем

**Q: Thinking выводится пользователю?**

A: НЕТ! Thinking - внутренний процесс reasoning Claude. Пользователь видит только результаты (план, код, solutions).

**Q: Как выбрать правильный шаблон thinking?**

A: По типу задачи:
- **PRD Analysis** - перед планированием, проверка alignment
- **Root Cause** - при анализе кодовой базы, определении изменений
- **Technical Decision** - выбор между 2-3 alternatives
- **Solution Comparison** - детальное сравнение 3+ вариантов
- **Risk Assessment** - перед рискованными операциями

**Q: Можно ли комбинировать шаблоны?**

A: ДА! Например:
```xml
<thinking>
# PRD Analysis
ЗАДАЧА: [...]
PRD СЕКЦИИ: [...]

# Technical Decision
ОПЦИИ: [...]
ВЫБОР: [...]

# Risk Assessment
РИСКИ: [...]
МИТИГАЦИЯ: [...]
</thinking>
```

**Q: Что если thinking привел к неправильному решению?**

A: Validation framework поймает ошибки при валидации результатов. Если validation FAILED:
1. Вернуться к thinking
2. Пересмотреть ОПЦИИ
3. Выбрать другой вариант
4. RETRY

**Q: Нужно ли документировать thinking в коде/commits?**

A: НЕТ! Thinking - процесс reasoning, не документация. В коде/commits документируй только:
- Финальное решение (commit message body)
- Trade-offs если критичны (code comments)
- Риски если остались (TODO/FIXME)

---

### Phase-Based Thinking FAQ

**Q: Какой thinking шаблон использовать при task decomposition?**

A: **Шаблон 6: Decomposition Thinking**. Этот шаблон специально разработан для разбиения задачи на 2-5 фаз с анализом dependencies и acceptance criteria mapping.

**Q: Thinking нужен перед каждой фазой или один раз при decomposition?**

A: **Оба случая:**
- **При decomposition:** Шаблон 6 (Decomposition Thinking) - один раз, разбивает всю задачу
- **Перед каждой фазой:** Шаблон 7 (Phase Analysis Thinking) - для каждой фазы, анализирует readiness

**Q: Что если при Phase Analysis обнаружилось что dependencies не resolved?**

A: STOP немедленно (BLOCKING)! Phase Analysis Thinking должен выявить это:

```xml
<thinking>
АНАЛИЗ ГОТОВНОСТИ:
Dependencies resolved: ✗ Phase 1 not completed (User model missing)
→ ACTION: STOP, завершить Phase 1 сначала
</thinking>
```

**Q: Decomposition Thinking требует thinking для КАЖДОЙ фазы отдельно?**

A: НЕТ! Decomposition Thinking делается ОДИН РАЗ для всей задачи:
- Определяет количество фаз (2-5)
- Описывает каждую фазу кратко (goal, dependencies)
- НЕ планирует детально каждую фазу (это делает Phase Planning Thinking)

**Q: В чем разница между Phase Analysis Thinking (Шаблон 7) и Phase Planning Thinking (Шаблон 8)?**

A:
- **Phase Analysis Thinking (Шаблон 7):** Используется перед ВЫПОЛНЕНИЕМ готового phase file. Анализирует readiness, проверяет dependencies, планирует execution.
- **Phase Planning Thinking (Шаблон 8):** Используется при СОЗДАНИИ phase file из master plan. Определяет scope, breakdown steps (3-7), commit message.

**Workflow:**
1. Decomposition Thinking (Шаблон 6) → создает master plan
2. Phase Planning Thinking (Шаблон 8) → создает phase-1.md, phase-2.md, ...
3. Phase Analysis Thinking (Шаблон 7) → перед выполнением каждого phase-N.md

**Q: Можно ли пропустить Decomposition Thinking если задача очевидно многофазная?**

A: НЕТ! Decomposition Thinking **обязателен** для phase-based workflow. Он:
- Обосновывает ПОЧЕМУ многофазная (не assumptions)
- Определяет правильное количество фаз (2-5, не 1 и не 10)
- Проверяет acceptance criteria mapping
- Идентифицирует cross-phase risks

**Q: Что если Decomposition Thinking показал что задача слишком простая (1 фаза)?**

A: Используй **task-lite-template** вместо phase-based workflow! Decomposition Thinking может заключить:

```xml
<thinking>
ДЕКОМПОЗИЦИЯ:
Почему многофазная: НЕ МНОГОФАЗНАЯ
  Все изменения в одном компоненте (OrderService)
  Нет dependencies между частями
  Выполняется за 1-2 часа
→ ВЫВОД: Используй task-lite-template, не phase-based
</thinking>
```

**Q: Phase Planning Thinking (Шаблон 8) - сколько steps должен определить?**

A: **3-7 steps per phase**. Это оптимальное количество:
- < 3 steps: фаза слишком мелкая, можно объединить с другой
- > 7 steps: фаза слишком большая, нужно разбить на 2 фазы

Decomposition Thinking должен следить чтобы phases были balanced.
