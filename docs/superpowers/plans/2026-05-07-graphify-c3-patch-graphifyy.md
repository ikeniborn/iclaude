# Graphify Portability v2: Patch graphifyy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Заменить hook-based normalize-paths инфраструктуру тремя малыми патчами в vendored graphifyy, удалив 2 Claude hooks и ~200 строк кода нормализации.

**Architecture:** Три unified-diff патча применяются после `uv tool install graphifyy` через `apply_patches.sh` (idempotent через marker comment). Patches заставляют graphifyy писать relative paths в `manifest.json`, `.graphify_root`, `cache/ast/*.json`. Удаляем PreToolUse/PostToolUse Bash hooks и `normalize-paths.py`.

**Tech Stack:** bash, GNU patch(1), Python 3.12, pytest.

**Spec:** [docs/superpowers/specs/2026-05-07-graphify-c3-patch-graphifyy-design.md](../specs/2026-05-07-graphify-c3-patch-graphifyy-design.md)

---

## File Map

```
Создать:
  lib/graphify/patches/01-detect-relativize-manifest.patch       ← unified diff
  lib/graphify/patches/02-watch-relativize-graphify-root.patch   ← unified diff
  lib/graphify/patches/03-cache-relativize-source-file.patch     ← unified diff
  lib/graphify/apply_patches.sh                                  ← idempotent applier
  lib/graphify/UPSTREAM_ISSUE.md                                 ← upstream tracker
  tests/test_graphify_patches.py                                 ← pytest suite

Изменить:
  lib/graphify/install.sh                          ← вызвать apply_patches.sh; удалить normalize call
  .nvm-isolated/.claude-isolated/settings.json     ← удалить rel2abs/abs2rel hooks

Удалить:
  .nvm-isolated/.claude-isolated/hooks/normalize-paths.py
  tests/test_normalize_paths.py
```

**Out of scope:** Существующая `_patch_graphify_watch` функция в `install.sh` (sed-based фикс manifest_path argument для отдельного upstream-бага) НЕ затрагивается.

---

### Task 1: Создать patch файлы

**Files:**
- Create: `lib/graphify/patches/01-detect-relativize-manifest.patch`
- Create: `lib/graphify/patches/02-watch-relativize-graphify-root.patch`
- Create: `lib/graphify/patches/03-cache-relativize-source-file.patch`

- [ ] **Step 1: Создать каталог**

```bash
mkdir -p lib/graphify/patches
```

- [ ] **Step 2: Создать `01-detect-relativize-manifest.patch`**

```patch
--- a/detect.py
+++ b/detect.py
@@ -760,11 +760,19 @@ def save_manifest(files: dict[str, list[str]], manifest_path: str = _MANIFEST_PATH) -> None:
 def save_manifest(files: dict[str, list[str]], manifest_path: str = _MANIFEST_PATH) -> None:
     """Save current file mtimes + content hashes for change detection on --update."""
     manifest: dict[str, dict] = {}
+    # ICLAUDE-PATCHED-v1: relativize keys vs CWD for git portability
+    import os as _os
+    _cwd = Path.cwd().resolve()
     for file_list in files.values():
         for f in file_list:
             try:
                 p = Path(f)
-                manifest[f] = {"mtime": p.stat().st_mtime, "hash": _md5_file(p)}
+                key = f
+                if p.is_absolute():
+                    rel = _os.path.relpath(f, _cwd)
+                    if not rel.startswith(".."):
+                        key = rel
+                manifest[key] = {"mtime": p.stat().st_mtime, "hash": _md5_file(p)}
             except OSError:
                 pass  # file deleted between detect() and manifest write - skip it
     Path(manifest_path).parent.mkdir(parents=True, exist_ok=True)
```

- [ ] **Step 3: Создать `02-watch-relativize-graphify-root.patch`**

```patch
--- a/watch.py
+++ b/watch.py
@@ -130,7 +130,8 @@
         questions = suggest_questions(G, communities, labels)
 
         out.mkdir(exist_ok=True)
-        (out / ".graphify_root").write_text(str(watch_root), encoding="utf-8")
+        # ICLAUDE-PATCHED-v1: preserve user-provided path (relative if `.`)
+        (out / ".graphify_root").write_text(str(watch_path), encoding="utf-8")
 
         json_written = to_json(G, communities, str(out / "graph.json"), force=force, built_at_commit=commit)
         if not json_written:
```

- [ ] **Step 4: Создать `03-cache-relativize-source-file.patch`**

```patch
--- a/cache.py
+++ b/cache.py
@@ -118,5 +118,17 @@ def save_cached(path: Path, result: dict, root: Path = Path("."), kind: str = "ast") -> None:
     p = Path(path)
     if not p.is_file():
         return
+    # ICLAUDE-PATCHED-v1: relativize source_file vs root for git portability
+    _root_abs = Path(root).resolve()
+    for _bucket in ("nodes", "edges"):
+        for _item in result.get(_bucket, []):
+            _sf = _item.get("source_file", "")
+            if _sf and Path(_sf).is_absolute():
+                try:
+                    _rel = os.path.relpath(_sf, _root_abs)
+                    if not _rel.startswith(".."):
+                        _item["source_file"] = _rel
+                except ValueError:
+                    pass
     h = file_hash(p, root)
     target_dir = cache_dir(root, kind)
```

- [ ] **Step 5: Validate patch syntax (dry-run против vendored)**

```bash
GRAPHIFY_PKG="$ISOLATED_NVM_DIR/.claude-isolated/graphify/graphifyy/lib/python3.12/site-packages/graphify"
for p in lib/graphify/patches/*.patch; do
    echo "=== $p ==="
    patch -p1 --dry-run -d "$GRAPHIFY_PKG" < "$p"
done
```

Expected: `patching file <name>` для каждого, exit 0. Если падает — line numbers в diff не совпадают с фактическими; пересчитать.

- [ ] **Step 6: Commit**

```bash
git add lib/graphify/patches/
git commit -m "feat(graphify): add unified-diff patches for relative paths in graphifyy"
```

---

### Task 2: Test для apply_patches.sh idempotency

**Files:**
- Create: `tests/test_graphify_patches.py`

- [ ] **Step 1: Создать тестовый файл (skeleton)**

```python
#!/usr/bin/env python3
"""Tests for lib/graphify/apply_patches.sh — idempotent patch applier."""
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
import pytest

REPO_ROOT = Path(__file__).parent.parent
APPLY_SH = REPO_ROOT / "lib" / "graphify" / "apply_patches.sh"
PATCHES_DIR = REPO_ROOT / "lib" / "graphify" / "patches"


@pytest.fixture
def fake_pkg(tmp_path):
    """Создаёт минимальный faux graphify пакет для патчинга."""
    pkg = tmp_path / "graphify"
    pkg.mkdir()
    # Skeleton — тесты конкретных патчей перепишут содержимое
    (pkg / "detect.py").write_text("# detect\n")
    (pkg / "watch.py").write_text("# watch\n")
    (pkg / "cache.py").write_text("# cache\n")
    return pkg


def run_apply(pkg_dir: Path, env_override=None):
    env = os.environ.copy()
    env["GRAPHIFY_PKG_OVERRIDE"] = str(pkg_dir)
    if env_override:
        env.update(env_override)
    return subprocess.run(
        ["bash", str(APPLY_SH)],
        env=env, capture_output=True, text=True
    )


class TestApplyPatchesBasic:
    def test_script_exists_and_executable(self):
        assert APPLY_SH.exists()
        assert os.access(APPLY_SH, os.X_OK)

    def test_skips_when_pkg_missing(self, tmp_path):
        result = run_apply(tmp_path / "nonexistent")
        assert result.returncode == 0  # best-effort: missing pkg → skip
        assert "not installed" in (result.stdout + result.stderr).lower() or result.returncode == 0
```

- [ ] **Step 2: Запустить — убедиться что падает на отсутствии apply_patches.sh**

```bash
python3 -m pytest tests/test_graphify_patches.py::TestApplyPatchesBasic::test_script_exists_and_executable -v
```

Expected: FAIL — `lib/graphify/apply_patches.sh` does not exist.

- [ ] **Step 3: Commit failing test**

```bash
git add tests/test_graphify_patches.py
git commit -m "test(graphify): add failing test for apply_patches.sh existence"
```

---

### Task 3: Реализовать apply_patches.sh (basic)

**Files:**
- Create: `lib/graphify/apply_patches.sh`

- [ ] **Step 1: Написать скрипт**

```bash
#!/usr/bin/env bash
# Apply iclaude portability patches to vendored graphifyy.
# Idempotent — skips files already patched (marker comment ICLAUDE-PATCHED-v1).
# Best-effort — degrades gracefully if patch fails (warns, continues).

set -uo pipefail

MARKER="ICLAUDE-PATCHED-v1"

# Resolve graphify package dir (override via env for tests)
if [[ -n "${GRAPHIFY_PKG_OVERRIDE:-}" ]]; then
    GRAPHIFY_PKG="$GRAPHIFY_PKG_OVERRIDE"
else
    GRAPHIFY_PKG="${ISOLATED_NVM_DIR:-}/.claude-isolated/graphify/graphifyy/lib/python3.12/site-packages/graphify"
fi

PATCHES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/patches"

if [[ ! -d "$GRAPHIFY_PKG" ]]; then
    echo "apply_patches: graphifyy not installed at $GRAPHIFY_PKG (skip)" >&2
    exit 0
fi

if [[ ! -d "$PATCHES_DIR" ]]; then
    echo "apply_patches: patches dir not found: $PATCHES_DIR (skip)" >&2
    exit 0
fi

applied=0
skipped=0
failed=0

for patch_file in "$PATCHES_DIR"/*.patch; do
    [[ -f "$patch_file" ]] || continue

    target_file=$(grep -m1 '^+++ b/' "$patch_file" | sed 's|^+++ b/||')
    if [[ -z "$target_file" ]]; then
        echo "apply_patches: cannot parse target from $(basename "$patch_file")" >&2
        ((failed++))
        continue
    fi

    target_path="$GRAPHIFY_PKG/$target_file"
    if [[ ! -f "$target_path" ]]; then
        echo "apply_patches: target missing: $target_path (skip)" >&2
        ((skipped++))
        continue
    fi

    if grep -q "$MARKER" "$target_path" 2>/dev/null; then
        ((skipped++))
        continue
    fi

    if ! patch -p1 --dry-run -d "$GRAPHIFY_PKG" < "$patch_file" >/dev/null 2>&1; then
        echo "apply_patches: dry-run failed for $(basename "$patch_file") (graphifyy upstream may have changed)" >&2
        ((failed++))
        continue
    fi

    if patch -p1 -d "$GRAPHIFY_PKG" < "$patch_file" >/dev/null 2>&1; then
        echo "apply_patches: applied $(basename "$patch_file")"
        ((applied++))
    else
        echo "apply_patches: failed to apply $(basename "$patch_file")" >&2
        ((failed++))
    fi
done

echo "apply_patches: applied=$applied skipped=$skipped failed=$failed"
exit 0
```

- [ ] **Step 2: chmod +x**

```bash
chmod +x lib/graphify/apply_patches.sh
```

- [ ] **Step 3: Запустить test — должен пройти**

```bash
python3 -m pytest tests/test_graphify_patches.py::TestApplyPatchesBasic -v
```

Expected: PASS все тесты класса.

- [ ] **Step 4: Commit**

```bash
git add lib/graphify/apply_patches.sh
git commit -m "feat(graphify): add idempotent apply_patches.sh"
```

---

### Task 4: Tests для idempotency и dry-run-fail

**Files:**
- Modify: `tests/test_graphify_patches.py`

- [ ] **Step 1: Добавить класс TestIdempotency**

В конец `tests/test_graphify_patches.py`:

```python
class TestIdempotency:
    def test_applied_marker_prevents_reapply(self, fake_pkg):
        """Если marker в файле — patch не применяется повторно."""
        # Подложим vendored-like содержимое, совпадающее с патчами
        _seed_real_targets(fake_pkg)

        # Первый apply: применяется
        r1 = run_apply(fake_pkg)
        assert r1.returncode == 0
        assert "applied=3" in r1.stdout

        # Marker должен присутствовать
        for f in ("detect.py", "watch.py", "cache.py"):
            assert "ICLAUDE-PATCHED-v1" in (fake_pkg / f).read_text()

        # Второй apply: skip (idempotent)
        r2 = run_apply(fake_pkg)
        assert r2.returncode == 0
        assert "skipped=3" in r2.stdout
        assert "applied=0" in r2.stdout

    def test_dry_run_fail_does_not_block(self, fake_pkg):
        """Если dry-run patch fails — best-effort exit 0, fails counted."""
        # Подложим target файл с НЕсовпадающим содержимым
        (fake_pkg / "detect.py").write_text("# completely different content\n")
        (fake_pkg / "watch.py").write_text("# different\n")
        (fake_pkg / "cache.py").write_text("# different\n")

        result = run_apply(fake_pkg)
        assert result.returncode == 0
        assert "failed=3" in result.stdout


def _seed_real_targets(pkg: Path):
    """Скопировать реальные vendored файлы в fake_pkg для valid patch context."""
    real_pkg_env = os.environ.get("ISOLATED_NVM_DIR", "")
    if not real_pkg_env:
        pytest.skip("ISOLATED_NVM_DIR not set — cannot source real graphifyy")
    real_pkg = Path(real_pkg_env) / ".claude-isolated/graphify/graphifyy/lib/python3.12/site-packages/graphify"
    if not real_pkg.exists():
        pytest.skip(f"vendored graphifyy not found at {real_pkg}")
    for f in ("detect.py", "watch.py", "cache.py"):
        shutil.copy(real_pkg / f, pkg / f)
```

- [ ] **Step 2: Запустить — убедиться что проходит**

```bash
python3 -m pytest tests/test_graphify_patches.py::TestIdempotency -v
```

Expected: PASS обоих тестов. Если `ISOLATED_NVM_DIR` не задана → SKIPPED (acceptable).

- [ ] **Step 3: Commit**

```bash
git add tests/test_graphify_patches.py
git commit -m "test(graphify): cover apply_patches idempotency and dry-run-fail handling"
```

---

### Task 5: Integration test — graphify produces relative paths after patches

**Files:**
- Modify: `tests/test_graphify_patches.py`

- [ ] **Step 1: Добавить класс TestPortability**

```python
class TestPortabilityE2E:
    """End-to-end: после apply_patches graphify update пишет relative paths."""

    @pytest.fixture
    def graphify_bin(self):
        bin_path = Path(os.environ.get("ISOLATED_NVM_DIR", "")) / "bin" / "graphify"
        if not bin_path.exists():
            pytest.skip(f"graphify not at {bin_path} — run --install-graphify")
        return str(bin_path)

    def _verify_patches_applied(self):
        """Проверяет что vendored graphifyy уже патчен (precondition)."""
        pkg = Path(os.environ.get("ISOLATED_NVM_DIR", "")) / ".claude-isolated/graphify/graphifyy/lib/python3.12/site-packages/graphify"
        for f in ("detect.py", "watch.py", "cache.py"):
            content = (pkg / f).read_text()
            if "ICLAUDE-PATCHED-v1" not in content:
                pytest.skip(f"{f} not patched — run lib/graphify/apply_patches.sh first")

    def test_manifest_keys_relative(self, tmp_path, graphify_bin):
        self._verify_patches_applied()
        # Минимальный git repo
        subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
        (tmp_path / "foo.py").write_text("def hello(): pass\n")

        result = subprocess.run(
            [graphify_bin, "update", "."],
            cwd=tmp_path, capture_output=True, text=True,
            env={**os.environ, "GRAPHIFY_OUT": "graphify-out"}
        )
        assert result.returncode == 0, f"graphify failed: {result.stderr}"

        manifest_path = tmp_path / "graphify-out" / "manifest.json"
        assert manifest_path.exists()

        import json
        manifest = json.loads(manifest_path.read_text())
        assert manifest, "manifest should not be empty"
        for key in manifest:
            assert not key.startswith("/"), f"absolute key found: {key}"

    def test_graphify_root_is_dot(self, tmp_path, graphify_bin):
        self._verify_patches_applied()
        subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
        (tmp_path / "foo.py").write_text("def hello(): pass\n")

        subprocess.run(
            [graphify_bin, "update", "."],
            cwd=tmp_path, capture_output=True, text=True,
            env={**os.environ, "GRAPHIFY_OUT": "graphify-out"}, check=True
        )

        root_file = tmp_path / "graphify-out" / ".graphify_root"
        assert root_file.exists()
        assert root_file.read_text().strip() == "."

    def test_cache_source_file_relative(self, tmp_path, graphify_bin):
        self._verify_patches_applied()
        subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
        # Несколько файлов чтобы cache точно сгенерировался
        for i in range(3):
            (tmp_path / f"mod{i}.py").write_text(f"def func{i}(): pass\n")

        subprocess.run(
            [graphify_bin, "update", "."],
            cwd=tmp_path, capture_output=True, text=True,
            env={**os.environ, "GRAPHIFY_OUT": "graphify-out"}, check=True
        )

        import json
        cache_files = list((tmp_path / "graphify-out" / "cache" / "ast").glob("*.json"))
        if not cache_files:
            pytest.skip("no cache files generated — graphify may have inlined")

        for cf in cache_files:
            data = json.loads(cf.read_text())
            for bucket in ("nodes", "edges"):
                for item in data.get(bucket, []):
                    sf = item.get("source_file", "")
                    if sf:
                        assert not sf.startswith("/"), f"absolute source_file in {cf.name}: {sf}"
```

- [ ] **Step 2: Apply patches вручную перед запуском**

```bash
ISOLATED_NVM_DIR="$PWD/.nvm-isolated" bash lib/graphify/apply_patches.sh
```

Expected: `applied=3`.

- [ ] **Step 3: Запустить integration tests**

```bash
ISOLATED_NVM_DIR="$PWD/.nvm-isolated" python3 -m pytest tests/test_graphify_patches.py::TestPortabilityE2E -v
```

Expected: PASS все 3 теста (или SKIP если graphify не установлен).

- [ ] **Step 4: Commit**

```bash
git add tests/test_graphify_patches.py
git commit -m "test(graphify): add E2E portability tests (manifest/root/cache)"
```

---

### Task 6: Wire apply_patches.sh в install.sh

**Files:**
- Modify: `lib/graphify/install.sh`

- [ ] **Step 1: Добавить вызов apply_patches.sh после `_patch_graphify_watch` (line 184 install_graphify)**

Использовать Edit tool с уникальным контекстом (sed-вставка хрупка из-за нескольких вызовов `_patch_graphify_watch`). Прочитать `lib/graphify/install.sh` вокруг line 184, найти точное место в `install_graphify()`, заменить:

```bash
    _patch_graphify_watch
```

на:

```bash
    _patch_graphify_watch

    # Apply iclaude portability patches (relative paths in manifest/root/cache)
    if [[ -f "$LIB_DIR/graphify/apply_patches.sh" ]]; then
        bash "$LIB_DIR/graphify/apply_patches.sh"
    fi
```

Если `_patch_graphify_watch` встречается несколько раз — расширить контекст Edit (включить 3-5 строк до/после) для уникальности.

- [ ] **Step 2: Удалить normalize-paths вызов в `_graphify_rebuild_graph` (lines 92-94)**

Прочитать `lib/graphify/install.sh` вокруг lines 88-96 для уникального контекста (несколько `}` в файле). Edit с захватом окружающих строк функции `_graphify_rebuild_graph`:

old:
```bash
    if [[ -n "$CLAUDE_CONFIG_DIR" && -f "$CLAUDE_CONFIG_DIR/hooks/normalize-paths.py" ]]; then
        python3 "$CLAUDE_CONFIG_DIR/hooks/normalize-paths.py" abs2rel < /dev/null
    fi
}
```

new:
```bash
}
```

При неуникальности `}` — добавить предшествующую строку (например `print_success ...`) в old/new для якоря.

- [ ] **Step 3: Validate bash syntax**

```bash
bash -n lib/graphify/install.sh && echo "OK"
```

Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add lib/graphify/install.sh
git commit -m "refactor(graphify): wire apply_patches.sh; drop normalize-paths.py call"
```

---

### Task 7: Удалить hooks из settings.json

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/settings.json`

- [ ] **Step 1: Удалить третий PreToolUse элемент (rel2abs)**

Удалить из `.nvm-isolated/.claude-isolated/settings.json` блок строк 128–136:

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

(Не забыть запятую после предшествующего объекта redact-secrets.)

- [ ] **Step 2: Удалить весь PostToolUse блок (lines 138-148)**

Удалить:

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
    ],
```

- [ ] **Step 3: Validate JSON**

```bash
python3 -m json.tool .nvm-isolated/.claude-isolated/settings.json > /dev/null && echo "OK"
```

Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/settings.json
git commit -m "refactor(hooks): remove normalize-paths Pre/PostToolUse hooks"
```

---

### Task 8: Удалить normalize-paths.py + test_normalize_paths.py

**Files:**
- Delete: `.nvm-isolated/.claude-isolated/hooks/normalize-paths.py`
- Delete: `tests/test_normalize_paths.py`

- [ ] **Step 1: Удалить файлы**

```bash
git rm .nvm-isolated/.claude-isolated/hooks/normalize-paths.py
git rm tests/test_normalize_paths.py
```

- [ ] **Step 2: Удалить также `.nvm-isolated/.claude-isolated/hooks/normalize_paths.py` если существует**

```bash
[[ -f .nvm-isolated/.claude-isolated/hooks/normalize_paths.py ]] && \
    git rm .nvm-isolated/.claude-isolated/hooks/normalize_paths.py
```

- [ ] **Step 3: Запустить полный pytest — убедиться нет ссылок на удалённые файлы**

```bash
python3 -m pytest tests/ -v 2>&1 | tail -20
```

Expected: PASS / SKIP всех тестов. Никаких `ModuleNotFoundError: No module named 'normalize_paths'`.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(graphify): remove normalize-paths.py hook and tests"
```

---

### Task 9: Migration — rebuild .graphify/ с patches

**Files:**
- Modify: `.graphify/manifest.json`, `.graphify/.graphify_root`, `.graphify/cache/ast/*.json`

- [ ] **Step 1: Apply patches к vendored**

```bash
ISOLATED_NVM_DIR="$PWD/.nvm-isolated" bash lib/graphify/apply_patches.sh
```

Expected: `applied=3` (или `skipped=3` если уже применены ранее).

- [ ] **Step 2: Удалить старый cache + manifest + root**

```bash
rm -rf .graphify/cache .graphify/manifest.json .graphify/.graphify_root
```

- [ ] **Step 3: Rebuild через ./iclaude.sh --graphify**

```bash
./iclaude.sh --graphify 2>&1 | tail -10
```

Expected: `Rebuilt: NNNN nodes, NNNN edges`. `.graphify/` пересоздан.

- [ ] **Step 4: Verify portability**

```bash
python3 -c "
import json
m = json.load(open('.graphify/manifest.json'))
abs_keys = [k for k in m if k.startswith('/')]
assert not abs_keys, f'absolute keys: {abs_keys[:3]}'
print(f'manifest: {len(m)} keys, all relative')
"

test "$(cat .graphify/.graphify_root)" = "." && echo ".graphify_root = . OK"

python3 -c "
import json, glob
files = glob.glob('.graphify/cache/ast/*.json')
print(f'cache: {len(files)} files')
abs_count = 0
for f in files:
    d = json.load(open(f))
    for bucket in ('nodes', 'edges'):
        for item in d.get(bucket, []):
            sf = item.get('source_file', '')
            if sf and sf.startswith('/'):
                abs_count += 1
assert abs_count == 0, f'{abs_count} absolute source_file entries'
print('cache: all source_file relative')
"
```

Expected: 3 `OK` строки.

- [ ] **Step 5: Commit обновлённого .graphify/**

```bash
git add .graphify/manifest.json .graphify/.graphify_root .graphify/cache
git commit -m "chore(graphify): rebuild .graphify with relative paths via patched graphifyy"
```

---

### Task 10: Создать UPSTREAM_ISSUE.md

**Files:**
- Create: `lib/graphify/UPSTREAM_ISSUE.md`

- [ ] **Step 1: Написать tracker файл**

```markdown
# Upstream Issue / PR Tracker

**Repository:** https://github.com/safishamsi/graphify

## Status

- [ ] Issue submitted
- [ ] Issue triaged by maintainer
- [ ] PR submitted
- [ ] PR merged
- [ ] Released in graphifyy>=X.Y.Z
- [ ] Local patches removed (cleanup cycle)

## Issue draft

**Title:** Absolute paths in manifest.json, .graphify_root, and cache/ast/*.json break git-based portability

**Body:**

> ## Problem
>
> When `.graphify/` (or custom `GRAPHIFY_OUT/`) is committed to git for
> incremental cache sharing across machines/CI, three artifacts contain
> absolute paths and break on clone to a different filesystem location:
>
> 1. `manifest.json` — keys are absolute (`/home/alice/proj/foo.py`)
>    → `detect_incremental` cache miss → full rebuild
> 2. `.graphify_root` — absolute project path
>    → `graphify update` (no args) fails on a different machine
> 3. `cache/ast/*.json` — `source_file` field is absolute
>    → not directly fatal but pollutes diffs and leaks user paths
>
> `graph.json` is already correctly relativized via
> `watch._relativize_source_files`, demonstrating the intent.
>
> ## Reproduce
>
> ```bash
> mkdir /tmp/p && cd /tmp/p && git init -q && echo "def f(): pass" > a.py
> graphify update .
> head -3 graphify-out/manifest.json
> # keys: "/tmp/p/a.py" — absolute
> cat graphify-out/.graphify_root
> # /tmp/p — absolute
> ```
>
> ## Proposed fix
>
> Three small changes mirroring existing `_relativize_source_files`:
>
> 1. `detect.save_manifest` — relativize absolute keys against CWD
>    (skip paths outside via `os.path.relpath` ".." check)
> 2. `watch._rebuild_code` — write `str(watch_path)` instead of
>    `str(watch_root)` so user-provided `.` is preserved
> 3. `cache.save_cached` — walk `result["nodes"]` + `result["edges"]`,
>    relativize `source_file` against `root` before serialization
>
> All three are backwards compatible.
>
> ## Workaround
>
> Vendored patches: see iclaude project `lib/graphify/patches/`.
>
> Happy to submit a PR after triage.

## PR (after triage)

- Fork: `<set after fork>`
- Branch: `fix/portable-paths`
- Commits: one per patch point (atomic for review)
- Tests added in upstream test suite:
  - `test_save_manifest_relativizes_keys`
  - `test_save_cached_relativizes_source_file`
  - `test_graphify_root_preserves_relative`
- PR link: `<set after submit>`

## Cleanup cycle (after merge + release)

1. Pin `graphifyy>=X.Y.Z` in lockfile
2. Remove `lib/graphify/patches/` + `apply_patches.sh`
3. Remove `tests/test_graphify_patches.py`
4. Remove apply_patches call from `lib/graphify/install.sh`
5. Update [docs/superpowers/specs/2026-05-07-graphify-c3-patch-graphifyy-design.md](../../docs/superpowers/specs/2026-05-07-graphify-c3-patch-graphifyy-design.md) status
```

- [ ] **Step 2: Submit issue**

Открыть в браузере и заполнить вручную из `UPSTREAM_ISSUE.md`:

```bash
gh issue create --repo safishamsi/graphify --web
```

(sed-extraction из markdown с `**bold**` ненадёжна — конфликт со звёздочками. Лучше копипаст из tracker файла.)

- [ ] **Step 3: Update tracker с issue link**

После submit отметить чекбокс `Issue submitted` и добавить URL.

- [ ] **Step 4: Commit**

```bash
git add lib/graphify/UPSTREAM_ISSUE.md
git commit -m "docs(graphify): add upstream issue tracker for portability fix"
```

---

### Task 11: Final verification

- [ ] **Step 1: Полный pytest**

```bash
python3 -m pytest tests/ -v 2>&1 | tail -30
```

Expected: PASS всех (no `test_normalize_paths` references; новые `test_graphify_patches` PASS или SKIP).

- [ ] **Step 2: bash syntax check**

```bash
bash -n iclaude.sh && bash -n lib/graphify/install.sh && bash -n lib/graphify/apply_patches.sh && echo "ALL OK"
```

Expected: `ALL OK`.

- [ ] **Step 3: Симулировать "другой ПК" — проверить incremental cache hit**

```bash
# Нормализация уже сделана patches. Симулируем clone в другую директорию.
DEST=$(mktemp -d)
git clone . "$DEST" 2>&1 | tail -2
cd "$DEST"

# Apply patches на новой "машине"
ISOLATED_NVM_DIR="$OLDPWD/.nvm-isolated" bash lib/graphify/apply_patches.sh

# Запустить graphify update — должен использовать incremental cache (no full rebuild)
ISOLATED_NVM_DIR="$OLDPWD/.nvm-isolated" \
    "$OLDPWD/.nvm-isolated/bin/graphify" update . 2>&1 | tee /tmp/upd.log

# Проверка: лог содержит "Rebuilt: N nodes" — но N маленькое если cache hit
grep -E "Rebuilt|cache" /tmp/upd.log

cd "$OLDPWD"
rm -rf "$DEST"
```

Expected: graphify завершается без ошибок; cache используется (не падает на missing files).

- [ ] **Step 4: --check-graphify status**

```bash
./iclaude.sh --check-graphify 2>&1 | tail -10
```

Expected: статус OK, никаких ссылок на normalize-paths.

- [ ] **Step 5: Suite metrics — измерить exposed reduction**

```bash
echo "=== Diff stats vs main ==="
git diff --stat origin/master HEAD -- lib/graphify .nvm-isolated/.claude-isolated/hooks .nvm-isolated/.claude-isolated/settings.json tests
echo "=== Net delta ==="
git diff --shortstat origin/master HEAD
```

Документировать в commit message финального merge: net −X строк.

- [ ] **Step 6: Final commit (если мелкие правки нужны)**

```bash
git add -A && git commit -m "chore(graphify): finalize C3 portability migration" || echo "Nothing to commit"
```
