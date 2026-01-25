# Week 5: Testing & Migration Plan

**Date:** 2026-01-25
**Status:** ✅ READY FOR EXECUTION

---

## Test Environment Setup

**Prerequisites:**
- Isolated environment installed: `./iclaude.sh --isolated-install`
- Claude Code CLI available
- Git repository initialized
- No pending changes (clean working tree)

**Test Directory Structure:**
```
/home/ikeniborn/Documents/Project/iclaude/
├── examples/
│   ├── test-loop-simple.md          # Test Case 1
│   ├── test-loop-retry.md           # Test Cases 2, 9
│   └── test-loop-parallel.md        # Test Cases 3, 4, 10
├── iclaude.sh                       # Main script with loop mode
└── test-results/                    # Created during testing
    ├── test-1-simple.log
    ├── test-2-max-iterations.log
    └── ...
```

---

## Test Cases

### Test Case 1: Simple Sequential Task (Success on First Iteration)

**Objective:** Verify basic loop mode functionality with immediate success

**Command:**
```bash
./iclaude.sh --loop examples/test-loop-simple.md
```

**Expected Behavior:**
1. Parse task definition from Markdown
2. Invoke Claude Code for iteration 1
3. Claude creates `test-loop-output.txt`
4. Validation command succeeds: `ls test-loop-output.txt`
5. Completion promise detected
6. Git commit created (if Git Config specified)
7. Exit code 0

**Success Criteria:**
- ✅ Task completed in 1 iteration
- ✅ File `test-loop-output.txt` exists
- ✅ Git commit contains "test: verify loop mode functionality"
- ✅ Exit code = 0

**Validation:**
```bash
# Check exit code
echo $?  # Should be 0

# Verify file created
ls test-loop-output.txt

# Check git log
git log --oneline -1  # Should show test commit
```

---

### Test Case 2: Max Iterations Reached (Failure Scenario)

**Objective:** Verify loop exits correctly when max iterations exceeded

**Setup:**
Modify `test-loop-retry.md` to set impossible completion promise:
```markdown
## Completion Promise
THIS_FILE_WILL_NEVER_EXIST.txt

## Max Iterations
3
```

**Command:**
```bash
./iclaude.sh --loop examples/test-loop-retry.md
```

**Expected Behavior:**
1. Iteration 1: Validation fails
2. Wait 2s (exponential backoff)
3. Iteration 2: Validation fails
4. Wait 4s
5. Iteration 3: Validation fails
6. Exit with code 1 (max iterations reached)

**Success Criteria:**
- ✅ 3 iterations executed
- ✅ Exponential backoff delays observed (2s, 4s)
- ✅ Exit code = 1
- ✅ Error message: "Max iterations (3) reached for task: Test Retry Logic"

**Validation:**
```bash
echo $?  # Should be 1

# Check logs for exponential backoff
grep -E "Retry in [0-9]+s" /tmp/iclaude-loop-iter-*.log
```

---

### Test Case 3: Parallel Execution (3 Tasks, No Conflicts)

**Objective:** Verify parallel execution with git worktrees

**Command:**
```bash
./iclaude.sh --loop-parallel examples/test-loop-parallel.md
```

**Expected Behavior:**
1. Load 3 tasks from file (2 parallel + 1 sequential)
2. Group tasks by PARALLEL_GROUP
3. Create 2 worktrees for parallel tasks:
   - `.git/worktrees/loop-test-parallel-task-1-*`
   - `.git/worktrees/loop-test-parallel-task-2-*`
4. Execute tasks 1 and 2 in background (parallel)
5. Wait for both to complete
6. Merge changes back to main worktree
7. Execute task 3 sequentially
8. Cleanup worktrees
9. Exit code 0

**Success Criteria:**
- ✅ 3 files created: `parallel-task-1.txt`, `parallel-task-2.txt`, `sequential-task.txt`
- ✅ Worktrees created and cleaned up
- ✅ No merge conflicts
- ✅ All tasks succeeded
- ✅ Exit code = 0

**Validation:**
```bash
# Verify files created
ls parallel-task-1.txt parallel-task-2.txt sequential-task.txt

# Check no worktrees remain
git worktree list  # Should show only main worktree

# Verify git log shows all commits
git log --oneline -3
```

---

### Test Case 4: Parallel Execution with File Conflicts (AI Resolution)

**Objective:** Test AI-assisted merge conflict resolution

**Setup:**
Create `test-loop-conflict.md` with 2 parallel tasks modifying the same file:

```markdown
# Task: Conflict Task 1

## Description
Modify conflict-file.txt (append line "Task 1 was here")

## Parallel Group
Group: 1

---

# Task: Conflict Task 2

## Description
Modify conflict-file.txt (append line "Task 2 was here")

## Parallel Group
Group: 1
```

**Command:**
```bash
./iclaude.sh --loop-parallel examples/test-loop-conflict.md
```

**Expected Behavior:**
1. Both tasks modify `conflict-file.txt` simultaneously
2. Merge attempt detects conflicts
3. Invoke `resolve_merge_conflicts_ai()` function
4. Claude Code resolves conflict (combines both changes)
5. Merge completes successfully
6. Exit code 0

**Success Criteria:**
- ✅ File `conflict-file.txt` contains both lines:
  ```
  Task 1 was here
  Task 2 was here
  ```
- ✅ No conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) remain
- ✅ Git merge committed successfully
- ✅ Exit code = 0

**Validation:**
```bash
# Check file content
cat conflict-file.txt

# Verify no conflict markers
! grep -E "^<<<<<<<|^=======|^>>>>>>>" conflict-file.txt

# Check git log for merge commit
git log --oneline -1 | grep -i merge
```

---

### Test Case 5: Proxy Configuration Compatibility

**Objective:** Verify loop mode works with HTTPS_PROXY set

**Setup:**
Configure proxy:
```bash
export HTTPS_PROXY="https://proxy.example.com:8118"
export HTTP_PROXY="https://proxy.example.com:8118"
```

**Command:**
```bash
./iclaude.sh --proxy https://proxy.example.com:8118 --loop examples/test-loop-simple.md
```

**Expected Behavior:**
1. Proxy environment variables inherited by Claude Code process
2. Claude Code uses proxy for API calls
3. Task executes normally
4. Exit code 0

**Success Criteria:**
- ✅ Claude Code launches successfully
- ✅ API calls routed through proxy
- ✅ Task completes normally
- ✅ Exit code = 0

**Validation:**
```bash
# Check proxy env vars were set
env | grep PROXY

# Verify task completed
echo $?  # Should be 0
```

**Note:** This test requires actual proxy server. Skip if proxy unavailable.

---

### Test Case 6: OAuth Token Refresh During Loop

**Objective:** Verify token refresh doesn't interrupt loop execution

**Setup:**
1. Set token expiration to near-future (manual edit of `.credentials.json`)
2. Start long-running loop (5+ minutes)

**Command:**
```bash
./iclaude.sh --loop examples/test-loop-long-running.md
```

**Expected Behavior:**
1. Loop starts with valid token
2. Token expires mid-execution
3. `check_oauth_token()` detects expiration
4. Automatic refresh via `claude setup-token`
5. Loop continues with new token
6. Task completes successfully

**Success Criteria:**
- ✅ Token refreshed automatically
- ✅ Loop execution not interrupted
- ✅ Task completes successfully
- ✅ Exit code = 0

**Validation:**
```bash
# Check credentials file for new token
jq '.claudeAiOauth.expiresAt' .nvm-isolated/.claude-isolated/.credentials.json

# Verify task completed
echo $?  # Should be 0
```

**Note:** This test requires manual token manipulation. Optional for automated testing.

---

### Test Case 7: Git Integration (Auto-commit + Push)

**Objective:** Verify automatic git commit and push functionality

**Setup:**
Modify task definition to enable auto-push:
```markdown
## Git Config
Branch: test/auto-push
Commit message: test: verify auto-push functionality
Auto-push: true
```

**Command:**
```bash
./iclaude.sh --loop examples/test-loop-git-push.md
```

**Expected Behavior:**
1. Task completes successfully
2. Git checkout creates branch `test/auto-push`
3. Changes committed with message "test: verify auto-push functionality"
4. Changes pushed to remote origin
5. Exit code 0

**Success Criteria:**
- ✅ Branch `test/auto-push` exists
- ✅ Commit created with correct message
- ✅ Commit includes Co-Authored-By trailer
- ✅ Branch pushed to remote (if remote configured)
- ✅ Exit code = 0

**Validation:**
```bash
# Check branch exists
git branch | grep test/auto-push

# Verify commit message
git log test/auto-push --oneline -1

# Check Co-Authored-By trailer
git log test/auto-push -1 --format=%B | grep "Co-Authored-By"

# Verify push (if remote exists)
git ls-remote origin test/auto-push
```

**Note:** This test requires git remote configured. Skip push verification if no remote.

---

### Test Case 8: Completion Promise Verification (Regex Pattern)

**Objective:** Test regex-based completion promise matching

**Setup:**
Create task with regex pattern in completion promise:
```markdown
## Completion Promise
All tests passed|SUCCESS

## Validation Command
echo "Test run completed: SUCCESS"
```

**Command:**
```bash
./iclaude.sh --loop examples/test-loop-regex.md
```

**Expected Behavior:**
1. Validation command outputs: "Test run completed: SUCCESS"
2. Regex pattern matches "SUCCESS"
3. Completion promise verified successfully
4. Task exits with code 0

**Success Criteria:**
- ✅ Regex pattern matched correctly
- ✅ Task completed in 1 iteration
- ✅ Exit code = 0

**Validation:**
```bash
# Verify completion
echo $?  # Should be 0

# Check logs for pattern match
grep "Completion promise met" /tmp/iclaude-loop-iter-1-*.log
```

---

### Test Case 9: Exponential Backoff Retry (Timing Verification)

**Objective:** Verify exponential backoff delays are correct

**Setup:**
Task with 4 iterations (will retry 3 times)

**Command:**
```bash
time ./iclaude.sh --loop examples/test-loop-retry.md
```

**Expected Behavior:**
1. Iteration 1: Execute (0s)
2. Delay: 2s (2^1)
3. Iteration 2: Execute
4. Delay: 4s (2^2)
5. Iteration 3: Execute
6. Delay: 8s (2^3)
7. Iteration 4: Execute (success or max reached)

**Success Criteria:**
- ✅ Delays observed: 2s, 4s, 8s
- ✅ Total execution time ≈ 14s + task execution time
- ✅ Exit code = 0 (if task succeeds) or 1 (if max iterations)

**Validation:**
```bash
# Check logs for delay messages
grep -E "Retry in [0-9]+s" /tmp/iclaude-loop-iter-*.log

# Verify delays
# Should show: "Retry in 2s", "Retry in 4s", "Retry in 8s"
```

---

### Test Case 10: Worktree Cleanup After Success

**Objective:** Verify all worktrees removed after parallel execution

**Command:**
```bash
./iclaude.sh --loop-parallel examples/test-loop-parallel.md
```

**Expected Behavior:**
1. Create 2 worktrees for parallel tasks
2. Execute tasks in worktrees
3. Merge changes back to main
4. Cleanup worktrees via `cleanup_worktree()`
5. No worktrees remain after completion

**Success Criteria:**
- ✅ Tasks execute successfully
- ✅ All worktrees cleaned up
- ✅ `git worktree list` shows only main worktree
- ✅ No `.git/worktrees/loop-*` directories remain
- ✅ Exit code = 0

**Validation:**
```bash
# Check no worktrees remain
git worktree list  # Should show only 1 entry (main)

# Verify no worktree directories
ls -la .git/worktrees/ 2>/dev/null | grep -c loop  # Should be 0

# Check task completion
echo $?  # Should be 0
```

---

## Integration Tests

### Integration Test 1: End-to-End CI/CD Fix Loop

**Objective:** Simulate real-world use case - fixing CI/CD errors

**Setup:**
1. Create PR with failing tests
2. Create task definition for fixing tests
3. Run loop mode to auto-fix

**Task Definition:**
```markdown
# Task: Fix CI/CD Errors

## Description
Fix all failing TypeScript type checks and unit tests

## Completion Promise
gh pr checks 123

## Validation Command
gh pr checks 123 | grep -E "✓|success" | wc -l

## Max Iterations
5

## Git Config
Branch: fix/ci-errors
Commit message: fix: resolve CI/CD errors
Auto-push: true
```

**Expected Behavior:**
1. Loop monitors PR checks
2. Identifies failing tests
3. Fixes type errors
4. Commits changes
5. Pushes to remote
6. CI/CD re-runs
7. Loop verifies all checks pass
8. Exit code 0

**Note:** Requires GitHub CLI (`gh`) and active PR. Optional for testing.

---

### Integration Test 2: Multi-Module Parallel Refactoring

**Objective:** Test parallel execution on real codebase refactoring

**Setup:**
3 independent modules to refactor simultaneously

**Task Definition:**
```markdown
# Task: Refactor Module A

## Parallel Group
Group: 1

## Description
Refactor authentication module to use new API

---

# Task: Refactor Module B

## Parallel Group
Group: 1

## Description
Refactor database module to use connection pooling

---

# Task: Refactor Module C

## Parallel Group
Group: 1

## Description
Refactor logging module to use structured logging
```

**Expected Behavior:**
1. All 3 tasks execute in parallel (separate worktrees)
2. No file conflicts (modules independent)
3. Changes merged successfully
4. All tests pass
5. Exit code 0

---

## Proxy/OAuth Compatibility Tests

### Proxy Test 1: HTTP Proxy

**Command:**
```bash
./iclaude.sh --proxy http://proxy:8118 --loop examples/test-loop-simple.md
```

**Expected:** Works, but warning about domain preservation

### Proxy Test 2: HTTPS Proxy

**Command:**
```bash
./iclaude.sh --proxy https://proxy:8118 --loop examples/test-loop-simple.md
```

**Expected:** Works correctly, domain preserved for OAuth

### Proxy Test 3: Proxy with TLS Certificate

**Command:**
```bash
./iclaude.sh --proxy https://proxy:8118 --proxy-ca /path/to/cert.pem --loop examples/test-loop-simple.md
```

**Expected:** Works correctly, certificate verified

---

## Test Execution Checklist

**Pre-execution:**
- [ ] Clean working directory (`git status` clean)
- [ ] Isolated environment installed
- [ ] Claude Code CLI functional (`./iclaude.sh --check-isolated`)
- [ ] No active proxy (unless testing proxy compatibility)

**Execution order:**
1. [ ] Test Case 1: Simple sequential
2. [ ] Test Case 2: Max iterations
3. [ ] Test Case 8: Regex completion promise
4. [ ] Test Case 9: Exponential backoff
5. [ ] Test Case 3: Parallel (no conflicts)
6. [ ] Test Case 10: Worktree cleanup
7. [ ] Test Case 4: Parallel (with conflicts)
8. [ ] Test Case 7: Git integration
9. [ ] Test Case 5: Proxy compatibility (optional)
10. [ ] Test Case 6: OAuth refresh (optional)

**Post-execution:**
- [ ] Review logs in `/tmp/iclaude-loop-iter-*.log`
- [ ] Verify git history clean
- [ ] Cleanup test files (`rm test-*.txt parallel-*.txt`)
- [ ] Document any failures in WEEK5-RESULTS.md

---

## Expected Results Summary

| Test Case | Expected Exit Code | Expected Duration | Critical |
|-----------|-------------------|-------------------|----------|
| 1. Simple sequential | 0 | < 1 min | ✅ |
| 2. Max iterations | 1 | ~14s (delays) | ✅ |
| 3. Parallel (no conflicts) | 0 | < 2 min | ✅ |
| 4. Parallel (conflicts) | 0 | < 2 min | ✅ |
| 5. Proxy compatibility | 0 | < 1 min | 🔶 |
| 6. OAuth refresh | 0 | > 5 min | 🔶 |
| 7. Git integration | 0 | < 1 min | ✅ |
| 8. Regex completion | 0 | < 1 min | ✅ |
| 9. Exponential backoff | 0 or 1 | ~14s | ✅ |
| 10. Worktree cleanup | 0 | < 2 min | ✅ |

**Legend:**
- ✅ Critical test (must pass)
- 🔶 Optional test (environment-dependent)

---

## Troubleshooting

### Issue: Loop hangs during execution

**Possible causes:**
- Claude Code waiting for user input
- Infinite loop in task logic
- Network timeout

**Solution:**
- Check `/tmp/iclaude-loop-iter-*.log` for last action
- Send SIGINT (Ctrl+C) to interrupt
- Review task definition for logic errors

### Issue: Worktrees not cleaned up

**Possible causes:**
- Loop interrupted before cleanup
- Merge conflict unresolved

**Solution:**
```bash
# List worktrees
git worktree list

# Remove manually
git worktree remove .git/worktrees/loop-*

# Cleanup .git/worktrees directory
git worktree prune
```

### Issue: Completion promise never met

**Possible causes:**
- Incorrect regex pattern
- Validation command fails
- File not created by Claude

**Solution:**
- Test validation command manually
- Verify completion promise regex matches expected output
- Check Claude Code logs for errors

---

## Next Steps After Testing

1. **Document results** in `WEEK5-RESULTS.md`
2. **Update lockfile** if any versions changed
3. **Create final commit** with test results
4. **Update README.md** with tested usage examples
5. **Announce migration** to users (deprecation notice for ralph-loop)

---

## Acceptance Criteria for Week 5

- [ ] All 10 test cases documented
- [ ] At least 7/10 critical tests pass
- [ ] Migration guide complete (MIGRATION-GUIDE.md)
- [ ] No bash syntax errors (`bash -n iclaude.sh`)
- [ ] Git history clean (meaningful commits)
- [ ] Documentation updated (README.md, CLAUDE.md)
- [ ] No ralph-loop references remain (except migration guide)
