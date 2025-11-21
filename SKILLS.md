# Claude Code Skills Documentation

**Версия:** 1.0.0
**Дата:** 2025-11-20

Этот документ описывает все доступные Claude Code Skills для проекта и предоставляет quick reference guide.

---

## Содержание

1. [Что такое Skills?](#что-такое-skills)
2. [Universal Skills](#universal-skills-применимы-к-любым-проектам)
3. [Project-Specific Skills](#project-specific-skills-для-init_claude)
4. [Quick Reference](#quick-reference)
5. [Зависимости между Skills](#зависимости-между-skills)
6. [Примеры комбинированного использования](#примеры-комбинированного-использования)

---

## Что такое Skills?

**Claude Code Skills** - это специализированные модули с domain expertise для автоматизации типовых задач. Вместо повторения одних и тех же инструкций в каждом промпте, скилы предоставляют:

- ✅ **Шаблоны кода** (code templates) с best practices
- ✅ **Чеклисты** для проверки качества
- ✅ **Q&A** для типичных проблем
- ✅ **Примеры использования** из реальных кейсов
- ✅ **Контекст проекта** (технологии, архитектура, стиль)

### Преимущества Skills

| До Skills | После Skills |
|-----------|--------------|
| 1213 строк в template | 200-250 строк в template |
| ~50k токенов контекста | ~10k токенов (экономия 80%) |
| Дублирование инструкций | Lazy loading по требованию |
| Сложно поддерживать | Один скил = один файл |
| Нет переиспользования | Skills работают в любых templates |

---

## Universal Skills (применимы к любым проектам)

### 1. structured-planning

**Файл:** `.claude/skills/structured-planning/SKILL.md`
**Размер:** ~700 строк
**Tags:** planning, json-schema, structured-output, validation, task-management

**Назначение:**
Создание структурированных планов задач с JSON Schema валидацией. Обеспечивает полноту и правильность планов через программную валидацию.

**Когда использовать:**
- Создать структурированный план с JSON валидацией
- Спланировать execution steps для задачи
- Определить файлы для изменения (create/modify/delete)
- Идентифицировать риски и митигации
- Подготовить git workflow (branch, commit type)

**Ключевые шаблоны:**
- JSON Schema для task_plan (validation rules)
- Execution step template с validation commands
- File change template (create/modify/delete)
- Markdown plan output форматтер

**Зависимости:** thinking-framework

**Пример запроса:**
```
Создай план для добавления метода calculate_total в BudgetService
с валидацией acceptance criteria
```

---

### 2. validation-framework

**Файл:** `.claude/skills/validation-framework/SKILL.md`
**Размер:** ~850 строк
**Tags:** validation, testing, acceptance-criteria, prd-compliance, syntax-checks

**Назначение:**
Комплексная валидация результатов через acceptance criteria, PRD compliance, syntax и functional checks с блокирующими ошибками.

**Когда использовать:**
- Валидировать acceptance criteria после выполнения
- Проверить PRD compliance (соответствие требованиям)
- Выполнить syntax checks для измененных файлов
- Провести functional checks
- Определить blocking issues перед финализацией

**Ключевые шаблоны:**
- JSON Schema для validation_results
- Syntax check commands по языкам (Python, JS, TS, Bash, Go, Rust, etc)
- Acceptance criterion template (criterion, status, evidence)
- PRD compliance check template
- Validation rules (overall_status logic)

**Зависимости:** structured-planning, error-handling

**Пример запроса:**
```
Провалидируй acceptance criteria и PRD compliance для выполненной задачи
```

---

### 3. git-workflow

**Файл:** `.claude/skills/git-workflow/SKILL.md`
**Размер:** ~750 строк
**Tags:** git, conventional-commits, changelog, versioning, github

**Назначение:**
Стандартизированный git workflow с Conventional Commits форматом, автоматической генерацией changelog entries и structured output для git operations.

**Когда использовать:**
- Создать git commit с Conventional Commits форматом
- Сгенерировать changelog entry для GitHub Release
- Выполнить structured git operations (branch, commit, push)
- Определить правильный commit type (feat, fix, refactor)
- Создать правильный branch name pattern

**Ключевые шаблоны:**
- Commit message template (Conventional Format + Co-Authored-By)
- Git commit JSON (structured output)
- Changelog entry JSON и Markdown
- Branch naming patterns (feature/, fix/, refactor/)
- Semantic Versioning guide

**Зависимости:** structured-planning

**Пример запроса:**
```
Создай git commit для выполненной задачи и сгенерируй changelog entry
```

---

### 4. thinking-framework

**Файл:** `.claude/skills/thinking-framework/SKILL.md`
**Размер:** ~550 строк
**Tags:** thinking, reasoning, decision-making, analysis

**Назначение:**
Структурированный reasoning через стандартизированные thinking блоки перед критическими решениями.

**Когда использовать:**
- Проанализировать задачу перед планированием
- Принять техническое решение между альтернативами
- Оценить риски и компромиссы (trade-offs)
- Обосновать выбор подхода
- Выполнить root cause analysis

**Ключевые шаблоны:**
- PRD Analysis Thinking (проверка alignment)
- Root Cause Analysis Thinking (анализ кодовой базы)
- Technical Decision Thinking (выбор между alternatives)
- Solution Comparison Thinking (детальное сравнение вариантов)
- Risk Assessment Thinking (оценка рисков)

**Зависимости:** нет

**Пример запроса:**
```
Используй thinking-framework для анализа выбора между PostgreSQL и MongoDB
```

---

### 5. approval-gates

**Файл:** `.claude/skills/approval-gates/SKILL.md`
**Размер:** ~450 строк
**Tags:** approval, confirmation, structured-output, safety

**Назначение:**
Программные approval gates для получения явного подтверждения перед выполнением критических действий.

**Когда использовать:**
- Получить подтверждение плана задачи перед выполнением
- Запросить approval перед деструктивными операциями
- Предоставить возможность review перед git push
- Предотвратить автоматическое выполнение без explicit consent

**Ключевые шаблоны:**
- Approval request message template
- Plan approval gate (Phase 1 → Phase 2)
- Destructive operation approval
- Approval JSON (structured output с boolean)
- Response parsing patterns (approved/rejected/modify)

**Зависимости:** structured-planning

**Пример запроса:**
```
Используй approval-gates для получения подтверждения плана
```

---

### 6. error-handling

**Файл:** `.claude/skills/error-handling/SKILL.md`
**Размер:** ~400 строк
**Tags:** error-handling, retry-logic, troubleshooting

**Назначение:**
Типовая обработка ошибок workflow с правильными actions (STOP/RETRY/ASK/BLOCKING) и structured error messages.

**Когда использовать:**
- Произошла ошибка в workflow
- Нужно определить правильный action (STOP/RETRY/ASK)
- Нужно вывести structured error message
- Нужно понять retry logic (сколько попыток)

**Ключевые шаблоны:**
- PRD_CONFLICT (STOP)
- JSON_SCHEMA_VALIDATION_ERROR (RETRY max 1)
- ACCEPTANCE_FAIL (RETRY max 2)
- SYNTAX_ERROR (STOP)
- APPROVAL_REJECTED (STOP)
- VALIDATION_FAILED (BLOCKING)
- GIT_COMMIT_FAILED (STOP)

**Зависимости:** нет

**Пример запроса:**
```
Используй error-handling для обработки syntax error в файле
```

---

### 7. phase-execution

**Файл:** `.claude/skills/phase-execution/SKILL.md`
**Размер:** ~650 строк
**Tags:** phase-based, execution, checkpoint, validation, workflow

**Назначение:**
Автоматизация выполнения ОДНОЙ фазы из готового phase file с checkpoint validation и structured output. Выполняет parse, validate, execute, commit, summary.

**Когда использовать:**
- Выполнить конкретную фазу из готового phase-N-slug.md file
- Phase file уже создан (task-decomposition завершен)
- Нужна автоматизация: parse → validate → execute → commit → summary
- Требуется mandatory checkpoint validation между этапами

**Ключевые шаблоны:**
- Phase File Reading and Parsing
- CHECKPOINT 1: ЗАГРУЗКА И АНАЛИЗ (BLOCKING)
- CHECKPOINT 2: ВЫПОЛНЕНИЕ (BLOCKING)
- Git Commit с validation
- Phase Summary JSON

**Зависимости:** thinking-framework, validation-framework, git-workflow, error-handling

**Пример запроса:**
```
Выполни Phase 2 из plans/phase-2-backend-api.md
```

---

### 8. task-decomposition

**Файл:** `.claude/skills/task-decomposition/SKILL.md`
**Размер:** ~700 строк
**Tags:** phase-based, decomposition, planning, master-plan, workflow

**Назначение:**
Автоматизация разбиения complex задачи на 2-5 логических фаз с генерацией master plan и individual phase files. Includes acceptance criteria mapping и dependency graph.

**Когда использовать:**
- Задача слишком большая для одного commit (>10 steps, >5 файлов)
- Задача имеет логические этапы с dependencies
- Acceptance criteria можно разделить по фазам
- Нужна возможность rollback отдельных частей

**Ключевые шаблоны:**
- Decomposition Thinking (ОБЯЗАТЕЛЬНО)
- Task Decomposition JSON (2-5 phases)
- Master Plan Generation
- Phase File Generation (phase-N-slug.md)
- Approval Gate (BLOCKING)

**Зависимости:** thinking-framework, structured-planning, approval-gates, error-handling

**Пример запроса:**
```
Разбей задачу "Добавить систему аутентификации" на фазы
```

---

## Project-Specific Skills (для init_claude)

### 9. bash-development

**Файл:** `.claude/skills/bash-development/SKILL.md`
**Размер:** ~323 строки
**Tags:** bash, shell, scripting, development, refactoring

**Назначение:**
Разработка bash-функций для проекта init_claude с best practices.

**Когда использовать:**
- Добавить новый флаг в init_claude.sh
- Создать новую bash-функцию
- Рефакторить существующую функцию
- Работать с env variables (HTTPS_PROXY, etc)
- Обработать ошибки

**Пример запроса:**
```
Добавь новый флаг --timeout для ограничения времени ожидания
```

---

### 10. proxy-management

**Файл:** `.claude/skills/proxy-management/SKILL.md`
**Размер:** ~496 строк
**Tags:** proxy, https, socks5, tls, certificates

**Назначение:**
Настройка прокси, TLS сертификатов, тестирование подключений, отладка проблем.

**Когда использовать:**
- Настроить HTTPS/SOCKS5 прокси
- Отладить TLS проблемы (self-signed certificates)
- Добавить поддержку нового proxy protocol
- Тестировать proxy connectivity

**Пример запроса:**
```
Отладь проблему: Test proxy failed с ошибкой "SSL certificate problem"
```

---

### 11. isolated-environment

**Файл:** `.claude/skills/isolated-environment/SKILL.md`
**Размер:** ~949 строк
**Tags:** nvm, node, isolation, lockfile, reproducibility

**Назначение:**
Управление изолированным NVM окружением в директории проекта для воспроизводимых установок.

**Когда использовать:**
- Установить Claude Code в изолированное окружение
- Создать lockfile текущей установки
- Восстановить окружение из lockfile
- Починить симлинки после git clone

**Пример запроса:**
```
Установи Claude Code в изолированное окружение с lockfile
```

---

## Quick Reference

### Таблица: Когда использовать какой скил

| Задача | Скил | Примерный запрос |
|--------|------|------------------|
| Создать план задачи | structured-planning | "Создай план с JSON валидацией" |
| Валидировать результаты | validation-framework | "Провалидируй acceptance criteria" |
| Git commit и changelog | git-workflow | "Создай commit с Conventional format" |
| Анализ перед решением | thinking-framework | "Проанализируй выбор между X и Y" |
| Получить подтверждение | approval-gates | "Получи approval плана" |
| Обработать ошибку | error-handling | "Обработай syntax error" |
| **Разбить задачу на фазы** | **task-decomposition** | **"Разбей задачу на 2-5 фаз с master plan"** |
| **Выполнить фазу** | **phase-execution** | **"Выполни Phase 2 из phase-2-backend-api.md"** |
| Добавить bash функцию | bash-development | "Добавь флаг --timeout" |
| Настроить прокси | proxy-management | "Отладь TLS проблему" |
| Установить изолированно | isolated-environment | "Установи в изолированное окружение" |

### Таблица: Skills по фазам workflow (Simple Tasks)

| Phase | Skills |
|-------|--------|
| Phase 1: Анализ | thinking-framework, structured-planning |
| Phase 2: Согласование | approval-gates |
| Phase 3: Выполнение | bash-development, proxy-management, isolated-environment (project-specific) |
| Phase 4: Валидация | validation-framework, error-handling |
| Phase 5: Финализация | git-workflow, error-handling |

### Таблица: Skills для Phase-Based Workflow (Complex Tasks)

| Workflow Stage | Skills |
|---------------|--------|
| **Planning Phase** | |
| 1. Decomposition | thinking-framework (Decomposition Thinking), task-decomposition |
| 2. Approval | approval-gates |
| **Execution (per phase)** | |
| 3. Phase Analysis | thinking-framework (Phase Analysis Thinking) |
| 4. Phase Execution | phase-execution, validation-framework, git-workflow |
| 5. Phase Summary | phase-execution |

**Workflow:**
1. Task Decomposition → создает master plan + phase files
2. Для каждой фазы: Phase Execution → читает phase file, выполняет, commit, summary
3. Повторяем пока все фазы не completed

---

## Зависимости между Skills

```
thinking-framework (независимый)
    ↓
structured-planning
    ↓
approval-gates
    ↓
execution (project-specific skills)
    ↓
validation-framework → error-handling
    ↓
git-workflow
```

### Граф зависимостей

**Universal Skills:**
```
thinking-framework (независимый)
    ↓
    ├──→ structured-planning
    │         ↓
    │         ├──→ task-decomposition ──→ approval-gates
    │         │                                  ↓
    │         └──────────────────────────────────┤
    │                                             ↓
    ├──→ phase-execution ←─────────────────────┬─┤
    │         ↓                                 │ │
    │         └──→ validation-framework         │ │
    │                   ↓                       │ │
    │                   └──→ error-handling ────┘ │
    │                                             │
    └──→ git-workflow ←───────────────────────────┘

Легенда:
→ = depends on (зависит от)
├─ = multiple dependencies
└─ = end of dependency branch
```

**Phase-Based Workflow Dependencies:**
```
1. task-decomposition
   Dependencies: thinking-framework, structured-planning, approval-gates, error-handling

2. phase-execution
   Dependencies: thinking-framework, validation-framework, git-workflow, error-handling
```

**Project-Specific Skills:**
```
bash-development (независимый, project-specific)
proxy-management (независимый, project-specific)
isolated-environment (независимый, project-specific)
```

### Dependencies в SKILL.md frontmatter

**structured-planning:**
```yaml
dependencies: [thinking-framework]
```

**validation-framework:**
```yaml
dependencies: [structured-planning, error-handling]
```

**git-workflow:**
```yaml
dependencies: [structured-planning]
```

**approval-gates:**
```yaml
dependencies: [structured-planning]
```

**thinking-framework, error-handling:**
```yaml
dependencies: []  # независимые
```

**task-decomposition:**
```yaml
dependencies: [thinking-framework, structured-planning, approval-gates, error-handling]
```

**phase-execution:**
```yaml
dependencies: [thinking-framework, validation-framework, git-workflow, error-handling]
```

---

## Примеры комбинированного использования

### Пример 1: Стандартный workflow (6 skills)

**Задача:** "Добавить метод calculate_total в BudgetService"

**Skills sequence:**
1. **thinking-framework** (PRD Analysis) - проверить alignment с PRD
2. **thinking-framework** (Root Cause) - проанализировать кодовую базу
3. **thinking-framework** (Technical Decision) - обдумать решение
4. **structured-planning** - создать JSON plan с validation
5. **approval-gates** - получить подтверждение плана
6. *Execution* - реализовать метод
7. **validation-framework** - валидировать acceptance criteria
8. **git-workflow** - создать commit и changelog
9. **error-handling** - если возникли ошибки

**Token usage:** ~40k (vs 70k в monolithic template)

---

### Пример 2: Добавление bash функции (3 skills)

**Задача:** "Добавь флаг --timeout в init_claude.sh"

**Skills sequence:**
1. **thinking-framework** (Technical Decision) - определить где добавить флаг
2. **bash-development** - использовать шаблоны bash функций
3. **git-workflow** - создать commit

**Token usage:** ~20k

---

### Пример 3: Рефакторинг с несколькими файлами (7 skills)

**Задача:** "Рефактори OrderService - выдели OrderValidator"

**Skills sequence:**
1. **thinking-framework** (Root Cause + Risk Assessment) - анализ и риски
2. **structured-planning** - детальный план с 3 файлами
3. **approval-gates** - подтверждение (рефакторинг рискованный)
4. *Execution* - создать OrderValidator, обновить OrderService, endpoints
5. **validation-framework** - syntax checks для всех 3 файлов
6. **error-handling** - если syntax errors
7. **git-workflow** - refactor commit с changelog

**Token usage:** ~45k

---

### Пример 4: Phase-Based Workflow для complex задачи (8 skills)

**Задача:** "Добавить систему аутентификации с JWT и refresh tokens"

**Phase 1: Task Decomposition**
1. **thinking-framework** (Decomposition Thinking) - разбить задачу на 3 фазы
2. **task-decomposition** - создать master plan + 3 phase files
3. **approval-gates** - получить подтверждение плана

**Phase 2: Execute Phase 1 (Database Models)**
4. **thinking-framework** (Phase Analysis Thinking) - анализ Phase 1
5. **phase-execution** - читает phase-1-database-models.md
   - Checkpoint 1: ЗАГРУЗКА (branch context, dependencies)
   - Execute 5 steps (create User model, RefreshToken model, migrations)
   - Checkpoint 2: ВЫПОЛНЕНИЕ (completion criteria)
   - **validation-framework** - syntax checks, completion validation
   - **git-workflow** - commit Phase 1
   - Phase summary

**Phase 3: Execute Phase 2 (Backend API)**
6. **phase-execution** - читает phase-2-backend-api.md
   - Checkpoint 1 (проверяет Phase 1 completed)
   - Execute 7 steps (JWTService, endpoints, middleware)
   - Checkpoint 2 (API tests)
   - **git-workflow** - commit Phase 2

**Phase 4: Execute Phase 3 (Frontend)**
7. **phase-execution** - читает phase-3-frontend-integration.md
   - Execute 6 steps
   - **git-workflow** - commit Phase 3

8. **error-handling** - если ошибки на любом этапе

**Token usage:** ~60-70k (все 3 фазы), но можно выполнять поэтапно с промежутками

**Преимущества:**
- ✅ Atomic commits (каждая фаза = отдельный commit)
- ✅ Можно rollback отдельные фазы
- ✅ Checkpoint validation гарантирует корректность перехода между фазами
- ✅ Структурированный процесс (не потеряешь контекст)

---

### Пример 4: Отладка прокси проблемы (2 skills)

**Задача:** "Почему test proxy failed с HTTP 407?"

**Skills sequence:**
1. **thinking-framework** (Root Cause) - анализ проблемы
2. **proxy-management** - использовать Q&A и troubleshooting templates

**Token usage:** ~15k

---

### Пример 5: Установка изолированного окружения (1 skill)

**Задача:** "Установи Claude Code в изолированное окружение с lockfile"

**Skills sequence:**
1. **isolated-environment** - следовать installation workflow

**Token usage:** ~12k (только один скил загружается)

---

## Советы по использованию Skills

### Как Claude автоматически выбирает скил

Claude анализирует:
1. **Ключевые слова** в запросе ("план", "валидация", "git commit", "thinking")
2. **Контекст workflow** (какая Phase выполняется)
3. **Tags в SKILL.md** (соответствие типу задачи)
4. **Зависимости** (если нужен skill A, возможно нужен и skill B)

### Явное указание скила

Вы можете явно указать скил:
```
Используй structured-planning skill для создания плана с JSON валидацией
```

### Комбинирование скилов

Для сложных задач Claude автоматически комбинирует скилы:
```
"Добавь поддержку SOCKS4 прокси в init_claude.sh с полной валидацией"
→ proxy-management (валидация URL) + bash-development (создание функций) +
   validation-framework (тестирование) + git-workflow (commit)
```

### Переиспользование в других проектах

**Universal skills** (1-6) можно переиспользовать в любых проектах:
- Скопировать `.claude/skills/` директории (structured-planning, validation-framework, etc)
- Обновить `dependencies` и project context если нужно
- Использовать в любых templates (lite/standard/complex)

**Project-specific skills** (7-9) специфичны для init_claude, но их формат можно использовать как template для создания своих скилов.

---

## Метрики экономии

### Token usage (сравнение)

| Сценарий | Monolithic Template | Skills-based Template | Экономия |
|----------|---------------------|----------------------|----------|
| Простая задача (add method) | 70k | 30k | 57% |
| Средняя задача (refactoring) | 70k | 40k | 43% |
| Сложная задача (все skills) | 70k | 51k | 27% |

### Размер files

| Файл | До | После | Изменение |
|------|---|-------|-----------|
| task-lite-template.md | 1213 строк | 280 строк (v3.0) | -77% |
| Общий контекст | ~50k токенов | ~10k токенов | -80% |

### Поддерживаемость

| Метрика | До | После |
|---------|---|--------|
| Изменение JSON Schema | Править template ~200 строк | Править 1 скил ~50 строк |
| Добавление нового error type | Править template | Править error-handling skill |
| Обновление git workflow | Править template | Править git-workflow skill |

---

## Версия
**Documentation Version:** 1.0.0
**Дата:** 2025-11-20
**Количество скилов:** 9 (6 universal + 3 project-specific)
