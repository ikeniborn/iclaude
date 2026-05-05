---
wiki_sources:
  - "lib/nvm/detect.sh"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - bash
  - functions
  - lib
  - iclaude
aliases:
  - "detect_nvm"
---

# detect_nvm

`detect_nvm()` — обнаруживает доступное NVM окружение с тремя уровнями приоритета. Возвращает 0 если NVM найден, 1 если нет.

## Основные характеристики

Модуль: `lib/nvm/detect.sh`

Сигнатура: `detect_nvm([skip_isolated])`

Порядок проверок:

1. **Изолированное окружение** (приоритет 1): если `skip_isolated != true` и `USE_ISOLATED_BY_DEFAULT=true` и `$ISOLATED_NVM_DIR` существует → вызывает `setup_isolated_nvm()` и возвращает 0
2. **Системный NVM** (приоритет 2): если `$NVM_DIR` установлен и `$NVM_DIR/nvm.sh` существует → возвращает 0
3. **NVM в PATH** (приоритет 3): если `npm` или `node` в PATH содержат `.nvm` в пути → возвращает 0

Аргумент `skip_isolated="true"` используется при `--system` режиме (bypass изолированного окружения).

Побочный эффект при Priority 1: вызов `setup_isolated_nvm()` изменяет `NVM_DIR`, `PATH`, `NPM_CONFIG_PREFIX`.

## Связанные концепции

- [[библиотека/функции/setup-isolated-nvm]]
- [[библиотека/функции/get-nvm-claude-path]]
- [[библиотека/категории/nvm]]
