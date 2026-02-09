# Complexity Rules - Адаптивные правила валидации

Правила валидации адаптируются к типу плана (minimal/standard/complex).

## Minimal Plans

**Scope:** Простые одно-файловые изменения

**Required validations:**
- ✅ Structural (Level 1) - basic sections only
- ✅ Semantic (Level 2) - solution_addresses_problem, file_alignment (basic)

**Skipped validations:**
- ❌ Technical (Level 3) - git info не требуется
- ❌ Completeness (Level 4) - detail checks не требуются

**Required sections:**
```
[task_name, problem, solution, critical_files, implementation_steps, verification]
```

**Thresholds:**
- Blocking threshold: 0 issues
- Min score: 70
- Solution confidence: >= 0.5

---

## Standard Plans

**Scope:** Multi-file changes с git workflow

**Required validations:**
- ✅ Structural (Level 1) - all sections + git_info
- ✅ Semantic (Level 2) - all checks
- ✅ Technical (Level 3) - all checks (warnings only, не блокирует)

**Optional validations:**
- ⚠️ Completeness (Level 4) - warnings only (не блокирует)

**Required sections:**
```
[task_name, problem, solution, critical_files, implementation_steps, verification, git_info]
```

**Thresholds:**
- Blocking threshold: 0 issues
- Min score: 75
- Solution confidence: >= 0.6
- Steps coverage: >= 0.7
- Completeness mode: "warning"

---

## Complex Plans

**Scope:** Architectural changes, multi-phase, high risk

**Required validations:**
- ✅ Structural (Level 1) - all sections + risks + dependencies
- ✅ Semantic (Level 2) - all checks (strict thresholds)
- ✅ Technical (Level 3) - all checks (warnings)
- ✅ Completeness (Level 4) - **ALL checks BLOCKING**

**Required sections:**
```
[task_name, problem, solution, critical_files, implementation_steps,
 verification, git_info, risks, dependencies]
```

**Thresholds:**
- Blocking threshold: 0 issues
- Min score: 80
- Solution confidence: >= 0.7 (strict)
- Steps coverage: >= 0.8 (strict)
- Completeness mode: "blocking" (warnings → BLOCKING)

---

## Score Weights

Распределение баллов по уровням:

| Level | Weight | Max Score |
|-------|--------|-----------|
| Structural | 25% | 25 points |
| Semantic | 25% | 25 points |
| Technical | 25% | 25 points |
| Completeness | 25% | 25 points |
| **Total** | **100%** | **100 points** |

---

## Skip Checks Matrix

Таблица пропускаемых проверок по plan_type:

| Check | Minimal | Standard | Complex |
|-------|---------|----------|---------|
| git_branch_pattern | SKIP | RUN | RUN |
| commit_type_valid | SKIP | RUN | RUN |
| steps_detail | SKIP | WARNING | BLOCKING |
| acceptance_criteria_testable | SKIP | WARNING | BLOCKING |
| risks_identified | SKIP | SKIP | BLOCKING |
| dependencies_documented | SKIP | SKIP | BLOCKING |

---

## Rules Engine

Правила применяются автоматически на основе `plan_type` из adaptive-workflow:

```javascript
function getValidationRules(plan_type) {
  const rules = COMPLEXITY_RULES[plan_type];

  return {
    required_sections: rules.required_sections,
    skip_checks: rules.skip_checks,
    blocking_threshold: rules.blocking_threshold,
    min_score: rules.min_score,
    completeness_mode: rules.completeness_mode
  };
}
```

Полная спецификация правил доступна в `templates/validation-rules.json`.
