---
wiki_sources:
  - "lib/nvm/detect.sh"
  - "lib/nvm/setup.sh"
  - "lib/nvm/cleanup.sh"
  - "lib/nvm/install.sh"
  - "lib/nvm/repair.sh"
  - "lib/nvm/claude.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/nvm"
  - "nvm module"
---

# nvm

Подсистема `lib/nvm/` — управление изолированным Node.js окружением. Отвечает за обнаружение NVM, настройку PATH, поиск бинарника claude и установку/ремонт изолированного окружения `.nvm-isolated/`.

## Основные характеристики

Файловый состав (6 модулей):

| Файл | Содержимое |
|------|-----------|
| `detect.sh` | `detect_nvm()`, `get_nvm_claude_path()`, `get_cli_version()` |
| `setup.sh` | `setup_isolated_nvm()` — настройка PATH, экспорт `NVM_DIR`, `NPM_CONFIG_PREFIX` |
| `cleanup.sh` | `cleanup_isolated_nvm()` — удаление `.nvm-isolated/` с подтверждением |
| `install.sh` | `install_isolated_nvm()` — первичная установка NVM + Node.js + Claude Code |
| `repair.sh` | `repair_isolated_nvm()` — скачивание нативного бинарника, восстановление symlinks |
| `claude.sh` | Вспомогательные функции Claude Code |

`detect_nvm()` — порядок приоритетов:
1. Изолированное окружение `.nvm-isolated/` (если `USE_ISOLATED_BY_DEFAULT=true`)
2. Системный NVM (`$NVM_DIR/nvm.sh`)
3. npm/node в PATH из NVM

`get_nvm_claude_path()` — порядок поиска бинарника:
1. `$npm_prefix/bin/claude` (symlink)
2. `bin/.claude-*` (временные бинарники, по mtime)
3. `bin/claude.exe` (нативный бинарник с v2.1.114)
4. `cli.js` в `node_modules/@anthropic-ai/claude-code/` (legacy)

`setup_isolated_nvm()` задаёт:
- `NVM_DIR=$ISOLATED_NVM_DIR`
- `NPM_CONFIG_PREFIX=$NVM_DIR/npm-global`
- Prepend `$NPM_CONFIG_PREFIX/bin:$node_version_dir/bin` к PATH

## Связанные концепции

- [[библиотека/функции/detect-nvm]]
- [[библиотека/функции/get-nvm-claude-path]]
- [[библиотека/функции/setup-isolated-nvm]]
- [[библиотека/категории/core]]
