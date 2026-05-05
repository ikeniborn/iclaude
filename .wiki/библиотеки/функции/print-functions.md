---
wiki_sources:
  - "lib/core/logging.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - functions
  - lib
  - iclaude
aliases:
  - "print_info"
  - "print_success"
  - "print_warning"
  - "print_error"
  - "print functions"
---

# print_info / print_success / print_warning / print_error

Четыре функции цветного вывода из `lib/core/logging.sh`. Используются повсеместно во всех модулях iclaude для единообразного форматирования сообщений.

## Основные характеристики

Модуль: `lib/core/logging.sh`

| Функция | Символ | Цвет | Назначение |
|---------|--------|------|-----------|
| `print_info` | `ℹ` | синий | Информационные сообщения |
| `print_success` | `✓` | зелёный | Успешное выполнение |
| `print_warning` | `⚠` | жёлтый | Предупреждения (не критично) |
| `print_error` | `✗` | красный | Ошибки |

Реализация через `echo -e "${COLOR}СИМВОЛ${NC} $1"`.

Цвета определены в `lib/core/init.sh` как `$RED`, `$GREEN`, `$YELLOW`, `$BLUE`, `$NC` и экспортированы для subshells.

Все функции пишут в stdout (не в stderr). Для разделения потоков используется перенаправление при вызове: `print_info "текст" >&2`.

## Связанные концепции

- [[библиотека/категории/core]]
- [[библиотека/функции/init-environment]]
