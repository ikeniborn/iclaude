"""Unit tests for the pure helpers in the iwiki Stop/Sync hooks.

iwiki_common is stdlib-only (no httpx), so it imports cleanly via a sys.path
insert of the plugin hooks dir — no engine venv needed.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..",
                                "plugin", "iwiki", "hooks"))
import iwiki_common as iw  # noqa: E402


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
