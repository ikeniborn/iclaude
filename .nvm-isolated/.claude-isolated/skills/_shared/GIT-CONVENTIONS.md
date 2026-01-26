# Git Conventions Reference

**Version:** 1.0.0
**Last Updated:** 2026-01-25
**Purpose:** Централизованные правила для Conventional Commits и branch naming, используемые всеми skills

---

## Overview

Этот документ содержит проверенные паттерны для git операций, используемые в git-workflow, commit-and-push, pr-automation и других skills.

**Ключевые принципы:**
- ✅ Conventional Commits спецификация (https://www.conventionalcommits.org/)
- ✅ Semantic versioning для автоматических changelog
- ✅ Консистентный branch naming pattern
- ✅ Co-authored commits для AI-generated code

**Кому это нужно:**
- git-workflow skill (primary consumer)
- commit-and-push skill
- pr-automation skill
- structured-planning skill (для git field validation)

---

## Conventional Commits Format

### conventional-commits

### commit-message-format

### Structure

```
{type}({scope}): {summary}

{body}

{footer}
```

**Required:**
- `type` - см. Commit Types ниже
- `summary` - краткое описание изменения (imperative mood)

**Optional:**
- `scope` - область изменения (api, ui, db, config, etc.)
- `body` - детальное объяснение "why" (не "what")
- `footer` - breaking changes, issue references

### Rules

1. **Summary Line:**
   - Max 72 символа (включая type и scope)
   - Imperative mood ("add feature", НЕ "added feature")
   - Нет точки в конце
   - Lowercase (кроме proper nouns)

2. **Body:**
   - Опционально
   - Wrap at 100 символов
   - Объясняет "why", а не "what"
   - Отделено от summary пустой строкой

3. **Footer:**
   - `BREAKING CHANGE:` для breaking changes (major version bump)
   - `Fixes #123` для связи с issues
   - `Co-Authored-By: Name <email>` для соавторов

### Commit Types

Используйте `@shared:commit-types.json` для полного списка.

**Primary types:**

| Type | Description | When to Use | Semver Impact |
|------|-------------|-------------|---------------|
| **feat** | New feature | Добавление новой функциональности | minor |
| **fix** | Bug fix | Исправление бага | patch |
| **refactor** | Code refactoring | Изменение структуры без изменения поведения | patch |
| **docs** | Documentation | Только документация | - |
| **test** | Tests | Добавление/изменение тестов | - |
| **chore** | Maintenance | Обновление зависимостей, tooling | - |
| **perf** | Performance | Оптимизация производительности | patch |
| **style** | Code style | Formatting, whitespace, semicolons | - |

**Secondary types (less common):**
- `build` - Build system changes (webpack, gulp, npm)
- `ci` - CI/CD configuration (GitHub Actions, Travis)
- `revert` - Revert previous commit

### Reference Examples

**Example 1: Simple Feature**
```
feat: add calculate_total method to BudgetService

Implement method to sum amounts from budget facts.
This enables total calculation for budget reports.

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Example 2: Bug Fix**
```
fix: handle null pointer in OrderValidator

Add null check before accessing order.items property.
Fixes #123.

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Example 3: Feature with Scope**
```
feat(api): add transaction filtering endpoint

Add GET /api/transactions with query parameters:
- date_from (ISO date)
- date_to (ISO date)
- category (enum)

Returns paginated results with total count.

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Example 4: Breaking Change**
```
feat(api)!: change authentication to JWT

Replace session-based auth with JWT tokens.

BREAKING CHANGE: All existing sessions will be invalidated.
Clients must update to use Authorization header with Bearer token.

Migration guide: docs/migration/v2-auth.md

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Example 5: Refactoring**
```
refactor: extract validation logic to OrderValidator class

Move validation code from OrderService to separate validator.
No functional changes, improves testability and maintainability.

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Example 6: Multiple Issues**
```
fix: resolve transaction calculation errors

Fix three related issues:
- Null pointer when items array is empty
- Precision loss in decimal calculations
- Incorrect total for negative amounts

Fixes #234, #235, #236

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Example 7: Documentation**
```
docs: add API documentation for transaction endpoints

Document all CRUD endpoints with request/response examples.
Add authentication requirements and error codes.

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

---

## Branch Naming Convention

### branch-naming

### Pattern

**Standard Pattern:**
```
{type}/{slug}
```

**Development Pattern (with timestamp):**
```
dev/{slug}_{timestamp}
```

**Components:**
- `type` - Same types as commits (feat, fix, refactor, etc.) OR `dev` for timestamped branches
- `slug` - Kebab-case description (lowercase, hyphens)
- `timestamp` - YYYYMMDDhhmmss format (only for dev/ branches)

### Rules

1. **Type:**
   - Must match commit types (feat, fix, refactor, docs, test, chore, perf, style) OR `dev`
   - Lowercase only

2. **Slug:**
   - Kebab-case (lowercase, hyphens)
   - Descriptive but concise (2-5 words)
   - No special characters except hyphens
   - Max 50 characters (for dev/ branches)

3. **Timestamp (dev/ branches only):**
   - Format: YYYYMMDDhhmmss (e.g., 20260126143022)
   - Generated from UTC time
   - Ensures branch uniqueness
   - Separator: underscore (_)

4. **Pattern:**
   - Standard: `^(feat|fix|refactor|docs|test|chore|perf|style)/[a-z0-9-]+$`
   - Development: `^dev/[a-z0-9-]+_[0-9]{14}$`
   - Valid: `feat/add-user-auth`, `dev/add-user-auth_20260126143022`
   - Invalid: `Feature/Add_User_Auth`, `feat/add user auth`, `dev/add-user-auth` (missing timestamp)

### Reference Examples

**Example 1: Development Branch (with timestamp)**
```
dev/add-calculate-total_20260126143022
dev/user-authentication_20260126150000
dev/transaction-filtering_20260126160112
dev/dashboard-widget_20260126143500
```

**Example 2: Feature Branch**
```
feat/add-calculate-total
feat/user-authentication
feat/transaction-filtering
feat/dashboard-widget
```

**Example 3: Bug Fix Branch**
```
fix/null-pointer-validator
fix/login-validation-bug
fix/transaction-calculation
fix/memory-leak-service
```

**Example 4: Refactoring Branch**
```
refactor/extract-order-validator
refactor/cleanup-services
refactor/database-connection
refactor/improve-error-handling
```

**Example 5: Documentation Branch**
```
docs/api-endpoints
docs/setup-guide
docs/architecture-diagrams
```

**Example 6: Test Branch**
```
test/add-integration-tests
test/coverage-improvement
test/e2e-scenarios
```

**Example 7: Chore Branch**
```
chore/update-dependencies
chore/cleanup-unused-files
chore/eslint-config
```

**Example 8: Performance Branch**
```
perf/optimize-database-queries
perf/reduce-bundle-size
perf/cache-api-responses
```

### Dev Branch Format Details

**Purpose:** Uniquely identify development branches with temporal ordering

**Format:** `dev/<task_slug>_<YYYYMMDDhhmmss>`

**Components:**
- `dev/` - Fixed prefix for development branches
- `task_slug` - Slugified task name (lowercase, alphanumeric + hyphens, max 50 chars)
- `_` - Separator (underscore)
- `timestamp` - ISO 8601 compact (YYYYMMDDhhmmss from UTC)

**Slug generation rules:**
```javascript
function generateSlug(taskName) {
  return taskName
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')  // Remove special chars
    .replace(/\s+/g, '-')           // Spaces to hyphens
    .replace(/-+/g, '-')            // Collapse multiple hyphens
    .slice(0, 50);                  // Max 50 chars
}

// Example: "Add User Authentication Endpoint"
//       → "add-user-authentication-endpoint"
```

**Timestamp generation:**
```javascript
function generateTimestamp() {
  return new Date().toISOString()
    .replace(/[-:]/g, '')
    .slice(0, 14); // YYYYMMDDhhmmss
}

// Example: 2026-01-26T14:30:22.123Z → 20260126143022
```

**Branch uniqueness:**
If dev branch with same name exists, append version suffix:
```
dev/add-user-auth_20260126143022     # Original
dev/add-user-auth_20260126143022_v2  # Duplicate
dev/add-user-auth_20260126143022_v3  # Duplicate again
```

Check existence:
```bash
git rev-parse --verify dev/add-user-auth_20260126143022 2>/dev/null
```

---

## Co-Authored Commits (AI-Generated Code)

### Purpose

Обозначить commits, сгенерированные Claude Code, для:
- Transparency (user знает, что код AI-generated)
- Accountability (clear attribution)
- Compliance (некоторые организации требуют AI attribution)

### Format

**Required footer:**
```
🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Placement:**
- Всегда в конце commit message
- После body (если есть)
- После других footer tags (Fixes, BREAKING CHANGE)

**Variations по модели:**
```
Claude Sonnet 4.5 <noreply@anthropic.com>  # Current default
Claude Opus 4.5 <noreply@anthropic.com>    # If using opus
Claude Haiku 4.0 <noreply@anthropic.com>   # If using haiku
```

### Integration with Skills

**git-workflow:**
```json
{
  "git": {
    "commit_type": "feat",
    "commit_summary": "add user authentication",
    "commit_body": "Implement JWT-based authentication...",
    "co_authored_by": "Claude Sonnet 4.5 <noreply@anthropic.com>"
  }
}
```

**Auto-generation:**
- Skills ВСЕГДА включают co-authored footer
- Emoji 🤖 добавляется автоматически
- Model name определяется из environment/config

---

## Scope Guidelines (Optional)

Scopes помогают категоризировать изменения по модулям/областям.

### Common Scopes

**By Layer:**
- `api` - API endpoints, routes
- `ui` - User interface, components
- `db` - Database, migrations, models
- `config` - Configuration files
- `auth` - Authentication/authorization
- `validation` - Input validation
- `logging` - Logging infrastructure

**By Feature:**
- `orders` - Order management
- `users` - User management
- `transactions` - Transaction processing
- `reports` - Reporting features

**Infrastructure:**
- `deps` - Dependencies
- `ci` - CI/CD pipeline
- `docker` - Docker configuration
- `security` - Security improvements

### Scope Usage

**With scope:**
```
feat(api): add transaction filtering
fix(ui): button alignment on mobile
refactor(db): optimize user queries
```

**Without scope (also valid):**
```
feat: add transaction filtering
fix: button alignment on mobile
refactor: optimize user queries
```

**Recommendation:** Use scopes for large projects with clear module boundaries. Skip for small projects or when scope is obvious from context.

---

## Breaking Changes

### Declaration

Breaking changes MUST be indicated in two places:

**1. Type with ! (exclamation mark):**
```
feat(api)!: change authentication to JWT
```

**2. Footer with BREAKING CHANGE:**
```
BREAKING CHANGE: All existing sessions will be invalidated.
Clients must update to use Authorization header.
```

### Rules

1. **Both required:**
   - `!` in type line for visibility
   - `BREAKING CHANGE:` footer for details

2. **Footer format:**
   - Start with `BREAKING CHANGE:` (uppercase)
   - Describe what broke and why
   - Provide migration path or workaround

3. **Semver impact:**
   - Breaking change → major version bump (1.x.x → 2.0.0)

### Reference Examples

**Example 1: API Breaking Change**
```
feat(api)!: change transaction response format

Return transactions in nested structure for better clarity.

BREAKING CHANGE: Response format changed from flat array
to nested object with pagination metadata. Update clients
to access data via response.data instead of response directly.

Migration: See docs/migration/v2-api.md

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Example 2: Config Breaking Change**
```
chore(config)!: migrate to new config format

Replace YAML config with JSON for better tooling support.

BREAKING CHANGE: Config file format changed from YAML to JSON.
Rename config.yaml to config.json and convert format.

Migration script: scripts/migrate-config.sh

🤖 Generated with Claude Code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

---

## Integration with Skills

### git-workflow Skill

**Uses:**
- Commit Types table
- Commit Format structure
- Branch Naming pattern
- Co-Authored footer format

**Reference:**
```
@shared:GIT-CONVENTIONS.md#conventional-commits-format
@shared:GIT-CONVENTIONS.md#branch-naming-convention
```

### commit-and-push Skill

**Uses:**
- Commit Format validation
- Co-Authored footer generation

### pr-automation Skill

**Uses:**
- Branch naming validation
- Commit message parsing for PR title/description
- Breaking change detection

### structured-planning Skill

**Uses:**
- Git field schema validation
- Branch name generation
- Commit message templates

### JSON Schema Integration

Reference in schemas via base-schema.json:
```json
{
  "branch_name": {
    "$ref": "../_shared/base-schema.json#/definitions/git/properties/branch_name"
  },
  "commit_type": {
    "$ref": "../_shared/base-schema.json#/definitions/git/properties/commit_type"
  }
}
```

---

## Validation

### Commit Message Validation

**git-workflow performs:**
1. Type validation (must be from allowed list)
2. Summary length check (max 72 chars)
3. Body line length (max 100 chars)
4. Co-Authored format validation

### Branch Name Validation

**Regex pattern:**
```regex
^(feat|fix|refactor|docs|test|chore|perf|style|build|ci|revert)/[a-z0-9-]+$
```

**Valid:**
- `feat/add-user-auth` ✅
- `fix/login-bug` ✅
- `refactor/extract-validator` ✅

**Invalid:**
- `Feature/Add_User_Auth` ❌ (uppercase, underscore)
- `feat/add user auth` ❌ (spaces)
- `feature/add-auth` ❌ (wrong type)

---

## Best Practices

### ✅ DO

1. **Use imperative mood:** "add feature" not "added feature"
2. **Keep summary concise:** Max 72 chars, clear and descriptive
3. **Explain why in body:** Context for future maintainers
4. **Reference issues:** `Fixes #123` for automatic closing
5. **Include co-author:** Always for AI-generated code
6. **Use scopes consistently:** If you start, maintain throughout project
7. **Mark breaking changes:** Both `!` and `BREAKING CHANGE:` footer

### ❌ DON'T

1. **Past tense:** "added feature" ❌
2. **Vague summaries:** "fix bug", "update code" ❌
3. **Describe what changed:** Code diff shows that, explain why ❌
4. **Skip co-author:** All AI commits need attribution ❌
5. **Mix conventions:** Pick one style and stick with it ❌
6. **Forget breaking change flag:** Users need to know ❌
7. **Use dates in branches:** Git history provides that ❌

---

## Security Best Practices

### security-best-practices

**Commit Message Security:**
- ❌ Never include credentials, API keys, or passwords in commit messages
- ❌ Avoid including sensitive file paths or internal URLs
- ✅ Use generic descriptions for security fixes (detail in private issue tracker)

**Branch Naming Security:**
- ❌ Don't include ticket IDs that expose vulnerability details (e.g., `fix/cve-2024-1234`)
- ✅ Use generic names for security branches (e.g., `fix/authentication-validation`)

**Co-Authored Transparency:**
- ✅ Always include Co-Authored footer for AI-generated code
- ✅ Helps with security audits and code reviews
- ✅ Enables compliance tracking

---

## References

### Specifications

- **Conventional Commits:** https://www.conventionalcommits.org/
- **Semantic Versioning:** https://semver.org/
- **Git Commit Guidelines:** https://git-scm.com/book/en/v2/Distributed-Git-Contributing-to-a-Project

### Internal Resources

- **commit-types.json:** `@shared:commit-types.json`
- **base-schema.json:** `@shared:base-schema.json#/definitions/git`
- **git-workflow SKILL.md:** `@skill:git-workflow`
- **commit-and-push SKILL.md:** `@skill:commit-and-push`

---

## Version History

### v1.0.0 (2026-01-25)

- ✅ Initial release
- ✅ Conventional Commits specification
- ✅ Branch naming patterns
- ✅ Co-Authored footer format
- ✅ 15 reference examples (commit messages)
- ✅ 20 reference examples (branch names)
- ✅ Breaking change guidelines
- ✅ Validation rules
- ✅ Best practices

---

**Автор:** Claude Code Team
**License:** MIT
**Support:** См. git-workflow/SKILL.md для вопросов по integration
