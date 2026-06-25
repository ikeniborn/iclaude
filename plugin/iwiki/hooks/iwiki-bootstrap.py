#!/usr/bin/env python3
"""SessionStart hook — bootstrap the wiki and establish the session baseline.

Three jobs at the start of every session:

1. **Baseline.** Snapshot the current HEAD and the pre-existing dirty working
   tree into the shared session state. The Stop sync hook subtracts this `wip`
   set so it only ever nags about changes THIS session introduced — never a
   half-finished WIP that was already on disk when the session opened.

2. **Seed `.iwikiignore`.** For a project that already uses iwiki (has a
   `docs/wiki/`), write a commented `.iwikiignore` template at the project root
   when none exists, so the exclude file is discoverable. Idempotent.

3. **Bootstrap nudge.** If the project has documentable source but no wiki yet,
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
        payload = json.load(sys.stdin)
    except Exception:
        payload = {}
    sid = str(payload.get("session_id") or "") if isinstance(payload, dict) else ""
    try:
        iw.cd_project()
        # 1. Reset the session baseline — but ONLY for a genuinely new session.
        # SessionStart can re-fire within one session (e.g. resume); the session
        # id is stable across those re-fires. Re-resetting on every fire would
        # clobber the Stop hook's dedup (asked_sig/count) and re-arm the nag every
        # turn, so reset only when the id is new (or no state file yet). Never
        # overwrite an existing baseline with an empty one when HEAD is unreadable.
        prev = iw.read_session()
        exists = os.path.exists(iw.session_path())
        new_session = (not exists) or (sid != "" and sid != prev.get("session_id", ""))
        head = iw.git_head()
        if new_session and (head or not exists):
            iw.write_session({
                "session_id": sid,
                "head": head,
                "wip": iw.changed_sources(),
                "edits": [],
                "wiki_dirty": False,
                "asked_sig": "",
                "count": 0,
            })
        # 2. Seed a commented .iwikiignore template at the project root for
        # projects that use iwiki (have a wiki), so the exclude file is
        # discoverable. Idempotent — never touches an existing file.
        if iw.wiki_present():
            iw.seed_ignore()
        # 3. Bootstrap nudge.
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
