#!/usr/bin/env python3
"""SessionStart hook — bootstrap the wiki and establish the session baseline.

Two jobs at the start of every session:

1. **Baseline.** Snapshot the current HEAD and the pre-existing dirty working
   tree into the shared session state. The Stop sync hook subtracts this `wip`
   set so it only ever nags about changes THIS session introduced — never a
   half-finished WIP that was already on disk when the session opened.

2. **Bootstrap nudge.** If the project has documentable source but no wiki yet,
   nudge `/iwiki-init`; if it has pages but no index, nudge a rebuild. This is
   the one place that surfaces the wiki when it does not exist yet — no other
   trigger fires on an empty `docs/wiki/`.

Filesystem/git only (no embedding call), so it stays fast. Fail-soft and never
blocks the session. Kill switch: IWIKI_AUTO_BOOTSTRAP=0.
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iwiki_common as iw  # type: ignore[import-not-found]  # noqa: E402


def _emit(context: str) -> None:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    }}))


def main() -> int:
    if os.environ.get("IWIKI_AUTO_BOOTSTRAP", "1") == "0":
        return 0
    try:
        json.load(sys.stdin)  # consume payload; decision is filesystem-driven
    except Exception:
        pass
    try:
        iw.cd_project()
        # 1. Reset the session baseline (fresh work boundary).
        iw.write_session({
            "head": iw.git_head(),
            "wip": iw.changed_sources(),
            "edits": [],
            "wiki_dirty": False,
            "asked_sig": "",
            "asked_wiki": "",
            "count": 0,
        })
        # 2. Bootstrap nudge.
        pages = iw.wiki_pages() if iw.wiki_present() else []
        if not pages:
            if iw.has_documentable_source():
                _emit("[iwiki] This project has no docs/wiki/ yet. To make the "
                      "wiki + semantic recall available, run /iwiki-init to "
                      "bootstrap pages from the source tree.")
            return 0
        if not iw.index_exists():
            _emit("[iwiki] docs/wiki/ has pages but no embedding index. Run "
                  "/iwiki-ingest on any page (or rebuild the index) so semantic "
                  "search and pre-work recall work.")
        return 0
    except Exception:
        return 0  # a documentation helper must never disrupt session start


if __name__ == "__main__":
    sys.exit(main())
