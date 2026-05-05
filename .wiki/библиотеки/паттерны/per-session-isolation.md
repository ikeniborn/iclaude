---
wiki_sources:
  - "lib/core/init.sh"
  - "lib/launcher/launch.sh"
  - "lib/pii-proxy/detect.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - patterns
  - lib
  - iclaude
aliases:
  - "per-session isolation"
  - "ICLAUDE_SESSION_ID"
  - "per-session"
---

# Per-session isolation

Паттерн изоляции параллельных сессий iclaude через уникальный идентификатор `ICLAUDE_SESSION_ID`. Предотвращает гонки состояния при одновременном запуске нескольких сессий.

## Основные характеристики

`ICLAUDE_SESSION_ID` генерируется в `init_environment()`:

```bash
ICLAUDE_SESSION_ID="${ICLAUDE_SESSION_ID:-$(od -An -N6 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' || printf '%012x' $((RANDOM * RANDOM + RANDOM)))}"
export ICLAUDE_SESSION_ID
```

Ключевая семантика: `${:-}` сохраняет значение при наследовании. Дочерние процессы (subshells, скрипты через Bash tool) получают тот же SID и могут переиспользовать ресурсы родителя.

Применение паттерна в модулях:

| Ресурс | Имя файла |
|--------|----------|
| PII proxy PID | `pii-proxy-pid/{SID}.pid` |
| PII proxy port | `pii-proxy-logs/pii-proxy-{SID}.port` |
| PII proxy log | `pii-proxy-logs/{SID}.log` |
| microVM TAP | `tap-{prefix}-{slot}` (slot из `microvm-slots/slot-N.lock` с PID) |
| FC socket | `microvm-run/{SID}.sock` |
| sync lock | `/tmp/iclaude-{SID}-sync.lock` |

Guardrail при переиспользовании PII proxy: `start_pii_proxy_server()` обнаруживает живой proxy с тем же SID и возвращает `PII_PROXY_SESSION_OWNED=false`. Это предотвращает убийство родительского прокси при завершении дочерней сессии.

Исключение для combined mode: при `CCR_SESSION_OWNED=true` всегда стартует новый прокси — нужен для chaining с CCR.

## Связанные концепции

- [[библиотека/функции/init-environment]]
- [[библиотека/функции/start-pii-proxy-server]]
- [[библиотека/паттерны/orphan-cleanup]]
- [[библиотека/паттерны/slot-based-resource-pools]]
