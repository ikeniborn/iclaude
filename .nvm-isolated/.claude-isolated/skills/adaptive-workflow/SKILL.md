---
name: Adaptive Workflow
description: Автоматический выбор сложности workflow
version: 1.0.0
tags: [workflow, complexity, adaptation, optimization]
dependencies: [context-awareness]
files:
  templates: ./templates/*.json
---

# Adaptive Workflow

Автоматическое определение сложности задачи и выбор оптимального workflow.

## Когда использовать

- После context-awareness (Phase 0)
- Для каждой новой задачи

## Уровни сложности

| Level | Критерии | Workflow |
|-------|----------|----------|
| **minimal** | <3 файлов, 1 функция, нет breaking changes | Упрощённый |
| **standard** | 3-5 файлов, 1 компонент | Полный lite |
| **complex** | >5 файлов, несколько компонентов, breaking changes | Phase-based |

## Алгоритм определения

```
1. Подсчитать files_to_change
2. Определить количество компонентов
3. Проверить на breaking changes
4. Оценить estimated_complexity

complexity =
  if files < 3 AND components == 1 AND !breaking_changes:
    "minimal"
  elif files <= 5 AND components <= 2:
    "standard"
  else:
    "complex"
```

## Output

Используй шаблон: `@template:complexity-result`

## Skip Rules

```yaml
minimal:
  skip:
    - approval_gate
    - prd_compliance
    - code_review
    - changelog
  keep:
    - syntax_check
    - basic_validation

standard:
  skip: []
  optional:
    - code_review
    - prd_compliance (if has_prd)

complex:
  skip: []
  required:
    - all phases
    - code_review
    - prd_compliance (if has_prd)
```

## Quick Reference

```json
{
  "complexity_result": {
    "level": "minimal|standard|complex",
    "workflow": "lite|full|phase-based",
    "skip": ["approval_gate", "prd_compliance"],
    "required": ["syntax_check"],
    "reasoning": "why this level"
  }
}
```
