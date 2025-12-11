---
name: Thinking Framework
description: Структурированный reasoning через 3 универсальных шаблона
version: 2.0.0
tags: [thinking, reasoning, decision-making, analysis]
dependencies: []
files:
  templates: ./templates/*.xml
  examples: ./examples/*.md
---

# Thinking Framework v2.0

Оптимизированный framework с 3 универсальными шаблонами вместо 8.

## Когда использовать

- Перед планированием (analysis)
- При выборе между вариантами (decision)
- Перед рискованными операциями (risk)

## Шаблоны

### 1. Analysis Thinking

**Объединяет:** PRD Analysis + Root Cause Analysis

```xml
<thinking type="analysis">
ЗАДАЧА: [описание задачи]
КОНТЕКСТ: [текущее состояние]
КОМПОНЕНТЫ: [затрагиваемые файлы/модули]
PRD: [релевантные секции если есть]
ACCEPTANCE CRITERIA: [критерии успеха]
ВЫВОДЫ: [что нужно сделать]
</thinking>
```

Шаблон: `@template:analysis`

### 2. Decision Thinking

**Объединяет:** Technical Decision + Solution Comparison

```xml
<thinking type="decision">
КОНТЕКСТ: [ситуация]
ОПЦИИ:
  1. [вариант] — Плюсы: [...] Минусы: [...]
  2. [вариант] — Плюсы: [...] Минусы: [...]
TRADE-OFFS: [что жертвуем]
ВЫБОР: [вариант N]
ОБОСНОВАНИЕ: [почему именно этот]
</thinking>
```

Шаблон: `@template:decision`

### 3. Risk Thinking

**Для:** Risk Assessment перед опасными операциями

```xml
<thinking type="risk">
ОПЕРАЦИЯ: [что планируем]
РИСКИ:
  1. [риск] — Вероятность: [...] Impact: [...]
     Митигация: [...]
  2. [риск] — Вероятность: [...] Impact: [...]
     Митигация: [...]
FALLBACK: [что делать если не получится]
ROLLBACK: [как откатить]
</thinking>
```

Шаблон: `@template:risk`

## Когда какой шаблон

| Ситуация | Шаблон |
|----------|--------|
| Начало задачи, анализ требований | analysis |
| Выбор библиотеки/подхода | decision |
| Рефакторинг, миграция, breaking changes | risk |
| Несколько вариантов решения | decision |
| Проверка соответствия PRD | analysis |

## Правила

1. **Thinking обязателен** перед:
   - Началом каждой фазы
   - Выбором между альтернативами
   - Рискованными операциями

2. **Thinking опционален** для:
   - Простых однозначных задач
   - Когда решение очевидно

3. **Thinking НЕ выводится** пользователю (внутренний процесс)

## Примеры

- `@example:prd-analysis`
- `@example:technical-decision`
- `@example:risk-assessment`
