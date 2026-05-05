---
wiki_sources:
  - "lib/nvm/setup.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - functions
  - lib
  - iclaude
aliases:
  - "setup_isolated_nvm"
---

# setup_isolated_nvm

`setup_isolated_nvm()` — настраивает изолированное NVM окружение: экспортирует ключевые переменные и prepend-ит изолированные пути в `$PATH`.

## Основные характеристики

Модуль: `lib/nvm/setup.sh`

Выполняемые действия:

1. Экспорт `NVM_DIR=$ISOLATED_NVM_DIR`
2. Экспорт `NPM_CONFIG_PREFIX=$NVM_DIR/npm-global`
3. Экспорт `ISOLATED_CONFIG_DIR=$ISOLATED_NVM_DIR/.claude-isolated`
4. Поиск Node.js: `find $NVM_DIR/versions/node -maxdepth 1 -type d -name "v*"` → сортировка `LC_ALL=C sort | tail -1` (детерминированный выбор новейшей версии)
5. Prepend PATH: `$NPM_CONFIG_PREFIX/bin:$node_version_dir/bin:$PATH`
6. `CLAUDE_CODE_ENABLE_TASKS=true` (если не переопределён)
7. `load_claude_config()` (из `lib/config/isolated.sh`) — загрузка `.claude_config`
8. `repair_plugin_paths "quiet"` — тихий авторемонт symlinks LSP

Вызывается из `detect_nvm()` при обнаружении изолированного окружения.

Сортировка `LC_ALL=C sort`: необходима для детерминированного поведения на разных файловых системах (порядок вывода `find` не гарантирован на ext4).

## Связанные концепции

- [[библиотека/функции/detect-nvm]]
- [[библиотека/категории/nvm]]
- [[библиотека/категории/config]]
