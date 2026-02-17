---
name: thinking-framework
description: Структурированный reasoning через 3 универсальных шаблона
user-invocable: false
context: fork
---
<!-- version: 2.2.0 | tags: thinking, reasoning, decision-making, analysis, risk-assessment | dependencies: [] | files: { templates: ./templates/*.xml, examples: ./examples/*.md, shared: @shared:THINKING-PATTERNS.md } | context: fork -->

# Thinking Framework v2.2

Структурированный reasoning через 3 универсальных шаблона (analysis, decision, risk).

**Навигация:**
- **Full specification:** `@shared:THINKING-PATTERNS.md` (templates, field descriptions, 9 examples)
- **Domain-specific examples:** `./examples/` (2 уникальных real-world scenarios)
- **Template files:** `./templates/*.xml` (XML structure references)

---

## Когда использовать

- **Перед планированием** (PHASE 1) - analysis thinking
- **При выборе между вариантами** - decision thinking
- **Перед рискованными операциями** - risk thinking
- **Всегда когда нужно обосновать решение**

---

## Quick Reference: Templates

**Full specification:** `@shared:THINKING-PATTERNS.md`

| Template | When | Structure |
|----------|------|-----------|
| **analysis** | Начало задачи, PRD check | ЗАДАЧА → КОНТЕКСТ → КОМПОНЕНТЫ → PRD → CRITERIA → ВЫВОДЫ |
| **decision** | Несколько вариантов | КОНТЕКСТ → ОПЦИИ → TRADE-OFFS → ВЫБОР → ОБОСНОВАНИЕ |
| **risk** | Опасные операции | ОПЕРАЦИЯ → РИСКИ → FALLBACK → ROLLBACK |

**Field descriptions:** См. `@shared:THINKING-PATTERNS.md#template-1-analysis-thinking`

---

## Template Selection Guide

**Quick Reference (First 3 Situations)**

| Situation | Template | Example |
|-----------|----------|---------|
| User request: "Add feature X" | **analysis** | Understand requirements, AC |
| Choice between libraries | **decision** | Compare options |
| Database migration | **risk** | Assess risks, plan rollback |

*(See TOON block below for complete 7-situation guide)*

**Complete Template Selection Guide (TOON)**

```toon
template_guide[7]{situation,template,example}:
  User request: Add feature X,analysis,Understand requirements AC
  Choice between libraries,decision,Compare options
  Database migration,risk,Assess risks plan rollback
  Bug fix: Error in Y,analysis,Root cause analysis
  Multiple API designs,decision,Trade-off analysis
  Refactor critical code,risk,Breaking change risk
  PRD implementation check,analysis,Alignment verification
```

**Full decision tree:** См. `@shared:THINKING-PATTERNS.md#when-to-use-which-template`

---

## Rules

**Quick summary:**

### When Thinking is Required

1. **Перед началом каждой фазы**
   - PHASE 1: analysis thinking перед planning
   - PHASE 2: decision thinking если несколько approaches
   - PHASE 4: risk thinking если risky validation

2. **Выбор между альтернативами**
   - Несколько библиотек/паттернов
   - Разные implementation strategies

3. **Рискованные операции**
   - Breaking changes
   - Database migrations
   - Production deployments

### When Thinking is Optional

- Простые однозначные задачи (typo fix, add constant)
- Когда решение очевидно (one clear approach)
- Repetitive operations (same pattern as before)

### Thinking is NOT Outputted

**IMPORTANT:** Thinking - внутренний процесс Claude. User видит только:
- Structured output (JSON)
- Task plan
- Final result

Thinking НЕ включается в user-facing output.

---

## Examples

### Domain-Specific Examples (в этом навыке)

**2 уникальных real-world примера:**

| Example | Template | Scenario | File |
|---------|----------|----------|------|
| Feature Implementation | analysis | Transaction filtering endpoint с PRD compliance | `examples/01-analysis-feature-implementation.md` |
| Breaking API Change | risk | Response format v1→v2 с mobile app compatibility | `examples/02-risk-breaking-api-change.md` |

**Почему эти примеры уникальны:**
- **Example 1:** Демонстрирует PRD integration, FastAPI context, detailed query parameters design (не покрыто в PATTERNS.md)
- **Example 2:** Enterprise-scale risk assessment с API versioning, third-party integrations, gradual rollout (не покрыто в PATTERNS.md)

### Reference Examples (в PATTERNS.md)

**9 reference примеров для всех шаблонов:**

См. `@shared:THINKING-PATTERNS.md#reference-examples`:
- **Analysis:** Simple feature (calculate_total), Bug fix (OrderValidator), PRD alignment check
- **Decision:** Library choice (datetime vs arrow), Architecture pattern (OrderValidator class), Error handling strategy
- **Risk:** Database migration (email_verified column), Major refactoring (auth system), Production deployment

---

## Integration with Other Skills

**Интеграция:**

### structured-planning
- Uses analysis thinking в PHASE 1 для понимания задачи
- Uses decision thinking если несколько approaches

### adaptive-workflow
- Uses decision thinking для выбора complexity level (minimal/standard/complex)

### validation-framework
- Uses risk thinking перед risky validations (deletions, schema changes, breaking formats)

**Full integration patterns:** См. `@shared:THINKING-PATTERNS.md#integration-with-skills`

---

## Best Practices

**Critical reminders:**
- Use thinking BEFORE structured output (reasoning first, then JSON)
- Be specific in ВЫВОДЫ/ОБОСНОВАНИЕ (actionable conclusions)
- Use appropriate template (см. Template Selection Guide выше)
- Don't skip thinking for complex tasks (даже если obvious)
- Don't output thinking to user (it's internal reasoning process)

**Full best practices (DO/DON'T lists):** См. `@shared:THINKING-PATTERNS.md#best-practices`

---

## Advanced Topics

**Advanced usage patterns:**
- **Nesting Rules:** См. `@shared:THINKING-PATTERNS.md#nesting-rules` (когда nesting valid, когда избегать)
- **Risk Matrix:** См. `@shared:THINKING-PATTERNS.md#risk-matrix` (Probability × Impact decision aid)

---

## Version History

### v2.2.0 (2026-02-08)

- Оптимизация: Устранено 56.7% дублирования с THINKING-PATTERNS.md
- Удалено: 4 дублирующихся примера (Bug Fix, Library Choice, Architecture, DB Migration)
- Удалено: Best Practices section (ссылка на PATTERNS.md)
- Создано: 2 уникальных примера в examples/ (Feature Implementation, API Breaking Change)
- SKILL.md сокращен с 459 до ~267 строк (42% reduction / ~192 строки removed)
- Роль: SKILL.md = navigation layer, PATTERNS.md = single source of truth

### v2.1.0 (2026-01-25)

- Централизация: Templates и rules → `@shared:THINKING-PATTERNS.md`
- Добавлено: 6 полных примеров (PRD analysis, library choice, migration risk, etc.)
- Улучшено: Integration guide для других skills

---

**Author:** Claude Code Team
**License:** MIT
**Support:** См. `@shared:THINKING-PATTERNS.md` для полной документации templates

## Changelog

### 2.2.0 (2026-02-08)
- Оптимизация: Удалено 56.7% дублирования с THINKING-PATTERNS.md
- Удалено: 4 дублирующихся примера (Bug Fix, Library Choice, Architecture, DB Migration)
- Удалено: Best Practices section (ссылка на PATTERNS.md)
- Создано: 2 уникальных примера (Feature Implementation, API Breaking Change)
- SKILL.md сокращен с 460 до ~267 строк (42% reduction)
- Сохранен уникальный контент: Rules section (33 строки)
- Навигационная роль: SKILL.md → reference layer, PATTERNS.md → source of truth

### 2.1.0 (2026-01-25)
- Централизация: Templates и rules → @shared:THINKING-PATTERNS.md
- Добавлено: 6 полных примеров (PRD analysis, library choice, migration risk, etc.)
- Улучшено: Integration guide для других skills
