---
name: Error Handling
description: Структурированная обработка ошибок workflow
version: 2.2.0
tags: [errors, recovery, retry, handling]
dependencies: []
files:
  templates: ./templates/*.json
user-invocable: false
changelog:
  - version: 2.2.0
    date: 2026-01-25
    changes:
      - "Централизация: TOON specs → @shared:TOON-REFERENCE.md"
      - "Добавлено: 3 примера (single error, multiple errors, TOON optimization)"
      - "Skill-specific TOON usage notes для error_history[]"
      - "Обновлены references"
  - version: 2.1.0
    date: 2026-01-23
    changes:
      - "TOON Format Support для error_history[]"
      - "Extended error history для complex tasks"
  - version: 2.0.0
    date: 2025-XX-XX
    changes:
      - "Structured error types и actions"
---

# Error Handling v2.2

Структурированная обработка ошибок с чёткими действиями.

## Error Types и Actions

| Error Type | Action | Max Retries | Blocking |
|------------|--------|-------------|----------|
| SYNTAX_ERROR | FIX, RETRY | 2 | Yes |
| VALIDATION_FAILED | FIX, RETRY | 2 | Yes |
| ACCEPTANCE_NOT_MET | FIX, RETRY | 2 | Yes |
| PRD_CONFLICT | ASK user | 0 | Yes |
| APPROVAL_REJECTED | STOP | 0 | Yes |
| GIT_FAILED | STOP | 0 | Yes |
| FILE_NOT_FOUND | ASK user | 0 | No |
| PERMISSION_DENIED | STOP | 0 | Yes |

## Error Handling Flow

```
1. Catch error
2. Classify error type
3. Check retry count
4. If retries < max:
   - Attempt fix
   - RETRY operation
5. Else:
   - Use rollback-recovery skill
   - ASK user or STOP
```

## Output Template

```json
{
  "error": {
    "type": "SYNTAX_ERROR",
    "message": "SyntaxError: unexpected indent",
    "file": "service.py",
    "line": 42,
    "action": "RETRY",
    "retry_count": 1,
    "max_retries": 2,
    "fix_applied": "Fixed indentation on line 42"
  }
}
```

## User-Facing Message

```
🚨 ОШИБКА: {type}

Файл: {file}:{line}
Проблема: {message}

{если action == RETRY}
Исправление: {fix_applied}
Попытка: {retry_count}/{max_retries}

{если action == ASK}
Требуется решение:
- [A] {option_a}
- [B] {option_b}

{если action == STOP}
Действие: Остановка выполнения
Причина: {reason}
```

## Recovery Trigger

При `retry_count >= max_retries`:
```
→ Вызвать @skill:rollback-recovery
→ Откатить изменения
→ STOP или ASK user
```

## Extended Error History

**Для задач с множественными ошибками и retry attempts:** массив `error_history[]`

**Структура:**
```json
{
  "error_handling_summary": {
    "total_errors": 8,
    "errors_fixed": 7,
    "errors_remaining": 1,
    "retry_iterations": 3,
    "final_status": "partially_resolved",
    "error_history": [
      {
        "attempt_id": 1,
        "error_type": "SYNTAX_ERROR",
        "file": "auth_service.py",
        "line": 42,
        "message": "SyntaxError: unexpected indent",
        "fix_applied": "Fixed indentation",
        "outcome": "success"
      },
      // ... more errors
    ]
  }
}
```

**Используется когда:**
- Задача генерирует ≥5 ошибок
- Множественные retry iterations
- Детальное логирование требуется

## TOON Format Support

**Skill uses TOON format** для token-efficient error_history[] reporting.

### References

**TOON Format Specification:**
- Full spec: `@shared:TOON-REFERENCE.md`
- Integration patterns: `@shared:TOON-REFERENCE.md#integration-patterns`
- Token savings benchmarks: `@shared:TOON-REFERENCE.md#token-savings`

### Skill-Specific TOON Usage

**error-handling генерирует TOON для:**
- `error_history[]` - когда >= 5 errors

**Implementation:**
```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Error handling summary
const errorSummary = {
  total_errors: 8,
  errors_fixed: 7,
  error_history: [...]  // 8 errors
};

// Add TOON optimization (only if >= 5 elements)
if (errorSummary.error_history.length >= 5) {
  // Normalize fix_applied (null → "none" для TOON consistency)
  const errorsNormalized = errorSummary.error_history.map(e => ({
    attempt_id: e.attempt_id,
    error_type: e.error_type,
    file: e.file.replace(/^.*\//, ''),  // basename only для компактности
    line: e.line,
    message: e.message.replace(/\n/g, ' '),  // single line
    fix_applied: e.fix_applied || 'none',
    outcome: e.outcome
  }));

  errorSummary.toon = {
    error_history_toon: arrayToToon('error_history', errorsNormalized,
      ['attempt_id', 'error_type', 'file', 'line', 'message', 'fix_applied', 'outcome']),
    ...calculateTokenSavings({ error_history: errorsNormalized })
  };
}

return errorSummary;
```

**Token Savings (Error-Specific):**
- 5 errors: **32.1% savings** (1450 → 985 tokens)
- 8 errors: **35.2% savings** (2340 → 1516 tokens)
- 15 errors: **39.5% savings** (4380 → 2650 tokens)

---

## Examples

### Example 1: Single Error (SYNTAX_ERROR)

**Scenario:** Python syntax error during validation

**Input:**
```python
# File: auth_service.py, line 42
def validate_token(token):
    if token is None
        return False  # Missing colon on line 42
```

**Error detection:**
```json
{
  "error": {
    "type": "SYNTAX_ERROR",
    "message": "SyntaxError: invalid syntax (missing colon)",
    "file": "auth_service.py",
    "line": 42,
    "action": "RETRY",
    "retry_count": 1,
    "max_retries": 2,
    "fix_applied": "Added missing colon after if statement"
  }
}
```

**User message:**
```
🚨 ОШИБКА: SYNTAX_ERROR

Файл: auth_service.py:42
Проблема: SyntaxError: invalid syntax (missing colon)

Исправление: Added missing colon after if statement
Попытка: 1/2
```

**Result:** Error fixed automatically, retry successful.

---

### Example 2: Multiple Errors (3 attempts)

**Scenario:** Complex validation with sequential errors

**Error sequence:**

**Attempt 1: SYNTAX_ERROR**
```json
{
  "error": {
    "type": "SYNTAX_ERROR",
    "file": "user.py",
    "line": 15,
    "message": "IndentationError: unexpected indent",
    "fix_applied": "Fixed indentation",
    "retry_count": 1,
    "max_retries": 2,
    "outcome": "success"
  }
}
```

**Attempt 2: VALIDATION_FAILED**
```json
{
  "error": {
    "type": "VALIDATION_FAILED",
    "file": "test_user.py",
    "line": 34,
    "message": "AssertionError: expected 200 got 500",
    "fix_applied": "Fixed database connection string",
    "retry_count": 1,
    "max_retries": 2,
    "outcome": "success"
  }
}
```

**Attempt 3: ACCEPTANCE_NOT_MET**
```json
{
  "error": {
    "type": "ACCEPTANCE_NOT_MET",
    "file": "user.py",
    "line": 56,
    "message": "GET /users returns empty array instead of user list",
    "fix_applied": "Fixed SQL query WHERE clause",
    "retry_count": 1,
    "max_retries": 2,
    "outcome": "success"
  }
}
```

**Error summary:**
```json
{
  "error_handling_summary": {
    "total_errors": 3,
    "errors_fixed": 3,
    "errors_remaining": 0,
    "retry_iterations": 3,
    "final_status": "all_resolved",
    "error_history": [
      {"attempt_id": 1, "error_type": "SYNTAX_ERROR", "file": "user.py", "line": 15, "message": "IndentationError", "fix_applied": "Fixed indentation", "outcome": "success"},
      {"attempt_id": 2, "error_type": "VALIDATION_FAILED", "file": "test_user.py", "line": 34, "message": "AssertionError", "fix_applied": "Fixed DB connection", "outcome": "success"},
      {"attempt_id": 3, "error_type": "ACCEPTANCE_NOT_MET", "file": "user.py", "line": 56, "message": "Empty array", "fix_applied": "Fixed SQL query", "outcome": "success"}
    ]
  }
}
```

**Result:** All 3 errors resolved after 3 retry iterations.

---

### Example 3: Complex Task with TOON Optimization (8 errors)

**Scenario:** Large authentication module with multiple errors

**Error summary with TOON:**
```json
{
  "error_handling_summary": {
    "total_errors": 8,
    "errors_fixed": 7,
    "errors_remaining": 1,
    "retry_iterations": 3,
    "final_status": "partially_resolved",
    "error_history": [
      {"attempt_id": 1, "error_type": "SYNTAX_ERROR", "file": "auth_service.py", "line": 42, "message": "SyntaxError: unexpected indent", "fix_applied": "Fixed indentation", "outcome": "success"},
      {"attempt_id": 2, "error_type": "VALIDATION_FAILED", "file": "auth.py", "line": 78, "message": "Type mismatch: expected str got int", "fix_applied": "Added type casting", "outcome": "success"},
      {"attempt_id": 3, "error_type": "SYNTAX_ERROR", "file": "security.py", "line": 23, "message": "NameError: name 'hashlib' is not defined", "fix_applied": "Added import hashlib", "outcome": "success"},
      {"attempt_id": 4, "error_type": "VALIDATION_FAILED", "file": "test_auth.py", "line": 56, "message": "AssertionError: expected 200 got 401", "fix_applied": "Fixed mock JWT token", "outcome": "success"},
      {"attempt_id": 5, "error_type": "SYNTAX_ERROR", "file": "middleware.py", "line": 34, "message": "IndentationError: expected an indented block", "fix_applied": "Fixed indentation", "outcome": "success"},
      {"attempt_id": 6, "error_type": "ACCEPTANCE_NOT_MET", "file": "auth.py", "line": 120, "message": "POST /auth/login returns 500", "fix_applied": "Fixed database connection", "outcome": "success"},
      {"attempt_id": 7, "error_type": "SYNTAX_ERROR", "file": "user.py", "line": 15, "message": "SyntaxError: invalid syntax", "fix_applied": "Fixed missing colon", "outcome": "success"},
      {"attempt_id": 8, "error_type": "PRD_CONFLICT", "file": "auth.py", "line": 200, "message": "Logout should invalidate both tokens not just refresh", "fix_applied": null, "outcome": "pending"}
    ],
    "toon": {
      "error_history_toon": "error_history[8]{attempt_id,error_type,file,line,message,fix_applied,outcome}:\n  1,SYNTAX_ERROR,auth_service.py,42,SyntaxError: unexpected indent,Fixed indentation,success\n  2,VALIDATION_FAILED,auth.py,78,Type mismatch: expected str got int,Added type casting,success\n  3,SYNTAX_ERROR,security.py,23,NameError: name 'hashlib' is not defined,Added import hashlib,success\n  4,VALIDATION_FAILED,test_auth.py,56,AssertionError: expected 200 got 401,Fixed mock JWT token,success\n  5,SYNTAX_ERROR,middleware.py,34,IndentationError: expected an indented block,Fixed indentation,success\n  6,ACCEPTANCE_NOT_MET,auth.py,120,POST /auth/login returns 500,Fixed database connection,success\n  7,SYNTAX_ERROR,user.py,15,SyntaxError: invalid syntax,Fixed missing colon,success\n  8,PRD_CONFLICT,auth.py,200,Logout should invalidate both tokens not just refresh,none,pending",
      "token_savings": "35.2%",
      "size_comparison": "JSON: 2340 tokens, TOON: 1516 tokens"
    }
  }
}
```

**User message:**
```
🚨 ERROR SUMMARY: 8 errors encountered, 7 fixed, 1 pending

Fixed automatically (7):
✓ SYNTAX_ERROR (auth_service.py:42) - Fixed indentation
✓ VALIDATION_FAILED (auth.py:78) - Added type casting
✓ SYNTAX_ERROR (security.py:23) - Added import hashlib
✓ VALIDATION_FAILED (test_auth.py:56) - Fixed mock JWT token
✓ SYNTAX_ERROR (middleware.py:34) - Fixed indentation
✓ ACCEPTANCE_NOT_MET (auth.py:120) - Fixed database connection
✓ SYNTAX_ERROR (user.py:15) - Fixed missing colon

Requires user decision (1):
❌ PRD_CONFLICT (auth.py:200) - Logout should invalidate both tokens not just refresh

Status: 7/8 resolved (87.5%)
Token savings: 35.2% (TOON format)
```

**Result:** 7 errors auto-fixed, 1 PRD conflict requires user decision. TOON optimization saved 35.2% tokens.

---

## Integration with Other Skills

**Uses:**
- `rollback-recovery` → Called when retry_count >= max_retries
- `toon-skill` → TOON optimization for error_history[] (см. `@shared:TOON-REFERENCE.md`)

**Used by:**
- `adaptive-workflow` → Catches errors during workflow execution
- `phase-execution` → Handles checkpoint validation errors
- `validation-framework` → Processes validation failures

---

🤖 Generated with Claude Code

**Author:** ikeniborn
**License:** MIT
