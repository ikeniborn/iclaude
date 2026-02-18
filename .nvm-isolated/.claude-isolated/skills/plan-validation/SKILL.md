---
name: plan-validation
description: Multi-perspective validation of planning outputs before execution
user-invocable: true
context: fork
---
<!-- version: 1.0.1 | tags: validation, planning, quality-assurance, blocking, pre-execution | dependencies: structured-planning, adaptive-workflow, thinking-framework, toon-skill | files: templates=./templates/*.json, schemas=./schemas/*.json, examples=./examples/*.md, rules=./rules/*.md, levels=./levels/*.md -->

# Plan Validation

Multi-perspective validation system for validating planning outputs BEFORE execution (PHASE 1.5).

## Table of Contents

- [Когда использовать](#когда-использовать)
- [Validation Levels](#validation-levels)
- [Output Schema](#output-schema)
- [Integration](#integration)
- [TOON Optimization](#toon-optimization)
- [Examples](#examples)
- [References](#references)

## Когда использовать

**PHASE 1.5** - Между structured-planning (PHASE 1) и approval-gates (PHASE 2).

### Триггеры активации

1. **После генерации плана** - structured-planning создал task_plan.md
2. **Перед approval** - валидация БЛОКИРУЕТ approval при критических проблемах
3. **Ручная валидация** - пользователь вызывает `/plan-validation`

### Что проверяется

- **Структурная корректность** - все обязательные разделы присутствуют
- **Семантическая согласованность** - solution решает problem, файлы соответствуют steps
- **Техническая валидность** - git info корректна, файлы существуют
- **Полнота деталей** - достаточно информации для выполнения

### Интеграция в workflow

```
PHASE 1: structured-planning → task_plan.md
         ↓
PHASE 1.5: plan-validation (THIS SKILL) → validates plan
         ↓ IF passed
PHASE 2: approval-gates
         ↓ IF validation.passed == false
         BLOCK approval, show blocking_issues
```

## Validation Levels

Четыре уровня валидации с адаптивными правилами по complexity.

### Level 1: Structural Validation (BLOCKING)

**Цель:** Проверить наличие обязательных разделов

**Key checks:**
- ✅ task_name, problem, solution present
- ✅ critical_files (>= 1), implementation_steps (>= 1)
- ✅ verification present
- ✅ git_info present (standard/complex only)
- ✅ risks, dependencies present (complex only)

**Score:** 25 points max
**Blocking:** Any missing required section → BLOCKING

📄 **Details:** [levels/structural-validation.md](levels/structural-validation.md)

---

### Level 2: Semantic Validation (BLOCKING)

**Цель:** Проверить логическую согласованность плана

**Key checks:**

1. **Solution Addresses Problem** - Correlation analysis (keyword matching)
   - Confidence >= 0.6 (standard) или >= 0.7 (complex)
   - Блокирует если confidence < threshold

2. **Steps Lead to Solution** - Coverage analysis
   - Coverage >= 0.7 (standard) или >= 0.8 (complex)
   - Блокирует если coverage < threshold

3. **File Alignment** - Files в steps должны быть в critical_files
   - Extracts file paths from implementation_steps
   - Compares with critical_files list
   - Блокирует если mismatch detected

4. **No Contradictions** - Противоречивые утверждения
   - Детектит opposite actions (add vs remove, enable vs disable)
   - Блокирует если contradiction found

**Score:** 25 points max
**Blocking:** Любой failed check → BLOCKING

📄 **Details:** [rules/semantic-validation.md](rules/semantic-validation.md)

---

### Level 3: Technical Validation (WARNING)

**Цель:** Проверить техническую корректность (не блокирует)

**Key checks:**
- ⚠️ Files exist (для change_type=modify)
- ⚠️ Validation commands valid syntax
- ⚠️ Git branch pattern: `^(feature|fix|refactor|dev|chore|test|docs)/[a-z0-9_-]+$`
- ⚠️ Commit type: `feat|fix|refactor|docs|test|chore|perf|style`
- ⚠️ JSON schema compliance

**Score:** 25 points max
**Mode:** WARNING only (не блокирует execution)

📄 **Details:** [rules/technical-validation.md](rules/technical-validation.md)

---

### Level 4: Completeness Validation

**Цель:** Проверить достаточность деталей

**Mode по plan_type:**
- **Minimal:** SKIP (не проверяется)
- **Standard:** WARNING only (не блокирует)
- **Complex:** **BLOCKING** (warnings → BLOCKING)

**Key checks:**
- Steps detail (avg >= 3 actions per step)
- Acceptance criteria testable (>= 50%)
- Risks identified (complex only)
- Root cause analysis (bug fixes only)
- Dependencies documented (complex only)

**Score:** 25 points max

📄 **Details:** [levels/completeness-validation.md](levels/completeness-validation.md)

---

## Complexity Rules

Правила валидации адаптируются к plan_type (minimal/standard/complex).

**Краткий обзор:**

| Plan Type | Required Levels | Optional Levels | Min Score | Completeness Mode |
|-----------|----------------|-----------------|-----------|-------------------|
| **Minimal** | Structural, Semantic | - | 70 | SKIP |
| **Standard** | Structural, Semantic, Technical | Completeness (WARNING) | 75 | WARNING |
| **Complex** | ALL (Completeness BLOCKING) | - | 80 | BLOCKING |

📄 **Full Specification:** [complexity-rules.md](complexity-rules.md)

---

## Output Schema

Основан на `@shared:base-schema.json` definitions.

### plan_validation_result (краткая структура)

```json
{
  "plan_validation_result": {
    "plan_type": "minimal|standard|complex",
    "timestamp": "2026-02-09T14:30:00Z",
    "passed": false,
    "score": 75,
    "max_score": 100,

    "structural_validation": { "passed": true, "score": 25, "checks": [...], "blocking_issues": [] },
    "semantic_validation": { "passed": false, "score": 15, "checks": [...], "blocking_issues": [...] },
    "technical_validation": { "passed": true, "score": 20, "warnings": [] },
    "completeness_validation": { "passed": true, "score": 15, "warnings": [] },

    "blocking_issues": [/* aggregated from all levels */],
    "warnings": [/* aggregated warnings */],
    "suggestions": [/* improvement suggestions */],

    "metrics": {
      "structural_score": 25,
      "semantic_score": 15,
      "technical_score": 20,
      "completeness_score": 15,
      "total_score": 75
    }
  }
}
```

📄 **Full Schema:** [schemas/validation-result.schema.json](schemas/validation-result.schema.json)
📄 **Template:** [templates/validation-result.json](templates/validation-result.json)

---

## Integration

### С structured-planning (PHASE 1)

**Последовательность:**
1. structured-planning генерирует task_plan.md
2. plan-validation автоматически запускается
3. Если `passed == false` → блокирует переход к approval-gates
4. Показывает blocking_issues и suggestions

**Output:** Добавляет `plan_validation_result` в task_plan.json

---

### С approval-gates (PHASE 2)

**Логика:**
```
IF plan_validation_result.passed == false:
  BLOCK approval
  SHOW blocking_issues
  REQUIRE plan fixes

IF warnings.length > 0:
  SHOW warnings
  ALLOW approval (warnings не блокируют)
```

**Example блокировки:**
```
❌ Plan validation FAILED (score: 65/100)

BLOCKING ISSUES:
- [SEMANTIC] File alignment mismatch: Step 3 references tests/test_jwt_service.py
  not in Critical Files
  Suggestion: Add tests/test_jwt_service.py to Critical Files section

Please fix blocking issues before approval.
```

---

### С adaptive-workflow

**Использование:**
- adaptive-workflow определяет `plan_type` (minimal/standard/complex)
- plan-validation применяет соответствующие rules из [complexity-rules.md](complexity-rules.md)
- Адаптивные thresholds и skip_checks

---

### С thinking-framework

**Использование:**
- Semantic validation использует `<analysis_thinking>` для correlation analysis
- Solution_addresses_problem check использует keyword extraction logic
- Steps coverage calculation использует analytical reasoning

---

### С toon-skill

**Использование:**
- Конвертация validation_checks[] в TOON формат (если >= 20 checks)
- Token savings для complex планов с большим количеством проверок

---

## TOON Optimization

### Когда применять

**Триггеры:**
- `validation_checks.length >= 20` (complex plans)
- `blocking_issues.length >= 5`
- `warnings.length >= 5`

### Формат TOON

**Для validation_checks[]:**
```toon
validation_checks[32]{level,check,status,score}:
  structural,frontmatter_complete,passed,3.125
  structural,critical_files_present,passed,6.25
  semantic,solution_addresses_problem,passed,6.25
  semantic,file_alignment,failed,0
  technical,git_branch_pattern,warning,4.0
  ...
```

**Для blocking_issues[]:**
```toon
blocking_issues[3]{issue,severity,level}:
  file_alignment_mismatch,BLOCKING,semantic
  steps_detail_insufficient,BLOCKING,completeness
  risks_missing,BLOCKING,structural
```

**Token savings:** ~32% для 32 checks

---

## Examples

### Example 1: Minimal Plan - Passed

**File:** [examples/minimal-plan-passed.md](examples/minimal-plan-passed.md)

**Scenario:** Minimal план с корректной структурой и семантикой

**Result:**
- ✅ Passed (score: 100/100)
- No blocking issues, no warnings

---

### Example 2: Standard Plan - Failed

**File:** [examples/standard-plan-failed.md](examples/standard-plan-failed.md)

**Scenario:** Standard план с file alignment mismatch

**Result:**
- ❌ Failed (score: 75/100)
- Blocking issue: file_alignment_mismatch
- Suggestion: Add missing file to Critical Files

---

### Example 3: Complex Plan - Warnings

**File:** [examples/complex-plan-warnings.md](examples/complex-plan-warnings.md)

**Scenario:** Complex план с warnings (git branch pattern, testable criteria)

**Result:**
- ✅ Passed with warnings (score: 85/100)
- 2 warnings (не блокируют)
- Demonstrates TOON optimization для 25+ checks

---

## References

### Shared Resources

- `@shared:base-schema.json` - Base definitions (plan_validation_result, severity enum)
- `@shared:WORKFLOW-SKILLS-UNIVERSAL.md` - Universal workflow integration
- `@shared:TOON-REFERENCE.md` - TOON format specification

### Dependencies

- **structured-planning** - Источник task_plan для валидации
- **adaptive-workflow** - Определяет plan_type для адаптивных rules
- **thinking-framework** - Analytical reasoning для semantic checks
- **toon-skill** - JSON ↔ TOON конвертация

### Related Skills

- **approval-gates** - Использует plan_validation_result для approval decision
- **error-handling** - Retry logic если validation fails
- **code-review** - Похожая multi-level validation structure

### Internal Documentation

- [complexity-rules.md](complexity-rules.md) - Адаптивные правила валидации
- [levels/structural-validation.md](levels/structural-validation.md) - Level 1 details
- [levels/completeness-validation.md](levels/completeness-validation.md) - Level 4 details
- [rules/semantic-validation.md](rules/semantic-validation.md) - Level 2 algorithms
- [rules/technical-validation.md](rules/technical-validation.md) - Level 3 algorithms

---

## Usage

### Автоматический вызов (рекомендуемый)

```bash
# structured-planning автоматически вызывает plan-validation
# Если validation fails → блокирует approval-gates
```

### Ручной вызов

```bash
# В Claude Code session
/plan-validation

# Валидирует текущий task_plan.md
# Показывает plan_validation_result
```

---

## Changelog

### v1.0.1 (2026-02-09)

- Optimization: Moved detailed validation level docs to levels/ directory
- Optimization: Extracted complexity rules to complexity-rules.md
- Reduced SKILL.md from 663 to ~430 lines (35% reduction)

### v1.0.0 (2026-02-09)

- Initial release
- 4-level validation system (structural, semantic, technical, completeness)
- Adaptive rules для minimal/standard/complex
- TOON optimization для complex планов
- Integration с structured-planning, approval-gates, adaptive-workflow
