#!/usr/bin/env python3
"""PostToolUse hook — record what changed this turn; defer the reindex (no engine call).

(Filename kept as iwiki-reindex.py for plugin-cache stability; the actual `index`
pass is now batched once at Stop by iwiki-sync.py — this hook only flags it.)

Cheap, deterministic bookkeeping after each Write/Edit/MultiEdit so the Stop
hook can act precisely instead of re-deriving everything from the dirty tree:

- A **documentable source** edit is appended to the session `edits` set. This is
  the action-attributed signal (improvement F): the Stop hook nags about files
  the agent actually touched, not whatever happened to be dirty on disk.
- A **wiki page** edit flips `wiki_dirty`. The reindex is then run ONCE at Stop
  (batched) instead of per edit — N page edits in a turn cost one `index`, not
  N. No uv spawn happens here, so the edit is never slowed and the old per-edit
  90 s timeout window is gone.

Fail-soft, never blocks the edit (always exit 0). Kill switch: IWIKI_AUTO_REINDEX=0
(disables the wiki-dirty flag, hence the batched reindex; edit-tracking is cheap
and stays on so source-change nags keep working).
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iwiki_common as iw  # type: ignore[import-not-found]  # noqa: E402


def _is_wiki_page(path: str) -> bool:
    if not path or not path.endswith(".md"):
        return False
    ap = os.path.abspath(path)
    root = os.path.abspath(iw.WIKI_DIR)
    if not (ap == root or ap.startswith(root + os.sep)):
        return False
    return os.sep + ".iwiki" + os.sep not in ap  # ignore the index dir itself


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    if data.get("tool_name") not in ("Write", "Edit", "MultiEdit"):
        return 0
    iw.cd_project()
    path = (data.get("tool_input") or {}).get("file_path") or ""
    if not path:
        return 0

    sess = iw.read_session()
    dirty = False
    if _is_wiki_page(path):
        if os.environ.get("IWIKI_AUTO_REINDEX", "1") != "0" and not sess.get("wiki_dirty"):
            sess["wiki_dirty"] = True
            dirty = True
    else:
        rel = iw.rel_to_project(path)
        if iw.is_documentable(rel) and rel not in sess.get("edits", []):
            sess.setdefault("edits", []).append(rel)
            dirty = True
    if dirty:
        iw.write_session(sess)
    return 0


if __name__ == "__main__":
    sys.exit(main())
