---
name: Git Workflow
description: Стандартизированный git workflow с Conventional Commits
version: 2.0.0
tags: [git, commit, branch, conventional-commits]
dependencies: []
files:
  templates: ./templates/*.txt
  examples: ./examples/*.md
  shared: ../_shared/commit-types.json
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
