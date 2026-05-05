---
wiki_sources:
  - "lib/ohmyposh/detect.sh"
  - "lib/ohmyposh/install.sh"
  - "lib/ohmyposh/status.sh"
wiki_updated: 2026-05-05
wiki_status: stub
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/ohmyposh"
  - "ohmyposh module"
  - "oh-my-posh module"
---

# ohmyposh

Подсистема `lib/ohmyposh/` — управление oh-my-posh для расширенной строки статуса терминала с метриками Claude Code.

## Основные характеристики

Файловый состав (3 модуля):

| Файл | Содержимое |
|------|-----------|
| `detect.sh` | `detect_ohmyposh()` — обнаружение oh-my-posh |
| `install.sh` | `install_ohmyposh()` — установка |
| `status.sh` | `check_ohmyposh_status()` |

Используется совместно с подсистемой statusline для отображения контекстной информации о сессии Claude Code.

## Связанные концепции

- [[библиотека/категории/statusline]]
