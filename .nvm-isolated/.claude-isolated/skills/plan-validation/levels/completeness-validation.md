# Level 4: Completeness Validation

## Цель
Проверить достаточность деталей для execution.

## Mode по plan_type

- **Minimal:** SKIP (не проверяется)
- **Standard:** WARNING only (не блокирует)
- **Complex:** BLOCKING (блокирует если не passed)

## Checks

### 1. Steps Detail

**Требование:** Avg >= 3 actions per step

**Алгоритм:**
```
avg_actions = total_actions / steps_count
if avg_actions < 3:
    status = "warning" (standard) or "failed" (complex)
```

### 2. Acceptance Criteria Testable

**Требование:** >= 50% критериев testable (измеримые)

**Testable criteria examples:**
- ✅ "Login endpoint returns 200 OK with valid JWT"
- ✅ "User model has email field"
- ❌ "Code works correctly" (not measurable)

### 3. Risks Identified (Complex only)

**Требование:** >= 1 risk documented

### 4. Root Cause Analysis (Bug fixes only)

**Проверка:** Если `commit_type == "fix"`, требуется root cause в `problem` section

### 5. Dependencies Documented (Complex only)

**Требование:** >= 1 dependency (external lib, API, service)

## Scoring

- **Max score:** 25 points
- **Mode-specific blocking:**
  - Standard: warnings не снижают score, не блокируют
  - Complex: warnings становятся BLOCKING

## Example Output

```json
{
  "completeness_validation": {
    "passed": true,
    "score": 15,
    "checks": [
      {"check": "steps_detail", "status": "passed", "avg_actions": 4.2},
      {"check": "acceptance_criteria_testable", "status": "passed", "testable_pct": 0.8}
    ],
    "warnings": []
  }
}
```
