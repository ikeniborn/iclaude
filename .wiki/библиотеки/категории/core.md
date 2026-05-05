---
wiki_sources:
  - "lib/core/init.sh"
  - "lib/core/logging.sh"
  - "lib/core/validation.sh"
  - "lib/core/json.sh"
  - "lib/core/remaining.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/core"
  - "core module"
---

# core

Подсистема `lib/core/` — фундаментальный уровень iclaude. Инициализирует глобальное окружение, экспортирует переменные, определяет цвета и логирующие функции. Загружается первой (Phase 0) до всех остальных модулей.

## Основные характеристики

Файловый состав (5 модулей):

| Файл | Функция |
|------|---------|
| `init.sh` | `init_environment()` — инициализация всех глобальных переменных и экспорт |
| `logging.sh` | `print_info/success/warning/error()` — цветной вывод |
| `validation.sh` | `validate_dependency()`, `validate_jq_installed()` — проверки зависимостей |
| `json.sh` | JSON-утилиты |
| `remaining.sh` | Вспомогательные функции |

Глобальные переменные, определяемые в `init_environment()`:

- `SCRIPT_DIR`, `CREDENTIALS_FILE` — пути к конфигурации
- `ISOLATED_NVM_DIR` — `.nvm-isolated/`
- `ISOLATED_CONFIG_DIR` — `.nvm-isolated/.claude-isolated/`
- `ICLAUDE_SESSION_ID` — уникальный идентификатор сессии (6 байт hex, per-session isolation)
- `PII_PROXY_*` — конфигурация PII прокси
- `CCR_*` — конфигурация Claude Code Router
- `MICRO_VM_*` — конфигурация Firecracker microVM
- `TOKEN_REFRESH_THRESHOLD` — порог обновления OAuth токена (604800 секунд = 7 дней)

Цвета для вывода: `$RED`, `$GREEN`, `$YELLOW`, `$BLUE`, `$NC` (экспортируются для subshells).

Порядок загрузки: Phase 0 — до всех feature-модулей.

## Связанные концепции

- [[библиотека/паттерны/per-session-isolation]]
- [[библиотека/функции/init-environment]]
- [[библиотека/функции/print-functions]]
