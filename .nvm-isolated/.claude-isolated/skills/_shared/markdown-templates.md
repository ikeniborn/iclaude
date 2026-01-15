# Markdown Output Templates - Shared Component

**Version:** 1.0.0
**Author:** iclaude Skills Team
**Purpose:** Стандартизированные Markdown шаблоны для единообразного вывода всех skills

---

## Overview

Этот компонент определяет стандартные форматы Markdown output для всех skills. Использование этих темплейтов обеспечивает консистентность документации и улучшает читаемость.

**Используется в:**
- structured-planning (task plan output)
- code-review (review report)
- pr-automation (PR body)
- git-workflow (task summary)

---

## General Formatting Rules

### Heading Levels

```markdown
## Основной заголовок (h2) - для секций
### Подзаголовок (h3) - для подсекций
#### Детали (h4) - для деталей
```

**Rules:**
- h1 (`#`) - НЕ используется (резервируется для названия документа)
- h2 (`##`) - Основные секции (Problem, Solution, Acceptance Criteria)
- h3 (`###`) - Подсекции (Step 1, Risk 1)
- h4 (`####`) - Детали (Actions, Validation)

---

### Code Blocks

```markdown
\u0060\u0060\u0060language
code here
\u0060\u0060\u0060
```

**Supported languages:**
- `bash` - Shell commands
- `python` - Python code
- `typescript` - TypeScript/JavaScript code
- `json` - JSON data
- `yaml` - YAML configuration
- `sql` - SQL queries
- `markdown` - Markdown examples

---

### Lists

**Unordered lists:**
```markdown
- Item 1
- Item 2
  - Nested item (2 spaces indent)
```

**Ordered lists:**
```markdown
1. Step 1
2. Step 2
   - Sub-item (3 spaces indent to align with step text)
```

**Checklist:**
```markdown
- [ ] Incomplete task
- [x] Completed task
```

---

### Emphasis

```markdown
**Bold** - Ключевые термины, статусы (BLOCKING, WARNING, SUCCESS)
*Italic* - Примечания, опциональные поля
`code` - Переменные, команды, file paths
```

---

### Links

```markdown
[Link text](URL or file path)
[@skill:skill-name](../skill-name/SKILL.md) - Ссылка на другой skill
```

---

## Template 1: Task Plan Output (structured-planning)

**Used by:** structured-planning skill

**Format:**

```markdown
## Task Plan: {task_name}

### Problem
{problem_description}

### Solution
{solution_description}

### Acceptance Criteria
- [ ] {criterion_1}
- [ ] {criterion_2}
- [ ] {criterion_3}

### Files to Change
| File | Change Type | Description |
|------|-------------|-------------|
| `{file_path_1}` | {create/modify/delete} | {description_1} |
| `{file_path_2}` | {modify} | {description_2} |

### Execution Steps

#### Step 1: {step_description}

**Actions:**
- {action_1}
- {action_2}

**Validation:**
- {validation_method}

#### Step 2: {step_description}

**Actions:**
- {action_1}

**Validation:**
- {validation_method}

### Risks & Mitigation (Optional)

| Risk | Mitigation |
|------|-----------|
| {risk_1} | {mitigation_1} |
| {risk_2} | {mitigation_2} |

### Git Configuration
- **Branch:** `{branch_name}`
- **Base branch:** `{base_branch}`
- **Commit type:** `{commit_type}`
- **Commit summary:** {commit_summary}

---

**Plan generated with Claude Code**
```

**Example:**

```markdown
## Task Plan: Add User Authentication

### Problem
Application lacks user authentication, allowing unauthorized access to sensitive data.

### Solution
Implement JWT-based authentication with FastAPI, including login endpoint, token generation, and middleware for protected routes.

### Acceptance Criteria
- [ ] User can login with email/password
- [ ] JWT token is generated on successful login
- [ ] Protected routes require valid token
- [ ] Token expiration is enforced

### Files to Change
| File | Change Type | Description |
|------|-------------|-------------|
| `src/api/auth.py` | create | Add login endpoint and token generation |
| `src/middleware/auth_middleware.py` | create | Add JWT validation middleware |
| `tests/test_auth.py` | create | Add authentication tests |

### Execution Steps

#### Step 1: Create authentication endpoint

**Actions:**
- Create `src/api/auth.py`
- Add `/login` POST endpoint
- Implement email/password validation
- Generate JWT token on success

**Validation:**
- Run `pytest tests/test_auth.py::test_login_success`
- Verify 200 OK response with token

#### Step 2: Add JWT middleware

**Actions:**
- Create `src/middleware/auth_middleware.py`
- Implement token validation logic
- Add middleware to FastAPI app

**Validation:**
- Test protected endpoint returns 401 without token
- Test protected endpoint returns 200 with valid token

### Git Configuration
- **Branch:** `feature/user-auth`
- **Base branch:** `main`
- **Commit type:** `feat`
- **Commit summary:** Add JWT-based user authentication

---

**Plan generated with Claude Code**
```

---

## Template 2: Code Review Report (code-review)

**Used by:** code-review skill

**Format:**

```markdown
## Code Review Report

**Score:** {score}/100

**Status:** {PASSED/WARNING/BLOCKING}

---

### Summary

{overall_summary_1_2_sentences}

---

### Issues Found ({issue_count})

#### BLOCKING Issues ({blocking_count})

##### Issue 1: {category} - {file}:{line}

**Severity:** BLOCKING

**Message:** {issue_message}

**Suggestion:** {suggestion}

**Code:**
\u0060\u0060\u0060{language}
{code_snippet}
\u0060\u0060\u0060

---

#### WARNING Issues ({warning_count})

##### Issue 2: {category} - {file}:{line}

**Severity:** WARNING

**Message:** {issue_message}

**Suggestion:** {suggestion}

---

### Code Quality Metrics

| Metric | Score | Details |
|--------|-------|---------|
| Security | {score}/25 | {details} |
| Code Quality | {score}/25 | {details} |
| Error Handling | {score}/25 | {details} |
| Type Safety | {score}/25 | {details} |

---

### Recommendations

- {recommendation_1}
- {recommendation_2}

---

**Review completed with Claude Code**
```

**Example:**

```markdown
## Code Review Report

**Score:** 85/100

**Status:** WARNING

---

### Summary

Code is generally well-structured with good error handling. Found 2 warnings related to type safety and 1 SQL injection vulnerability.

---

### Issues Found (3)

#### BLOCKING Issues (1)

##### Issue 1: security - src/api/users.py:42

**Severity:** BLOCKING

**Message:** Potential SQL injection vulnerability - user input not sanitized

**Suggestion:** Use parameterized query instead of string concatenation

**Code:**
\u0060\u0060\u0060python
query = f"SELECT * FROM users WHERE email = '{email}'"  # DANGEROUS
cursor.execute(query)
\u0060\u0060\u0060

**Fix:**
\u0060\u0060\u0060python
query = "SELECT * FROM users WHERE email = %s"
cursor.execute(query, (email,))
\u0060\u0060\u0060

---

#### WARNING Issues (2)

##### Issue 2: type_safety - src/service.py:15

**Severity:** WARNING

**Message:** Function parameter lacks type hint

**Suggestion:** Add type hints for better type checking

---

### Code Quality Metrics

| Metric | Score | Details |
|--------|-------|---------|
| Security | 18/25 | 1 SQL injection vulnerability |
| Code Quality | 23/25 | Good structure, minor naming issues |
| Error Handling | 22/25 | Missing try-catch in 1 location |
| Type Safety | 22/25 | 2 missing type hints |

---

### Recommendations

- Fix SQL injection vulnerability before merging
- Add type hints for better maintainability
- Consider adding error handling in data parsing

---

**Review completed with Claude Code**
```

---

## Template 3: PR Body (pr-automation)

**Used by:** pr-automation skill

**Format:**

```markdown
## Summary

{1-3_bullet_points_summarizing_changes}

---

## Changes Made

### Files Changed ({file_count})
{list_of_changed_files_with_change_types}

### Key Updates
- {key_update_1}
- {key_update_2}

---

## Test Plan

- [ ] {test_item_1}
- [ ] {test_item_2}
- [ ] {test_item_3}

---

## CI/CD Status

{table_of_checks_with_status}

---

## Related Issues

Closes #{issue_number}
Relates to #{issue_number}

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

**Example:**

```markdown
## Summary

- Added JWT-based user authentication system
- Implemented login endpoint with token generation
- Added middleware for protected routes

---

## Changes Made

### Files Changed (5)
- ✨ **create** `src/api/auth.py` - Login endpoint
- ✨ **create** `src/middleware/auth_middleware.py` - JWT validation
- ✨ **create** `tests/test_auth.py` - Authentication tests
- 📝 **modify** `src/main.py` - Add middleware
- 📝 **modify** `requirements.txt` - Add PyJWT dependency

### Key Updates
- Implemented JWT token generation with 1-hour expiration
- Added password hashing with bcrypt
- Protected all `/api/v1/users/*` endpoints

---

## Test Plan

- [x] Unit tests for login endpoint
- [x] Integration tests for protected routes
- [x] Token expiration tests
- [ ] Manual testing with Postman
- [ ] Load testing with 100 concurrent users

---

## CI/CD Status

| Check | Status |
|-------|--------|
| TypeScript Type Check | ✅ Passed |
| Unit & Integration Tests | ✅ Passed |
| Build Verification | ✅ Passed |
| Linting & Formatting | ✅ Passed |

---

## Related Issues

Closes #123
Relates to #456

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Template 4: Task Summary (git-workflow)

**Used by:** git-workflow skill

**Format:**

```markdown
## Task Completed: {task_name}

**Status:** ✅ SUCCESS / ⚠️ WARNING / ❌ FAILED

**Duration:** {duration_minutes}m {duration_seconds}s

---

### What Was Done

{summary_of_work_done}

---

### Files Changed ({file_count})

| File | Lines Added | Lines Deleted | Change Type |
|------|-------------|---------------|-------------|
| {file_1} | +{n} | -{m} | {modify/create/delete} |
| {file_2} | +{n} | -{m} | {modify} |

---

### Git Information

- **Branch:** `{branch_name}`
- **Commit:** `{commit_hash}`
- **Commit message:** {commit_summary}

---

### Metrics

- **Code review score:** {score}/100
- **Tests:** {passed}/{total} passed
- **Build:** {SUCCESS/FAILED}

---

### Next Steps

- {next_step_1}
- {next_step_2}

---

🤖 Task completed with Claude Code
```

**Example:**

```markdown
## Task Completed: Add User Authentication

**Status:** ✅ SUCCESS

**Duration:** 12m 34s

---

### What Was Done

Implemented JWT-based authentication system with login endpoint, token generation, and middleware for protected routes. All tests passing, code review score 92/100.

---

### Files Changed (5)

| File | Lines Added | Lines Deleted | Change Type |
|------|-------------|---------------|-------------|
| src/api/auth.py | +87 | -0 | create |
| src/middleware/auth_middleware.py | +45 | -0 | create |
| tests/test_auth.py | +112 | -0 | create |
| src/main.py | +3 | -1 | modify |
| requirements.txt | +1 | -0 | modify |

---

### Git Information

- **Branch:** `feature/user-auth`
- **Commit:** `abc123def`
- **Commit message:** feat(auth): add JWT-based user authentication

---

### Metrics

- **Code review score:** 92/100
- **Tests:** 45/45 passed
- **Build:** SUCCESS

---

### Next Steps

- Create pull request to `main` branch
- Request code review from team
- Deploy to staging environment after approval

---

🤖 Task completed with Claude Code
```

---

## Usage in Skills

### Referencing Templates

Skills должны ссылаться на эти темплейты следующим образом:

```markdown
## Output Format

Use [@shared:markdown-templates](../_shared/markdown-templates.md) for consistent Markdown output.

**Template:** Task Plan Output (Template 1)

See [@shared:markdown-templates#template-1-task-plan-output](../_shared/markdown-templates.md#template-1-task-plan-output) for complete format.
```

---

## Version History

- **1.0.0** (2026-01-15): Initial version
  - Template 1: Task Plan Output
  - Template 2: Code Review Report
  - Template 3: PR Body
  - Template 4: Task Summary
  - General formatting rules

---

## References

- [structured-planning/SKILL.md](../structured-planning/SKILL.md) - Task plan generation
- [code-review/SKILL.md](../code-review/SKILL.md) - Code review output
- [pr-automation/SKILL.md](../pr-automation/SKILL.md) - PR body generation
- [git-workflow/SKILL.md](../git-workflow/SKILL.md) - Task summary
- [Markdown Guide](https://www.markdownguide.org/)
