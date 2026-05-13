# Graphify Portability: Нормализация путей Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Сделать `.graphify/` портативным между ПК через git — конвертировать абсолютные пути ↔ относительные через Claude hooks и standalone script.

**Architecture:** Python-скрипт `normalize-paths.py` конвертирует пути в трёх файлах (manifest.json, .graphify_root, cache/ast/*.json). Срабатывает как Claude PreToolUse (rel→abs перед graphify) и PostToolUse (abs→rel после graphify) hook. Вызывается также из `lib/graphify/install.sh` после graphify update вне Claude.

**Tech Stack:** Python 3.12 (stdlib только: json, os, re, subprocess, pathlib, concurrent.futures), pytest, bash.

---

## File Map

```
Создать:
  .nvm-isolated/.claude-isolated/hooks/normalize-paths.py   ← скрипт нормализации
  tests/test_normalize_paths.py                             ← pytest тесты

Изменить:
  .nvm-isolated/.claude-isolated/settings.json              ← добавить Pre/PostToolUse hooks
  lib/graphify/install.sh:60-62                             ← вызов normalize после graphify
```

---

### Task 1: Написать тесты для normalize-paths.py

**Files:**
- Create: `tests/test_normalize_paths.py`

- [ ] **Step 1: Создать файл тестов**

```python
#!/usr/bin/env python3
"""Tests for normalize-paths.py path normalization logic."""
import json
import sys
import os
import tempfile
from pathlib import Path
import pytest

# Добавляем hooks/ в путь для импорта
HOOKS_DIR = Path(__file__).parent.parent / ".nvm-isolated" / ".claude-isolated" / "hooks"
sys.path.insert(0, str(HOOKS_DIR))

import normalize_paths as np_mod


@pytest.fixture
def tmp_gout(tmp_path):
    """Создаёт временную .graphify/-подобную директорию."""
    gout = tmp_path / ".graphify"
    gout.mkdir()
    (gout / "cache" / "ast").mkdir(parents=True)
    return gout


PROJECT_ROOT = Path("/home/alice/projects/myproject")
OTHER_ROOT = Path("/home/bob/repos/myproject")


class TestGetProjectRoot:
    def test_reads_abs_path_from_graphify_root(self, tmp_gout, tmp_path):
        (tmp_gout / ".graphify_root").write_text(str(tmp_path))

        result = np_mod.get_project_root(tmp_gout)

        assert result == tmp_path

    def test_ignores_dot_in_graphify_root(self, tmp_gout, monkeypatch):
        (tmp_gout / ".graphify_root").write_text(".")
        # git rev-parse вернёт что-то — мокаем
        monkeypatch.setattr(
            "subprocess.check_output",
            lambda *a, **kw: "/home/alice/project\n"
        )

        result = np_mod.get_project_root(tmp_gout)

        assert result == Path("/home/alice/project")

    def test_fallback_to_cwd_without_git(self, tmp_gout, monkeypatch):
        import subprocess as sp
        monkeypatch.setattr(
            "subprocess.check_output",
            lambda *a, **kw: (_ for _ in ()).throw(sp.CalledProcessError(128, "git"))
        )

        result = np_mod.get_project_root(tmp_gout)

        assert result == Path.cwd()


class TestNormalizeManifest:
    def test_abs2rel_converts_keys(self, tmp_gout):
        manifest = {
            str(PROJECT_ROOT / "lib/foo.py"): {"mtime": 1.0, "hash": "abc"},
            str(PROJECT_ROOT / "README.md"): {"mtime": 2.0, "hash": "def"},
        }
        (tmp_gout / "manifest.json").write_text(json.dumps(manifest))

        np_mod.normalize_manifest(tmp_gout, PROJECT_ROOT, "abs2rel")

        result = json.loads((tmp_gout / "manifest.json").read_text())
        assert "lib/foo.py" in result
        assert "README.md" in result
        assert str(PROJECT_ROOT / "lib/foo.py") not in result

    def test_rel2abs_converts_keys(self, tmp_gout):
        manifest = {
            "lib/foo.py": {"mtime": 1.0, "hash": "abc"},
            "README.md": {"mtime": 2.0, "hash": "def"},
        }
        (tmp_gout / "manifest.json").write_text(json.dumps(manifest))

        np_mod.normalize_manifest(tmp_gout, PROJECT_ROOT, "rel2abs")

        result = json.loads((tmp_gout / "manifest.json").read_text())
        assert str(PROJECT_ROOT / "lib/foo.py") in result
        assert str(PROJECT_ROOT / "README.md") in result
        assert "lib/foo.py" not in result

    def test_abs2rel_idempotent(self, tmp_gout):
        manifest = {"lib/foo.py": {"mtime": 1.0, "hash": "abc"}}
        (tmp_gout / "manifest.json").write_text(json.dumps(manifest))

        np_mod.normalize_manifest(tmp_gout, PROJECT_ROOT, "abs2rel")

        result = json.loads((tmp_gout / "manifest.json").read_text())
        assert "lib/foo.py" in result

    def test_rel2abs_idempotent(self, tmp_gout):
        manifest = {str(PROJECT_ROOT / "lib/foo.py"): {"mtime": 1.0, "hash": "abc"}}
        (tmp_gout / "manifest.json").write_text(json.dumps(manifest))

        np_mod.normalize_manifest(tmp_gout, PROJECT_ROOT, "rel2abs")
        np_mod.normalize_manifest(tmp_gout, PROJECT_ROOT, "rel2abs")

        result = json.loads((tmp_gout / "manifest.json").read_text())
        assert str(PROJECT_ROOT / "lib/foo.py") in result

    def test_skips_paths_outside_project_root(self, tmp_gout):
        manifest = {"/etc/passwd": {"mtime": 1.0, "hash": "abc"}}
        (tmp_gout / "manifest.json").write_text(json.dumps(manifest))

        np_mod.normalize_manifest(tmp_gout, PROJECT_ROOT, "abs2rel")

        result = json.loads((tmp_gout / "manifest.json").read_text())
        assert "/etc/passwd" in result

    def test_missing_manifest_no_error(self, tmp_gout):
        np_mod.normalize_manifest(tmp_gout, PROJECT_ROOT, "abs2rel")  # no exception

    def test_portability_abs2rel_then_rel2abs_other_machine(self, tmp_gout):
        """Симулирует git clone на другой машине."""
        manifest = {
            str(PROJECT_ROOT / "lib/foo.py"): {"mtime": 1.0, "hash": "abc"},
        }
        (tmp_gout / "manifest.json").write_text(json.dumps(manifest))

        # На исходной машине: abs→rel
        np_mod.normalize_manifest(tmp_gout, PROJECT_ROOT, "abs2rel")

        # На новой машине: rel→abs с другим root
        np_mod.normalize_manifest(tmp_gout, OTHER_ROOT, "rel2abs")

        result = json.loads((tmp_gout / "manifest.json").read_text())
        assert str(OTHER_ROOT / "lib/foo.py") in result


class TestNormalizeRoot:
    def test_abs2rel_writes_dot(self, tmp_gout):
        (tmp_gout / ".graphify_root").write_text(str(PROJECT_ROOT))

        np_mod.normalize_root(tmp_gout, PROJECT_ROOT, "abs2rel")

        assert (tmp_gout / ".graphify_root").read_text() == "."

    def test_rel2abs_writes_project_root(self, tmp_gout):
        (tmp_gout / ".graphify_root").write_text(".")

        np_mod.normalize_root(tmp_gout, PROJECT_ROOT, "rel2abs")

        assert (tmp_gout / ".graphify_root").read_text() == str(PROJECT_ROOT)

    def test_missing_root_no_error(self, tmp_gout):
        np_mod.normalize_root(tmp_gout, PROJECT_ROOT, "abs2rel")  # no exception


class TestNormalizeCacheFile:
    def test_abs2rel_source_file_in_nodes(self, tmp_gout):
        cache_data = {
            "nodes": [
                {"id": "foo", "source_file": str(PROJECT_ROOT / "lib/foo.py"), "label": "foo"},
            ],
            "edges": [],
        }
        cache_file = tmp_gout / "cache" / "ast" / "abc123.json"
        cache_file.write_text(json.dumps(cache_data))

        np_mod.normalize_cache_file(cache_file, PROJECT_ROOT, "abs2rel")

        result = json.loads(cache_file.read_text())
        assert result["nodes"][0]["source_file"] == "lib/foo.py"

    def test_abs2rel_source_file_in_edges(self, tmp_gout):
        cache_data = {
            "nodes": [],
            "edges": [
                {"source": "a", "target": "b",
                 "source_file": str(PROJECT_ROOT / "lib/foo.py"),
                 "source_location": "L1", "relation": "calls", "weight": 1.0},
            ],
        }
        cache_file = tmp_gout / "cache" / "ast" / "abc123.json"
        cache_file.write_text(json.dumps(cache_data))

        np_mod.normalize_cache_file(cache_file, PROJECT_ROOT, "abs2rel")

        result = json.loads(cache_file.read_text())
        assert result["edges"][0]["source_file"] == "lib/foo.py"

    def test_rel2abs_source_file(self, tmp_gout):
        cache_data = {
            "nodes": [{"id": "foo", "source_file": "lib/foo.py", "label": "foo"}],
            "edges": [],
        }
        cache_file = tmp_gout / "cache" / "ast" / "abc123.json"
        cache_file.write_text(json.dumps(cache_data))

        np_mod.normalize_cache_file(cache_file, PROJECT_ROOT, "rel2abs")

        result = json.loads(cache_file.read_text())
        assert result["nodes"][0]["source_file"] == str(PROJECT_ROOT / "lib/foo.py")


class TestHookFilter:
    def test_non_bash_tool_exits_zero(self, tmp_gout, monkeypatch):
        """Скрипт не трогает ничего если tool_name != Bash."""
        hook_input = json.dumps({"tool_name": "Read", "tool_input": {"file_path": "/foo"}})

        # Мокаем stdin
        monkeypatch.setattr("sys.stdin", __import__("io").StringIO(hook_input))
        monkeypatch.setattr("sys.argv", ["normalize-paths.py", "abs2rel"])

        with pytest.raises(SystemExit) as exc:
            np_mod.main()
        assert exc.value.code == 0

    def test_bash_without_graphify_exits_zero(self, tmp_gout, monkeypatch):
        hook_input = json.dumps({"tool_name": "Bash", "tool_input": {"command": "ls -la"}})

        monkeypatch.setattr("sys.stdin", __import__("io").StringIO(hook_input))
        monkeypatch.setattr("sys.argv", ["normalize-paths.py", "abs2rel"])

        with pytest.raises(SystemExit) as exc:
            np_mod.main()
        assert exc.value.code == 0

    def test_empty_stdin_direct_call_runs(self, tmp_gout, monkeypatch):
        """Прямой вызов (пустой stdin) — нормализация выполняется."""
        monkeypatch.setattr("sys.stdin", __import__("io").StringIO(""))
        monkeypatch.setattr("sys.argv", ["normalize-paths.py", "abs2rel"])
        monkeypatch.setenv("GRAPHIFY_OUT", tmp_gout.name)

        # Создаём manifest с abs путём
        manifest = {str(PROJECT_ROOT / "lib/foo.py"): {"mtime": 1.0, "hash": "abc"}}
        (tmp_gout / "manifest.json").write_text(json.dumps(manifest))

        # Мокаем get_project_root → tmp_gout.parent
        monkeypatch.setattr(np_mod, "get_project_root", lambda: PROJECT_ROOT)

        # Прямой вызов не должен падать
        # (реальная нормализация не произойдёт из-за PROJECT_ROOT != tmp_gout.parent,
        #  но функция должна завершиться без исключения)
        try:
            np_mod.main()
        except SystemExit as e:
            assert e.code in (0, None)
```

- [ ] **Step 2: Запустить тесты — убедиться что падают (файл не существует)**

```bash
python3 -m pytest tests/test_normalize_paths.py -v 2>&1 | head -20
```

Ожидание: `ModuleNotFoundError: No module named 'normalize_paths'`

- [ ] **Step 3: Commit тестов**

```bash
git add tests/test_normalize_paths.py
git commit -m "test(graphify): add normalize-paths hook unit tests"
```

---

### Task 2: Создать normalize-paths.py

**Files:**
- Create: `.nvm-isolated/.claude-isolated/hooks/normalize-paths.py`

- [ ] **Step 1: Создать скрипт**

```python
#!/usr/bin/env python3
"""
Pre/PostToolUse hook — нормализация путей в GRAPHIFY_OUT/ для портативности.

abs2rel: абсолютные пути → относительные  (PostToolUse, для git)
rel2abs: относительные пути → абсолютные  (PreToolUse, для graphifyy runtime)

Прямой вызов (stdin пустой/не JSON):
  python3 normalize-paths.py abs2rel < /dev/null
"""
import sys
import json
import os
import re
import subprocess
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor


def get_project_root(gout: Path) -> Path:
    # abs2rel: читаем сохранённый путь из .graphify_root (самый точный источник)
    root_file = gout / ".graphify_root"
    if root_file.exists():
        content = root_file.read_text(encoding="utf-8").strip()
        if content and content.startswith("/") and Path(content).exists():
            return Path(content)
    # rel2abs / fallback: git rev-parse или CWD
    try:
        root = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL, text=True
        ).strip()
        return Path(root)
    except Exception:
        return Path.cwd()


def normalize_manifest(gout: Path, project_root: Path, mode: str) -> None:
    manifest_path = gout / "manifest.json"
    if not manifest_path.exists():
        return
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception:
        return

    new_data: dict = {}
    changed = False

    for key, value in data.items():
        if mode == "abs2rel":
            if key.startswith("/"):
                try:
                    rel = os.path.relpath(key, project_root)
                    if rel.startswith("../"):
                        new_data[key] = value
                    else:
                        new_data[rel] = value
                        changed = True
                except ValueError:
                    new_data[key] = value
            else:
                new_data[key] = value
        else:  # rel2abs
            if key and not key.startswith("/"):
                new_data[str(project_root / key)] = value
                changed = True
            else:
                new_data[key] = value

    if changed:
        manifest_path.write_text(json.dumps(new_data, indent=2), encoding="utf-8")


def normalize_root(gout: Path, project_root: Path, mode: str) -> None:
    root_path = gout / ".graphify_root"
    if not root_path.exists():
        return
    content = root_path.read_text(encoding="utf-8").strip()
    if mode == "abs2rel":
        if content.startswith("/"):
            root_path.write_text(".", encoding="utf-8")
    else:  # rel2abs
        if not content.startswith("/"):
            root_path.write_text(str(project_root), encoding="utf-8")


def normalize_cache_file(cache_file: Path, project_root: Path, mode: str) -> None:
    try:
        data = json.loads(cache_file.read_text(encoding="utf-8"))
    except Exception:
        return

    changed = False

    for container in (data.get("nodes", []), data.get("edges", [])):
        for item in container:
            sf = item.get("source_file", "")
            if not sf:
                continue
            if mode == "abs2rel" and sf.startswith("/"):
                try:
                    rel = os.path.relpath(sf, project_root)
                    if not rel.startswith("../"):
                        item["source_file"] = rel
                        changed = True
                except ValueError:
                    pass
            elif mode == "rel2abs" and sf and not sf.startswith("/"):
                item["source_file"] = str(project_root / sf)
                changed = True

    if changed:
        cache_file.write_text(json.dumps(data), encoding="utf-8")


def normalize_cache(gout: Path, project_root: Path, mode: str) -> None:
    cache_dir = gout / "cache" / "ast"
    if not cache_dir.exists():
        return
    files = list(cache_dir.glob("*.json"))
    if not files:
        return
    with ThreadPoolExecutor() as ex:
        list(ex.map(lambda f: normalize_cache_file(f, project_root, mode), files))


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] not in ("abs2rel", "rel2abs"):
        sys.exit(0)

    mode = sys.argv[1]
    raw = sys.stdin.read()

    if raw.strip():
        try:
            data = json.loads(raw)
        except (json.JSONDecodeError, ValueError):
            sys.exit(0)
        if data.get("tool_name") != "Bash":
            sys.exit(0)
        command = data.get("tool_input", {}).get("command", "")
        if not re.search(r"\bgraphify\b", command):
            sys.exit(0)

    # Определяем gout через git/CWD (project_root нужен ещё до чтения .graphify_root)
    graphify_out = os.environ.get("GRAPHIFY_OUT", "graphify-out")
    try:
        git_root = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL, text=True
        ).strip()
        gout = Path(git_root) / graphify_out
    except Exception:
        gout = Path.cwd() / graphify_out

    if not gout.exists():
        sys.exit(0)

    # get_project_root читает .graphify_root для abs2rel (точнее git)
    project_root = get_project_root(gout)

    normalize_manifest(gout, project_root, mode)
    normalize_root(gout, project_root, mode)
    normalize_cache(gout, project_root, mode)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Сделать исполняемым**

```bash
chmod +x .nvm-isolated/.claude-isolated/hooks/normalize-paths.py
```

- [ ] **Step 3: Запустить тесты — убедиться что проходят**

```bash
python3 -m pytest tests/test_normalize_paths.py -v
```

Ожидание: все тесты PASS.

- [ ] **Step 4: Проверить прямой вызов вручную**

```bash
# Посмотреть первый ключ manifest.json до нормализации
python3 -c "import json; d=json.load(open('.graphify/manifest.json')); print(list(d.keys())[0])"

# Нормализовать
python3 .nvm-isolated/.claude-isolated/hooks/normalize-paths.py abs2rel < /dev/null

# Убедиться что ключ стал относительным
python3 -c "import json; d=json.load(open('.graphify/manifest.json')); print(list(d.keys())[0])"
```

Ожидание: первый вывод = абсолютный путь `/home/.../...`, второй = относительный `lib/...` или `tests/...`.

- [ ] **Step 5: Вернуть обратно**

```bash
python3 .nvm-isolated/.claude-isolated/hooks/normalize-paths.py rel2abs < /dev/null
python3 -c "import json; d=json.load(open('.graphify/manifest.json')); print(list(d.keys())[0])"
```

Ожидание: снова абсолютный путь.

- [ ] **Step 6: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/normalize-paths.py
git commit -m "feat(graphify): add normalize-paths hook for abs↔rel path portability"
```

---

### Task 3: Обновить settings.json — добавить hooks

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/settings.json`

- [ ] **Step 1: Добавить PreToolUse hook для rel2abs**

Текущий `settings.json` содержит:
```json
"PreToolUse": [
    { "matcher": "Read|Edit|Write|MultiEdit|Bash", "hooks": [{"type": "command", "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/block-secrets.py\""}] },
    { "matcher": "Write|Edit|MultiEdit|Bash", "hooks": [{"type": "command", "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/redact-secrets.py\""}] }
]
```

Добавить третий элемент в массив PreToolUse:
```json
{
    "matcher": "Bash",
    "hooks": [
        {
            "type": "command",
            "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/normalize-paths.py\" rel2abs"
        }
    ]
}
```

- [ ] **Step 2: Добавить секцию PostToolUse**

В `settings.json` нет секции `PostToolUse`. Добавить после `PreToolUse`:
```json
"PostToolUse": [
    {
        "matcher": "Bash",
        "hooks": [
            {
                "type": "command",
                "command": "python3 \"$CLAUDE_CONFIG_DIR/hooks/normalize-paths.py\" abs2rel"
            }
        ]
    }
]
```

- [ ] **Step 3: Проверить синтаксис JSON**

```bash
python3 -m json.tool .nvm-isolated/.claude-isolated/settings.json > /dev/null && echo "OK"
```

Ожидание: `OK`

- [ ] **Step 4: Проверить что hook срабатывает на graphify-команду**

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"graphify update ."}}' \
  | python3 .nvm-isolated/.claude-isolated/hooks/normalize-paths.py rel2abs
echo "exit: $?"
```

Ожидание: `exit: 0` (без ошибок; нормализация выполнена если .graphify/ существует)

- [ ] **Step 5: Проверить что hook не срабатывает на не-graphify команду**

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
  | python3 .nvm-isolated/.claude-isolated/hooks/normalize-paths.py abs2rel
echo "exit: $?"
```

Ожидание: `exit: 0` (no-op)

- [ ] **Step 6: Commit**

```bash
git add .nvm-isolated/.claude-isolated/settings.json
git commit -m "feat(hooks): add graphify normalize-paths Pre/PostToolUse hooks"
```

---

### Task 4: Обновить lib/graphify/install.sh

**Files:**
- Modify: `lib/graphify/install.sh:60-63`

- [ ] **Step 1: Добавить вызов normalize после graphify**

Текущий код (строки 60-63):
```bash
    UV_TOOL_DIR="$GRAPHIFY_TOOL_DIR" \
        env "${env_args[@]}" \
        "$uv_bin" tool run --from graphifyy graphify "${graphify_args[@]}"
}
```

Заменить на:
```bash
    UV_TOOL_DIR="$GRAPHIFY_TOOL_DIR" \
        env "${env_args[@]}" \
        "$uv_bin" tool run --from graphifyy graphify "${graphify_args[@]}"

    if [[ -n "$CLAUDE_CONFIG_DIR" && -f "$CLAUDE_CONFIG_DIR/hooks/normalize-paths.py" ]]; then
        python3 "$CLAUDE_CONFIG_DIR/hooks/normalize-paths.py" abs2rel < /dev/null
    fi
}
```

- [ ] **Step 2: Проверить синтаксис bash**

```bash
bash -n lib/graphify/install.sh && echo "OK"
```

Ожидание: `OK`

- [ ] **Step 3: Commit**

```bash
git add lib/graphify/install.sh
git commit -m "feat(graphify): call normalize-paths after graphify update in install.sh"
```

---

### Task 5: Интеграционная проверка портативности

- [ ] **Step 1: Запустить полный тест suite**

```bash
python3 -m pytest tests/test_normalize_paths.py -v
```

Ожидание: все тесты PASS.

- [ ] **Step 2: Симулировать "другой ПК" — проверить полный цикл**

```bash
# Нормализовать (как при commit на текущей машине)
python3 .nvm-isolated/.claude-isolated/hooks/normalize-paths.py abs2rel < /dev/null

# Убедиться что manifest содержит относительные пути
python3 -c "
import json
d = json.load(open('.graphify/manifest.json'))
keys = list(d.keys())[:3]
for k in keys:
    assert not k.startswith('/'), f'Абсолютный путь найден: {k}'
    print('OK:', k)
"

# Убедиться что .graphify_root стал '.'
cat .graphify/.graphify_root

# Убедиться что cache файл содержит относительные source_file
python3 -c "
import json, glob
files = glob.glob('.graphify/cache/ast/*.json')
if files:
    d = json.load(open(files[0]))
    for n in d.get('nodes', [])[:2]:
        sf = n.get('source_file','')
        assert not sf.startswith('/'), f'Абсолютный source_file: {sf}'
        print('OK:', sf)
"
```

Ожидание: все `OK`, `.graphify_root` = `.`

- [ ] **Step 3: Вернуть пути в abs (для текущей сессии)**

```bash
python3 .nvm-isolated/.claude-isolated/hooks/normalize-paths.py rel2abs < /dev/null
cat .graphify/.graphify_root
```

Ожидание: `.graphify_root` = абсолютный путь проекта.

- [ ] **Step 4: Commit текущего состояния .graphify/ в портативном формате**

```bash
# Нормализовать для git
python3 .nvm-isolated/.claude-isolated/hooks/normalize-paths.py abs2rel < /dev/null

git add .graphify/manifest.json .graphify/.graphify_root .graphify/cache/ast/
git commit -m "chore(graphify): normalize .graphify/ paths to relative for git portability"

# Вернуть abs для текущей работы
python3 .nvm-isolated/.claude-isolated/hooks/normalize-paths.py rel2abs < /dev/null
```
