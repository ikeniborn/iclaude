# PR Creation Flow Example

**Scenario:** Add transaction filtering functionality to frontend

**Branch:** `feature/transaction-filters` → `test`

---

## PHASE 0A: Auto-detect Stack & CI/CD (45s)

**Actions:**
1. Read `/docs/architecture/index.yaml`
2. Parse `.github/workflows/*.yml`
3. Build error patterns

**Output:**
```json
{
  "detectedStack": {
    "backend": "Python 3 + FastAPI",
    "frontend": "TypeScript + Vite + HTMX + Tailwind",
    "database": "PostgreSQL 16"
  },
  "cicdConfig": {
    "platform": "GitHub Actions",
    "requiredChecks": [
      "TypeScript Type Check",
      "Unit & Integration Tests",
      "Build Verification",
      "Linting & Formatting"
    ]
  },
  "errorPatterns": {
    "typescript": { "enabled": true },
    "eslint": { "enabled": true },
    "vitest": { "enabled": true }
  }
}
```

---

## PHASE 0B: Initialization (1m)

**User Prompt:** "Создать PR из feature/transaction-filters в test"

**Actions:**
1. Verify gh CLI: `gh auth status` ✅
2. Verify branches exist
3. Confirm with user:
   - Source: feature/transaction-filters
   - Target: test

**Output:**
```json
{
  "sourceBranch": "feature/transaction-filters",
  "targetBranch": "test",
  "authenticated": true
}
```

---

## PHASE 1: Analysis (1m 12s)

**Actions:**
1. Git diff:
```bash
git diff test...feature/transaction-filters --stat
```

**Result:**
```
frontend/web/static/js/budget/transactionFilter.ts | 95 ++++++++++++++++++++
frontend/web/static/js/budget/transactionForm.ts   | 12 ++-
frontend/web/static/js/__tests__/filter.test.ts    | 45 ++++++++++
3 files changed, 151 insertions(+), 1 deletion(-)
```

2. Extract commits:
```bash
git log test..feature/transaction-filters --oneline
```

**Result:**
```
abc123d feat: add filtering modal UI
def456e feat: implement filter logic
ghi789j test: add filter unit tests
```

3. Generate PR description from template
4. Detect file types: TypeScript ✅, Frontend ✅

**Output:**
```json
{
  "commits": [
    {"hash": "abc123d", "message": "feat: add filtering modal UI"},
    {"hash": "def456e", "message": "feat: implement filter logic"},
    {"hash": "ghi789j", "message": "test: add filter unit tests"}
  ],
  "changedFiles": [
    {"path": "transactionFilter.ts", "additions": 95, "deletions": 0}
  ],
  "hasTypescriptChanges": true,
  "hasFrontendChanges": true
}
```

---

## PHASE 2: PR Creation (23s)

**Command:**
```bash
gh pr create --draft \
  --base test \
  --head feature/transaction-filters \
  --title "feat(frontend): add transaction filtering functionality" \
  --body "$(cat pr_description.md)"
```

**Output:**
```
https://github.com/ikeniborn/familyBudget/pull/312
```

**Wait 10s** for GitHub to trigger workflows...

**Output:**
```json
{
  "prNumber": 312,
  "prUrl": "https://github.com/ikeniborn/familyBudget/pull/312",
  "isDraft": true
}
```

---

## PHASE 3: CI/CD Monitoring (4m 56s)

**Monitor checks:**
```bash
gh pr checks 312 --watch --interval 30
```

**Output (iteration 1 - 2m):**
```
TypeScript Type Check       ●  in_progress  123456789
Unit & Integration Tests    ●  queued
Build Verification          ●  queued
Linting & Formatting        ●  queued
```

**Output (iteration 2 - 4m):**
```
TypeScript Type Check       ✗  failure      123456789
Unit & Integration Tests    ✓  success      123456790
Build Verification          ✓  success      123456791
Linting & Formatting        ✓  success      123456792
```

**Analysis:**
- Total: 4 checks
- Passed: 3
- Failed: 1 (TypeScript Type Check)

**Decision:** → PHASE 4 (Error Fixing)

---

## PHASE 4: Error Fixing Loop (1m 8s)

### Iteration 1

**Fetch failed check logs:**
```bash
gh run view 123456789 --log-failed > /tmp/ci_logs.txt
```

**Parse errors:**
```
transactionFilter.ts(45,12): error TS2322: Type 'string' is not assignable to type 'number'.
```

**Error details:**
```json
{
  "errorType": "typescript",
  "errorCode": "TS2322",
  "file": "frontend/web/static/js/budget/transactionFilter.ts",
  "line": 45,
  "message": "Type 'string' is not assignable to type 'number'"
}
```

**Option A: Manual fix in Claude Code**

Fix the error directly by editing transactionFilter.ts:45

**Option B: External loop tool (bash loop)**

Create task definition:
```markdown
# Task: Fix TypeScript Error TS2322

## Description
Fix type mismatch in transactionFilter.ts:45
Type 'string' is not assignable to type 'number'

## Completion Promise
gh pr checks 312

## Validation Command
gh pr checks 312 | grep -E "✓|success" | wc -l

## Max Iterations
5

## Git Config
Branch: fix/ts2322-transaction-filter
Commit message: fix: resolve TS2322 type mismatch
Auto-push: true
```

Run loop:
```bash
./iclaude.sh --loop fix-ts2322.md
```

**Loop actions:**

1. Read `transactionFilter.ts` lines 35-55
2. Analyze error:
```typescript
// Line 45 (before fix)
const minAmount: number = formData.get('minAmount');
```

3. Apply fix:
```typescript
// Line 45 (after fix)
const minAmount: number = parseInt(formData.get('minAmount'), 10);
```

4. Commit:
```bash
git add frontend/web/static/js/budget/transactionFilter.ts
git commit -m "fix(frontend): resolve TS2322 type mismatch in transactionFilter.ts

Added parseInt() conversion for form input values to match
number type annotation.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
git push origin feature/transaction-filters
```

5. Wait for checks (30s + 2m)
6. Verify completion promise:
```bash
gh pr checks 312 | grep -E "✓|success" | wc -l
# Output: 4 ✅ (all checks pass)
```

**Ralph-loop completes ✅**

**Output:**
```json
{
  "iteration": 1,
  "fixedErrors": [
    {
      "errorType": "typescript",
      "file": "transactionFilter.ts",
      "line": 45,
      "fix": "Added parseInt() conversion",
      "commitHash": "jkl012m"
    }
  ],
  "promiseVerified": true
}
```

---

## PHASE 5: Finalization (10s)

**Mark PR as ready:**
```bash
gh pr ready 312
```

**Generate summary output:**

```json
{
  "success": true,
  "prNumber": 312,
  "prUrl": "https://github.com/ikeniborn/familyBudget/pull/312",
  "finalStatus": "all_checks_passed",
  "checksStatus": {
    "total": 4,
    "passed": 4,
    "failed": 0
  },
  "fixIterations": 1,
  "autoFixedErrors": [
    {
      "errorType": "typescript",
      "file": "transactionFilter.ts",
      "line": 45,
      "message": "Type mismatch"
    }
  ],
  "executionTime": {
    "total": "8m 34s",
    "phaseBreakdown": {
      "phase0": "45s",
      "phase1": "1m 12s",
      "phase2": "23s",
      "phase3": "4m 56s",
      "phase4": "1m 8s",
      "phase5": "10s"
    }
  }
}
```

**User-facing summary:**
```
========================================
✅ PR Automation Complete
========================================

PR: https://github.com/ikeniborn/familyBudget/pull/312
Status: Ready for review

Checks: 4/4 passed
✓ TypeScript Type Check
✓ Unit & Integration Tests
✓ Build Verification
✓ Linting & Formatting

Auto-fixes applied: 1
- fix(frontend): resolve TS2322 type mismatch in transactionFilter.ts

Total time: 8m 34s
Fix iterations: 1/5
```

---

## Timeline

```
00:00 │ PHASE 0A: Auto-detect stack
00:45 │ PHASE 0B: User confirmation
01:45 │ PHASE 1: Git diff analysis
02:57 │ PHASE 2: Create draft PR #312
03:20 │ PHASE 3: Monitor CI/CD checks...
08:16 │   └─> TypeScript check fails ✗
08:16 │ PHASE 4: Ralph-loop iteration 1
08:46 │   ├─> Parse error TS2322
08:47 │   ├─> Apply fix (parseInt)
08:50 │   ├─> Commit + push
09:20 │   ├─> Wait for checks...
11:20 │   └─> All checks pass ✓
11:20 │ PHASE 5: Mark PR as ready
11:30 │ ✅ COMPLETE
```

**Total:** 8 minutes 34 seconds
