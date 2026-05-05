---
wiki_sources:
  - "docs/architecture/overview.yaml"
  - "docs/architecture/diagrams/README.md"
wiki_updated: 2026-05-05
wiki_status: stub
tags:
  - architecture
  - oauth
  - iclaude
aliases:
  - "OAuth"
  - "токен"
  - "автообновление токена"
---

# OAuth Token Management

Модуль автоматической валидации и обновления OAuth токена в iclaude. Проверяется при каждом запуске; при истечении срока ближе чем через 7 дней запускает обновление.

## Основные характеристики

**Расположение в коде:** `iclaude.sh:3021-3183`

### Субкомпоненты

- `check_oauth_token` (`iclaude.sh:3021-3127`) — читает `.credentials.json`, запускает проверку и обновление
- `refresh_oauth_token` (`iclaude.sh:3129-3183`) — вызывает `claude setup-token` для получения нового токена
- `check_token_expiration` (`iclaude.sh:2032-2094`) — сравнивает `expiresAt` с текущим временем + порог

### Логика работы

```
При запуске:
  1. Читать .credentials.json
  2. Извлечь expiresAt
  3. Если expires_in < 7 дней → запустить claude setup-token
  4. Обновить .credentials.json
  5. Продолжить запуск
```

### Важные особенности

- При ошибке обновления credentials **не удаляются** — пользователю предлагается выполнить `/login` вручную
- Новый токен действителен ~1 год
- Зависит от `jq` для парсинга `.credentials.json`
- Работает только с OAuth токенами (`sk-ant-oat01-...`), не с API ключами (`sk-ant-api03-...`)

### Типы токенов

| Тип | Формат | Совместимость с CCR |
|-----|--------|---------------------|
| OAuth | `sk-ant-oat01-...` | Нет — CCR требует API ключ |
| API key | `sk-ant-api03-...` | Да |

## Связанные концепции

- [[../потоки/поток-обновления-oauth]]
