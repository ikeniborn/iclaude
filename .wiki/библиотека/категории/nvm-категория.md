---
wiki_sources: ["lib/nvm/detect.sh", "lib/README.md"]
wiki_updated: 2026-05-05
wiki_status: developing
tags: ["bash", "module", "iclaude"]
aliases: ["lib/nvm", "nvm modules", "Phase 3"]
---

# NVM — категория управления окружением Node.js (lib/nvm/)

Категория `lib/nvm/` управляет изолированным окружением NVM + Node.js + Claude Code. Обеспечивает обнаружение, установку, обслуживание и очистку портативного Node.js в `.nvm-isolated/`.

## Основные характеристики

| Модуль | Ключевые функции | Назначение |
|--------|-----------------|------------|
| `detect.sh` | `detect_nvm()`, `get_nvm_claude_path()`, `get_cli_version()` | Обнаружение NVM и бинарного файла Claude Code |
| `setup.sh` | `setup_isolated_nvm()` | Настройка PATH + NVM_DIR + NPM_CONFIG_PREFIX |
| `install.sh` | `install_isolated_nvm()`, `install_npm_package_with_lockfile()` | Установка NVM и npm-пакетов |
| `claude.sh` | `install_claude_code_isolated()`, `update_claude_code_isolated()` | Установка и обновление Claude Code |
| `repair.sh` | `repair_isolated_environment()` | Восстановление симлинков, загрузка native binary |
| `cleanup.sh` | `cleanup_isolated_nvm()` | Очистка устаревших установок |

## Приоритет обнаружения (detect_nvm)

```
1. Изолированное окружение (.nvm-isolated/) — если USE_ISOLATED_BY_DEFAULT=true
   → вызывает setup_isolated_nvm(), возвращает 0
2. Системный NVM ($NVM_DIR/nvm.sh существует)
   → возвращает 0, PATH уже настроен
3. npm/node в PATH содержит ".nvm" в пути
   → возвращает 0
```

## Порядок поиска бинарного файла Claude Code (get_nvm_claude_path)

```
1. $nvm_bin/claude               (стандартный symlink)
2. $nvm_bin/.claude-*            (временные бинарные файлы, сортировка по mtime)
3. bin/claude.exe                (native binary, v2.1.114+)
4. claude-code/cli.js            (legacy формат, pre-v2.1.114)
5. .claude-code-*/cli.js         (временные папки, сортировка по mtime)
```

Поиск выполняется в двух местах: сначала в `$NVM_DIR/versions/node/$current_node/`, затем в `$(npm prefix -g)/`.

## Важно: setup_isolated_nvm vs source nvm.sh

`setup_isolated_nvm()` устанавливает PATH, NVM_DIR и NPM_CONFIG_PREFIX напрямую — без `source nvm.sh`.

`source nvm.sh` вызывает `nvm_auto("use")` → `nvm use <version>`, что с `set -euo pipefail` в CI приводит к ненулевому коду возврата и завершению скрипта. Эта ошибка была причиной серии сбоев CI (февраль 2026).

## Версии Node.js в репозитории

В `.nvm-isolated/versions/node/` зафиксированы три версии:
- v18.20.8
- v20.20.0
- v20.20.2

`setup_isolated_nvm()` использует `LC_ALL=C sort | tail -1` → выбирает v20.20.2 (последняя). CCR v2.0.0 требует Node.js ≥20 (использует File API, отсутствующий в v18).

## Связанные концепции

- [[категории/обзор-lib]]
- [[категории/core-категория]]
