---
wiki_sources:
  - "lib/update/update.sh"
  - "lib/update/isolated.sh"
  - "lib/update/cleanup.sh"
wiki_updated: 2026-05-05
wiki_status: stub
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/update"
  - "update module"
---

# update

Подсистема `lib/update/` — обновление Claude Code в изолированном окружении через npm, сохранение lockfile и ротация устаревших артефактов.

## Основные характеристики

Файловый состав (3 модуля):

| Файл | Содержимое |
|------|-----------|
| `update.sh` | `update_claude_code()` — `npm install -g @anthropic-ai/claude-code` + save lockfile |
| `isolated.sh` | Обновление в изолированном окружении |
| `cleanup.sh` | Ротация устаревших версий и нативных бинарников |

После обновления рекомендуется проверить lockfile и запустить `--test` для проверки прокси.

Команда: `./iclaude.sh --update`.

## Связанные концепции

- [[библиотека/категории/nvm]]
- [[библиотека/категории/lockfile]]
