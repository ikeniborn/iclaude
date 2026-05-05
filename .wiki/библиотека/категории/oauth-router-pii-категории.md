---
wiki_sources: ["lib/oauth/token.sh", "lib/router/detect.sh", "lib/pii-proxy/detect.sh", "lib/README.md"]
wiki_updated: 2026-05-05
wiki_status: developing
tags: ["bash", "module", "iclaude"]
aliases: ["lib/oauth", "lib/router", "lib/pii-proxy", "OAuth", "CCR", "PII Proxy"]
---

# OAuth, Router, PII-Proxy — сервисные категории

Три категории, обеспечивающие аутентификацию, маршрутизацию запросов к LLM и маскирование персональных данных.

## lib/oauth/ — управление OAuth-токенами

| Модуль | Функции | Назначение |
|--------|---------|------------|
| `token.sh` | `check_token_expiration()`, `check_oauth_token()`, `refresh_oauth_token()`, `validate_jq_installed()` | Валидация, мониторинг и автоматическое обновление OAuth-токена |

### Логика check_oauth_token()

```
1. CLAUDE_CODE_OAUTH_TOKEN установлен → пропустить проверку (токен передаётся напрямую)
2. Найти credentials.json (изолированный или системный путь)
3. Извлечь .claudeAiOauth.expiresAt через jq
   ВАЖНО: именно .claudeAiOauth.expiresAt, не .mcpOAuth.*.expiresAt
4. Если до истечения ≤ TOKEN_REFRESH_THRESHOLD (7 дней) → вызвать refresh_oauth_token()
5. Если до истечения < 1 час → вывести предупреждение, но не прерывать запуск
```

### Коды возврата check_token_expiration()

```
0 → Все токены валидны
1 → Токен истёк
2 → Токен истекает в течение 1 часа
```

### refresh_oauth_token()

Вызывает `claude setup-token` — открывает браузер для OAuth, создаёт долгосрочный токен (~1 год). Использует `detect_nvm()` + `get_nvm_claude_path()` для поиска бинарного файла Claude Code.

## lib/router/ — интеграция Claude Code Router (CCR)

| Модуль | Функции | Назначение |
|--------|---------|------------|
| `detect.sh` | `detect_router()`, `get_router_path()`, `get_ccr_port()` | Обнаружение CCR, чтение конфигурации |
| `install.sh` | `install_isolated_router()` | Установка CCR в изолированное окружение |
| `status.sh` | `check_router_status()` | Вывод состояния CCR |

### detect_router()

Требует одновременного наличия:
1. `router.json` в конфигурационной директории
2. Бинарного файла `ccr` в `$ISOLATED_NVM_DIR/npm-global/bin/` или в PATH

### get_ccr_port()

Читает `PORT` и `HOST` из `router.json` через jq (fallback: grep). Обновляет глобальные переменные `CCR_HOST` и `CCR_PORT`. Используется в режиме совместной работы PII Proxy + CCR для построения `ANTHROPIC_UPSTREAM_URL`.

### Ограничения CCR

CCR требует реального API-ключа (`sk-ant-api03-...`), не OAuth-токена (`sk-ant-oat01-...`). CCR требует Node.js ≥20 (использует File API).

## lib/pii-proxy/ — PII Proxy (Presidio NLP)

| Модуль | Функции | Назначение |
|--------|---------|------------|
| `detect.sh` | `detect_pii_proxy()`, `get_pii_proxy_python()` | Проверка наличия venv и Python 3.8+ |
| `install.sh` | `install_isolated_pii_proxy()` | Идемпотентная установка venv + Presidio + spaCy |
| `status.sh` | `check_pii_proxy_status()` | Вывод состояния PII-proxy |
| `server.py` | HTTP-сервер | Перехват и маскирование PII в 100% трафика Anthropic API |

### detect_pii_proxy()

Условия доступности PII-proxy:
1. Изолированное окружение (`$ISOLATED_NVM_DIR`) существует
2. `$PII_PROXY_SERVER_SCRIPT` (`pii-proxy-server.py`) установлен
3. Python venv создан (`$PII_PROXY_VENV/bin/python3`)
4. Версия Python ≥ 3.8 (проверяется как целое число: 308 = 3.8, 310 = 3.10)

### Per-session изоляция PII-proxy

PID-файлы хранятся в `$PII_PROXY_PID_DIR/{ICLAUDE_SESSION_ID}.pid`. Каждая параллельная сессия iclaude запускает собственный экземпляр PII-proxy на уникальном порту из диапазона 20000–40000.

## Связанные концепции

- [[категории/обзор-lib]]
- [[категории/core-категория]]
- [[категории/nvm-категория]]
