# Basic Usage Example - code-review

## Scenario

Автоматический review кода перед commit с проверкой security issues, code quality, error handling и type safety (с LSP integration когда доступен).

**Use cases:**
- Pre-commit code review
- Automated quality checks
- Security vulnerability detection
- Type checking via LSP

---

## Input

```json
{
  "files_changed": [
    "src/api/users.py",
    "src/service.py",
    "src/models.py"
  ],
  "lsp_status": {
    "status": "READY",
    "languages": [
      {"language": "python", "server": "pyright", "server_installed": true}
    ]
  }
}
```

---

## Execution

code-review skill выполняет следующие шаги:

### Step 1: Static Analysis
- Scan для security issues (SQL injection, XSS, hardcoded secrets)
- Check code quality (complexity, duplication, naming)
- Check error handling (bare except, empty catch)

### Step 2: LSP Diagnostics (since lsp_status.status == "READY")
- Request LSP diagnostics from pyright
- Parse type errors, warnings
- Merge LSP diagnostics в review warnings

### Step 3: Score Calculation
```
score = 100 - (blocking_issues * 20) - (warnings * 5) - (suggestions * 1)
passed = blocking_issues.length === 0
```

---

## Output

```json
{
  "code_review": {
    "score": 75,
    "passed": false,
    "blocking_issues": [
      {
        "category": "security",
        "severity": "BLOCKING",
        "file": "src/api/users.py",
        "line": 42,
        "message": "Potential SQL injection vulnerability - user input not sanitized",
        "suggestion": "Use parameterized query instead of string concatenation",
        "code_snippet": "query = f\"SELECT * FROM users WHERE email = '{email}'\""
      }
    ],
    "warnings": [
      {
        "category": "code_quality",
        "severity": "WARNING",
        "file": "src/service.py",
        "line": 65,
        "message": "Function too long (72 lines)",
        "suggestion": "Extract helper methods to reduce complexity"
      },
      {
        "category": "type_safety",
        "severity": "WARNING",
        "file": "src/models.py",
        "line": 15,
        "message": "Missing type hint for function parameter",
        "suggestion": "Add type hint: def process_data(data: dict) -> None",
        "source": "pyright"
      }
    ],
    "lsp_diagnostics": [
      {
        "source": "pyright",
        "severity": "error",
        "file": "src/service.py",
        "line": 45,
        "column": 12,
        "message": "Type 'str' is not assignable to type 'int'",
        "code": "reportGeneralTypeIssues",
        "suggestion": "Add type conversion: int(value)"
      }
    ],
    "suggestions": [
      "Consider adding docstrings to public functions",
      "Use constants instead of magic numbers"
    ],
    "metrics": {
      "security": {"score": 5, "max": 25, "issues": 1},
      "code_quality": {"score": 20, "max": 25, "issues": 1},
      "error_handling": {"score": 25, "max": 25, "issues": 0},
      "type_safety": {"score": 25, "max": 25, "issues": 2}
    },
    "files_reviewed": ["src/api/users.py", "src/service.py", "src/models.py"],
    "lsp_available": true
  }
}
```

**Console output:**
```
## Code Review: 75/100

🛑 BLOCKING ISSUES (1):
- src/api/users.py:42 - Potential SQL injection vulnerability
  Suggestion: Use parameterized query instead of string concatenation

  Code:
  query = f"SELECT * FROM users WHERE email = '{email}'"  # DANGEROUS

  Fix:
  query = "SELECT * FROM users WHERE email = %s"
  cursor.execute(query, (email,))

⚠️ WARNINGS (2):
- src/service.py:65 - Function too long (72 lines)
  Suggestion: Extract helper methods to reduce complexity

- src/models.py:15 - Missing type hint for function parameter
  Suggestion: Add type hint: def process_data(data: dict) -> None
  Source: pyright LSP

💡 SUGGESTIONS:
- Consider adding docstrings to public functions
- Use constants instead of magic numbers

🔍 LSP Diagnostics (1):
- src/service.py:45:12 - Type 'str' is not assignable to type 'int'
  Source: pyright
  Suggestion: Add type conversion: int(value)

📊 Metrics:
| Category        | Score | Issues |
|-----------------|-------|--------|
| Security        |  5/25 |   1    |
| Code Quality    | 20/25 |   1    |
| Error Handling  | 25/25 |   0    |
| Type Safety     | 25/25 |   2    |

✗ Review FAILED - Fix blocking issues before committing
```

---

## Explanation

### Review Categories:

**1. Security (BLOCKING):**
- SQL Injection, XSS, Command Injection
- Path Traversal, Hardcoded secrets
- Insecure deserialization

**2. Code Quality (WARNING):**
- Code duplication
- High complexity (cyclomatic > 10)
- Long functions (> 50 lines)
- Deep nesting (> 4 levels)
- Magic numbers

**3. Error Handling (WARNING):**
- Bare except clauses
- Empty catch blocks
- Missing null checks
- Unhandled promises

**4. Type Safety (INFO):**
- Missing type hints (Python)
- Any types (TypeScript)
- Implicit type conversions

### LSP Integration:

**When LSP available (lsp_status.status == "READY"):**
```
1. Request LSP diagnostics for changed files
2. Parse diagnostics:
   - severity: "error" → BLOCKING issue
   - severity: "warning" → WARNING issue
   - severity: "information" → INFO suggestion
3. Merge into code_review.warnings[] with category: "type_safety"
4. Enhanced scoring: LSP errors = -10 points (instead of -5)
```

**Without LSP:**
```
✓ Fallback to regex-based type checking
✓ Basic checks only (missing type hints, obvious issues)
⚠️  Less comprehensive than LSP diagnostics
```

### Score Interpretation:

```
90-100: Excellent code quality
75-89:  Good, minor improvements needed
60-74:  Fair, multiple warnings
40-59:  Poor, significant issues
<40:    Critical, major refactoring needed

passed = true IF blocking_issues.length === 0
```

### Fix Workflow:

```
1. code-review runs
2. IF blocking_issues found:
     → Show issues
     → Suggest fixes
     → Wait for user to fix
     → Re-run code-review
   ELSE:
     → Approve for commit
```

---

## Related

- [code-review/SKILL.md](../SKILL.md)
- [lsp-integration/SKILL.md](../lsp-integration/SKILL.md)
- [git-workflow/SKILL.md](../git-workflow/SKILL.md)
