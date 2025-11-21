# Task Execution Template (Lite) v3.0 (Skills-based)

**Назначение:** Упрощенный шаблон для точечных доработок с автоматической загрузкой Claude Code Skills по требованию.

**Ключевое отличие v3.0:** Вместо 1200+ строк инструкций, использует 6 специализированных скилов (~200-250 строк template, скилы загружаются динамически).

---

## Конфигурация
- Режим: последовательное выполнение
- Thinking: enabled через **thinking-framework** skill
- Structured Output: enabled через **structured-planning**, **validation-framework**, **approval-gates** skills
- Валидация: critical_only через **validation-framework** skill
- Error Handling: через **error-handling** skill
- Git: через **git-workflow** skill
- Среда: локальная разработка (без /opt/, без запущенных сервисов)

## Принципы
1. **PRD Compliance** - все решения ДОЛЖНЫ соответствовать PRD из `docs/prd`
2. **Acceptance Criteria** - все критерии ДОЛЖНЫ быть выполнены
3. **Skills-based execution** - используй Claude Code Skills для специализированных задач
4. **Approval Gate** - plan ДОЛЖЕН быть согласован перед выполнением
5. **Минималистичный код** - код должен быть самодокументируемым
6. **Один коммит** - все изменения в одном git commit

---

## Доступные Skills

### Universal Skills (для любых проектов)
1. **structured-planning** - создание JSON планов с schema validation
2. **validation-framework** - комплексная валидация (acceptance, PRD, syntax, functional)
3. **git-workflow** - Conventional Commits, changelog, structured git operations
4. **thinking-framework** - структурированный reasoning для критических решений
5. **approval-gates** - программные approval gates с JSON validation
6. **error-handling** - типовая обработка ошибок (STOP/RETRY/ASK/BLOCKING)

### Project-Specific Skills (для init_claude)
- **bash-development** - разработка bash-функций
- **proxy-management** - настройка прокси, TLS, отладка
- **isolated-environment** - изолированная установка NVM, lockfiles

**Как использовать:** Просто укажи "Используй {skill-name} skill для {задачи}" и Claude автоматически загрузит нужный скил.

---

## Процесс

### PHASE 1: АНАЛИЗ

#### **Шаг 1. [THINKING - ОБЯЗАТЕЛЬНО] Загрузить и изучить PRD**

**Используй thinking-framework skill** (Шаблон: PRD Analysis)

```xml
<thinking>
ЗАДАЧА: [краткое описание от пользователя]
PRD СЕКЦИИ: [какие секции релевантны]
ACCEPTANCE CRITERIA: [идентифицировать из задачи]
ALIGNMENT: [проверить соответствие задачи PRD]
</thinking>
```

**Действия:**
- Прочитать `docs/prd` релевантные секции
- Проверить alignment задачи с PRD
- Идентифицировать acceptance criteria

**Exit Condition:**
- ✓ PRD прочитан
- ✓ Acceptance criteria идентифицированы

**Violation Action:** Используй **error-handling** skill (PRD_CONFLICT → STOP)

---

#### **Шаг 2. [THINKING - ОБЯЗАТЕЛЬНО] Проанализировать текущее состояние**

**Используй thinking-framework skill** (Шаблон: Root Cause Analysis)

```xml
<thinking>
КОНТЕКСТ: [текущее состояние кодовой базы]
ROOT CAUSES: [что нужно изменить]
КОМПОНЕНТЫ: [какие файлы/модули затронуты]
СЛОЖНОСТЬ: [оценка объема работы]
</thinking>
```

**Exit Condition:**
- ✓ Root causes определены
- ✓ Компоненты идентифицированы

---

#### **Шаг 3. ЗАДАТЬ УТОЧНЯЮЩИЕ ВОПРОСЫ (если требуется)**

**Когда спрашивать:**
- При неясности требований → СТОП и спросить
- При конфликте с PRD → СТОП и спросить

**Формат вопроса:**
```
❓ ТРЕБУЕТСЯ УТОЧНЕНИЕ
Неясно: [что конкретно]
Варианты: [опции]
Вопрос: [конкретный вопрос]
```

---

#### **Шаг 4. [THINKING - ОБЯЗАТЕЛЬНО] Обдумать решение**

**Используй thinking-framework skill** (Шаблон: Technical Decision)

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

---

#### **Шаг 5. [STRUCTURED OUTPUT - BLOCKING] Создать план**

**Используй structured-planning skill для создания JSON плана с schema validation**

**Скил автоматически:**
1. Создаст JSON plan с обязательными секциями (task_name, prd_sections, problem, solution, acceptance_criteria, files_to_change, execution_steps, risks, validation, git)
2. Валидирует JSON через Schema (минимум 2 execution_steps, все обязательные поля, branch pattern validation)
3. Выведет Markdown plan для user readability

**Exit Conditions:**
- ✓ JSON Schema validation PASSED
- ✓ План содержит минимум 2 шага
- ✓ Все обязательные поля заполнены
- ✓ Markdown план выведен

**Violation Action:** Используй **error-handling** skill (JSON_SCHEMA_VALIDATION_ERROR → RETRY max 1)

---

### PHASE 2: СОГЛАСОВАНИЕ

#### **[STRUCTURED OUTPUT - APPROVAL GATE] Получение подтверждения**

**Используй approval-gates skill для получения явного подтверждения плана**

**Скил автоматически:**
1. Выведет approval gate message с статистикой плана
2. ОСТАНОВИТСЯ и будет ждать ответа пользователя
3. Parse ответ через patterns (approved/rejected/modify)
4. Создаст approval JSON с `can_proceed_to_execution` boolean

**Exit Conditions:**
- ✓ approval.approved = true
- ✓ can_proceed_to_execution = true

**Violation Action:**
- approved = false → Используй **error-handling** skill (APPROVAL_REJECTED → STOP)
- Запрос изменений → Вернуться к Phase 1, Шаг 5

---

### PHASE 3: ВЫПОЛНЕНИЕ

**Entry Conditions:**
- ✓ approval.can_proceed_to_execution = true
- ✓ task_plan валидирован

#### **Шаг 1. Выполнение шагов**

Для каждого `step` в `task_plan.execution_steps[]`:

**a) Выполнить действия**
- Следовать `step.actions[]`
- Достичь результата из `step.description`

**Правила комментирования кода:**

✅ **ПИСАТЬ комментарии ТОЛЬКО для:**
1. Сложной бизнес-логики, которая неочевидна из кода
2. Критичных решений и их обоснования
3. Workarounds и временных решений (FIXME, TODO)
4. API endpoints - краткое описание (1-2 строки)
5. Регулярных выражений и сложных SQL

❌ **НЕ ПИСАТЬ комментарии для:**
1. Очевидных операций
2. Переменных с понятными именами
3. Пересказа кода
4. Закомментированного кода (удалять!)

**b) Валидация шага**
```bash
# Выполнить команду из step.validation
```

**c) Вывести статус**
```
✓ Шаг {step_number} выполнен: {description}
```

**Exit Conditions:**
- ✓ Все шаги выполнены
- ✓ Каждый step.validation пройден

---

### PHASE 4: ВАЛИДАЦИЯ (БЛОКИРУЮЩАЯ)

**Entry Conditions:**
- ✓ Все шаги выполнения завершены

#### **[STRUCTURED OUTPUT - BLOCKING] Критичные проверки**

**Используй validation-framework skill для комплексной валидации результатов**

**Скил автоматически:**
1. Проверит acceptance criteria (total, met, not_met с evidence)
2. Проверит PRD compliance (compliant boolean, conflicts[], checks_performed[])
3. Выполнит syntax checks для всех измененных файлов
4. Выполнит functional checks
5. Определит overall_status (PASSED/FAILED) и blocking_issues
6. Выведет structured JSON + Markdown report

**Exit Conditions:**
- ✓ overall_status = "PASSED"
- ✓ can_proceed_to_finalization = true
- ✓ blocking_issues = []

**Violation Action:**
- overall_status = "FAILED" → Используй **error-handling** skill (VALIDATION_FAILED → BLOCKING)
- Max 2 попытки исправления, затем STOP

---

### PHASE 5: ФИНАЛИЗАЦИЯ

**Entry Conditions:**
- ✓ validation_results.can_proceed_to_finalization = true

#### **Шаг 1. Обновить документацию PRD (если требуется)**

Если задача меняет функциональность, задокументированную в PRD:
- Обновить релевантные секции в `docs/prd`

---

#### **Шаг 2. [STRUCTURED OUTPUT] Подготовить changelog entry**

**Используй git-workflow skill для генерации changelog entry**

**Скил автоматически:**
1. Создаст changelog_entry JSON (category, title, changes[], user_impact, technical_details, breaking_changes)
2. Определит правильную category на основе commit_type
3. Выведет Markdown changelog entry готовый для GitHub Release

---

#### **Шаг 3. [STRUCTURED OUTPUT] Git commit и push**

**Используй git-workflow skill для Conventional Commits format**

**Скил автоматически:**
1. Создаст commit message в Conventional Commits format (type: summary + body + Co-Authored-By footer)
2. Выполнит git add, commit, push
3. Создаст git_commit JSON с validation (commit_hash, commit_status, push_status)

**Exit Conditions:**
- ✓ commit_status = "success"
- ✓ pushed = true
- ✓ push_status = "success"

**Violation Action:** Используй **error-handling** skill (GIT_COMMIT_FAILED → STOP)

---

#### **Шаг 4. Вывести SUMMARY**

**Вывести краткий summary:**
```
═══════════════════════════════════════════════════════════
                ✅ ЗАДАЧА ЗАВЕРШЕНА
═══════════════════════════════════════════════════════════

СТАТУС: ✓ COMPLETED

СДЕЛАНО:
- [список изменений]

ФАЙЛЫ:
- [список файлов с change_type]

ACCEPTANCE CRITERIA: ✓ Все выполнены

GIT:
- Branch: {branch}
- Commit: {commit_hash}

NEXT STEPS:
- [ ] Создать PR из {branch} в {base_branch}
- [ ] Добавить changelog entry в GitHub Release

═══════════════════════════════════════════════════════════
```

---

## Error Handling

**Используй error-handling skill при любых ошибках**

**Скил предоставляет:**
- Типовые error types (PRD_CONFLICT, SYNTAX_ERROR, ACCEPTANCE_FAIL, VALIDATION_FAILED, etc)
- Правильные actions (STOP/RETRY/ASK/BLOCKING)
- Structured error messages
- Retry logic с max attempts

---

## Startup Sequence

**КРИТИЧНО - выполнить СТРОГО в этом порядке:**

1. ✓ Прочитать задачи из промпта
2. ✓ **ПЕРВЫМ ДЕЛОМ** загрузить PRD из `docs/prd`
3. ✓ Phase 1, Шаг 1: thinking-framework (PRD Analysis)
4. ✓ Phase 1, Шаг 2: thinking-framework (Root Cause)
5. ✓ Phase 1, Шаг 3: Задать вопросы (если требуется)
6. ✓ Phase 1, Шаг 4: thinking-framework (Technical Decision)
7. ✓ Phase 1, Шаг 5: structured-planning (JSON + Markdown plan)
8. ✓ Phase 2: approval-gates (получить подтверждение)
9. ✓ Phase 3: Выполнение шагов
10. ✓ Phase 4: validation-framework (BLOCKING validation)
11. ✓ Phase 5 Шаг 1: Обновить PRD (если требуется)
12. ✓ Phase 5 Шаг 2: git-workflow (changelog entry)
13. ✓ Phase 5 Шаг 3: git-workflow (commit + push)
14. ✓ Phase 5 Шаг 4: Вывести summary

---

## Важные напоминания

### ✅ ВСЕГДА ДЕЛАЙТЕ:
- ✓ Используйте thinking-framework для reasoning
- ✓ Используйте structured-planning для планов с JSON validation
- ✓ Используйте approval-gates перед выполнением
- ✓ Используйте validation-framework для проверки результатов
- ✓ Используйте git-workflow для commits и changelog
- ✓ Используйте error-handling при ошибках

### ❌ НИКОГДА НЕ ДЕЛАЙТЕ:
- ❌ НЕ пропускайте approval gate
- ❌ НЕ пропускайте thinking для requires_thinking="true"
- ❌ НЕ продолжайте при validation FAILED
- ❌ НЕ начинайте выполнение без подтверждения

---

## Преимущества v3.0 (Skills-based)

### vs v2.0 (Monolithic):
- ✅ **Размер template:** 200-250 строк вместо 1213 (80% меньше)
- ✅ **Token usage:** ~10k вместо ~50k при загрузке (80% экономия)
- ✅ **Lazy loading:** Skills загружаются только когда нужны
- ✅ **Модульность:** Один скил = одна responsibility
- ✅ **Переиспользование:** Skills работают в любых шаблонах (lite/standard/complex)
- ✅ **Поддерживаемость:** Изменение JSON Schema → править один скил
- ✅ **Тестирование:** Каждый скил тестируется независимо

### Экономия контекста:
- **До оптимизации:** Template 50k + Global rules 20k = 70k токенов
- **После оптимизации:** Template 10k + Global rules 20k + Skills on-demand ~15k = 45k токенов (36% экономия)
- **Максимум (все skills):** ~51k токенов (27% экономия)

---

## Версия
**Template Version:** 3.0 (Skills-based)
**Дата:** 2025-11-20
**Изменения:**
- Полный рефакторинг: большие секции вынесены в 6 специализированных скилов
- Добавлен lazy loading скилов (загружаются по требованию)
- Сокращен template с 1213 до 200-250 строк
- Экономия контекста: 36-80% в зависимости от используемых скилов
- Улучшена модульность и переиспользуемость
- Упрощена поддержка (изменения в одном месте = один скил)
