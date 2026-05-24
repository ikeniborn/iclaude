# lat.md Integration Design

**Date:** 2026-05-24
**Status:** Approved

## Overview

Интеграция [lat.md](https://github.com/1st1/lat.md) в iclaude как documentation graph layer — дополнение к graphify (code graph). Решает проблему слабой связи кода с документацией и потери контекста агентом между сессиями.

**Что удаляется:** скилл `llm-wiki` (неэффективен — нет referential integrity, нет code↔doc linkage).

**Что добавляется:** `lib/lat/` модуль по образцу `lib/graphify/`, Node 22 upgrade, MCP server, pre-commit hook, обновлённый `update-docs`.

## Разделение ответственности

| Слой | Инструмент | Покрывает |
|------|-----------|-----------|
| Code graph | graphify | структура файлов, зависимости, кластеры |
| Doc graph | lat.md | архитектурные решения, WHY, `[[ссылки]]` |
| Agent tools | lat mcp | семантический поиск по документации |
| Integrity | lat check | сломанные `[[refs]]` = блок коммита |

## Архитектура

```
iclaude launch
      │
      ├── lib/graphify/  ──→  graphify-out/     (code graph)
      │
      └── lib/lat/       ──→  lat.md/            (doc graph)
               │
               ↓
    settings.json → mcpServers: { lat: "lat mcp" }
               │
               ↓
    Agent MCP tools: lat_search, lat_locate, lat_refs, lat_section
```

## Node.js Upgrade

lat.md требует Node 22+. Текущая изолированная среда — Node 20.20.2.

`--install-lat` выполняет:
```bash
nvm install 22
nvm alias default 22
```

Это обновляет версию по умолчанию для всей изолированной среды (Claude Code запускается на Node 22). Node 22 — активный LTS, совместим с Claude Code.

## Новые файлы

```
lib/lat/
  install.sh   — install_lat()        : Node 22 upgrade + npm install -g lat.md + MCP inject
  detect.sh    — detect_lat()         : проверяет lat CLI в изолированном npm
               — detect_lat_project() : ищет lat.md/ в $CWD
  mcp.sh       — inject_lat_mcp()     : добавляет lat mcp в settings.json mcpServers
  check.sh     — run_lat_check()      : запускает lat check в проекте
               — install_lat_precommit() : пишет/дополняет .git/hooks/pre-commit
               — remove_lat_precommit() : удаляет секцию lat из pre-commit hook
```

## Переменные в `lib/core/init.sh`

Добавляются в `init_environment()`:

```bash
LAT_ENABLED=false          # устанавливается в true при detect_lat() + detect_lat_project()
LAT_BIN=""                 # путь к lat CLI (resolve при detect)
LAT_PROJECT_ROOT=""        # путь к lat.md/ в текущем проекте
```

## Новые флаги в `iclaude.sh`

| Флаг | Описание |
|------|---------|
| `--install-lat` | Node 22 + npm install lat.md + MCP в settings.json |
| `--lat-init` | `lat init` в текущем проекте (scaffold lat.md/) |
| `--lat-check` | `lat check` + pre-commit hook setup |
| `--check-lat` | статус: lat версия, lat.md/ найдена/нет, MCP настроен/нет |

## MCP Integration

`inject_lat_mcp()` вызывается **при каждом запуске** iclaude (не только при `--install-lat`) и записывает актуальный config в `settings.json` перед стартом Claude Code:

```json
{
  "mcpServers": {
    "lat": {
      "type": "stdio",
      "command": "$NPM_CONFIG_PREFIX/bin/lat",
      "args": ["mcp"],
      "cwd": "$PROJECT_ROOT"
    }
  }
}
```

Оба значения подставляются `inject_lat_mcp()` как абсолютные пути:
- `command` — `$NPM_CONFIG_PREFIX/bin/lat` (задан при установке, не меняется)
- `cwd` — `$PROJECT_ROOT` (рабочий каталог текущего запуска iclaude; `git rev-parse --show-toplevel` или `$PWD`)

Так lat mcp всегда работает в контексте запущенного проекта. Если `lat.md/` не найдена в `$PROJECT_ROOT`, MCP сервер стартует, инструменты возвращают пустые результаты (не фатально).

## Data Flow

### Install
```
./iclaude.sh --install-lat
  → nvm install 22 && nvm alias default 22
  → npm install -g lat.md
  → print_success "lat.md installed. MCP wires automatically on each launch."
```

### Launch (авто-детект)
```
./iclaude.sh
  → detect_lat()                        → lat CLI найден?
  → detect_lat_project()                → lat.md/ в $PROJECT_ROOT?
  → оба true  → LAT_ENABLED=true
               → inject_lat_mcp()       → settings.json (command + cwd актуальны)
               → lat mcp стартует при запуске Claude
  → один false → silent skip (MCP не добавляется)
```

### --lat-check
```
./iclaude.sh --lat-check
  → detect_lat_project() → нет lat.md/ → ошибка + hint --lat-init
  → есть → lat check
      exit 0 → "All references valid ✓"
      exit 1 → список broken refs + exit 1
  → install_lat_precommit() если hook не установлен
```

### Pre-commit hook
```
git commit
  → .git/hooks/pre-commit → lat check
      exit 0 → commit продолжается
      exit 1 → commit заблокирован + broken refs
```

### update-docs (после разработки)
```
/update-docs
  Phase 1: graphify update .           ← code graph rebuild
  Phase 2: lat check                   ← doc integrity validation
  Phase 3: обновить lat.md/ секции     ← синк изменённых doc sections
```

## Изменения скиллового слоя

### Удалить
```
.nvm-isolated/.claude-isolated/skills/llm-wiki/   ← весь каталог
```

### Обновить `update-docs` скилл
Добавить Phase 2 и Phase 3 (lat check + doc sync). Убрать упоминания llm-wiki.

### Обновить `CLAUDE.md` (корень проекта)
- Убрать: llm-wiki из таблицы Features и раздела Maintenance
- Добавить: lat.md workflow, `--install-lat`, `--lat-init`, `--lat-check`

### Обновить `MEMORY.md`
- Убрать: llm-wiki упоминания
- Добавить: lat.md как doc graph инструмент

## Изменения в `lib/command/usage.sh`

Добавить в `show_usage()`:
```
  --install-lat          Install lat.md documentation graph tool (Node 22 + MCP)
  --lat-init             Initialize lat.md knowledge graph in current project
  --lat-check            Check documentation link integrity (lat check)
  --check-lat            Show lat.md installation and project status
```

## Совместимость

- Все существующие флаги iclaude сохраняются без изменений
- graphify работает независимо (Python/uv, не затронут)
- Node 22 обратно совместим с Node 20 для Claude Code
- pre-commit hook: идемпотентный (повторный `--lat-check` не дублирует hook)
- MCP: `lat mcp` без `lat.md/` — не фатально, silent

## Out of scope (v1)

- `lat search` с семантикой (требует OpenAI/Vercel API key) — пользователь настраивает самостоятельно
- Авто-аннотация кода `// @lat:` — ручной процесс, документируется в README
- Интеграция `lat expand` в pre-prompt агента
