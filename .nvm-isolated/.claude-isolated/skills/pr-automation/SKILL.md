---
name: pr-automation
description: Автоматизация создания PR с мониторингом CI/CD и авто-исправлением через ralph-loop
version: 1.1.0
author: ikeniborn
tags: [github, pr, ci/cd, automation, ralph-loop, github-actions, typescript, eslint, toon]
dependencies: [ralph-loop, git-workflow, code-review, toon-skill]
triggers:
  - "создать pr"
  - "создать pull request"
  - "сделать pr"
  - "открыть pull request"
user-invocable: true
changelog:
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
      - "Ralph-loop integration"
      - "Auto-detection stack & CI/CD"
---

# PR Automation Skill

Автоматизирует полный workflow создания Pull Request с мониторингом CI/CD и автоматическим исправлением ошибок через ralph-loop plugin.

## Возможности

- ✅ **Auto-detection** стека и CI/CD из `/docs/architecture`
- ✅ **Draft PR creation** с auto-generated описанием
- ✅ **Real-time CI/CD monitoring** через GitHub Actions
- ✅ **Автоматическое исправление** 4 типов ошибок:
  - TypeScript (TS2322, TS2304, TS2345, TS2531, TS2532)
  - ESLint/Prettier (no-console, no-unused-vars)
  - Vitest тесты (assertion failures, mock issues)
  - Build errors (module not found, syntax errors)
- ✅ **Ralph-loop integration** для итеративных фиксов
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

### 2. Ralph-loop Plugin

Должен быть установлен в Claude Code.

### 3. Git Workflow

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

3. **Вызов ralph-loop:**
```bash
/ralph-loop "Fix TypeScript error TS2322 in transactionForm.ts:45" \
  --context "File: transactionForm.ts, Line: 45, PR: 312" \
  --completion-promise "gh pr checks 312 shows all ✓" \
  --max-iterations 5
```

4. **Ralph-loop workflow:**
   - Читает файл с ошибкой
   - Применяет fix из `rules/error-fixing-strategies.md`
   - Коммитит (формат из `rules/commit-guidelines.md`)
   - Пушит в branch
   - Ждёт re-run checks
   - Проверяет completion promise

5. **Повторить** пока все checks не пройдут или max iterations

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

## Ralph-Loop Integration

### Completion Promise

**Primary:**
```
All GitHub Actions checks pass
```

**Verification:**
```bash
gh pr checks <pr-number> | grep -E "✓|success" | wc -l
# Expected: number of required checks
```

### Max Iterations

**Default:** 5 iterations

**Typical scenarios:**
- 1 iteration: Simple fixes (type conversion, remove console.log)
- 2-3 iterations: Multiple errors fixed sequentially
- 5 iterations: Max reached → manual intervention needed

---

## Output Format

**JSON Schema:** `schemas/pr-workflow.schema.json`

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
- Use Conventional Commits format
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

**Symptom:** Ralph-loop изменил не тот файл

**Причина:** Ambiguous error context

**Действия:**
1. Revert commit: `git revert HEAD`
2. Push revert
3. Предоставить более точный контекст для ralph-loop

---

## Examples

См. `examples/`:
- `pr-creation-flow.md` - Полный end-to-end пример
- `error-fixing-scenarios.md` - Типичные сценарии ошибок

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
│   └── ralph-loop-integration.md   # Completion promises
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

**Plugins:**
- ralph-loop (для automatic error fixing)
- git-workflow (для commit formatting)

**Skills:**
- code-review (опционально, для post-fix review)

---

## Version History

**1.0.0** (2026-01-13):
- Initial release
- PHASE 0A: Auto-detection stack & CI/CD
- Support for 4 error types
- Ralph-loop integration
- Draft PR workflow

---

## TOON Format Support

**NEW in v1.1.0:** Автоматическая генерация TOON format для token-efficient PR workflow reporting

### Когда генерируется TOON

Skill автоматически генерирует TOON format когда:
- `checks.length >= 5` ИЛИ
- `autoFixedErrors.length >= 5` ИЛИ
- `commits.length >= 5`

### Token Savings

**Типичная экономия:**
- 8 CI/CD checks: **38% token reduction**
- 15 auto-fixed errors: **40% token reduction**
- 12 commits: **35% token reduction**
- Combined (checks + errors + commits): **35-45% total savings**

### Output Structure (Hybrid JSON + TOON)

```json
{
  "success": true,
  "prNumber": 312,
  "prUrl": "https://github.com/user/repo/pull/312",
  "finalStatus": "all_checks_passed",
  "checksStatus": {
    "total": 8,
    "passed": 8,
    "failed": 0
  },
  "checks": [...],            // JSON (всегда присутствует)
  "fixIterations": 2,
  "autoFixedErrors": [...],   // JSON (всегда присутствует)
  "commits": [...],           // JSON (всегда присутствует)
  "executionTime": {
    "total": "8m 34s"
  },
  "toon": {                   // TOON (опционально, если >= 5 элементов)
    "checks_toon": "checks[8]{name,status,duration_ms,conclusion,details_url}:\n  TypeScript Type Check,success,45000,success,https://github.com/user/repo/actions/runs/123\n  ESLint & Prettier,success,28000,success,https://github.com/user/repo/actions/runs/124\n  Unit Tests (Vitest),success,67000,success,https://github.com/user/repo/actions/runs/125\n  Integration Tests,success,89000,success,https://github.com/user/repo/actions/runs/126\n  Build Verification,success,120000,success,https://github.com/user/repo/actions/runs/127\n  E2E Tests (Cypress),success,180000,success,https://github.com/user/repo/actions/runs/128\n  Security Scan,success,45000,success,https://github.com/user/repo/actions/runs/129\n  Deploy Preview,success,90000,success,https://github.com/user/repo/actions/runs/130",
    "autoFixedErrors_toon": "autoFixedErrors[15]{file,line,error_type,error_code,message,fix_applied,commit_sha}:\n  src/components/TransactionForm.tsx,45,typescript,TS2322,Type 'string | undefined' is not assignable to type 'string',Added type guard: if (value !== undefined),abc123\n  src/utils/validation.ts,89,typescript,TS2304,Cannot find name 'ValidationError',Added import: import { ValidationError } from './types',def456\n  src/api/transactions.ts,123,eslint,no-unused-vars,Variable 'oldApi' is defined but never used,Removed unused variable,ghi789\n  src/components/FilterPanel.tsx,67,typescript,TS2345,Argument of type 'number' is not assignable to parameter of type 'string',Added toString() conversion,jkl012\n  tests/integration/api.test.ts,234,vitest,assertion-failure,Expected 200 but received 404,Fixed mock API endpoint path,mno345\n  src/services/email.ts,156,typescript,TS2531,Object is possibly 'null',Added null check with optional chaining,pqr678\n  src/components/Dashboard.tsx,78,eslint,no-console,Unexpected console.log statement,Removed debug console.log,stu901\n  src/hooks/useTransactions.ts,45,typescript,TS2532,Object is possibly 'undefined',Added default value in destructuring,vwx234\n  src/utils/formatting.ts,23,prettier,formatting,Line exceeds 80 characters,Reformatted long line,yza567\n  tests/unit/validation.test.ts,89,vitest,mock-error,Mock function not called,Fixed mock setup timing issue,bcd890\n  src/api/auth.ts,167,typescript,TS2345,Type 'Promise<User>' is not assignable to type 'User',Added await keyword,efg123\n  src/components/UserProfile.tsx,201,eslint,no-unused-vars,Imported 'useState' is not used,Removed unused import,hij456\n  src/types/transaction.ts,34,typescript,TS2304,Cannot find name 'TransactionType',Added enum import from constants,klm789\n  src/utils/date.ts,78,eslint,no-implicit-coercion,Use the Number constructor instead of unary plus,Changed +value to Number(value),nop012\n  build/webpack.config.js,123,build-error,module-not-found,Module 'css-loader' not found,Added css-loader to package.json,qrs345",
    "commits_toon": "commits[12]{sha,author,timestamp,type,message}:\n  abc123,Claude Code,2026-01-23T10:15:30Z,fix,resolve TS2322 type mismatch in TransactionForm\n  def456,Claude Code,2026-01-23T10:18:45Z,fix,add missing ValidationError import\n  ghi789,Claude Code,2026-01-23T10:22:10Z,refactor,remove unused oldApi variable\n  jkl012,Claude Code,2026-01-23T10:25:30Z,fix,convert number to string in FilterPanel\n  mno345,Claude Code,2026-01-23T10:28:50Z,test,fix API mock endpoint path in integration test\n  pqr678,Claude Code,2026-01-23T10:32:15Z,fix,add null check for email service\n  stu901,Claude Code,2026-01-23T10:35:40Z,chore,remove debug console.log from Dashboard\n  vwx234,Claude Code,2026-01-23T10:39:05Z,fix,add default value in useTransactions hook\n  yza567,Claude Code,2026-01-23T10:42:30Z,style,reformat long line in formatting.ts\n  bcd890,Claude Code,2026-01-23T10:45:55Z,test,fix mock timing in validation test\n  efg123,Claude Code,2026-01-23T10:49:20Z,fix,add missing await in auth API call\n  hij456,Claude Code,2026-01-23T10:52:45Z,refactor,remove unused useState import",
    "token_savings": "40.2%",
    "size_comparison": "JSON: 5800 tokens, TOON: 3468 tokens"
  }
}
```

### Benefits

- **Backward Compatible**: JSON output неизменён (primary format)
- **Opt-in Optimization**: TOON добавляется только когда выгодно (>= 5 элементов)
- **Zero Breaking Changes**: Downstream consumers читают JSON как раньше
- **Token Efficient**: 35-45% savings для PR с множественными checks/fixes
- **Complete Audit Trail**: TOON сохраняет полную историю fixes и commits

### Integration with Other Skills

**Producers (pr-automation):**
```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Generate JSON output (always)
const prResult = {
  success: true,
  prNumber: 312,
  prUrl: "...",
  checks: [...],           // 8 checks
  autoFixedErrors: [...],  // 15 errors
  commits: [...]           // 12 commits
};

// Add TOON optimization (if threshold met)
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

if (prResult.toon) {
  const stats = calculateTokenSavings(dataToConvert);
  prResult.toon.token_savings = stats.savedPercent;
  prResult.toon.size_comparison = `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`;
}

return prResult;
```

**Consumers (reporting tools, dashboards):**
```javascript
import { toonToJson } from '../toon-skill/converters/toon-converter.mjs';

// Always read JSON (safest, backward compatible)
const checks = prResult.checks;
const autoFixedErrors = prResult.autoFixedErrors;

// Or prefer TOON if available (token efficient)
const checks = prResult.toon?.checks_toon
  ? toonToJson(prResult.toon.checks_toon).checks
  : prResult.checks;
```

### Token Savings Examples

**Example 1: Standard PR (8 checks, 15 errors, 12 commits)**
- JSON: 5800 tokens
- TOON: 3468 tokens
- **Savings: 40.2% (2332 tokens saved)**

**Example 2: Complex PR (12 checks, 30 errors, 25 commits)**
- JSON: 9200 tokens
- TOON: 5336 tokens
- **Savings: 42% (3864 tokens saved)**

**Example 3: Simple PR (3 checks, 2 errors, 4 commits)**
- JSON only: 1450 tokens
- No TOON generation (below threshold)

### Use Cases

**1. CI/CD Monitoring:**
- Track check execution times across PRs
- Identify slow or failing checks
- Optimize CI/CD pipeline based on patterns

**2. Auto-Fix Analysis:**
- Analyze most common error types (TS2322 vs ESLint)
- Track ralph-loop fix success rates
- Identify recurring error patterns in codebase

**3. Commit History:**
- Review auto-generated commits for quality
- Track commit message patterns
- Ensure Conventional Commits compliance

**4. PR Metrics Dashboard:**
- Aggregate TOON data across multiple PRs
- Generate reports on PR workflow efficiency
- Identify bottlenecks in CI/CD or auto-fix process

### See Also

- **toon-skill** - Базовый навык для TOON API ([../toon-skill/SKILL.md](../toon-skill/SKILL.md))
- **TOON-PATTERNS.md** - Integration patterns ([../_shared/TOON-PATTERNS.md](../_shared/TOON-PATTERNS.md))
- **git-workflow** - Commit message formatting ([../git-workflow/SKILL.md](../git-workflow/SKILL.md))
- **ralph-loop** - Auto-fix plugin ([https://github.com/anthropics/ralph-loop](https://github.com/anthropics/ralph-loop))

---

## References

- [Ralph-Loop Plugin](https://github.com/anthropics/ralph-loop)
- [GitHub CLI](https://cli.github.com/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Actions](https://docs.github.com/en/actions)

---

🤖 Generated with Claude Code

**Author:** ikeniborn
**License:** MIT
