# Basic Usage Example - git-workflow

## Scenario

Стандартизированный git workflow с Conventional Commits, автоматической генерацией commit messages и соблюдением best practices.

**Use cases:**
- Создание git commit после завершения задачи
- Генерация Conventional Commit message
- Push изменений в remote repository

---

## Input

```json
{
  "task_completed": true,
  "files_changed": [
    "src/auth.py",
    "tests/test_auth.py",
    "README.md"
  ],
  "change_summary": "Fixed email validation bug in login form"
}
```

---

## Execution

git-workflow skill выполняет следующие шаги:

### Step 1: Git Status Analysis
- Run `git status`
- Found staged: src/auth.py, tests/test_auth.py
- Found untracked: README.md

### Step 2: Git Diff Analysis
- Run `git diff --cached`
- Analyze changes:
  - src/auth.py: Updated email regex pattern
  - tests/test_auth.py: Added test for new email validation
  - README.md: Updated documentation

### Step 3: Commit Message Generation
- Type: `fix` (bug fix)
- Scope: `auth` (authentication module)
- Summary: "fix email validation regex to accept valid emails"
- Body: "Previous regex was too strict and rejected valid emails with plus signs"

### Step 4: Git Commit
- Stage untracked files
- Create commit with Co-Authored-By trailer

---

## Output

```bash
# Git commit executed:
git add README.md
git commit -m "$(cat <<'EOF'
fix(auth): fix email validation regex to accept valid emails

Previous regex was too strict and rejected valid emails with plus signs (+).
Updated pattern to RFC 5322 compliant version.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"
```

**Console output:**
```
✓ Files staged (3):
  - src/auth.py
  - tests/test_auth.py
  - README.md

✓ Commit created:
  Type: fix
  Scope: auth
  Message: fix email validation regex to accept valid emails

✓ Commit hash: abc123def

📝 Commit message:
  fix(auth): fix email validation regex to accept valid emails

  Previous regex was too strict and rejected valid emails with plus signs (+).
  Updated pattern to RFC 5322 compliant version.

  Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

---

## Explanation

### Conventional Commits Format:

```
<type>(<scope>): <summary>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring (no functional change)
- `docs`: Documentation only
- `test`: Adding/updating tests
- `chore`: Build process, tooling
- `perf`: Performance improvement
- `style`: Code style (formatting, whitespace)

**Scope:** Module or component name (auth, api, ui, etc.)

**Summary:**
- Imperative mood ("add" not "added")
- Lowercase
- No period at end
- Max 72 characters

### Commit Message Best Practices:

**Good examples:**
```
feat(api): add user registration endpoint
fix(auth): fix JWT token expiration handling
refactor(db): extract database connection logic
docs(readme): update installation instructions
test(auth): add integration tests for login flow
```

**Bad examples:**
```
❌ "Fixed bug" (не следует Conventional Commits, не descriptive)
❌ "Add feature." (точка в конце)
❌ "Added new API endpoint" (не imperative mood)
❌ "WIP" (meaningless commit message)
```

### Git Workflow Steps:

```
1. git status          # Check untracked/modified files
2. git diff            # Analyze changes
3. git log -5          # Review recent commits (для matching style)
4. git add <files>     # Stage relevant files
5. git commit -m "..." # Create commit with Conventional Commits
6. git status          # Verify commit created
```

### Co-Authored-By Trailer:

```
# Always add Co-Authored-By for Claude contributions
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Why:**
- Attribution для AI-assisted code
- Transparency
- GitHub recognizes co-authors

### Branch Strategy:

```json
{
  "git": {
    "branch_name": "fix/auth-email-validation",
    "base_branch": "main",
    "commit_type": "fix",
    "commit_summary": "fix email validation regex to accept valid emails"
  }
}
```

**Branch naming:**
```
<type>/<slug>

Examples:
- feature/user-registration
- fix/login-validation
- refactor/cleanup-auth
- docs/update-readme
```

### Pre-commit Validation:

```
# Before commit:
✓ Syntax check passed
✓ Type check passed (if LSP available)
✓ Tests passed: pytest tests/ → 25 passed
✓ Linting passed: ruff check → No errors

# Safe to commit
```

---

## Related

- [git-workflow/SKILL.md](../SKILL.md)
- [pr-automation/SKILL.md](../pr-automation/SKILL.md)
- [code-review/SKILL.md](../code-review/SKILL.md)
