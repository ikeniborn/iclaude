#!/usr/bin/env python3
"""PostToolUse hook — keep the embedding index fresh automatically.

When any docs/wiki/*.md page is written or edited (by the iwiki-ingest skill OR
by hand), refresh the engine index so semantic search reflects the change with
no manual step. The index pass is incremental (unchanged chunks are reused, so
no embedding call when nothing changed) and idempotent.

No loop: it triggers only on docs/wiki/*.md edits; the index it writes lives in
docs/wiki/.iwiki/ and is not itself a wiki page. Advisory and fail-soft — never
disrupts the edit (always exit 0). Kill switch: IWIKI_AUTO_REINDEX=0.
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iwiki_common as iw  # type: ignore[import-not-found]  # noqa: E402

INDEX_TIMEOUT = 90.0


def _is_wiki_page(path: str) -> bool:
    if not path or not path.endswith(".md"):
        return False
    ap = os.path.abspath(path)
    root = os.path.abspath(iw.WIKI_DIR)
    if not (ap == root or ap.startswith(root + os.sep)):
        return False
    return os.sep + ".iwiki" + os.sep not in ap  # ignore the index dir itself


def main() -> int:
    if os.environ.get("IWIKI_AUTO_REINDEX", "1") == "0":
        return 0
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0

    if data.get("tool_name") not in ("Write", "Edit", "MultiEdit"):
        return 0
    iw.cd_project()
    path = (data.get("tool_input") or {}).get("file_path") or ""
    if not _is_wiki_page(path):
        return 0
    if not iw.index_exists():
        return 0  # wiki not initialised → nothing to refresh

    rc, out = iw.run_engine(["index"], INDEX_TIMEOUT)
    if rc == 0 and out:
        # Surface the result so the reindex is visible, not silent magic.
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": "[iwiki] index refreshed after wiki edit: " + out,
        }}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
