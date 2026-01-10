---
name: Validation Framework
description: Адаптивная валидация с поддержкой partial validation
version: 2.0.0
tags: [validation, testing, acceptance-criteria, quality]
dependencies: [structured-planning]
files:
  templates: ./templates/*.json
  schemas: ./schemas/*.json
  examples: ./examples/*.md
user-invocable: false
---

# Validation Framework v2.0

Адаптивная валидация с выбором режима по сложности задачи.

## Когда использовать

- После выполнения задачи (Phase 4)
- Перед git commit

## Режимы валидации

| Mode | Checks | Blocking |
|------|--------|----------|
| **lite** | syntax only | syntax |
| **standard** | syntax + acceptance | syntax, acceptance |
| **full** | all checks | all |

## Выбор режима

```
if complexity == "minimal":
  mode = "lite"
elif complexity == "standard":
  mode = "standard"
else:
  mode = "full"
```

## Шаблоны

### Lite (validation-lite)

```json
{
  "validation_lite": {
    "syntax_check": "passed|failed",
    "files_modified": ["file1.py"],
    "status": "PASSED|FAILED"
  }
}
```

### Full (validation-full)

```json
{
  "validation_results": {
    "acceptance_criteria": {
      "total": 2,
      "met": 2,
      "not_met": 0,
      "details": [...]
    },
    "prd_compliance": {
      "compliant": true,
      "conflicts": []
    },
    "syntax_checks": {
      "total_files": 2,
      "passed": 2,
      "failed": 0
    },
    "functional_checks": {
      "total": 1,
      "passed": 1,
      "failed": 0
    },
    "overall_status": "PASSED",
    "can_proceed": true,
    "blocking_issues": []
  }
}
```

## Validation Logic

```javascript
// Lite mode
status = syntax_check === "passed" ? "PASSED" : "FAILED"

// Full mode
overall_status = "PASSED" if (
  acceptance_criteria.not_met === 0 &&
  (prd_compliance.compliant || !has_prd) &&
  syntax_checks.failed === 0 &&
  functional_checks.failed === 0
)

can_proceed = overall_status === "PASSED"
```

## Syntax Commands

Используй: `@shared:syntax-commands`

## Markdown Output

```
═══════════════════════════════════════════════════════════
              ВАЛИДАЦИЯ: {status}
═══════════════════════════════════════════════════════════

SYNTAX: {passed}/{total} ✓
ACCEPTANCE: {met}/{total} ✓

{если FAILED}
🛑 BLOCKING:
- {issue1}
- {issue2}

═══════════════════════════════════════════════════════════
```

## Примеры

- Passed: `@example:passed`
- Failed: `@example:failed`
