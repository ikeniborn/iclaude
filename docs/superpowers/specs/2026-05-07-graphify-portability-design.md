# Graphify Knowledge Graph: Портативность через Git

**Дата:** 2026-05-07  
**Статус:** Одобрен

## Проблема

`.graphify/` committed в git содержит абсолютные пути текущей машины. При clone на другой ПК:

- `manifest.json` — ключи = абсолютные пути → `detect_incremental()` не находит файлы → полный rebuild
- `.graphify_root` — абсолютный путь проекта → `graphify update` без аргументов ломается
- `cache/ast/*.json` — поле `source_file` = абсолютные пути → cache miss на новой машине

Портативны уже: `graph.json`, `GRAPH_REPORT.md`, `graph.html`, `cost.json`, `.graphify_labels.json`, `.graphify_python`.

Дополнительная проблема (Слой 2): SKILL.md навыков hardcode `.graphify/` вместо `${GRAPHIFY_OUT}`, что ломается при нестандартном `GRAPHIFY_OUT`.

## Решение

Два независимых слоя.

### Слой 1: Hook-based нормализация путей

Python-скрипт `normalize-paths.py` работает в двух режимах:

- **abs2rel** — конвертирует абсолютные пути → относительные (для git)
- **rel2abs** — конвертирует обратно (для graphifyy Python runtime)

Скрипт срабатывает как Claude hook вокруг каждого Bash-вызова содержащего `graphify`.

Скрипт также вызывается из `lib/graphify/install.sh` после `graphify update` — для покрытия запусков вне Claude (через `--install-graphify`).

### Слой 2: SKILL.md hardcodes

7 замен `.graphify/` → `{GOUT}` в трёх навыках, где `{GOUT}` резолвится в Step 0 каждого навыка.

## Архитектура

```
[Claude: Bash tool с graphify]
        │
        ├── PreToolUse hook
        │   normalize-paths.py rel2abs
        │   (manifest/cache читаемы graphifyy)
        │
        ▼
[graphify update . / graphify build .]
        │
        └── PostToolUse hook
            normalize-paths.py abs2rel
            (manifest/cache портативны для git)

[Вне Claude: --install-graphify]
        └── lib/graphify/install.sh
            вызывает normalize-paths.py abs2rel после graphify
```

## Компоненты

### normalize-paths.py

**Расположение:** `.nvm-isolated/.claude-isolated/hooks/normalize-paths.py`

**Аргументы:** `abs2rel` | `rel2abs`

**Алгоритм:**

```
1. Прочитать stdin (JSON tool input от Claude hooks)
   Если stdin пустой или не JSON → режим "прямой вызов" (из install.sh), пропустить шаг 2
2. Если tool_name != Bash OR команда не содержит \bgraphify\b → exit 0 (no-op)
3. project_root = git rev-parse --show-toplevel || CWD
4. graphify_out = GRAPHIFY_OUT env || "graphify-out"
5. gout = project_root / graphify_out

Режим abs2rel:
  manifest.json:    ключи → os.path.relpath(key, project_root)
  .graphify_root:   → "."
  cache/ast/*.json: node.source_file → os.path.relpath(val, project_root)

Режим rel2abs:
  manifest.json:    ключи → str(Path(project_root) / key)
  .graphify_root:   → str(project_root)
  cache/ast/*.json: node.source_file → str(Path(project_root) / val)

Idempotency:
  abs2rel: пропускает ключи не начинающиеся с "/"
  rel2abs: пропускает ключи начинающиеся с "/"
```

**Производительность:** `cache/ast/*.json` обрабатываются параллельно через `concurrent.futures.ThreadPoolExecutor`.

### settings.json

Новые hooks добавляются к существующим PreToolUse и PostToolUse:

```json
"PreToolUse": [
  { ...существующие block-secrets, redact-secrets... },
  {
    "matcher": "Bash",
    "hooks": [{
      "type": "command",
      "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/normalize-paths.py\" rel2abs"
    }]
  }
],
"PostToolUse": [{
  "matcher": "Bash",
  "hooks": [{
    "type": "command",
    "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/normalize-paths.py\" abs2rel"
  }]
}]
```

`$CLAUDE_CONFIG_DIR` — существующая переменная окружения, портативна между ПК.

### lib/graphify/install.sh

После вызова `graphify update` добавить:

```bash
python3 "$CLAUDE_CONFIG_DIR/hooks/normalize-paths.py" abs2rel < /dev/null
```

Пустой stdin → скрипт переходит в режим прямого вызова: пропускает проверку Bash команды, сразу выполняет нормализацию.

### SKILL.md изменения (Слой 2)

Step 0 добавляется в начало `graphify-context/SKILL.md` и `graphify/SKILL.md`:

```bash
GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")
```

Замены в трёх файлах:

| Файл | Количество замен | Шаблон |
|------|-----------------|--------|
| `graphify-context/SKILL.md` | 5 | `.graphify/` → `{GOUT}/` |
| `context-awareness/SKILL.md` | 1 | `{CWD}/.graphify/` → `{CWD}/{GOUT}/` |
| `graphify/SKILL.md` | 1 | `graphify-out/` → `${GRAPHIFY_OUT:-graphify-out}/` |

## Edge Cases

| Ситуация | Поведение |
|----------|-----------|
| Bash команда без `graphify` | exit 0, ~3ms overhead |
| `GRAPHIFY_OUT` не задан | fallback `graphify-out` |
| Скрипт вызван дважды в одном режиме | idempotent, пропускает уже конвертированные |
| graphify crash, manifest не перезаписан | PostToolUse нормализует что есть |
| Запуск вне Claude (терминал) | `--install-graphify` / `lib/graphify/install.sh` вызывает нормализацию |
| git не найден | fallback CWD |
| Путь файла вне project_root | `os.path.relpath` даёт `../../...` — пропускаем такие пути (не трогаем) |

## Изменённые файлы

```
Новые:
  .nvm-isolated/.claude-isolated/hooks/normalize-paths.py

Изменённые:
  .nvm-isolated/.claude-isolated/settings.json
  lib/graphify/install.sh
  .nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md
  .nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md
  .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md
```

## Что не меняется

- graphifyy Python пакет — не патчим upstream
- `.gitignore` — cache/ast/ остаётся в git (для инкрементальности между ПК после нормализации)
- `graph.json`, `GRAPH_REPORT.md` — уже портативны, не трогаем
