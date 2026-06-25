"""Tests for .iwikiignore loading and gitignore-style matching."""
from iwiki_engine.config import _load_ignore


def test_absent_file_returns_none(monkeypatch, tmp_path):
    monkeypatch.chdir(tmp_path)
    assert _load_ignore(".iwikiignore") is None


def test_comment_and_blank_only_returns_none(monkeypatch, tmp_path):
    monkeypatch.chdir(tmp_path)
    (tmp_path / ".iwikiignore").write_text("# just a comment\n\n   \n")
    assert _load_ignore(".iwikiignore") is None


def test_basename_pattern_matches_at_any_depth(monkeypatch, tmp_path):
    monkeypatch.chdir(tmp_path)
    (tmp_path / ".iwikiignore").write_text("command.md\n")
    spec = _load_ignore(".iwikiignore")
    assert spec is not None
    assert spec.match_file("docs/wiki/command.md")
    assert spec.match_file("command.md")
    assert not spec.match_file("docs/wiki/iwiki.md")


def test_anchored_pattern_only_matches_root(monkeypatch, tmp_path):
    monkeypatch.chdir(tmp_path)
    (tmp_path / ".iwikiignore").write_text("/launcher.md\n")
    spec = _load_ignore(".iwikiignore")
    assert spec is not None
    assert spec.match_file("launcher.md")
    assert not spec.match_file("docs/wiki/launcher.md")


def test_negation_re_includes(monkeypatch, tmp_path):
    monkeypatch.chdir(tmp_path)
    (tmp_path / ".iwikiignore").write_text("docs/wiki/*.md\n!docs/wiki/keep.md\n")
    spec = _load_ignore(".iwikiignore")
    assert spec is not None
    assert spec.match_file("docs/wiki/drop.md")
    assert not spec.match_file("docs/wiki/keep.md")


def test_directory_pattern_matches_subtree(monkeypatch, tmp_path):
    monkeypatch.chdir(tmp_path)
    (tmp_path / ".iwikiignore").write_text("docs/wiki/archive/\n")
    spec = _load_ignore(".iwikiignore")
    assert spec is not None
    assert spec.match_file("docs/wiki/archive/old.md")
    assert not spec.match_file("docs/wiki/iwiki.md")
