---
wiki_sources:
  - "lib/oauth/token.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - functions
  - lib
  - iclaude
aliases:
  - "check_oauth_token"
  - "refresh_oauth_token"
---

# check_oauth_token

`check_oauth_token()` — проверяет срок действия OAuth токена перед запуском Claude Code и автоматически обновляет истекающий токен.

## Основные характеристики

Модуль: `lib/oauth/token.sh`

Сигнатура: `check_oauth_token([skip_isolated])`

Алгоритм:

1. Если `$CLAUDE_CODE_OAUTH_TOKEN` установлен → немедленный return 0 (env-токен используется напрямую)
2. Определение файла credentials: изолированный или системный
3. Парсинг `.claudeAiOauth.expiresAt` через jq (не `.mcpOAuth.*.expiresAt` — намеренно)
4. Сравнение с текущим временем: если `(expires_at - now) <= TOKEN_REFRESH_THRESHOLD (604800s)`:
   - Вывод предупреждения с оставшимся временем
   - Вызов `refresh_oauth_token()`
   - При неудаче: предупреждение, но не блокировка запуска

`refresh_oauth_token()`:
- Запускает `claude setup-token` (открывает браузер для OAuth)
- Создаёт долгосрочный токен (~1 год)
- Возвращает 0 при успехе, 1 при ошибке

Важно: при неудаче обновления credentials файл НЕ удаляется — refreshToken может быть ещё использован Claude Code.

## Связанные концепции

- [[библиотека/категории/oauth]]
- [[библиотека/функции/launch-claude]]
