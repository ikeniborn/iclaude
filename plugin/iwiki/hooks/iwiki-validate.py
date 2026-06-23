#!/usr/bin/env python3
"""PreToolUse hook — block wiki pages that break section-formation structure.

Blocks (exit 2) a Write/Edit/MultiEdit to a docs/wiki/ page whose RESULTING content
has a heading deeper than ## (deep_heading) or indexable text before the first ##
other than a single # H1 (pre_h2_text). Advisory findings (missing Overview, lead
length) are left to lint and never block.

Mirrors the engine validator's blocking regexes inline (same convention as lint.py
inlining chunk._H2) so the hook needs no uv/engine spawn on every edit.

Kill switch: IWIKI_VALIDATE_SECTIONS=0. Fails OPEN on any internal error (always
exit 0 unless a real violation is found) so it can never wedge an edit.
"""
from __future__ import annotations

import json
import os
import re
import sys

try:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import iwiki_common as iw  # type: ignore[import-not-found]  # noqa: E402
except Exception:
    sys.exit(0)  # cannot load common module — fail open, never wedge an edit

_DEEP = re.compile(r"^#{3,}\s", re.MULTILINE)
_H1_LINE = re.compile(r"^#\s+\S")
_H2 = re.compile(r"^##\s+", re.MULTILINE)


def _is_wiki_page(path: str) -> bool:
    if not path or not path.endswith(".md"):
        return False
    ap = os.path.abspath(path)
    root = os.path.abspath(iw.WIKI_DIR)
    if not (ap == root or ap.startswith(root + os.sep)):
        return False
    return os.sep + ".iwiki" + os.sep not in ap


def _post_edit_content(tool: str, ti: dict) -> str | None:
    """Resulting file content after the tool runs, or None if underivable."""
    if tool == "Write":
        return ti.get("content") or ""
    path = ti.get("file_path") or ""
    try:
        cur = open(path, encoding="utf-8").read()
    except Exception:
        cur = ""
    if tool == "Edit":
        old, new = ti.get("old_string", ""), ti.get("new_string", "")
        return cur.replace(old, new) if ti.get("replace_all") else cur.replace(old, new, 1)
    if tool == "MultiEdit":
        for e in ti.get("edits", []):
            old, new = e.get("old_string", ""), e.get("new_string", "")
            cur = cur.replace(old, new) if e.get("replace_all") else cur.replace(old, new, 1)
        return cur
    return None


def _blocking_violations(content: str) -> list[str]:
    out: list[str] = []
    if _DEEP.search(content):
        out.append("deep_heading: a heading deeper than ## (###+); flatten to ##")
    h2 = _H2.search(content)
    pre = content[:h2.start()] if h2 else content
    if any(ln.strip() and not _H1_LINE.match(ln) for ln in pre.splitlines()):
        out.append("pre_h2_text: text before the first ## (only a single # H1 allowed)")
    return out


def main() -> int:
    if os.environ.get("IWIKI_VALIDATE_SECTIONS", "1") == "0":
        return 0
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    if data.get("tool_name") not in ("Write", "Edit", "MultiEdit"):
        return 0
    try:
        iw.cd_project()
        ti = data.get("tool_input") or {}
        if not _is_wiki_page(ti.get("file_path") or ""):
            return 0
        content = _post_edit_content(data["tool_name"], ti)
        if content is None:
            return 0
        violations = _blocking_violations(content)
    except Exception:
        return 0  # fail open — never wedge an edit
    if violations:
        reason = ("iwiki section-formation blocked "
                  + os.path.basename(ti.get("file_path") or "page")
                  + ":\n  - " + "\n  - ".join(violations))
        print(reason, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
