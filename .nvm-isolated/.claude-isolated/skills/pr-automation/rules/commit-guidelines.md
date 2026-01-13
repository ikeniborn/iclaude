# Commit Guidelines for Auto-Fixes

**Version:** 1.0.0
**Purpose:** Guidelines for automatic commits generated during error fixing

---

## Commit Message Format

All auto-fix commits follow Conventional Commits:

```
<type>(<scope>): <summary>

[optional body]

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

---

## Commit Types for Auto-Fixes

### `fix` - Bug Fixes

Used for fixing errors detected by CI/CD:

```bash
fix(frontend): resolve TS2322 type mismatch in transactionForm.ts

Added parseInt() conversion for form input values to match
number type annotation.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**When to use:**
- TypeScript type errors
- Runtime errors
- Test failures
- Build errors

### `style` - Code Style Fixes

Used for linting and formatting fixes:

```bash
style(frontend): remove console.log statement in budgetState.ts

Replaced console.log with debugLog() to comply with
no-console ESLint rule.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**When to use:**
- ESLint violations
- Prettier formatting
- Unused variable removal
- Import ordering

### `refactor` - Code Refactoring

Used when fixing requires code restructuring:

```bash
refactor(frontend): add null check in calculateTotal method

Added null/undefined check to prevent TypeError when
accessing order.items property.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**When to use:**
- Null/undefined handling
- Type narrowing
- Defensive programming

### `test` - Test Fixes

Used for fixing test failures:

```bash
test(frontend): fix assertion in api.test.ts

Updated expected value from 404 to 200 to match actual
API response after endpoint fix.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**When to use:**
- Assertion fixes
- Mock updates
- Test timeout adjustments

---

## Scope Guidelines

### Frontend Scope
```
fix(frontend): ...
style(frontend): ...
refactor(frontend): ...
test(frontend): ...
```

**Use when fixing:**
- TypeScript files in `frontend/`
- JavaScript modules
- CSS/SCSS files
- Frontend tests

### Backend Scope
```
fix(backend): ...
refactor(backend): ...
test(backend): ...
```

**Use when fixing:**
- Python files in `backend/`
- API endpoints
- Service layer
- Backend tests

### Build Scope
```
fix(build): ...
```

**Use when fixing:**
- Webpack/Vite config
- Package.json dependencies
- Build scripts
- Bundle size issues

---

## Summary Guidelines

### Be Specific

❌ Bad:
```
fix(frontend): fix error
fix(frontend): update file
```

✅ Good:
```
fix(frontend): resolve TS2322 type mismatch in transactionForm.ts
fix(frontend): add parseInt conversion for amount field
```

### Imperative Mood

Use imperative verbs (add, fix, remove, update):

✅ Correct:
```
fix(frontend): resolve type error
style(frontend): remove console.log
refactor(frontend): add null check
```

❌ Incorrect:
```
fix(frontend): resolved type error
style(frontend): removing console.log
refactor(frontend): added null check
```

### Max 72 Characters

Keep summary line under 72 characters:

```
fix(frontend): resolve TS2322 in transactionForm.ts  # 51 chars ✅
```

---

## Body Guidelines

### Include Error Context

```
fix(frontend): resolve TS2322 type mismatch in transactionForm.ts

Error: Type 'string' is not assignable to type 'number'
File: frontend/web/static/js/budget/transactionForm.ts
Line: 45

Added parseInt() conversion for form input values to match
number type annotation.
```

### Explain the Fix

```
style(frontend): remove console.log in budgetState.ts

Replaced console.log with debugLog() from utils/debug.ts
to comply with no-console ESLint rule.
```

### Reference Error Code

For TypeScript errors, include error code:

```
fix(frontend): resolve TS2304 in api.ts

Error TS2304: Cannot find name 'UnknownType'
Import added for missing type definition.
```

---

## Examples by Error Type

### TypeScript TS2322 (Type Mismatch)

```
fix(frontend): resolve TS2322 type mismatch in transactionFilter.ts

Added parseInt() conversion for form data to match number type.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### ESLint no-console

```
style(frontend): remove console.log in transactionForm.ts

Replaced console.log with debugLog() to comply with ESLint.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### ESLint no-unused-vars

```
style(frontend): remove unused variable in helpers.ts

Removed unused 'foo' variable to comply with no-unused-vars rule.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### Vitest Test Failure

```
test(frontend): fix assertion in api.test.ts

Updated expected status code from 404 to 200.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### Build Module Not Found

```
fix(build): install missing lodash dependency

Added lodash@4.17.21 to resolve build error.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

---

## Co-Author Attribution

All auto-fix commits include:

```
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

This indicates:
- Commit was generated automatically
- Claude Code pr-automation skill was used
- Human should review changes

---

## Verification Before Commit

Before each auto-fix commit:

1. ✅ Verify fix resolves the error
2. ✅ Run type check/linter locally
3. ✅ Ensure no new errors introduced
4. ✅ Commit message follows guidelines
5. ✅ Push to branch and monitor checks

---

## References

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Git Best Practices](https://git-scm.com/book/en/v2/Distributed-Git-Contributing-to-a-Project)
- [Semantic Commit Messages](https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716)
