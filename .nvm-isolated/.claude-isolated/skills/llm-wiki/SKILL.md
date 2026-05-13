---
name: llm-wiki
description: Создание и поддержка Obsidian-вики из raw-источников (код, docs, papers) — извлечение, синтез, дедупликация знаний по доменам. Использовать когда пользователь просит "построить/обновить/освежить вики", "загрузить новые источники в vault", "синтезировать знания по домену". НЕ для live-запросов к кодовой базе — использовать graphify-context.
user-invocable: true
context: fork
# version: 2.2.0 | updated: 2026-05-06
# tags: obsidian, wiki, knowledge-management, llm-wiki, karpathy, ingest
# dependencies: context-awareness
# files: rules/*, schemas/*, templates/*
# changelog: 2.2.0 — multi-language sources: .py, .ts, .tsx, .js, .mjs, .sh через source_types + readers
#             2.1.0 — bootstrap интегрирован в init (автозапуск при пустых entity_types)
#             2.0.0 — локальная wiki в .wiki/.config/, domain-map перенесён из shared/
#             1.1.0 — bootstrap: автогенерация entity_types из source_paths
#             1.0.0 — initial release
---

# LLM Wiki

Скилл реализует паттерн формирования и поддержания вики для Obsidian vault: вместо поиска по сотням сырых файлов — компаундируемая wiki-база знаний, которую LLM поддерживает автоматически в разрезе доменов.

**Принцип работы:**
```
Raw Sources (неизменны) → ingest → Wiki (синтезируется) → query → Ответы
<repo>/ИИ/                         <repo>/.wiki/ии/
<repo>/Ростелеком/                 <repo>/.wiki/ростелеком/
<repo>/Прочее/Базы данных/         <repo>/.wiki/базы-данных/
```

## Когда использовать

| Ситуация | Операция |
|----------|---------|
| Написал заметку или провёл встречу | `ingest` |
| Нужен ответ на вопрос по теме | `query` |
| Хочу сохранить ответ навсегда | `query --save` |
| Проверить качество и актуальность вики | `lint` |
| Первый запуск, хочу создать вики из существующих заметок | `init` |

---

## Quick Reference

```bash
/llm-wiki ingest "ИИ/2026-04-14 Встреча по агентам.md"
/llm-wiki query "Какова архитектура потока данных ГП → ЦХД?"
/llm-wiki query "Что такое SCD2?" --save
/llm-wiki lint ростелеком
/llm-wiki init ростелеком
```

---

## Структура wiki в репозитории

```
<repo-root>/
└── .wiki/
    ├── .config/                   ← технический каталог (создаётся один раз)
    │   ├── domain-map.json      ← конфигурация доменов
    │   ├── schema.md           ← конвенции (человекочитаемые)
    │   ├── index.md            ← каталог страниц
    │   └── log.md              ← append-only лог операций
    ├── ии/                      ← домен (прямой потомок .wiki/)
    │   ├── агенты/
    │   ├── claude-code/
    │   ├── концепции/
    │   ├── инструменты/
    │   ├── паттерны/
    │   └── промпты/
    ├── ростелеком/
    │   ├── архитектура-данных/
    │   └── системная-архитектура/
    └── базы-данных/
        ├── субд/
        ├── концепции/
        └── паттерны-запросов/
```

---

## Phase 0: Определение окружения и парсинг аргументов

**Выполнять первым. Определить пути, проверить/создать структуру, затем разобрать аргументы.**

### Шаг 0.0: Определить пути

```
wiki_root = {CWD}/.wiki
wiki_dir  = {wiki_root}/.config
```

### Шаг 0.1: Проверить и создать структуру (только при первом запуске)

```
IF NOT exists {wiki_root}/:
  → Создать {wiki_root}/
  → Создать {wiki_dir}/
  → Создать {wiki_dir}/domain-map.json  ← пустой шаблон (см. ниже)
  → Создать {wiki_dir}/schema.md       ← содержимое из @rules:wiki-conventions.md
  → Создать {wiki_dir}/index.md        ← пустой индекс (см. ниже)
  → Создать {wiki_dir}/log.md          ← пустой лог (см. ниже)
  → Сообщить пользователю:
      "Создана структура wiki в {wiki_root}/"
      "Следующий шаг: /llm-wiki init <domain-id> — настроить домены и создать wiki"
  → Если текущая операция не init: предложить запустить /llm-wiki init <domain-id>

ELSE IF NOT exists {wiki_dir}/:
  → Мигрировать: создать {wiki_dir}/
  → Переместить из {wiki_root}/ в {wiki_dir}/:
      schema.md, index.md, log.md (если существуют)
  → Создать {wiki_dir}/domain-map.json если отсутствует
  → Сообщить: "Мигрировано: технические файлы перемещены в .config/"
```

**Шаблон пустого domain-map.json:**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "LLM Wiki Domain Map",
  "version": "1.0.0",
  "wiki_root": ".wiki",
  "domains": [],
  "cross_domain_rules": {
    "description": "Правила для сущностей, встречающихся в нескольких доменах",
    "rules": []
  },
  "special_source_types": {},
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
    ".tsx": {
      "reader": "typescript",
      "extract": ["public_api", "docstrings", "types", "imports"],
      "rules_file": "rules/readers/typescript.md"
    },
    ".js": {
      "reader": "javascript",
      "extract": ["public_api", "docstrings", "imports"],
      "rules_file": "rules/readers/javascript.md"
    },
    ".mjs": {
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
}
```

**Шаблон пустого index.md:**
```markdown
# Wiki Index

<!-- Этот файл обновляется автоматически при ingest/init/query --save -->

## Страницы по доменам

```

**Шаблон пустого log.md:**
```markdown
# Wiki Log

<!-- Append-only лог. Новые записи добавляются в конец. -->

```

### Шаг 0.2: Парсинг аргументов

```
1. Если операция не указана (аргументы пусты):
   → AskUserQuestion:
       Вопрос: "Что вы хотите сделать с LLM Wiki?"
       Варианты:
         • ingest     — добавить файл/заметку в wiki
         • query      — задать вопрос по теме
         • lint       — проверить качество wiki
         • init       — первичная инициализация раздела

2. Если указан id домена без операции (любой id из domain-map):
   → AskUserQuestion с теми же вариантами, сохранить домен

3. Если операция указана без обязательного аргумента или требует подтверждения:
   - ingest без файла   → AskUserQuestion: "Укажите путь к файлу-источнику"
   - query без вопроса  → AskUserQuestion: "Введите ваш вопрос"
   - init без section   → AskUserQuestion: "Выберите домен для инициализации"
                           Варианты: из domain-map.domains[].id

4. После получения всех аргументов — перейти к Phase 1
```

---

## Phase 1: Инициализация (при каждом вызове)

```
1. Читать {wiki_dir}/domain-map.json
   → загрузить домены, entity_types, extraction_cues, cross_domain_rules

2. Читать {wiki_dir}/schema.md
   → загрузить конвенции вики

3. Читать {wiki_dir}/index.md
   → получить список существующих wiki-страниц

4. Определить операцию из аргументов пользователя
```

---

## Phase 2: Выполнение операции

### Операция: ingest

**Назначение:** Прочитать файл-источник, извлечь сущности, обновить wiki-страницы.

**Детальный алгоритм:** `@rules:ingest-rules.md`

```
ВХОД: путь к файлу-источнику

1. Определить домен по пути (сопоставить с domain-map.source_paths)
   Если источник в !Daily/ или домен не определён → определять по содержимому

1а. Проверить entity_types домена:
    IF entity_types пусты:
      → Предупредить: "Домен «{id}» не настроен (entity_types пусты).
        Для корректного извлечения сущностей сначала запустите:
        /llm-wiki init {domain-id}
        Продолжить ingest без entity_types? (сущности не будут извлечены)"
      → AskUserQuestion:
          Варианты: продолжить без извлечения сущностей | отменить
      Если продолжить: выполнить только шаги 2, 7, 8 (без шагов 3, 4, 5 — нет entity_types для извлечения)
      Если отменить: завершить

1.5. Source Type Resolution:
     a. ext = lowercase расширение файла
     b. Найти ext в domain-map.source_types
     c. Если найдено → загрузить @rules:readers/{source_types[ext].reader}.md
     d. Если не найдено → AskUserQuestion: plain text | пропустить
     (Детали: @rules:ingest-rules.md#source-type-resolution)

2. Прочитать файл через Read tool

3. Для каждого entity_type домена:
   - Найти сущности по extraction_cues
   - Подсчитать упоминания
   - Решение CREATE / UPDATE / SKIP (по @rules:ingest-rules)

4. Для cross-domain сущностей → применить cross_domain_rules

5. CREATE: создать страницу по @template:wiki-page, wiki_status="stub"
   UPDATE: прочитать страницу, добавить новую информацию, НЕ удалять старое

6. Обновить wiki_sources, wiki_updated на созданных/обновлённых страницах

7. APPEND запись в {wiki_dir}/log.md по @template:log-entry

8. Обновить {wiki_dir}/index.md (новые страницы)

ВЫХОД: отчёт (создано N, обновлено M, пропущено K)
```

**Важно:** Источники НЕ модифицируются. Синтез — не копирование.

---

### Операция: query [--save]

**Назначение:** Ответить на вопрос используя wiki; при --save сохранить ответ.

```
ВХОД: вопрос (строка), опция --save

1. По ключевым словам определить домен(ы) вопроса

2. Из {wiki_dir}/index.md найти релевантные страницы

3. Прочитать wiki-страницы (приоритет: mature > developing > stub)

4. Если wiki недостаточна → прочитать источники из wiki_sources найденных страниц

5. Сформировать ответ с WikiLinks на использованные страницы

6. Если --save:
   a. Определить имя страницы (kebab-case из ключевых слов вопроса)
   b. Определить папку домена: {wiki_root}/{domain-id}/{subfolder}/
   c. Создать страницу по @template:wiki-page
   d. APPEND в {wiki_dir}/log.md
   e. Добавить в {wiki_dir}/index.md

ВЫХОД: ответ + [опционально] путь к сохранённой странице
```

---

### Операция: lint [section]

**Назначение:** Проверить качество и актуальность wiki.

**Критерии проверок:** `@rules:lint-criteria.md`

```
ВХОД: section (опционально: id домена из domain-map)

1. Glob ".md" файлы в {wiki_root}/{section}/** (или всей вики)
   Исключить: {wiki_dir}/index.md, {wiki_dir}/log.md, {wiki_dir}/schema.md

2. Для каждого файла: FM-* проверки (frontmatter)
3. Батч: CT-003 мёртвые WikiLinks, CT-004 orphan-страницы
4. ST-* проверки структуры ({wiki_dir}/index.md vs реальные файлы)
5. CV-* проверки покрытия (источники без ingest)

ВЫХОД: отчёт по формату @rules:lint-criteria.md#Формат отчёта lint
```

---

### Операция: init <section>

**Назначение:** Первичная инициализация раздела вики из всего корпуса источников.

```
ВХОД: section (domain-id из domain-map), опция --dry-run

1. Из domain-map получить source_paths домена

1а. Проверить entity_types домена:
    IF entity_types пусты:
      → Сообщить: "Домен «{id}» не имеет entity_types. Запускаю анализ источников..."
      → Выполнить bootstrap-анализ:

      [bootstrap-анализ]
      а) Построить glob-паттерн из ключей domain-map.source_types:
         extensions = ключи source_types без точки (["md","py","ts","js","sh"])
         pattern = "**/*.{" + extensions.join(",") + "}"
         Glob {pattern} по source_paths
         Исключить: *.excalidraw.md, node_modules/, __pycache__/, .git/
         Если 0 файлов → ошибка: "Файлы не найдены в source_paths"
         Если файлов ≥ 50 → AskUserQuestion:
           "Найдено {N} файлов. Анализ займёт много токенов. Продолжить?"
           Варианты: да, продолжить | нет, отменить

      б) Прочитать ВСЕ найденные файлы (Read tool)
         Для .md файлов: собрать #теги из frontmatter, заголовки H1/H2/H3,
                         повторяющиеся именованные существительные
         Для кода (.py/.ts/.js/.sh): применить соответствующий @rules:readers/*.md,
                         собрать публичные функции/классы/типы как кандидатов entity_types
         Во всех случаях: искать повторяющиеся понятия ≥ 3 упоминаний

      в) Сгенерировать черновик entity_types — 3–7 типов:
         - type: короткий id в kebab-case
         - description: одно предложение
         - extraction_cues: 5–10 ключевых слов
         - min_mentions_for_page: 1 или 2–3
         - wiki_subfolder: "{domain-id}/{type}s"
         Также: tags (если текущее значение []), language_notes (если "")

      г) Показать черновик через AskUserQuestion:
         "Проанализировано {N} файлов. Черновик entity_types для домена «{name}»:
          {список типов с описаниями}
          Подтвердить перед запуском init?"
         Варианты:
           • подтвердить и продолжить init
           • исключить типы — указать id через запятую
           • отменить init

         Если "исключить типы":
           → AskUserQuestion: "Введите id типов для удаления (через запятую)"
           → Удалить, показать обновлённый черновик, снова запросить подтверждение
           → Если entity_types стал пустым → сообщить и предложить только "отменить"

         Если "отменить":
           → завершить выполнение init

      д) Записать entity_types (и tags/language_notes если были пустыми)
         в {wiki_dir}/domain-map.json (Write tool)
         Сообщить: "entity_types сохранены. Продолжаю init..."

      е) Сохранить список файлов как $source_files_list
         (используется на шаге 2 — повторный Glob не нужен)
      [/bootstrap-анализ]

    ELSE (entity_types непусты):
      → Продолжить как обычно

2. Получить список файлов:
   IF $source_files_list уже собран (после bootstrap-анализа) → использовать его
   ELSE:
     extensions = ключи domain-map.source_types без точки
     pattern = "**/*.{" + extensions.join(",") + "}"
     Glob {pattern} по source_paths
     Исключить: *.excalidraw.md, node_modules/, __pycache__/, .git/

3. Приоритизировать:
   - HLD-документы (path содержит "HLD") → первыми
   - Архитектурные заметки (Best Practices, Template) → вторыми
   - Daily notes → последними

4. Batch обработка по batch_size=10:
   Для каждого файла → выполнить шаги 2-6 из алгоритма ingest
   После каждого batch → обновить {wiki_dir}/log.md и {wiki_dir}/index.md

5. Итоговый отчёт + рекомендация запустить lint

ВЫХОД: сводный отчёт по всему домену
```

**Использовать один раз.** При повторном запуске без --force — пропускает уже ingested файлы.

**Bootstrap-анализ** запускается автоматически если `entity_types` домена пусты. При повторном `init` на уже настроенном домене этот шаг пропускается.

---

## Phase 3: Валидация и отчёт

После каждой операции:

1. Убедиться что `{wiki_dir}/log.md` обновлён
2. Убедиться что `{wiki_dir}/index.md` актуален (новые страницы добавлены)
3. Вывести отчёт пользователю

**Формат отчёта (все операции):**
```
Операция: {тип}
Домен: {домен}
Время: {timestamp}

{специфика операции}

Следующий шаг: {рекомендация}
```

---

## Правила и конвенции

| Файл | Содержание |
|------|-----------|
| `@rules:ingest-rules.md` | Алгоритм CREATE/UPDATE/SKIP, разрешение противоречий |
| `@rules:wiki-conventions.md` | Язык, структура страниц, WikiLinks, frontmatter |
| `@rules:lint-criteria.md` | Таблица всех проверок FM/CT/ST/CV |
| `@rules:readers/{markdown,python,typescript,javascript,bash}.md` | Язык-специфичные правила извлечения сущностей (см. ниже) |
| `{wiki_dir}/domain-map.json` | Домены, source_paths, entity_types, extraction_cues |
| `@template:wiki-page.json` | Шаблон новой wiki-страницы |
| `@template:log-entry.json` | Шаблон записи в log.md |

---

## Readers (язык-специфичные правила)

Файлы `rules/readers/*.md` определяют, **что извлекать** и **как именовать wiki-страницы** для каждого расширения. Сопоставление расширения → reader → файл правил задано в `domain-map.json::source_types[ext]`.

| Reader | Расширения | Извлекает |
|--------|-----------|-----------|
| `markdown` | `.md` | narrative, frontmatter, code_blocks, headings |
| `python` | `.py` | public_api, docstrings, types, imports |
| `typescript` | `.ts`, `.tsx` | public_api, docstrings, types, imports |
| `javascript` | `.js`, `.mjs` | public_api, docstrings, imports |
| `bash` | `.sh` | functions, flags, exports, comments |

### Где применяются

| Операция | Использование |
|----------|---------------|
| `ingest` | Шаг 1.5 (Source Type Resolution): по расширению файла загрузить `@rules:readers/{reader}.md` перед шагом 3 (извлечение сущностей). Правила reader'а определяют: что считать сущностью, какие приватные/служебные конструкции игнорировать, как формировать имя wiki-страницы, какие поля попадают в раздел "Сигнатура"/"API". |
| `init` (bootstrap-анализ) | Шаг 1а.б: для каждого найденного файла применить соответствующий reader, чтобы собрать кандидатов в `entity_types` (публичные функции/классы/типы для кода; теги/заголовки для markdown). Reader формирует список повторяющихся понятий ≥ 3 упоминаний. |
| `init` (основной проход) | Шаг 4: batch обработка вызывает алгоритм `ingest`, который сам выполняет шаг 1.5 (см. выше) — отдельной активации не требуется. |
| `lint` | При проверке wiki-страниц с `wiki_sources`, указывающим на код (`.py`/`.ts`/`.js`/`.sh`): сверять имена сущностей с правилами именования из reader'а (kebab-case согласно "Правила именования"); проверять, что для функций/классов присутствуют разделы "Сигнатура"/"API" в соответствии с разделом "Правила синтеза" reader'а. Расхождения помечать как `CV-*` (coverage) или `ST-*` (structure). |

### Расширение

Чтобы добавить новый язык:
1. Создать `rules/readers/{language}.md` по образцу существующих (разделы: «Что искать» с подсписком «Игнорировать», «Правила именования», «Правила синтеза», «Пример»).
2. Добавить запись в `domain-map.json::source_types[".ext"]` с `reader`, `extract`, `rules_file`.
3. Ingest/init подхватят автоматически; для lint — добавить проверки в `@rules:lint-criteria.md` если нужны язык-специфичные критерии.

---

## Примеры использования

- `@example:ingest-example.md` — ingest файла о версионировании данных
- `@example:query-example.md` — query с сохранением страницы
- `@example:lint-example.md` — lint домена с отчётом об ошибках
