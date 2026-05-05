---
wiki_sources:
  - "docs/architecture/overview.yaml"
  - "docs/architecture/diagrams/data-flow-isolated-installation.md"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - architecture
  - iclaude
aliases:
  - "Installation Layer"
  - "Слой установки"
---

# Installation-слой (Слой установки)

Архитектурный слой iclaude, отвечающий за установку и обновление NVM, Node.js, Claude Code и Claude Code Router в изолированное окружение `.nvm-isolated/`.

## Основные характеристики

**Ответственности:**
- Загрузка и установка NVM в изолированную директорию
- Установка конкретных версий Node.js через NVM
- Установка Claude Code CLI через npm
- Установка Claude Code Router (CCR) при необходимости
- Создание и поддержка симлинков на бинарники
- Очистка временных установок (`.claude-code-*`)

**Компоненты слоя:**

| Компонент | Строки | Назначение |
|-----------|--------|-----------|
| `nvm-installer` | 448–484 | Загрузка и установка NVM |
| `nodejs-installer` | 485–531 | Установка Node.js через NVM |
| `claude-installer` | 532–589 | Установка Claude Code через npm |
| `router-installer` | 590–644 | Установка Claude Code Router |
| `claude-updater` | 645–731 | Обновление Claude Code |
| `cleanup-old-installations` | 2268–2405 | Удаление временных папок |
| `symlink-manager` | 2406–2698 | Создание симлинков npm/npx/claude/ccr |
| `nvm-detector` | 204–237 | Определение NVM (isolated или system) |
| `claude-path-finder` | 238–332 | Поиск бинарника Claude Code |
| `version-detector` | 384–421 | Определение установленной версии CLI |

## Артефакты установки

| Путь | Описание |
|------|----------|
| `.nvm-isolated/` | Корень изолированного окружения |
| `.nvm-isolated/versions/node/vX.X.X/` | Node.js |
| `.nvm-isolated/npm-global/bin/claude` | Симлинк или нативный бинарник CLI |
| `.nvm-isolated/npm-global/bin/claude.exe` | Нативный бинарник (v2.1.114+) |
| `.nvm-isolated-lockfile.json` | Файл зафиксированных версий |

## Связанные концепции

- [[core-слой]]
- [[sandbox-слой]]
- [[поток-изолированной-установки]]
