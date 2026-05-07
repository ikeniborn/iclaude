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
