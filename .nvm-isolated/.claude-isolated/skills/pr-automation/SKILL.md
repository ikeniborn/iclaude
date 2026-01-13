---
name: pr-automation
description: Автоматизация создания PR с мониторингом CI/CD и авто-исправлением через ralph-loop
version: 1.0.0
author: ikeniborn
tags: [github, pr, ci/cd, automation, ralph-loop, github-actions, typescript, eslint]
dependencies: [ralph-loop, git-workflow, code-review]
triggers:
  - "создать pr"
  - "создать pull request"
  - "сделать pr"
  - "открыть pull request"
user-invocable: true
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

## References

- [Ralph-Loop Plugin](https://github.com/anthropics/ralph-loop)
- [GitHub CLI](https://cli.github.com/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Actions](https://docs.github.com/en/actions)

---

🤖 Generated with Claude Code

**Author:** ikeniborn
**License:** MIT
