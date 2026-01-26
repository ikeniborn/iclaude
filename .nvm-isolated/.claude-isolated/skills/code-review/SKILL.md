---
name: code-review
description: Автоматический review кода перед commit
version: 1.3.0
tags: [review, quality, security, code-smells, toon]
dependencies: [toon-skill, lsp-integration]
files:
  templates: ./templates/*.json
  rules: ./rules/*.md
user-invocable: true
changelog:
  - version: 1.3.0
    date: 2026-01-26
    changes:
      - "Структурная оптимизация: TOC, Quick Start, компактные секции"
      - "Консолидация TOON информации в Output Formats"
      - "Примеры сокращены (inline summary + ссылки на examples/*.md)"
      - "Агрессивное удаление дублирования (619 → ~400 строк, 35% сокращение)"
  - version: 1.2.0
    date: 2026-01-25
    changes:
      - "Централизация: TOON specs → @shared:TOON-REFERENCE.md"
      - "Добавлено: 3 примера (simple review, LSP integration, TOON optimization)"
      - "Skill-specific TOON usage notes для warnings[] и lsp_diagnostics[]"
  - version: 1.1.0
    date: 2026-01-23
    changes:
      - "**TOON Format Support**: Автоматическая генерация TOON для token efficiency"
      - "TOON для warnings[] и lsp_diagnostics[] (когда >= 5 элементов)"
      - "40-50% token savings для больших review reports"
      - "100% backward compatibility (JSON остаётся primary format)"
---

# Code Review

Автоматическая проверка качества, безопасности и архитектурной целостности кода с LSP integration и TOON optimization.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Overview](#overview)
- [Check Categories](#check-categories)
  - [Architecture Compliance](#1-architecture-compliance-blocking)
  - [Security](#2-security-blocking)
  - [Code Quality](#3-code-quality-warning)
  - [Error Handling](#4-error-handling-warning)
  - [Type Safety](#5-type-safety-info)
- [LSP Integration](#lsp-integration)
- [Output Formats](#output-formats)
  - [JSON Schema](#json-schema)
  - [Score Calculation](#score-calculation)
  - [TOON Optimization](#toon-optimization)
- [Examples](#examples)
- [Integration](#integration-with-other-skills)
- [Advanced Topics](#advanced-topics)
- [References](#references)

---

## Quick Start

```bash
# Automatic review в adaptive-workflow (PHASE 3)
# Требования: yq, jq, architecture docs (auto-generated if missing)

# Output: JSON с blocking_issues[], warnings[], score
{
  "code_review": {
    "score": 85,
    "passed": true,
    "blocking_issues": [],  # Architecture, security
    "warnings": [...]       # Code quality, type safety
  }
}
```

**Когда блокирует commit:**
- ⚠️ Architecture violations (circular deps, undocumented components)
- 🔒 Security issues (SQL injection, XSS, hardcoded secrets)

---

## Overview

### Когда использовать

- После выполнения задачи (standard/complex workflows)
- Перед git commit (автоматически в git-workflow skill)
- По запросу пользователя

### Требования

| Компонент | Статус | Описание |
|-----------|--------|----------|
| **yq** | Required | YAML→JSON конвертация архитектуры |
| **jq** | Required | JSON parsing для валидации |
| **Architecture docs** | Required | `docs/architecture/overview.yaml` (auto-generated) |
| **LSP integration** | Optional | Enhanced type checking (см. [@skill:lsp-integration](../lsp-integration/SKILL.md)) |

---

## Check Categories

| # | Category | Severity | Examples | Details |
|---|----------|----------|----------|---------|
| 1 | **Architecture Compliance** | BLOCKING | Circular deps, layer violations, undocumented components | [@rules:architecture](./rules/architecture.md) |
| 2 | **Security** | BLOCKING | SQL injection, XSS, command injection, hardcoded secrets | [@rules:security](./rules/security.md) |
| 3 | **Code Quality** | WARNING | Long functions (>50 lines), high complexity (>10), duplication | Regex-based |
| 4 | **Error Handling** | WARNING | Bare except, empty catch, unhandled promises | Regex-based |
| 5 | **Type Safety** | INFO | Missing type hints, Any types, implicit conversions | LSP-enhanced |

### 1. Architecture Compliance (BLOCKING)

**Проверки:**
- Referential integrity (все зависимости существуют)
- Circular dependency detection (DAG validation)
- Component file path validation (измененные файлы документированы)
- Layer boundary compliance (no upward dependencies)

**Scope:** Гибридный (modified components + their dependents)

**Architecture paths** (приоритет):
1. Пользовательские пути (`.clauderc`, `CODE_REVIEW_ARCH_PATHS` env, `.claude/config.json`)
2. Стандартные пути (`docs/architecture/`, `doc/architecture/`, `documentation/architecture/`)
3. Рекурсивный поиск (fallback, глубина 3)

**Fallback:** Если архитектура не найдена → автоматически запускает `@skill:architecture-documentation` для генерации.

**Детали:** См. [@rules:architecture](./rules/architecture.md)

### 2. Security (BLOCKING)

**Паттерны:**
- SQL Injection (string concatenation в queries)
- Command Injection (shell=True, unsanitized input)
- XSS (innerHTML assignment)
- Path Traversal (unsanitized file paths)
- Hardcoded secrets (API_KEY=, password=, token=)
- Insecure deserialization

**Детали:** См. [@rules:security](./rules/security.md)

### 3. Code Quality (WARNING)

**Метрики:**
- Function length > 50 lines
- Cyclomatic complexity > 10
- Deep nesting > 4 levels
- Code duplication
- Magic numbers
- Unused imports/variables

### 4. Error Handling (WARNING)

**Паттерны:**
- Bare `except:` clauses (Python)
- Empty catch blocks (JavaScript/TypeScript)
- Missing null checks
- Unhandled promises

### 5. Type Safety (INFO)

**LSP-enhanced проверки:**
- Missing type hints (Python via pyright)
- Any types (TypeScript via vtsls)
- Type mismatches (LSP diagnostics)
- Implicit type conversions

---

## LSP Integration

**Активируется когда:** `lsp_status.status == "READY"` (из lsp-integration skill)

**Что предоставляет LSP:**
1. **Type Checking:** mismatches, Any types, missing type hints
2. **Code Intelligence:** undefined names, unused variables (via find-references)
3. **Diagnostics:** merged в `code_review.warnings[]` с category: "type_safety"

**Поддерживаемые LSP серверы:**

| Язык | LSP Server | Plugin |
|------|------------|--------|
| TypeScript | vtsls | typescript-lsp@claude-plugins-official |
| Python | pyright | pyright-lsp@claude-plugins-official |
| Go | gopls | gopls-lsp@claude-plugins-official |
| Rust | rust-analyzer | rust-analyzer-lsp@claude-plugins-official |

**Интеграция:**
```
IF lsp_status.status == "READY":
  1. Request LSP diagnostics for files_changed
  2. Parse severity: error → BLOCKING, warning → WARNING, info → INFO
  3. Merge into code_review.warnings[] + lsp_diagnostics[]
  4. Adjust score: LSP errors -10 points (vs. -5 for regex checks)
ELSE:
  Fallback to regex-based checks
```

**Backward Compatibility:** Без LSP skill работает полностью функционально (regex-based checks).

**Детали:** См. [@skill:lsp-integration](../lsp-integration/SKILL.md)

---

## Output Formats

### JSON Schema

```json
{
  "code_review": {
    "score": 75,                    // 0-100
    "passed": false,                // blocking_issues.length === 0
    "blocking_issues": [            // BLOCKING severity только
      {
        "category": "architecture_compliance",
        "severity": "BLOCKING",
        "rule": "circular_dependency",
        "message": "...",
        "suggestion": "..."
      }
    ],
    "warnings": [                   // WARNING + INFO
      {
        "category": "code_quality",
        "severity": "WARNING",
        "file": "service.py",
        "line": 42,
        "message": "Function too long (65 lines)",
        "suggestion": "Extract helper methods"
      }
    ],
    "lsp_diagnostics": [...],       // Optional (if LSP available)
    "toon": { ... }                 // Optional (if >= 5 warnings/diagnostics)
  }
}
```

**Полный шаблон:** См. [templates/review-output.json](./templates/review-output.json)

### Score Calculation

**Формула:**

| Category | Weight | Penalty | Max Score |
|----------|--------|---------|-----------|
| Architecture | 25% | -10 per blocking | 25 |
| Security | 25% | -10 per blocking | 25 |
| Code Quality | 25% | -5 per warning | 25 |
| Error Handling | 15% | -5 per warning | 15 |
| Type Safety | 10% | -5 per warning | 10 |

```
total_score = architecture_score + security_score + code_quality_score +
              error_handling_score + type_safety_score

passed = blocking_issues.length === 0
```

**Fallback:** Если архитектура недоступна, веса пересчитываются: Security 33.33%, Code Quality 33.33%, Error 20%, Type 13.33%.

**Markdown Output:**

```markdown
## Code Review: 75/100

🛑 BLOCKING ISSUES:
- file.py:42 — SQL injection detected

⚠️ WARNINGS:
- service.py:65 — Function too long (72 lines)
- models.py:15 — Missing type hint

💡 SUGGESTIONS:
- Consider adding docstrings to public functions

✗ Review failed - fix blocking issues before commit
```

### TOON Optimization

**Цель:** 40-50% token savings для больших review reports (>= 5 warnings/diagnostics)

**Что оптимизируется:**
- `warnings[]` — когда >= 5 warnings
- `lsp_diagnostics[]` — когда >= 5 LSP issues

**Threshold:** TOON генерируется только если массив >= 5 элементов.

**Token Savings (Review-Specific):**

| Array Size | Token Savings | JSON Tokens | TOON Tokens |
|------------|---------------|-------------|-------------|
| 8 warnings | 35.4% | 1420 | 918 |
| 12 warnings + 8 LSP | 40.2% | 3560 | 2130 |
| 25 warnings + 15 LSP | 45.7% | 7120 | 3865 |

**Implementation:**

```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Review output
const review = {
  warnings: [...],          // 12 warnings
  lsp_diagnostics: [...]    // 8 LSP issues
};

// Add TOON optimization (if >= 5 elements)
if (review.warnings.length >= 5) {
  review.toon = {
    warnings_toon: arrayToToon('warnings', review.warnings,
      ['severity', 'file', 'line', 'message', 'rule']),
    token_savings: "40.2%",
    size_comparison: "JSON: 3560 tokens, TOON: 2130 tokens"
  };
}

if (review.lsp_diagnostics?.length >= 5) {
  review.toon.lsp_diagnostics_toon = arrayToToon('lsp_diagnostics', review.lsp_diagnostics,
    ['severity', 'file', 'line', 'message', 'source']);
}
```

**Output Structure:**

```json
{
  "code_review": {
    "warnings": [...],              // JSON (always present)
    "lsp_diagnostics": [...],
    "toon": {                       // TOON (optional, if >= 5 elements)
      "warnings_toon": "warnings[12]{severity,file,line,message,rule}:\n  ...",
      "lsp_diagnostics_toon": "lsp_diagnostics[8]{severity,file,line,message,source}:\n  ...",
      "token_savings": "40.2%",
      "size_comparison": "JSON: 3560 tokens, TOON: 2130 tokens"
    }
  }
}
```

**100% Backward Compatibility:**
- JSON остаётся primary format (всегда присутствует)
- TOON добавляется как optimization layer (opt-in)
- Downstream skills могут читать JSON (всегда работает) или TOON (если доступен)

**Детали:** См. [@shared:TOON-REFERENCE.md](../_shared/TOON-REFERENCE.md)

---

## Examples

**Формат:** Короткие inline summaries + ссылки на детальные примеры

| Scenario | Files | Score | Result | Details |
|----------|-------|-------|--------|---------|
| **Simple Review** | 2 files, 2 warnings | 92/100 | ✓ Passed | [examples/basic-usage.md](./examples/basic-usage.md) |
| **LSP Integration** | 3 TS files, 5 type errors | 58/100 | ✗ Failed (BLOCKING) | [examples/architecture-validation.md](./examples/architecture-validation.md) |
| **TOON Optimization** | 8 files, 12 warnings + 8 LSP | 73/100 | ✓ Passed (40.2% savings) | [examples/toon-output.example](./examples/toon-output.example) |

**Example 1 Summary:** Small change (payment service + test), 2 non-blocking warnings (complexity, type hint), review passed.

**Example 2 Summary:** TypeScript refactor, LSP detected 5 blocking type errors (string|undefined mismatch, missing property, null checks), review failed.

**Example 3 Summary:** Full module review, 12 code quality warnings + 8 LSP diagnostics (unused imports, partial types), TOON optimization saved 40.2% tokens (3560 → 2130).

**Детальные примеры:** См. директорию [examples/](./examples/)

---

## Integration with Other Skills

**Used by:**
- `adaptive-workflow` → Review code after PHASE 3 (implementation) for standard/complex workflows
- `commit-and-push` → Pre-commit validation (blocks commit if `passed: false`)

**Uses:**
- `lsp-integration` → LSP diagnostics для enhanced type checking (optional)
- `architecture-documentation` → Architecture validation (auto-generates if missing)
- `toon-skill` → TOON optimization для warnings[] и lsp_diagnostics[] (см. @shared:TOON-REFERENCE.md)

**Data Flow:**
```
files_changed[] → code-review skill
                    ├─ Architecture checks (if docs available)
                    ├─ Security checks (regex-based)
                    ├─ Code quality checks (regex-based)
                    ├─ LSP diagnostics (if lsp_status.status == "READY")
                    └─ TOON optimization (if warnings >= 5)
                  → {code_review: {...}}
```

---

## Advanced Topics

### Custom Architecture Paths

**3 способа конфигурации:**

1. **Переменная окружения:**
   ```bash
   export CODE_REVIEW_ARCH_PATHS="custom/arch:internal/docs/architecture"
   ```

2. **`.clauderc` в корне проекта:**
   ```json
   {
     "codeReview": {
       "architecturePaths": ["custom/architecture", "internal/docs/arch"]
     }
   }
   ```

3. **Isolated config** (`.claude/config.json`):
   ```json
   {
     "skills": {
       "codeReview": {
         "architecturePaths": ["team/architecture", "wiki/system-design"]
       }
     }
   }
   ```

**Приоритет:** Пользовательские пути → Стандартные пути → Рекурсивный поиск.

### Architecture Format Support

| Формат | Детекция | Источник | Status |
|--------|----------|----------|--------|
| `iclaude` | `project.id` + `components[]` + `layers[]` | Ручное создание | ✅ Full support |
| `arch-doc` | `architecture.metadata` + `architecture.components[]` | @skill:architecture-documentation | ✅ Full support |
| `c4` | `model.softwareSystems` или `model.containers` | Structurizr | ✅ Full support |
| `generic` | `components[]` | Различные инструменты | ✅ Basic support |

**Graceful Degradation:**
- Нераспознанный формат: WARNING (не BLOCKING)
- Остальные проверки (security, code quality) выполняются
- Рекомендация: запустить `@skill:architecture-documentation` для генерации совместимого формата

**Детали форматов:** См. [examples/supported-formats.md](./examples/supported-formats.md)

---

## References

**TOON Format:**
- Full spec: [@shared:TOON-REFERENCE.md](../_shared/TOON-REFERENCE.md)
- Integration patterns: [@shared:TOON-REFERENCE.md#integration-patterns](../_shared/TOON-REFERENCE.md#integration-patterns)
- Token savings benchmarks: [@shared:TOON-REFERENCE.md#token-savings](../_shared/TOON-REFERENCE.md#token-savings)

**Rules:**
- Architecture compliance: [@rules:architecture](./rules/architecture.md)
- Security patterns: [@rules:security](./rules/security.md)

**Templates:**
- Review output JSON schema: [templates/review-output.json](./templates/review-output.json)

**Examples:**
- Basic usage: [examples/basic-usage.md](./examples/basic-usage.md)
- Architecture validation: [examples/architecture-validation.md](./examples/architecture-validation.md)
- TOON optimization: [examples/toon-output.example](./examples/toon-output.example)
- Supported formats: [examples/supported-formats.md](./examples/supported-formats.md)

**Task Structure:**
- [@shared:TASK-STRUCTURE.md#code-review](../_shared/TASK-STRUCTURE.md#code-review)

---

🤖 Generated with Claude Code

**Author:** ikeniborn
**License:** MIT
