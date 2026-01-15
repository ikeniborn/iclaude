# Basic Usage Example - error-handling

## Scenario

Структурированная обработка ошибок во время выполнения workflow с категоризацией, recovery strategies и structured error output.

**Use cases:**
- Handling compilation errors
- Handling test failures
- Handling runtime errors (import errors, missing dependencies)
- Structured error reporting

---

## Input

```json
{
  "operation": "Run tests",
  "command": "pytest tests/",
  "expected_result": "all tests pass"
}
```

---

## Execution

error-handling skill выполняет следующие шаги:

### Step 1: Execute Operation
- Run command: `pytest tests/`
- Capture stdout, stderr, exit code

### Step 2: Error Detection
- Exit code: 1 (failure)
- Parse stderr for error messages

### Step 3: Error Categorization
- Category: TEST_FAILURE
- Severity: BLOCKING (critical для workflow)
- Affected files: tests/test_auth.py

### Step 4: Recovery Strategy
- Suggest fix: Update failing test assertions
- Provide error context

---

## Output

```json
{
  "error_report": {
    "category": "TEST_FAILURE",
    "severity": "BLOCKING",
    "operation": "Run tests",
    "command": "pytest tests/",
    "exit_code": 1,
    "errors": [
      {
        "file": "tests/test_auth.py",
        "line": 42,
        "type": "AssertionError",
        "message": "assert 401 == 200",
        "context": "test_login_invalid_credentials"
      },
      {
        "file": "tests/test_auth.py",
        "line": 58,
        "type": "AssertionError",
        "message": "assert 'Unauthorized' in response.text",
        "context": "test_jwt_token_expired"
      }
    ],
    "recovery_strategy": {
      "automatic": false,
      "suggested_fix": [
        "Update test assertions to expect 401 instead of 200",
        "Check if error message format changed"
      ],
      "rollback_available": true
    },
    "timestamp": "2026-01-15T15:00:00Z"
  }
}
```

**Console output:**
```
❌ ERROR: TEST_FAILURE (BLOCKING)

📋 Operation: Run tests
💻 Command: pytest tests/
🚫 Exit code: 1

🔍 Errors found (2):

1. tests/test_auth.py:42 (test_login_invalid_credentials)
   AssertionError: assert 401 == 200

2. tests/test_auth.py:58 (test_jwt_token_expired)
   AssertionError: assert 'Unauthorized' in response.text

💡 Suggested fix:
  - Update test assertions to expect 401 instead of 200
  - Check if error message format changed

🔄 Rollback available: YES

❓ What would you like to do?
  [1] Apply suggested fix
  [2] Rollback to checkpoint
  [3] Manual fix
```

---

## Explanation

### Error Categories:

```
SYNTAX_ERROR:     Compilation/parsing errors (syntax, type errors)
TEST_FAILURE:     Test suite failures
IMPORT_ERROR:     Missing dependencies, import failures
RUNTIME_ERROR:    Execution errors (null pointer, etc.)
VALIDATION_ERROR: Schema validation, linting failures
NETWORK_ERROR:    HTTP errors, connection timeouts
```

### Severity Levels:

```
BLOCKING:  Must be fixed to continue (syntax errors, test failures)
WARNING:   Should be fixed but not critical (linting warnings)
INFO:      Informational (deprecation warnings)
```

### Recovery Strategies:

**Automatic recovery (when possible):**
```
IMPORT_ERROR → Install missing dependency
  npm install missing-package

NETWORK_ERROR → Retry with exponential backoff
  Attempt 1/3... Failed
  Attempt 2/3... Failed
  Attempt 3/3... Success
```

**Manual recovery (user intervention):**
```
SYNTAX_ERROR → Show error, suggest fix, wait for user
TEST_FAILURE → Show failing tests, suggest fixes
```

**Rollback recovery:**
```
CRITICAL_ERROR → Automatic rollback to checkpoint
  See rollback-recovery skill
```

### Structured Error Output:

```json
{
  "error_report": {
    "category": "IMPORT_ERROR",
    "severity": "BLOCKING",
    "errors": [{
      "file": "src/main.py",
      "line": 1,
      "message": "ModuleNotFoundError: No module named 'fastapi'"
    }],
    "recovery_strategy": {
      "automatic": true,
      "action": "pip install fastapi",
      "retry_after_fix": true
    }
  }
}
```

**Console output:**
```
❌ ERROR: IMPORT_ERROR (BLOCKING)

🔍 Missing dependency: fastapi

🤖 Automatic recovery available!
   Running: pip install fastapi

✓ fastapi installed successfully
🔄 Retrying operation...
✓ Operation succeeded
```

---

## Related

- [error-handling/SKILL.md](../SKILL.md)
- [rollback-recovery/SKILL.md](../rollback-recovery/SKILL.md)
- [validation-framework/SKILL.md](../validation-framework/SKILL.md)
