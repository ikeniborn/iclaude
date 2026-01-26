---
name: Git Workflow
description: Стандартизированный git workflow с Conventional Commits
version: 2.2.0
tags: [git, commit, branch, conventional-commits, toon]
dependencies: []
files:
  templates: ./templates/*.txt
  examples: ./examples/*.md
  shared: ../_shared/commit-types.json
user-invocable: false
changelog:
  - version: 2.2.0
    date: 2026-01-25
    changes:
      - "Централизация: Branch naming и commit format → @shared:GIT-CONVENTIONS.md"
      - "Централизация: TOON support → @shared:TOON-REFERENCE.md"
      - "Добавлено: 7 полных workflow примеров (feature, hotfix, multi-file, etc.)"
      - "Сокращено: -95 строк дублированного контента"
  - version: 2.1.0
    date: 2026-01-23
    changes:
      - "TOON Format Support для validation_checks[] (26% token savings)"
      - "Pre-commit validation checks массив"
---

# Git Workflow v2.2

Стандартизированный git workflow с Conventional Commits.

## Когда использовать

- При создании ветки (Phase 1.5) [NEW]
- При commit (Phase 5A)
- При создании PR (Phase 5B)

## Режимы работы

git-workflow поддерживает 2 режима:

**Mode 1: create-branch** (PHASE 1.5)
- Input: branch_name from task_plan.git.branch_name
- Actions: checkout base → pull → create branch → switch
- Output: {branch, switched: true}

**Mode 2: commit-and-push** (PHASE 5A)
- Input: files, commit_message
- Actions: stage → commit → push
- Output: {commit_hash, files_committed, pushed}
- Assumption: Already on correct branch (created in PHASE 1.5)

---

## References

### Git Conventions

**Branch Naming:**
```
@shared:GIT-CONVENTIONS.md#branch-naming-convention
```

Pattern: `{type}/{slug}` (e.g., `feature/add-user-auth`)

**Commit Message Format:**
```
@shared:GIT-CONVENTIONS.md#conventional-commits-format
```

Structure:
```
{type}: {summary}

{body}

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Full specification:** См. `@shared:GIT-CONVENTIONS.md` для:
- Все commit types (feat, fix, refactor, etc.)
- Branch naming rules и validation regex
- Breaking changes format
- 35+ reference примеров

### TOON Format

**TOON Support:**
```
@shared:TOON-REFERENCE.md
```

git-workflow генерирует TOON для `validation_checks[]` когда >= 5 элементов.

**Target array:** validation_checks (pre-commit validation results)
**Token savings:** 20-30% для 5+ checks
**Implementation:** См. `@shared:TOON-REFERENCE.md#pattern-1-simple-array-conversion`

---

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

---

## Mode 1: Create Branch Only (PHASE 1.5)

### Usage

Called after structured-planning to create development branch before any code changes.

### Input Schema

```json
{
  "branch_name": "dev/add-user-auth_20260126143022",
  "base_branch": "main"
}
```

### Commands

```bash
# 1. Switch to base branch
git checkout {base_branch}

# 2. Pull latest changes
git pull origin {base_branch}

# 3. Create and switch to new branch
git checkout -b {branch_name}

# 4. Verify current branch
git branch --show-current
```

### Output Schema

```json
{
  "git_branch_result": {
    "branch": "dev/add-user-auth_20260126143022",
    "base_branch": "main",
    "switched": true,
    "timestamp": "2026-01-26T14:30:22Z"
  }
}
```

### Error Handling

**Branch already exists:**
- Check if branch exists: `git rev-parse --verify {branch_name}`
- If exists: Use unique suffix `_v2`, `_v3`, etc.
- Example: `dev/add-user-auth_20260126143022_v2`

**Base branch not found:**
- Fail with error message
- User must specify correct base branch in CORE REQUIREMENTS #1

**Uncommitted changes:**
- Fail with error message
- User must commit or stash changes before creating new branch

---

## Mode 2: Commit & Push (PHASE 5A)

### Usage

Called after code execution and validation to commit and push changes.

**Assumption:** Already on development branch (created in PHASE 1.5)

### Commands

```bash
# Verify we're on the correct branch
current_branch=$(git branch --show-current)
if [[ "$current_branch" != "$expected_branch" ]]; then
  echo "ERROR: Expected branch $expected_branch, but on $current_branch"
  exit 1
fi

git add {files}
git commit -m "{message}"
git push -u origin {branch}
```

---

## Output Schema

```json
{
  "git_result": {
    "mode": "commit-and-push",
    "branch": "dev/add-calculate-total_20260126143022",
    "commit_hash": "abc123def",
    "commit_message": "feat: add calculate_total method",
    "files_committed": ["service.py"],
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
      }
    ],
    "toon": {
      "validation_checks_toon": "validation_checks[5]{...}:\n  ...",
      "token_savings": "23.5%"
    }
  }
}
```

**Fields:**
- `mode` - Execution mode: "create-branch" (PHASE 1.5) or "commit-and-push" (PHASE 5A)
- `branch` - Branch name (matches pattern from GIT-CONVENTIONS.md)
- `commit_hash` - Short commit SHA (only for mode: commit-and-push)
- `commit_message` - Full commit message (Conventional Commits format, only for mode: commit-and-push)
- `files_committed` - Array of file paths (only for mode: commit-and-push)
- `pushed` - Boolean (whether pushed to remote, only for mode: commit-and-push)
- `remote` - Remote name (usually "origin", only for mode: commit-and-push)
- `validation_checks` - Array of pre-commit validation results (optional, only for mode: commit-and-push)
- `toon` - TOON optimization (optional, if validation_checks >= 5, only for mode: commit-and-push)
- `switched` - Boolean (whether switched to new branch, only for mode: create-branch)
- `base_branch` - Base branch name (only for mode: create-branch)
- `timestamp` - ISO 8601 timestamp (only for mode: create-branch)

---

## Task Summary

После push выводить enhanced summary.

**Template:** `@template:task-summary`

**Example:**
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

VALIDATION:
- 5/5 checks passed (syntax, tests, lint, types, security)
- Total duration: 1.32s

═══════════════════════════════════════════════════════════
```

---

## Safety Rules

```yaml
NEVER:
  - force push to main/master (use --force-with-lease only if needed)
  - commit secrets/credentials (.env, API keys, tokens)
  - use --no-verify (bypasses pre-commit hooks)
  - amend others' commits (only your own unpushed commits)
  - push directly to protected branches (always create PR)

ALWAYS:
  - check branch before commit (git branch --show-current)
  - verify files to commit (git status, git diff)
  - use conventional commit format (type: summary)
  - include co-author for AI-generated code
  - run validation checks before commit (if configured)
```

---

## Domain-Specific Examples

### Example 1: Feature Branch Workflow (Standard)

**Task:** Add user authentication endpoint

**Workflow:**

1. **Create branch:**
```bash
git checkout main
git pull origin main
git checkout -b feature/user-authentication
```

2. **Make changes:**
- Create `app/api/auth.py` (login endpoint)
- Create `app/services/jwt_service.py` (JWT generation)
- Create `tests/test_auth.py` (unit tests)

3. **Commit:**
```bash
git add app/api/auth.py app/services/jwt_service.py tests/test_auth.py
git commit -m "feat(api): add user authentication endpoint

Implement JWT-based authentication with login endpoint.
Supports email/password credentials and returns access token.

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

4. **Push:**
```bash
git push -u origin feature/user-authentication
```

**Output:**
```json
{
  "git_result": {
    "branch": "feature/user-authentication",
    "commit_hash": "a1b2c3d",
    "commit_message": "feat(api): add user authentication endpoint",
    "files_committed": ["app/api/auth.py", "app/services/jwt_service.py", "tests/test_auth.py"],
    "pushed": true,
    "remote": "origin"
  }
}
```

---

### Example 2: Hotfix Workflow (Emergency Fix)

**Task:** Fix critical SQL injection vulnerability

**Workflow:**

1. **Create hotfix branch:**
```bash
git checkout main
git pull origin main
git checkout -b fix/sql-injection-auth
```

2. **Fix issue:**
- Edit `app/api/auth.py` (use parameterized query)

3. **Commit with issue reference:**
```bash
git add app/api/auth.py
git commit -m "fix(security): prevent SQL injection in auth endpoint

Replace string concatenation with parameterized query.
Fixes critical security vulnerability.

Fixes #456

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

4. **Push immediately:**
```bash
git push -u origin fix/sql-injection-auth
```

**Output:**
```json
{
  "git_result": {
    "branch": "fix/sql-injection-auth",
    "commit_hash": "d4e5f6g",
    "commit_message": "fix(security): prevent SQL injection in auth endpoint",
    "files_committed": ["app/api/auth.py"],
    "pushed": true,
    "remote": "origin",
    "validation_checks": [
      {"check_id": 1, "check_name": "Security scan", "command": "bandit -r .", "status": "passed", "duration_ms": 340, "details": "No issues found"}
    ]
  }
}
```

---

### Example 3: Multi-File Refactoring

**Task:** Extract validation logic to separate class

**Workflow:**

1. **Create refactor branch:**
```bash
git checkout -b refactor/extract-order-validator
```

2. **Make changes:**
- Create `app/validators/order_validator.py` (new validator class)
- Modify `app/services/order_service.py` (use new validator)
- Update `tests/test_order_service.py` (update tests)
- Delete `app/utils/validation.py` (old validation code)

3. **Commit:**
```bash
git add app/validators/order_validator.py app/services/order_service.py tests/test_order_service.py
git rm app/utils/validation.py
git commit -m "refactor: extract validation logic to OrderValidator class

Move validation code from OrderService to separate validator.
No functional changes, improves testability and maintainability.

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

4. **Push:**
```bash
git push -u origin refactor/extract-order-validator
```

**Output:**
```json
{
  "git_result": {
    "branch": "refactor/extract-order-validator",
    "commit_hash": "h7i8j9k",
    "commit_message": "refactor: extract validation logic to OrderValidator class",
    "files_committed": [
      "app/validators/order_validator.py",
      "app/services/order_service.py",
      "tests/test_order_service.py"
    ],
    "files_deleted": ["app/utils/validation.py"],
    "pushed": true,
    "remote": "origin"
  }
}
```

---

### Example 4: Breaking Change Workflow

**Task:** Change API response format (breaking change)

**Workflow:**

1. **Create feature branch:**
```bash
git checkout -b feat/api-response-v2
```

2. **Make breaking changes:**
- Modify `app/api/transactions.py` (nested response structure)
- Update `docs/API.md` (document breaking change)
- Update `tests/test_api.py` (update tests)

3. **Commit with breaking change marker:**
```bash
git add app/api/transactions.py docs/API.md tests/test_api.py
git commit -m "feat(api)!: change transaction response format

Return transactions in nested structure for better clarity.

BREAKING CHANGE: Response format changed from flat array
to nested object with pagination metadata. Update clients
to access data via response.data instead of response directly.

Migration guide: docs/migration/v2-api.md

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

4. **Push:**
```bash
git push -u origin feat/api-response-v2
```

**Output:**
```json
{
  "git_result": {
    "branch": "feat/api-response-v2",
    "commit_hash": "k0l1m2n",
    "commit_message": "feat(api)!: change transaction response format",
    "files_committed": ["app/api/transactions.py", "docs/API.md", "tests/test_api.py"],
    "pushed": true,
    "remote": "origin",
    "breaking_change": true
  }
}
```

---

### Example 5: Commit with Pre-Commit Validation

**Task:** Add calculate_total method with comprehensive validation

**Workflow:**

1. **Create branch:**
```bash
git checkout -b feature/calculate-total
```

2. **Make changes:**
- Add method to `app/services/budget_service.py`
- Add tests to `tests/test_budget_service.py`

3. **Commit triggers pre-commit hooks:**
```bash
git add app/services/budget_service.py tests/test_budget_service.py
git commit -m "feat: add calculate_total method to BudgetService

Implement method to sum amounts from budget facts.
This enables total calculation for budget reports.

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# Pre-commit hooks automatically run:
# ✓ Syntax validation (150ms)
# ✓ Unit tests (680ms)
# ✓ Code linting (420ms)
# ✓ Type checking (290ms)
# ✓ Security scan (510ms)
# ✓ Code coverage (720ms)
```

4. **Push:**
```bash
git push -u origin feature/calculate-total
```

**Output (with TOON optimization):**
```json
{
  "git_result": {
    "branch": "feature/calculate-total",
    "commit_hash": "n3o4p5q",
    "commit_message": "feat: add calculate_total method to BudgetService",
    "files_committed": ["app/services/budget_service.py", "tests/test_budget_service.py"],
    "pushed": true,
    "remote": "origin",
    "validation_checks": [
      {"check_id": 1, "check_name": "Syntax validation", "command": "python -m py_compile *.py", "status": "passed", "duration_ms": 150, "details": "All files valid"},
      {"check_id": 2, "check_name": "Unit tests", "command": "pytest tests/", "status": "passed", "duration_ms": 680, "details": "24 passed, 0 failed"},
      {"check_id": 3, "check_name": "Code linting", "command": "pylint *.py", "status": "passed", "duration_ms": 420, "details": "Score: 9.2/10"},
      {"check_id": 4, "check_name": "Type checking", "command": "mypy *.py", "status": "passed", "duration_ms": 290, "details": "No type errors"},
      {"check_id": 5, "check_name": "Security scan", "command": "bandit -r .", "status": "passed", "duration_ms": 510, "details": "No issues"},
      {"check_id": 6, "check_name": "Code coverage", "command": "pytest --cov=app tests/", "status": "passed", "duration_ms": 720, "details": "Coverage: 87%"}
    ],
    "toon": {
      "validation_checks_toon": "validation_checks[6]{check_id,check_name,command,status,duration_ms,details}:\n  1,Syntax validation,python -m py_compile *.py,passed,150,All files valid\n  2,Unit tests,pytest tests/,passed,680,24 passed 0 failed\n  3,Code linting,pylint *.py,passed,420,Score: 9.2/10\n  4,Type checking,mypy *.py,passed,290,No type errors\n  5,Security scan,bandit -r .,passed,510,No issues\n  6,Code coverage,pytest --cov=app tests/,passed,720,Coverage: 87%",
      "token_savings": "26.1%",
      "size_comparison": "JSON: 1580 tokens, TOON: 1168 tokens"
    }
  }
}
```

---

### Example 6: Documentation Update

**Task:** Update API documentation

**Workflow:**

1. **Create docs branch:**
```bash
git checkout -b docs/api-endpoints
```

2. **Update documentation:**
- Edit `docs/API.md` (add new endpoint documentation)
- Edit `README.md` (update getting started guide)

3. **Commit:**
```bash
git add docs/API.md README.md
git commit -m "docs: add API documentation for transaction endpoints

Document all CRUD endpoints with request/response examples.
Add authentication requirements and error codes.

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

4. **Push:**
```bash
git push -u origin docs/api-endpoints
```

**Output:**
```json
{
  "git_result": {
    "branch": "docs/api-endpoints",
    "commit_hash": "q6r7s8t",
    "commit_message": "docs: add API documentation for transaction endpoints",
    "files_committed": ["docs/API.md", "README.md"],
    "pushed": true,
    "remote": "origin"
  }
}
```

---

### Example 7: Performance Optimization

**Task:** Optimize database queries

**Workflow:**

1. **Create perf branch:**
```bash
git checkout -b perf/optimize-queries
```

2. **Make optimizations:**
- Modify `app/services/transaction_service.py` (add index hints)
- Modify `app/models/transaction.py` (add composite index)
- Update `tests/test_performance.py` (verify improvements)

3. **Commit:**
```bash
git add app/services/transaction_service.py app/models/transaction.py tests/test_performance.py
git commit -m "perf: optimize transaction query performance

Add composite index on (user_id, date) for faster filtering.
Add query hints to use index efficiently.

Reduces query time from 450ms to 85ms (81% improvement).

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

4. **Push:**
```bash
git push -u origin perf/optimize-queries
```

**Output:**
```json
{
  "git_result": {
    "branch": "perf/optimize-queries",
    "commit_hash": "t9u0v1w",
    "commit_message": "perf: optimize transaction query performance",
    "files_committed": [
      "app/services/transaction_service.py",
      "app/models/transaction.py",
      "tests/test_performance.py"
    ],
    "pushed": true,
    "remote": "origin"
  }
}
```

---

## Integration with Other Skills

### structured-planning

**Uses git field from task_plan:**
```json
{
  "task_plan": {
    "git": {
      "branch_name": "feature/transaction-filtering",
      "commit_type": "feat",
      "commit_summary": "add transaction filtering endpoint"
    }
  }
}
```

git-workflow executes:
1. Create branch from `git.branch_name`
2. Generate commit message from `git.commit_type` + `git.commit_summary`
3. Add co-author footer automatically

### validation-framework

**validation_checks integration:**

validation-framework results → git-workflow.validation_checks[]

If pre-commit hooks enabled, git-workflow runs validation before commit and includes results in output.

### pr-automation

**git_result usage:**

git-workflow output → pr-automation input

pr-automation uses `git_result.branch` для creating PR from current branch to target branch.

---

## Best Practices

### ✅ DO

1. **Always verify branch** before committing (`git branch --show-current`)
2. **Review staged files** before commit (`git diff --staged`)
3. **Use meaningful commit messages** (explain "why", not "what")
4. **Include issue references** when fixing bugs (`Fixes #123`)
5. **Mark breaking changes** with `!` and `BREAKING CHANGE:` footer
6. **Run validation checks** before commit (if configured)
7. **Push after commit** to backup work to remote

### ❌ DON'T

1. **Skip commit message body** for non-trivial changes
2. **Use generic messages** ("fix bug", "update code")
3. **Commit secrets** (use .gitignore for sensitive files)
4. **Force push** to shared branches (main, develop)
5. **Bypass pre-commit hooks** (--no-verify) without good reason
6. **Amend commits** after pushing to shared branch
7. **Push directly** to protected branches (always create PR)

---

## Version History

### v2.2.0 (2026-01-25)

- ✅ Centralized git conventions → `@shared:GIT-CONVENTIONS.md`
- ✅ Centralized TOON support → `@shared:TOON-REFERENCE.md`
- ✅ Added 7 complete workflow examples (feature, hotfix, multi-file, breaking, validation, docs, perf)
- ✅ Reduced duplication: -95 lines (TOON секция удалена)
- ✅ Enhanced task summary template

### v2.1.0 (2026-01-23)

- ✅ TOON Format Support для validation_checks[]
- ✅ Pre-commit validation checks массив
- ✅ Token savings: 20-30% для 5+ checks

### v2.0.0

- ✅ Initial standardized workflow
- ✅ Conventional Commits integration
- ✅ Co-authored commits для AI code

---

**Author:** Claude Code Team
**License:** MIT
**Support:** См. @shared:GIT-CONVENTIONS.md для полной git спецификации
