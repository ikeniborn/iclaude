---
wiki_sources:
  - "lib/launcher/launch.sh"
  - "lib/sandbox/microvm.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - patterns
  - lib
  - iclaude
aliases:
  - "orphan cleanup"
  - "stale cleanup"
  - "cleanup_orphaned"
---

# Orphan cleanup

Паттерн очистки осиротевших ресурсов от сессий, завершившихся без корректного shutdown (SIGKILL, crash, потеря питания). Применяется к PII proxy, microVM, session-env директориям.

## Основные характеристики

Проблема: при некорректном завершении сессии EXIT trap не выполняется. Остаются PID-файлы, port-файлы, FC сокеты, slot lock-файлы.

Три cleanup функции и когда они вызываются:

**`cleanup_orphaned_pii_proxies()`** (в `start_pii_proxy_server()`):
- Сканирует `pii-proxy-pid/*.pid` — проверяет `kill -0 $pid`
- Дополнительно: `ps -p $pid -o cmd= | grep pii-proxy-server.py` — защита от recycled PIDs
- Удаляет мёртвые PID + соответствующий port файл
- Legacy sweep: старые `pii-proxy-*.pid` в root `ISOLATED_CONFIG_DIR`
- Ротация логов старше `PII_LOG_RETENTION_DAYS` (дефолт: 7 дней)

**`cleanup_orphaned_microvm_sessions()`** (в `launch_claude()` перед start_microvm):
- Сканирует `microvm-slots/slot-N.lock` — проверяет живость PID
- Удаляет стейл FC сокеты из `microvm-run/`

**`cleanup_stale_session_env()`** (в `launch_claude()` при каждом запуске):
- Сканирует `ISOLATED_CONFIG_DIR/session-env/*/`
- Пустые директории: удалять после `SESSION_ENV_RETENTION_DAYS` (дефолт: 7)
- Непустые директории: удалять после `SESSION_ENV_RETENTION_DAYS * 4` (дефолт: 28)

Guard от recycled PIDs: `kill -0` подтверждает что процесс существует, `ps -p cmd=` подтверждает что это именно нужный процесс (не случайно переиспользованный PID).

## Связанные концепции

- [[библиотека/паттерны/per-session-isolation]]
- [[библиотека/функции/start-pii-proxy-server]]
- [[библиотека/функции/start-microvm]]
- [[библиотека/паттерны/slot-based-resource-pools]]
