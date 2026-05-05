---
wiki_sources:
  - "docs/architecture/overview.yaml"
  - "docs/architecture/diagrams/README.md"
  - "docs/architecture/diagrams/data-flow-oauth-token-refresh.md"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - architecture
  - oauth
  - iclaude
aliases:
  - "oauth token refresh flow"
  - "обновление токена"
---

# Поток обновления OAuth токена

Автоматическая проверка и обновление OAuth токена при каждом запуске iclaude.

## Основные характеристики

**Диаграмма:** `docs/architecture/diagrams/data-flow-oauth-token-refresh.md`

### Ключевые особенности

- Токен проверяется **при каждом запуске**
- Автообновление за **7 дней** до истечения (константа `TOKEN_REFRESH_THRESHOLD=604800`)
- Новый токен действителен ~1 год
- При ошибке credentials **не удаляются** (preserves `refreshToken`)

### Алгоритм проверки

```
expires_at = credentials.claudeAiOauth.expiresAt  # ms timestamp
threshold  = 7 * 24 * 60 * 60 * 1000

if (expires_at - now()) < threshold → refresh_token()
else                                → launch_claude()
```

### Этапы

1. Чтение `.credentials.json`, извлечение `expiresAt`
2. Расчёт `expires_in < 7 дней?`
   - **НЕТ** → запуск Claude
   - **ДА** → `claude setup-token` (открывает браузер)
3. Пользователь авторизуется на Anthropic OAuth Server
4. Получение нового `accessToken`, `refreshToken`, `expiresAt`
5. Обновление `.credentials.json`
6. Запуск Claude Code CLI с валидным токеном

### Структура `.credentials.json`

```json
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-oat01-...",
    "refreshToken": "sk-ant-ort01-...",
    "expiresAt": 1766460813792,
    "scopes": ["user:inference", "user:profile", "user:sessions:claude_code"],
    "subscriptionType": "max"
  }
}
```

### Обработка ошибок

При сбое `claude setup-token`:
- Выводится предупреждение; credentials **сохраняются**
- Claude Code может продолжить работу через внутренний механизм refresh
- Ручное обновление: `./iclaude.sh --refresh-token` или `/login` внутри сессии

### Ограничения

- `setup-token` требует интерактивной браузерной аутентификации
- Не работает в headless/CI окружениях без GUI

## Связанные концепции

- [[../компоненты/oauth-token-management]]
