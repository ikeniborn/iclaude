---
wiki_sources:
  - "lib/lockfile/install.sh"
  - "lib/lockfile/save.sh"
wiki_updated: 2026-05-05
wiki_status: stub
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/lockfile"
  - "lockfile module"
---

# lockfile

Подсистема `lib/lockfile/` — версионирование установки через `.nvm-isolated-lockfile.json`. Обеспечивает воспроизводимость: позволяет зафиксировать точные версии Node.js и Claude Code и восстановить их на другом хосте.

## Основные характеристики

Файловый состав (2 модуля):

| Файл | Содержимое |
|------|-----------|
| `save.sh` | `save_lockfile()` — запись текущих версий в lockfile |
| `install.sh` | `install_from_lockfile()` — установка точных версий из lockfile |

Lockfile: `.nvm-isolated-lockfile.json` в корне проекта. Хешируется при каждом запуске — при изменении предупреждает о необходимости пересборки.

Переменная `LOCKFILE_HASH_FILE`: `.nvm-isolated/.claude-isolated/.last-lockfile-hash` — хранит последний известный хеш для детектирования изменений.

Команды: `--update` сохраняет lockfile после обновления; `--install-from-lockfile` восстанавливает точные версии.

## Связанные концепции

- [[библиотека/категории/nvm]]
- [[библиотека/категории/update]]
