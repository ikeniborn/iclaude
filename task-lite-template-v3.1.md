# Task Execution Template (Lite) v3.1

**Назначение:** Упрощенный шаблон для точечных доработок с автоматическим использованием Claude Code Skills.

**Для пользователя:** Просто опишите задачи ниже. Claude автоматически применит нужные skills, создаст план, запросит подтверждение и выполнит задачу.

---

## 📋 Задачи

[Пользователь описывает задачи здесь. Примеры:]

```
1. Добавить метод calculate_total() в BudgetService
2. Исправить bug с null pointer в validator
3. Обновить документацию для API endpoint /auth/login
```

**Acceptance Criteria (опционально):**
```
- Метод calculate_total() возвращает корректную сумму
- Null pointer exception больше не возникает
- Документация содержит все query parameters
```

---

## ⚙️ Конфигурация (для Claude)

<details>
<summary>Внутренние настройки (автоматические)</summary>

- **Skills:** thinking-framework, structured-planning, validation-framework, approval-gates, git-workflow, error-handling
- **Thinking:** Enabled (автоматически для критических решений)
- **Structured Output:** Enabled (JSON + Markdown)
- **Validation:** Critical only
- **Git:** Conventional Commits format
- **PRD Compliance:** Обязательно

</details>

---

## 🔄 Workflow (выполняется автоматически)

### PHASE 1: АНАЛИЗ И ПЛАНИРОВАНИЕ

Claude автоматически:
1. Загрузит PRD (если есть `docs/prd`)
2. Проанализирует текущий код
3. Определит что нужно изменить
4. Создаст структурированный план
5. Запросит ваше подтверждение

**Внутренние инструкции для Claude:**

<details>
<summary>Шаг 1.1: Загрузка PRD</summary>

**[INTERNAL] Используй thinking-framework skill (PRD Analysis template)**

```xml
<thinking>
ЗАДАЧА: [из секции "Задачи" выше]
PRD СЕКЦИИ: [какие секции релевантны]
ACCEPTANCE CRITERIA: [из user input или определить самостоятельно]
ALIGNMENT: [проверить соответствие PRD]
</thinking>
```

**Действия:**
- Если `docs/prd` существует → прочитать релевантные секции
- Проверить alignment задачи с PRD
- Идентифицировать acceptance criteria

**Exit Condition:** PRD проанализирован ИЛИ отсутствует (skip)

**Error:** Конфликт с PRD → STOP, спросить пользователя
</details>

<details>
<summary>Шаг 1.2: Анализ текущего состояния</summary>

**[INTERNAL] Используй thinking-framework skill (Root Cause Analysis template)**

```xml
<thinking>
КОНТЕКСТ: [текущее состояние кодовой базы]
ROOT CAUSES: [что нужно изменить]
КОМПОНЕНТЫ: [файлы/модули]
СЛОЖНОСТЬ: [оценка]
</thinking>
```

**Действия:**
- Прочитать затрагиваемые файлы
- Определить root causes
- Идентифицировать компоненты для изменения

**Exit Condition:** Понятно что и где менять
</details>

<details>
<summary>Шаг 1.3: Уточняющие вопросы (при неясности)</summary>

**Когда спрашивать:**
- Требования неоднозначны
- Конфликт с PRD
- Отсутствует критичная информация

**Формат (для пользователя):**
```
❓ ТРЕБУЕТСЯ УТОЧНЕНИЕ

Неясно: [что конкретно]
Варианты:
  A) [вариант 1]
  B) [вариант 2]

Вопрос: [конкретный вопрос]
```
</details>

<details>
<summary>Шаг 1.4: Обдумывание решения</summary>

**[INTERNAL] Используй thinking-framework skill (Technical Decision template)**

```xml
<thinking>
КОНТЕКСТ: [текущая ситуация]
ЗАДАЧА: [что нужно сделать]
ОПЦИИ:
  Option 1: [описание] - Плюсы: [...] Минусы: [...]
  Option 2: [описание] - Плюсы: [...] Минусы: [...]
ВЫБОР: Option [N] потому что [обоснование]
РИСКИ: [что может пойти не так]
ПРОВЕРКА: [как валидируем]
</thinking>
```
</details>

<details>
<summary>Шаг 1.5: Создание плана</summary>

**[INTERNAL] Используй structured-planning skill (Task Plan JSON + Markdown)**

Скил автоматически создаст:
1. **JSON план** с полями:
   - task_name, problem, solution
   - acceptance_criteria[] (минимум 1)
   - files_to_change[] с change_type (create/modify/delete)
   - execution_steps[] (минимум 2)
   - risks[], validation, git

2. **Markdown план** для пользователя:
```markdown
## План выполнения

### Цель
[краткое описание]

### Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

### Изменяемые файлы
- src/services/budget_service.py (modify)
- tests/test_budget_service.py (modify)

### Шаги выполнения
1. [Шаг 1]
2. [Шаг 2]

### Риски
- [Risk 1] → Митигация: [...]

### Git
- Branch: feature/add-calculate-total
- Commit type: feat
```

**Exit Condition:** JSON Schema validation PASSED
**Error:** Schema validation failed → RETRY (max 1)
</details>

---

### PHASE 2: СОГЛАСОВАНИЕ

**Для пользователя:** Claude покажет план и запросит подтверждение.

<details>
<summary>Approval Gate (автоматический)</summary>

**[INTERNAL] Используй approval-gates skill**

Скил выведет:
```
═══════════════════════════════════════════════════════════
           📋 ТРЕБУЕТСЯ ПОДТВЕРЖДЕНИЕ
═══════════════════════════════════════════════════════════

ПЛАН:
- Задача: [название]
- Шагов: [N]
- Файлов изменится: [N]
- Branch: [название]

ИЗМЕНЕНИЯ:
[краткое описание изменений]

═══════════════════════════════════════════════════════════

❓ Подтвердить выполнение плана?
   [yes] - Выполнить план
   [no] - Отменить
   [modify] - Внести изменения в план

═══════════════════════════════════════════════════════════
```

**[INTERNAL] ОСТАНОВИТЬСЯ и ждать ответа!**

**Exit Condition:** approval.approved = true
**Error:** approved = false → STOP
</details>

---

### PHASE 3: ВЫПОЛНЕНИЕ

**Для пользователя:** Claude выполнит все шаги из плана.

<details>
<summary>Выполнение шагов (автоматическое)</summary>

Для каждого `step` в `task_plan.execution_steps[]`:

**[INTERNAL] Действия:**
1. Выполнить все actions из step.actions[]
2. Запустить validation команду (если указана в step.validation)
3. Вывести статус: `✓ Шаг {N} выполнен: {description}`

**Правила комментирования (INTERNAL):**
- ✅ Комментарии ТОЛЬКО для сложной бизнес-логики, workarounds, API docs
- ❌ НЕ комментировать очевидный код, переменные, пересказ кода
- ❌ НЕ оставлять закомментированный код (удалять!)

**Exit Condition:** Все шаги выполнены, все validations passed
</details>

---

### PHASE 4: ВАЛИДАЦИЯ

**Для пользователя:** Claude проверит результаты автоматически.

<details>
<summary>Комплексная валидация (автоматическая)</summary>

**[INTERNAL] Используй validation-framework skill**

Скил автоматически проверит:

1. **Acceptance Criteria:**
   - Каждый criterion: met/not_met + evidence
   - Подсчет: criteria_met / criteria_total

2. **PRD Compliance (если PRD есть):**
   - PRD requirements vs implementation
   - Конфликты (если есть)

3. **Syntax Checks:**
   - Для всех измененных файлов
   - Python: `python -m py_compile`
   - JavaScript: `npx eslint`
   - Bash: `shellcheck`
   - и т.д.

4. **Functional Checks:**
   - Запустить validation commands из плана

**Скил выведет:**
```
═══════════════════════════════════════════════════════════
              ✅ ВАЛИДАЦИЯ РЕЗУЛЬТАТОВ
═══════════════════════════════════════════════════════════

ACCEPTANCE CRITERIA: 3/3 ✓
  [✓] Criterion 1: Met
  [✓] Criterion 2: Met
  [✓] Criterion 3: Met

SYNTAX CHECKS: ✓ All passed (2 files)

FUNCTIONAL CHECKS: ✓ All passed

OVERALL STATUS: ✓ PASSED

═══════════════════════════════════════════════════════════
```

**Exit Condition:** overall_status = "PASSED"
**Error:** FAILED → BLOCKING, исправить, RETRY (max 2)
</details>

---

### PHASE 5: ФИНАЛИЗАЦИЯ

**Для пользователя:** Claude создаст changelog и git commit.

<details>
<summary>Шаг 5.1: Обновление PRD (если требуется)</summary>

**[INTERNAL]** Если задача меняет функциональность из PRD:
- Обновить релевантные секции в `docs/prd`
</details>

<details>
<summary>Шаг 5.2: Changelog Entry</summary>

**[INTERNAL] Используй git-workflow skill (Changelog Generation)**

Скил создаст changelog entry для GitHub Release:
```markdown
### [Категория] Краткое описание

**Изменения:**
- ✨ Что добавлено
- 🔧 Что изменено
- 🐛 Что исправлено

**Влияние на пользователей:**
[Описание изменений для пользователя]

**Технические детали:**
- Файлы: [список]
- Commits: [hash]
```
</details>

<details>
<summary>Шаг 5.3: Git Commit</summary>

**[INTERNAL] Используй git-workflow skill (Conventional Commits)**

Скил автоматически:
1. Создаст commit message:
```
{type}: {summary}

{body}

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

2. Выполнит:
```bash
git add .
git commit -m "{message}"
git push origin {branch}
```

3. Выведет git_commit JSON с commit_hash, push_status

**Exit Condition:** commit_status = "success", pushed = true
**Error:** Failed → STOP
</details>

<details>
<summary>Шаг 5.4: Summary</summary>

**[INTERNAL] Вывести final summary:**

```
═══════════════════════════════════════════════════════════
                ✅ ЗАДАЧА ЗАВЕРШЕНА
═══════════════════════════════════════════════════════════

СТАТУС: ✓ COMPLETED

СДЕЛАНО:
- [список изменений]

ФАЙЛЫ:
- [список с change_type]

ACCEPTANCE CRITERIA: ✓ Все выполнены ({N}/{N})

GIT:
- Branch: {branch}
- Commit: {commit_hash}

NEXT STEPS:
- [ ] Создать PR из {branch} в {base_branch}
- [ ] Добавить changelog entry в GitHub Release

═══════════════════════════════════════════════════════════
```
</details>

---

## 🚨 Error Handling (автоматический)

<details>
<summary>Обработка ошибок (Internal)</summary>

**[INTERNAL] Используй error-handling skill при любых ошибках**

Типовые ошибки:
- **PRD_CONFLICT** → STOP, спросить пользователя
- **SYNTAX_ERROR** → STOP, показать ошибку
- **ACCEPTANCE_FAIL** → RETRY (max 2), затем STOP
- **VALIDATION_FAILED** → BLOCKING, исправить, RETRY (max 2)
- **APPROVAL_REJECTED** → STOP
- **GIT_COMMIT_FAILED** → STOP

Формат error message:
```
🚨 ОШИБКА: {Type}

Проблема: [описание]
Контекст: [где произошло]
Действие: [STOP/RETRY/ASK]
```
</details>

---

## 📚 Для разработчиков шаблона

<details>
<summary>Технические детали (только для разработчиков Claude Code Skills)</summary>

### Используемые Skills

**Universal Skills:**
1. **thinking-framework** - PRD Analysis, Root Cause, Technical Decision
2. **structured-planning** - Task Plan JSON + Schema Validation + Markdown
3. **approval-gates** - Approval Gate с JSON validation
4. **validation-framework** - Acceptance, PRD, Syntax, Functional checks
5. **git-workflow** - Conventional Commits, Changelog, Git operations
6. **error-handling** - Error types, Actions, Structured messages

**Project-Specific Skills (автозагрузка при необходимости):**
- **bash-development** (если задача про bash)
- **proxy-management** (если задача про прокси)
- **isolated-environment** (если задача про NVM/lockfiles)

### Execution Sequence (строгий порядок)

1. ✓ Parse задачи из "## Задачи"
2. ✓ PRD Analysis (thinking-framework)
3. ✓ Root Cause Analysis (thinking-framework)
4. ✓ Ask clarifications (если требуется)
5. ✓ Technical Decision (thinking-framework)
6. ✓ Create Plan (structured-planning) → JSON + Markdown
7. ✓ Approval Gate (approval-gates) → WAIT for user
8. ✓ Execute steps → для каждого step
9. ✓ Validation (validation-framework) → BLOCKING
10. ✓ Update PRD (если требуется)
11. ✓ Changelog (git-workflow)
12. ✓ Git Commit (git-workflow)
13. ✓ Summary output

### Принципы v3.1

- **User-friendly:** Пользователь видит только задачи и результат
- **Skills-driven:** Все сложности скрыты в скилах
- **Automatic:** Claude сам выбирает нужные скилы
- **Transparent:** Workflow понятен через Markdown output
- **Modular:** Легко добавить новый skill без изменения template

### Size Comparison

| Version | Lines | Token Usage |
|---------|-------|-------------|
| v2.0 (monolithic) | 1213 | ~50k |
| v3.0 (skills-based) | 393 | ~10k template + ~15k skills on-demand |
| v3.1 (user-friendly) | ~450 | ~10k template + ~15k skills on-demand |

**Improvement:** 80% меньше токенов в template, 36-80% общая экономия контекста
</details>

---

## 📝 Version

**Template Version:** 3.1 (User-Friendly Skills-Based)
**Дата:** 2025-11-21
**Changelog:**
- v3.1: Переработан для user-friendly интерфейса
  - Добавлена секция "## Задачи" для пользователя
  - Скрыты технические детали в `<details>`
  - Workflow описан естественным языком
  - Skills используются автоматически (под капотом)
- v3.0: Первая skills-based версия
  - Рефакторинг из 1213 строк в 393 строки
  - Вынесены инструкции в 6 специализированных скилов
  - Lazy loading скилов
