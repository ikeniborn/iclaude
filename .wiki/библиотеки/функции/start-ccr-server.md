---
wiki_sources:
  - "lib/launcher/launch.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - functions
  - lib
  - iclaude
aliases:
  - "start_ccr_server"
  - "stop_ccr_server"
---

# start_ccr_server / stop_ccr_server

`start_ccr_server()` — запускает CCR (Claude Code Router) как фоновый daemon для combined mode (PII proxy + router). `stop_ccr_server()` — останавливает при завершении сессии.

## Основные характеристики

Модуль: `lib/launcher/launch.sh`

**`start_ccr_server(skip_isolated, [ccr_cmd])`**:

1. Резолв пути ccr если не передан
2. `get_ccr_port()` — парсинг `CCR_HOST:CCR_PORT` из `router.json`
3. Проверка: если CCR уже слушает на `CCR_HOST:CCR_PORT` → переиспользовать (`CCR_SESSION_OWNED=false`)
4. Запуск: `HOME=$CCR_HOME nohup ccr start >> ccr-daemon.log 2>&1 &`
5. Polling до 5 секунд (10×0.5s): TCP check `/dev/tcp/$CCR_HOST/$CCR_PORT`
6. При успехе: `ANTHROPIC_BASE_URL=http://$CCR_HOST:$CCR_PORT`, `CCR_SESSION_OWNED=true`

Важно: `start_pii_proxy_server()` читает `ANTHROPIC_BASE_URL` как `upstream_url`. После запуска PII proxy, `ANTHROPIC_BASE_URL` перезаписывается на PII proxy порт. Цепочка: `claude → PII(:auto) → CCR(:3456) → providers`.

**`stop_ccr_server()`**:
- Только если `CCR_SESSION_OWNED=true`
- SIGTERM → wait up to 1s → SIGKILL

## Связанные концепции

- [[библиотека/категории/router]]
- [[библиотека/функции/start-pii-proxy-server]]
- [[библиотека/паттерны/detect-start-stop-lifecycle]]
- [[библиотека/паттерны/health-check-dev-tcp]]
