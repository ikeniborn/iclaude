---
wiki_sources:
  - "lib/statusline/detect.sh"
  - "lib/statusline/install.sh"
  - "lib/statusline/status.sh"
wiki_updated: 2026-05-05
wiki_status: stub
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/statusline"
  - "statusline module"
---

# statusline

Подсистема `lib/statusline/` — строка статуса с мониторингом использования токенов, кеша, стоимости сессии и активных компонентов (PII proxy, router, microVM).

## Основные характеристики

Файловый состав (3 модуля):

| Файл | Содержимое |
|------|-----------|
| `detect.sh` | `detect_statusline()` — проверка наличия oh-my-posh |
| `install.sh` | `install_statusline()` — установка |
| `status.sh` | `check_statusline_status()` |

Сигнальные переменные (устанавливаются в `launch_claude()`):
- `ICLAUDE_ROUTER_ACTIVE=1` — подавляет отображение RL в строке статуса
- `ICLAUDE_PII_ACTIVE=1` — включает отображение PII метрик
- `ICLAUDE_PII_ACTIVE_PORT` — порт PII proxy
- `ICLAUDE_MICROVM_ACTIVE=1` — активен microVM режим

Установка через `--install-lsp` (вместе с oh-my-posh).

## Связанные концепции

- [[библиотека/категории/ohmyposh]]
- [[библиотека/категории/pii-proxy]]
- [[библиотека/категории/launcher]]
