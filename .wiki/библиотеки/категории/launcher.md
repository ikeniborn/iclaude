---
wiki_sources:
  - "lib/launcher/launch.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/launcher"
  - "launcher module"
---

# launcher

Подсистема `lib/launcher/` — точка финального запуска Claude Code. Содержит `launch_claude()` — единственную функцию, которая в итоге запускает бинарник claude или роутер, а также функции управления жизненным циклом PII proxy и CCR daemon.

## Основные характеристики

Файловый состав (1 файл):

| Файл | Содержимое |
|------|-----------|
| `launch.sh` | `launch_claude()`, `start_pii_proxy_server()`, `stop_pii_proxy_server()`, `start_ccr_server()`, `stop_ccr_server()`, `cleanup_orphaned_pii_proxies()`, `cleanup_stale_session_env()` |

`launch_claude()` принимает аргумент `skip_isolated` и список аргументов для claude. Логика выбора режима запуска:

1. Если `USE_ROUTER_FLAG=true` и `detect_router()` — запуск через CCR
2. Если `USE_MICRO_VM_FLAG=true` — запуск внутри Firecracker guest через SSH
3. Если `USE_PII_PROXY_FLAG=true` — запуск с ANTHROPIC_BASE_URL перенаправленным в PII proxy
4. Иначе — прямой `exec claude`

Цепочка combined mode: `claude → PII proxy(:auto) → CCR(:3456) → providers`

Особенность запуска с PII proxy: нельзя использовать `exec` — EXIT trap должен сработать для остановки proxy. Поэтому используется вызов без exec + `exit $?`.

Функции cleanup: `cleanup_orphaned_pii_proxies()` — вызывается при каждом запуске, чистит осиротевшие PID-файлы. `cleanup_stale_session_env()` — чистит старые session-env директории.

## Связанные концепции

- [[библиотека/паттерны/exec-vs-fork]]
- [[библиотека/паттерны/orphan-cleanup]]
- [[библиотека/паттерны/detect-start-stop-lifecycle]]
- [[библиотека/функции/launch-claude]]
- [[библиотека/функции/start-pii-proxy-server]]
- [[библиотека/категории/pii-proxy]]
- [[библиотека/категории/router]]
- [[библиотека/категории/sandbox]]
