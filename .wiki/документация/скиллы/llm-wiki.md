---
wiki_sources:
  - "[[.nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md]]"
  - "[[docs/audits/2026-05-08-skills-description-audit.md]]"
wiki_updated: 2026-05-08
wiki_status: stub
wiki_outgoing_links:
  - "[[документация/функции/graphify]]"
tags:
  - iclaude
  - documentation
  - skill
  - wiki
aliases:
  - "LLM Wiki"
  - "llm-wiki"
---

# llm-wiki

Claude Code skill, реализующий паттерн компаундируемой вики для Obsidian vault: raw-источники остаются неизменными, а синтезированная база знаний автоматически поддерживается LLM в разрезе доменов. Альтернатива поиску по сотням сырых файлов — структурированные wiki-страницы с WikiLinks между сущностями.

## Основные характеристики

- **Версия:** 2.2.0 (2026-05-06); user-invocable, context: fork
- **Принцип:** Raw Sources (неизменны) → `ingest` → Wiki (синтезируется) → `query` → Ответы
- **Структура хранения:** `<repo>/.wiki/.config/` — технический каталог (domain-map.json, schema.md, index.md, log.md); `<repo>/.wiki/<домен>/` — wiki-страницы домена
- **Домены настраиваются** в `.wiki/.config/domain-map.json` через массив `domains[]` с полями `id`, `source_paths`, `entity_types`, `wiki_subfolder`
- **Multi-language sources** (с v2.2.0): извлечение из `.md`, `.py`, `.ts`, `.tsx`, `.js`, `.mjs`, `.sh` через `source_types` + readers
- **Неизменность источников:** исходные файлы только читаются (Read tool), синтез в wiki — переработка, не копирование (исключение: SQL-запросы и конфигурации в code-блоках)
- **Компаундируемость:** при UPDATE старая информация не удаляется, новая приписывается к источнику с датой; при противоречиях — обе версии с явной атрибуцией

## Операции

### ingest

Прочитать файл-источник, извлечь сущности по `extraction_cues` домена, обновить wiki-страницы (CREATE/UPDATE/SKIP).

- Решение CREATE — если страницы нет и `mentions ≥ min_mentions_for_page`
- Решение UPDATE — если страница есть и в источнике новая информация
- Решение SKIP — иначе (с логированием причины)
- Источник добавляется в `wiki_sources` страницы

### query [--save]

Ответить на вопрос, используя релевантные wiki-страницы (приоритет: `mature` > `developing` > `stub`). Если вики недостаточна — читать источники из `wiki_sources` найденных страниц. С `--save` сохранять ответ как новую страницу в соответствующем поддомене.

### lint [section]

Проверить качество и актуальность wiki: FM-* (frontmatter), CT-* (мёртвые WikiLinks, orphan-страницы), ST-* (структура index.md vs реальные файлы), CV-* (источники без ingest).

### init <section>

Первичная инициализация раздела вики из всего корпуса источников. Если `entity_types` домена пусты — автоматически запускается **bootstrap-анализ**: чтение всех файлов по `source_types`, генерация черновика 3–7 типов сущностей с подтверждением через `AskUserQuestion`. Далее batch-обработка по 10 файлов с приоритетом HLD → Best Practices → Daily notes.

## Архитектура skill-а

Skill состоит из:
- `SKILL.md` — точка входа с фазами Phase 0 (окружение и парсинг аргументов), Phase 1 (инициализация), Phase 2 (выполнение операции), Phase 3 (валидация и отчёт)
- `rules/ingest-rules.md` — алгоритм CREATE/UPDATE/SKIP, разрешение противоречий
- `rules/wiki-conventions.md` — конвенции (язык, структура, WikiLinks, frontmatter)
- `rules/lint-criteria.md` — таблица проверок FM/CT/ST/CV
- `rules/readers/{markdown,python,typescript,javascript,bash}.md` — язык-специфичные правила извлечения
- `templates/wiki-page.json`, `templates/log-entry.json` — шаблоны страниц и записей лога

## Readers

Файлы `rules/readers/*.md` определяют, что извлекать и как именовать wiki-страницы для каждого расширения. Сопоставление расширения → reader задано в `domain-map.json::source_types[ext]`.

| Reader | Расширения | Извлекает |
|--------|-----------|-----------|
| markdown | `.md` | narrative, frontmatter, code_blocks, headings |
| python | `.py` | public_api, docstrings, types, imports |
| typescript | `.ts`, `.tsx` | public_api, docstrings, types, imports |
| javascript | `.js`, `.mjs` | public_api, docstrings, imports |
| bash | `.sh` | functions, flags, exports, comments |

Расширение языка: создать `rules/readers/{language}.md` (разделы «Что искать», «Правила именования», «Правила синтеза», «Пример») и добавить запись в `domain-map.json::source_types[".ext"]`.

## Триггеры использования

| Ситуация | Операция |
|----------|---------|
| Написал заметку или провёл встречу | `ingest` |
| Нужен ответ на вопрос по теме | `query` |
| Хочу сохранить ответ навсегда | `query --save` |
| Проверить качество и актуальность вики | `lint` |
| Первичная инициализация раздела из корпуса источников | `init` |

## Маршрутизация (frontmatter description)

По итогам аудита `description:` всех 13 скиллов (2026-05-08) каноническая формулировка для `llm-wiki`:

> Создание и поддержка Obsidian-вики из raw-источников (код, docs, papers) — извлечение, синтез, дедупликация знаний по доменам. Использовать когда пользователь просит "построить/обновить/освежить вики", "загрузить новые источники в vault", "синтезировать знания по домену". НЕ для live-запросов к кодовой базе — использовать graphify-context.

**Границы относительно соседних скиллов:**

- **vs `graphify`** — `graphify` строит граф знаний из папки файлов с community detection и тремя артефактами (HTML / GraphRAG JSON / GRAPH_REPORT.md); `llm-wiki` синтезирует Obsidian-вики со структурированными страницами и WikiLinks. Разные форматы вывода для разных целей (анализ связей vs читаемая база знаний).
- **vs `graphify-context`** — `graphify-context` отвечает на live-запросы к уже построенному графу; `llm-wiki` — отдельный процесс синтеза/поддержки вики.
- **vs `context-awareness`** — `context-awareness` определяет язык/framework/команды проекта в Phase 0 задачи; `llm-wiki` не дублирует эту функцию.

См. [[документация/архитектура/skills-маршрутизация]] (если будет создана) и `docs/audits/2026-05-08-skills-description-audit.md`.

## Связанные концепции

- [[документация/функции/graphify]]
