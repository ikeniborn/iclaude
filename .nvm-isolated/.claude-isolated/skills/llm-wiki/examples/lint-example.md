# Example: lint — Проверка домена базы-данных

## Сценарий

После нескольких операций ingest пользователь хочет проверить качество wiki-страниц в разделе баз данных.

## Команда

```
/llm-wiki lint базы-данных
```

---

## Шаг 1: Загрузка контекста

```
Claude читает:
1. @shared:domain-map.json → wiki_folder для домена "базы-данных"
2. vaults/Work/!Wiki/schema.md
3. vaults/Work/!Wiki/index.md → список страниц домена
```

## Шаг 2: Сбор файлов

```
Glob: vaults/Work/!Wiki/базы-данных/**/*.md

Найдено 4 файла:
  - базы-данных/субд/clickhouse.md
  - базы-данных/субд/greenplum.md
  - базы-данных/концепции/партиционирование.md
  - базы-данных/паттерны-запросов/window-functions.md
```

## Шаг 3: Проверки каждого файла

### clickhouse.md — проверки FM-*

```yaml
wiki_sources: ["vaults/Work/Ростелеком/...Best Practices...md"]  # FM-001 ✓
wiki_updated: "2026-04-14"                                         # FM-002 ✓
wiki_status: "stub"                                                # FM-003 ✓
tags: ["database", "database/name/clickhouse"]                     # FM-004 ✓
# aliases отсутствует                                              # FM-006 ℹ
```

Контент: 5 предложений, есть H1 и вводный абзац → CT-001 ✓

### greenplum.md — проверки FM-*

```yaml
wiki_sources: []   # ПУСТО → FM-001 ERROR ✗
wiki_updated: "2026-04-14"
wiki_status: "stub"
```

### партиционирование.md

```yaml
wiki_sources: ["vaults/Work/Прочее/Базы данных/ClickHouse/Партиционирование.md"]  # FM-005: проверить
wiki_updated: "2026-02-10"   # 63 дня назад, status=stub → CT-002 WARNING
wiki_status: "stub"
```

WikiLinks: содержит `[[clickhouse-v24]]` → файл не существует → CT-003 WARNING

### window-functions.md

Нет входящих ссылок из других страниц → CT-004 INFO (orphan)

## Шаг 4: Батч-проверки

**CT-003 (мёртвые WikiLinks):**
- Собраны все WikiLinks из 4 файлов
- `[[clickhouse-v24]]` → файл не существует → WARNING

**CT-004 (orphan):**
- `window-functions.md` — нет входящих ссылок → INFO

**ST-002 (рассинхрон index.md):**
- `window-functions.md` добавлен после последнего обновления index.md → WARNING

## Шаг 5: Покрытие CV-*

```
Glob: vaults/Work/Прочее/Базы данных/**/*.md → 95 файлов
Wiki_sources упоминают: 3 файла
Не ingested: 92 файла > 7 дней → CV-001 INFO (x92)
```

## Итоговый отчёт

```markdown
# Lint Report — базы-данных

**Дата:** 2026-04-14
**Проверено страниц:** 4

## Итого

| Уровень | Количество |
|---------|-----------|
| Errors | 1 |
| Warnings | 3 |
| Info | 3 |

---

## Errors (требуют исправления)

### [FM-001] Отсутствуют wiki_sources

**Файл:** `vaults/Work/!Wiki/базы-данных/субд/greenplum.md`
**Детали:** wiki_sources пустой массив
**Рекомендация:** Запустить `/llm-wiki ingest` для файлов о GreenPlum из
`vaults/Work/Прочее/Базы данных/` или удалить страницу

---

## Warnings

### [CT-002] Stub-страница без обновлений > 30 дней

**Файл:** `vaults/Work/!Wiki/базы-данных/концепции/партиционирование.md`
**Детали:** wiki_status=stub, wiki_updated=2026-02-10 (63 дня назад)
**Рекомендация:** `/llm-wiki ingest "vaults/Work/Прочее/Базы данных/ClickHouse/Партиционирование.md"`

### [CT-003] Мёртвая WikiLink

**Файл:** `vaults/Work/!Wiki/базы-данных/концепции/партиционирование.md`
**Детали:** Ссылка [[clickhouse-v24]] — файл не существует
**Рекомендация:** Удалить ссылку или создать страницу clickhouse-v24.md через ingest

### [ST-002] Страница не в index.md

**Файл:** `vaults/Work/!Wiki/базы-данных/паттерны-запросов/window-functions.md`
**Детали:** Файл существует, но не упомянут в index.md
**Рекомендация:** Добавить в раздел "Базы данных" в index.md

---

## Info

### [FM-006] Отсутствуют aliases

**Файл:** `vaults/Work/!Wiki/базы-данных/субд/clickhouse.md`
**Рекомендация:** Добавить aliases: ["CH", "КликХаус", "ClickHouse OLAP"]

### [CT-004] Orphan-страница

**Файл:** `vaults/Work/!Wiki/базы-данных/паттерны-запросов/window-functions.md`
**Детали:** Нет входящих WikiLinks из других страниц вики
**Рекомендация:** Добавить [[window-functions]] в раздел "Связанные концепции" на странице clickhouse.md

### [CV-001] Источники без ingest (92 файла)

**Домен:** базы-данных
**Рекомендация:** `/llm-wiki init базы-данных` для первичного покрытия

---

## Следующие шаги

1. Исправить FM-001 в greenplum.md (критично)
2. Запустить `/llm-wiki ingest` для партиционирование.md (обновить stub)
3. Запустить `/llm-wiki init базы-данных` для покрытия 92 источников
```
