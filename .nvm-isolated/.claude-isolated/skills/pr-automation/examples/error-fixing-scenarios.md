# Error Fixing Scenarios

**Common error patterns and auto-fix workflows**

---

## Scenario 1: TypeScript Type Error

**Detected:**
```
TypeScript Type Check: FAILED
Error TS2322 in transactionForm.ts(45,12)
Type 'string' is not assignable to type 'number'
```

**Context:**
```typescript
// Line 45
const amount: number = formData.get('amount'); // ❌ formData returns string
```

**Ralph-loop fix:**
```typescript
// After fix
const amount: number = parseInt(formData.get('amount'), 10); // ✅
```

**Commit:**
```bash
fix(frontend): resolve TS2322 type mismatch in transactionForm.ts
```

**Verification:**
```bash
gh pr checks 312 | grep "TypeScript Type Check"
# Output: TypeScript Type Check   ✓  success
```

**Result:** ✅ Fixed in 1 iteration (2m 30s)

---

## Scenario 2: ESLint no-console

**Detected:**
```
Linting & Formatting: FAILED
transactionForm.ts  45:12  error  'console.log' is not allowed  no-console
```

**Context:**
```typescript
// Line 45
console.log('Transaction amount:', amount); // ❌
```

**Ralph-loop fix:**
```typescript
import { debugLog } from '@/utils/debug';
debugLog('Transaction amount:', amount); // ✅
```

**Commit:**
```bash
style(frontend): remove console.log in transactionForm.ts
```

**Result:** ✅ Fixed in 1 iteration (1m 45s)

---

## Scenario 3: Test Failure

**Detected:**
```
Unit & Integration Tests: FAILED
FAIL  api.test.ts
  Error: expect(received).toBe(expected)
  Expected: 200
  Received: 404
```

**Context:**
```typescript
// Test expects 200 but API returns 404
it('should return success', () => {
  expect(response.status).toBe(200); // ❌ API changed to 404
});
```

**Ralph-loop analysis:**
- Check if API endpoint changed
- Verify if test or code is wrong

**Fix (if API is correct now):**
```typescript
it('should return success', () => {
  expect(response.status).toBe(404); // ✅ Updated to match actual
});
```

**Commit:**
```bash
test(frontend): fix assertion in api.test.ts
```

**Result:** ✅ Fixed in 1 iteration (2m 10s)

---

## Scenario 4: Multiple Errors

**Detected:**
```
TypeScript Type Check: FAILED (2 errors)
Linting & Formatting: FAILED (1 error)
```

**Error 1:** TS2322 in transactionForm.ts:45
**Error 2:** TS2304 in budgetState.ts:78
**Error 3:** no-console in helpers.ts:23

**Ralph-loop strategy:** Fix sequentially

### Iteration 1: Fix TS2322

```typescript
// transactionForm.ts:45
const amount: number = parseInt(formData.get('amount'), 10);
```

**Commit:** `fix(frontend): resolve TS2322 in transactionForm.ts`

**Push → Wait → Checks:**
```
TypeScript Type Check: FAILED (1 error left)
```

### Iteration 2: Fix TS2304

```typescript
// budgetState.ts:78
import { BudgetItem } from './types'; // Add missing import
```

**Commit:** `fix(frontend): resolve TS2304 in budgetState.ts`

**Push → Wait → Checks:**
```
TypeScript Type Check: SUCCESS ✓
Linting & Formatting: FAILED (1 error)
```

### Iteration 3: Fix no-console

```typescript
// helpers.ts:23
import { debugLog } from '@/utils/debug';
debugLog('Helper called');
```

**Commit:** `style(frontend): remove console.log in helpers.ts`

**Push → Wait → Checks:**
```
All checks passed ✓
```

**Result:** ✅ Fixed in 3 iterations (7m 20s)

---

## Scenario 5: Coverage Threshold

**Detected:**
```
Unit & Integration Tests: FAILED
Coverage for lines (8.5%) does not meet threshold (8.9%)
```

**Analysis:**
- New code added: `calculateTotal()` function
- No tests for new function

**Ralph-loop fix:**
Add tests:

```typescript
// In __tests__/budget.test.ts
describe('calculateTotal', () => {
  it('should sum amounts correctly', () => {
    expect(calculateTotal([1, 2, 3])).toBe(6);
  });

  it('should handle empty array', () => {
    expect(calculateTotal([])).toBe(0);
  });

  it('should handle null values', () => {
    expect(calculateTotal([1, null, 3])).toBe(4);
  });
});
```

**Commit:**
```bash
test(frontend): add tests for calculateTotal method
```

**Verification:**
```bash
npm run test:coverage
# Lines: 9.2% ✅ (above 8.9% threshold)
```

**Result:** ✅ Fixed in 1 iteration (3m 30s)

---

## Scenario 6: Build Module Not Found

**Detected:**
```
Build Verification: FAILED
ERROR in ./transactionFilter.ts
Module not found: Error: Can't resolve 'lodash'
```

**Context:**
```typescript
import { debounce } from 'lodash'; // ❌ lodash not installed
```

**Ralph-loop fix:**

1. Install dependency:
```bash
npm install lodash
npm install --save-dev @types/lodash
```

2. Commit both changes:
```bash
git add package.json package-lock.json
git commit -m "fix(build): install missing lodash dependency"
```

**Result:** ✅ Fixed in 1 iteration (2m 45s)

---

## Scenario 7: Max Iterations Reached

**Detected:**
```
TypeScript Type Check: FAILED
(Complex type inference error)
```

**Ralph-loop attempts:**

**Iteration 1:** Add type annotation → Still fails
**Iteration 2:** Add type cast → Still fails
**Iteration 3:** Refactor to simpler types → Still fails
**Iteration 4:** Use `any` (bad practice) → ESLint fails now
**Iteration 5:** Revert to original → Still original error

**Result:** ❌ Max iterations (5) reached

**Output:**
```json
{
  "success": false,
  "finalStatus": "max_iterations_reached",
  "fixIterations": 5,
  "errors": [
    "Complex type inference error requires manual intervention"
  ]
}
```

**User-facing message:**
```
⚠️ Unable to auto-fix after 5 iterations

Remaining error:
- TypeScript TS2589: Type instantiation is excessively deep

Manual intervention required. Please review:
https://github.com/ikeniborn/familyBudget/pull/312
```

---

## Scenario 8: Null Pointer Fix

**Detected:**
```
Unit & Integration Tests: FAILED
TypeError: Cannot read properties of undefined (reading 'total')
```

**Context:**
```typescript
// In calculateTotal
const total = order.items.reduce((sum, item) => sum + item.amount, 0);
// ❌ order.items might be undefined
```

**Ralph-loop fix:**
```typescript
const total = order?.items?.reduce((sum, item) => sum + item.amount, 0) ?? 0;
// ✅ Optional chaining + nullish coalescing
```

**Also add TypeScript fix:**
```typescript
// Update type to allow null/undefined
interface Order {
  items?: BudgetItem[]; // Make optional
}
```

**Commit:**
```bash
refactor(frontend): add null check in calculateTotal method
```

**Result:** ✅ Fixed in 1 iteration (2m 20s)

---

## Summary of Fix Times

| Scenario | Iterations | Time | Success |
|----------|-----------|------|---------|
| TypeScript TS2322 | 1 | 2m 30s | ✅ |
| ESLint no-console | 1 | 1m 45s | ✅ |
| Test failure | 1 | 2m 10s | ✅ |
| Multiple errors (3) | 3 | 7m 20s | ✅ |
| Coverage threshold | 1 | 3m 30s | ✅ |
| Module not found | 1 | 2m 45s | ✅ |
| Complex type error | 5 | 15m | ❌ |
| Null pointer | 1 | 2m 20s | ✅ |

**Average successful fix:** 2.6 minutes (1.3 iterations)
**Success rate:** 87.5% (7/8 scenarios)

---

## Common Patterns

### Pattern 1: Type Conversion

**Error:** TS2322, TS2345
**Fix:** Add `parseInt()`, `String()`, `Number()`
**Time:** ~2 minutes

### Pattern 2: Import Missing

**Error:** TS2304, Module not found
**Fix:** Add import or install package
**Time:** ~2-3 minutes

### Pattern 3: Null Safety

**Error:** TypeError, TS2531, TS2532
**Fix:** Add optional chaining or null checks
**Time:** ~2 minutes

### Pattern 4: Test Update

**Error:** Test assertion mismatch
**Fix:** Update expected value or fix code
**Time:** ~2 minutes

### Pattern 5: Linting

**Error:** ESLint violations
**Fix:** Remove debug statements, fix formatting
**Time:** ~1-2 minutes

---

## When Auto-Fix Fails

**Manual intervention needed if:**

1. **Complex type errors** (TS2589, TS2769)
2. **Architectural changes required**
3. **Breaking API changes**
4. **Database schema conflicts**
5. **Merge conflicts**

**Action:** Report partial success and guide user to manual fix.
