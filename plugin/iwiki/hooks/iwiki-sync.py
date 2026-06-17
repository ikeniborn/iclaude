#!/usr/bin/env python3
"""Stop hook — keep the wiki current after work, automatically.

When a turn ends with documentable source changes (uncommitted code/docs that a
wiki page describes, including anything a subagent edited this turn), this drives
Claude to update the wiki: it blocks the stop once and injects a directive to run
iwiki-ingest on the changed sources, then /iwiki-lint. Page regeneration needs
the LLM, so the hook cannot do it itself — it forces the follow-up instead of
relying on anyone remembering.

Loop-safe: a stamp records the change-set already acted on. The same set never
blocks twice (ingesting edits the wiki, not the source, so the signature holds),
so at most one ingest pass per distinct set of source changes — and none once the
work is committed. Fail-soft and kill-switchable (IWIKI_AUTO_SYNC=0).
"""
from __future__ import annotations

import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iwiki_common as iw  # type: ignore[import-not-found]  # noqa: E402


def _stamp_path() -> str:
    ccd = os.environ.get("CLAUDE_CONFIG_DIR")
    base = os.path.join(ccd, ".cache") if ccd else ".git"
    try:
        os.makedirs(base, exist_ok=True)
    except Exception:
        base = "."
    return os.path.join(base, "iwiki-sync.stamp")


def _signature(paths: list[str]) -> str:
    return hashlib.sha256("\n".join(paths).encode("utf-8")).hexdigest()[:16]


def _read_stamp(p: str) -> str:
    try:
        with open(p, encoding="utf-8") as f:
            return f.read().strip()
    except Exception:
        return ""


def _write_stamp(p: str, sig: str) -> None:
    try:
        with open(p, "w", encoding="utf-8") as f:
            f.write(sig)
    except Exception:
        pass


def main() -> int:
    if os.environ.get("IWIKI_AUTO_SYNC", "1") == "0":
        return 0
    try:
        json.load(sys.stdin)  # consume payload; the decision is git-driven
    except Exception:
        pass

    try:
        iw.cd_project()
        if not iw.wiki_present():
            return 0  # project does not use iwiki → never pester

        sources = iw.changed_sources()
        stamp = _stamp_path()
        if not sources:
            _write_stamp(stamp, "")   # nothing pending → reset
            return 0
        sig = _signature(sources)
        if _read_stamp(stamp) == sig:
            return 0  # already acted on this exact change-set → allow stop
        _write_stamp(stamp, sig)      # stamp BEFORE forcing → no infinite loop

        shown = sources[:12]
        more = "" if len(sources) == len(shown) else \
            f"\n  …and {len(sources) - len(shown)} more"
        listing = "\n".join(f"  - {p}" for p in shown) + more
        reason = (
            "[iwiki] Source changed this turn — update the wiki before finishing "
            "(docs/wiki/ must stay current):\n" + listing + "\n"
            "For each changed source, run the iwiki:iwiki-ingest skill to "
            "regenerate/update its docs/wiki page, then /iwiki-lint. Skip files "
            "with no documentable behaviour change (pure formatting/typos)."
        )
        print(json.dumps({"decision": "block", "reason": reason}))
        return 0
    except Exception:
        return 0  # a documentation helper must never wedge a stop


if __name__ == "__main__":
    sys.exit(main())
