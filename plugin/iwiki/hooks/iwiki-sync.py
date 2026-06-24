#!/usr/bin/env python3
"""Stop hook — batch the reindex and keep the wiki current after work.

Runs once at the end of a turn and does two things:

1. **Batched reindex.** If a wiki page changed this session (`wiki_dirty` set by
   the record hook), run the engine `index` exactly once so semantic search
   reflects every page edit — without an `index` per edit.

2. **Source-change nag.** Compute the documentable sources this *session* changed
   and, if any are still undocumented, block the stop once and inject a directive
   to run iwiki-ingest + /iwiki-lint. Page regeneration needs the LLM, so the
   hook forces the follow-up rather than relying on anyone remembering.

The change-set is attributed to the session's own actions, not the raw dirty
tree:

- **− baseline WIP** (improvement F / fewer false positives): files already dirty
  at SessionStart are subtracted, so pre-existing work-in-progress the agent
  never touched does not trigger a nag.
- **+ committed** (catch commit-evasion): sources committed during the session
  are still flagged, so committing before stop no longer evades the wiki update.
- **+ explicit edits**: files the record hook saw the agent edit are kept even if
  they overlap the baseline WIP set.

Loop-safe (C): the same unchanged set re-asks at most MAX_ASK times via the pure
decide_nag bound, then yields so the stop is never wedged. The bound is the ask
count alone — no wiki/index state feeds it, so the hook's own reindex can no
longer reset it. Fail-soft and kill-switchable (IWIKI_AUTO_SYNC=0).
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iwiki_common as iw  # type: ignore[import-not-found]  # noqa: E402

# Re-ask this many times for an unchanged pending set, then yield so the stop is
# never wedged. Override via IWIKI_SYNC_MAX_ASK (default 2; 0 = ask once, then
# yield on the next stop). This only bounds re-asks for a *persisted* set — it
# does not change the single ask emitted whenever the session state is reset.
try:
    MAX_ASK = max(0, int(os.environ.get("IWIKI_SYNC_MAX_ASK", "2")))
except ValueError:
    MAX_ASK = 2
REINDEX_TIMEOUT = 90.0


def _pending(sess: dict) -> list[str]:
    """Documentable sources this session changed and that still exist:
    (working ∪ committed) minus pre-existing WIP, plus the agent's explicit
    edits — then minus sources already covered by a fresh wiki page (the nag
    clears when the doc work is actually done, not when MAX_ASK runs out)."""
    wip = set(sess.get("wip", []))
    working = set(iw.changed_sources())
    committed = set(iw.committed_sources(sess.get("head", "")))
    universe = working | committed
    git_delta = universe - wip
    edits_pending = set(sess.get("edits", [])) & universe
    covered = iw.covered_sources()
    return sorted(p for p in (git_delta | edits_pending)
                  if os.path.exists(p) and p not in covered)


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

        sess = iw.read_session()

        # 1. Batched reindex — one pass if any wiki page changed this session.
        if sess.get("wiki_dirty") and iw.index_exists() \
                and os.environ.get("IWIKI_AUTO_REINDEX", "1") != "0":
            iw.run_engine(["index"], REINDEX_TIMEOUT)
            sess["wiki_dirty"] = False
            iw.write_session(sess)

        # 2. Source-change nag.
        pending = _pending(sess)
        if not pending:
            sess["asked_sig"] = ""
            sess["count"] = 0
            iw.write_session(sess)
            return 0

        sig = iw.signature(pending)
        action, sess = iw.decide_nag(sess, sig, MAX_ASK)
        iw.write_session(sess)
        if action == "yield":
            return 0

        listing = iw.render_pending_listing(pending, iw.source_page_map())
        reason = (
            "[iwiki] Source changed this turn — update the wiki before finishing "
            "(docs/wiki/ must stay current):\n" + listing + "\n"
            "Re-run the iwiki:iwiki-ingest skill for each stale page (or to create "
            "a missing one), then /iwiki-lint. Skip files with no documentable "
            "behaviour change (pure formatting/typos)."
        )
        print(json.dumps({"decision": "block", "reason": reason}))
        return 0
    except Exception:
        return 0  # a documentation helper must never wedge a stop


if __name__ == "__main__":
    sys.exit(main())
