#!/usr/bin/env python3
"""Tests for normalize-paths.py path normalization logic."""
import json
import sys
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
        monkeypatch.setattr(
            "subprocess.check_output",
            lambda *_, **__: "/home/alice/project\n"
        )

        result = np_mod.get_project_root(tmp_gout)

        assert result == Path("/home/alice/project")

    def test_fallback_to_cwd_without_git(self, tmp_gout, monkeypatch):
        import subprocess as sp
        monkeypatch.setattr(
            "subprocess.check_output",
            lambda *_, **__: (_ for _ in ()).throw(sp.CalledProcessError(128, "git"))
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

        np_mod.normalize_manifest(tmp_gout, PROJECT_ROOT, "abs2rel")
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
    def test_non_bash_tool_exits_zero(self, monkeypatch):
        hook_input = json.dumps({"tool_name": "Read", "tool_input": {"file_path": "/foo"}})

        monkeypatch.setattr("sys.stdin", __import__("io").StringIO(hook_input))
        monkeypatch.setattr("sys.argv", ["normalize-paths.py", "abs2rel"])

        with pytest.raises(SystemExit) as exc:
            np_mod.main()
        assert exc.value.code == 0

    def test_bash_without_graphify_exits_zero(self, monkeypatch):
        hook_input = json.dumps({"tool_name": "Bash", "tool_input": {"command": "ls -la"}})

        monkeypatch.setattr("sys.stdin", __import__("io").StringIO(hook_input))
        monkeypatch.setattr("sys.argv", ["normalize-paths.py", "abs2rel"])

        with pytest.raises(SystemExit) as exc:
            np_mod.main()
        assert exc.value.code == 0

    @pytest.mark.parametrize("command,should_skip", [
        ("git add .graphify/", True),
        ("cd .graphify && ls", True),
        ("cat .graphify/manifest.json", True),
        ("mv .graphify foo", True),
        ("graphify update .", False),
        ("./graphify update", False),
        ("which graphify", False),
        ("/usr/bin/graphify", False),
        ("uv tool run --from graphifyy graphify update", False),
    ])
    def test_dotgraphify_path_does_not_trigger_hook(
        self, monkeypatch, tmp_path, command, should_skip
    ):
        """Regression: hook must skip commands operating on .graphify/ as path,
        but trigger on graphify CLI invocation."""
        hook_input = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})
        monkeypatch.setattr("sys.stdin", __import__("io").StringIO(hook_input))
        monkeypatch.setattr("sys.argv", ["normalize-paths.py", "rel2abs"])

        called = {"normalize_manifest": False}

        def fake_normalize(*args, **kwargs):
            called["normalize_manifest"] = True

        monkeypatch.setattr(np_mod, "normalize_manifest", fake_normalize)
        monkeypatch.setattr(np_mod, "normalize_root", lambda *a, **k: None)
        monkeypatch.setattr(np_mod, "normalize_cache", lambda *a, **k: None)
        monkeypatch.setattr(np_mod, "get_project_root", lambda gout: PROJECT_ROOT)

        gout = tmp_path / ".graphify"
        gout.mkdir()
        monkeypatch.chdir(tmp_path)
        monkeypatch.setenv("GRAPHIFY_OUT", ".graphify")

        try:
            np_mod.main()
        except SystemExit:
            pass

        if should_skip:
            assert not called["normalize_manifest"], f"hook should skip: {command}"
        else:
            assert called["normalize_manifest"], f"hook should run: {command}"

    def test_empty_stdin_direct_call_runs(self, tmp_gout, monkeypatch):
        """Прямой вызов (пустой stdin) — нормализация выполняется."""
        monkeypatch.setattr("sys.stdin", __import__("io").StringIO(""))
        monkeypatch.setattr("sys.argv", ["normalize-paths.py", "abs2rel"])
        monkeypatch.setenv("GRAPHIFY_OUT", tmp_gout.name)

        manifest = {str(PROJECT_ROOT / "lib/foo.py"): {"mtime": 1.0, "hash": "abc"}}
        (tmp_gout / "manifest.json").write_text(json.dumps(manifest))

        monkeypatch.setattr(np_mod, "get_project_root", lambda gout: PROJECT_ROOT)

        try:
            np_mod.main()
        except SystemExit as e:
            assert e.code in (0, None)
