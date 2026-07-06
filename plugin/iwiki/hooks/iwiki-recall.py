#!/usr/bin/env python3
"""UserPromptSubmit hook — consult the wiki BEFORE work, automatically.

Runs the iwiki engine's semantic `search` on the user's prompt and injects the
top matching docs/wiki sections as context, so relevant documentation is on the
table before any task starts — without the user (or Claude) having to remember
/iwiki-query.

Degrades gracefully: trivial prompts, an uninitialised wiki, missing config, or
a slow/failed engine fall back to a one-line nudge or silence. Never blocks the
prompt (UserPromptSubmit, always exit 0). Kill switch: IWIKI_AUTO_QUERY=0.

stdout (exit 0) on UserPromptSubmit is injected into Claude's context.
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iwiki_common as iw  # type: ignore[import-not-found]  # noqa: E402

MIN_PROMPT_CHARS = 24      # skip greetings / "коммит" / "push" / yes-no
SEARCH_TIMEOUT = 12.0
TOP_N = 5
NUDGE = ("[iwiki] Before starting, consider /iwiki-query to pull relevant "
         "docs/wiki context.")


def _prompt_text(data: dict) -> str:
    # UserPromptSubmit payload exposes the prompt; tolerate key variants.
    for key in ("prompt", "user_prompt", "message"):
        v = data.get(key)
        if isinstance(v, str) and v.strip():
            return v.strip()
    return ""


def main() -> int:
    if os.environ.get("IWIKI_AUTO_QUERY", "1") == "0":
        return 0
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0

    iw.cd_project()
    prompt = _prompt_text(data)
    if len(prompt) < MIN_PROMPT_CHARS or prompt.startswith("/"):
        return 0  # trivial / slash command → don't spend an embedding call
    if not iw.index_exists():
        return 0  # wiki not initialised here → silent

    rc, out = iw.run_engine(["search", prompt, "-k", str(TOP_N)], SEARCH_TIMEOUT)
    if rc != 0 or not out:
        # engine missing / config halt / timeout → light nudge, never fail hard
        print(NUDGE)
        return 0
    try:
        hits = json.loads(out)
    except Exception:
        print(NUDGE)
        return 0
    if not hits:
        return 0  # no relevant section above threshold → stay quiet

    lines = ["[iwiki] Relevant docs/wiki sections for this request "
             "(semantic match — read these or /iwiki-query before proceeding):"]
    for h in hits[:TOP_N]:
        score = h.get("score")
        tag = f" ({score:.2f})" if isinstance(score, (int, float)) else ""
        lines.append(f"- {h.get('id', h.get('file', '?'))}{tag}")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
