---
wiki_sources:
  - "docs/architecture/overview.yaml"
  - "docs/architecture/diagrams/README.md"
wiki_updated: 2026-05-05
wiki_status: stub
tags:
  - architecture
  - iclaude
aliases:
  - "nvm-isolated"
  - "изолированная установка"
---

# Isolated Environment

Менеджер изолированного окружения iclaude. Управляет переносимой установкой NVM + Node.js + Claude Code в директории `.nvm-isolated/`, не затрагивая системное окружение.

## Основные характеристики

**Расположение в коде:** `iclaude.sh:422-1121`

### Структура директории

```
.nvm-isolated/
├── versions/node/v18.x.x/    ← Node.js
├── npm-global/bin/
│   ├── claude                 ← симлинк
│   ├── bin/claude.exe         ← нативный бинарник (v2.1.114+, ~237MB)
│   └── cli.js                 ← legacy (до v2.1.114)
└── .claude-isolated/
    ├── settings.json
    ├── hooks/
    └── skills/
```

### Субкомпоненты

- `setup_isolated_nvm` (`iclaude.sh:422-446`) — конфигурация `NVM_DIR`, `PATH`
- `install_isolated_nvm` — скачивание и установка NVM в `.nvm-isolated/`
- `repair_isolated_environment` (`iclaude.sh:955-1120`) — восстановление симлинков после `git clone`
- `check_isolated_status` (`iclaude.sh:1122-1241`) — отображение состояния окружения

### Обнаружение бинарника Claude (порядок)

1. `$npm_prefix/bin/claude` (симлинк)
2. `bin/claude.exe` (нативный бинарник, v2.1.114+)
3. `cli.js` через `node` (legacy до v2.1.114)

### Переменные окружения

| Переменная | Значение | Когда устанавливается |
|-----------|---------|----------------------|
| `ISOLATED_NVM_DIR` | `.nvm-isolated/` | `lib/core/init.sh` |
| `CLAUDE_CONFIG_DIR` | `.nvm-isolated/.claude-isolated/` | перед запуском Claude |
| `NPM_CONFIG_PREFIX` | `$ISOLATED_NVM_DIR/npm-global` | `lib/nvm/setup.sh` |

### После git clone

Нативный бинарник (`bin/claude.exe`, ~237MB) исключён из git. Необходимо выполнить:

```bash
./iclaude.sh --repair-isolated
```

## Связанные концепции

- [[../концепции/изолированное-окружение]]
- [[../концепции/lockfile]]
- [[../потоки/поток-изолированной-установки]]
