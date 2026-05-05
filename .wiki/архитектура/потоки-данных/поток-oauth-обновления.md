---
wiki_sources:
  - "docs/architecture/overview.yaml"
  - "docs/architecture/diagrams/README.md"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - architecture
  - iclaude
aliases:
  - "OAuth Token Refresh Flow"
  - "Поток обновления токена"
---

# Поток обновления OAuth-токена

Автоматическая проверка срока действия OAuth-токена и его обновление при каждом запуске iclaude. Выполняется до запуска Claude Code.

## Основные характеристики

**ID потока:** `oauth-token-refresh-flow`

**Шаги:**

| Шаг | Компонент | Действие |
|-----|-----------|---------|
| 1 | `cli-main` | Инициация запуска Claude Code |
| 2 | `check-oauth-token` | Чтение `.credentials.json` |
| 3 | `check-token-expiration` | Вычисление: `expiresAt - now < 7 дней`? |
| 4a | — | NO: токен валиден → переход к запуску |
| 4b | `refresh-oauth-token` | YES: запуск `claude setup-token` |
| 5 | Browser | Авторизация пользователя в Anthropic OAuth |
| 6 | `credential-storage` | Запись нового токена в `.credentials.json` |
| 7 | `cli-main` | Продолжение запуска |

**Обработка ошибок:**
- При сбое `setup-token` credentials **не удаляются**
- Пользователю отображается предупреждение
- Для ручного обновления: `/login` внутри Claude Code

## Важные характеристики

- Порог автообновления: 7 дней (настраиваемо)
- Срок действия нового токена: ~1 год
- Токен хранится в `.credentials.json` (chmod 600 через `credential-storage`)

## Связанные концепции

- [[oauth-token-management]]
- [[core-слой]]
- [[защита-данных-доступа]]
