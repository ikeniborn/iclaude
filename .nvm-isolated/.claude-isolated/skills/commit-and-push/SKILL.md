---
name: commit-and-push
version: 1.0.0
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
2. Validate `commit_message` length (10-200 chars)
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
1. Use `git-workflow` dependency to format commit message
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
- `git-workflow` → Commit message validation and formatting

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
- Cause: Message length < 10 or > 200 chars
- Solution: Adjust message length to meet requirements

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

1. **Force push:** Only allow on feature branches, never on main/master
2. **Credentials:** Never pass credentials via input, use SSH keys or Git credential helper
3. **Validation:** Always enable `check_uncommitted_changes` and `verify_remote`
4. **Commit messages:** Never include sensitive data (API keys, passwords)

## Performance Considerations

- **Large repositories:** Push may take time for large codebases
- **Many files:** Staging 100+ files may be slow
- **Remote latency:** Network round-trip adds delay to push operation
