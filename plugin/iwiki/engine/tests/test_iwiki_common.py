import contextlib
import hashlib
import io
import json as _json
import os
import sys

# iwiki_common lives in the plugin's hooks/ dir, not the engine package.
_HOOKS = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "hooks"))
sys.path.insert(0, _HOOKS)
import iwiki_common  # noqa: E402


def test_read_session_warns_on_corrupt_file(tmp_path, monkeypatch):
    state = tmp_path / "iwiki-session.json"
    state.write_text("{not valid json", encoding="utf-8")
    monkeypatch.setattr(iwiki_common, "session_path", lambda: str(state))
    err = io.StringIO()
    with contextlib.redirect_stderr(err):
        out = iwiki_common.read_session()
    # fail-soft preserved: defaults returned
    assert out["session_id"] == ""
    assert out["count"] == 0
    # no longer silent
    assert "iwiki" in err.getvalue().lower()


def test_read_session_silent_when_absent(tmp_path, monkeypatch):
    missing = tmp_path / "nope.json"
    monkeypatch.setattr(iwiki_common, "session_path", lambda: str(missing))
    err = io.StringIO()
    with contextlib.redirect_stderr(err):
        out = iwiki_common.read_session()
    assert out["session_id"] == ""
    assert err.getvalue() == ""   # absent state is normal — stay quiet


def _setup_wiki(tmp_path, monkeypatch):
    """A project tree with docs/wiki/.iwiki/log.jsonl; cwd set to it."""
    monkeypatch.chdir(tmp_path)
    log = tmp_path / "docs" / "wiki" / ".iwiki" / "log.jsonl"
    log.parent.mkdir(parents=True)
    return log


def _write_log(log, records):
    log.write_text(
        "".join(_json.dumps(r) + "\n" for r in records), encoding="utf-8")


def test_source_page_map_last_record_wins(tmp_path, monkeypatch):
    log = _setup_wiki(tmp_path, monkeypatch)
    _write_log(log, [
        {"op": "ingest", "source": "a.py", "page": "docs/wiki/old.md"},
        {"op": "ingest", "source": "a.py", "page": "docs/wiki/new.md"},
        {"source": "b.py", "page": "docs/wiki/b.md"},  # no "op" → still counts
        {"op": "ingest", "page": "docs/wiki/x.md"},     # no source → skipped
        {"op": "ingest", "source": "c.py"},             # no page → skipped
        "",                                             # JSON empty-string / non-dict record skipped
    ])
    assert iwiki_common.source_page_map() == {
        "a.py": "docs/wiki/new.md", "b.py": "docs/wiki/b.md"}


def test_source_page_map_missing_or_corrupt_log(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    assert iwiki_common.source_page_map() == {}          # no log at all
    log = _setup_wiki(tmp_path, monkeypatch)
    log.write_text("{not json\n", encoding="utf-8")
    assert iwiki_common.source_page_map() == {}           # corrupt → {}


def test_covered_sources_freshness(tmp_path, monkeypatch):
    log = _setup_wiki(tmp_path, monkeypatch)
    src = tmp_path / "a.py"
    page = tmp_path / "docs" / "wiki" / "a.md"
    src.write_text("x", encoding="utf-8")
    page.write_text("y", encoding="utf-8")
    _write_log(log, [{"op": "ingest", "source": "a.py", "page": "docs/wiki/a.md"}])

    # page newer than source → covered
    os.utime("a.py", (1000, 1000))
    os.utime("docs/wiki/a.md", (2000, 2000))
    assert iwiki_common.covered_sources() == {"a.py"}

    # source edited after ingest (source newer) → not covered (re-staled)
    os.utime("a.py", (3000, 3000))
    assert iwiki_common.covered_sources() == set()


def test_covered_sources_missing_page_on_disk(tmp_path, monkeypatch):
    log = _setup_wiki(tmp_path, monkeypatch)
    (tmp_path / "a.py").write_text("x", encoding="utf-8")
    # log references a page that does not exist on disk
    _write_log(log, [{"op": "ingest", "source": "a.py", "page": "docs/wiki/gone.md"}])
    assert iwiki_common.covered_sources() == set()


def _reset_ignore_cache(monkeypatch):
    """source_ignore() caches per process; clear it so each test re-reads."""
    monkeypatch.setattr(iwiki_common, "_ignore_spec",
                        iwiki_common._ignore_sentinel, raising=False)


def test_is_documentable_without_ignore_file(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    _reset_ignore_cache(monkeypatch)
    # No .iwikiignore → unchanged behaviour: a plain source is documentable.
    assert iwiki_common.is_documentable("lib/foo/bar.py") is True


def test_iwikiignore_suppresses_documentable_source(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    _reset_ignore_cache(monkeypatch)
    (tmp_path / ".iwikiignore").write_text(
        "experiments/\nbar.py\n", encoding="utf-8")
    # Directory subtree and basename-anywhere patterns drop the source.
    assert iwiki_common.is_documentable("experiments/x.py") is False
    assert iwiki_common.is_documentable("lib/foo/bar.py") is False
    # A path not matched by any pattern stays documentable.
    assert iwiki_common.is_documentable("lib/foo/keep.py") is True


def test_iwikiignore_comment_only_is_noop(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    _reset_ignore_cache(monkeypatch)
    (tmp_path / ".iwikiignore").write_text("# just a comment\n\n", encoding="utf-8")
    assert iwiki_common.source_ignore() is None
    assert iwiki_common.is_documentable("lib/foo/bar.py") is True


def test_covered_sources_hash_match_overrides_mtime(tmp_path, monkeypatch):
    # Cure case mirror of the engine test: page OLDER by mtime but hash matches
    # → still covered.
    log = _setup_wiki(tmp_path, monkeypatch)
    (tmp_path / "a.py").write_text("x", encoding="utf-8")
    (tmp_path / "docs" / "wiki" / "a.md").write_text("y", encoding="utf-8")
    h = hashlib.sha256(b"x").hexdigest()[:16]
    _write_log(log, [
        {"op": "ingest", "source": "a.py", "page": "docs/wiki/a.md", "src_hash": h}])
    os.utime("a.py", (3000, 3000))
    os.utime("docs/wiki/a.md", (1000, 1000))
    assert iwiki_common.covered_sources() == {"a.py"}


def test_covered_sources_hash_mismatch_not_covered(tmp_path, monkeypatch):
    # Page NEWER by mtime but hash differs → not covered.
    log = _setup_wiki(tmp_path, monkeypatch)
    (tmp_path / "a.py").write_text("x", encoding="utf-8")
    (tmp_path / "docs" / "wiki" / "a.md").write_text("y", encoding="utf-8")
    _write_log(log, [
        {"op": "ingest", "source": "a.py", "page": "docs/wiki/a.md",
         "src_hash": "0000000000000000"}])
    os.utime("a.py", (1000, 1000))
    os.utime("docs/wiki/a.md", (2000, 2000))
    assert iwiki_common.covered_sources() == set()
