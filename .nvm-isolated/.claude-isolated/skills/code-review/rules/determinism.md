# Determinism & Idempotency Rules

## Overview

Эти правила гарантируют, что повторное ревью одного и того же кода даёт **идентичные результаты**.

**Проблема без этих правил:** Claude может при каждом прогоне code-review генерировать разные suggestions для одного и того же кода → исправление по suggestion_1 приводит к новому suggestion_2 → бесконечный цикл переписывания.

**Решение:** Все проверки и suggestions основаны на **объективных, измеримых критериях**. Каждое исправление имеет **верифицируемый критерий завершения**.

---

## Rule D-1: Idempotency Guarantee

**Определение:** Два последовательных ревью одного и того же кода (без изменений кода между ними) **ДОЛЖНЫ** возвращать идентичный набор findings.

**Требования к реализации:**

1. Все findings основаны исключительно на **объективных паттернах** (regex, структурные проверки, числовые пороги)
2. Ни один finding **НЕ** должен зависеть от контекста или "общего впечатления" от кода
3. Пороги — **строгие константы** (см. Rule D-3), не диапазоны и не субъективные оценки
4. Suggestions — **canonical format** (см. Rule D-4), не свободный текст

**Verification test (мысленный):** Если запустить ревью дважды подряд на одном файле — `diff` результатов должен быть пустым.

---

## Rule D-2: Scope-Based Stability

**Определение:** Finding по конкретному `file:line` выдаётся **ТОЛЬКО** если файл входит в scope текущего ревью.

**Scope текущего ревью = изменённые файлы + их dependents в архитектуре:**

```
scope = git_diff_files ∪ dependent_components_files
```

**Правило для повторного ревью:**

```
IF file NOT IN current_scope:
  SKIP → не генерировать findings для этого файла
```

**Следствие:** Если файл не изменялся, он не получает новых findings, даже если там есть потенциальные проблемы. Это **намеренное поведение** — ревью проверяет именно изменения, а не весь codebase.

### Исключения из scope-ограничения

Следующие проверки выполняются **на весь граф архитектуры**, а не только на scope, потому что являются глобальными свойствами и не имеют смысла в частичном разрезе:

| Проверка | Почему глобальная |
|----------|-------------------|
| **Referential integrity** | Несуществующая зависимость может быть в любом компоненте, не только изменённом |
| **Circular dependencies** | Цикл может замыкаться через компоненты вне scope |

Эти проверки выполняются на весь граф компонентов из `docs/architecture/`, но **детектируют только нарушения** — не генерируют findings для компонентов вне scope при отсутствии нарушений.

Следующие проверки **применяют scope**:

| Проверка | Scope |
|----------|-------|
| Security (SQL injection, XSS, ...) | Только `git_diff_files` |
| Code Quality (length, complexity, ...) | Только `git_diff_files` |
| Error Handling | Только `git_diff_files` |
| Type Safety | Только `git_diff_files` |
| Component file path validation | Только `git_diff_files` |
| Layer boundary compliance | `git_diff_files ∪ dependent_components_files` |

---

## Rule D-3: Explicit Threshold Constants

Все пороги — **явные константы**. При изменении порогов необходимо обновить эту таблицу.

### Code Quality Thresholds

| Метрика | Константа | Порог | Проверка |
|---------|-----------|-------|----------|
| Длина функции | `MAX_FUNCTION_LINES` | **50** | `line_count > 50` → WARNING |
| Цикломатическая сложность | `MAX_COMPLEXITY` | **10** | `complexity > 10` → WARNING |
| Глубина вложенности | `MAX_NESTING_DEPTH` | **4** | `nesting > 4` → WARNING |
| Дублирование кода | `MAX_DUPLICATE_BLOCK` | **7 строк** | Блок `> 7` строк встречается 2+ раз → WARNING |

**Семантика порогов:** `> N` (строго больше) для всех констант. Значение N само по себе — PASS.
- Функция 50 строк → PASS; функция 51 строка → WARNING
- Дублирующийся блок 7 строк → PASS; 8 строк (> 7) → WARNING

**Запрещено:** Использовать нечёткие формулировки типа "approximately", "around", "roughly" при оценке метрик.

---

## Rule D-4: Canonical Suggestion Format

**Каждый `suggestion`** должен следовать формату:

```
{VERB} {SPECIFIC_TARGET} {CRITERION}
```

### Компоненты формата

| Компонент | Требование | Пример |
|-----------|-----------|--------|
| **VERB** | Один из: Split / Replace / Remove / Add / Rename / Extract / Move / Wrap | `Split` |
| **SPECIFIC_TARGET** | Конкретная функция, переменная, строка: `function_name() (file.py:N-M)` | `` `process_data()` (service.py:65-136) `` |
| **CRITERION** | Измеримый критерий завершения: "until each function ≤ 50 lines" | `until each resulting function ≤ 50 lines` |

### Допустимые VERB-ы

| VERB | Применяется для |
|------|----------------|
| `Split` | Длинные функции, сложные классы |
| `Replace` | Небезопасный паттерн → безопасный |
| `Remove` | Неиспользуемые переменные, imports |
| `Add` | Отсутствующие type hints, null checks |
| `Rename` | Неинформативные имена |
| `Extract` | Дублирующиеся блоки → helper function |
| `Move` | Компоненты в неправильном слое |
| `Wrap` | Небезопасные вызовы в try/except |

### Примеры (ПРАВИЛЬНО)

```json
// Security — SQL Injection
"suggestion": "Replace string concatenation in `get_user()` (users.py:42) with parameterized query `cursor.execute(query, (email,))` until no f-string/%-format is used in DB queries in this function"

// Code Quality — Long Function
"suggestion": "Split `process_data()` (service.py:65-136) into sub-functions until each function in service.py:65-136 is ≤50 lines"

// Type Safety — Missing hint
"suggestion": "Add type hint to parameter `data` in `process_data()` (models.py:15) as `data: dict` until pyright reports no missing-type-hints for this function"

// Architecture — Circular Dependency
"suggestion": "Move dependency from `credential-storage → cli-main` to an event/callback interface until `detect_circular_dependencies()` reports no cycles in cli-main → proxy-management → credential-storage path"
```

### Примеры (ЗАПРЕЩЕНО)

```json
// ❌ Нет конкретной цели
"suggestion": "Extract helper methods to reduce complexity"

// ❌ Нет критерия завершения
"suggestion": "Use parameterized queries"

// ❌ Расплывчатый VERB "Consider"
"suggestion": "Consider adding docstrings to public functions"

// ❌ Нет file:line
"suggestion": "Reduce function length"
```

---

## Rule D-5: Prohibition of Open-Ended Suggestions

**`suggestions[]` массив верхнего уровня — ЗАПРЕЩЁН** при машинном ревью.

**Причина:** Это массив свободных текстовых рекомендаций без привязки к конкретному коду. Каждый прогон LLM генерирует разный набор → недетерминированность.

**Вместо этого:** Любое наблюдение, требующее действия, оформляется как WARNING/INFO finding с обязательными полями `file`, `line`, `rule`, `suggestion` в canonical format.

**Альтернатива (если observation не привязан к строке):**

```json
{
  "category": "code_quality",
  "severity": "INFO",
  "file": "src/service.py",
  "line": null,
  "rule": "missing_module_docstring",
  "message": "Module has no module-level docstring",
  "suggestion": "Add module docstring at src/service.py:1 describing module purpose"
}
```

**Устаревший шаблон из `suggestions[]` — заменяется:**

| Было (недетерминировано) | Стало (детерминировано) |
|--------------------------|------------------------|
| "Consider adding docstrings to public functions" | INFO finding: rule=`missing_docstring`, file, line |
| "Use constants instead of magic numbers" | WARNING finding: rule=`magic_number`, file=N, line=N |
| "Consider documenting new function at iclaude.sh:3850-3900" | WARNING finding: rule=`undocumented_component`, file, line |

---

## Rule D-6: Pre-Verified Fix Patterns

Для каждого security rule — **фиксированный паттерн исправления**, который не зависит от контекста и не варьируется между ревью.

### SQL Injection

**Detection pattern:**
```regex
f".*SELECT.*WHERE.*{|%s.*%.*variable|\.format\(.*\).*query
```

**Canonical fix** (всегда один и тот же):
```python
# BEFORE (detected)
query = f"SELECT * FROM users WHERE email = '{email}'"
cursor.execute(query)

# AFTER (verified fix)
query = "SELECT * FROM users WHERE email = %s"
cursor.execute(query, (email,))
```

**Verification criterion:** `query` не содержит f-string/%-format/`.format()` при вызове `execute()` в этой функции.

### Command Injection

**Detection pattern:**
```regex
os\.system\(f|subprocess\.(call|run)\(.*shell=True.*\+|subprocess\.(call|run)\(.*shell=True.*f"
```

**Canonical fix:**
```python
# BEFORE (detected)
subprocess.call(user_input, shell=True)
os.system(f"ls {user_input}")

# AFTER (verified fix)
subprocess.run(["ls", user_input], shell=False)
```

**Verification criterion:** `shell=True` не используется вместе с переменными пользовательского ввода.

### XSS

**Detection pattern:**
```regex
\.innerHTML\s*=\s*[^"'][^;]*[^"']
```

**Canonical fix:**
```javascript
// BEFORE (detected)
element.innerHTML = userInput;

// AFTER (verified fix)
element.textContent = userInput;
// OR
element.innerHTML = DOMPurify.sanitize(userInput);
```

**Verification criterion:** Прямое присваивание `innerHTML` не используется без обёртки в DOMPurify.sanitize().

### Hardcoded Secrets

**Detection pattern:**
```regex
(API_KEY|password|secret|token|SECRET|TOKEN|PASSWD)\s*=\s*["'][A-Za-z0-9+/=_\-]{8,}["']
```

**Canonical fix:**
```python
# BEFORE (detected)
API_KEY = "sk-ant-api03-..."

# AFTER (verified fix)
import os
API_KEY = os.environ.get("API_KEY")  # or os.environ["API_KEY"]
```

**Verification criterion:** Значение переменной не является строковым литералом — читается из `os.environ` или конфигурационного файла.

### Path Traversal

**Detection pattern:**
```regex
open\(f"/.*\{|os\.path\.join\([^,]+,\s*[^"'][^)]*\)|open\([^)]*\+[^)]*filename
```

**Canonical fix:**
```python
# BEFORE (detected)
file_path = f"/uploads/{filename}"
open(file_path)

# AFTER (verified fix)
safe_path = os.path.join("/uploads", os.path.basename(filename))
open(safe_path)
```

**Verification criterion:** Пути, содержащие пользовательский ввод, проходят через `os.path.basename()` перед использованием.

---

## Rule D-7: Re-Run Behavior

При повторном ревью (после того как разработчик исправил часть issues):

### Что должно произойти

1. **Исправленные issues** — НЕ выдаются, если код прошёл verification criterion
2. **Не исправленные issues** — выдаются с теми же `rule`, `message`, `suggestion` (идентично первому ревью)
3. **Новые issues в изменённых файлах** — выдаются если появились в результате исправлений
4. **Не изменившиеся файлы вне scope** — не проверяются (Rule D-2)

### Признак правильно реализованного ревью

```
Ревью 1: file.py:42 — SQL injection BLOCKING
Разработчик исправляет: заменяет f-string на parameterized query
Ревью 2: file.py:42 — нет findings (исправление прошло verification criterion)
```

### Признак нарушения идемпотентности (антипаттерн)

```
Ревью 1: "Extract helper methods to reduce complexity"
Разработчик разбивает функцию на 3 части
Ревью 2: "Consider using utility class instead of separate functions"  ← ДРУГОЙ СОВЕТ
```

**Решение:** Использовать Rule D-4 canonical format с explicit criterion — тогда разработчик знает точно, когда исправление считается принятым.

---

## Rule D-8: Score Calculation (Canonical)

**Единственная каноническая формула** (устраняет противоречие между SKILL.md и examples/basic-usage.md):

```
total_score = Σ category_scores

category_score = max_score - (blocking_in_category × 10) - (warnings_in_category × 5)
category_score = max(0, category_score)  # не уходит в минус
```

| Категория | Max Score | Penalty per BLOCKING | Penalty per WARNING |
|-----------|-----------|---------------------|-------------------|
| Architecture | 25 | -10 | -5 |
| Security | 25 | -10 | -5 |
| Code Quality | 25 | — | -5 |
| Error Handling | 15 | — | -5 |
| Type Safety | 10 | -10 (LSP error only) ¹ | -5 |

**¹ LSP Enhanced Scoring:** LSP diagnostics с `severity: "error"` дают -10 (как BLOCKING penalty), с `severity: "warning"` — -5. LSP errors при этом **не добавляются** в `blocking_issues[]` — они остаются в `lsp_diagnostics[]`. Статус `passed` зависит только от `blocking_issues[].length === 0`.

**Если architecture недоступна** — redistributed weights:

```
Security: 33, Code Quality: 33, Error Handling: 20, Type Safety: 14
```

**Запрещены** альтернативные формулы типа `100 - (blocking * 20) - (warnings * 5) - (suggestions * 1)` — устаревший формат из basic-usage.md, не используется.

---

## Summary: Determinism Checklist

Перед выдачей каждого finding проверить:

- [ ] Finding основан на **объективном паттерне**, не на субъективной оценке
- [ ] `file` и `line` **указаны** (или `null` с объяснением)
- [ ] `rule` — **фиксированный идентификатор** из известного списка (не произвольная строка)
- [ ] `suggestion` — **canonical format**: `{VERB} {SPECIFIC_TARGET} {CRITERION}`
- [ ] `suggestion` содержит **измеримый критерий** завершения
- [ ] Файл входит в **текущий scope** (Rule D-2)
- [ ] **Не используется** `suggestions[]` массив верхнего уровня
- [ ] Threshold используется как **явная константа** из Rule D-3
