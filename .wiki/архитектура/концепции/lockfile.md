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
  - ".nvm-isolated-lockfile.json"
  - "lockfile"
  - "версионирование окружения"
---

# Lockfile

Механизм фиксации точных версий компонентов изолированного окружения для воспроизводимой установки.

## Основные характеристики

**Файл:** `.nvm-isolated-lockfile.json`

### Структура

Содержит зафиксированные версии:
- `nvmVersion` — версия NVM
- `nodeVersion` — версия Node.js (например `18.20.8`)
- `claudeCodeVersion` — версия `@anthropic-ai/claude-code`
- `routerVersion` — версия CCR (или `"not installed"`)
- `jqVersion` — версия jq бинарника (с Phase 2)

### Операции с lockfile

| Команда | Операция |
|---------|---------|
| `./iclaude.sh --isolated-install` | Создаёт lockfile после установки |
| `./iclaude.sh --update` | Обновляет Claude Code и перезаписывает lockfile |
| `./iclaude.sh --install-from-lockfile` | Устанавливает точные версии из lockfile |
| `./iclaude.sh --check-isolated` | Показывает текущие версии vs lockfile |

### Воспроизводимость

После `git clone`:
```bash
./iclaude.sh --repair-isolated       # скачать нативный бинарник
./iclaude.sh --install-from-lockfile # установить зафиксированные версии
```

### Рекомендации

- Проверять lockfile после `--update`
- Коммитить lockfile в git для team-воспроизводимости
- Нативный бинарник (`bin/claude.exe`) в git НЕ коммитится (>100MB)

## Связанные концепции

- [[изолированное-окружение]]
- [[../компоненты/isolated-environment]]
- [[../потоки/поток-изолированной-установки]]
