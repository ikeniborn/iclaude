# Task Execution Template v4.0

**Назначение:** Адаптивный шаблон для задач любой сложности с lazy-loading skills и автоматическим определением контекста.

**Для пользователя:** Просто опишите задачи. Claude автоматически определит сложность, выберет оптимальный workflow и выполнит задачу.

---

## Задачи

[Опишите задачи здесь]

```
Примеры:
1. Добавить метод calculate_total() в BudgetService
2. Рефакторинг: вынести валидацию в отдельный класс
3. Исправить bug с null pointer в validator
```

**Acceptance Criteria (опционально):**
```
- Метод возвращает корректную сумму
- Все тесты проходят
```

---

## Workflow (автоматический)

<details>
<summary>PHASE 0: КОНТЕКСТ И АДАПТАЦИЯ (автоматически)</summary>

### 0.1 Определение контекста проекта

**Skill:** `@skill:context-awareness`

Claude автоматически определяет:
- Язык проекта (Python/JS/Go/Rust/Bash)
- Framework (FastAPI/Django/Express/React)
- Тестовый framework (pytest/jest)
- Наличие PRD (`docs/prd/`)
- Code style (PEP8/Prettier)

**Output:**
```json
{
  "project_context": {
    "language": "python",
    "framework": "fastapi",
    "test_framework": "pytest",
    "has_prd": true,
    "syntax_command": "python -m py_compile"
  }
}
```

### 0.2 Определение сложности задачи

**Skill:** `@skill:adaptive-workflow`

| Сложность | Критерии | Workflow |
|-----------|----------|----------|
| **minimal** | <3 файлов, 1 функция | Упрощённый (без approval) |
| **standard** | 3-5 файлов, 1 компонент | Полный lite workflow |
| **complex** | >5 файлов, несколько компонентов | Phase-based workflow |

**Output:**
```json
{
  "complexity": "standard",
  "skip": [],
  "workflow": "lite"
}
```

</details>

---

<details>
<summary>PHASE 1: АНАЛИЗ И ПЛАНИРОВАНИЕ</summary>

### 1.1 Анализ задачи

**Skill:** `@skill:thinking-framework` → `@template:analysis`

```xml
<thinking type="analysis">
ЗАДАЧА: [из секции "Задачи"]
КОНТЕКСТ: [текущее состояние кода]
КОМПОНЕНТЫ: [затрагиваемые файлы/модули]
ACCEPTANCE CRITERIA: [из user input или определить]
</thinking>
```

### 1.2 PRD Compliance (если has_prd=true)

**Условие:** Выполняется только если `project_context.has_prd = true`

```xml
<thinking type="analysis">
PRD СЕКЦИИ: [релевантные секции]
ALIGNMENT: [соответствие требованиям]
CONFLICTS: [конфликты если есть]
</thinking>
```

**Skip:** Если PRD отсутствует, используются general best practices.

### 1.3 Выбор решения

**Skill:** `@skill:thinking-framework` → `@template:decision`

```xml
<thinking type="decision">
ОПЦИИ:
  1. [вариант] - Плюсы: [...] Минусы: [...]
  2. [вариант] - Плюсы: [...] Минусы: [...]
ВЫБОР: [вариант N]
ОБОСНОВАНИЕ: [почему]
</thinking>
```

### 1.4 Создание плана

**Skill:** `@skill:structured-planning` → `@template:task-plan`

**Minimal complexity** — упрощённый план:
```json
{
  "task_plan_lite": {
    "task_name": "string",
    "files_to_change": ["file1.py", "file2.py"],
    "steps": ["step1", "step2"],
    "validation": "syntax_command"
  }
}
```

**Standard/Complex** — полный план:
```json
{
  "task_plan": {
    "task_name": "string",
    "problem": "string",
    "solution": "string",
    "acceptance_criteria": ["AC1", "AC2"],
    "files_to_change": [
      {"file_path": "path", "change_type": "modify", "description": "desc"}
    ],
    "execution_steps": [
      {"step_number": 1, "description": "desc", "actions": ["a1"], "validation": "cmd"}
    ],
    "risks": [{"risk": "r", "mitigation": "m"}],
    "git": {"branch_name": "feature/x", "commit_type": "feat", "commit_summary": "summary"}
  }
}
```

**Пример:** `@example:structured-planning/simple-task`

</details>

---

<details>
<summary>PHASE 2: СОГЛАСОВАНИЕ (адаптивное)</summary>

### Для minimal complexity — SKIP

Approval gate пропускается. Сразу к выполнению.

### Для standard/complex — Approval Gate

**Skill:** `@skill:approval-gates` → `@template:approval-lite`

```
## План готов

**Задача:** {task_name}
**Изменится:** {N} файлов
**Шагов:** {M}

**Изменения:**
- {file1} — {описание}
- {file2} — {описание}

---
Выполнить? [yes/no/modify]
```

**Exit:** `approval.response = "yes"`
**Stop:** `approval.response = "no"`
**Modify:** Вернуться к планированию

</details>

---

<details>
<summary>PHASE 3: ВЫПОЛНЕНИЕ</summary>

### 3.1 Выполнение шагов

Для каждого `step` в плане:

1. Выполнить actions
2. Запустить syntax check (из `project_context.syntax_command`)
3. Вывести статус: `✓ Шаг {N}: {description}`

### 3.2 Правила кода

**DO:**
- Писать чистый, читаемый код
- Следовать стилю проекта
- Добавлять комментарии только для сложной логики

**DON'T:**
- Комментировать очевидный код
- Оставлять закомментированный код
- Добавлять избыточную документацию

### 3.3 Code Review (для standard/complex)

**Skill:** `@skill:code-review`

Автоматическая проверка:
- Security (OWASP Top 10)
- Code smells
- Error handling
- Type safety

**Output:**
```json
{
  "review": {
    "score": 85,
    "blocking_issues": [],
    "suggestions": ["Consider adding type hints"]
  }
}
```

</details>

---

<details>
<summary>PHASE 4: ВАЛИДАЦИЯ (адаптивная)</summary>

### Для minimal complexity — Quick Validation

**Skill:** `@skill:validation-framework` → `@template:validation-lite`

```json
{
  "validation_lite": {
    "syntax_check": "passed",
    "files_modified": ["file1.py"],
    "status": "PASSED"
  }
}
```

### Для standard/complex — Full Validation

**Skill:** `@skill:validation-framework` → `@template:validation-full`

```json
{
  "validation_results": {
    "acceptance_criteria": {"total": 2, "met": 2, "not_met": 0},
    "prd_compliance": {"compliant": true},
    "syntax_checks": {"total_files": 2, "passed": 2, "failed": 0},
    "functional_checks": {"total": 1, "passed": 1, "failed": 0},
    "overall_status": "PASSED",
    "can_proceed": true
  }
}
```

**Пример PASSED:** `@example:validation-framework/passed`
**Пример FAILED:** `@example:validation-framework/failed`

### При FAILED

**Skill:** `@skill:error-handling`

1. Определить тип ошибки
2. Попытка исправления (max 2 retry)
3. Если не удалось → `@skill:rollback-recovery`

</details>

---

<details>
<summary>PHASE 5: ФИНАЛИЗАЦИЯ</summary>

### 5.1 Git Commit

**Skill:** `@skill:git-workflow` → `@template:commit`

```bash
git add {files}
git commit -m "{type}: {summary}

{body}

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### 5.2 Summary

```
═══════════════════════════════════════════════════════════
                    ✅ ЗАДАЧА ЗАВЕРШЕНА
═══════════════════════════════════════════════════════════

СТАТУС: ✓ COMPLETED

СДЕЛАНО:
- {список изменений}

ФАЙЛЫ:
- {file1} (modified)
- {file2} (created)

GIT:
- Branch: {branch}
- Commit: {hash}

═══════════════════════════════════════════════════════════
```

</details>

---

## Skills Architecture v2.0

### Структура декомпозированных Skills

```
skills/
├── _shared/                        # Переиспользуемые компоненты
│   ├── syntax-commands.json        # Команды по языкам
│   ├── commit-types.json           # Conventional commits
│   └── validation-logic.md         # Общая логика
│
├── context-awareness/              # NEW: Определение контекста
│   ├── SKILL.md                    # Core (~30 строк)
│   └── templates/
│       └── project-context.json
│
├── adaptive-workflow/              # NEW: Выбор сложности
│   ├── SKILL.md                    # Core (~40 строк)
│   └── templates/
│       └── complexity-rules.json
│
├── thinking-framework/             # Оптимизированный (3 шаблона)
│   ├── SKILL.md                    # Core (~50 строк)
│   ├── templates/
│   │   ├── analysis.xml
│   │   ├── decision.xml
│   │   └── risk.xml
│   └── examples/
│       └── *.md
│
├── structured-planning/            # С гибкой schema
│   ├── SKILL.md                    # Core (~50 строк)
│   ├── templates/
│   │   ├── task-plan.json
│   │   ├── task-plan-lite.json
│   │   └── phase-metadata.json
│   ├── schemas/
│   │   └── task-plan.schema.json
│   └── examples/
│       ├── simple-task.md
│       └── refactoring.md
│
├── validation-framework/           # С partial validation
│   ├── SKILL.md                    # Core (~50 строк)
│   ├── templates/
│   │   ├── validation-full.json
│   │   └── validation-lite.json
│   ├── schemas/
│   │   └── validation.schema.json
│   └── examples/
│       ├── passed.md
│       └── failed.md
│
├── code-review/                    # NEW: Автоматический review
│   ├── SKILL.md
│   ├── templates/
│   │   └── review-result.json
│   └── rules/
│       ├── security.md
│       └── code-quality.md
│
├── git-workflow/
│   ├── SKILL.md
│   ├── templates/
│   │   └── commit-message.txt
│   └── examples/
│       └── conventional-commits.md
│
├── approval-gates/
│   ├── SKILL.md
│   └── templates/
│       ├── approval-full.md
│       └── approval-lite.md
│
├── error-handling/
│   ├── SKILL.md
│   └── templates/
│       └── error-types.json
│
└── rollback-recovery/              # NEW: Откат при ошибках
    ├── SKILL.md
    └── templates/
        └── rollback-strategies.json
```

### Загрузка Skills (Lazy Loading)

```
Сценарий: Простая задача (minimal complexity)

Загружается:
1. context-awareness/SKILL.md        (~30 строк)
2. adaptive-workflow/SKILL.md        (~40 строк)
3. structured-planning/SKILL.md      (~50 строк)
4. structured-planning/templates/task-plan-lite.json
5. validation-framework/SKILL.md     (~50 строк)
6. validation-framework/templates/validation-lite.json
7. git-workflow/SKILL.md             (~50 строк)

Total: ~300 строк (вместо 8677 в монолите)
Экономия: 96%
```

---

## Error Handling

<details>
<summary>Обработка ошибок</summary>

**Skill:** `@skill:error-handling`

| Ошибка | Action | Max Retries |
|--------|--------|-------------|
| SYNTAX_ERROR | BLOCKING, исправить | 2 |
| VALIDATION_FAILED | RETRY | 2 |
| PRD_CONFLICT | ASK user | 0 |
| APPROVAL_REJECTED | STOP | 0 |
| GIT_FAILED | STOP | 0 |

### При превышении retries

**Skill:** `@skill:rollback-recovery`

```json
{
  "rollback": {
    "strategy": "git_reset_soft",
    "files_restored": ["file1.py"],
    "status": "rolled_back"
  }
}
```

</details>

---

## Конфигурация

<details>
<summary>Настройки (для разработчиков)</summary>

### Skills (автоматические)
- context-awareness
- adaptive-workflow
- thinking-framework
- structured-planning
- validation-framework
- code-review (standard/complex only)
- git-workflow
- approval-gates (standard/complex only)
- error-handling
- rollback-recovery

### Режимы валидации

```yaml
validation_modes:
  minimal:
    required: [syntax_checks]
    skip: [prd_compliance, functional_checks, approval]

  standard:
    required: [syntax_checks, acceptance_criteria]
    optional: [prd_compliance, functional_checks]

  complex:
    required: [all]
    code_review: true
```

### Автоопределение PRD

```yaml
prd_detection:
  paths:
    - docs/prd/
    - docs/PRD.md
    - PRD.md
  fallback: general_best_practices
```

</details>

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| v4.0 | 2024-12 | Адаптивный workflow, декомпозированные skills, lazy loading |
| v3.1 | 2024-11 | User-friendly интерфейс, skills-based |
| v3.0 | 2024-11 | Первая skills-based версия |
| v2.0 | 2024-10 | Монолитный шаблон (1213 строк) |

### Ключевые улучшения v4.0

1. **Адаптивность**: Автоматический выбор сложности workflow
2. **Context Awareness**: Определение языка, framework, наличия PRD
3. **Lazy Loading**: Skills загружаются по необходимости (экономия 96%)
4. **Code Review**: Автоматический review перед commit
5. **Rollback Recovery**: Механизм отката при критических ошибках
6. **Упрощённый Thinking**: 3 шаблона вместо 8
7. **Опциональный PRD**: Работает без PRD документации
8. **Гибкая валидация**: Partial validation для простых задач

---

## Quick Reference

### Ссылки на Skills

```
@skill:name           → Загрузить SKILL.md
@template:skill/name  → Загрузить template
@schema:skill/name    → Загрузить JSON schema
@example:skill/name   → Загрузить пример
@shared:name          → Загрузить из _shared/
```

### Workflow по сложности

| Complexity | Phases | Approval | Code Review | PRD Check |
|------------|--------|----------|-------------|-----------|
| minimal | 0,1,3,4,5 | Skip | Skip | Skip |
| standard | All | Yes | Optional | If exists |
| complex | All + Phases | Yes | Yes | If exists |

### Команды syntax check

```json
{
  "python": "python -m py_compile {file}",
  "javascript": "node --check {file}",
  "typescript": "tsc --noEmit {file}",
  "bash": "bash -n {file}",
  "go": "go build {file}",
  "rust": "cargo check"
}
```
