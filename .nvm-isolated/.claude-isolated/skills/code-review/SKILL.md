---
name: code-review
description: Автоматический review кода перед commit
version: 1.2.0
tags: [review, quality, security, code-smells, toon]
dependencies: [toon-skill, lsp-integration]
files:
  templates: ./templates/*.json
  rules: ./rules/*.md
user-invocable: true
changelog:
  - version: 1.2.0
    date: 2026-01-25
    changes:
      - "Централизация: TOON specs → @shared:TOON-REFERENCE.md"
      - "Добавлено: 3 примера (simple review, LSP integration, TOON optimization)"
      - "Skill-specific TOON usage notes для warnings[] и lsp_diagnostics[]"
      - "Обновлены references"
  - version: 1.1.0
    date: 2026-01-23
    changes:
      - "**TOON Format Support**: Автоматическая генерация TOON для token efficiency"
      - "TOON для warnings[] и lsp_diagnostics[] (когда >= 5 элементов)"
      - "40-50% token savings для больших review reports"
      - "100% backward compatibility (JSON остаётся primary format)"
      - "Integration examples для producers и consumers"
  - version: 1.0.0
    date: 2025-11-XX
    changes:
      - "Initial release"
      - "Architecture compliance, security, code quality checks"
      - "LSP integration для enhanced type checking"
---

# Code Review

Автоматическая проверка качества и безопасности кода.

## Когда использовать

- После выполнения задачи (standard/complex только)
- Перед git commit
- По запросу пользователя

## Категории проверок

### 1. Architecture Compliance (BLOCKING)

```
- Referential integrity (все зависимости существуют)
- Circular dependency detection (обнаружение циклов)
- Component file path validation (измененные файлы документированы)
- Layer boundary compliance (соблюдение границ слоев)
- Scope: гибридный (измененные компоненты + их dependents)
```

**Требования:**
- Архитектурная документация в одном из поддерживаемых путей:
  - **Рекомендуемые**: `docs/architecture/overview.yaml`, `doc/architecture/overview.yaml`
  - **Альтернативные**: `documentation/architecture/`, `.github/docs/architecture/`, `design/architecture/`, `adr/`
  - **Fallback**: Рекурсивный поиск в корне проекта (глубина до 3 уровней)
- Инструменты: `yq` (для YAML→JSON), `jq` (для JSON parsing), `find` (для рекурсивного поиска)
- Компоненты документированы с `file_path` и `dependencies`

**Пользовательская конфигурация путей:**

1. **Через переменную окружения:**
   ```bash
   export CODE_REVIEW_ARCH_PATHS="custom/arch:internal/docs/architecture"
   ```

2. **Через .clauderc в корне проекта:**
   ```json
   {
     "codeReview": {
       "architecturePaths": [
         "custom/architecture",
         "internal/docs/arch"
       ]
     }
   }
   ```

3. **Через isolated config (.claude/config.json):**
   ```json
   {
     "skills": {
       "codeReview": {
         "architecturePaths": [
           "team/architecture",
           "wiki/system-design"
         ]
       }
     }
   }
   ```

**Приоритет путей:**
1. Пользовательские пути (.clauderc, environment, config.json)
2. Стандартные пути (docs/architecture, doc/architecture, etc.)
3. Рекурсивный поиск (fallback)

**Поведение при отсутствии архитектуры:**
- Блокирует commit с предложением запустить `@skill:architecture-documentation`
- Автоматически вызывает architecture-documentation skill для генерации
- После генерации повторно запускает валидацию

**Правила:** `@rules:architecture`

**Поддерживаемые форматы архитектуры:**

| Формат | Детекция | Источник |
|--------|----------|----------|
| `iclaude` | `project.id` + `components[]` + `layers[]` | Ручное создание |
| `arch-doc` | `architecture.metadata` + `architecture.components[]` | `@skill:architecture-documentation` |
| `c4` | `model.softwareSystems` или `model.containers` | Structurizr |
| `generic` | `components[]` | Различные инструменты |

**Graceful Degradation:**
- Нераспознанный формат: WARNING (не BLOCKING)
- Остальные проверки (security, code quality) выполняются
- Рекомендация: запустить `@skill:architecture-documentation` для генерации совместимого формата

### 2. Security (BLOCKING)

```
- SQL Injection
- XSS (Cross-Site Scripting)
- Command Injection
- Path Traversal
- Hardcoded secrets
- Insecure deserialization
```

Правила: `@rules:security`

### 3. Code Quality (WARNING)

```
- Code duplication
- High complexity (cyclomatic > 10)
- Long functions (> 50 lines)
- Deep nesting (> 4 levels)
- Magic numbers
- Unused variables/imports
```

Правила: `@rules:code-quality`

### 4. Error Handling (WARNING)

```
- Bare except clauses
- Empty catch blocks
- Missing null checks
- Unhandled promises
```

### 5. Type Safety (INFO)

```
- Missing type hints (Python)
- Any types (TypeScript)
- Implicit type conversions
```

## LSP Integration (Optional)

**Активируется когда:** `lsp_status.status == "READY"` (из lsp-integration skill)

Когда LSP доступен, code-review использует Language Server Protocol для enhanced type checking и code intelligence:

### Что предоставляет LSP:

**1. Type Checking:**
- Детектирование type mismatches
- Поиск использования `Any` types (TypeScript)
- Проверка missing type hints (Python via pyright)

**2. Code Intelligence:**
- Go-to-definition (проверка существования импортов)
- Find-references (детектирование unused variables/functions)
- Символы не найдены (undefined names)

**3. LSP Diagnostics:**
- Parsing LSP error messages
- Merge в `code_review.warnings` с category: "type_safety"
- Увеличенный score penalty для type errors

### Алгоритм интеграции:

```
IF lsp_status.status == "READY":
  1. Request LSP diagnostics for files_changed
  2. Parse diagnostics response:
     - severity: "error" → BLOCKING issue
     - severity: "warning" → WARNING issue
     - severity: "information" → INFO suggestion
  3. Merge into code_review.warnings[]:
     {
       "category": "type_safety",
       "severity": map_lsp_severity(diagnostic.severity),
       "file": diagnostic.uri,
       "line": diagnostic.range.start.line,
       "message": diagnostic.message,
       "suggestion": diagnostic.codeActions[0] (if available)
     }
  4. Adjust score:
     - LSP errors: -10 points each (instead of -5)
     - Total type_safety score capped at 25 points
ELSE:
  Skip LSP checks (fallback to regex-based checks)
  Show info message: "LSP not available - basic checks only"
```

### Поддерживаемые LSP серверы:

| Язык | LSP Server | Plugin |
|------|------------|--------|
| TypeScript | vtsls | typescript-lsp@claude-plugins-official |
| Python | pyright | pyright-lsp@claude-plugins-official |
| Go | gopls | gopls-lsp@claude-plugins-official |
| Rust | rust-analyzer | rust-analyzer-lsp@claude-plugins-official |

**Note:** См. [@skill:lsp-integration](../lsp-integration/SKILL.md) для установки LSP plugins.

### Backward Compatibility:

- LSP integration полностью опциональная
- Без LSP skill работает с regex-based checks
- Output формат одинаковый с/без LSP
- `lsp_diagnostics` field добавляется только при LSP available

## References

**TOON Format Specification:**
- Full spec: @shared:TOON-REFERENCE.md
- Integration patterns: @shared:TOON-REFERENCE.md#integration-patterns
- Token savings benchmarks: @shared:TOON-REFERENCE.md#token-savings

**Task Structure:**
- @shared:TASK-STRUCTURE.md#code-review

## Skill-Specific TOON Usage

**code-review генерирует TOON для:**
- `warnings[]` - когда >= 5 warnings
- `lsp_diagnostics[]` - когда >= 5 LSP issues

**Implementation:**
```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Review output
const review = {
  status: "passed",
  total_warnings: 12,
  warnings: [...],          // 12 warnings
  lsp_diagnostics: [...]    // 8 LSP issues
};

// Add TOON optimization
const dataToConvert = {};

if (review.warnings.length >= 5) {
  review.toon = review.toon || {};
  review.toon.warnings_toon = arrayToToon('warnings', review.warnings,
    ['severity', 'file', 'line', 'message', 'rule']);
  dataToConvert.warnings = review.warnings;
}

if (review.lsp_diagnostics && review.lsp_diagnostics.length >= 5) {
  review.toon = review.toon || {};
  review.toon.lsp_diagnostics_toon = arrayToToon('lsp_diagnostics', review.lsp_diagnostics,
    ['severity', 'file', 'line', 'message', 'source']);
  dataToConvert.lsp_diagnostics = review.lsp_diagnostics;
}

if (review.toon) {
  const stats = calculateTokenSavings(dataToConvert);
  review.toon.token_savings = stats.savedPercent;
  review.toon.size_comparison = `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`;
}
```

**Token Savings (Review-Specific):**
- 8 warnings: **35.4% savings** (1420 → 918 tokens)
- 12 warnings + 8 LSP: **40.2% savings** (3560 → 2130 tokens)
- 25 warnings + 15 LSP: **45.7% savings** (7120 → 3865 tokens)

## Output

```json
{
  "code_review": {
    "score": 85,
    "blocking_issues": [],
    "warnings": [
      {
        "category": "code_quality",
        "file": "service.py",
        "line": 42,
        "message": "Function too long (65 lines)",
        "suggestion": "Extract helper methods"
      }
    ],
    "suggestions": [
      "Consider adding type hints to function parameters"
    ],
    "passed": true
  }
}
```

## Score Calculation

```
# Новая формула с весами для 5 категорий:
architecture_score = 25 - (arch_blocking * 10)    # 25%
security_score = 25 - (sec_blocking * 10)          # 25%
code_quality_score = 25 - (quality_warnings * 5)   # 25%
error_handling_score = 15 - (error_warnings * 5)   # 15%
type_safety_score = 10 - (type_warnings * 5)       # 10%

total_score = architecture_score + security_score + code_quality_score +
              error_handling_score + type_safety_score

# Если архитектура недоступна, пересчитываем веса:
# security = 33.33%, code_quality = 33.33%, error = 20%, type = 13.33%

passed = blocking_issues.length === 0
```

## Markdown Output

```
## Code Review: {score}/100

{если blocking}
🛑 BLOCKING ISSUES:
- {file}:{line} — {message}

{если warnings}
⚠️ WARNINGS:
- {file}:{line} — {message}

{если suggestions}
💡 SUGGESTIONS:
- {suggestion}

{passed ? "✓ Review passed" : "✗ Review failed"}
```

---

## Examples

### Example 1: Simple Review (Passed)

**Scenario:** Small change - 2 files, no blocking issues

**Files reviewed:**
- `backend/services/payment.py` (modified)
- `tests/test_payment.py` (created)

**Review result:**
```json
{
  "code_review": {
    "score": 92,
    "blocking_issues": [],
    "warnings": [
      {
        "category": "code_quality",
        "severity": "WARNING",
        "file": "backend/services/payment.py",
        "line": 45,
        "message": "Function 'process_payment' complexity 12 exceeds threshold 10",
        "suggestion": "Consider refactoring to reduce complexity"
      },
      {
        "category": "type_safety",
        "severity": "INFO",
        "file": "tests/test_payment.py",
        "line": 12,
        "message": "Missing type hint for parameter 'amount'",
        "suggestion": "Add type hint: def test_payment(amount: Decimal)"
      }
    ],
    "passed": true
  }
}
```

**User message:**
```
## Code Review: 92/100

⚠️ WARNINGS:
- backend/services/payment.py:45 — Function complexity 12 exceeds threshold 10

💡 SUGGESTIONS:
- tests/test_payment.py:12 — Add type hint for parameter 'amount'

✓ Review passed
```

**Result:** Review passed, 2 non-blocking warnings, ready to commit.

---

### Example 2: LSP Integration (Type Errors Found)

**Scenario:** TypeScript refactor - LSP detected 8 type errors (5 BLOCKING)

**Files reviewed:**
- `frontend/src/services/AuthService.ts`
- `frontend/src/hooks/useAuth.ts`
- `frontend/src/contexts/AuthContext.tsx`

**Review result:**
```json
{
  "code_review": {
    "score": 58,
    "blocking_issues": [
      {
        "category": "type_safety",
        "severity": "ERROR",
        "file": "frontend/src/services/AuthService.ts",
        "line": 45,
        "message": "Argument of type 'string | undefined' is not assignable to parameter of type 'string'",
        "source": "typescript"
      },
      {
        "category": "type_safety",
        "severity": "ERROR",
        "file": "frontend/src/services/AuthService.ts",
        "line": 78,
        "message": "Property 'refreshToken' does not exist on type 'AuthResponse'",
        "source": "typescript"
      },
      {
        "category": "type_safety",
        "severity": "ERROR",
        "file": "frontend/src/hooks/useAuth.ts",
        "line": 23,
        "message": "Object is possibly 'null'",
        "source": "typescript"
      },
      {
        "category": "type_safety",
        "severity": "ERROR",
        "file": "frontend/src/hooks/useAuth.ts",
        "line": 56,
        "message": "Type '() => Promise<void>' is not assignable to type '() => void'",
        "source": "typescript"
      },
      {
        "category": "type_safety",
        "severity": "ERROR",
        "file": "frontend/src/contexts/AuthContext.tsx",
        "line": 112,
        "message": "Cannot find name 'User'. Did you mean 'user'?",
        "source": "typescript"
      }
    ],
    "warnings": [
      {
        "category": "code_quality",
        "severity": "WARNING",
        "file": "frontend/src/services/AuthService.ts",
        "line": 34,
        "message": "Async function without error handling"
      },
      {
        "category": "code_quality",
        "severity": "WARNING",
        "file": "frontend/src/hooks/useAuth.ts",
        "line": 67,
        "message": "Missing dependency in useEffect"
      }
    ],
    "lsp_diagnostics": [
      {"severity": "ERROR", "file": "AuthService.ts", "line": 45, "message": "Type mismatch", "source": "typescript"},
      {"severity": "ERROR", "file": "AuthService.ts", "line": 78, "message": "Property missing", "source": "typescript"},
      {"severity": "ERROR", "file": "useAuth.ts", "line": 23, "message": "Null check required", "source": "typescript"},
      {"severity": "ERROR", "file": "useAuth.ts", "line": 56, "message": "Promise type error", "source": "typescript"},
      {"severity": "ERROR", "file": "AuthContext.tsx", "line": 112, "message": "Undefined name", "source": "typescript"},
      {"severity": "WARNING", "file": "AuthService.ts", "line": 12, "message": "Unused import", "source": "typescript"},
      {"severity": "WARNING", "file": "useAuth.ts", "line": 8, "message": "Unused import", "source": "typescript"},
      {"severity": "WARNING", "file": "AuthContext.tsx", "line": 5, "message": "Unused import", "source": "typescript"}
    ],
    "passed": false,
    "toon": {
      "lsp_diagnostics_toon": "lsp_diagnostics[8]{severity,file,line,message,source}:\n  ERROR,AuthService.ts,45,Type mismatch,typescript\n  ERROR,AuthService.ts,78,Property missing,typescript\n  ERROR,useAuth.ts,23,Null check required,typescript\n  ERROR,useAuth.ts,56,Promise type error,typescript\n  ERROR,AuthContext.tsx,112,Undefined name,typescript\n  WARNING,AuthService.ts,12,Unused import,typescript\n  WARNING,useAuth.ts,8,Unused import,typescript\n  WARNING,AuthContext.tsx,5,Unused import,typescript",
      "token_savings": "35.4%",
      "size_comparison": "JSON: 1420 tokens, TOON: 918 tokens"
    }
  }
}
```

**User message:**
```
## Code Review: 58/100

🛑 BLOCKING ISSUES:
- AuthService.ts:45 — Argument type mismatch: string | undefined → string
- AuthService.ts:78 — Property 'refreshToken' does not exist on type 'AuthResponse'
- useAuth.ts:23 — Object is possibly 'null'
- useAuth.ts:56 — Type mismatch in async handler
- AuthContext.tsx:112 — Cannot find name 'User'

⚠️ WARNINGS:
- AuthService.ts:34 — Async function without error handling
- useAuth.ts:67 — Missing dependency in useEffect
- 3 unused imports (auto-fixable)

✗ Review failed - fix blocking issues before commit

Token savings: 35.4% (TOON format)
```

**Result:** Review failed, 5 blocking type errors must be fixed before commit.

---

### Example 3: TOON Optimization (Large Review)

**Scenario:** Full module review - 12 warnings + 8 LSP diagnostics

**Review result:**
```json
{
  "code_review": {
    "score": 73,
    "blocking_issues": [],
    "warnings": [
      {"category": "code_quality", "severity": "WARNING", "file": "backend/app/services/auth_service.py", "line": 45, "message": "Function complexity 15 exceeds threshold 10", "rule": "cognitive-complexity"},
      {"category": "code_quality", "severity": "WARNING", "file": "backend/app/services/auth_service.py", "line": 78, "message": "Long function (67 lines) exceeds limit 50", "rule": "function-length"},
      {"category": "code_quality", "severity": "WARNING", "file": "backend/app/api/v1/endpoints/auth.py", "line": 34, "message": "Missing docstring for public function", "rule": "documentation"},
      {"category": "code_quality", "severity": "WARNING", "file": "backend/app/api/v1/endpoints/auth.py", "line": 89, "message": "Deep nesting level 5 exceeds limit 4", "rule": "nesting-depth"},
      {"category": "security", "severity": "WARNING", "file": "backend/app/core/security.py", "line": 23, "message": "Hardcoded secret detected", "rule": "security"},
      {"category": "code_quality", "severity": "WARNING", "file": "backend/app/middleware/auth_middleware.py", "line": 56, "message": "Duplicate code block found", "rule": "duplicate-code"},
      {"category": "code_quality", "severity": "INFO", "file": "tests/services/test_auth_service.py", "line": 12, "message": "Test coverage 78% below target 80%", "rule": "test-coverage"},
      {"category": "code_quality", "severity": "INFO", "file": "tests/api/test_auth_endpoints.py", "line": 45, "message": "Consider parameterizing test cases", "rule": "test-quality"},
      {"category": "code_quality", "severity": "WARNING", "file": "backend/app/models/user.py", "line": 67, "message": "Mutable default argument []", "rule": "code-smell"},
      {"category": "type_safety", "severity": "WARNING", "file": "backend/app/schemas/auth.py", "line": 34, "message": "Missing type annotation", "rule": "type-hints"},
      {"category": "code_quality", "severity": "INFO", "file": "backend/app/config.py", "line": 12, "message": "Consider using environment variables", "rule": "configuration"},
      {"category": "code_quality", "severity": "WARNING", "file": "docs/authentication.md", "line": 89, "message": "Documentation outdated", "rule": "documentation"}
    ],
    "lsp_diagnostics": [
      {"severity": "WARNING", "file": "backend/app/services/auth_service.py", "line": 23, "message": "'jwt' is not accessed", "source": "pyright"},
      {"severity": "WARNING", "file": "backend/app/services/auth_service.py", "line": 45, "message": "Return type partially unknown", "source": "pyright"},
      {"severity": "WARNING", "file": "backend/app/api/v1/endpoints/auth.py", "line": 12, "message": "'Depends' is not accessed", "source": "pyright"},
      {"severity": "WARNING", "file": "backend/app/core/security.py", "line": 8, "message": "'hashlib' is not accessed", "source": "pyright"},
      {"severity": "INFO", "file": "backend/app/middleware/auth_middleware.py", "line": 34, "message": "Type partially unknown", "source": "pyright"},
      {"severity": "WARNING", "file": "backend/app/models/user.py", "line": 5, "message": "'Optional' is not accessed", "source": "pyright"},
      {"severity": "WARNING", "file": "backend/app/schemas/auth.py", "line": 3, "message": "'BaseModel' is not accessed", "source": "pyright"},
      {"severity": "INFO", "file": "tests/services/test_auth_service.py", "line": 7, "message": "Import could be condensed", "source": "pyright"}
    ],
    "passed": true,
    "toon": {
      "warnings_toon": "warnings[12]{category,severity,file,line,message,rule}:\n  code_quality,WARNING,backend/app/services/auth_service.py,45,Function complexity 15 exceeds threshold 10,cognitive-complexity\n  code_quality,WARNING,backend/app/services/auth_service.py,78,Long function (67 lines) exceeds limit 50,function-length\n  code_quality,WARNING,backend/app/api/v1/endpoints/auth.py,34,Missing docstring for public function,documentation\n  code_quality,WARNING,backend/app/api/v1/endpoints/auth.py,89,Deep nesting level 5 exceeds limit 4,nesting-depth\n  security,WARNING,backend/app/core/security.py,23,Hardcoded secret detected,security\n  code_quality,WARNING,backend/app/middleware/auth_middleware.py,56,Duplicate code block found,duplicate-code\n  code_quality,INFO,tests/services/test_auth_service.py,12,Test coverage 78% below target 80%,test-coverage\n  code_quality,INFO,tests/api/test_auth_endpoints.py,45,Consider parameterizing test cases,test-quality\n  code_quality,WARNING,backend/app/models/user.py,67,Mutable default argument [],code-smell\n  type_safety,WARNING,backend/app/schemas/auth.py,34,Missing type annotation,type-hints\n  code_quality,INFO,backend/app/config.py,12,Consider using environment variables,configuration\n  code_quality,WARNING,docs/authentication.md,89,Documentation outdated,documentation",
      "lsp_diagnostics_toon": "lsp_diagnostics[8]{severity,file,line,message,source}:\n  WARNING,backend/app/services/auth_service.py,23,'jwt' is not accessed,pyright\n  WARNING,backend/app/services/auth_service.py,45,Return type partially unknown,pyright\n  WARNING,backend/app/api/v1/endpoints/auth.py,12,'Depends' is not accessed,pyright\n  WARNING,backend/app/core/security.py,8,'hashlib' is not accessed,pyright\n  INFO,backend/app/middleware/auth_middleware.py,34,Type partially unknown,pyright\n  WARNING,backend/app/models/user.py,5,'Optional' is not accessed,pyright\n  WARNING,backend/app/schemas/auth.py,3,'BaseModel' is not accessed,pyright\n  INFO,tests/services/test_auth_service.py,7,Import could be condensed,pyright",
      "token_savings": "40.2%",
      "size_comparison": "JSON: 3560 tokens, TOON: 2130 tokens"
    }
  }
}
```

**User message:**
```
## Code Review: 73/100

⚠️ WARNINGS:
- security.py:23 — Hardcoded secret detected (SECURITY)
- auth_service.py:45 — Function complexity 15 exceeds threshold
- auth_service.py:78 — Long function (67 lines)
- auth_middleware.py:56 — Duplicate code block found
- ... 8 more warnings

💡 LSP DIAGNOSTICS:
- 6 unused imports (auto-fixable)
- 2 type hints partially unknown (info)

✓ Review passed (with warnings)

Top priority fixes:
1. security.py:23 - Remove hardcoded secret (SECURITY)
2. auth_service.py - Refactor complex function

Token savings: 40.2% (TOON format)
```

**Result:** Review passed, 12 non-blocking warnings, TOON optimization saves 40.2% tokens.

---

## Integration with Other Skills

**Used by:**
- `adaptive-workflow` → Review code after PHASE 3 (implementation)
- `commit-and-push` → Pre-commit validation

**Uses:**
- `lsp-integration` → LSP diagnostics for type checking
- `architecture-documentation` → Architecture validation
- `toon-skill` → TOON optimization for warnings[] и lsp_diagnostics[] (см. `@shared:TOON-REFERENCE.md`)

---

🤖 Generated with Claude Code

**Author:** ikeniborn
**License:** MIT
