---
wiki_sources:
  - "virtual:commit-note/graphify-integration-2026-05-07"
  - ".nvm-isolated/.claude-isolated/skills/graphify/SKILL.md"
  - ".nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md"
  - ".nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md"
  - "lib/launcher/launch.sh"
wiki_updated: 2026-05-07
wiki_status: developing
wiki_outgoing_links:
  - "[[модульная-структура|Модульная структура (lib/)]]"
  - "[[claude-config|Конфигурационный файл (.claude_config)]]"
tags:
  - iclaude
  - documentation
aliases:
  - "graphify"
  - "GRAPHIFY_OUT"
  - "knowledge graph"
  - "graphify-context"
  - "graphify skills"
---

# Graphify-интеграция iclaude

Graphify — модуль построения knowledge graph. В iclaude интегрирован через `lib/graphify/` и три skill-файла: `graphify/SKILL.md`, `graphify-context/SKILL.md`, `context-awareness/SKILL.md`.

## Ключевая переменная: GRAPHIFY_OUT

`GRAPHIFY_OUT` — переменная окружения, задающая директорию вывода graphify (по умолчанию: `graphify-out`). Для текущего проекта iclaude значение — `.graphify`.

### Как передаётся в Claude Code

`_sync_graphify_env_to_settings()` в `lib/launcher/launch.sh` записывает актуальное значение `GRAPHIFY_OUT` в `env`-блок `settings.json` **перед каждым запуском** Claude Code:

```bash
# lib/launcher/launch.sh
_sync_graphify_env_to_settings() {
    [[ -z "${GRAPHIFY_OUT:-}" ]] && return 0
    python3 - "$settings_file" "$GRAPHIFY_OUT" <<'PYEOF'
    # ...дописывает env.GRAPHIFY_OUT в settings.json
}
# Вызов перед launch:
_sync_graphify_env_to_settings
```

Без этой синхронизации `${GRAPHIFY_OUT:-graphify-out}` в bash-блоках skill-файлов откатывался бы к `graphify-out` независимо от реального конфига проекта.

## Устранение хардкода `.graphify/` в skill-файлах

До изменения: path-check инструкции в `graphify-context/SKILL.md` и `context-awareness/SKILL.md` содержали хардкод `.graphify/` (путь, специфичный для iclaude). После изменения: добавлен **Step 0** с динамическим резолвингом перед каждой проверкой пути:

```bash
GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")
```

Далее все проверки используют `{GOUT}` вместо `.graphify/`.

### Где применён Step 0

| Файл | Изменение |
|------|-----------|
| `graphify-context/SKILL.md` | Добавлен Step 0 (`GOUT=$(echo ...)`) перед Phase 0 path-check |
| `context-awareness/SKILL.md` | Добавлен Step 0 (`GOUT=$(echo ...)`) в секции Graph Detection |
| `graphify/SKILL.md` | Уже содержал Step 0.5 — паттерн-образец |

### Оставшиеся ссылки на `.graphify/`

Не все вхождения `.graphify/` являются хардкодом проекта:

- `~/.graphify/repos/` — глобальный кэш клонов GitHub-репозиториев (корректно, не проектный путь)
- Example 4c в `context-awareness/SKILL.md` — намеренно показывает проектно-специфичный конфиг iclaude с комментарием `GRAPHIFY_OUT=.graphify for this project`

## Архитектура skill-слоя

```
context-awareness/SKILL.md
  Phase 6: Graph Detection
    → GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")
    → IF exists {CWD}/{GOUT}/GRAPH_REPORT.md
    → Skill(skill="graphify-context")

graphify-context/SKILL.md
  Step 0: GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")
  Phase 0: IF exists {CWD}/{GOUT}/GRAPH_REPORT.md
  Phase 1: graphify query / path / explain CLI

graphify/SKILL.md
  Step 0.5: echo "${GRAPHIFY_OUT:-graphify-out}"
  Step 1+: использует разрешённое значение буквально
```

## Паттерн Step 0

Во всех трёх skill-файлах применяется единый паттерн для разрешения пути перед использованием:

```bash
GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")
```

`echo` используется намеренно — субоболочка выполняет подстановку переменной и возвращает конкретную строку, которая затем используется литерально во всех путях. Это делает поведение предсказуемым независимо от того, задан ли `GRAPHIFY_OUT` в environment или нет.

## Связанные компоненты

- `lib/graphify/` — bash-модуль установки graphify (`--install-graphify`)
- `lib/launcher/launch.sh` → `_sync_graphify_env_to_settings()` — синхронизация GRAPHIFY_OUT в settings.json
- `.graphify/` — директория вывода graphify для проекта iclaude
- `~/.graphify/repos/` — глобальный кэш клонированных GitHub-репозиториев
