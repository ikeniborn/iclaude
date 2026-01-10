---
name: code-review
description: Автоматический review кода перед commit
version: 1.0.0
tags: [review, quality, security, code-smells]
dependencies: []
files:
  templates: ./templates/*.json
  rules: ./rules/*.md
user-invocable: false
---

# Code Review

Автоматическая проверка качества и безопасности кода.

## Когда использовать

- После выполнения задачи (standard/complex только)
- Перед git commit
- По запросу пользователя

## Категории проверок

### 1. Security (BLOCKING)

```
- SQL Injection
- XSS (Cross-Site Scripting)
- Command Injection
- Path Traversal
- Hardcoded secrets
- Insecure deserialization
```

Правила: `@rules:security`

### 2. Code Quality (WARNING)

```
- Code duplication
- High complexity (cyclomatic > 10)
- Long functions (> 50 lines)
- Deep nesting (> 4 levels)
- Magic numbers
- Unused variables/imports
```

Правила: `@rules:code-quality`

### 3. Error Handling (WARNING)

```
- Bare except clauses
- Empty catch blocks
- Missing null checks
- Unhandled promises
```

### 4. Type Safety (INFO)

```
- Missing type hints (Python)
- Any types (TypeScript)
- Implicit type conversions
```

## Output

```json
{
  "code_review": {
    "score": 85,
    "blocking_issues": [],
    "warnings": [
      {
        "category": "code_quality",
        "file": "service.py",
        "line": 42,
        "message": "Function too long (65 lines)",
        "suggestion": "Extract helper methods"
      }
    ],
    "suggestions": [
      "Consider adding type hints to function parameters"
    ],
    "passed": true
  }
}
```

## Score Calculation

```
score = 100 - (blocking * 20) - (warnings * 5) - (suggestions * 1)

passed = blocking_issues.length === 0
```

## Markdown Output

```
## Code Review: {score}/100

{если blocking}
🛑 BLOCKING ISSUES:
- {file}:{line} — {message}

{если warnings}
⚠️ WARNINGS:
- {file}:{line} — {message}

{если suggestions}
💡 SUGGESTIONS:
- {suggestion}

{passed ? "✓ Review passed" : "✗ Review failed"}
```
