---
name: pr-automation
description: Автоматизация создания PR с мониторингом CI/CD и автоматическим исправлением ошибок
version: 1.3.0
author: ikeniborn
tags: [github, pr, ci/cd, automation, github-actions, typescript, eslint, toon, loop-mode]
dependencies: [git-workflow, code-review, toon-skill]
triggers:
  - "создать pr"
  - "создать pull request"
  - "сделать pr"
  - "открыть pull request"
user-invocable: true
changelog:
  - version: 1.3.0
    date: 2026-01-25
    changes:
      - "**BREAKING**: Удален ralph-loop plugin (deprecated)"
      - "Замена: Bash loop mode через ./iclaude.sh --loop task.md"
      - "External tool для итеративных фиксов (не auto-invocation)"
      - "Обновлены examples для manual loop invocation"
  - version: 1.2.0
    date: 2026-01-25
    changes:
      - "Централизация: TOON specs → @shared:TOON-REFERENCE.md"
      - "Добавлено: 7 полных примеров (simple, TS errors, multiple types, max iterations, TOON optimization, production, CI timeout)"
      - "Skill-specific TOON usage notes для checks[], autoFixedErrors[], commits[]"
      - "Обновлены references: @shared:GIT-CONVENTIONS.md, @shared:TOON-REFERENCE.md, @shared:TASK-STRUCTURE.md"
  - version: 1.1.0
    date: 2026-01-23
    changes:
      - "**TOON Format Support**: Автоматическая генерация TOON для token efficiency"
      - "TOON для checks[], autoFixedErrors[], commits[] (когда >= 5 элементов)"
      - "35-45% token savings для PR с множественными checks/fixes"
      - "100% backward compatibility (JSON остаётся primary format)"
      - "Complete audit trail сохраняется в TOON"
      - "Use cases: CI/CD monitoring, auto-fix analysis, commit history, PR metrics"
  - version: 1.0.0
    date: 2025-XX-XX
    changes:
      - "Initial release"
      - "Auto-detection stack & CI/CD"
---

# PR Automation Skill

Автоматизирует полный workflow создания Pull Request с мониторингом CI/CD и поддержкой автоматического исправления ошибок.

## Возможности

- ✅ **Auto-detection** стека и CI/CD из `/docs/architecture`
- ✅ **Draft PR creation** с auto-generated описанием
- ✅ **Real-time CI/CD monitoring** через GitHub Actions
- ✅ **Автоматическое исправление** 4 типов ошибок:
  - TypeScript (TS2322, TS2304, TS2345, TS2531, TS2532)
  - ESLint/Prettier (no-console, no-unused-vars)
  - Vitest тесты (assertion failures, mock issues)
  - Build errors (module not found, syntax errors)
- ✅ **External loop tool** для итеративных фиксов (./iclaude.sh --loop)
- ✅ **Conventional Commits** для всех автокоммитов
- ✅ **Ready-for-review** после успешного прохождения всех проверок

## Предварительные требования

### 1. gh CLI в изолированном окружении

```bash
cd /home/ikeniborn/Documents/Project/claude
./iclaude.sh --install-gh
./iclaude.sh --check-gh
```

**Авторизация:**
```bash
gh auth login
```

### 2. Git Workflow

Требуется для форматирования commit messages.

## Использование

### Базовый запрос

```
Создать PR из feature/transaction-filters в test
```

### С явными параметрами

```
Сделай pull request для текущей ветки в test,
включи автоисправление ошибок
```

### Для production

```
Открыть PR из feature/my-feature в prod
```

## Workflow Фазы

### PHASE 0A: Auto-detect Stack & CI/CD (30-60s)

**Автоматически определяет:**
- Технологический стек из `/docs/architecture/index.yaml`
- CI/CD платформу из `.github/workflows/*.yml`
- Required checks для PR
- Error patterns для detected stack

**Действия:**

1. **Чтение архитектурной документации:**
```bash
yq eval -o=json docs/architecture/index.yaml > /tmp/arch_index.json

# Extract stack info
backend=$(jq -r '.sections.functionality.modules[0].description' /tmp/arch_index.json)
frontend=$(jq -r '.sections.web.components[1].description' /tmp/arch_index.json)
```

2. **Парсинг CI/CD workflows:**
```bash
for workflow in .github/workflows/*.yml; do
  yq eval '.jobs | keys' "$workflow" -o=json
done
```

3. **Построение error patterns:**
```javascript
// Detected: TypeScript + Python
{
  "typescript": { "enabled": true },
  "eslint": { "enabled": true },
  "vitest": { "enabled": true },
  "python": { "enabled": false }  // Not typical for frontend PRs
}
```

**Fallback (если документация отсутствует):**
```bash
# Detect from file extensions
typescript_files=$(find . -name "*.ts" | wc -l)
# If > 0 → enable TypeScript patterns
```

**Output:**
```json
{
  "detectedStack": {
    "backend": "Python 3 + FastAPI",
    "frontend": "TypeScript + Vite + HTMX + Tailwind"
  },
  "cicdConfig": {
    "platform": "GitHub Actions",
    "requiredChecks": [
      "TypeScript Type Check",
      "Unit & Integration Tests",
      "Build Verification"
    ]
  }
}
```

---

### PHASE 0B: Initialization (1-2 min)

**Действия:**
1. Проверка `gh auth status`
2. Проверка `git status`
3. AskUserQuestion для подтверждения веток
4. Валидация веток существуют

**Output:**
```json
{
  "sourceBranch": "feature/transaction-filters",
  "targetBranch": "test",
  "authenticated": true
}
```

---

### PHASE 1: Analysis (2-3 min)

**Действия:**
1. `git diff test...feature/transaction-filters`
2. `git log test..feature/transaction-filters --oneline`
3. Определение типов файлов (TypeScript, Python, etc.)
4. Генерация PR description из `templates/pr-description.md.mustache`

**Output:**
```json
{
  "commits": [...],
  "changedFiles": [...],
  "hasTypescriptChanges": true
}
```

---

### PHASE 2: PR Creation (1 min)

**Команда:**
```bash
gh pr create --draft \
  --base test \
  --head feature/transaction-filters \
  --title "feat(frontend): add transaction filtering" \
  --body "$(cat pr_description.md)"
```

**Output:**
```json
{
  "prNumber": 312,
  "prUrl": "https://github.com/ikeniborn/familyBudget/pull/312",
  "isDraft": true
}
```

---

### PHASE 3: CI/CD Monitoring (5-15 min)

**Мониторинг:**
```bash
gh pr checks 312 --watch --interval 30
```

**Парсинг статуса:**
```bash
gh pr checks 312 --json name,conclusion,detailsUrl
```

**Решение:**
- Все success → PHASE 5 (Finalization)
- Есть failure → PHASE 4 (Error Fixing)

---

### PHASE 4: Error Fixing Loop (10-30 min, итеративно)

**Для каждого failed check:**

1. **Получить логи:**
```bash
gh run view $run_id --log-failed > /tmp/ci_logs.txt
```

2. **Парсинг ошибок** (используя `templates/error-patterns.json`):
```bash
grep -E "error TS[0-9]+" /tmp/ci_logs.txt
```

3. **Исправление ошибок** (manual или через external loop tool):
   - Option A: Manual fix в Claude Code
   - Option B: External loop tool (./iclaude.sh --loop task.md)
     ```bash
     # Create task definition
     cat > fix-ts-error.md <<'EOF'
     # Task: Fix TypeScript error TS2322
     ## Description
     Fix TS2322 in transactionForm.ts:45
     ## Completion Promise
     gh pr checks 312
     ## Validation Command
     gh pr checks 312 | grep -E "✓|success" | wc -l
     ## Max Iterations
     5
     EOF

     # Run loop (external to Claude session)
     ./iclaude.sh --loop fix-ts-error.md
     ```
   - Применяет fix из `rules/error-fixing-strategies.md`
   - Коммитит (формат из `@shared:GIT-CONVENTIONS.md#conventional-commits`)
   - Пушит в branch
   - Ждёт re-run checks

4. **Повторить** пока все checks не пройдут или max iterations

**Output:**
```json
{
  "fixedErrors": [
    {
      "errorType": "typescript",
      "file": "transactionForm.ts",
      "line": 45,
      "fix": "Added parseInt() conversion",
      "commitHash": "abc123"
    }
  ]
}
```

---

### PHASE 5: Finalization (1 min)

**Действия:**
1. Mark PR as ready:
```bash
gh pr ready 312
```

2. Generate summary output

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
- fix(frontend): resolve TS2322 type mismatch

Total time: 8m 34s
Fix iterations: 1/5
```

---

## Типы авто-исправляемых ошибок

### 1. TypeScript Errors

**TS2322: Type Mismatch**
```typescript
// Before
const amount: number = formData.get('amount');

// After
const amount: number = parseInt(formData.get('amount'), 10);
```

**TS2304: Cannot Find Name**
```typescript
// Add missing import
import { MyType } from './types';
```

**TS2531/TS2532: Null/Undefined**
```typescript
// Add optional chaining
const total = order?.items?.reduce(...) ?? 0;
```

### 2. ESLint Errors

**no-console**
```typescript
// Replace console.log with debugLog
import { debugLog } from '@/utils/debug';
debugLog('Message');
```

**no-unused-vars**
```typescript
// Remove unused variable or prefix with _
const _unused = getValue();
```

### 3. Vitest Test Failures

**Assertion Mismatch**
```typescript
// Update expected value if API changed
expect(response.status).toBe(200); // Was 404
```

**Mock Not Called**
```typescript
// Add await for async
await functionThatCallsMock();
expect(mockFn).toHaveBeenCalled();
```

### 4. Build Errors

**Module Not Found**
```bash
npm install lodash
```

**Bundle Size Exceeded**
```typescript
// Code splitting with lazy loading
const HeavyComponent = lazy(() => import('./Heavy'));
```

---

## Output Format

**JSON Schema:** См. `@shared:TASK-STRUCTURE.md#pr-workflow`

**Example:**
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
  "fixIterations": 2,
  "autoFixedErrors": [...],
  "executionTime": {
    "total": "8m 34s"
  }
}
```

---

## Safety Rules

**NEVER:**
- Force push to main/master
- Commit secrets/credentials
- Use `--no-verify` flag
- Amend others' commits
- Auto-merge PR (always leave for human review)

**ALWAYS:**
- Create as Draft PR first
- Verify branch before push
- Use Conventional Commits format (см. `@shared:GIT-CONVENTIONS.md`)
- Include Co-Authored-By for auto-fixes
- Wait for all checks before marking ready

---

## Troubleshooting

### Issue 1: gh CLI Not Authenticated

**Symptom:**
```
gh: To use GitHub CLI, please authenticate by running: gh auth login
```

**Fix:**
```bash
gh auth login
# Follow interactive prompts
```

### Issue 2: Max Iterations Reached

**Symptom:**
```
⚠️ Unable to auto-fix after 5 iterations
```

**Причина:** Complex error требует ручного вмешательства

**Действия:**
1. Проверить последнюю ошибку в PR checks
2. Читать `rules/error-fixing-strategies.md`
3. Исправить вручную
4. Commit и push

### Issue 3: Checks Never Complete

**Symptom:** Checks stuck in "pending"

**Причина:** GitHub Actions queue delay

**Действия:**
1. Подождать (обычно 2-5 минут)
2. Проверить workflow file на ошибки
3. Cancel и re-trigger checks

### Issue 4: Wrong File Fixed

**Symptom:** Исправлен не тот файл

**Причина:** Ambiguous error context

**Действия:**
1. Revert commit: `git revert HEAD`
2. Push revert
3. Предоставить более точный контекст для fix

---

## TOON Format Support

**Skill uses TOON format** для token-efficient PR workflow reporting.

### References

**TOON Format Specification:**
- Full spec: `@shared:TOON-REFERENCE.md`
- Benefits: `@shared:TOON-REFERENCE.md#benefits`
- Integration patterns: `@shared:TOON-REFERENCE.md#integration-patterns`
- Token savings benchmarks: `@shared:TOON-REFERENCE.md#token-savings`

**Git Conventions:**
- Commit format: `@shared:GIT-CONVENTIONS.md#conventional-commits`

**Task Structure:**
- PR workflow schema: `@shared:TASK-STRUCTURE.md#pr-workflow`

### Skill-Specific TOON Usage

**pr-automation генерирует TOON для:**
- `checks[]` - когда >= 5 CI/CD checks
- `autoFixedErrors[]` - когда >= 5 auto-fixed errors
- `commits[]` - когда >= 5 commits

**Implementation:**
```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// PR result with multiple arrays
const prResult = {
  success: true,
  prNumber: 312,
  prUrl: "https://github.com/user/repo/pull/312",
  checks: [...],           // 8 checks
  autoFixedErrors: [...],  // 15 errors
  commits: [...]           // 12 commits
};

// Add TOON optimization (only if >= 5 elements)
const dataToConvert = {};

if (prResult.checks.length >= 5) {
  prResult.toon = prResult.toon || {};
  prResult.toon.checks_toon = arrayToToon('checks', prResult.checks,
    ['name', 'status', 'duration_ms', 'conclusion', 'details_url']);
  dataToConvert.checks = prResult.checks;
}

if (prResult.autoFixedErrors.length >= 5) {
  prResult.toon = prResult.toon || {};
  prResult.toon.autoFixedErrors_toon = arrayToToon('autoFixedErrors', prResult.autoFixedErrors,
    ['file', 'line', 'error_type', 'error_code', 'message', 'fix_applied', 'commit_sha']);
  dataToConvert.autoFixedErrors = prResult.autoFixedErrors;
}

if (prResult.commits.length >= 5) {
  prResult.toon = prResult.toon || {};
  prResult.toon.commits_toon = arrayToToon('commits', prResult.commits,
    ['sha', 'author', 'timestamp', 'type', 'message']);
  dataToConvert.commits = prResult.commits;
}

// Calculate total token savings
if (prResult.toon) {
  const stats = calculateTokenSavings(dataToConvert);
  prResult.toon.token_savings = stats.savedPercent;
  prResult.toon.size_comparison = `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`;
}

return prResult;
```

**Token Savings (PR-Specific):**
- Standard PR (8 checks, 15 errors, 12 commits): **40.2% savings** (5800 → 3468 tokens)
- Complex PR (12 checks, 30 errors, 25 commits): **42% savings** (9200 → 5336 tokens)
- Simple PR (<5 elements): JSON only, no TOON overhead

**Use Cases (PR-Specific):**
1. **CI/CD Monitoring**: Track check execution times, identify slow checks
2. **Auto-Fix Analysis**: Analyze error types (TS2322 vs ESLint), track fix success rates
3. **Commit History**: Review auto-generated commits for Conventional Commits compliance
4. **PR Metrics Dashboard**: Aggregate data across PRs, identify CI/CD bottlenecks

---

## Examples

### Example 1: Simple PR (No CI Failures)

**User Task:** "Создать PR из feature/add-logout-button в test"

**Input:**
```json
{
  "sourceBranch": "feature/add-logout-button",
  "targetBranch": "test"
}
```

**Workflow:**

1. **PHASE 0A: Auto-detect Stack**
   - Detected: TypeScript + Vite (from architecture docs)
   - Required checks: ["TypeScript Type Check", "ESLint", "Vitest Tests", "Build"]

2. **PHASE 1: Analysis**
   - Changed files: 3 (Header.tsx, auth.ts, auth.test.ts)
   - Commits: 2 ("feat: add logout button", "test: add logout functionality test")

3. **PHASE 2: PR Creation**
   - Created draft PR #412
   - Title: "feat(frontend): add logout button"

4. **PHASE 3: CI/CD Monitoring**
   - All 4 checks passed on first run (no errors)

5. **PHASE 5: Finalization**
   - Marked PR as ready for review

**Output:**
```json
{
  "success": true,
  "prNumber": 412,
  "prUrl": "https://github.com/user/repo/pull/412",
  "finalStatus": "all_checks_passed",
  "checksStatus": {
    "total": 4,
    "passed": 4,
    "failed": 0
  },
  "checks": [
    {"name": "TypeScript Type Check", "status": "success", "duration_ms": 38000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/401"},
    {"name": "ESLint", "status": "success", "duration_ms": 22000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/402"},
    {"name": "Vitest Tests", "status": "success", "duration_ms": 45000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/403"},
    {"name": "Build", "status": "success", "duration_ms": 67000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/404"}
  ],
  "fixIterations": 0,
  "autoFixedErrors": [],
  "commits": [
    {"sha": "abc123", "author": "User", "timestamp": "2026-01-25T10:00:00Z", "type": "feat", "message": "add logout button"},
    {"sha": "def456", "author": "User", "timestamp": "2026-01-25T10:05:00Z", "type": "test", "message": "add logout functionality test"}
  ],
  "executionTime": {
    "total": "3m 12s"
  }
}
```

**Result:** PR created and ready in 3 minutes, no errors to fix.

---

### Example 2: PR with TypeScript Error (Auto-Fixed)

**User Task:** "Сделать PR из feature/transaction-form в test, включи автоисправление"

**Input:**
```json
{
  "sourceBranch": "feature/transaction-form",
  "targetBranch": "test",
  "autoFix": true
}
```

**Workflow:**

1. **PHASE 0A-1:** Same as Example 1

2. **PHASE 2:** Created draft PR #413

3. **PHASE 3: CI/CD Monitoring**
   - TypeScript check failed: TS2322 error in transactionForm.ts:45

4. **PHASE 4: Error Fixing Loop**

   **Iteration 1:**
   - Parsed error: `Type 'string' is not assignable to type 'number'`
   - Fix context: `transactionForm.ts:45, field: amount`
   - Fix applied: Added `parseInt(value, 10)` conversion
   - Committed: `fix: resolve TS2322 type mismatch in amount field`
   - Re-run checks: All passed ✓

5. **PHASE 5:** Marked ready

**Output:**
```json
{
  "success": true,
  "prNumber": 413,
  "prUrl": "https://github.com/user/repo/pull/413",
  "finalStatus": "all_checks_passed",
  "checksStatus": {
    "total": 4,
    "passed": 4,
    "failed": 0
  },
  "checks": [
    {"name": "TypeScript Type Check", "status": "success", "duration_ms": 42000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/405"},
    {"name": "ESLint", "status": "success", "duration_ms": 25000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/406"},
    {"name": "Vitest Tests", "status": "success", "duration_ms": 48000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/407"},
    {"name": "Build", "status": "success", "duration_ms": 70000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/408"}
  ],
  "fixIterations": 1,
  "autoFixedErrors": [
    {
      "file": "transactionForm.ts",
      "line": 45,
      "error_type": "typescript",
      "error_code": "TS2322",
      "message": "Type 'string' is not assignable to type 'number'",
      "fix_applied": "Added parseInt(value, 10) conversion",
      "commit_sha": "xyz789"
    }
  ],
  "commits": [
    {"sha": "abc123", "author": "User", "timestamp": "2026-01-25T11:00:00Z", "type": "feat", "message": "add transaction form"},
    {"sha": "xyz789", "author": "Claude Code", "timestamp": "2026-01-25T11:08:00Z", "type": "fix", "message": "resolve TS2322 type mismatch in amount field"}
  ],
  "executionTime": {
    "total": "8m 34s"
  }
}
```

**Result:** PR created with 1 auto-fix iteration, total time 8m 34s.

---

### Example 3: PR with Multiple Error Types

**User Task:** "Создать PR из feature/dashboard-redesign в test"

**Input:**
```json
{
  "sourceBranch": "feature/dashboard-redesign",
  "targetBranch": "test",
  "autoFix": true
}
```

**Workflow:**

1. **PHASE 2:** Created draft PR #414

2. **PHASE 3:** CI/CD checks failed with 3 different error types

3. **PHASE 4: Error Fixing Loop**

   **Iteration 1 (TypeScript):**
   - Error: TS2304 - Cannot find name 'DashboardData'
   - Fix: Added `import { DashboardData } from './types'`
   - Commit: `fix: add missing DashboardData import`
   - Re-run: TypeScript passed, ESLint failed

   **Iteration 2 (ESLint):**
   - Error: no-console in dashboard.ts:67
   - Fix: Removed debug console.log
   - Commit: `chore: remove debug console.log from dashboard`
   - Re-run: ESLint passed, Vitest failed

   **Iteration 3 (Vitest):**
   - Error: Assertion failure - expected 200, got 404 in dashboard.test.ts:89
   - Fix: Updated mock API endpoint path from `/api/stats` to `/api/dashboard/stats`
   - Commit: `test: fix mock API endpoint path in dashboard test`
   - Re-run: All checks passed ✓

4. **PHASE 5:** Marked ready

**Output:**
```json
{
  "success": true,
  "prNumber": 414,
  "prUrl": "https://github.com/user/repo/pull/414",
  "finalStatus": "all_checks_passed",
  "checksStatus": {
    "total": 4,
    "passed": 4,
    "failed": 0
  },
  "checks": [
    {"name": "TypeScript Type Check", "status": "success", "duration_ms": 44000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/409"},
    {"name": "ESLint", "status": "success", "duration_ms": 27000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/410"},
    {"name": "Vitest Tests", "status": "success", "duration_ms": 52000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/411"},
    {"name": "Build", "status": "success", "duration_ms": 72000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/412"}
  ],
  "fixIterations": 3,
  "autoFixedErrors": [
    {
      "file": "dashboard.ts",
      "line": 23,
      "error_type": "typescript",
      "error_code": "TS2304",
      "message": "Cannot find name 'DashboardData'",
      "fix_applied": "Added import { DashboardData } from './types'",
      "commit_sha": "aaa111"
    },
    {
      "file": "dashboard.ts",
      "line": 67,
      "error_type": "eslint",
      "error_code": "no-console",
      "message": "Unexpected console.log statement",
      "fix_applied": "Removed debug console.log",
      "commit_sha": "bbb222"
    },
    {
      "file": "dashboard.test.ts",
      "line": 89,
      "error_type": "vitest",
      "error_code": "assertion-failure",
      "message": "Expected 200 but received 404",
      "fix_applied": "Updated mock API endpoint path",
      "commit_sha": "ccc333"
    }
  ],
  "commits": [
    {"sha": "abc123", "author": "User", "timestamp": "2026-01-25T12:00:00Z", "type": "feat", "message": "redesign dashboard layout"},
    {"sha": "aaa111", "author": "Claude Code", "timestamp": "2026-01-25T12:10:00Z", "type": "fix", "message": "add missing DashboardData import"},
    {"sha": "bbb222", "author": "Claude Code", "timestamp": "2026-01-25T12:15:00Z", "type": "chore", "message": "remove debug console.log from dashboard"},
    {"sha": "ccc333", "author": "Claude Code", "timestamp": "2026-01-25T12:20:00Z", "type": "test", "message": "fix mock API endpoint path in dashboard test"}
  ],
  "executionTime": {
    "total": "15m 42s"
  }
}
```

**Result:** PR created with 3 sequential auto-fixes (TypeScript → ESLint → Vitest), total time 15m 42s.

---

### Example 4: Max Iterations Reached

**User Task:** "Создать PR из feature/complex-refactor в test"

**Input:**
```json
{
  "sourceBranch": "feature/complex-refactor",
  "targetBranch": "test",
  "autoFix": true
}
```

**Workflow:**

1. **PHASE 2:** Created draft PR #415

2. **PHASE 3:** CI/CD checks failed with complex TypeScript errors

3. **PHASE 4: Error Fixing Loop**

   **Iterations 1-5:** All attempts to fix TS2345 error failed
   - Complex type incompatibility requiring architectural changes
   - Multiple approaches tried (type assertions, interface extensions, generics)
   - Each fix introduced new type errors
   - Max iterations (5) reached without success

4. **Manual intervention required**

**Output:**
```json
{
  "success": false,
  "prNumber": 415,
  "prUrl": "https://github.com/user/repo/pull/415",
  "finalStatus": "max_iterations_reached",
  "checksStatus": {
    "total": 4,
    "passed": 2,
    "failed": 2
  },
  "checks": [
    {"name": "TypeScript Type Check", "status": "failure", "duration_ms": 46000, "conclusion": "failure", "details_url": "https://github.com/user/repo/actions/runs/413"},
    {"name": "ESLint", "status": "success", "duration_ms": 28000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/414"},
    {"name": "Vitest Tests", "status": "failure", "duration_ms": 55000, "conclusion": "failure", "details_url": "https://github.com/user/repo/actions/runs/415"},
    {"name": "Build", "status": "success", "duration_ms": 74000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/416"}
  ],
  "fixIterations": 5,
  "autoFixedErrors": [],
  "lastError": {
    "file": "refactored-module.ts",
    "line": 234,
    "error_type": "typescript",
    "error_code": "TS2345",
    "message": "Argument of type 'ComplexType<A>' is not assignable to parameter of type 'ComplexType<B>'",
    "attempted_fixes": [
      "Type assertion to ComplexType<B>",
      "Extended interface to include both A and B",
      "Generic type parameter",
      "Union type ComplexType<A | B>",
      "Intersection type ComplexType<A & B>"
    ]
  },
  "commits": [
    {"sha": "abc123", "author": "User", "timestamp": "2026-01-25T13:00:00Z", "type": "refactor", "message": "complex type system refactor"}
    // No auto-fix commits (all failed)
  ],
  "executionTime": {
    "total": "28m 17s"
  },
  "manualInterventionRequired": true,
  "recommendation": "Complex type incompatibility requires architectural review. Suggest: 1) Review type hierarchy design, 2) Consult error-fixing-strategies.md, 3) Manual fix with detailed type analysis"
}
```

**Result:** Max iterations reached, manual intervention required. Error too complex for automated fixing.

---

### Example 5: Complex PR with TOON Optimization

**User Task:** "Создать PR из feature/major-refactor в test"

**Input:**
```json
{
  "sourceBranch": "feature/major-refactor",
  "targetBranch": "test",
  "autoFix": true
}
```

**Workflow:**

1. **PHASE 2:** Created draft PR #416

2. **PHASE 3-4:** Multiple iterations fixing 15 errors across 8 CI/CD checks

3. **PHASE 5:** All checks passed, TOON optimization triggered (>= 5 elements)

**Output (with TOON):**
```json
{
  "success": true,
  "prNumber": 416,
  "prUrl": "https://github.com/user/repo/pull/416",
  "finalStatus": "all_checks_passed",
  "checksStatus": {
    "total": 8,
    "passed": 8,
    "failed": 0
  },
  "checks": [
    {"name": "TypeScript Type Check", "status": "success", "duration_ms": 45000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/417"},
    {"name": "ESLint & Prettier", "status": "success", "duration_ms": 28000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/418"},
    {"name": "Unit Tests (Vitest)", "status": "success", "duration_ms": 67000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/419"},
    {"name": "Integration Tests", "status": "success", "duration_ms": 89000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/420"},
    {"name": "Build Verification", "status": "success", "duration_ms": 120000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/421"},
    {"name": "E2E Tests (Cypress)", "status": "success", "duration_ms": 180000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/422"},
    {"name": "Security Scan", "status": "success", "duration_ms": 45000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/423"},
    {"name": "Deploy Preview", "status": "success", "duration_ms": 90000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/424"}
  ],
  "fixIterations": 4,
  "autoFixedErrors": [
    {"file": "src/components/Form.tsx", "line": 45, "error_type": "typescript", "error_code": "TS2322", "message": "Type mismatch", "fix_applied": "Added type guard", "commit_sha": "aaa111"},
    {"file": "src/utils/validation.ts", "line": 89, "error_type": "typescript", "error_code": "TS2304", "message": "Cannot find name", "fix_applied": "Added import", "commit_sha": "bbb222"},
    {"file": "src/api/transactions.ts", "line": 123, "error_type": "eslint", "error_code": "no-unused-vars", "message": "Variable unused", "fix_applied": "Removed unused", "commit_sha": "ccc333"},
    {"file": "src/components/Filter.tsx", "line": 67, "error_type": "typescript", "error_code": "TS2345", "message": "Argument type error", "fix_applied": "Added conversion", "commit_sha": "ddd444"},
    {"file": "tests/integration/api.test.ts", "line": 234, "error_type": "vitest", "error_code": "assertion-failure", "message": "Expected 200 got 404", "fix_applied": "Fixed mock path", "commit_sha": "eee555"},
    {"file": "src/services/email.ts", "line": 156, "error_type": "typescript", "error_code": "TS2531", "message": "Object possibly null", "fix_applied": "Added null check", "commit_sha": "fff666"},
    {"file": "src/components/Dashboard.tsx", "line": 78, "error_type": "eslint", "error_code": "no-console", "message": "Unexpected console", "fix_applied": "Removed console.log", "commit_sha": "ggg777"},
    {"file": "src/hooks/useData.ts", "line": 45, "error_type": "typescript", "error_code": "TS2532", "message": "Object possibly undefined", "fix_applied": "Added default value", "commit_sha": "hhh888"},
    {"file": "src/utils/format.ts", "line": 23, "error_type": "prettier", "error_code": "formatting", "message": "Line too long", "fix_applied": "Reformatted", "commit_sha": "iii999"},
    {"file": "tests/unit/validation.test.ts", "line": 89, "error_type": "vitest", "error_code": "mock-error", "message": "Mock not called", "fix_applied": "Fixed mock timing", "commit_sha": "jjj000"},
    {"file": "src/api/auth.ts", "line": 167, "error_type": "typescript", "error_code": "TS2345", "message": "Type Promise not assignable", "fix_applied": "Added await", "commit_sha": "kkk111"},
    {"file": "src/components/Profile.tsx", "line": 201, "error_type": "eslint", "error_code": "no-unused-vars", "message": "Import not used", "fix_applied": "Removed import", "commit_sha": "lll222"},
    {"file": "src/types/transaction.ts", "line": 34, "error_type": "typescript", "error_code": "TS2304", "message": "Cannot find TransactionType", "fix_applied": "Added enum import", "commit_sha": "mmm333"},
    {"file": "src/utils/date.ts", "line": 78, "error_type": "eslint", "error_code": "no-implicit-coercion", "message": "Use Number constructor", "fix_applied": "Changed +value to Number(value)", "commit_sha": "nnn444"},
    {"file": "build/webpack.config.js", "line": 123, "error_type": "build-error", "error_code": "module-not-found", "message": "Module css-loader not found", "fix_applied": "Added css-loader to package.json", "commit_sha": "ooo555"}
  ],
  "commits": [
    {"sha": "abc123", "author": "User", "timestamp": "2026-01-25T14:00:00Z", "type": "refactor", "message": "major codebase refactoring"},
    {"sha": "aaa111", "author": "Claude Code", "timestamp": "2026-01-25T14:10:00Z", "type": "fix", "message": "resolve TS2322 type mismatch"},
    {"sha": "bbb222", "author": "Claude Code", "timestamp": "2026-01-25T14:15:00Z", "type": "fix", "message": "add missing import"},
    {"sha": "ccc333", "author": "Claude Code", "timestamp": "2026-01-25T14:20:00Z", "type": "refactor", "message": "remove unused variable"},
    {"sha": "ddd444", "author": "Claude Code", "timestamp": "2026-01-25T14:25:00Z", "type": "fix", "message": "add type conversion"},
    {"sha": "eee555", "author": "Claude Code", "timestamp": "2026-01-25T14:30:00Z", "type": "test", "message": "fix mock API endpoint"},
    {"sha": "fff666", "author": "Claude Code", "timestamp": "2026-01-25T14:35:00Z", "type": "fix", "message": "add null check"},
    {"sha": "ggg777", "author": "Claude Code", "timestamp": "2026-01-25T14:40:00Z", "type": "chore", "message": "remove debug console.log"},
    {"sha": "hhh888", "author": "Claude Code", "timestamp": "2026-01-25T14:45:00Z", "type": "fix", "message": "add default value"},
    {"sha": "iii999", "author": "Claude Code", "timestamp": "2026-01-25T14:50:00Z", "type": "style", "message": "reformat long line"},
    {"sha": "jjj000", "author": "Claude Code", "timestamp": "2026-01-25T14:55:00Z", "type": "test", "message": "fix mock timing"},
    {"sha": "kkk111", "author": "Claude Code", "timestamp": "2026-01-25T15:00:00Z", "type": "fix", "message": "add missing await"},
    {"sha": "lll222", "author": "Claude Code", "timestamp": "2026-01-25T15:05:00Z", "type": "refactor", "message": "remove unused import"},
    {"sha": "mmm333", "author": "Claude Code", "timestamp": "2026-01-25T15:10:00Z", "type": "fix", "message": "add enum import"},
    {"sha": "nnn444", "author": "Claude Code", "timestamp": "2026-01-25T15:15:00Z", "type": "refactor", "message": "use Number constructor"},
    {"sha": "ooo555", "author": "Claude Code", "timestamp": "2026-01-25T15:20:00Z", "type": "build", "message": "add css-loader dependency"}
  ],
  "executionTime": {
    "total": "42m 18s"
  },
  "toon": {
    "checks_toon": "checks[8]{name,status,duration_ms,conclusion,details_url}:\n  TypeScript Type Check,success,45000,success,https://github.com/user/repo/actions/runs/417\n  ESLint & Prettier,success,28000,success,https://github.com/user/repo/actions/runs/418\n  Unit Tests (Vitest),success,67000,success,https://github.com/user/repo/actions/runs/419\n  Integration Tests,success,89000,success,https://github.com/user/repo/actions/runs/420\n  Build Verification,success,120000,success,https://github.com/user/repo/actions/runs/421\n  E2E Tests (Cypress),success,180000,success,https://github.com/user/repo/actions/runs/422\n  Security Scan,success,45000,success,https://github.com/user/repo/actions/runs/423\n  Deploy Preview,success,90000,success,https://github.com/user/repo/actions/runs/424",
    "autoFixedErrors_toon": "autoFixedErrors[15]{file,line,error_type,error_code,message,fix_applied,commit_sha}:\n  src/components/Form.tsx,45,typescript,TS2322,Type mismatch,Added type guard,aaa111\n  src/utils/validation.ts,89,typescript,TS2304,Cannot find name,Added import,bbb222\n  src/api/transactions.ts,123,eslint,no-unused-vars,Variable unused,Removed unused,ccc333\n  src/components/Filter.tsx,67,typescript,TS2345,Argument type error,Added conversion,ddd444\n  tests/integration/api.test.ts,234,vitest,assertion-failure,Expected 200 got 404,Fixed mock path,eee555\n  src/services/email.ts,156,typescript,TS2531,Object possibly null,Added null check,fff666\n  src/components/Dashboard.tsx,78,eslint,no-console,Unexpected console,Removed console.log,ggg777\n  src/hooks/useData.ts,45,typescript,TS2532,Object possibly undefined,Added default value,hhh888\n  src/utils/format.ts,23,prettier,formatting,Line too long,Reformatted,iii999\n  tests/unit/validation.test.ts,89,vitest,mock-error,Mock not called,Fixed mock timing,jjj000\n  src/api/auth.ts,167,typescript,TS2345,Type Promise not assignable,Added await,kkk111\n  src/components/Profile.tsx,201,eslint,no-unused-vars,Import not used,Removed import,lll222\n  src/types/transaction.ts,34,typescript,TS2304,Cannot find TransactionType,Added enum import,mmm333\n  src/utils/date.ts,78,eslint,no-implicit-coercion,Use Number constructor,Changed +value to Number(value),nnn444\n  build/webpack.config.js,123,build-error,module-not-found,Module css-loader not found,Added css-loader to package.json,ooo555",
    "commits_toon": "commits[16]{sha,author,timestamp,type,message}:\n  abc123,User,2026-01-25T14:00:00Z,refactor,major codebase refactoring\n  aaa111,Claude Code,2026-01-25T14:10:00Z,fix,resolve TS2322 type mismatch\n  bbb222,Claude Code,2026-01-25T14:15:00Z,fix,add missing import\n  ccc333,Claude Code,2026-01-25T14:20:00Z,refactor,remove unused variable\n  ddd444,Claude Code,2026-01-25T14:25:00Z,fix,add type conversion\n  eee555,Claude Code,2026-01-25T14:30:00Z,test,fix mock API endpoint\n  fff666,Claude Code,2026-01-25T14:35:00Z,fix,add null check\n  ggg777,Claude Code,2026-01-25T14:40:00Z,chore,remove debug console.log\n  hhh888,Claude Code,2026-01-25T14:45:00Z,fix,add default value\n  iii999,Claude Code,2026-01-25T14:50:00Z,style,reformat long line\n  jjj000,Claude Code,2026-01-25T14:55:00Z,test,fix mock timing\n  kkk111,Claude Code,2026-01-25T15:00:00Z,fix,add missing await\n  lll222,Claude Code,2026-01-25T15:05:00Z,refactor,remove unused import\n  mmm333,Claude Code,2026-01-25T15:10:00Z,fix,add enum import\n  nnn444,Claude Code,2026-01-25T15:15:00Z,refactor,use Number constructor\n  ooo555,Claude Code,2026-01-25T15:20:00Z,build,add css-loader dependency",
    "token_savings": "40.2%",
    "size_comparison": "JSON: 5800 tokens, TOON: 3468 tokens"
  }
}
```

**Result:** Complex PR with 8 checks, 15 auto-fixes, 16 commits. TOON optimization saved 40.2% tokens (2332 tokens saved).

---

### Example 6: PR to Production (Stricter Checks)

**User Task:** "Открыть PR из feature/user-auth в prod"

**Input:**
```json
{
  "sourceBranch": "feature/user-auth",
  "targetBranch": "prod",
  "autoFix": true
}
```

**Workflow:**

1. **PHASE 0A: Auto-detect Stack**
   - Detected: TypeScript + Vite
   - Target: **prod** → Additional checks enabled:
     - Security scan (SAST)
     - Dependency vulnerability check
     - Code coverage threshold (80%)
     - Performance benchmarks

2. **PHASE 2:** Created draft PR #417

3. **PHASE 3:** 7 checks (4 standard + 3 production-specific)

4. **PHASE 4:** Fixed 2 ESLint warnings, 1 security finding (hardcoded API key → env variable)

5. **PHASE 5:** All checks passed, ready for production

**Output:**
```json
{
  "success": true,
  "prNumber": 417,
  "prUrl": "https://github.com/user/repo/pull/417",
  "finalStatus": "all_checks_passed",
  "targetBranch": "prod",
  "checksStatus": {
    "total": 7,
    "passed": 7,
    "failed": 0
  },
  "checks": [
    {"name": "TypeScript Type Check", "status": "success", "duration_ms": 48000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/425"},
    {"name": "ESLint & Prettier", "status": "success", "duration_ms": 30000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/426"},
    {"name": "Vitest Tests (Coverage 80%)", "status": "success", "duration_ms": 70000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/427"},
    {"name": "Build Verification", "status": "success", "duration_ms": 125000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/428"},
    {"name": "Security Scan (SAST)", "status": "success", "duration_ms": 95000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/429"},
    {"name": "Dependency Vulnerabilities", "status": "success", "duration_ms": 55000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/430"},
    {"name": "Performance Benchmarks", "status": "success", "duration_ms": 110000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/431"}
  ],
  "fixIterations": 2,
  "autoFixedErrors": [
    {
      "file": "src/config/api.ts",
      "line": 12,
      "error_type": "security",
      "error_code": "hardcoded-secret",
      "message": "Hardcoded API key detected",
      "fix_applied": "Replaced with process.env.API_KEY",
      "commit_sha": "sec111"
    },
    {
      "file": "src/utils/logger.ts",
      "line": 45,
      "error_type": "eslint",
      "error_code": "no-console",
      "message": "Unexpected console.warn",
      "fix_applied": "Replaced with winston logger",
      "commit_sha": "log222"
    }
  ],
  "commits": [
    {"sha": "abc123", "author": "User", "timestamp": "2026-01-25T16:00:00Z", "type": "feat", "message": "add user authentication"},
    {"sha": "sec111", "author": "Claude Code", "timestamp": "2026-01-25T16:12:00Z", "type": "security", "message": "replace hardcoded API key with env variable"},
    {"sha": "log222", "author": "Claude Code", "timestamp": "2026-01-25T16:18:00Z", "type": "refactor", "message": "replace console.warn with winston logger"}
  ],
  "executionTime": {
    "total": "18m 55s"
  },
  "productionReadiness": {
    "securityScanPassed": true,
    "codeCoverage": "85%",
    "performanceBenchmarks": "All within thresholds"
  }
}
```

**Result:** PR to production with stricter checks (7 total), including security scan. 2 auto-fixes applied (security + logging), ready for production deployment.

---

### Example 7: CI Timeout Recovery

**User Task:** "Создать PR из feature/heavy-feature в test"

**Input:**
```json
{
  "sourceBranch": "feature/heavy-feature",
  "targetBranch": "test",
  "autoFix": true
}
```

**Workflow:**

1. **PHASE 2:** Created draft PR #418

2. **PHASE 3: CI/CD Monitoring**
   - First run: E2E tests stuck in "pending" for 10+ minutes
   - Detection: No progress in check status for 8 minutes
   - Action: Cancelled stuck workflow via `gh run cancel <run-id>`
   - Re-triggered: `gh workflow run e2e-tests.yml`

3. **PHASE 3 (retry):** Second run completed successfully

4. **PHASE 5:** All checks passed

**Output:**
```json
{
  "success": true,
  "prNumber": 418,
  "prUrl": "https://github.com/user/repo/pull/418",
  "finalStatus": "all_checks_passed",
  "checksStatus": {
    "total": 4,
    "passed": 4,
    "failed": 0
  },
  "checks": [
    {"name": "TypeScript Type Check", "status": "success", "duration_ms": 47000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/432"},
    {"name": "ESLint", "status": "success", "duration_ms": 29000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/433"},
    {"name": "Vitest Tests", "status": "success", "duration_ms": 68000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/434"},
    {"name": "E2E Tests (Cypress)", "status": "success", "duration_ms": 195000, "conclusion": "success", "details_url": "https://github.com/user/repo/actions/runs/436"}
  ],
  "fixIterations": 0,
  "autoFixedErrors": [],
  "commits": [
    {"sha": "abc123", "author": "User", "timestamp": "2026-01-25T17:00:00Z", "type": "feat", "message": "add heavy feature with E2E tests"}
  ],
  "executionTime": {
    "total": "22m 34s"
  },
  "cicdRecovery": {
    "timeoutDetected": true,
    "cancelledRuns": [
      {"run_id": 435, "reason": "Stuck in pending for 10+ minutes", "cancelled_at": "2026-01-25T17:12:00Z"}
    ],
    "retriggeredWorkflows": [
      {"workflow": "e2e-tests.yml", "retriggered_at": "2026-01-25T17:13:00Z", "run_id": 436}
    ],
    "finalOutcome": "success"
  }
}
```

**Result:** CI timeout detected and recovered. Cancelled stuck E2E test run, re-triggered successfully. All checks passed on retry.

---

## Files Structure

```
pr-automation/
├── SKILL.md                        # Этот файл
├── templates/
│   ├── error-patterns.json         # Regex patterns для ошибок
│   ├── pr-input.json               # Input schema
│   ├── pr-output.json              # Output schema
│   └── pr-description.md.mustache  # PR description template
├── schemas/
│   └── pr-workflow.schema.json     # Workflow validation
├── rules/
│   ├── pr-best-practices.md        # GitHub PR conventions
│   ├── error-fixing-strategies.md  # Как исправлять ошибки
│   ├── commit-guidelines.md        # Conventional Commits
│   └── error-fixing-strategies.md  # Error fixing strategies
└── examples/
    ├── pr-creation-flow.md         # Full example
    └── error-fixing-scenarios.md   # Common scenarios
```

---

## Зависимости

**External:**
- gh CLI v2.45.0+ (в `.nvm-isolated/`)
- jq (JSON parsing)
- yq (YAML parsing для auto-detect)
- git 2.0+

**External Tools:**
- Loop mode (./iclaude.sh --loop) для iterative error fixing
- git-workflow (для commit formatting)

**Skills:**
- code-review (опционально, для post-fix review)

---

## References

- Git conventions: `@shared:GIT-CONVENTIONS.md`
- TOON format: `@shared:TOON-REFERENCE.md`
- Task structure: `@shared:TASK-STRUCTURE.md`
- [Loop Mode Documentation](../../CLAUDE.md#loop-mode-commands)
- [GitHub CLI](https://cli.github.com/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Actions](https://docs.github.com/en/actions)

---

🤖 Generated with Claude Code

**Author:** ikeniborn
**License:** MIT
