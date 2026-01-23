---
name: Git Workflow
description: Стандартизированный git workflow с Conventional Commits
version: 2.1.0
tags: [git, commit, branch, conventional-commits]
dependencies: []
files:
  templates: ./templates/*.txt
  examples: ./examples/*.md
  shared: ../_shared/commit-types.json
user-invocable: false
---

# Git Workflow v2.0

Стандартизированный git workflow.

## Когда использовать

- При создании ветки (Phase 1)
- При commit (Phase 5)
- При создании PR

## Branch Naming

```
{type}/{slug}

Примеры:
- feature/add-calculate-total
- fix/null-pointer-validator
- refactor/extract-order-validator
```

Types: `@shared:commit-types`

## Commit Message Format

```
{type}: {summary}

{body}

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Rules

- `summary`: max 72 chars, imperative mood
- `body`: wrap at 100 chars, explain "why" not "what"
- `type`: from Conventional Commits

### Examples

```
feat: add calculate_total method to BudgetService

Implement method to sum amounts from budget facts.
This enables total calculation for budget reports.

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>
```

```
fix: handle null pointer in OrderValidator

Add null check before accessing order.items property.
Fixes #123.

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Git Commands

### Create Branch

```bash
git checkout {base_branch}
git pull origin {base_branch}
git checkout -b {branch_name}
```

### Commit

```bash
git add {files}
git commit -m "{message}"
```

### Push

```bash
git push -u origin {branch_name}
```

## Output

```json
{
  "git_result": {
    "branch": "feature/add-calculate-total",
    "commit_hash": "abc123def",
    "commit_message": "feat: add calculate_total method",
    "files_committed": ["service.py"],
    "pushed": true,
    "remote": "origin"
  }
}
```

## Task Summary

После push выводить summary.

Template: `@template:task-summary`

Пример:
```
═══════════════════════════════════════════════════════════
                    ✅ ЗАДАЧА ЗАВЕРШЕНА
═══════════════════════════════════════════════════════════

СТАТУС: ✓ COMPLETED

СДЕЛАНО:
- Добавлен метод calculate_total в BudgetService
- Написаны unit-тесты для нового метода

ФАЙЛЫ:
- app/services/budget_service.py (modified)
- tests/test_budget_service.py (created)

GIT:
- Branch: feature/add-calculate-total
- Commit: abc123def
- Pushed: origin/feature/add-calculate-total

═══════════════════════════════════════════════════════════
```

## Safety Rules

```yaml
NEVER:
  - force push to main/master
  - commit secrets/credentials
  - use --no-verify
  - amend others' commits

ALWAYS:
  - check branch before commit
  - verify files to commit
  - use conventional commit format
```

## Pre-Commit Validation (v2.1.0)

**Новое:** Для обеспечения качества commit, добавляется массив `validation_checks[]` с pre-commit checks.

**Структура:**
```json
{
  "git_result": {
    "branch": "feature/add-calculate-total",
    "commit_hash": "abc123def",
    "commit_message": "feat: add calculate_total method",
    "files_committed": ["service.py", "test_service.py"],
    "pushed": true,
    "remote": "origin",
    "validation_checks": [
      {
        "check_id": 1,
        "check_name": "Syntax validation",
        "command": "python -m py_compile service.py",
        "status": "passed",
        "duration_ms": 120,
        "details": "No syntax errors"
      },
      {
        "check_id": 2,
        "check_name": "Unit tests",
        "command": "pytest tests/test_service.py",
        "status": "passed",
        "duration_ms": 450,
        "details": "8 passed, 0 failed"
      },
      {
        "check_id": 3,
        "check_name": "Code linting",
        "command": "pylint service.py",
        "status": "passed",
        "duration_ms": 230,
        "details": "Score: 9.5/10"
      },
      {
        "check_id": 4,
        "check_name": "Type checking",
        "command": "mypy service.py",
        "status": "passed",
        "duration_ms": 180,
        "details": "No type errors"
      },
      {
        "check_id": 5,
        "check_name": "Security scan",
        "command": "bandit -r .",
        "status": "passed",
        "duration_ms": 340,
        "details": "No security issues"
      }
    ]
  }
}
```

Используется когда:
- Pre-commit hooks enabled
- Quality gates требуются перед commit
- CI/CD-style validation локально

## TOON Format Support (v2.1.0)

**Назначение:** Автоматическая оптимизация токенов для validation_checks[] массива.

### Threshold

TOON генерируется если **validation_checks[] >= 5**

### Target Array

**validation_checks[]**
- Обычно: 3-10 checks per commit
- Поля: check_id, check_name, command, status, duration_ms, details
- Token savings: ~20-30% для 5+ checks

### Output Structure

**Git Result (с TOON):**
```json
{
  "git_result": {
    "branch": "feature/auth-system",
    "commit_hash": "abc123def456",
    "commit_message": "feat: add JWT authentication endpoints",
    "files_committed": ["auth_service.py", "auth.py", "security.py", "test_auth.py", "test_endpoints.py"],
    "pushed": true,
    "remote": "origin",
    "validation_checks": [
      {"check_id": 1, "check_name": "Syntax validation", "command": "python -m py_compile *.py", "status": "passed", "duration_ms": 150, "details": "All 5 files valid"},
      {"check_id": 2, "check_name": "Unit tests", "command": "pytest tests/", "status": "passed", "duration_ms": 680, "details": "24 passed, 0 failed"},
      {"check_id": 3, "check_name": "Code linting", "command": "pylint --rcfile=.pylintrc *.py", "status": "passed", "duration_ms": 420, "details": "Average score: 9.2/10"},
      {"check_id": 4, "check_name": "Type checking", "command": "mypy --strict *.py", "status": "passed", "duration_ms": 290, "details": "No type errors found"},
      {"check_id": 5, "check_name": "Security scan", "command": "bandit -r . -ll", "status": "passed", "duration_ms": 510, "details": "No high/medium severity issues"},
      {"check_id": 6, "check_name": "Code coverage", "command": "pytest --cov=app tests/", "status": "passed", "duration_ms": 720, "details": "Coverage: 87%"}
    ],
    "toon": {
      "validation_checks_toon": "validation_checks[6]{check_id,check_name,command,status,duration_ms,details}:\n  1,Syntax validation,python -m py_compile *.py,passed,150,All 5 files valid\n  2,Unit tests,pytest tests/,passed,680,24 passed 0 failed\n  3,Code linting,pylint --rcfile=.pylintrc *.py,passed,420,Average score: 9.2/10\n  4,Type checking,mypy --strict *.py,passed,290,No type errors found\n  5,Security scan,bandit -r . -ll,passed,510,No high/medium severity issues\n  6,Code coverage,pytest --cov=app tests/,passed,720,Coverage: 87%",
      "token_savings": "26.1%",
      "size_comparison": "JSON: 1580 tokens, TOON: 1168 tokens"
    }
  }
}
```

### Implementation Pattern

```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Git result with validation checks
const gitResult = {
  branch: "feature/auth-system",
  commit_hash: "abc123def456",
  validation_checks: [...]  // 6+ checks
};

// Add TOON optimization (только для validation_checks >= 5)
if (gitResult.validation_checks.length >= 5) {
  gitResult.toon = {
    validation_checks_toon: arrayToToon('validation_checks', gitResult.validation_checks,
      ['check_id', 'check_name', 'command', 'status', 'duration_ms', 'details']),
    ...calculateTokenSavings({ validation_checks: gitResult.validation_checks })
  };
}
```

### Token Savings Examples

| Scenario | JSON Tokens | TOON Tokens | Savings | Checks |
|----------|-------------|-------------|---------|--------|
| Standard checks (5 checks) | 1320 | 1010 | 23.5% | 5 |
| Comprehensive (6 checks) | 1580 | 1168 | 26.1% | 6 |
| Full suite (8 checks) | 2100 | 1520 | 27.6% | 8 |

**Typical use case:** Commit с 6 pre-commit checks: **~26% token reduction**

### Backward Compatibility

- ✅ JSON format always present (primary format)
- ✅ TOON field optional (only when threshold met)
- ✅ Simple output without checks unchanged
- ✅ Zero breaking changes для downstream consumers

### When TOON is Generated

**Always generated:**
- Commits with comprehensive pre-commit validation (5+ checks)
- Quality-gated workflows
- CI/CD-style local validation

**Not generated:**
- Simple commits (< 5 validation checks)
- No pre-commit hooks configured
- Quick commits без validation

См. также: **toon-skill** для API документации, **_shared/TOON-PATTERNS.md** для integration patterns.

