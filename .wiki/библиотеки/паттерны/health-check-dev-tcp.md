---
wiki_sources:
  - "lib/launcher/launch.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - patterns
  - lib
  - iclaude
aliases:
  - "health check via /dev/tcp"
  - "/dev/tcp health check"
  - "TCP health check"
---

# Health check через /dev/tcp

Паттерн двухуровневой проверки готовности TCP-сервиса: быстрый TCP check через bash built-in `/dev/tcp`, затем HTTP health endpoint. Используется для PII proxy и CCR router.

## Основные характеристики

Bash built-in TCP check:

```bash
(: >/dev/tcp/127.0.0.1/"$port") 2>/dev/null
```

Не создаёт subprocess — bash открывает TCP соединение напрямую. Скорее обычного `nc` или `curl`. Используется как быстрый фильтр перед дорогостоящим HTTP check.

Двухуровневый polling (PII proxy, timeout 15s):

```bash
while [[ $ticks -lt 30 ]]; do
    # Быстрая проверка: процесс жив?
    kill -0 "$proxy_pid" || break

    if [[ -f "$port_file" ]]; then
        port=$(cat "$port_file")
        # Level 1: TCP check (bash built-in, no subprocess)
        if (: >/dev/tcp/127.0.0.1/"$port") 2>/dev/null; then
            # Level 2: HTTP health (subprocess, only when TCP up)
            if _pii_proxy_http_health "$port"; then
                health_ok=true; break
            fi
        fi
    fi
    sleep 0.5
    ticks=$((ticks + 1))
done
```

Для CCR: только TCP check (нет HTTP health endpoint), timeout 5s (10×0.5).

Fail-fast: обнаружение ранней смерти процесса через `kill -0 $pid` — не ждёт полный timeout.

HTTP health реализован через python subprocess (не curl) для минимизации зависимостей:

```python
urllib.request.urlopen("http://127.0.0.1:" + port + "/api/health", timeout=2)
```

Защита от injection: порт предварительно валидируется регулярным выражением `^[0-9]+$`.

## Связанные концепции

- [[библиотека/функции/start-pii-proxy-server]]
- [[библиотека/функции/start-ccr-server]]
- [[библиотека/паттерны/detect-start-stop-lifecycle]]
