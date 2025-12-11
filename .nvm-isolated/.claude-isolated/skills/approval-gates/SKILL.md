---
name: Approval Gates
description: Упрощённые approval gates для подтверждения плана
version: 2.0.0
tags: [approval, confirmation, user-interaction]
dependencies: [structured-planning]
files:
  templates: ./templates/*.md
---

# Approval Gates v2.0

Упрощённые, user-friendly approval gates.

## Когда использовать

- После создания плана (standard/complex only)
- **SKIP** для minimal complexity

## Шаблоны

### Lite (approval-lite)

Для standard complexity — компактный формат:

```markdown
## План готов

**Задача:** {task_name}
**Изменится:** {N} файлов
**Шагов:** {M}

**Изменения:**
- {file1} — {description}
- {file2} — {description}

---
Выполнить? [yes/no/modify]
```

### Full (approval-full)

Для complex/phase-based — детальный формат:

```markdown
## План готов

**Задача:** {task_name}
**Сложность:** complex
**Фаз:** {N}

### Фазы:
1. {phase1} — {N} шагов
2. {phase2} — {N} шагов

### Файлы ({total}):
- {file1} [{change_type}] — {description}
- {file2} [{change_type}] — {description}

### Риски:
- {risk1} → {mitigation}

---
Выполнить? [yes/no/modify]
```

## Response Handling

| Response | Action |
|----------|--------|
| `yes` | Proceed to execution |
| `no` | STOP, cancel task |
| `modify` | Return to planning |

## Output

```json
{
  "approval": {
    "response": "yes|no|modify",
    "timestamp": "ISO8601",
    "plan_hash": "md5 of plan"
  }
}
```

## Auto-Skip Rules

```yaml
skip_approval_when:
  - complexity == "minimal"
  - user_config.auto_approve == true
  - CI/CD environment detected
```
