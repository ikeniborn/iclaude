---
name: code-review
description: Автоматический review кода перед commit
version: 1.0.0
tags: [review, quality, security, code-smells]
dependencies: []
files:
  templates: ./templates/*.json
  rules: ./rules/*.md
user-invocable: true
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
