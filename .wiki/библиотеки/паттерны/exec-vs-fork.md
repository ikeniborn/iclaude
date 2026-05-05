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
  - "exec vs fork"
  - "exec pattern"
---

# exec vs fork

Паттерн выбора между `exec` (замена процесса) и `claude "$@"; exit $?` (fork) в `launch_claude()`. Выбор определяется необходимостью выполнения EXIT trap.

## Основные характеристики

**`exec claude "$@"`** — стандартный путь:
- Заменяет shell-процесс бинарником claude
- Shell больше не существует — EXIT trap не выполняется
- Нет overhead подпроцесса
- Используется: стандартный запуск, solo router (`exec ccr code "$@"`)

**`claude "$@"; exit $?`** — fork/wait путь:
- Shell остаётся живым до завершения claude
- EXIT trap срабатывает после `exit` (или при SIGTERM/SIGINT)
- Используется: всегда когда нужно остановить внешние сервисы

Случаи когда нельзя использовать exec:

| Режим | Причина |
|-------|---------|
| PII proxy solo | EXIT trap → `stop_pii_proxy_server()` |
| PII proxy + Router (combined) | EXIT trap → `stop_pii_proxy_server(); stop_ccr_server()` |
| microVM | SSH exec внутри trap; stop_microvm в EXIT |

Регистрация trap зависит от комбинации флагов:

```bash
# microVM + PII + CCR
trap '_cm_cleanup; stop_microvm; stop_pii_proxy_server; stop_ccr_server' EXIT INT TERM

# PII solo
trap 'stop_pii_proxy_server' EXIT INT TERM
```

## Связанные концепции

- [[библиотека/функции/launch-claude]]
- [[библиотека/паттерны/detect-start-stop-lifecycle]]
- [[библиотека/функции/start-pii-proxy-server]]
