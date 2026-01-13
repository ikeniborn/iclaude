# Ralph-Loop Integration Guide

**Version:** 1.0.0
**Plugin:** ralph-loop (Claude Code plugin)

---

## Overview

Ralph-loop enables iterative error fixing with automatic verification until completion promise is met.

**Key Concept:** Completion Promise = Condition that indicates task success

---

## Completion Promise Syntax

### Primary Promise

```
All GitHub Actions checks pass
```

**Verification:**
```bash
gh pr checks <pr-number> | grep -E "✓|success" | wc -l
# Expected: 4 (number of required checks)

gh pr checks <pr-number> | grep -E "✗|failure"
# Expected: empty output
```

### Alternative Promises

```
gh pr checks <pr-number> shows all ✓
No failed checks in gh pr checks output
TypeScript check passes
All tests pass with coverage ≥ 8.9%
```

---

## Invocation Pattern

### Basic Invocation

```bash
/ralph-loop "Fix TypeScript error TS2322 in transactionForm.ts:45" \
  --context "File: transactionForm.ts, Line: 45, PR: 312" \
  --completion-promise "All GitHub Actions checks pass"
```

### With Max Iterations

```bash
/ralph-loop "Fix ESLint no-console violation" \
  --context "File: budgetState.ts, Line: 67" \
  --completion-promise "gh pr checks 312 shows all ✓" \
  --max-iterations 5
```

### With Custom Timeout

```bash
/ralph-loop "Fix test failure in api.test.ts" \
  --context "Test: should return 200, PR: 312" \
  --completion-promise "Vitest tests pass" \
  --timeout 300
```

---

## Error Context Template

Always provide rich context for ralph-loop:

```json
{
  "errorType": "typescript",
  "errorCode": "TS2322",
  "file": "frontend/web/static/js/budget/transactionForm.ts",
  "line": 45,
  "column": 12,
  "message": "Type 'string' is not assignable to type 'number'",
  "prNumber": 312,
  "prUrl": "https://github.com/ikeniborn/familyBudget/pull/312",
  "checkName": "TypeScript Type Check",
  "runId": 123456789
}
```

**Bash invocation:**
```bash
/ralph-loop "Fix TypeScript error TS2322 in transactionForm.ts:45" \
  --context "$(cat <<EOF
Error Type: typescript
Error Code: TS2322
File: frontend/web/static/js/budget/transactionForm.ts
Line: 45
Message: Type 'string' is not assignable to type 'number'
PR: #312
Check: TypeScript Type Check
Run ID: 123456789
EOF
)" \
  --completion-promise "gh pr checks 312 shows TypeScript Type Check with ✓"
```

---

## Ralph-Loop Workflow

### Phase 1: Read & Analyze

Ralph-loop reads:
- Affected file (`transactionForm.ts:45`)
- Error message and context
- Surrounding code (±10 lines)

### Phase 2: Generate Fix

Based on error type and `error-fixing-strategies.md`:
- TypeScript TS2322 → Type conversion
- ESLint no-console → Replace with debugLog()
- Test failure → Fix assertion

### Phase 3: Apply Fix

```bash
# Edit file
nano frontend/web/static/js/budget/transactionForm.ts

# Stage changes
git add frontend/web/static/js/budget/transactionForm.ts

# Commit with Conventional Commits
git commit -m "fix(frontend): resolve TS2322 type mismatch in transactionForm.ts

Added parseInt() conversion for form input values to match
number type annotation.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# Push to PR branch
git push origin feature/transaction-filters
```

### Phase 4: Wait for Checks

```bash
# Wait for GitHub Actions to trigger
sleep 30

# Monitor check status
gh pr checks 312 --watch --interval 30
```

### Phase 5: Verify Promise

```bash
# Check if promise met
all_passed=$(gh pr checks 312 | grep -E "✓|success" | wc -l)
required_checks=4

if [[ $all_passed -eq $required_checks ]]; then
  echo "✅ Completion promise met"
  exit 0
else
  echo "❌ Promise not met, iteration continues"
  exit 1
fi
```

### Phase 6: Iterate or Complete

- **If promise met:** Ralph-loop completes ✅
- **If promise NOT met:** Repeat from Phase 1 (max 5 iterations)

---

## Iteration Limits

### Default: 5 iterations

```bash
/ralph-loop "Fix error" --max-iterations 5
```

### Scenarios

**Iteration 1:** Fix TypeScript error → Push → Wait → Check → ❌ Still failing (new error)
**Iteration 2:** Fix new error → Push → Wait → Check → ❌ Still failing (coverage)
**Iteration 3:** Add tests → Push → Wait → Check → ✅ All pass → **Complete!**

**Total time:** ~15-20 minutes for 3 iterations

---

## Promise Verification Commands

### GitHub Actions Checks

```bash
# Get all checks status
gh pr checks <pr-number> --json name,conclusion

# Count passed checks
gh pr checks <pr-number> | grep -c "✓"

# Check specific check
gh pr checks <pr-number> | grep "TypeScript Type Check"

# Watch checks in real-time
gh pr checks <pr-number> --watch --interval 30
```

### Check Run Details

```bash
# Get failed check logs
gh run view <run-id> --log-failed

# Get all logs
gh run view <run-id> --log
```

---

## Error Handling

### Max Iterations Reached

```bash
if [[ $iteration -ge $max_iterations ]]; then
  echo "❌ Max iterations ($max_iterations) reached"
  echo "Last error: $last_error"
  echo "Manual intervention required"
  exit 1
fi
```

**Action:** Report partial success and remaining errors to user

### Promise Never Verified

```bash
if [[ $timeout_exceeded == true ]]; then
  echo "⏱️ Timeout exceeded waiting for checks"
  echo "Current status: $current_status"
  exit 1
fi
```

**Action:** Report current check status and suggest manual inspection

### New Errors Introduced

```bash
if [[ $new_errors_count -gt $previous_errors_count ]]; then
  echo "⚠️ New errors introduced by fix"
  echo "Reverting last commit..."
  git revert HEAD --no-edit
  git push origin feature/transaction-filters
fi
```

**Action:** Revert problematic commit and try alternative fix

---

## Best Practices

### 1. Narrow Completion Promises

❌ **Too broad:**
```
All checks pass
```

✅ **Specific:**
```
TypeScript Type Check passes
gh pr checks 312 shows TypeScript Type Check with ✓
```

### 2. Rich Error Context

Always provide:
- File path (absolute or relative)
- Line number
- Error code (TS2322, etc.)
- Full error message
- PR number for verification

### 3. Incremental Fixes

Fix **one error type at a time**:
1. TypeScript errors first
2. ESLint violations second
3. Test failures third
4. Coverage issues last

### 4. Monitor Logs

Check ralph-loop output:
```bash
/ralph-loop ... 2>&1 | tee /tmp/ralph-loop-$pr_number.log
```

---

## Troubleshooting

### Promise Never Met

**Symptom:** Ralph-loop iterates 5 times, promise still false

**Diagnosis:**
```bash
# Check what's actually failing
gh pr checks 312 --json name,conclusion

# Get failed check logs
gh run view <run-id> --log-failed
```

**Solutions:**
- Adjust promise to be more specific
- Fix errors manually if ralph-loop can't handle
- Increase max iterations

### Checks Never Complete

**Symptom:** Checks stuck in "pending" state

**Diagnosis:**
```bash
gh pr checks 312 | grep pending
```

**Solutions:**
- Wait longer (GitHub Actions queue)
- Check workflow file for issues
- Cancel and re-trigger checks

### Wrong File Fixed

**Symptom:** Ralph-loop fixes wrong file

**Diagnosis:** Error context was ambiguous

**Solutions:**
- Provide absolute file path
- Include more context (full error message)

---

## Integration with pr-automation

### PHASE 4: Error Fixing Loop

```bash
# Parse errors from failed check
errors=$(parse_errors_from_logs /tmp/ci_logs.txt)

# For each error
for error in $errors; do
  error_type=$(get_error_type "$error")
  file=$(get_error_file "$error")
  line=$(get_error_line "$error")
  message=$(get_error_message "$error")

  # Invoke ralph-loop
  /ralph-loop \
    --task "Fix $error_type error: $message" \
    --context "File: $file, Line: $line, PR: $pr_number" \
    --completion-promise "gh pr checks $pr_number shows all ✓" \
    --max-iterations 5

  # Verify promise after ralph-loop completes
  verify_completion_promise "$pr_number"
done
```

---

## References

- Ralph-loop Plugin Documentation
- GitHub CLI (`gh`) Documentation
- [Completion Promises Pattern](https://github.com/anthropics/ralph-loop)
