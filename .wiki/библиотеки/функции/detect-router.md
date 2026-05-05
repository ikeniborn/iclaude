---
wiki_sources:
  - "lib/router/detect.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - functions
  - lib
  - iclaude
aliases:
  - "detect_router"
  - "get_router_path"
  - "get_ccr_port"
---

# detect_router / get_router_path / get_ccr_port

Три функции из `lib/router/detect.sh` для обнаружения и конфигурации Claude Code Router (CCR).

## Основные характеристики

Модуль: `lib/router/detect.sh`

**`detect_router(skip_isolated)`**:
- Проверяет наличие `router.json` (изолированный или системный путь)
- Проверяет доступность бинарника через `get_router_path()`
- Выводит предупреждение если `router.json` есть но ccr не установлен

**`get_router_path(skip_isolated)`**:
- Приоритет 1: `$ISOLATED_NVM_DIR/npm-global/bin/ccr`
- Приоритет 2: `command -v ccr` (системный PATH)
- Возвращает путь или пустую строку

**`get_ccr_port(skip_isolated)`**:
- Парсит `PORT` и `HOST` из `router.json`
- Использует jq при наличии, иначе grep+sed
- Обновляет глобалы `CCR_HOST` и `CCR_PORT`
- При ошибке: оставляет дефолты (127.0.0.1:3456)

CCR требует Node.js v20+ — `launch_claude()` prepend-ит v20 в PATH перед `start_ccr_server()`.

## Связанные концепции

- [[библиотека/категории/router]]
- [[библиотека/функции/start-ccr-server]]
- [[библиотека/функции/launch-claude]]
