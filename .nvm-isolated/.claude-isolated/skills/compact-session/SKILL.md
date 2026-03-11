---
name: compact-session
description: This skill should be used when the user asks to "analyze session", "summarize session", "compact session", "what happened in session", "/compact-session", or provides a path to a .toon session file and wants a summary of what was done.
version: 1.0.0
context: fork
model: haiku
allowed-tools: Read
---

# compact-session

Analyze a `.toon` session file and generate a structured Markdown summary of the work done.

## TOON Format

Session files use the TOON format. The first line is a header:

```
[N]{field1,field2,...}:
```

Each subsequent row has two leading spaces with comma-separated values. Quoted strings may contain `\n` escape sequences.

For conversation sessions the columns are `role`, `type`, `content`:

- `role`: `user` | `assistant`
- `type`: `text` | `thinking` | `tool_use` | `tool_result`

## Noise Filtering

Skip `user,text` rows whose content starts with any of:
`<local-command-caveat>`, `<command-name>`, `<local-command-stdout>`, `<command-message>`

Also skip skill/command body expansions injected into `user,text` — recognisable as long multi-section markdown starting with `## Правила`, `## Алгоритм`, `## Instructions`, or `## Your task`.

Skip meta-commands in user requests: `/clear`, `/verify`, `/terminal-setup`, `/compact-session`.

## Reading assistant rows

- `assistant,text` — primary source. When a row is a one-liner label (`"Смотрю код:"`, `"Исправляю:"`, `"Проверяю синтаксис:"`) — supplement it with adjacent `assistant,thinking` rows to reconstruct what actually happened.
- `assistant,thinking` — use actively to fill gaps; summarise the reasoning, never quote verbatim.

## Output Format

Write the report **in Russian**. Use Markdown with the sections below. One bullet per line. Total ≤ 150 lines.

Do not include: file paths to the session file, UUIDs, `.toon` filenames, dates, message counts, or any other meta-information about the file itself. Report only the substance of what was discussed and done.

### Цель сессии
Main goal in one sentence (from first substantive user message).

### Что запрашивалось
One bullet per distinct user task, condensed to one line.

### Что было сделано
For each task — what the assistant actually did:
- Изменённые файлы (пути если упоминались)
- Найденные и исправленные баги (`файл:строка` если доступно)
- Коммиты (хеш если упоминался)
- Ключевые решения и объяснения

### Проблемы
- Ошибки, заблокированные вызовы, сбои
- Как каждая была решена

### Итог
- Финальное состояние после сессии
- Нерешённые вопросы или follow-up пункты

### TL;DR
One paragraph, 2–4 sentences, in Russian, plain language.

Do not quote large content verbatim. Focus on intent and outcomes.
