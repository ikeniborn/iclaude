# Task Structure Reference

**Version:** 1.0.0
**Last Updated:** 2026-01-25
**Purpose:** Централизованная документация JSON schemas для task plans, file changes, code review, tests и validation

---

## Overview

Этот документ описывает structure и validation rules для всех structured outputs, используемых в Claude Code Skills. Все schemas определены в `@shared:base-schema.json` и переиспользуются между skills.

**Ключевые принципы:**
- ✅ Single source of truth для JSON schemas
- ✅ Reusable definitions через $ref
- ✅ Adaptive schemas (lite vs full)
- ✅ Field-by-field documentation
- ✅ JSON Schema Draft 07 compliance

**Кому это нужно:**
- structured-planning skill (task plans)
- validation-framework skill (validation results)
- code-review skill (code review issues)
- git-workflow skill (git operations)
- Все skills генерирующие structured output

---

## Schema Definitions Overview

`base-schema.json` содержит 10 reusable definitions:

| Definition | Purpose | Primary Consumer |
|------------|---------|------------------|
| **git** | Git branch/commit info | git-workflow, structured-planning |
| **file_change** | File modification | structured-planning, code-review |
| **code_review_issue** | Code review warning | code-review |
| **test_result** | Test execution result | validation-framework |
| **execution_step** | Task plan step | structured-planning |
| **validation_result** | Validation result | validation-framework |
| **skill_dependency** | Skill dependency | All skills (frontmatter) |
| **toon_optimization** | TOON format data | All TOON-enabled skills |
| **structured_output_with_toon** | Base structure | Template для TOON skills |

---

## 1. Git Definition

### git-commit

### Purpose

Git branch and commit information для создания branches и commits в соответствии с Conventional Commits.

### JSON Schema

```json
{
  "type": "object",
  "properties": {
    "branch_name": {
      "type": "string",
      "pattern": "^(feature|fix|refactor|chore|test|docs|perf|style)/[a-z0-9_-]+$"
    },
    "commit_type": {
      "type": "string",
      "enum": ["feat", "fix", "refactor", "docs", "test", "chore", "perf", "style"]
    },
    "commit_summary": {
      "type": "string",
      "maxLength": 72,
      "minLength": 10
    },
    "commit_body": {
      "type": "string",
      "maxLength": 500
    },
    "co_authored_by": {
      "type": "string",
      "pattern": "^[^<>]+\\s<[^@]+@[^>]+>$"
    }
  },
  "required": ["branch_name", "commit_type", "commit_summary"]
}
```

### Fields

| Field | Type | Required | Constraints | Description |
|-------|------|----------|-------------|-------------|
| **branch_name** | string | ✅ Yes | Pattern: `{type}/{slug}` | Git branch name (e.g., `feature/add-user-auth`) |
| **commit_type** | string | ✅ Yes | Enum: feat, fix, refactor, etc. | Conventional Commits type |
| **commit_summary** | string | ✅ Yes | 10-72 chars | Commit message summary (imperative mood) |
| **commit_body** | string | ⚠️ Optional | Max 500 chars | Detailed commit message body |
| **co_authored_by** | string | ⚠️ Optional | Pattern: `Name <email>` | Co-author for AI-generated commits |

### Usage Example

```json
{
  "git": {
    "branch_name": "feature/add-calculate-total",
    "commit_type": "feat",
    "commit_summary": "add calculate_total method to BudgetService",
    "commit_body": "Implement method to sum amounts from budget facts.\nThis enables total calculation for budget reports.",
    "co_authored_by": "Claude Sonnet 4.5 <noreply@anthropic.com>"
  }
}
```

### Validation Rules

1. **branch_name:**
   - Must match pattern: `(feature|fix|refactor|...)/kebab-case-slug`
   - Type must be from allowed list
   - Slug must be lowercase with hyphens only

2. **commit_summary:**
   - Max 72 characters (including type и scope)
   - Min 10 characters (must be descriptive)
   - Imperative mood ("add feature" НЕ "added feature")

3. **co_authored_by:**
   - Format: `Full Name <email@domain.com>`
   - Always include для AI-generated commits

### References

- Full specification: `@shared:GIT-CONVENTIONS.md`
- Schema: `@shared:base-schema.json#/definitions/git`

---

## 2. File Change Definition

### Purpose

File modification information для tracking changes в task plans и code reviews.

### JSON Schema

```json
{
  "type": "object",
  "properties": {
    "file_path": {
      "type": "string",
      "minLength": 1
    },
    "change_type": {
      "type": "string",
      "enum": ["create", "modify", "delete", "rename"]
    },
    "description": {
      "type": "string",
      "maxLength": 200
    },
    "old_path": {
      "type": "string"
    },
    "lines_added": {
      "type": "integer",
      "minimum": 0
    },
    "lines_deleted": {
      "type": "integer",
      "minimum": 0
    }
  },
  "required": ["file_path", "change_type"],
  "allOf": [
    {
      "if": { "properties": { "change_type": {"const": "rename"} } },
      "then": { "required": ["old_path"] }
    }
  ]
}
```

### Fields

| Field | Type | Required | Constraints | Description |
|-------|------|----------|-------------|-------------|
| **file_path** | string | ✅ Yes | Min 1 char | Relative or absolute file path |
| **change_type** | string | ✅ Yes | Enum: create, modify, delete, rename | Type of file operation |
| **description** | string | ⚠️ Optional | Max 200 chars | What changed in this file |
| **old_path** | string | ⚠️ Conditional | Required if rename | Original path (for rename) |
| **lines_added** | integer | ⚠️ Optional | >= 0 | Number of lines added |
| **lines_deleted** | integer | ⚠️ Optional | >= 0 | Number of lines deleted |

### Usage Example

```json
{
  "files_to_change": [
    {
      "file_path": "app/services/budget_service.py",
      "change_type": "modify",
      "description": "Add calculate_total method"
    },
    {
      "file_path": "tests/test_budget_service.py",
      "change_type": "create",
      "description": "Create unit tests for calculate_total"
    },
    {
      "file_path": "app/validators/old_validator.py",
      "change_type": "rename",
      "old_path": "app/validators/validator.py",
      "description": "Rename for clarity"
    }
  ]
}
```

### Conditional Requirements

**If change_type === "rename":**
- `old_path` становится required
- `description` should explain why rename

**If change_type === "delete":**
- `description` should explain why deletion
- Consider adding migration notes

### References

- Schema: `@shared:base-schema.json#/definitions/file_change`

---

## 3. Code Review Issue Definition

### code-review

### Purpose

Code review issue/warning с категорией, severity и suggested fix.

### JSON Schema

```json
{
  "type": "object",
  "properties": {
    "category": {
      "type": "string",
      "enum": [
        "security", "code_quality", "error_handling", "type_safety",
        "performance", "maintainability", "best_practices", "naming", "documentation"
      ]
    },
    "severity": {
      "type": "string",
      "enum": ["BLOCKING", "WARNING", "INFO"]
    },
    "file": {
      "type": "string",
      "minLength": 1
    },
    "line": {
      "type": "integer",
      "minimum": 1
    },
    "column": {
      "type": "integer",
      "minimum": 1
    },
    "message": {
      "type": "string",
      "minLength": 10,
      "maxLength": 500
    },
    "suggestion": {
      "type": "string",
      "maxLength": 500
    },
    "code_snippet": {
      "type": "string"
    }
  },
  "required": ["category", "severity", "file", "message"]
}
```

### Fields

| Field | Type | Required | Constraints | Description |
|-------|------|----------|-------------|-------------|
| **category** | string | ✅ Yes | Enum: 9 categories | Issue category (security, code_quality, etc.) |
| **severity** | string | ✅ Yes | Enum: BLOCKING, WARNING, INFO | Severity level |
| **file** | string | ✅ Yes | Min 1 char | File path where issue found |
| **line** | integer | ✅ Yes | >= 1 | Line number where issue found |
| **column** | integer | ⚠️ Optional | >= 1 | Column number (optional precision) |
| **message** | string | ✅ Yes | 10-500 chars | Issue description |
| **suggestion** | string | ⚠️ Optional | Max 500 chars | Suggested fix or improvement |
| **code_snippet** | string | ⚠️ Optional | - | Relevant code showing the issue |

### Severity Levels

| Severity | Meaning | Action Required |
|----------|---------|-----------------|
| **BLOCKING** | Critical issue, must fix BEFORE commit | Fix immediately |
| **WARNING** | Non-critical issue, should fix | Fix if time allows |
| **INFO** | Informational, optional improvement | Optional |

### Categories

**Security (BLOCKING priority):**
- SQL injection, XSS, CSRF
- Hardcoded credentials
- Insecure random, weak crypto

**Code Quality (WARNING):**
- Function too long
- Complex cyclomatic complexity
- Code duplication

**Error Handling (WARNING/BLOCKING):**
- Missing try-catch
- Broad exception catch
- Unhandled edge cases

**Type Safety (WARNING):**
- Missing type hints (Python)
- Any type usage (TypeScript)
- Implicit type conversions

### Usage Example

```json
{
  "warnings": [
    {
      "category": "security",
      "severity": "BLOCKING",
      "file": "src/app.js",
      "line": 42,
      "message": "SQL injection vulnerability - query uses string concatenation",
      "suggestion": "Use parameterized queries with bind variables",
      "code_snippet": "const query = `SELECT * FROM users WHERE id = ${userId}`"
    },
    {
      "category": "code_quality",
      "severity": "WARNING",
      "file": "src/service.py",
      "line": 15,
      "message": "Function too long (72 lines) - exceeds recommended 50 line limit",
      "suggestion": "Extract helper methods for readability"
    }
  ]
}
```

### References

- Schema: `@shared:base-schema.json#/definitions/code_review_issue`
- Code review rules: `@skill:code-review`

---

## 4. Test Result Definition

### Purpose

Test execution result (passed/failed/skipped) с error details.

### JSON Schema

```json
{
  "type": "object",
  "properties": {
    "test_name": {
      "type": "string",
      "minLength": 1
    },
    "status": {
      "type": "string",
      "enum": ["passed", "failed", "skipped", "error"]
    },
    "duration_ms": {
      "type": "number",
      "minimum": 0
    },
    "error_message": {
      "type": "string"
    },
    "stack_trace": {
      "type": "string"
    },
    "file": {
      "type": "string"
    },
    "line": {
      "type": "integer",
      "minimum": 1
    }
  },
  "required": ["test_name", "status"],
  "allOf": [
    {
      "if": { "properties": { "status": {"enum": ["failed", "error"]} } },
      "then": { "required": ["error_message"] }
    }
  ]
}
```

### Fields

| Field | Type | Required | Constraints | Description |
|-------|------|----------|-------------|-------------|
| **test_name** | string | ✅ Yes | Min 1 char | Test case name/description |
| **status** | string | ✅ Yes | Enum: passed, failed, skipped, error | Test result |
| **duration_ms** | number | ⚠️ Optional | >= 0 | Execution time (milliseconds) |
| **error_message** | string | ⚠️ Conditional | - | Error message (required if failed/error) |
| **stack_trace** | string | ⚠️ Optional | - | Full stack trace for debugging |
| **file** | string | ⚠️ Optional | - | Test file path |
| **line** | integer | ⚠️ Optional | >= 1 | Line where test defined |

### Status Values

| Status | Meaning | Example |
|--------|---------|---------|
| **passed** | Test executed successfully | Assertion passed |
| **failed** | Test failed with assertion error | Expected 5, got 3 |
| **skipped** | Test was skipped (disabled/conditional) | @skip decorator |
| **error** | Test crashed with exception | NullPointerException |

### Conditional Requirements

**If status === "failed" OR "error":**
- `error_message` becomes required
- `stack_trace` highly recommended

### Usage Example

```json
{
  "test_results": [
    {
      "test_name": "test_calculate_total_with_valid_input",
      "status": "passed",
      "duration_ms": 12.5,
      "file": "tests/test_budget_service.py",
      "line": 42
    },
    {
      "test_name": "test_calculate_total_with_empty_array",
      "status": "failed",
      "duration_ms": 8.3,
      "error_message": "AssertionError: Expected 0, got None",
      "stack_trace": "Traceback (most recent call last):\n  File 'tests/test_budget_service.py', line 58...",
      "file": "tests/test_budget_service.py",
      "line": 54
    },
    {
      "test_name": "test_calculate_total_with_invalid_type",
      "status": "skipped"
    }
  ]
}
```

### References

- Schema: `@shared:base-schema.json#/definitions/test_result`
- Validation usage: `@skill:validation-framework`

---

## 5. Execution Step Definition

### execution-step

### Purpose

Single execution step in task plan с actions, validation и dependencies.

### JSON Schema

```json
{
  "type": "object",
  "properties": {
    "step_number": {
      "type": "integer",
      "minimum": 1
    },
    "description": {
      "type": "string",
      "minLength": 10,
      "maxLength": 200
    },
    "actions": {
      "type": "array",
      "items": { "type": "string", "minLength": 5 },
      "minItems": 1
    },
    "validation": {
      "type": "string",
      "maxLength": 200
    },
    "files_to_change": {
      "type": "array",
      "items": { "$ref": "#/definitions/file_change" }
    },
    "dependencies": {
      "type": "array",
      "items": { "type": "integer", "minimum": 1 }
    }
  },
  "required": ["step_number", "description", "actions"]
}
```

### Fields

| Field | Type | Required | Constraints | Description |
|-------|------|----------|-------------|-------------|
| **step_number** | integer | ✅ Yes | >= 1 | Sequential step number (1, 2, 3...) |
| **description** | string | ✅ Yes | 10-200 chars | What will be done in this step |
| **actions** | array | ✅ Yes | Min 1 item | List of actions to perform |
| **validation** | string | ⚠️ Optional | Max 200 chars | How to verify step completion |
| **files_to_change** | array | ⚠️ Optional | - | Files modified in this step |
| **dependencies** | array | ⚠️ Optional | - | Step numbers this step depends on |

### Usage Example

```json
{
  "execution_steps": [
    {
      "step_number": 1,
      "description": "Create FastAPI endpoint for user login",
      "actions": [
        "Create file app/api/auth.py",
        "Add POST /auth/login endpoint",
        "Add Pydantic model for request validation",
        "Add error handling for invalid credentials"
      ],
      "validation": "Run pytest tests/test_auth_api.py",
      "files_to_change": [
        {
          "file_path": "app/api/auth.py",
          "change_type": "create",
          "description": "Create authentication endpoint"
        }
      ],
      "dependencies": []
    },
    {
      "step_number": 2,
      "description": "Add JWT token generation service",
      "actions": [
        "Create JWTService class",
        "Implement generate_token() method",
        "Implement verify_token() method"
      ],
      "validation": "Run unit tests for JWT service",
      "files_to_change": [
        {
          "file_path": "app/services/jwt_service.py",
          "change_type": "create",
          "description": "Create JWT token service"
        }
      ],
      "dependencies": []
    },
    {
      "step_number": 3,
      "description": "Integrate JWT service with auth endpoint",
      "actions": [
        "Import JWTService in auth.py",
        "Call generate_token() on successful login",
        "Return token in response"
      ],
      "validation": "Integration test for login flow",
      "dependencies": [1, 2]
    }
  ]
}
```

### Dependencies

**Purpose:** Указать dependencies между steps для правильного порядка выполнения.

**Example:**
- Step 3 depends on [1, 2] → Step 3 can only execute AFTER steps 1 and 2 complete

**Validation:**
- Dependency step numbers must exist
- No circular dependencies allowed
- Dependencies должны быть на предыдущие steps (lower numbers)

### References

- Schema: `@shared:base-schema.json#/definitions/execution_step`
- Planning usage: `@skill:structured-planning`

---

## 6. Validation Result Definition

### validation-result

### Purpose

Validation result from schema/linting/testing с errors/warnings/info.

### JSON Schema

```json
{
  "type": "object",
  "properties": {
    "validator_name": {
      "type": "string",
      "minLength": 1
    },
    "status": {
      "type": "string",
      "enum": ["passed", "warning", "failed"]
    },
    "errors": {
      "type": "array",
      "items": { "type": "string" }
    },
    "warnings": {
      "type": "array",
      "items": { "type": "string" }
    },
    "info": {
      "type": "array",
      "items": { "type": "string" }
    }
  },
  "required": ["validator_name", "status"]
}
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| **validator_name** | string | ✅ Yes | Name of validator that ran |
| **status** | string | ✅ Yes | Overall status: passed/warning/failed |
| **errors** | array | ⚠️ Optional | List of error messages (blocking issues) |
| **warnings** | array | ⚠️ Optional | List of warnings (non-blocking) |
| **info** | array | ⚠️ Optional | Informational messages |

### Status Levels

| Status | Meaning | Action |
|--------|---------|--------|
| **passed** | Validation успешна, нет errors | Proceed |
| **warning** | Validation passed, но есть warnings | Review warnings, proceed |
| **failed** | Validation failed, есть errors | Fix errors, retry |

### Usage Example

```json
{
  "validation_results": [
    {
      "validator_name": "JSON Templates",
      "status": "passed",
      "info": ["Validated 5 template files successfully"]
    },
    {
      "validator_name": "YAML frontmatter",
      "status": "warning",
      "warnings": [
        "Missing 'version' field in skill-generator/SKILL.md",
        "Deprecated 'author' field in validation-framework/SKILL.md"
      ],
      "info": ["Validated 22 SKILL.md files"]
    },
    {
      "validator_name": "JSON Schemas",
      "status": "failed",
      "errors": [
        "task-plan.schema.json: Invalid $ref '../_shared/base-schema.json#/invalid'",
        "approval.schema.json: Missing required field 'type'"
      ]
    }
  ]
}
```

### References

- Schema: `@shared:base-schema.json#/definitions/validation_result`
- Validation usage: `@skill:validation-framework`

---

## 7. TOON Optimization Definition

### toon-optimization

### Purpose

Optional TOON format для token-efficient array representation (added v7.0).

### JSON Schema

```json
{
  "type": "object",
  "properties": {
    "token_savings": {
      "type": "string",
      "pattern": "^\\d+(\\.\\d+)?%$"
    },
    "size_comparison": {
      "type": "string",
      "pattern": "^JSON: \\d+ tokens, TOON: \\d+ tokens$"
    }
  },
  "patternProperties": {
    "^[a-z_]+_toon$": {
      "type": "string",
      "pattern": "^[a-z_]+\\[\\d+\\]\\{[a-z_,]+\\}:"
    }
  },
  "required": ["token_savings"]
}
```

### Fields

| Field | Type | Required | Pattern | Description |
|-------|------|----------|---------|-------------|
| **token_savings** | string | ✅ Yes | `\d+.\d+%` | Percentage saved (e.g., "42.3%") |
| **size_comparison** | string | ⚠️ Optional | `JSON: N tokens, TOON: M tokens` | Human-readable comparison |
| **{array}_toon** | string | ⚠️ Optional | TOON format | TOON representation of array |

### Usage Example

```json
{
  "status": "success",
  "warnings": [
    { "category": "security", "file": "app.js", "line": 42, "severity": "BLOCKING", "message": "SQL injection" },
    { "category": "code_quality", "file": "db.js", "line": 15, "severity": "WARNING", "message": "Missing index" }
  ],
  "toon": {
    "warnings_toon": "warnings[15]{category,file,line,severity,message}:\n  security,app.js,42,BLOCKING,SQL injection\n  code_quality,db.js,15,WARNING,Missing index\n  ...",
    "token_savings": "42.3%",
    "size_comparison": "JSON: 450 tokens, TOON: 260 tokens"
  }
}
```

### Threshold

**TOON генерируется только когда:**
- Array >= 5 элементов (минимум для окупаемости overhead)
- Consistent schema (все элементы имеют одинаковые поля)

### References

- Full TOON specification: `@shared:TOON-REFERENCE.md`
- Schema: `@shared:base-schema.json#/definitions/toon_optimization`
- Integration patterns: `@shared:TOON-PATTERNS.md`

---

## Adaptive Schemas

### Concept

Schemas адаптируются к complexity level задачи:

| Complexity | Schema | Fields | Validation |
|------------|--------|--------|------------|
| **minimal** | task-plan-lite | Упрощённые поля | Relaxed rules |
| **standard** | task-plan | Полные поля | Standard validation |
| **complex** | task-plan + phases | Extended fields | Strict validation |

### Task Plan Lite (Minimal)

**Used when:** Простые задачи (1-2 files, 2-3 steps)

```json
{
  "task_plan_lite": {
    "task_name": "Add calculate_total method",
    "files": ["service.py", "test_service.py"],
    "steps": [
      "Add method to BudgetService",
      "Write unit tests"
    ],
    "validation": "pytest tests/test_budget_service.py"
  }
}
```

**Relaxed rules:**
- No git field (will be auto-generated)
- No acceptance_criteria (steps serve as criteria)
- No risks field
- Simple string arrays instead of structured objects

### Task Plan Full (Standard/Complex)

**Used when:** Стандартные и сложные задачи

```json
{
  "task_plan": {
    "task_name": "Implement transaction filtering",
    "problem": "Users cannot filter transactions by date/category",
    "solution": "Add GET /transactions endpoint with query params",
    "acceptance_criteria": [
      "Endpoint accepts date_from, date_to, category params",
      "Results are paginated",
      "Invalid params return 400 error"
    ],
    "files_to_change": [
      {
        "file_path": "app/api/transactions.py",
        "change_type": "modify",
        "description": "Add query params to endpoint"
      }
    ],
    "execution_steps": [
      {
        "step_number": 1,
        "description": "Add query parameters to endpoint",
        "actions": ["Update route definition", "Add Pydantic models"],
        "validation": "pytest tests/test_api.py"
      }
    ],
    "risks": [
      {
        "risk": "Performance degradation with large date ranges",
        "mitigation": "Add pagination, limit max date range to 90 days"
      }
    ],
    "git": {
      "branch_name": "feature/transaction-filtering",
      "commit_type": "feat",
      "commit_summary": "add transaction filtering endpoint"
    }
  }
}
```

**Standard rules:**
- All structured fields required
- Git field required
- Acceptance criteria минимум 1
- Execution steps минимум 1

---

## Schema Relationships

### Dependency Graph

```
task_plan
  ├─ execution_steps[]
  │  └─ files_to_change[]
  │     └─ file_change (definition)
  ├─ git
  │  └─ git (definition)
  └─ risks[]

code_review_results
  ├─ warnings[]
  │  └─ code_review_issue (definition)
  └─ blocking_issues[]
     └─ code_review_issue (definition)

validation_results[]
  └─ validation_result (definition)
     ├─ errors[]
     ├─ warnings[]
     └─ info[]

test_suite_results
  └─ test_results[]
     └─ test_result (definition)
```

### Schema Reuse

**Example: File Change используется в:**
- structured-planning → `files_to_change[]`
- code-review → `files_reviewed[]`
- git-workflow → `files_committed[]`

**Benefit:** Consistent validation across skills.

---

## Validation Rules Summary

### Required Fields по Schema

| Schema | Required Fields | Optional Fields |
|--------|----------------|-----------------|
| git | branch_name, commit_type, commit_summary | commit_body, co_authored_by |
| file_change | file_path, change_type | description, old_path, lines_added/deleted |
| code_review_issue | category, severity, file, message | column, suggestion, code_snippet |
| test_result | test_name, status | duration_ms, error_message*, stack_trace, file, line |
| execution_step | step_number, description, actions | validation, files_to_change, dependencies |
| validation_result | validator_name, status | errors, warnings, info |

**\*** = Conditional required (if status === "failed" or "error")

### Constraints

**String Lengths:**
- commit_summary: 10-72 chars
- file_change.description: max 200 chars
- code_review_issue.message: 10-500 chars
- execution_step.description: 10-200 chars

**Integers:**
- step_number: >= 1
- line: >= 1
- lines_added/deleted: >= 0

**Patterns:**
- branch_name: `^(feature|fix|refactor|...)/[a-z0-9-]+$`
- co_authored_by: `^[^<>]+\s<[^@]+@[^>]+>$`

---

## Integration with Skills

### How Skills Use These Schemas

**structured-planning:**
```json
{
  "$schema": "../_shared/base-schema.json",
  "type": "object",
  "properties": {
    "task_plan": {
      "properties": {
        "git": {
          "$ref": "../_shared/base-schema.json#/definitions/git"
        },
        "execution_steps": {
          "items": {
            "$ref": "../_shared/base-schema.json#/definitions/execution_step"
          }
        }
      }
    }
  }
}
```

**validation-framework:**
```json
{
  "validation_results": {
    "type": "array",
    "items": {
      "$ref": "../_shared/base-schema.json#/definitions/validation_result"
    }
  }
}
```

### Reference Syntax

**In JSON Schema:**
```json
{
  "$ref": "../_shared/base-schema.json#/definitions/{definition_name}"
}
```

**In SKILL.md:**
```markdown
See schema: @shared:base-schema.json#/definitions/execution_step
```

---

## Best Practices

### ✅ DO

1. **Reuse definitions** - всегда используйте $ref вместо дублирования
2. **Validate early** - проверяйте JSON перед output
3. **Include optional fields when useful** - description, validation, suggestions
4. **Use consistent naming** - kebab-case для files, snake_case для fields
5. **Document conditional requirements** - когда field становится required
6. **Follow enum values** - не используйте values вне enum lists

### ❌ DON'T

1. **Duplicate schema definitions** - используйте $ref
2. **Skip required fields** - validation будет fail
3. **Exceed maxLength** - truncate если нужно
4. **Use invalid enum values** - только из allowed lists
5. **Ignore conditional requirements** - если rename, нужен old_path
6. **Mix schemas** - используйте правильный schema для complexity

---

## Additional Schema References

### task-plan-schema

См. "Adaptive Schemas" выше для lite vs full task plan schemas.

### task-decomposition

См. "Execution Step Definition" (#5) для decomposition structured-planning задач на steps.

### phase-metadata

Phase metadata включает: phase_number, phase_name, dependencies[], status. См. task-decomposition skill для детальной структуры.

### rollback-strategy

См. rollback-recovery skill для git reset strategies (soft, hard, stash, file restore).

### commit-output

См. "1. Git Definition" выше для commit structure. Commit output включает: branch_name, commit_type, commit_summary, commit_body, co_authored_by.

### complexity-result

Complexity result от adaptive-workflow skill: minimal, standard, complex. См. "Adaptive Schemas" выше.

### adaptive-behavior

Schemas адаптируются к complexity level. См. "Adaptive Schemas" section выше.

### approval-gates

Approval gate structure: gate_id, status (pending/approved/rejected), required_approvers[], timestamp. См. approval-gates skill.

### pr-workflow

PR workflow output: pr_url, pr_number, title, body, base_branch, head_branch, status. См. pr-automation skill.

### master-plan

Master plan from task-decomposition: phases[], total_phases, decomposition_strategy, estimated_duration. См. task-decomposition skill.

---

## References

### Internal Resources

- **base-schema.json:** `@shared:base-schema.json`
- **Git conventions:** `@shared:GIT-CONVENTIONS.md`
- **TOON format:** `@shared:TOON-REFERENCE.md`

### Skills Using These Schemas

- **structured-planning:** task_plan schema
- **validation-framework:** validation_result schema
- **code-review:** code_review_issue schema
- **git-workflow:** git schema
- **All TOON-enabled skills:** toon_optimization schema

---

## Version History

### v1.0.0 (2026-01-25)

- ✅ Initial release
- ✅ Documentation для 7 core definitions
- ✅ Field-by-field descriptions
- ✅ Validation rules
- ✅ Usage examples для каждого definition
- ✅ Adaptive schemas (lite vs full)
- ✅ Schema relationship diagram

---

**Автор:** Claude Code Team
**License:** MIT
**Support:** См. structured-planning/SKILL.md для вопросов по schemas
