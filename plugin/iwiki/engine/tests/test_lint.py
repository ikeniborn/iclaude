import json
import os
import hashlib
from iwiki_engine.lint import lint


def _wiki(tmp_path, pages: dict) -> str:
    wd = tmp_path / "wiki"
    wd.mkdir()
    for name, body in pages.items():
        (wd / name).write_text(body, encoding="utf-8")
    return str(wd)


def test_absent_wiki_is_noop(tmp_path):
    assert lint(str(tmp_path / "nope")) == {"wiki_present": False}


def test_detects_broken_ref(tmp_path):
    wd = _wiki(tmp_path, {"a.md": "## A\nlink to [[missing]] here\n"})
    out = lint(wd)
    assert any(b["ref"] == "missing" for b in out["broken"])


def test_code_fence_ref_not_broken(tmp_path):
    # page-level regression for P1: bash [[...]] in a fence is not a broken ref
    wd = _wiki(tmp_path, {
        "a.md": "## A\n```bash\nif [[ -d x ]]; then :; fi\n```\n[[b]]\n",
        "b.md": "## B\nbody\n",
    })
    assert lint(wd)["broken"] == []


def test_detects_orphan(tmp_path):
    wd = _wiki(tmp_path, {"a.md": "## A\nno links\n", "b.md": "## B\nno links\n"})
    out = lint(wd)
    assert set(out["orphans"]) == {
        os.path.normpath(os.path.join(wd, "a.md")),
        os.path.normpath(os.path.join(wd, "b.md")),
    }


def test_stale_ignores_legacy_and_malformed_log_records(tmp_path):
    wd = _wiki(tmp_path, {"a.md": "## A\nbody\n"})
    iwiki = os.path.join(wd, ".iwiki")
    os.makedirs(iwiki, exist_ok=True)
    with open(os.path.join(iwiki, "log.jsonl"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps({"op": "init", "scope": "x", "note": "legacy"}) + "\n")
        fh.write("not json at all\n")
    out = lint(wd)
    assert out["wiki_present"] is True
    assert out["stale"] == []   # records lacking source/page are tolerated, ignored


def test_section_findings_folded_into_report(tmp_path):
    # page with a ### deep heading and no ## Overview → both findings surface
    wd = _wiki(tmp_path, {"a.md": "## A\nlead.\n\n### deep\nx\n"})
    out = lint(wd)
    types = {f["type"] for f in out["sections"]}
    assert "deep_heading" in types
    assert "missing_overview" in types
    assert all("page" in f for f in out["sections"])


def _h(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def _wiki_with_log(tmp_path, page_body, src_body, src_hash=None):
    """Wiki dir with one page, one source file, and a single ingest log record
    (absolute paths). Returns (wiki_dir, src_path, page_path)."""
    wd = tmp_path / "wiki"
    wd.mkdir()
    page = wd / "a.md"
    page.write_text(page_body, encoding="utf-8")
    src = tmp_path / "a.py"
    src.write_text(src_body, encoding="utf-8")
    iwiki = wd / ".iwiki"
    iwiki.mkdir()
    rec = {"op": "ingest", "source": str(src), "page": str(page)}
    if src_hash is not None:
        rec["src_hash"] = src_hash
    (iwiki / "log.jsonl").write_text(json.dumps(rec) + "\n", encoding="utf-8")
    return str(wd), str(src), str(page)


def test_stale_hash_match_overrides_older_page_mtime(tmp_path):
    # The cure case: page mtime OLDER than source, but src_hash matches the
    # current source → NOT stale (kills git-reset / same-day false positives).
    wd, src, page = _wiki_with_log(
        tmp_path, "## A\nbody\n", "print('x')\n", src_hash=_h("print('x')\n"))
    os.utime(src, (2000, 2000))
    os.utime(page, (1000, 1000))
    assert lint(wd)["stale"] == []


def test_stale_hash_mismatch_is_stale_even_if_page_newer(tmp_path):
    # Hash recorded for OLD content; source now differs → stale regardless of mtime.
    wd, src, page = _wiki_with_log(
        tmp_path, "## A\nbody\n", "new content\n", src_hash=_h("old content\n"))
    os.utime(src, (1000, 1000))
    os.utime(page, (2000, 2000))
    assert any(s["source"] == src for s in lint(wd)["stale"])


def test_stale_without_hash_uses_mtime(tmp_path):
    # No src_hash in the record → unchanged mtime behaviour.
    wd, src, page = _wiki_with_log(tmp_path, "## A\nbody\n", "x\n")
    os.utime(src, (2000, 2000))
    os.utime(page, (1000, 1000))
    assert any(s["source"] == src for s in lint(wd)["stale"])
    os.utime(page, (3000, 3000))
    assert lint(wd)["stale"] == []


def test_stale_hash_present_but_unreadable_falls_back_to_mtime(tmp_path, monkeypatch):
    # src_hash present but source unreadable (_src_hash → None) → mtime path.
    import iwiki_engine.lint as lintmod
    wd, src, page = _wiki_with_log(
        tmp_path, "## A\nbody\n", "x\n", src_hash="deadbeefdeadbeef")
    monkeypatch.setattr(lintmod, "_src_hash", lambda p: None)
    os.utime(src, (2000, 2000))
    os.utime(page, (1000, 1000))
    assert any(s["source"] == src for s in lint(wd)["stale"])
