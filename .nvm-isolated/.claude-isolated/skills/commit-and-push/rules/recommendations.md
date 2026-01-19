# Recommendations and Best Practices

## Best Practices

### 1. Commit Messages

**DO:**
- Use conventional commit format: `type: description`
- Keep messages concise (10-200 chars as enforced by schema)
- Use imperative mood: "add feature" not "added feature"

**DON'T:**
- Use generic messages like "fix" or "update"
- Include sensitive data in commit messages
- Use emojis unless project conventions require them

**Examples:**
```
✅ feat: add user authentication with JWT
✅ fix: resolve memory leak in data processor
✅ docs: update API documentation for v2.0
❌ "updated stuff"
❌ "fix bug"
❌ "commit"
```

### 2. File Staging

**DO:**
- Stage only related files (cohesive changesets)
- Use `files_to_stage` to explicitly control what gets committed
- Review changes before committing

**DON'T:**
- Stage unrelated changes in single commit
- Commit generated files (build artifacts, node_modules, etc.)
- Use `git add .` without reviewing changes

**Example workflow:**
```json
{
  "files_to_stage": [
    "src/auth/login.js",
    "src/auth/register.js",
    "tests/auth.test.js"
  ]
}
```

### 3. Push Options

**DO:**
- Set `set_upstream: true` when pushing new branch first time
- Verify remote before pushing (`verify_remote: true`)
- Use `force: false` by default

**DON'T:**
- Use `force: true` on shared branches (main, master, develop)
- Push without verifying remote exists
- Skip pre-commit validation in production workflows

**Safe push configuration:**
```json
{
  "push_options": {
    "force": false,
    "set_upstream": true,
    "remote": "origin"
  },
  "validation": {
    "check_uncommitted_changes": true,
    "verify_remote": true
  }
}
```

### 4. Branch Management

**DO:**
- Specify target branch explicitly
- Use feature branches for new work
- Keep branch names descriptive

**DON'T:**
- Commit directly to `main`/`master` without review
- Use ambiguous branch names
- Push to wrong branch

### 5. Error Handling

**DO:**
- Check `status` field before assuming success
- Read `errors` array for failure diagnostics
- Handle `partial` status gracefully

**DON'T:**
- Ignore validation warnings
- Retry failed pushes without understanding error
- Skip error logging

**Error handling pattern:**
```javascript
if (output.status === "failed") {
  console.error("Commit failed:", output.errors.join(", "));
  // Handle rollback or user notification
} else if (output.status === "partial") {
  console.warn("Partial success:", output.warnings.join(", "));
  // Decide whether to continue or abort
}
```

## Common Pitfalls

### Pitfall 1: Forgetting to Pull Before Push

**Problem:** Pushing without pulling latest changes causes conflicts

**Solution:**
```bash
# Before using skill, ensure local branch is up to date
git pull origin main
# Then use commit-and-push skill
```

### Pitfall 2: Large Binary Files

**Problem:** Committing large files slows down repository

**Solution:**
- Use `.gitignore` for build artifacts
- Use Git LFS for large media files
- Review `files_to_stage` carefully

### Pitfall 3: Sensitive Data in Commits

**Problem:** Accidentally committing secrets (API keys, passwords)

**Solution:**
- Never include credentials in `commit_message`
- Use environment variables for secrets
- Review staged files before committing

### Pitfall 4: Force Push on Shared Branches

**Problem:** `force: true` overwrites teammates' work

**Solution:**
- Use `force: false` by default
- Only force push on personal feature branches
- Communicate with team before force pushing

## Integration with git-workflow

This skill depends on `git-workflow` for:
- Conventional commit message format validation
- Branch naming conventions
- Git operation execution (commit, push)

**Recommended usage:**
```javascript
// 1. Use git-workflow to validate commit message
// 2. Use commit-and-push to execute commit+push
// 3. git-workflow handles Co-Authored-By trailer automatically
```

## Performance Considerations

- **Large repositories:** Push may take time, consider timeout configuration
- **Many files:** Staging 100+ files may be slow, batch if possible
- **Remote latency:** `verify_remote` adds network round-trip, skip if confident

## Security Considerations

- **Force push:** Only allow on feature branches, never on main/master
- **Credentials:** Never pass credentials via input, use SSH keys or Git credential helper
- **Validation:** Always enable `check_uncommitted_changes` and `verify_remote`
