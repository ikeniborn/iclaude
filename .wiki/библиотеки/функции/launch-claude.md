---
wiki_sources:
  - "lib/launcher/launch.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - functions
  - lib
  - iclaude
aliases:
  - "launch_claude"
---

# launch_claude

`launch_claude()` — главная функция финального запуска Claude Code. Реализует дерево решений: какой режим использовать (microVM / router / PII proxy / прямой). Функция не возвращает управление — завершается через `exec` или `exit $?`.

## Основные характеристики

Модуль: `lib/launcher/launch.sh`

Сигнатура: `launch_claude(skip_isolated [args...])`

Дерево решений (последовательность проверок):

1. `unset CHROME_DESKTOP` — предотвращает захват браузера VS Code
2. `check_oauth_token` — проверка/обновление OAuth токена
3. `cleanup_stale_session_env` — фоновая очистка устаревших session-env
4. Если `USE_ROUTER_FLAG=true` и `detect_router()`: `use_router=true`
5. Если `USE_MICRO_VM_FLAG=true` и `detect_microvm()`: `use_microvm=true`
6. Если `USE_PII_PROXY_FLAG=true` и `detect_pii_proxy()`: `use_pii_proxy=true`

Режимы запуска (в порядке приоритета):

| Комбинация флагов | Запуск |
|-------------------|-------|
| microVM + PII + Router | `start_ccr_server → start_pii_proxy_server → start_microvm → SSH exec claude в VM` |
| microVM + Router | `start_ccr_server → start_microvm → SSH exec claude в VM` |
| microVM | `start_microvm → SSH exec claude в VM` |
| Router + PII (combined) | `start_ccr_server → start_pii_proxy_server → exec claude` (без exec — PII) |
| Router solo | `HOME=$ccr_home exec ccr code "$@"` |
| PII solo | `start_pii_proxy_server → claude "$@"; exit $?` |
| Стандартный | `exec claude "$@"` |

Поиск бинарника claude (при non-router режимах):
1. NVM (`detect_nvm` → `get_nvm_claude_path`)
2. `/usr/local/bin/claude`, `/usr/bin/claude`
3. `command -v claude` (без NVM путей)
4. `npm prefix -g`/bin/claude
5. `npx @anthropic-ai/claude-code` (fallback)

Важно: при `use_pii_proxy=true` нельзя использовать `exec` — EXIT trap должен сработать для остановки прокси. Используется `claude "$@"; exit $?`.

## Связанные концепции

- [[библиотека/категории/launcher]]
- [[библиотека/паттерны/exec-vs-fork]]
- [[библиотека/паттерны/detect-start-stop-lifecycle]]
- [[библиотека/функции/start-pii-proxy-server]]
- [[библиотека/функции/start-microvm]]
