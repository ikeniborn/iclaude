---
name: compact-session
description: This skill should be used when the user asks to "analyze session", "summarize session", "compact session", "what happened in session", "/compact-session", or provides a path to a .jsonl session file and wants a summary of what was done.
version: 2.0.0
context: fork
model: haiku
allowed-tools: Read, Write, Bash
---

# compact-session

Analyze a Claude Code session JSONL file and generate a structured Markdown summary.

## Finding the session file

The user must provide a path to a `.jsonl` session file as an argument.
The path is available as a clickable 📄 link in the status line (OSC8 hyperlink).

If no path was provided → ask the user to pass it:
> "Передай путь к файлу сессии (`.jsonl`). Его можно скопировать из 📄 ссылки в строке состояния."

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

## Saving the report

After generating the Markdown report, save it to a file in the project's `tmp/` directory:

1. Run `mkdir -p tmp` via Bash to ensure the directory exists.
2. Run `date +%Y%m%d-%H%M%S` via Bash to get a timestamp.
3. Write the report to `tmp/compact-session-<timestamp>.md` using the Write tool
   (absolute path: prepend the result of `pwd` to the filename).
4. Tell the user the saved path:
   > "Отчёт сохранён: `tmp/compact-session-<timestamp>.md`"

Use the current working directory (project root where the session was opened).
Do **not** save to the system `/tmp` — always use the project-local `tmp/` folder.
