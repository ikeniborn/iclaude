---
wiki_sources:
  - "virtual:commit-note/graphify-integration-2026-05-07"
  - ".nvm-isolated/.claude-isolated/skills/graphify/SKILL.md"
  - ".nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md"
  - ".nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md"
  - "lib/launcher/launch.sh"
  - "lib/graphify/install.sh"
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
  - "watch.py"
  - "save-result"
  - "_patch_graphify_watch"
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

## Явные пути в CLI-командах skill-файлов

### graphify-context/SKILL.md: --graph flag

До изменения: CLI-команды `graphify query / path / explain` использовали дефолтный путь (`graphify-out/graph.json`), игнорируя `GRAPHIFY_OUT`. После изменения: каждый вызов передаёт явный `--graph "${GRAPHIFY_OUT}/graph.json"`:

```bash
# Широкий обзор компонентов
graphify query "..." --budget 1200 --graph "${GRAPHIFY_OUT}/graph.json"

# Трассировка пути
graphify path "ComponentA" "ComponentB" --graph "${GRAPHIFY_OUT}/graph.json"

# Контекст узла
graphify explain "ClassName" --graph "${GRAPHIFY_OUT}/graph.json"
```

Без явного `--graph` CLI-бинарь использовал хардкод `graphify-out/graph.json`, что приводило к ошибкам при нестандартном `GRAPHIFY_OUT`.

### graphify/SKILL.md: --memory-dir flag

До изменения: `save-result` вызовы использовали дефолтный `--memory-dir` (`graphify-out/memory`), создавая паразитный каталог `graphify-out/` при `GRAPHIFY_OUT != graphify-out`. После изменения: явный `--memory-dir "${GRAPHIFY_OUT}/memory"`:

```bash
$(cat "${GRAPHIFY_OUT}/.graphify_python") -m graphify save-result \
  --question "..." --answer "..." --type query --nodes NODE1 \
  --memory-dir "${GRAPHIFY_OUT}/memory"
```

Применено во всех трёх операциях: `query`, `path_query`, `explain`.

## Патч watch.py: auto-patch при каждом rebuild

### Проблема

`graphify.watch._rebuild_code()` вызывал `save_manifest(detected["files"])` без аргумента `manifest_path` — upstream bug в `graphifyy`. Без него функция использовала хардкод `graphify-out/manifest.json`, независимо от `GRAPHIFY_OUT`.

### Решение: `_patch_graphify_watch()`

В `lib/graphify/install.sh` добавлена функция `_patch_graphify_watch()`:

```bash
_patch_graphify_watch() {
    local watch_py
    watch_py=$(UV_TOOL_DIR="$GRAPHIFY_TOOL_DIR" \
        "$uv_bin" tool run --from graphifyy python3 \
        -c "import graphify.watch; print(graphify.watch.__file__)" 2>/dev/null)
    [[ -z "$watch_py" || ! -f "$watch_py" ]] && return 0

    # Idempotent: patch только если непатченная строка присутствует
    if grep -qF 'save_manifest(detected["files"])' "$watch_py"; then
        if sed -i 's|save_manifest(detected\["files"\])|save_manifest(detected["files"], manifest_path=str(out / "manifest.json"))|' "$watch_py"; then
            print_info "Patched graphify watch.py: save_manifest now uses explicit manifest_path"
        else
            print_warning "Failed to patch graphify watch.py (sed error — check permissions)"
        fi
    fi
}
```

**Идемпотентность:** патч применяется только если непатченная строка ещё присутствует. При ошибке `sed` выводится предупреждение вместо молчаливого игнорирования.

**Точки вызова:**
- После `uv tool install` в `install_graphify()` — один раз при установке
- В начале `_graphify_rebuild_graph()` — защитно перед каждым rebuild

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
  Phase 1: graphify query/path/explain + --graph "${GRAPHIFY_OUT}/graph.json"

graphify/SKILL.md
  Step 0.5: echo "${GRAPHIFY_OUT:-graphify-out}"
  Step 1+: использует разрешённое значение буквально
  save-result: всегда с --memory-dir "${GRAPHIFY_OUT}/memory"
```

## Паттерн Step 0

Во всех трёх skill-файлах применяется единый паттерн для разрешения пути перед использованием:

```bash
GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")
```

`echo` используется намеренно — субоболочка выполняет подстановку переменной и возвращает конкретную строку, которая затем используется литерально во всех путях. Это делает поведение предсказуемым независимо от того, задан ли `GRAPHIFY_OUT` в environment или нет.

## Связанные компоненты

- `lib/graphify/install.sh` — функции `install_graphify()`, `_graphify_rebuild_graph()`, `_patch_graphify_watch()`
- `lib/graphify/detect.sh`, `lib/graphify/status.sh` — дополнительные модули graphify
- `lib/launcher/launch.sh` → `_sync_graphify_env_to_settings()` — синхронизация GRAPHIFY_OUT в settings.json
- `.graphify/` — директория вывода graphify для проекта iclaude
- `~/.graphify/repos/` — глобальный кэш клонированных GitHub-репозиториев
