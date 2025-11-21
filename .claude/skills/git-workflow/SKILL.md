---
name: Git Workflow
description: Стандартизированный git workflow с Conventional Commits, changelog generation и structured output
version: 1.0.0
author: Claude Code Team
tags: [git, conventional-commits, changelog, versioning, github, workflow]
dependencies: [structured-planning]
---

# Git Workflow

Автоматизация стандартизированного git workflow с Conventional Commits форматом, автоматической генерацией changelog entries и structured output для git operations. Обеспечивает консистентность commit messages и подготовку записей для GitHub Releases.

## Когда использовать этот скил

Используй этот скил когда нужно:
- Создать git commit с Conventional Commits форматом
- Сгенерировать changelog entry для GitHub Release
- Выполнить structured git operations (branch, commit, push) с JSON validation
- Определить правильный commit type (feat, fix, refactor, etc)
- Создать правильный branch name pattern (feature/, fix/, etc)
- Добавить Co-Authored-By footer для Claude Code commits
- Подготовить release notes

Скил автоматически вызывается при запросах типа:
- "Создай git commit для выполненной задачи"
- "Сгенерируй changelog entry для этого изменения"
- "Выполни git push с правильным commit message"
- "Подготовь release notes"

## Контекст проекта

### Философия Git Workflow

**Принципы:**
- **Conventional Commits:** Единый формат commit messages
- **Semantic Versioning:** Version bumps based on commit types
- **Changelog-driven:** Каждый commit генерирует changelog entry
- **Claude attribution:** Co-Authored-By: Claude footer
- **Structured operations:** Git commands через JSON validation

### Conventional Commits Format

```
<type>: <summary>

<optional body>

<optional footers>
```

**Commit Types:**
- **feat:** Новая функциональность (minor version bump)
- **fix:** Исправление ошибки (patch version bump)
- **refactor:** Рефакторинг без изменения функциональности
- **docs:** Только документация
- **chore:** Обслуживание, CI/CD, зависимости
- **test:** Добавление или исправление тестов
- **perf:** Оптимизация производительности
- **style:** Форматирование, whitespace (не меняет поведение)

### Branch Naming Pattern

```
<type>/<task-name>
```

**Примеры:**
- `feature/calculate-total`
- `fix/null-pointer-in-validator`
- `refactor/extract-order-validator`
- `docs/update-api-documentation`
- `chore/upgrade-dependencies`

### Semantic Versioning (SemVer)

```
MAJOR.MINOR.PATCH
```

- **MAJOR (v2.0.0):** Breaking changes (несовместимые изменения API)
- **MINOR (v1.2.0):** Новая функциональность (обратно совместимая)
- **PATCH (v1.2.1):** Bug fixes

**Commit type → Version:**
- `feat:` → MINOR bump
- `fix:` → PATCH bump
- `BREAKING CHANGE:` footer → MAJOR bump
- `refactor:`, `docs:`, `chore:` → no bump (до release)

## Шаблоны

### Шаблон 1: Commit Message (Conventional Format)

```
<type>: <summary> (max 72 chars)

<detailed description>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Примеры:**

**feat commit:**
```
feat: add calculate_total method to BudgetService

Implements calculation of total budget amounts from a list of BudgetFact
objects. Method accepts list[BudgetFact] and returns Decimal sum.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**fix commit:**
```
fix: handle None values in OrderValidator.validate_amount

Previously would crash with TypeError when amount is None.
Now returns ValidationError with appropriate message.

Fixes #123

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**refactor commit:**
```
refactor: extract OrderValidator from OrderService

Moves validation logic to separate class following Single Responsibility
Principle. No functional changes, all tests pass.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**BREAKING CHANGE commit:**
```
feat: change API response format for /orders endpoint

BREAKING CHANGE: Response now returns { "data": {...}, "meta": {...} }
instead of flat object. Clients must update to access data.orders.

Migration guide in docs/migrations/v2.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Шаблон 2: Git Commit JSON (Structured Output)

```json
{
  "git_commit": {
    "branch": "feature/task-name",
    "commit_hash": "abc123def456",
    "commit_type": "feat",
    "commit_summary": "add calculate_total method",
    "files_committed": [
      "backend/app/services/service.py",
      "backend/app/api/v1/endpoints/facts.py"
    ],
    "commit_status": "success",
    "pushed": true,
    "push_status": "success"
  }
}
```

**Fields:**
- `branch`: Текущая ветка
- `commit_hash`: SHA commit после успешного commit
- `commit_type`: Conventional commit type (feat, fix, etc)
- `commit_summary`: Первая строка commit message (без type:)
- `files_committed`: Список файлов в commit
- `commit_status`: "success" | "failed"
- `pushed`: boolean - был ли выполнен push
- `push_status`: "success" | "failed" (если pushed = true)

### Шаблон 3: Changelog Entry JSON

```json
{
  "changelog_entry": {
    "category": "Features",
    "title": "Добавлен метод calculate_total",

    "changes": [
      "✨ Создан метод calculate_total в BudgetService",
      "🔧 Обновлен endpoint для использования нового метода"
    ],

    "user_impact": "Пользователи получат более точный расчет общей суммы",

    "technical_details": {
      "files_changed": [
        "backend/app/services/budget_service.py",
        "backend/app/api/v1/endpoints/facts.py"
      ],
      "prd_sections": ["FR-042"],
      "commits": ["abc123f"]
    },

    "breaking_changes": null
  }
}
```

**Changelog Categories:**
- **Features** - новая функциональность (feat:)
- **Bug Fixes** - исправления ошибок (fix:)
- **Performance** - оптимизация производительности (perf:)
- **Refactoring** - рефакторинг без изменения функциональности (refactor:)
- **Documentation** - только документация (docs:)
- **Infrastructure** - DevOps, CI/CD, deployment (chore:)

### Шаблон 4: Changelog Entry Markdown

```markdown
### [Category] Title

**Изменения:**
- ✨ Новая функциональность
- 🔧 Изменения существующего
- 🐛 Исправления ошибок
- 📝 Обновления документации

**Влияние на пользователей:**
[Что изменится для пользователя]

**Технические детали:**
- Файлы: `[список файлов]`
- PRD: [ссылка на секцию PRD]
- Commits: [commit hashes]

**Breaking Changes:** [Да/Нет] [Описание если есть]
```

### Шаблон 5: Git Commands Sequence

```bash
# 1. Create branch
git checkout master
git checkout -b <type>/<task-name>

# 2. Make changes...

# 3. Stage files
git add <files>

# 4. Commit with conventional format
git commit -m "<type>: <summary>

<body>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# 5. Push
git push -u origin <type>/<task-name>

# 6. Verify
git log -1
git branch --show-current
```

### Шаблон 6: GitHub Release Notes Structure

```markdown
## v1.3.0 - 2025-11-20

### Features
#### ✨ Feature Title
[Changelog entry markdown]

#### ✨ Another Feature
[Changelog entry markdown]

### Bug Fixes
#### 🐛 Fix Title
[Changelog entry markdown]

### Performance
#### ⚡ Performance Improvement
[Changelog entry markdown]

### Refactoring
#### ♻️ Refactoring Title
[Changelog entry markdown]

### Documentation
#### 📝 Documentation Update
[Changelog entry markdown]

### Infrastructure
#### 🔧 Infrastructure Change
[Changelog entry markdown]
```

## Проверочный чеклист

После создания git commit проверь:

**Commit Message:**
- [ ] Commit type корректен (feat, fix, refactor, etc)
- [ ] Summary max 72 символа
- [ ] Summary в imperative mood ("add" не "added")
- [ ] Body объясняет "почему", не "что" (если нужен)
- [ ] Footer с Co-Authored-By добавлен
- [ ] Footer с 🤖 Generated добавлен
- [ ] BREAKING CHANGE: footer если есть breaking changes

**Branch Name:**
- [ ] Соответствует паттерну `<type>/<task-name>`
- [ ] Task name в kebab-case
- [ ] Type соответствует commit type

**Git Operations:**
- [ ] commit_status = "success"
- [ ] commit_hash получен (не пустой)
- [ ] pushed = true (если нужен push)
- [ ] push_status = "success" (если pushed)
- [ ] files_committed список не пустой

**Changelog Entry:**
- [ ] Category соответствует commit type
- [ ] Title краткий и понятный
- [ ] Changes используют emoji (✨🔧🐛📝)
- [ ] User impact объясняет влияние для пользователя
- [ ] Technical details содержат файлы, PRD, commits
- [ ] Breaking changes указаны если есть

## Связанные скилы

- **structured-planning**: plan содержит git секцию для этого скила
- **validation-framework**: валидация перед git commit
- **approval-gates**: может требовать approval перед push
- **phase-execution**: использует git-workflow для создания phase commits
- **task-decomposition**: генерирует branch_name для master plan

## Примеры использования

### Пример 1: Feat commit (новая функциональность)

**Контекст:**
Добавлен метод calculate_total в BudgetService.

**Claude использует git-workflow скил:**

```bash
# 1. Создать branch
git checkout master
git checkout -b feature/calculate-total

# 2. Files already modified...

# 3. Stage files
git add backend/app/services/budget_service.py

# 4. Commit
git commit -m "feat: add calculate_total method to BudgetService

Implements calculation of total budget amounts from list of BudgetFact.
Method accepts list[BudgetFact] and returns Decimal sum.

Resolves FR-042

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# 5. Push
git push -u origin feature/calculate-total
```

**Structured Output:**
```json
{
  "git_commit": {
    "branch": "feature/calculate-total",
    "commit_hash": "a1b2c3d4e5f6",
    "commit_type": "feat",
    "commit_summary": "add calculate_total method to BudgetService",
    "files_committed": ["backend/app/services/budget_service.py"],
    "commit_status": "success",
    "pushed": true,
    "push_status": "success"
  }
}
```

**Changelog Entry:**
```markdown
### [Features] Добавлен метод calculate_total в BudgetService

**Изменения:**
- ✨ Создан метод calculate_total для расчета общей суммы бюджетных фактов

**Влияние на пользователей:**
Пользователи получат точный расчет общей суммы в отчетах

**Технические детали:**
- Файлы: `backend/app/services/budget_service.py`
- PRD: FR-042
- Commits: a1b2c3d

**Breaking Changes:** Нет
```

### Пример 2: Fix commit (исправление ошибки)

**Контекст:**
Исправлен NullPointerError в OrderValidator.

**Claude использует git-workflow скил:**

```bash
git checkout master
git checkout -b fix/null-pointer-in-validator

# Files modified...

git add backend/app/validators/order_validator.py

git commit -m "fix: handle None values in OrderValidator.validate_amount

Previously would crash with TypeError when amount is None.
Now returns ValidationError with appropriate message.

Fixes #123

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

git push -u origin fix/null-pointer-in-validator
```

**Changelog Entry:**
```markdown
### [Bug Fixes] Исправлен NullPointerError в OrderValidator

**Изменения:**
- 🐛 Добавлена обработка None values в validate_amount
- 🔧 ValidationError теперь возвращается вместо TypeError

**Влияние на пользователей:**
Исправлен crash при валидации заказов с пустой суммой

**Технические детали:**
- Файлы: `backend/app/validators/order_validator.py`
- PRD: NFR-008 (Error Handling)
- Commits: b2c3d4e
- Fixes: #123

**Breaking Changes:** Нет
```

### Пример 3: Refactor commit с multiple files

**Контекст:**
Рефакторинг: выделен OrderValidator из OrderService (3 файла).

**Claude использует git-workflow скил:**

```bash
git checkout master
git checkout -b refactor/extract-order-validator

# Files created/modified...

git add backend/app/validators/order_validator.py \
        backend/app/services/order_service.py \
        backend/app/api/v1/endpoints/orders.py

git commit -m "refactor: extract OrderValidator from OrderService

Moves validation logic to separate class following Single Responsibility
Principle. No functional changes, all tests pass.

Changes:
- Created OrderValidator class with validate_order method
- Updated OrderService to use OrderValidator
- Updated orders endpoints to import OrderValidator

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

git push -u origin refactor/extract-order-validator
```

**Structured Output:**
```json
{
  "git_commit": {
    "branch": "refactor/extract-order-validator",
    "commit_hash": "c3d4e5f6a7b8",
    "commit_type": "refactor",
    "commit_summary": "extract OrderValidator from OrderService",
    "files_committed": [
      "backend/app/validators/order_validator.py",
      "backend/app/services/order_service.py",
      "backend/app/api/v1/endpoints/orders.py"
    ],
    "commit_status": "success",
    "pushed": true,
    "push_status": "success"
  }
}
```

### Пример 4: BREAKING CHANGE commit

**Контекст:**
Изменен формат API response для /orders endpoint.

**Claude использует git-workflow скил:**

```bash
git checkout master
git checkout -b feature/restructure-orders-api

# Files modified...

git add backend/app/api/v1/endpoints/orders.py \
        docs/migrations/v2.md

git commit -m "feat: restructure API response format for /orders endpoint

BREAKING CHANGE: Response now returns { \"data\": {...}, \"meta\": {...} }
instead of flat object. Clients must update to access data.orders.

Changes:
- Wrapped response in data/meta structure
- Added pagination metadata to meta
- Added migration guide

Migration guide: docs/migrations/v2.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

git push -u origin feature/restructure-orders-api
```

**Changelog Entry:**
```markdown
### [Features] Реструктуризация API response format для /orders

**Изменения:**
- ✨ Новый формат ответа с data/meta структурой
- 📝 Добавлена миграционная документация

**Влияние на пользователей:**
⚠️ **BREAKING CHANGE**: Клиенты должны обновить код для доступа к data.orders вместо прямого объекта.

**Технические детали:**
- Файлы: `backend/app/api/v1/endpoints/orders.py`, `docs/migrations/v2.md`
- PRD: FR-055
- Commits: d4e5f6a

**Breaking Changes:** ДА
- Формат response изменен с `{orders: [...]}` на `{data: {orders: [...]}, meta: {...}}`
- Миграция: См. docs/migrations/v2.md
- Требуется версия клиента: v2.0.0+
```

---

## Phase-Based Git Workflow

### Когда использовать Phase-Based Git Workflow

Используй phase-based git workflow когда:
- Задача разбита на несколько фаз (phase-based execution)
- Каждая фаза завершается отдельным коммитом
- Нужна проверка branch context перед выполнением фазы > 1
- Требуется git commit validation с commit_hash проверкой

### Шаблон 5: Phase Commit

**Назначение:** Создание git commit после завершения phase execution.

**Входные данные:** `phase_metadata.commit_message` (type, summary, body)

**Actions:**
```bash
# Добавить измененные файлы
git add {файлы из completion_status.steps_completed[].files_changed}

# Создать коммит
git commit -m "{commit_message.type}: {commit_message.summary}

{commit_message.body}

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Получить commit hash
commit_hash=$(git log -1 --format=%H)

# Опционально: Push
# git push origin {branch_name}
```

**Правила:**
- Commit summary max 72 символа (enforced by phase_metadata schema)
- Body может быть многострочным
- ВСЕГДА добавляется Co-Authored-By footer
- Commit type из enum: feat, fix, refactor, docs, chore, test

**Пример:**
```bash
git add backend/app/services/service_a.py backend/app/schemas/schema_a.py

git commit -m "feat: add service A with basic logic

- Created service A
- Implemented basic methods: create(), get(), delete()
- Added validation logic

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Шаблон 6: Git Commit Validation JSON

**Назначение:** Валидация git commit после phase execution.

```json
{
  "git_commit": {
    "branch": "feature/task-name",
    "commit_hash": "abc123def456",
    "commit_type": "feat",
    "commit_summary": "add service A with basic logic",
    "files_committed": [
      "backend/app/services/service_a.py",
      "backend/app/schemas/schema_a.py"
    ],
    "commit_status": "success",
    "pushed": false,
    "push_status": null
  }
}
```

**JSON Schema:**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "git_commit": {
      "type": "object",
      "properties": {
        "branch": {"type": "string"},
        "commit_hash": {"type": "string", "pattern": "^[a-f0-9]{7,40}$"},
        "commit_type": {"type": "string", "enum": ["feat", "fix", "refactor", "docs", "chore", "test"]},
        "commit_summary": {"type": "string"},
        "files_committed": {
          "type": "array",
          "minItems": 0,
          "items": {"type": "string"}
        },
        "commit_status": {"type": "string", "enum": ["success", "failed"]},
        "pushed": {"type": "boolean"},
        "push_status": {"type": ["string", "null"], "enum": ["success", "failed", null]}
      },
      "required": [
        "branch", "commit_hash", "commit_type", "commit_summary",
        "files_committed", "commit_status", "pushed"
      ]
    }
  },
  "required": ["git_commit"]
}
```

**Validation Logic:**
```javascript
// commit_hash должен быть валидным (7-40 hex символов)
const commit_hash_valid = /^[a-f0-9]{7,40}$/.test(commit_hash)

// commit_status определяется успехом команды
commit_status = (commit_command_exit_code === 0) ? "success" : "failed"

// push_status определяется pushed флагом
push_status = pushed ?
  (push_command_exit_code === 0 ? "success" : "failed") :
  null
```

**Exit Conditions:**
- ✓ `commit_status` = "success"
- ✓ `commit_hash` не пустой и соответствует паттерну
- ✓ Если `pushed` = true, то `push_status` = "success"

**Violation Action:**
- commit_status = "failed" → STOP, использовать error-handling: GIT_COMMIT_FAILED
- commit_hash invalid → STOP, проверить git log
- push_status = "failed" → STOP, проверить git remote

### Шаблон 7: Branch Context Check

**Назначение:** Проверка branch context перед выполнением фазы > 1.

**Когда использовать:** Перед выполнением Phase 2, 3, 4, 5 (НЕ для Phase 1).

**THINKING template:**
```xml
<thinking>
ПРОВЕРКА КОНТЕКСТА ВЕТКИ:
Текущая ветка: [git branch --show-current]
Ожидаемая ветка: [phase_metadata.context.branch_name]

Коммиты в ветке: [git log --oneline {base_branch}..HEAD]

Изменения в ветке: [git diff {base_branch}...HEAD --stat]

АНАЛИЗ:
- Предыдущие фазы выполнены? [проверить по коммитам]
- Есть незакоммиченные изменения? [git status]
- Готовы к выполнению текущей фазы? [да/нет]
</thinking>
```

**Actions:**
```bash
# Проверить текущую ветку
current_branch=$(git branch --show-current)
expected_branch="${phase_metadata.context.branch_name}"

if [ "$current_branch" != "$expected_branch" ]; then
  echo "✗ Неправильная ветка: $current_branch (ожидалось: $expected_branch)"
  exit 1
fi

# Проверить git status
git_status=$(git status --porcelain)
if [ -n "$git_status" ]; then
  echo "✗ Есть незакоммиченные изменения"
  git status
  exit 1
fi

# Проверить коммиты предыдущих фаз
base_branch="${phase_metadata.context.base_branch}"
commits_count=$(git log --oneline ${base_branch}..HEAD | wc -l)
expected_commits=$((phase_metadata.phase_number - 1))

if [ $commits_count -lt $expected_commits ]; then
  echo "✗ Недостаточно коммитов: $commits_count (ожидалось: $expected_commits)"
  exit 1
fi

# Показать изменения в ветке
echo "✓ Branch context OK"
git log --oneline ${base_branch}..HEAD
git diff ${base_branch}...HEAD --stat
```

**Exit Conditions:**
- ✓ На правильной ветке (current_branch === expected_branch)
- ✓ Нет незакоммиченных изменений (git status clean)
- ✓ Предыдущие фазы выполнены (commits_count >= expected_commits)

**Violation Actions:**
- Неправильная ветка → STOP, использовать error-handling: WRONG_BRANCH
- Незакоммиченные изменения → STOP, использовать error-handling: UNCOMMITTED_CHANGES
- Предыдущие фазы не выполнены → STOP, выполнить предыдущие фазы сначала

**JSON Output:**
```json
{
  "branch_context": {
    "current_branch": "feature/task-name",
    "expected_branch": "feature/task-name",
    "branch_match": true,

    "git_status": "clean",
    "uncommitted_changes": false,

    "commits_in_branch": 2,
    "expected_commits": 2,
    "commits_match": true,

    "context_valid": true,
    "blocking_issues": []
  }
}
```

---

## Часто задаваемые вопросы

**Q: Commit summary должен быть в прошедшем времени?**

A: НЕТ! Используй imperative mood (повелительное наклонение):
- ✅ "add calculate_total method"
- ✅ "fix null pointer in validator"
- ❌ "added calculate_total method"
- ❌ "fixed null pointer"

**Q: Когда использовать body в commit message?**

A: Body нужен когда:
- Изменение неочевидно и требует объяснения "почему"
- Есть несколько связанных изменений
- Нужно сослаться на issue (Fixes #123)
- BREAKING CHANGE (обязательно в footer)

Для простых изменений body не обязателен.

**Q: Co-Authored-By обязателен для всех commits?**

A: ДА для commits созданных Claude Code! Это указывает что commit сгенерирован AI.

**Q: Можно ли несколько commit types в одном commit?**

A: НЕТ! Один commit = один type. Если есть feat + fix, сделай 2 отдельных commits.

**Q: Как определить что это BREAKING CHANGE?**

A: BREAKING CHANGE если:
- API изменен несовместимо (response format, endpoint URL)
- Удален публичный метод/функция
- Изменена сигнатура публичного API
- Требуется миграция на стороне клиента

**Q: Changelog entry создается для каждого commit?**

A: Да! Каждый commit может потенциально попасть в changelog. При создании GitHub Release вручную собираются все entries с последнего релиза.

**Q: git_commit JSON обязателен после каждого commit?**

A: Да! Structured output гарантирует что commit успешен (commit_status = "success", push_status = "success").

**Q: Что делать если push failed?**

A: В git_commit JSON:
```json
{
  "git_commit": {
    ...
    "pushed": false,
    "push_status": "failed"
  }
}
```

Action: STOP, проверить ошибку (git status, git log), исправить, RETRY push.

**Q: Branch должен удаляться после merge?**

A: Обычно да (GitHub может auto-delete после PR merge). Но это вне scope git-workflow скила - это делается через GitHub UI или CI/CD.

**Q: Semver version bump происходит автоматически?**

A: НЕТ. Version bump делается вручную при создании GitHub Release:
- Собрать все commits с последнего релиза
- Определить highest commit type (BREAKING → major, feat → minor, fix → patch)
- Создать новый tag (v1.2.0 → v1.3.0 или v2.0.0)

**Q: Emoji в changelog обязательны?**

A: Рекомендуются! Emoji делают changelog более читаемым:
- ✨ Новая функциональность
- 🔧 Изменения существующего
- 🐛 Bug fix
- 📝 Документация
- ⚡ Performance
- ♻️ Refactoring

---

### Phase-Based Workflow FAQ

**Q: Каждая фаза должна иметь отдельный commit?**

A: ДА! Один phase = один commit. Это обеспечивает:
- Атомарность изменений (можно откатить одну фазу)
- Понятную историю (каждый commit = логически завершенный шаг)
- Возможность Code Review по фазам

**Q: Commit message для phase должен упоминать номер фазы?**

A: НЕТ! Commit message должен описывать ЧТО сделано, не "Phase 2".

❌ ПЛОХО:
```
feat: phase 2 implementation
```

✅ ХОРОШО:
```
feat: add order validation with business rules

- Implement OrderValidator
- Add validation rules
```

**Q: Как проверить что я на правильной ветке перед выполнением фазы?**

A: Используй **Шаблон 7: Branch Context Check**:
1. Прочитать phase_metadata.context.branch_name
2. Выполнить `git branch --show-current`
3. Сравнить с ожидаемым
4. Если не совпадает → STOP (BLOCKING)

**Q: Что если я на master вместо feature branch?**

A: STOP НЕМЕДЛЕННО! Это критичная ошибка:
```
❌ ОШИБКА: Wrong branch
Проблема: Ожидалась ветка "feature/task-name", текущая "master"
Действие: STOP (BLOCKING) - checkout правильную ветку
```

**Q: git_commit JSON нужен после каждого phase commit?**

A: ДА! Это обязательная часть Phase-Based Workflow. git_commit JSON (Шаблон 6) гарантирует:
- Commit успешен (commit_status = "success")
- Commit hash записан (для traceability)
- Правильные файлы committed

**Q: Нужен ли push после каждой фазы?**

A: Зависит от контекста:
- **Рекомендуется:** push после каждой фазы для backup
- **Допустимо:** batch push всех фаз в конце (если быстрая задача)
- **Обязательно:** push перед PR creation

**Q: Как обрабатывать uncommitted changes перед фазой?**

A: Branch Context Check (Шаблон 7) проверяет это:
```bash
git status --porcelain
```

Если есть uncommitted changes → STOP (BLOCKING):
- Либо commit их (если часть текущей фазы)
- Либо stash (если не относятся к задаче)
- Либо discard (если мусор)
