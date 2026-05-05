---
wiki_sources:
  - "lib/lsp/install.sh"
  - "lib/lsp/repair.sh"
  - "lib/lsp/status.sh"
wiki_updated: 2026-05-05
wiki_status: stub
tags:
  - bash
  - modules
  - lib
  - iclaude
aliases:
  - "lib/lsp"
  - "lsp module"
---

# lsp

Подсистема `lib/lsp/` — установка и управление LSP серверами (Language Server Protocol) для Claude Code. Поддерживаемые серверы: TypeScript и Python.

## Основные характеристики

Файловый состав (3 модуля):

| Файл | Содержимое |
|------|-----------|
| `install.sh` | `install_lsp()` — установка typescript-language-server и pylsp |
| `repair.sh` | `repair_plugin_paths()` — восстановление symlinks плагинов |
| `status.sh` | `check_lsp_status()` — отображение установленных LSP |

`repair_plugin_paths()` вызывается автоматически (тихо) из `setup_isolated_nvm()` при каждом запуске.

Установка через `--install-lsp`.

## Связанные концепции

- [[библиотека/категории/nvm]]
- [[библиотека/категории/config]]
