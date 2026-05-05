---
wiki_sources:
  - "lib/launcher/launch.sh"
  - "lib/router/detect.sh"
  - "lib/pii-proxy/detect.sh"
  - "lib/sandbox/detect.sh"
  - "lib/sandbox/microvm.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - patterns
  - lib
  - iclaude
aliases:
  - "detect→start→stop lifecycle"
  - "lifecycle pattern"
---

# detect → start → stop lifecycle

Архитектурный паттерн управления внешними процессами (PII proxy, CCR router, microVM). Три фазы: detect (проверка готовности), start (запуск + health check), stop (cleanup через EXIT trap).

## Основные характеристики

Паттерн применяется к трём компонентам:

| Компонент | detect | start | stop |
|-----------|--------|-------|------|
| PII proxy | `detect_pii_proxy()` | `start_pii_proxy_server()` | `stop_pii_proxy_server()` |
| CCR router | `detect_router()` | `start_ccr_server()` | `stop_ccr_server()` |
| microVM | `detect_microvm()` | `start_microvm()` | `stop_microvm()` |

Фаза **detect**:
- Проверяет наличие бинарников, конфигов, зависимостей
- Не изменяет состояние системы
- Возвращает 0/1

Фаза **start**:
- Запускает процесс в background
- Health check через `/dev/tcp` + HTTP (см. [[библиотека/паттерны/health-check-dev-tcp]])
- Записывает PID в файл для cleanup
- Устанавливает `SESSION_OWNED=true`

Фаза **stop**:
- Вызывается через `trap ... EXIT INT TERM`
- Проверяет `SESSION_OWNED` — не убивает чужие процессы
- SIGTERM → wait → SIGKILL
- Удаляет PID-файлы и port-файлы

Порядок остановки в combined mode (обратный порядку запуска):
```bash
trap '_cm_cleanup; stop_microvm; stop_pii_proxy_server; stop_ccr_server' EXIT INT TERM
```

## Связанные концепции

- [[библиотека/функции/start-pii-proxy-server]]
- [[библиотека/функции/start-ccr-server]]
- [[библиотека/функции/start-microvm]]
- [[библиотека/паттерны/per-session-isolation]]
- [[библиотека/паттерны/health-check-dev-tcp]]
