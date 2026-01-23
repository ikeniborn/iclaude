---
name: code-review
description: Автоматический review кода перед commit
version: 1.1.0
tags: [review, quality, security, code-smells, toon]
dependencies: [toon-skill]
files:
  templates: ./templates/*.json
  rules: ./rules/*.md
user-invocable: true
changelog:
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

## TOON Format Support

**NEW in v1.1.0:** Автоматическая генерация TOON format для token-efficient output

### Когда генерируется TOON

Skill автоматически генерирует TOON format когда:
- `warnings.length >= 5` ИЛИ
- `lsp_diagnostics.length >= 5`

### Token Savings

**Типичная экономия:**
- 15 warnings: **43% token reduction**
- 50 LSP diagnostics: **48% token reduction**
- Combined (warnings + diagnostics): **40-50% total savings**

### Output Structure (Hybrid JSON + TOON)

```json
{
  "code_review": {
    "score": 85,
    "blocking_issues": [],
    "warnings": [...],          // JSON (всегда присутствует)
    "lsp_diagnostics": [...],   // JSON (если LSP available)
    "toon": {                   // TOON (опционально, если >= 5 элементов)
      "warnings_toon": "warnings[15]{category,file,line,severity,message,suggestion}:\n  code_quality,service.py,42,WARNING,Function too long (65 lines),Extract helper methods\n  security,api.py,78,BLOCKING,SQL injection detected,Use parameterized queries\n  ...",
      "lsp_diagnostics_toon": "lsp_diagnostics[42]{file,line,severity,code,message}:\n  app.ts,15,error,TS2322,Type 'string' is not assignable to type 'number'\n  utils.ts,89,warning,TS6133,Variable 'unused' is declared but never used\n  ...",
      "token_savings": "43.2%",
      "size_comparison": "JSON: 3450 tokens, TOON: 1960 tokens"
    }
  }
}
```

### Benefits

- **Backward Compatible**: JSON output неизменён (primary format)
- **Opt-in Optimization**: TOON добавляется только когда выгодно (>= 5 элементов)
- **Zero Breaking Changes**: Downstream consumers читают JSON как раньше
- **Token Efficient**: 40-50% savings для больших review reports

### Integration with Other Skills

**Producers (code-review):**
```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Generate JSON output (always)
const codeReview = {
  score: 85,
  warnings: [...],  // 15 warnings
  lsp_diagnostics: [...]  // 42 diagnostics
};

// Add TOON optimization (if threshold met)
if (codeReview.warnings.length >= 5 ||
    (codeReview.lsp_diagnostics && codeReview.lsp_diagnostics.length >= 5)) {

  const dataToConvert = {};
  codeReview.toon = {};

  if (codeReview.warnings.length >= 5) {
    codeReview.toon.warnings_toon = arrayToToon('warnings', codeReview.warnings,
      ['category', 'file', 'line', 'severity', 'message', 'suggestion']);
    dataToConvert.warnings = codeReview.warnings;
  }

  if (codeReview.lsp_diagnostics && codeReview.lsp_diagnostics.length >= 5) {
    codeReview.toon.lsp_diagnostics_toon = arrayToToon('lsp_diagnostics', codeReview.lsp_diagnostics,
      ['file', 'line', 'severity', 'code', 'message']);
    dataToConvert.lsp_diagnostics = codeReview.lsp_diagnostics;
  }

  const stats = calculateTokenSavings(dataToConvert);
  codeReview.toon.token_savings = stats.savedPercent;
  codeReview.toon.size_comparison = `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`;
}

return { code_review: codeReview };
```

**Consumers (downstream skills):**
```javascript
import { toonToJson } from '../toon-skill/converters/toon-converter.mjs';

// Always read JSON (safest, backward compatible)
const warnings = codeReviewOutput.code_review.warnings;

// Or prefer TOON if available (token efficient)
const warnings = codeReviewOutput.code_review.toon?.warnings_toon
  ? toonToJson(codeReviewOutput.code_review.toon.warnings_toon).warnings
  : codeReviewOutput.code_review.warnings;
```

### See Also

- **toon-skill** - Базовый навык для TOON API ([../toon-skill/SKILL.md](../toon-skill/SKILL.md))
- **TOON-PATTERNS.md** - Integration patterns ([../_shared/TOON-PATTERNS.md](../_shared/TOON-PATTERNS.md))

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
