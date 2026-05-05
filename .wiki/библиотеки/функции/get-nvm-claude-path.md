---
wiki_sources:
  - "lib/nvm/detect.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - functions
  - lib
  - iclaude
aliases:
  - "get_nvm_claude_path"
---

# get_nvm_claude_path

`get_nvm_claude_path()` — возвращает путь к исполняемому файлу Claude Code в NVM окружении. Поддерживает нативный бинарник (v2.1.114+) и legacy cli.js.

## Основные характеристики

Модуль: `lib/nvm/detect.sh`

Порядок поиска (в двух контекстах: `$NVM_DIR/versions/node/$current_node/` и `npm prefix -g`):

1. `bin/claude` — стандартный symlink (наиболее часто)
2. `bin/.claude-*` — временные бинарники при обновлении (по mtime, новейший первым)
3. `lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe` — нативный бинарник (v2.1.114+, ~237MB)
4. `lib/node_modules/@anthropic-ai/claude-code/cli.js` → возвращает `"node /path/cli.js"` (legacy)
5. Временные `.claude-code-*/cli.js` папки (по mtime)

Возвращает строку. Для legacy пути возвращает `"node /path/cli.js"` — `launch_claude()` разбивает через `read -ra` для корректного exec.

Нативный бинарник (`claude.exe`) исключён из git (>100MB). После `git clone` необходимо `--repair-isolated` для скачивания через npm postinstall.

## Связанные концепции

- [[библиотека/функции/detect-nvm]]
- [[библиотека/функции/setup-isolated-nvm]]
- [[библиотека/категории/nvm]]
- [[библиотека/функции/launch-claude]]
