---
wiki_sources:
  - "lib/router/detect.sh"
  - "lib/router/install.sh"
  - "lib/router/status.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/router"
  - "router module"
---

# router

Подсистема `lib/router/` — интеграция с Claude Code Router (CCR). Обнаруживает наличие роутера, читает его конфигурацию и предоставляет путь к бинарнику `ccr`.

## Основные характеристики

Файловый состав (3 модуля):

| Файл | Содержимое |
|------|-----------|
| `detect.sh` | `detect_router()`, `get_router_path()`, `get_ccr_port()` |
| `install.sh` | `install_router()` — установка ccr через npm |
| `status.sh` | `check_router_status()` — статус CCR |

`detect_router()` — проверяет два условия:
1. Существование `router.json` (в изолированном или системном окружении)
2. Доступность бинарника `ccr`

`get_router_path()` — приоритет:
1. `$ISOLATED_NVM_DIR/npm-global/bin/ccr`
2. `ccr` в системном PATH

`get_ccr_port()` — парсит `PORT` и `HOST` из `router.json` (через jq, fallback grep):
- Дефолты: `CCR_HOST=127.0.0.1`, `CCR_PORT=3456`

Расположение `router.json`:
- Изолированное: `$ISOLATED_NVM_DIR/.claude-isolated/router.json`
- Системное: `$HOME/.claude/router.json`

CCR требует Node.js v20+ (использует глобал `File`, недоступный в v18). В `launch_claude()` добавляется `v20+` в PATH перед запуском CCR.

## Связанные концепции

- [[библиотека/функции/detect-router]]
- [[библиотека/функции/start-ccr-server]]
- [[библиотека/категории/launcher]]
- [[библиотека/паттерны/detect-start-stop-lifecycle]]
