---
wiki_sources:
  - "lib/command/dispatch.sh"
  - "lib/command/parse.sh"
  - "lib/command/usage.sh"
wiki_updated: 2026-05-05
wiki_status: stub
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/command"
  - "command module"
---

# command

Подсистема `lib/command/` — разбор аргументов командной строки, диспетчеризация команд и вывод справки. Phase 14 модуляризации.

## Основные характеристики

Файловый состав (3 модуля):

| Файл | Содержимое |
|------|-----------|
| `parse.sh` | `parse_cli_arguments()` — разбор флагов CLI |
| `dispatch.sh` | `dispatch_command()` — диспетчер (stub для Phase 15+) |
| `usage.sh` | `show_usage()` — вывод справки по --help |

Текущий статус `dispatch_command()`: stub-заглушка. Реальная диспетчеризация остаётся в `main()` основного скрипта — полное разделение запланировано в Phase 15+.

`parse_cli_arguments()` задаёт глобальные флаги:
- `USE_PROXY_FLAG`, `NO_PROXY_FLAG`, `USE_ROUTER_FLAG`
- `USE_MICRO_VM_FLAG`, `USE_PII_PROXY_FLAG`
- `SKIP_ISOLATED_FLAG`, `CHROME_FLAG`
- Флаги установки/обновления/диагностики

## Связанные концепции

- [[библиотека/категории/core]]
- [[библиотека/категории/launcher]]
