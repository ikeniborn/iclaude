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
  - "start_pii_proxy_server"
  - "stop_pii_proxy_server"
---

# start_pii_proxy_server / stop_pii_proxy_server

`start_pii_proxy_server()` — запускает per-session PII proxy сервер и перенаправляет API трафик через него. `stop_pii_proxy_server()` — останавливает при завершении сессии.

## Основные характеристики

Модуль: `lib/launcher/launch.sh`

**`start_pii_proxy_server(skip_isolated)`**:

1. Guard: если `ICLAUDE_SESSION_ID` унаследован от родительской сессии и прокси уже запущен → переиспользовать (не стартовать новый)
   - Исключение: combined mode (CCR_SESSION_OWNED=true) — нужен новый прокси для chaining
2. `cleanup_orphaned_pii_proxies()` — очистка осиротевших сессий
3. Запуск `pii-proxy-server.py --port $PII_PROXY_PORT --log-dir $PII_PROXY_LOG_DIR` в background
4. Запись PID в `$PII_PROXY_PID_DIR/$ICLAUDE_SESSION_ID.pid`
5. Polling до 15 секунд (30×0.5s): порт из файла → TCP check (`/dev/tcp`) → HTTP health (`/api/health`)
6. При успехе: `ANTHROPIC_BASE_URL=http://127.0.0.1:$port`, `ICLAUDE_PII_ACTIVE=1`

**`stop_pii_proxy_server()`**:
- Не убивает прокси если `PII_PROXY_SESSION_OWNED=false` (переиспользованный от родителя)
- Читает PID из файла → SIGTERM → wait up to 1s → SIGKILL
- В info режиме: удаляет session лог после завершения (не в debug режиме)

Эта пара функций — пример [[библиотека/паттерны/detect-start-stop-lifecycle]].

## Связанные концепции

- [[библиотека/категории/pii-proxy]]
- [[библиотека/категории/launcher]]
- [[библиотека/паттерны/per-session-isolation]]
- [[библиотека/паттерны/orphan-cleanup]]
- [[библиотека/паттерны/health-check-dev-tcp]]
- [[библиотека/функции/start-ccr-server]]
