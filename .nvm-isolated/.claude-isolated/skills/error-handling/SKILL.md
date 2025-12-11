---
name: Error Handling
description: Структурированная обработка ошибок workflow
version: 2.0.0
tags: [errors, recovery, retry, handling]
dependencies: []
files:
  templates: ./templates/*.json
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
