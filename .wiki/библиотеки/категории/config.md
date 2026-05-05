---
wiki_sources:
  - "lib/config/isolated.sh"
  - "lib/config/export.sh"
  - "lib/config/status.sh"
wiki_updated: 2026-05-05
wiki_status: stub
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/config"
  - "config module"
---

# config

Подсистема `lib/config/` — управление конфигурацией Claude Code. Создаёт изолированный `CLAUDE_CONFIG_DIR`, загружает переменные из `.claude_config` и отключает автообновления.

## Основные характеристики

Файловый состав (3 модуля):

| Файл | Содержимое |
|------|-----------|
| `isolated.sh` | `setup_isolated_config()`, `disable_auto_updates()`, `load_claude_config()` |
| `export.sh` | Экспорт дополнительных Claude Code переменных |
| `status.sh` | `check_config_status()` — отображение текущей конфигурации |

`setup_isolated_config()`:
- Создаёт `$ISOLATED_NVM_DIR/.claude-isolated/` если не существует
- Экспортирует `CLAUDE_CONFIG_DIR` в изолированную директорию

`load_claude_config()` — загружает из `.claude_config` и экспортирует:
- Модели: `ANTHROPIC_MODEL`, `CLAUDE_CODE_MODEL`, `ANTHROPIC_DEFAULT_*`
- Поведение: `CLAUDE_CODE_MAX_OUTPUT_TOKENS`, `CLAUDE_CODE_EFFORT_LEVEL`, `CLAUDE_CODE_ENABLE_TASKS`
- PII proxy: `PII_PROXY_MASKING_LEVEL`, `PII_PROXY_LOG_LEVEL`
- microVM: полный набор `MICRO_VM_*` переменных

`disable_auto_updates()`: устанавливает `autoUpdates: false` в `.claude.json` — обновления управляются через CI/CD.

## Связанные концепции

- [[библиотека/категории/core]]
- [[библиотека/категории/nvm]]
