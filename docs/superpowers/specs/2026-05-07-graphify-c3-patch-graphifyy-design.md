# Graphify Portability v2: Patch graphifyy Upstream (C3)

**Дата:** 2026-05-07
**Статус:** Одобрен
**Заменяет:** [2026-05-07-graphify-portability-design.md](2026-05-07-graphify-portability-design.md) (Layer 1)

## Контекст

Текущая реализация Layer 1 (hook-based normalize) работает, но избыточно сложна:

- 172 строки `normalize-paths.py` + 280 строк тестов
- 2 Claude hooks (Pre/PostToolUse Bash) триггерятся на КАЖДЫЙ Bash вызов
- Per-Bash overhead ~3-10ms (Python startup + regex check + early exit)
- Дублирующий вызов в `lib/graphify/install.sh`
- abs↔rel round-trip на каждом `graphify update`

## Анализ исходников graphifyy

Эмпирическая проверка native поведения (`graphify update .` без хуков) показывает:

| Файл | Native output | Требуется для git |
|---|---|---|
| `manifest.json` keys | `/abs/path/foo.py` | relative |
| `.graphify_root` | `/abs/path/project` | `.` |
| `cache/ast/*.json` `source_file` | `/abs/path/foo.py` | relative |
| `graph.json` `source_file` | relative (already!) — `_relativize_source_files` в `watch.py:34` | relative ✓ |

Где конкретно граффифи делает абсолютные пути:

- `detect.py:save_manifest` — keys = `f` где `f` = абсолютный из `extract` chain
- `watch.py:133` — `(out / ".graphify_root").write_text(str(watch_root))`, `watch_root = watch_path.resolve()` (всегда abs)
- `cache.py:save_cached` — пишет `result` как есть, `source_file` остаётся abs из extract.py

graphifyy сам с relative-путями работает корректно (проверено):

- `detect_incremental` использует `Path(f).stat()` — relative работает если CWD = project root
- `source_file` потребляется только как opaque-строка в `analyze.py` / `build.py`
- `.graphify_root` читается только в `graphify update` без аргументов; `Path(".").exists()` = true

→ **Абсолютные пути не нужны для функциональности**, только из-за неполной релативизации в graphifyy.

## Решение

Патчить vendored graphifyy в трёх точках. Удалить всю hook-инфраструктуру.

## Архитектура

```
[--install-graphify]
        │
        ├── uv tool install graphifyy
        │
        └── lib/graphify/apply_patches.sh
            └── patch vendored site-packages/graphify/{detect,watch,cache}.py
                └── marker: # ICLAUDE-PATCHED-v1

[runtime: graphify update .]
        │
        └── Пишет ВСЁ relative. Никаких хуков.

[git commit / pull]
        │
        └── Files уже portable. Никакой обработки.
```

## Patch scope (3 точки)

### 1. `detect.py:save_manifest` — relativize keys

```diff
@@ def save_manifest(files, manifest_path):
+    # ICLAUDE-PATCHED-v1: relativize keys for git portability
+    import os as _os
+    cwd = Path.cwd().resolve()
     for file_list in files.values():
         for f in file_list:
             try:
                 p = Path(f)
-                manifest[f] = {"mtime": p.stat().st_mtime, "hash": _md5_file(p)}
+                key = f
+                if p.is_absolute():
+                    rel = _os.path.relpath(f, cwd)
+                    if not rel.startswith(".."):
+                        key = rel
+                manifest[key] = {"mtime": p.stat().st_mtime, "hash": _md5_file(p)}
             except OSError:
                 pass
```

### 2. `watch.py:133` — `.graphify_root` preserves user input

```diff
-        (out / ".graphify_root").write_text(str(watch_root), encoding="utf-8")
+        # ICLAUDE-PATCHED-v1: preserve user-provided path (relative if user passed `.`)
+        (out / ".graphify_root").write_text(str(watch_path), encoding="utf-8")
```

### 3. `cache.py:save_cached` — relativize source_file

```diff
@@ def save_cached(path, result, root, kind="ast"):
+    # ICLAUDE-PATCHED-v1: relativize source_file for portability
+    root_abs = Path(root).resolve()
+    for bucket in ("nodes", "edges"):
+        for item in result.get(bucket, []):
+            sf = item.get("source_file", "")
+            if sf and Path(sf).is_absolute():
+                try:
+                    rel = os.path.relpath(sf, root_abs)
+                    if not rel.startswith(".."):
+                        item["source_file"] = rel
+                except ValueError:
+                    pass
     h = file_hash(p, root)
```

## Components

### `lib/graphify/patches/`

```
01-detect-relativize-manifest.patch
02-watch-relativize-graphify-root.patch
03-cache-relativize-source-file.patch
```

Unified diff format. `patch -p1` applicable.

### `lib/graphify/apply_patches.sh`

Idempotent applier. Algorithm:

```
1. Локализовать GRAPHIFY_PKG = $ISOLATED_NVM_DIR/.../site-packages/graphify
2. Для каждого *.patch в patches/:
   a. Извлечь target file из заголовка `+++ b/<file>`
   b. Если grep "ICLAUDE-PATCHED-v1" target → skip (already patched)
   c. patch -p1 --dry-run для валидации
   d. Если dry-run failed → print warning, skip (graphifyy upstream, вероятно, рефакторился)
   e. patch -p1 → apply
3. Exit 0 (best-effort — частичный успех допустим)
```

### `lib/graphify/install.sh` (изменение)

После `uv tool run --from graphifyy graphify "${graphify_args[@]}"`:

```bash
if [[ -f "$LIB_DIR/graphify/apply_patches.sh" ]]; then
    bash "$LIB_DIR/graphify/apply_patches.sh"
fi
```

Заменяет существующий вызов `normalize-paths.py abs2rel`.

## Удаляется

| Файл | Размер |
|---|---|
| `.nvm-isolated/.claude-isolated/hooks/normalize-paths.py` | 172 строки |
| `tests/test_normalize_paths.py` | ~280 строк |
| `settings.json` PreToolUse Bash hook (rel2abs) | 1 entry |
| `settings.json` PostToolUse Bash hook (abs2rel) | 1 entry |
| `lib/graphify/install.sh` normalize вызов | 4 строки |

## Не трогаем

- 7 hardcode `.graphify/` → `{GOUT}` в `graphify-context/SKILL.md`, `context-awareness/SKILL.md`, `graphify/SKILL.md` — Layer 2, орт. независимая проблема (про custom `GRAPHIFY_OUT`, не про path normalize)
- `graph.json`, `GRAPH_REPORT.md`, `graph.html`, `cost.json` — already portable

## Data flow (после patches)

```
graphify update .
    ├── detect(root)
    │     └── files: relative paths (existing)
    ├── extract(code_files, cache_root=watch_root)
    │     └── cache.save_cached(path, result, root)
    │            ├── PATCHED: relativize result["nodes"][i]["source_file"] vs root
    │            └── write cache/ast/{hash}.json (relative source_file)
    ├── save_manifest(detected["files"])
    │     └── PATCHED: relativize keys vs cwd → manifest.json (relative keys)
    ├── (out / ".graphify_root").write_text(str(watch_path))
    │     └── PATCHED: writes "." instead of resolved abs
    └── to_json → graph.json (relative source_file via existing _relativize_source_files)
```

## Edge cases

| Ситуация | Поведение |
|---|---|
| `graphify update /abs/path` (вне CWD) | watch.py:133 пишет `/abs/path` (correct — preserves user input). Patches detect/cache всё равно relativize content vs root |
| Обновление graphifyy upstream (новая версия) | apply_patches.sh dry-run fails → warning, skip. Patches требуют ручного review |
| Файл вне project root (symlinks etc) | `os.path.relpath` даёт `../`, patches пропускают (оставляют abs) |
| Pre-existing absolute manifest на новом ПК | Migration step (см. ниже). После migration всё native |
| `uv tool install --reinstall graphifyy` | Patches теряются. Решение: `apply_patches.sh` повторно вызывается из `install.sh` |

## Risks

1. **Fragility**: graphifyy upstream может рефакторить `save_manifest` / `save_cached` / `watch.py:133`. Mitigation:
   - Patches маленькие (~14 строк суммарно)
   - Marker comment `ICLAUDE-PATCHED-v1` для idempotency
   - Pin `graphifyy==X.Y.Z` в lockfile, manual review при unpin
   - apply_patches.sh degrades gracefully (warn + skip on dry-run fail)

2. **uv tool reinstall recreates venv**: pacthes теряются.
   Mitigation: `apply_patches.sh` запускается ВСЕГДА из `lib/graphify/install.sh` (idempotent через marker).

3. **Existing committed `.graphify/` с absolute путями**: после deploy patches новые runs пишут relative, но git history содержит abs. Migration step требуется (см. ниже).

4. **`apply_patches.sh` failure не блокирует install**: best-effort. Fallback — fall back на текущее non-portable поведение, не ломает функциональность graphify.

## Migration (one-shot после deploy)

```bash
# 1. Apply patches
./iclaude.sh --install-graphify

# 2. Rebuild .graphify/ с relative-путями
rm -rf .graphify/cache .graphify/manifest.json .graphify/.graphify_root
graphify update .

# 3. Verify portability
python3 -c "
import json
m = json.load(open('.graphify/manifest.json'))
assert all(not k.startswith('/') for k in m), 'manifest still has abs keys'
print('manifest OK')
"
test "$(cat .graphify/.graphify_root)" = "." && echo ".graphify_root OK"

# 4. Commit portable state
git add .graphify lib/graphify/patches lib/graphify/apply_patches.sh
git rm .nvm-isolated/.claude-isolated/hooks/normalize-paths.py tests/test_normalize_paths.py
git commit -m "refactor(graphify): replace normalize-paths hooks with vendored graphifyy patches"
```

## Testing

`tests/test_graphify_patches.py` (новый):

| Тест | Цель |
|---|---|
| `test_apply_patches_idempotent` | Повторный запуск не дублирует вставки, marker комментарий проверяется |
| `test_apply_patches_dry_run_fail_skips` | Если patch не применяется — exit 0 с warning, не блокирует |
| `test_manifest_keys_relative_after_update` | Запустить graphify update в tmp git repo, assert manifest keys не начинаются с `/` |
| `test_graphify_root_is_dot` | `.graphify_root` содержит `.` |
| `test_cache_source_file_relative` | `cache/ast/*.json` `source_file` без `/` |
| `test_portability_cycle` | abs2rel commit → симулировать clone в other_path → graphify update работает incrementally без full rebuild |

Все тесты запускают `graphify` через subprocess в `tmp_path`.

## Метрики упрощения

| Метрика | До (Layer 1) | После (C3) | Δ |
|---|---|---|---|
| Hook overhead per Bash call | ~3-10ms | 0 | -100% |
| Hook entries в `settings.json` | 2 | 0 | -2 |
| Кода нормализации (строк) | 172 + 280 = 452 | ~80 (patches) + ~50 (apply_patches.sh) + ~120 (тесты) = 250 | -202 |
| Round-trip abs↔rel на graphify call | 2 (Pre+Post) | 0 | -100% |
| install.sh wrapper | 4 строки (normalize call) | 4 строки (apply_patches call) | 0 |

Net: −202 строки, −2 hooks, −100% per-Bash overhead, +3 patch файла, +1 apply_patches.sh.

## Что не меняется

- graphifyy package source (не форк, патчим vendored copy)
- `.gitignore` (cache/ast/ остаётся в git для shared cache)
- `graph.json`, `GRAPH_REPORT.md` — уже portable
- Layer 2 SKILL.md hardcodes — отдельная задача
