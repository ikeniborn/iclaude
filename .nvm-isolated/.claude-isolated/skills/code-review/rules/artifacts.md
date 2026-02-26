# Artifact Management Rules

## Overview

Все файлы, создаваемые навыком code-review во время работы (результаты ревью, TOON-отчёты, временные файлы), являются **runtime-артефактами** и должны храниться строго в выделенной директории. Запись в произвольные места нарушает гит-гигиену проекта.

---

## Rule A-1: Mandatory Artifact Directory

**Единственно допустимый путь для артефактов:**

```
{PROJECT_ROOT}/.claude/code-review/
```

**Создание директории** (если не существует):

```bash
mkdir -p "${PROJECT_ROOT}/.claude/code-review/"
```

**Почему `.claude/code-review/`:**
- `.claude/*` уже добавлен в `.gitignore` проекта (покрывает всё содержимое автоматически)
- Изолировано от production-файлов проекта
- Стандартное место для Claude Code runtime-данных

---

## Rule A-2: Hard Prohibition — No Root Artifacts

**ЗАПРЕЩЕНО** создавать файлы в следующих местах:

| Запрещённый путь | Пример нарушения |
|-----------------|-----------------|
| Корень проекта (`./`) | `./code-review-6.toon`, `./review.json` |
| Текущий рабочий каталог | `code-review.toon` без явного пути |
| `/tmp` или системные временные каталоги | `/tmp/review-output.json` |
| Любой другой произвольный путь | `../artifacts/review.json` |

**Нарушение:** файлы `code-review-6.toon`, `research.toon` и подобные в корне проекта — прямое нарушение этого правила.

**Проверка перед записью:**

```python
# ОБЯЗАТЕЛЬНО проверять путь перед записью
def validate_artifact_path(path: str, project_root: str) -> bool:
    allowed_prefix = os.path.join(project_root, ".claude", "code-review")
    return os.path.realpath(path).startswith(os.path.realpath(allowed_prefix))
```

---

## Rule A-3: Naming Convention

Все артефакты должны следовать схеме именования с временной меткой:

| Тип файла | Шаблон имени | Пример |
|-----------|-------------|--------|
| Полный JSON-отчёт | `review-{YYYYMMDD-HHMMSS}.json` | `review-20260226-143022.json` |
| TOON-сводка | `review-{YYYYMMDD-HHMMSS}.toon` | `review-20260226-143022.toon` |
| Последний отчёт (символическая ссылка или копия) | `review-latest.json` | `review-latest.json` |

**Запрещены** имена без временной метки (перезаписывают предыдущие результаты) и имена с `code-review-N` нумерацией.

---

## Rule A-4: .gitignore Compliance

Директория `.claude/code-review/` **автоматически gitignored** через правило `.claude/*` в `.gitignore`.

Явное правило в `.gitignore` для документальной ясности:

```gitignore
# Code review runtime artifacts (review reports, TOON output)
.claude/code-review/
```

**Проверка:**

```bash
git check-ignore -v .claude/code-review/review-latest.json
# Ожидаемый вывод: .gitignore:N:.claude/*  .claude/code-review/review-latest.json
```

---

## Rule A-5: Directory Bootstrap

Перед записью любого артефакта навык **ОБЯЗАН** создать директорию:

```bash
ARTIFACT_DIR="${PROJECT_ROOT}/.claude/code-review"
mkdir -p "$ARTIFACT_DIR"

# Запись артефакта
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_FILE="$ARTIFACT_DIR/review-${TIMESTAMP}.json"
```

При отсутствии `PROJECT_ROOT` использовать:

```bash
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
```

---

## Enforcement Summary

| Действие | Разрешено | Запрещено |
|----------|-----------|-----------|
| Запись в `.claude/code-review/` | ✅ | |
| Запись в корень проекта (`./`) | | ❌ |
| Запись в `/tmp` | | ❌ |
| Запись в произвольный путь | | ❌ |
| Создание `.claude/code-review/` если нет | ✅ | |
| Файлы без временной метки | | ❌ |

**Ссылки:**
- `.gitignore` — правило `.claude/*` (строка ~118)
- [@rules:determinism](./determinism.md) — правила детерминизма
