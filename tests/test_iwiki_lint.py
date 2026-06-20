"""Unit tests for the config-free iwiki_engine.lint subcommand."""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..",
                                "plugin", "iwiki", "engine"))
from iwiki_engine.lint import lint  # noqa: E402


def test_missing_wiki_dir(tmp_path):
    # Directory does not exist at all → clean no-op, never an error.
    assert lint(str(tmp_path / "nope")) == {"wiki_present": False}


def test_empty_wiki_dir(tmp_path):
    # Dir exists but holds no *.md outside .iwiki/ → still a clean no-op.
    (tmp_path / ".iwiki").mkdir()
    (tmp_path / ".iwiki" / "index.jsonl").write_text("")
    assert lint(str(tmp_path)) == {"wiki_present": False}


def test_broken_link_and_orphan(tmp_path):
    # a links to b#Missing (bad heading) and b#Real (good). b links nowhere.
    (tmp_path / "a.md").write_text(
        "# A\n\n## Intro\n\n[[b#Missing]] and [[b#Real]]\n")
    (tmp_path / "b.md").write_text("# B\n\n## Real\n\nbody\n")
    res = lint(str(tmp_path))
    assert res["wiki_present"] is True
    assert res["pages"] == 2
    refs = {r["ref"] for r in res["broken"]}
    assert "b#Missing" in refs
    assert "b#Real" not in refs
    # b is referenced by a; a is referenced by no other page → orphan.
    assert res["orphans"] == [os.path.join(str(tmp_path), "a.md")]


def test_missing_target_file_is_broken(tmp_path):
    (tmp_path / "a.md").write_text("# A\n\n## S\n\n[[ghost#X]]\n")
    res = lint(str(tmp_path))
    assert {"page": os.path.join(str(tmp_path), "a.md"),
            "ref": "ghost#X"} in res["broken"]


def test_stale_when_source_newer_than_page(tmp_path):
    (tmp_path / "p.md").write_text("# P\n\n## S\n\nx\n")
    iwiki = tmp_path / ".iwiki"
    iwiki.mkdir()
    src = tmp_path / "src.sh"
    src.write_text("echo hi\n")
    rec = {"op": "ingest", "source": str(src), "page": str(tmp_path / "p.md"),
           "date": "2026-06-20"}
    (iwiki / "log.jsonl").write_text(json.dumps(rec) + "\n")
    os.utime(str(tmp_path / "p.md"), (1000, 1000))
    os.utime(str(src), (2000, 2000))
    res = lint(str(tmp_path))
    assert {"page": str(tmp_path / "p.md"), "source": str(src)} in res["stale"]
