---
name: Structured Planning
description: Создание планов задач с адаптивной JSON Schema
version: 2.0.0
tags: [planning, json-schema, structured-output]
dependencies: [thinking-framework, adaptive-workflow]
files:
  templates: ./templates/*.json
  schemas: ./schemas/*.json
  examples: ./examples/*.md
user-invocable: false
---

# Structured Planning v2.0

Адаптивное планирование с выбором схемы по сложности задачи.

## Когда использовать

- После analysis thinking
- Для создания плана выполнения

## Выбор шаблона

| Complexity | Template | Schema |
|------------|----------|--------|
| minimal | `@template:task-plan-lite` | Нет валидации |
| standard | `@template:task-plan` | `@schema:task-plan` |
| complex | `@template:task-plan` + phases | `@schema:task-plan` |

## Шаблоны

### Minimal (task-plan-lite)

```json
{
  "task_plan_lite": {
    "task_name": "string",
    "files": ["file1.py", "file2.py"],
    "steps": ["step1", "step2"],
    "validation": "syntax_command"
  }
}
```

### Standard/Complex (task-plan)

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
    "git": {
      "branch_name": "feature/x",
      "commit_type": "feat",
      "commit_summary": "summary"
    }
  }
}
```

## Ключевые правила

- `acceptance_criteria`: минимум 1
- `execution_steps`: минимум 1 (было 2)
- `branch_name`: pattern `^(feature|fix|refactor)/`
- `commit_summary`: max 72 символа
- `prd_sections`: ОПЦИОНАЛЬНО (не required)
- `risks`: ОПЦИОНАЛЬНО

## Markdown Output

После JSON всегда выводить читаемый план:

```
## План: {task_name}

**Файлы:** {N} файлов
**Шагов:** {M}

### Изменения
- {file1} — {description}
- {file2} — {description}

### Шаги
1. {step1}
2. {step2}

### Git
- Branch: {branch_name}
- Commit: {commit_type}: {commit_summary}
```

## Примеры

- Простая задача: `@example:simple-task`
- Рефакторинг: `@example:refactoring`
- Многофазная: `@example:multi-phase`
