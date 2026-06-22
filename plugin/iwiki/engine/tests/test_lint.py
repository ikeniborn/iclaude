import json
import os
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
