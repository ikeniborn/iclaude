"""Unit tests for the pure helpers in the iwiki Stop/Sync hooks.

iwiki_common is stdlib-only (no httpx), so it imports cleanly via a sys.path
insert of the plugin hooks dir — no engine venv needed.
"""
import importlib.util
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..",
                                "plugin", "iwiki", "hooks"))
import iwiki_common as iw  # noqa: E402

_SYNC_PATH = os.path.join(os.path.dirname(__file__), "..",
                          "plugin", "iwiki", "hooks", "iwiki-sync.py")
_sync_spec = importlib.util.spec_from_file_location("iwiki_sync", _SYNC_PATH)
sync = importlib.util.module_from_spec(_sync_spec)
_sync_spec.loader.exec_module(sync)


def test_is_documentable_excludes_instruction_and_meta_docs():
    # Agent-instruction basenames are excluded in ANY directory.
    assert iw.is_documentable("CLAUDE.md") is False
    assert iw.is_documentable("AGENTS.md") is False
    assert iw.is_documentable("GEMINI.md") is False
    assert iw.is_documentable("subdir/CLAUDE.md") is False
    # Root meta-docs are excluded only at the repo root.
    assert iw.is_documentable("README.md") is False
    # A subdir README.md may still document a component → kept.
    assert iw.is_documentable("docs/README.md") is True
    # Ordinary source stays documentable.
    assert iw.is_documentable("lib/foo.sh") is True
    assert iw.is_documentable("iclaude.sh") is True
    # Pre-existing prefix excludes still hold.
    assert iw.is_documentable("docs/wiki/x.md") is False
    assert iw.is_documentable("commands/y.md") is False


def test_is_documentable_excludes_tests():
    # Test directories anywhere in the path.
    assert iw.is_documentable("tests/test_x.py") is False
    assert iw.is_documentable("tests/api/test_mcp_auth.py") is False
    assert iw.is_documentable("src/__tests__/foo.ts") is False
    assert iw.is_documentable("pkg/spec/thing.js") is False
    # Test-shaped basenames in any directory.
    assert iw.is_documentable("src/test_foo.py") is False
    assert iw.is_documentable("pkg/foo_test.py") is False
    assert iw.is_documentable("conftest.py") is False
    assert iw.is_documentable("ui/button.test.ts") is False
    assert iw.is_documentable("ui/button.spec.js") is False
    # Non-test sources stay documentable (no false exclusion).
    assert iw.is_documentable("src/paw/main.py") is True
    assert iw.is_documentable("lib/iwiki/detect.sh") is True
    assert iw.is_documentable("latest/release.py") is True   # 'latest' != 'test' segment


def test_decide_nag_bounds_stable_sig():
    # Fresh session, stable sig: "ask" exactly MAX_ASK times (the first ask is
    # counted), then "yield" on every subsequent call — and it never resets.
    sess = {}
    actions = []
    for _ in range(6):
        action, sess = iw.decide_nag(sess, "deadbeef", 2)
        actions.append(action)
    assert actions == ["ask", "ask", "yield", "yield", "yield", "yield"]


def test_decide_nag_max_ask_zero():
    # MAX_ASK=0 → ask once, then yield forever.
    sess = {}
    a1, sess = iw.decide_nag(sess, "x", 0)
    a2, sess = iw.decide_nag(sess, "x", 0)
    a3, sess = iw.decide_nag(sess, "x", 0)
    assert [a1, a2, a3] == ["ask", "yield", "yield"]


def test_decide_nag_resets_on_changed_sig():
    # A different sig resets count to 1 and asks again.
    sess = {}
    _, sess = iw.decide_nag(sess, "A", 2)
    _, sess = iw.decide_nag(sess, "A", 2)
    action, sess = iw.decide_nag(sess, "B", 2)
    assert action == "ask"
    assert sess["asked_sig"] == "B"
    assert sess["count"] == 1


def test_render_pending_listing_groups_by_page():
    pending = ["src/mcp/tools.py", "src/mcp/server.py", "src/main.py", "src/new.py"]
    page_map = {
        "src/mcp/tools.py": "docs/wiki/mcp.md",
        "src/mcp/server.py": "docs/wiki/mcp.md",
        "src/main.py": "docs/wiki/main.md",
        # src/new.py: absent → "new, needs a page"
    }
    out = iw.render_pending_listing(pending, page_map)
    # 3 sources of mcp.md collapse to ONE line listing all three.
    assert ("  - docs/wiki/mcp.md is stale — re-run iwiki-ingest "
            "(covers: src/mcp/server.py, src/mcp/tools.py)") in out
    assert "docs/wiki/main.md is stale" in out
    assert "new, needs a wiki page — run iwiki-ingest: src/new.py" in out
    # One line per page (not one per source): mcp.md appears once.
    assert out.count("docs/wiki/mcp.md is stale") == 1


def test_render_pending_listing_caps_overflow():
    pending = [f"f{i}.py" for i in range(20)]   # 20 unpaged sources → 1 "new" line
    page_map = {}
    out = iw.render_pending_listing(pending, page_map, cap=12)
    # 20 unpaged sources are one "new" line, so no overflow here:
    assert "…and" not in out
    # But 20 distinct pages → 20 lines, capped at 12 + tail:
    many = {f"f{i}.py": f"docs/wiki/p{i}.md" for i in range(20)}
    out2 = iw.render_pending_listing([f"f{i}.py" for i in range(20)], many, cap=12)
    assert out2.count(" is stale") == 12
    assert "…and 8 more" in out2


def test_pending_subtracts_covered(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    for name in ("a.py", "b.py"):
        (tmp_path / name).write_text("x", encoding="utf-8")
    monkeypatch.setattr(sync.iw, "changed_sources", lambda: ["a.py", "b.py"])
    monkeypatch.setattr(sync.iw, "committed_sources", lambda since: [])
    monkeypatch.setattr(sync.iw, "covered_sources", lambda: {"a.py"})
    sess = {"wip": [], "head": "", "edits": []}
    # a.py is covered → only b.py remains pending
    assert sync._pending(sess) == ["b.py"]
