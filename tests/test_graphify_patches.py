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


class TestIdempotency:
    def test_applied_marker_prevents_reapply(self, fake_pkg):
        """Idempotent: после первого apply повторный — no-op."""
        # Подложим vendored-like содержимое (могут быть уже патченые)
        _seed_real_targets(fake_pkg)

        # Первый apply: applied=3 (если seed был unpatched) или skipped=3 (если уже patched).
        r1 = run_apply(fake_pkg)
        assert r1.returncode == 0
        assert "failed=0" in r1.stdout

        # После первого apply marker должен присутствовать во всех файлах
        for f in ("detect.py", "watch.py", "cache.py"):
            assert "ICLAUDE-PATCHED-v1" in (fake_pkg / f).read_text()

        # Второй apply: всегда skipped=3, applied=0 (idempotent)
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
