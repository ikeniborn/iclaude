---
wiki_sources: ["docs/functions/INTEGRATIONS.md"]
wiki_updated: 2026-05-06
wiki_status: developing
tags: [iclaude, features, oauth, authentication, token]
aliases: ["OAuth токен", "авторизация", "токен обновления"]
---

# OAuth Token Management

Модуль автоматически управляет OAuth токеном Anthropic: проверяет срок действия при каждом запуске и обновляет токен заблаговременно — до истечения.

## Основные характеристики

| Параметр | Значение |
|----------|----------|
| Модуль | `lib/oauth/token.sh` |
| Флаги | Автоматически при запуске, `--refresh-token` для ручного обновления |
| Зависимости | `jq`, Claude Code CLI, браузер (при первичной авторизации) |

## Логика обновления

При каждом запуске `iclaude.sh` проверяет поле `expiresAt` в `.credentials.json`. Если до истечения токена осталось меньше порогового значения (`TOKEN_REFRESH_THRESHOLD`, по умолчанию 7 дней) — запускается `claude setup-token`.

**Срок действия токена:** ~1 год (360+ дней).

```bash
# Ручное принудительное обновление токена
./iclaude.sh --refresh-token

# Проверка статуса токена
./iclaude.sh --check-isolated
```

## Источники токена

Порядок приоритета при запуске:

1. `CLAUDE_CODE_OAUTH_TOKEN` (из `.claude_config`) — используется как override
2. `.credentials.json` в `CLAUDE_CONFIG_DIR` — стандартное хранилище

## Конфигурация через .claude_config

```bash
# Явный OAuth токен (для headless-серверов без .credentials.json)
CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...

# Порог обновления (по умолчанию 7 дней = 604800 секунд)
# TOKEN_REFRESH_THRESHOLD=604800
```

## Ограничения

- OAuth токен подписки (`sk-ant-oat01-...`) **не принимается** `api.anthropic.com` напрямую
- При использовании Router в режиме Anthropic — нужен обычный API ключ (`ANTHROPIC_API_KEY`)
- Первичная авторизация требует браузер (открывается `claude login`)

## Связанные концепции

- [[функции/возможности/proxy]] — HTTPS прокси необходим для OAuth обновления в корпоративных сетях
- [[функции/конфигурация/переменные-окружения]] — `CLAUDE_CODE_OAUTH_TOKEN`, `TOKEN_REFRESH_THRESHOLD`
