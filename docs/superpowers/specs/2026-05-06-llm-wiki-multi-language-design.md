# LLM Wiki — Multi-Language Source Support

**Date:** 2026-05-06  
**Status:** Draft  
**Scope:** Расширение llm-wiki для чтения `.py`, `.ts`, `.js`, `.sh` как полноправных источников наравне с `.md`

---

## Проблема

Текущая реализация жёстко ограничена `.md` файлами в трёх местах:

- `init` (шаг 2): `Glob "**/*.md"` по `source_paths`
- `init` (шаг 1а, bootstrap-анализ): та же выборка `**/*.md`
- `lint` (шаг 1): `Glob ".md" файлы в {wiki_root}/**`

Это делает wiki неполной: код — полноправный источник архитектурных знаний (API, типы, зависимости, паттерны), но сейчас игнорируется.

---

## Цель

Сделать llm-wiki **language-agnostic**: читать любой тип файла по конфигурируемым правилам. Добавить новый язык = одна секция в JSON + один `.md` файл с инструкциями.

---

## Подход: A+B гибрид

**A — `source_types` в `domain-map.json`** — машиночитаемый реестр поддерживаемых типов файлов.  
**B — `rules/readers/*.md`** — детальные инструкции LLM как читать каждый язык.

`ingest` смотрит расширение → находит в `source_types` → загружает `rules_file` → применяет `extract` при чтении.

---

## Архитектура

```
domain-map.json
└── source_types (новая секция, глобальная для всего wiki)
      ├── .md  → reader: markdown
      ├── .py  → reader: python  → rules/readers/python.md
      ├── .ts  → reader: typescript → rules/readers/typescript.md
      ├── .js  → reader: javascript → rules/readers/javascript.md
      └── .sh  → reader: bash → rules/readers/bash.md

skills/llm-wiki/rules/readers/
      ├── python.md
      ├── typescript.md
      ├── javascript.md
      ├── bash.md
      └── markdown.md  (существующее поведение задокументировано явно)
```

`source_types` живёт на уровне всего wiki (не per-domain): язык программирования не зависит от домена знаний. Домен может переопределить через `domain_source_types` при необходимости (edge case, не реализуется сейчас).

---

## Схема `source_types` в `domain-map.json`

```json
"source_types": {
  ".md": {
    "reader": "markdown",
    "extract": ["narrative", "frontmatter", "code_blocks", "headings"],
    "rules_file": "rules/readers/markdown.md"
  },
  ".py": {
    "reader": "python",
    "extract": ["public_api", "docstrings", "types", "imports"],
    "rules_file": "rules/readers/python.md"
  },
  ".ts": {
    "reader": "typescript",
    "extract": ["public_api", "docstrings", "types", "imports"],
    "rules_file": "rules/readers/typescript.md"
  },
  ".js": {
    "reader": "javascript",
    "extract": ["public_api", "docstrings", "imports"],
    "rules_file": "rules/readers/javascript.md"
  },
  ".sh": {
    "reader": "bash",
    "extract": ["functions", "flags", "exports", "comments"],
    "rules_file": "rules/readers/bash.md"
  }
}
```

**Поля:**
- `reader` — идентификатор типа (для логов и отчётов)
- `extract` — машиночитаемый список категорий извлечения (используется в bootstrap-анализе для генерации `entity_types`)
- `rules_file` — путь к детальному промпту для LLM (относительно `skills/llm-wiki/`)

---

## Структура файлов `rules/readers/*.md`

Каждый reader-файл содержит четыре секции:

### 1. Что искать (синтаксические паттерны)

Конкретные конструкции языка, соответствующие категориям из `extract`:

| Категория | Что ищем |
|-----------|---------|
| `public_api` | `def`, `class`, `export function`, `export const`, `function` (без `_` prefix), `__all__` |
| `docstrings` | `"""..."""`, `'''...'''`, `/** */`, `//` над функцией |
| `types` | `dataclass`, `TypedDict`, `Pydantic BaseModel`, `interface`, `type Alias =`, `enum` |
| `imports` | `import`, `from ... import`, `require(...)`, `source` (bash) |
| `functions` | bash: `function name()` или `name()` |
| `flags` | bash: `--flag`, `getopts`, `case $1` |
| `exports` | bash: `export VAR=` |

### 2. Правила именования (код → wiki-сущность)

- Функция `calculate_revenue` → wiki-страница `calculate-revenue`
- Класс `DataPipeline` → `data-pipeline`
- TypeScript interface `UserConfig` → `user-config`
- Bash-флаг `--sandbox-microvm` → `sandbox-microvm-flag`

### 3. Правила синтеза (что писать в wiki-страницу)

Для функции/метода:
- H2 "Сигнатура" — точная сигнатура из кода
- H2 "Описание" — из docstring/JSDoc, если есть; иначе вывести по имени и телу
- H2 "Параметры" — таблица имя/тип/описание
- H2 "Возвращает" — тип и описание
- H2 "Использует" — WikiLinks на зависимости из `imports`

Для класса/интерфейса:
- H2 "Назначение" — из docstring
- H2 "Поля/Атрибуты" — таблица
- H2 "Методы" — список с WikiLinks
- H2 "Зависимости" — из imports

### 4. Пример (вход/выход)

Конкретный фрагмент кода → результирующая wiki-страница.

---

## Изменения в существующих файлах скилла

### SKILL.md

**Phase 0** — без изменений.

**Phase 2, операция `ingest`** — добавить шаг перед чтением файла:

```
Шаг 1.5: Source Type Resolution
1. Получить расширение файла (ext = lowercase suffix)
2. Найти ext в domain-map.source_types
3. Если не найдено:
   - Предупредить: "Тип файла {ext} не поддерживается. Обработать как plain text?"
   - AskUserQuestion: продолжить как plain text | пропустить файл
4. Загрузить rules_file для reader'а (@rules:readers/{reader}.md)
5. Применить extract-правила при извлечении сущностей (шаг 3)
```

**Phase 2, операция `init` (шаг 2 и bootstrap-анализ, шаг а):**

```
было: Glob "**/*.md" по source_paths, исключить *.excalidraw.md
стало: Glob "**/*.{md,py,ts,js,sh}" по source_paths
       Фильтр: только расширения из domain-map.source_types
       Исключить: *.excalidraw.md, node_modules/, __pycache__/, .git/
```

Bootstrap-анализ (шаг б) читает все найденные файлы. При анализе код-файлов — применять reader для данного расширения для понимания структуры, а не искать `#теги из frontmatter` (которых в коде нет).

**Phase 2, операция `lint` (шаг CV-*)**:

```
CV-* проверки: учитывать source_paths для всех поддерживаемых типов
было: только .md файлы в source_paths
стало: все файлы из source_types
```

### `ingest-rules.md`

Добавить секцию перед "Основными принципами":

```markdown
## Source Type Resolution

Перед чтением файла определить reader:
1. Расширение файла → domain-map.source_types
2. Загрузить соответствующий @rules:readers/{reader}.md
3. Применять extract-правила данного reader'а на шаге 3 (извлечение сущностей)

Fallback для неизвестных расширений: обработать как plain text,
искать только явные именованные понятия (существительные, аббревиатуры).
```

Секция "Excalidraw-файлы" расширяется:

```markdown
### Неподдерживаемые типы файлов
Файлы с расширениями не из source_types (бинарники, изображения, etc.)
→ SKIP с сообщением: "Тип {ext} не поддерживается"
```

---

## Шаблон domain-map (обновлённый)

Добавить `source_types` в шаблон пустого `domain-map.json` (Phase 0, Step 0.1):

```json
"source_types": {
  ".md":  { "reader": "markdown",   "extract": ["narrative", "frontmatter", "code_blocks"] },
  ".py":  { "reader": "python",     "extract": ["public_api", "docstrings", "types", "imports"] },
  ".ts":  { "reader": "typescript", "extract": ["public_api", "docstrings", "types", "imports"] },
  ".js":  { "reader": "javascript", "extract": ["public_api", "docstrings", "imports"] },
  ".sh":  { "reader": "bash",       "extract": ["functions", "flags", "exports"] }
}
```

---

## Что НЕ меняется

- Структура wiki (`.wiki/`, `.config/`, `domain-map.json` основные поля)
- Алгоритм CREATE/UPDATE/SKIP
- Формат wiki-страниц (`wiki-page.json` шаблон)
- Логирование и индекс
- Операции `query` и `lint` (за исключением CV-* проверок)

---

## Новые файлы

| Файл | Описание |
|------|---------|
| `rules/readers/markdown.md` | Документирует существующее поведение явно |
| `rules/readers/python.md` | Правила чтения Python: def, class, dataclass, imports |
| `rules/readers/typescript.md` | Правила чтения TS: export, interface, type, JSDoc |
| `rules/readers/javascript.md` | Правила чтения JS: module.exports, JSDoc, require |
| `rules/readers/bash.md` | Правила чтения bash: functions, flags, exports, comments |

---

## Критерии успеха

1. `ingest` на `.py` файл создаёт wiki-страницы для публичных функций/классов
2. `init` находит `.py`/`.ts` файлы наравне с `.md`
3. Bootstrap-анализ корректно предлагает `entity_types` для кодовой базы
4. Добавление нового языка = 1 запись в `source_types` + 1 файл в `rules/readers/`
5. Существующие `.md` источники работают без изменений

---

## Ограничения в скоупе

- Парсинг AST не используется — только LLM-чтение по правилам
- `domain_source_types` (override per-domain) не реализуется в v1
- Бинарные файлы (`.pyc`, `.whl`) — всегда SKIP
