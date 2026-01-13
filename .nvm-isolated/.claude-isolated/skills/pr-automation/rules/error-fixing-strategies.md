# Error Fixing Strategies

**Version:** 1.0.0
**Purpose:** Detailed guides for automatically fixing CI/CD errors

---

## TypeScript Errors

### TS2322: Type Mismatch

**Error:**
```
Type 'string' is not assignable to type 'number'
```

**Diagnosis:**
- Variable declared as `number` but assigned `string`
- Form data is always string, needs conversion

**Fixes:**

1. **Type Conversion:**
```typescript
// Before (error)
const amount: number = formData.get('amount');

// After (fixed)
const amount: number = parseInt(formData.get('amount'), 10);
```

2. **Type Annotation:**
```typescript
// Before (error)
const value: number = getValue();

// After (fixed)
const value: string | number = getValue();
```

3. **Type Assertion (if certain):**
```typescript
const value = getValue() as number;
```

**Commit:**
```
fix(frontend): resolve TS2322 type mismatch in transactionForm.ts

Added parseInt() conversion for form input values.
```

---

### TS2304: Cannot Find Name

**Error:**
```
Cannot find name 'UnknownType'
```

**Diagnosis:**
- Import missing
- Typo in variable/type name
- Variable not declared

**Fixes:**

1. **Add Import:**
```typescript
// Before
function foo(x: MyType) { }

// After
import { MyType } from './types';
function foo(x: MyType) { }
```

2. **Fix Typo:**
```typescript
// Before: UnkownType (typo)
// After: UnknownType
```

3. **Declare Variable:**
```typescript
const myVar: string = 'value';
```

**Commit:**
```
fix(frontend): resolve TS2304 in api.ts

Added missing import for MyType.
```

---

### TS2345: Argument Type Mismatch

**Error:**
```
Argument of type 'number' is not assignable to parameter of type 'string'
```

**Diagnosis:**
- Function expects different type
- Check function signature

**Fixes:**

1. **Convert Argument:**
```typescript
// Before
calculateTotal(amount); // number

// After
calculateTotal(String(amount)); // string
```

2. **Update Function Signature:**
```typescript
// If function should accept number
function calculateTotal(amount: number | string) { }
```

**Commit:**
```
fix(frontend): resolve TS2345 in budgetService.ts

Converted argument to expected string type.
```

---

### TS2531/TS2532: Null/Undefined Access

**Error:**
```
Object is possibly 'null'
Object is possibly 'undefined'
```

**Diagnosis:**
- Accessing property without null check
- Optional chaining needed

**Fixes:**

1. **Optional Chaining:**
```typescript
// Before (error)
const total = order.items.reduce(...);

// After (fixed)
const total = order?.items?.reduce(...) ?? 0;
```

2. **Null Check:**
```typescript
if (order && order.items) {
  const total = order.items.reduce(...);
}
```

3. **Non-Null Assertion (if certain):**
```typescript
const total = order!.items.reduce(...);
```

**Commit:**
```
refactor(frontend): add null check in calculateTotal

Added optional chaining to prevent TypeError.
```

---

## ESLint Errors

### no-console

**Error:**
```
'console.log' is not allowed  no-console
```

**Diagnosis:**
- Debug statement left in code
- ESLint rule forbids console

**Fixes:**

1. **Replace with debugLog:**
```typescript
// Before (error)
console.log('Transaction amount:', amount);

// After (fixed)
import { debugLog } from '@/utils/debug';
debugLog('Transaction amount:', amount);
```

2. **Remove if unnecessary:**
```typescript
// Just delete the line
```

3. **Disable rule (only if intentional):**
```typescript
// eslint-disable-next-line no-console
console.log('Critical error:', error);
```

**Commit:**
```
style(frontend): remove console.log in transactionForm.ts

Replaced with debugLog() from utils/debug.ts.
```

---

### @typescript-eslint/no-unused-vars

**Error:**
```
'foo' is assigned a value but never used
```

**Diagnosis:**
- Variable declared but not used
- Leftover from refactoring

**Fixes:**

1. **Remove Variable:**
```typescript
// Before
const foo = getValue();
const bar = getOther();
return bar;

// After
const bar = getOther();
return bar;
```

2. **Prefix with Underscore (intentional):**
```typescript
const _foo = getValue(); // Marked as intentionally unused
```

**Commit:**
```
style(frontend): remove unused variable in helpers.ts

Removed unused 'foo' variable.
```

---

### prettier/prettier

**Error:**
```
Delete `··` prettier/prettier
```

**Diagnosis:**
- Formatting doesn't match Prettier rules
- Extra spaces, missing semicolons

**Fixes:**

1. **Run Prettier:**
```bash
npx prettier --write <file>
```

2. **Auto-fix in code:**
```typescript
// Prettier will format automatically
```

**Commit:**
```
style(frontend): apply Prettier formatting

Ran prettier --write to fix formatting.
```

---

## Vitest Test Failures

### Assertion Mismatch

**Error:**
```
expect(received).toBe(expected)
Expected: 200
Received: 404
```

**Diagnosis:**
- Expected value doesn't match actual
- Check if logic changed
- API endpoint might have changed

**Fixes:**

1. **Update Expected Value (if API changed):**
```typescript
// Before
expect(response.status).toBe(404);

// After
expect(response.status).toBe(200);
```

2. **Fix Code Logic (if test is correct):**
```typescript
// Fix the actual implementation to return 200
```

**Commit:**
```
test(frontend): fix assertion in api.test.ts

Updated expected status code to match new API response.
```

---

### Mock Not Called

**Error:**
```
expect(jest.fn()).toHaveBeenCalled()
Expected number of calls: >= 1
Received number of calls:    0
```

**Diagnosis:**
- Mock function not invoked
- Code path changed
- Async timing issue

**Fixes:**

1. **Check Code Path:**
```typescript
// Ensure mock is actually called
await functionThatCallsMock();
expect(mockFn).toHaveBeenCalled();
```

2. **Add await (async issue):**
```typescript
// Before
functionThatCallsMock();
expect(mockFn).toHaveBeenCalled();

// After
await functionThatCallsMock();
expect(mockFn).toHaveBeenCalled();
```

**Commit:**
```
test(frontend): fix mock invocation in state.test.ts

Added await to ensure mock is called before assertion.
```

---

### Null/Undefined Access in Test

**Error:**
```
Cannot read properties of undefined (reading 'total')
```

**Diagnosis:**
- Test data incomplete
- Object not initialized

**Fixes:**

1. **Add Null Check in Code:**
```typescript
// In implementation
const total = data?.total ?? 0;
```

2. **Fix Test Data:**
```typescript
// In test
const mockData = {
  total: 100, // Add missing property
  items: []
};
```

**Commit:**
```
refactor(frontend): add null check for total property

Added optional chaining in calculateTotal method.
```

---

### Test Timeout

**Error:**
```
Test timeout of 5000ms exceeded
```

**Diagnosis:**
- Async operation too slow
- Infinite loop
- Missing await

**Fixes:**

1. **Increase Timeout:**
```typescript
it('should complete', async () => {
  // ...
}, 10000); // 10 seconds
```

2. **Optimize Code:**
```typescript
// Reduce fake timer delays
vi.advanceTimersByTime(100); // Instead of 1000
```

3. **Add await:**
```typescript
await waitFor(() => expect(...));
```

**Commit:**
```
test(frontend): increase timeout for slow test

Increased timeout to 10s for async operation.
```

---

## Build Errors

### Module Not Found

**Error:**
```
Module not found: Error: Can't resolve 'lodash' in '/path/to/app'
```

**Diagnosis:**
- Dependency not installed
- Import path wrong

**Fixes:**

1. **Install Dependency:**
```bash
npm install lodash
```

2. **Fix Import Path:**
```typescript
// Before
import { debounce } from 'lodash';

// After
import debounce from 'lodash/debounce';
```

**Commit:**
```
fix(build): install missing lodash dependency

Added lodash@4.17.21 to package.json.
```

---

### Bundle Size Exceeded

**Error:**
```
WARNING in asset size limit: The following asset(s) exceed the recommended size limit (500 KB)
```

**Diagnosis:**
- Bundle too large
- Large dependencies included

**Fixes:**

1. **Code Splitting:**
```typescript
// Before
import { HeavyComponent } from './HeavyComponent';

// After
const HeavyComponent = lazy(() => import('./HeavyComponent'));
```

2. **Remove Unused Imports:**
```typescript
// Remove unused lodash functions
```

3. **Use Smaller Alternatives:**
```typescript
// Replace moment.js with date-fns
```

**Commit:**
```
perf(build): reduce bundle size with code splitting

Lazy-loaded HeavyComponent to reduce initial bundle.
```

---

## Coverage Threshold Failures

### Lines Coverage Below Threshold

**Error:**
```
Coverage for lines (8.5%) does not meet threshold (8.9%)
```

**Diagnosis:**
- New code added without tests
- Uncovered lines in modified files

**Fixes:**

1. **Add Tests for New Code:**
```typescript
describe('calculateTotal', () => {
  it('should sum amounts correctly', () => {
    expect(calculateTotal([1, 2, 3])).toBe(6);
  });
});
```

2. **Test Edge Cases:**
```typescript
it('should handle empty array', () => {
  expect(calculateTotal([])).toBe(0);
});

it('should handle null values', () => {
  expect(calculateTotal([1, null, 3])).toBe(4);
});
```

**Commit:**
```
test(frontend): add tests for calculateTotal method

Added tests to meet coverage threshold (8.9% lines).
```

---

## General Strategies

### 1. Read Error Carefully

- Identify exact file and line
- Understand error type (TS2322, etc.)
- Check error message for hints

### 2. Check Context

- Read surrounding code (±10 lines)
- Understand function purpose
- Check related files

### 3. Apply Smallest Fix

- Don't refactor unnecessarily
- Fix only what's broken
- Keep changes minimal

### 4. Verify Fix Locally

```bash
# TypeScript
npm run type-check

# ESLint
npm run lint

# Tests
npm test

# Build
npm run build
```

### 5. Commit and Push

```bash
git add <file>
git commit -m "fix(scope): <message>"
git push origin <branch>
```

### 6. Monitor Checks

```bash
gh pr checks <pr-number> --watch
```

---

## References

- TypeScript Error Messages: https://typescript.tv/errors/
- ESLint Rules: https://eslint.org/docs/rules/
- Vitest API: https://vitest.dev/api/
