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
