---
name: Error Handling
description: Структурированная обработка ошибок workflow
version: 2.1.0
tags: [errors, recovery, retry, handling]
dependencies: []
files:
  templates: ./templates/*.json
user-invocable: false
---

# Error Handling v2.0

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

## Extended Error History (v2.1.0)

**Новое:** Для задач с множественными ошибками и retry attempts, добавляется массив `error_history[]`.

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
        "file": "backend/app/services/auth_service.py",
        "line": 42,
        "message": "SyntaxError: unexpected indent",
        "fix_applied": "Fixed indentation on line 42",
        "outcome": "success"
      },
      {
        "attempt_id": 2,
        "error_type": "VALIDATION_FAILED",
        "file": "backend/app/api/v1/endpoints/auth.py",
        "line": 78,
        "message": "Type mismatch: expected str, got int",
        "fix_applied": "Added type casting str(user_id)",
        "outcome": "success"
      },
      // ... more errors
    ]
  }
}
```

Используется когда:
- Задача генерирует ≥5 ошибок
- Множественные retry iterations
- Детальное логирование требуется

## TOON Format Support (v2.1.0)

**Назначение:** Автоматическая оптимизация токенов для error_history[] массива при множественных ошибках.

### Threshold

TOON генерируется если **error_history[] >= 5**

### Target Array

**error_history[]**
- Обычно: 1-15 errors per task (complex tasks may have more)
- Поля: attempt_id, error_type, file, line, message, fix_applied, outcome
- Token savings: ~30-40% для 5+ errors

### Output Structure

**Error Handling Summary (с TOON):**
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
      "error_history_toon": "error_history[8]{attempt_id,error_type,file,line,message,fix_applied,outcome}:\n  1,SYNTAX_ERROR,auth_service.py,42,SyntaxError: unexpected indent,Fixed indentation,success\n  2,VALIDATION_FAILED,auth.py,78,Type mismatch: expected str got int,Added type casting,success\n  3,SYNTAX_ERROR,security.py,23,NameError: name 'hashlib' is not defined,Added import hashlib,success\n  4,VALIDATION_FAILED,test_auth.py,56,AssertionError: expected 200 got 401,Fixed mock JWT token,success\n  5,SYNTAX_ERROR,middleware.py,34,IndentationError: expected an indented block,Fixed indentation,success\n  6,ACCEPTANCE_NOT_MET,auth.py,120,POST /auth/login returns 500,Fixed database connection,success\n  7,SYNTAX_ERROR,user.py,15,SyntaxError: invalid syntax,Fixed missing colon,success\n  8,PRD_CONFLICT,auth.py,200,Logout should invalidate both tokens not just refresh,null,pending",
      "token_savings": "35.2%",
      "size_comparison": "JSON: 2340 tokens, TOON: 1516 tokens"
    }
  }
}
```

### Implementation Pattern

```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Error handling summary
const errorSummary = {
  total_errors: 8,
  errors_fixed: 7,
  error_history: [...]  // 8+ errors
};

// Add TOON optimization (только для error_history >= 5)
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
```

### Token Savings Examples

| Scenario | JSON Tokens | TOON Tokens | Savings | Errors |
|----------|-------------|-------------|---------|--------|
| Small task (5 errors) | 1450 | 985 | 32.1% | 5 |
| Medium task (8 errors) | 2340 | 1516 | 35.2% | 8 |
| Large task (15 errors) | 4380 | 2650 | 39.5% | 15 |

**Typical use case:** Complex task с 8 ошибками: **~35% token reduction**

### Backward Compatibility

- ✅ JSON format always present (primary format)
- ✅ TOON field optional (only when threshold met)
- ✅ Single error output unchanged (для простых случаев)
- ✅ Zero breaking changes для downstream consumers

### When TOON is Generated

**Always generated:**
- Complex tasks with 5+ errors
- Multi-iteration retry workflows
- Detailed error logging enabled

**Not generated:**
- Simple tasks (< 5 errors total)
- Single error occurrence
- Error-free execution

См. также: **toon-skill** для API документации, **_shared/TOON-PATTERNS.md** для integration patterns.

