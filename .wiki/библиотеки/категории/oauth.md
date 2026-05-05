---
wiki_sources:
  - "lib/oauth/token.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/oauth"
  - "oauth module"
---

# oauth

Подсистема `lib/oauth/` — управление жизненным циклом OAuth токенов. Проверяет срок действия токена перед каждым запуском и при необходимости обновляет его через `claude setup-token`.

## Основные характеристики

Файловый состав (1 файл):

| Файл | Содержимое |
|------|-----------|
| `token.sh` | `check_oauth_token()`, `refresh_oauth_token()`, `check_token_expiration()`, `validate_jq_installed()` |

`check_oauth_token()` — вызывается из `launch_claude()` перед запуском:
- Если `CLAUDE_CODE_OAUTH_TOKEN` установлен явно — пропускает проверку
- Читает `expiresAt` из `.credentials.json` через jq (поле `.claudeAiOauth.expiresAt`)
- Если токен истекает в течение `TOKEN_REFRESH_THRESHOLD` (7 дней) — вызывает `refresh_oauth_token()`
- При ошибке обновления — предупреждает, но не блокирует запуск

`refresh_oauth_token()`:
- Запускает `claude setup-token` для создания долгосрочного токена (~1 год)
- Использует тот же бинарник claude, что и основной запуск

Расположение `.credentials.json`:
- Изолированное окружение: `$ISOLATED_NVM_DIR/.claude-isolated/.credentials.json`
- Системное: `$HOME/.claude/.credentials.json`

Важно: при `CLAUDE_CODE_OAUTH_TOKEN` (OAuth token из env) проверка полностью пропускается — Claude Code использует токен напрямую.

## Связанные концепции

- [[библиотека/функции/check-oauth-token]]
- [[библиотека/категории/core]]
- [[библиотека/категории/nvm]]
