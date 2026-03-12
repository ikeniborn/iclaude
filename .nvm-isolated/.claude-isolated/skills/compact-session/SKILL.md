---
name: compact-session
description: This skill should be used when the user asks to "analyze session", "summarize session", "compact session", "what happened in session", "/compact-session", or provides a path to a .jsonl session file and wants a summary of what was done.
version: 2.0.0
context: fork
model: haiku
allowed-tools: Read
---

# compact-session

Analyze a Claude Code session JSONL file and generate a structured Markdown summary.

## Finding the session file

If the user provided a path to a `.jsonl` file → use that path directly.

Otherwise → read the file `.claude/.current-session` in the current project directory.
Its content is an absolute path to the current session's JSONL file.
Use the Read tool to read `.claude/.current-session`, then read the JSONL file at that path.

## JSONL Format

Each line is an independent JSON object. Parse each line separately.

### User message
```json
{"type": "user", "message": {"role": "user", "content": "текст запроса"}, "uuid": "...", "timestamp": "..."}
```
`content` may be a string or an array of blocks.

### Assistant message
```json
{"message": {"role": "assistant", "content": [
  {"type": "thinking", "thinking": "внутренние рассуждения"},
  {"type": "text", "text": "ответ пользователю"},
  {"type": "tool_use", "name": "Bash", "input": {"command": "..."}}
]}, "uuid": "...", "timestamp": "..."}
```

### Tool result (user turn with tool output)
```json
{"type": "user", "message": {"role": "user", "content": [
  {"type": "tool_result", "tool_use_id": "...", "content": "вывод инструмента"}
]}}
```

### Service entries (skip these)
- `{"type": "file-history-snapshot", ...}` — пропустить
- Lines with only `parentUuid`, `isSidechain`, `sessionId` (no `message`) — пропустить

## Noise Filtering

Skip `user` message `content` that starts with:
`<local-command-caveat>`, `<command-name>`, `<local-command-stdout>`, `<command-message>`

Skip skill/command body injections — long multi-section markdown starting with
`## Правила`, `## Алгоритм`, `## Instructions`, `## Your task`.

Skip meta-commands: `/clear`, `/verify`, `/terminal-setup`, `/compact-session`.

## Reading assistant content

- `text` blocks — primary source
- `thinking` blocks — use to fill gaps; summarise reasoning, never quote verbatim
- `tool_use` blocks — identify which tools were used and what was done
- `tool_result` blocks (in user messages) — use only if essential to understand outcome

## Output Format

Write the report **in Russian**. Use Markdown. Total ≤ 150 lines.

Do not include: file paths to the session file, UUIDs, timestamps, message counts,
or any meta-information about the file itself. Report only what was discussed and done.

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
