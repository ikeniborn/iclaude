# Intent: lat hooks portable + lat-check/lat-search skills

**Date:** 2026-05-25
**Status:** approved

## Objective

`inject_lat_mcp()` записывает абсолютный путь `$LAT_BIN` в хуки `settings.json`.
При смене пути iclaude (переезд папки, другая машина, другой пользователь) хуки ломаются.
В других проектах Claude не может выполнить `lat search`/`lat check` — нет навыков,
бинарник не в PATH. Исправить сейчас, потому что хуки уже ломают Stop feedback loop.

## Desired Outcomes

- Хуки в `settings.json` не содержат абсолютных путей — резолвят `lat` через `$CLAUDE_CONFIG_DIR` в runtime
- Навыки `lat-check` и `lat-search` существуют в `.nvm-isolated/.claude-isolated/skills/`
- Claude в любом проекте с `lat.md/` вызывает навык и получает результаты через embedded бинарник iclaude
- Хук Stop не вызывает "lat not found" ни в iclaude-проекте, ни в других проектах
- CLAUDE.md, `lat-md` навык и другие зависимые навыки вызывают `lat-check`/`lat-search` через Skill tool, а не через raw bash `lat check`
- `lat check` проходит после всех изменений

## Health Metrics

- MCP сервер lat продолжает работать в iclaude-проекте
- `--install-lat` / `--lat-check` / `--lat-init` команды не ломаются
- Хуки молчат в проектах без `lat.md/` (условие `[[ -d "$LAUNCH_DIR/lat.md" ]]` сохраняется)
- Stop hook продолжает выводить feedback о несинхронизированных изменениях

## Strategic Context

- Взаимодействует с: `lib/lat/mcp.sh`, `settings.json`, `lat-mcp-wrapper.sh`, навыки в `skills/`
- Приоритет: **trust** (правильная архитектура) + **fix** (устранить текущую ломку) одновременно

## Constraints

### Steering (behavioral guidance)

- Хуки резолвят путь к `lat` через `$CLAUDE_CONFIG_DIR` вместо захардкоженного `$LAT_BIN`
- Навыки `lat-check`/`lat-search` сами находят бинарник (не зависят от системного PATH)
- `inject_lat_mcp()` не пишет абсолютные пути в `settings.json`
- Модель для хуков — `lat-mcp-wrapper.sh` (уже использует `dirname "$0"`)

### Hard (architectural enforcement)

- `settings.json` в `$CLAUDE_CONFIG_DIR` — единственный источник конфига хуков
- Навыки живут в `.nvm-isolated/.claude-isolated/skills/` iclaude (не копируются в проекты)
- Не создавать симлинки lat в системе (ограничение изолированной среды)

## Autonomy Zones

- **Full autonomy**: изменение `inject_lat_mcp()`, создание навыков `lat-check`/`lat-search`, правка `lat-mcp-wrapper.sh`
- **Guarded**: обновление зависимых навыков (CLAUDE.md, `lat-md` skill, idd, update-docs) — показать diff перед применением
- **Proposal-first**: изменение формата или структуры `settings.json`
- **No autonomy**: изменение поведения Stop hook (только обсуждение)

## Stop Rules

- **Halt if**: lat MCP перестаёт работать в iclaude-проекте после изменений
- **Escalate if**: найден третий способ где абсолютные пути захардкоджены (кроме хуков и MCP)
- **Done when**: хуки в `settings.json` без абсолютных путей + навыки `lat-check`/`lat-search` работают в другом проекте + `lat check` проходит
