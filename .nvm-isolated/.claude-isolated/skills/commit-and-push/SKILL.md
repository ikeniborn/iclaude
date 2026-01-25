---
name: commit-and-push
version: 1.1.0
description: Навык используется для коммита и пуша в репозиторий в коттором вызывается для фиксации изменений после изменений
user-invocable: true
context: fork
tags:
  - git
  - automation
  - workflow
dependencies:
  - git-workflow
files:
  templates:
    - input.json
    - output.json
  schemas:
    - input.schema.json
    - output.schema.json
  examples:
    - basic-usage.md
  rules:
    - recommendations.md
changelog:
  - version: 1.1.0
    date: 2026-01-25
    changes:
      - "Централизация: Git conventions → @shared:GIT-CONVENTIONS.md"
      - "Добавлено: 7 полных примеров (simple, commit all, force push, set upstream, partial, selective staging, CI/CD)"
      - "Улучшена интеграция с git-workflow через references"
      - "Добавлены skill-specific usage notes"
  - version: 1.0.0
    date: 2025-XX-XX
    changes:
      - "Initial release"
---

# Commit and Push

Автоматизация коммита и пуша изменений в Git репозиторий с валидацией и интеграцией с git-workflow.

## When to Use

Use this skill when you need to:
- Commit and push changes to a Git repository programmatically
- Automate git operations with validation checks
- Ensure consistent commit message format (via git-workflow dependency)
- Handle staging, committing, and pushing in a single operation
- Validate remote connectivity before pushing

**Manual invocation:**
`/commit-and-push`

**Automatic invocation:**
This is a user-invocable skill, so it's not automatically invoked by the system.

## How It Works

### Step 1: Input Validation

**Purpose:** Validate input parameters and repository state

**Actions:**
1. Check `repository_path` exists and contains `.git/` directory
2. Validate `commit_message` via `@shared:GIT-CONVENTIONS.md#conventional-commits`
3. Verify `files_to_stage` paths are relative to repository root
4. Check `branch` exists (if specified) or use current branch
5. Validate `push_options` (force, set_upstream, remote)

**Validation checks:**
- Repository path is absolute and exists
- Commit message meets conventional commit format (via git-workflow)
- Files to stage exist in repository
- Remote exists (if `verify_remote: true`)

**Output:**
```json
{
  "validation_results": {
    "pre_commit_checks": "passed",
    "remote_verification": "passed"
  }
}
```

### Step 2: File Staging

**Purpose:** Add specified files to Git staging area

**Actions:**
1. Change to repository directory
2. If `files_to_stage` specified:
   - Run `git add <file1> <file2> ...` for each file
3. If `files_to_stage` empty:
   - Run `git add -A` (stage all changes)
4. Verify files staged with `git diff --cached --name-only`

**Error handling:**
- If file not found → add to `warnings`, continue with found files
- If `git add` fails → status: "failed", error message

**Output:**
```json
{
  "commit_info": {
    "files_committed": 3
  }
}
```

### Step 3: Create Commit

**Purpose:** Create Git commit with validated message

**Actions:**
1. Use `git-workflow` dependency to format commit message (см. `@shared:GIT-CONVENTIONS.md#conventional-commits`)
2. Execute `git commit -m "<commit_message>"`
3. Extract commit hash with `git rev-parse --short HEAD`
4. Get timestamp with `git log -1 --format=%cI`
5. Get branch name with `git branch --show-current`

**Integration with git-workflow:**
- Commit message validated against conventional commit format
- Co-Authored-By trailer added automatically (if configured)

**Output:**
```json
{
  "commit_info": {
    "commit_hash": "a1b2c3d",
    "commit_message": "feat: add new feature",
    "files_committed": 3,
    "branch": "main",
    "timestamp": "2026-01-19T10:30:45Z"
  }
}
```

### Step 4: Push to Remote

**Purpose:** Push commit to remote repository

**Actions:**
1. If `verify_remote: true`:
   - Check remote exists with `git remote get-url <remote>`
2. Build push command:
   - Base: `git push <remote> <branch>`
   - If `force: true`: add `--force`
   - If `set_upstream: true`: add `-u`
3. Execute push command
4. Count commits pushed with `git rev-list <remote>/<branch>..HEAD`

**Error handling:**
- If remote not found → status: "failed", error: "Remote not found"
- If push rejected → status: "failed", error: "Push rejected (non-fast-forward)"
- If network error → status: "failed", error: "Network error"

**Output:**
```json
{
  "push_info": {
    "pushed": true,
    "remote": "origin",
    "remote_branch": "main",
    "commits_pushed": 1
  }
}
```

### Step 5: Result Aggregation

**Purpose:** Collect all operation results and generate final output

**Actions:**
1. Aggregate commit info, push info, validation results
2. Collect errors and warnings
3. Add integration notes
4. Determine final status:
   - `success`: Commit and push completed without errors
   - `partial`: Commit succeeded, push failed or warnings present
   - `failed`: Commit or validation failed

**Output:**
```json
{
  "commit_and_push_output": {
    "status": "success",
    "commit_info": {...},
    "push_info": {...},
    "validation_results": {...},
    "notes": [
      "Successfully committed and pushed 3 files",
      "Branch 'main' is up to date with 'origin/main'"
    ]
  }
}
```

## Output Format

### JSON Structure

See `@template:commit-and-push-output` for full structure.

**Key fields:**
- `status`: success | partial | failed
- `commit_info`: Commit details (hash, message, files, branch, timestamp)
- `push_info`: Push details (pushed, remote, commits_pushed)
- `validation_results`: Pre-commit and remote validation status
- `errors`: Array of error messages (if any)
- `warnings`: Array of warning messages (if any)
- `notes`: Integration notes for user

### Markdown Summary (Mixed Format)

When output format is "Mixed (JSON + Markdown)", the skill also outputs:

```markdown
## Commit and Push Results

**Status:** ✅ Success

### Commit Information
- **Hash:** a1b2c3d
- **Message:** feat: add new feature
- **Files:** 3
- **Branch:** main
- **Timestamp:** 2026-01-19T10:30:45Z

### Push Information
- **Pushed:** ✅ Yes
- **Remote:** origin
- **Remote Branch:** main
- **Commits Pushed:** 1

### Validation
- **Pre-commit Checks:** ✅ Passed
- **Remote Verification:** ✅ Passed

### Notes
- Successfully committed and pushed 3 files
- Branch 'main' is up to date with 'origin/main'
```

## References

**Git Conventions:**
- Commit format: `@shared:GIT-CONVENTIONS.md#conventional-commits`
- Branch naming: `@shared:GIT-CONVENTIONS.md#branch-naming`

**Task Structure:**
- Output schema: `@shared:TASK-STRUCTURE.md#commit-output`

## Skill-Specific Usage

### Integration with git-workflow

**Commit message validation:**
- Skill automatically validates commit messages via git-workflow dependency
- Conventional Commits format enforced (type: subject)
- Supported types: feat, fix, docs, style, refactor, test, chore
- Co-Authored-By trailer added if configured in git-workflow

**Example:**
```bash
# User input: "add new feature"
# git-workflow formats to: "feat: add new feature\n\nCo-Authored-By: Claude <noreply@anthropic.com>"
```

### Push Options

**force: false (default)**
- Safe push, fails on non-fast-forward
- Use for shared branches (main, develop, test, prod)
- Protects against overwriting remote commits

**force: true**
- Force push, overwrites remote branch
- **ONLY for feature branches** (never main/master)
- Use when rebasing or amending commits on feature branch
- Requires explicit user confirmation

**set_upstream: true**
- Sets remote tracking for new branches
- Enables `git pull` without specifying remote/branch
- Automatically used for first push to new branch

**Example scenarios:**
```javascript
// New feature branch (first push)
{ force: false, set_upstream: true }

// Feature branch after rebase
{ force: true, set_upstream: false }  // Only after user confirms

// Shared branch (main/test)
{ force: false, set_upstream: false }
```

## Examples

### Example 1: Simple Commit and Push (Staged Files)

**User Task:** "Commit and push changes to feature/add-logout"

**Input:**
```json
{
  "repository_path": "/home/user/project",
  "commit_message": "feat: add logout button",
  "files_to_stage": [
    "src/components/Header.tsx",
    "src/utils/auth.ts",
    "tests/Header.test.tsx"
  ],
  "branch": "feature/add-logout",
  "push_options": {
    "remote": "origin",
    "force": false,
    "set_upstream": false,
    "verify_remote": true
  }
}
```

**Workflow:**

1. **Validation:**
   - Repository exists: ✓
   - Commit message format: ✓ (conventional commit)
   - Files exist: ✓ (all 3 files found)
   - Remote "origin" exists: ✓

2. **Staging:**
   - `git add src/components/Header.tsx`
   - `git add src/utils/auth.ts`
   - `git add tests/Header.test.tsx`
   - Staged: 3 files

3. **Commit:**
   - `git commit -m "feat: add logout button"`
   - Commit hash: `a1b2c3d`

4. **Push:**
   - `git push origin feature/add-logout`
   - Pushed: 1 commit

**Output:**
```json
{
  "commit_and_push_output": {
    "status": "success",
    "commit_info": {
      "commit_hash": "a1b2c3d",
      "commit_message": "feat: add logout button",
      "files_committed": 3,
      "branch": "feature/add-logout",
      "timestamp": "2026-01-25T10:00:00Z"
    },
    "push_info": {
      "pushed": true,
      "remote": "origin",
      "remote_branch": "feature/add-logout",
      "commits_pushed": 1
    },
    "validation_results": {
      "pre_commit_checks": "passed",
      "remote_verification": "passed"
    },
    "errors": [],
    "warnings": [],
    "notes": [
      "Successfully committed and pushed 3 files",
      "Branch 'feature/add-logout' is up to date with 'origin/feature/add-logout'"
    ]
  }
}
```

**Result:** Committed 3 files to feature branch, pushed successfully to origin.

---

### Example 2: Commit All Changes (git add -A)

**User Task:** "Commit all changes and push to main"

**Input:**
```json
{
  "repository_path": "/home/user/project",
  "commit_message": "fix: resolve authentication bug",
  "files_to_stage": [],  // Empty array → stage all changes
  "branch": "main",
  "push_options": {
    "remote": "origin",
    "force": false,
    "set_upstream": false,
    "verify_remote": true
  }
}
```

**Workflow:**

1. **Validation:** Passed

2. **Staging:**
   - `git add -A` (stage all changes)
   - Detected changes:
     - Modified: 5 files
     - Added: 2 files
     - Deleted: 1 file
   - Total staged: 8 files

3. **Commit:**
   - `git commit -m "fix: resolve authentication bug"`
   - Commit hash: `b2c3d4e`

4. **Push:**
   - `git push origin main`
   - Pushed: 1 commit

**Output:**
```json
{
  "commit_and_push_output": {
    "status": "success",
    "commit_info": {
      "commit_hash": "b2c3d4e",
      "commit_message": "fix: resolve authentication bug",
      "files_committed": 8,
      "branch": "main",
      "timestamp": "2026-01-25T11:00:00Z"
    },
    "push_info": {
      "pushed": true,
      "remote": "origin",
      "remote_branch": "main",
      "commits_pushed": 1
    },
    "validation_results": {
      "pre_commit_checks": "passed",
      "remote_verification": "passed"
    },
    "errors": [],
    "warnings": [],
    "notes": [
      "Successfully committed and pushed 8 files (5 modified, 2 added, 1 deleted)",
      "Branch 'main' is up to date with 'origin/main'"
    ]
  }
}
```

**Result:** Committed all changes (8 files) to main, pushed successfully.

---

### Example 3: Force Push to Feature Branch (After Rebase)

**User Task:** "Force push rebased commits to feature/refactor-auth"

**Input:**
```json
{
  "repository_path": "/home/user/project",
  "commit_message": "refactor: simplify auth logic",
  "files_to_stage": [
    "src/auth/login.ts",
    "src/auth/logout.ts"
  ],
  "branch": "feature/refactor-auth",
  "push_options": {
    "remote": "origin",
    "force": true,  // Force push after rebase
    "set_upstream": false,
    "verify_remote": true
  }
}
```

**Workflow:**

1. **Validation:**
   - Repository exists: ✓
   - Commit message format: ✓
   - Files exist: ✓
   - Remote "origin" exists: ✓
   - **Warning:** Force push detected, verifying branch is not main/master

2. **Staging:**
   - `git add src/auth/login.ts src/auth/logout.ts`
   - Staged: 2 files

3. **Commit:**
   - `git commit -m "refactor: simplify auth logic"`
   - Commit hash: `c3d4e5f`

4. **Push:**
   - `git push origin feature/refactor-auth --force`
   - Pushed: 1 commit (force push)

**Output:**
```json
{
  "commit_and_push_output": {
    "status": "success",
    "commit_info": {
      "commit_hash": "c3d4e5f",
      "commit_message": "refactor: simplify auth logic",
      "files_committed": 2,
      "branch": "feature/refactor-auth",
      "timestamp": "2026-01-25T12:00:00Z"
    },
    "push_info": {
      "pushed": true,
      "remote": "origin",
      "remote_branch": "feature/refactor-auth",
      "commits_pushed": 1,
      "force_pushed": true
    },
    "validation_results": {
      "pre_commit_checks": "passed",
      "remote_verification": "passed"
    },
    "errors": [],
    "warnings": [
      "Force push used - remote history overwritten"
    ],
    "notes": [
      "Successfully force pushed to feature branch",
      "⚠️ Force push should only be used on feature branches, never on main/master"
    ]
  }
}
```

**Result:** Force pushed rebased commits to feature branch, remote history overwritten.

---

### Example 4: Set Upstream for New Branch

**User Task:** "Create first commit on new branch and set upstream"

**Input:**
```json
{
  "repository_path": "/home/user/project",
  "commit_message": "feat: add transaction filtering",
  "files_to_stage": [
    "src/components/TransactionFilter.tsx",
    "src/types/transaction.ts"
  ],
  "branch": "feature/transaction-filters",
  "push_options": {
    "remote": "origin",
    "force": false,
    "set_upstream": true,  // First push to new branch
    "verify_remote": true
  }
}
```

**Workflow:**

1. **Validation:**
   - Repository exists: ✓
   - Commit message format: ✓
   - Files exist: ✓
   - Remote "origin" exists: ✓
   - Branch "feature/transaction-filters" is new (no upstream)

2. **Staging:**
   - `git add src/components/TransactionFilter.tsx src/types/transaction.ts`
   - Staged: 2 files

3. **Commit:**
   - `git commit -m "feat: add transaction filtering"`
   - Commit hash: `d4e5f6g`

4. **Push:**
   - `git push -u origin feature/transaction-filters`
   - Pushed: 1 commit
   - Upstream set: origin/feature/transaction-filters

**Output:**
```json
{
  "commit_and_push_output": {
    "status": "success",
    "commit_info": {
      "commit_hash": "d4e5f6g",
      "commit_message": "feat: add transaction filtering",
      "files_committed": 2,
      "branch": "feature/transaction-filters",
      "timestamp": "2026-01-25T13:00:00Z"
    },
    "push_info": {
      "pushed": true,
      "remote": "origin",
      "remote_branch": "feature/transaction-filters",
      "commits_pushed": 1,
      "upstream_set": true
    },
    "validation_results": {
      "pre_commit_checks": "passed",
      "remote_verification": "passed"
    },
    "errors": [],
    "warnings": [],
    "notes": [
      "Successfully committed and pushed 2 files",
      "Upstream tracking set: origin/feature/transaction-filters",
      "Future pushes can use 'git push' without specifying remote"
    ]
  }
}
```

**Result:** First commit on new branch, upstream tracking configured.

---

### Example 5: Partial Success (Commit OK, Push Failed)

**User Task:** "Commit changes and push to remote"

**Input:**
```json
{
  "repository_path": "/home/user/project",
  "commit_message": "docs: update README",
  "files_to_stage": [
    "README.md"
  ],
  "branch": "main",
  "push_options": {
    "remote": "origin",
    "force": false,
    "set_upstream": false,
    "verify_remote": true
  }
}
```

**Workflow:**

1. **Validation:** Passed

2. **Staging:**
   - `git add README.md`
   - Staged: 1 file

3. **Commit:**
   - `git commit -m "docs: update README"`
   - Commit hash: `e5f6g7h`

4. **Push:**
   - `git push origin main`
   - **Error:** Push rejected (non-fast-forward)
   - Remote has commits not in local branch

**Output:**
```json
{
  "commit_and_push_output": {
    "status": "partial",
    "commit_info": {
      "commit_hash": "e5f6g7h",
      "commit_message": "docs: update README",
      "files_committed": 1,
      "branch": "main",
      "timestamp": "2026-01-25T14:00:00Z"
    },
    "push_info": {
      "pushed": false,
      "remote": "origin",
      "remote_branch": "main",
      "commits_pushed": 0,
      "error": "Push rejected (non-fast-forward)"
    },
    "validation_results": {
      "pre_commit_checks": "passed",
      "remote_verification": "passed"
    },
    "errors": [
      "E005: Push rejected - remote has commits not in local branch"
    ],
    "warnings": [],
    "notes": [
      "Commit created successfully, but push failed",
      "Remote branch 'origin/main' has diverged from local",
      "Suggested action: Pull remote changes first (git pull origin main), then retry push"
    ]
  }
}
```

**Result:** Commit successful locally, push failed due to diverged remote branch.

---

### Example 6: Multiple Files with Selective Staging

**User Task:** "Commit specific files (ignore untracked changes)"

**Input:**
```json
{
  "repository_path": "/home/user/project",
  "commit_message": "test: add unit tests for auth module",
  "files_to_stage": [
    "tests/auth/login.test.ts",
    "tests/auth/logout.test.ts",
    "tests/auth/token.test.ts"
  ],
  "branch": "feature/auth-tests",
  "push_options": {
    "remote": "origin",
    "force": false,
    "set_upstream": false,
    "verify_remote": true
  }
}
```

**Workflow:**

1. **Validation:**
   - Repository exists: ✓
   - Commit message format: ✓
   - Files exist: ✓ (all 3 files found)
   - **Note:** 5 other modified files NOT staged (selective staging)

2. **Staging:**
   - `git add tests/auth/login.test.ts`
   - `git add tests/auth/logout.test.ts`
   - `git add tests/auth/token.test.ts`
   - Staged: 3 files (5 other changes ignored)

3. **Commit:**
   - `git commit -m "test: add unit tests for auth module"`
   - Commit hash: `f6g7h8i`

4. **Push:**
   - `git push origin feature/auth-tests`
   - Pushed: 1 commit

**Output:**
```json
{
  "commit_and_push_output": {
    "status": "success",
    "commit_info": {
      "commit_hash": "f6g7h8i",
      "commit_message": "test: add unit tests for auth module",
      "files_committed": 3,
      "branch": "feature/auth-tests",
      "timestamp": "2026-01-25T15:00:00Z"
    },
    "push_info": {
      "pushed": true,
      "remote": "origin",
      "remote_branch": "feature/auth-tests",
      "commits_pushed": 1
    },
    "validation_results": {
      "pre_commit_checks": "passed",
      "remote_verification": "passed"
    },
    "errors": [],
    "warnings": [
      "5 modified files were not staged (selective staging)"
    ],
    "notes": [
      "Successfully committed and pushed 3 test files",
      "Working directory still has 5 uncommitted changes",
      "Branch 'feature/auth-tests' is up to date with 'origin/feature/auth-tests'"
    ]
  }
}
```

**Result:** Selective staging - only 3 specified files committed, 5 other changes remain uncommitted.

---

### Example 7: Integration with CI/CD Trigger

**User Task:** "Commit hotfix and trigger CI/CD pipeline"

**Input:**
```json
{
  "repository_path": "/home/user/project",
  "commit_message": "fix: resolve critical auth token expiration bug",
  "files_to_stage": [
    "src/auth/token.ts",
    "tests/auth/token.test.ts"
  ],
  "branch": "hotfix/token-expiration",
  "push_options": {
    "remote": "origin",
    "force": false,
    "set_upstream": true,
    "verify_remote": true
  },
  "ci_trigger": {
    "enabled": true,
    "pipeline": "hotfix-pipeline",
    "notify_on_failure": true
  }
}
```

**Workflow:**

1. **Validation:** Passed

2. **Staging:**
   - `git add src/auth/token.ts tests/auth/token.test.ts`
   - Staged: 2 files

3. **Commit:**
   - `git commit -m "fix: resolve critical auth token expiration bug"`
   - Commit hash: `g7h8i9j`

4. **Push:**
   - `git push -u origin hotfix/token-expiration`
   - Pushed: 1 commit
   - Upstream set

5. **CI/CD Trigger:**
   - Webhook fired to CI/CD system
   - Pipeline "hotfix-pipeline" queued

**Output:**
```json
{
  "commit_and_push_output": {
    "status": "success",
    "commit_info": {
      "commit_hash": "g7h8i9j",
      "commit_message": "fix: resolve critical auth token expiration bug",
      "files_committed": 2,
      "branch": "hotfix/token-expiration",
      "timestamp": "2026-01-25T16:00:00Z"
    },
    "push_info": {
      "pushed": true,
      "remote": "origin",
      "remote_branch": "hotfix/token-expiration",
      "commits_pushed": 1,
      "upstream_set": true
    },
    "validation_results": {
      "pre_commit_checks": "passed",
      "remote_verification": "passed"
    },
    "ci_trigger": {
      "triggered": true,
      "pipeline": "hotfix-pipeline",
      "pipeline_url": "https://ci.example.com/pipelines/hotfix-pipeline/runs/12345",
      "status": "queued"
    },
    "errors": [],
    "warnings": [],
    "notes": [
      "Successfully committed and pushed 2 files",
      "Upstream tracking set: origin/hotfix/token-expiration",
      "CI/CD pipeline 'hotfix-pipeline' triggered",
      "Pipeline status: queued (view at https://ci.example.com/pipelines/hotfix-pipeline/runs/12345)"
    ]
  }
}
```

**Result:** Hotfix committed, pushed to new branch with upstream tracking, CI/CD pipeline triggered successfully.

---

## Templates

- `@template:commit-and-push-input` - Input parameters for commit and push operation
- `@template:commit-and-push-output` - Output structure with commit and push results

## Schemas

- `@schema:commit-and-push-input` - JSON Schema for input validation (auto-generated from template)
- `@schema:commit-and-push-output` - JSON Schema for output validation (auto-generated from template)

## Examples

- `@example:basic-usage` - Basic commit and push workflow with file staging and validation

## Rules

- `@rules:recommendations` - Best practices for commit messages, file staging, push options, and error handling

## Workflow Integration

### Input Dependencies

Requires data from:
- `git-workflow` → Commit message validation and formatting (см. `@shared:GIT-CONVENTIONS.md`)

### Output Consumers

Provides data to:
- User → Review commit and push results
- CI/CD pipelines → Trigger on successful push
- Monitoring systems → Track git operations

### Integration Pattern

```javascript
// Typical workflow integration:
// 1. User makes code changes
// 2. User invokes /commit-and-push
// 3. Skill validates input and repository state
// 4. Skill uses git-workflow for commit message formatting
// 5. Skill stages files, creates commit, pushes to remote
// 6. Skill returns results with commit hash and push status
```

## Error Handling

**Common errors:**

**E001: Repository not found**
- Cause: `repository_path` doesn't exist or not a git repository
- Solution: Verify path and ensure `.git/` directory exists

**E002: Invalid commit message**
- Cause: Message doesn't follow conventional commit format (см. `@shared:GIT-CONVENTIONS.md`)
- Solution: Adjust message to match format: `type: subject`

**E003: Files not found**
- Cause: Files in `files_to_stage` don't exist
- Solution: Verify file paths are relative to repository root

**E004: Remote not found**
- Cause: Specified remote doesn't exist
- Solution: Check `git remote -v` and verify remote name

**E005: Push rejected**
- Cause: Non-fast-forward push (remote has commits not in local)
- Solution: Pull remote changes first, then retry push

**E006: Network error**
- Cause: Cannot connect to remote server
- Solution: Check network connectivity and remote URL

## Security Considerations

См. `@shared:GIT-CONVENTIONS.md#security-best-practices` для полных рекомендаций.

**Key rules:**
1. **Force push:** Only allow on feature branches, never on main/master
2. **Credentials:** Never pass credentials via input, use SSH keys or Git credential helper
3. **Validation:** Always enable `check_uncommitted_changes` and `verify_remote`
4. **Commit messages:** Never include sensitive data (API keys, passwords)

## Performance Considerations

- **Large repositories:** Push may take time for large codebases
- **Many files:** Staging 100+ files may be slow
- **Remote latency:** Network round-trip adds delay to push operation

---

🤖 Generated with Claude Code

**Author:** ikeniborn
**License:** MIT
