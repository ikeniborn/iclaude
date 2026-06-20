---
chain:
  intent: null
review:
  spec_hash: 70806bbac29924e6
  last_run: 2026-06-21
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - id: F-001
      phase: coverage
      severity: INFO
      section: "### 1. Exclude instruction / meta-doc files (`iwiki_common.py`)"
      section_hash: b005409fd162d61e
      text: >-
        is_documentable's own docstring (iwiki_common.py:143-144) describes the
        exclusion criteria ("source ext, outside the wiki/IDD/command/VCS
        noise"). The spec adds two new exclusion classes but does not mention
        updating that docstring. Cosmetic; behaviour-correct without it.
      verdict: open
      verdict_at: null
    - id: F-002
      phase: clarity
      severity: INFO
      section: "### 2. Hard-cap the nag, drop the `wiki_sig` reconcile"
      section_hash: 4c70f633472fed1e
      text: >-
        The decide_nag docstring says "asked at most max_ask times, then
        yields". Verified against the code: with MAX_ASK=2 the action sequence
        for a stable sig is [ask, ask, yield, ...] (exactly 2 asks); with
        MAX_ASK=0 it is [ask, yield, ...] (1 ask). Matches Test 2 and lines
        126-128. Wording "at most max_ask times" reads correctly only once you
        note the first ask is counted — no change required, recorded for trace.
      verdict: open
      verdict_at: null
---
# iwiki Stop-hook nag loop — fix

**Date:** 2026-06-21
**Status:** design
**Topic:** the iwiki Stop (`iwiki-sync.py`) nag loops forever in some projects

## Problem

In a project where the iwiki plugin is enabled, the Stop hook blocks the turn
forever with a repeating directive such as:

```
[iwiki] Source changed this turn — update the wiki before finishing:
  - CLAUDE.md
For each changed source, run the iwiki:iwiki-ingest skill ... then /iwiki-lint.
```

`git` shows `CLAUDE.md` clean (already committed), yet the nag never yields, so the
session cannot stop.

## Root cause

Two independent defects compound:

1. **Instruction files are treated as documentable source.**
   `iwiki_common.is_documentable()` accepts any `.md` (`SOURCE_EXTS` includes
   `.md`) that is not under an excluded prefix. `CLAUDE.md` / `AGENTS.md` /
   `GEMINI.md` therefore qualify. Once such a file is edited or committed during
   the session, `iwiki-sync._pending()` keeps it (via `edits` and
   `committed_sources`) — and it never leaves, because documenting a source in the
   wiki does not change that source's git status. So the pending set permanently
   contains `CLAUDE.md`.

2. **The `wiki_sig` reconcile defeats the `MAX_ASK` yield.**
   `iwiki-sync.py` (lines 95–110) is meant to re-ask a stable pending set at most
   `MAX_ASK` times (default 2) and then yield, so the stop is never wedged. But it
   has a branch: if the pending signature is unchanged AND `wiki_sig()` (a
   fingerprint of wiki-page + index mtimes) changed since the last ask, it assumes
   "an ingest happened" and **resets `count` to 0**. The Stop hook itself runs the
   batched `index` at the top of `main()` whenever a wiki page changed this session
   — which rewrites `docs/wiki/.iwiki/index.jsonl`, shifting its mtime, shifting
   `wiki_sig`. So every turn that touched the wiki resets the counter, `MAX_ASK` is
   never reached, and the nag re-asks forever.

The two combine: defect 1 keeps `CLAUDE.md` permanently pending; defect 2 prevents
the loop-guard from ever yielding while any wiki activity occurs.

## Decisions (locked)

- **Defect 1:** exclude agent-instruction files **and** root-level meta-docs from
  `is_documentable`.
- **Defect 2:** bound the nag with a hard ask-count cap; remove the `wiki_sig`
  reconcile entirely (it is unreliable — the hook's own reindex triggers it).
- **Testability:** extract the ask/yield decision into a pure function `decide_nag`
  in `iwiki_common.py` and unit-test it (plus `is_documentable`).

## Design

### 1. Exclude instruction / meta-doc files (`iwiki_common.py`)

Add two tuples near the existing exclude constants:

```python
# Agent-instruction files are never wiki source — excluded in ANY directory.
EXCLUDE_BASENAMES = ("CLAUDE.md", "AGENTS.md", "GEMINI.md")
# Project meta-docs are not wiki source at the repo ROOT (a subdir README.md may
# still document a component, so it stays documentable).
EXCLUDE_ROOT_DOCS = ("README.md", "CHANGELOG.md", "CONTRIBUTING.md", "LICENSE.md")
```

Extend `is_documentable(p)` after its current checks:

```python
base = os.path.basename(p)
if base in EXCLUDE_BASENAMES:
    return False
if "/" not in p and base in EXCLUDE_ROOT_DOCS:   # repo-root only (git uses '/')
    return False
return True
```

`is_documentable` is already used by both `_pending` (the nag) and
`has_documentable_source` (the bootstrap nudge), so the exclusion applies
consistently: a project whose only `.md` is `CLAUDE.md` no longer gets nagged and
no longer gets a spurious `/iwiki-init` nudge.

### 2. Hard-cap the nag, drop the `wiki_sig` reconcile

Add a pure decision function to `iwiki_common.py`:

```python
def decide_nag(sess: dict, sig: str, max_ask: int) -> tuple[str, dict]:
    """Decide whether the Stop nag should ask again or yield for the pending-set
    signature `sig`. Returns ("ask" | "yield", sess) with asked_sig/count updated.
    A stable sig is asked at most max_ask times, then yields — never wedging the
    stop. No wiki-state input: the bound is purely the ask count, so wiki/index
    churn between asks can no longer reset it."""
    if sig == sess.get("asked_sig"):
        if sess.get("count", 0) >= max_ask:
            return ("yield", sess)
        sess["count"] = sess.get("count", 0) + 1
    else:
        sess["asked_sig"] = sig
        sess["count"] = 1
    return ("ask", sess)
```

Rewrite the decision block in `iwiki-sync.py main()` to use it:

```python
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
# …build the directive and print {"decision": "block", "reason": …}
```

This preserves the existing `MAX_ASK` semantics (default 2 → at most 2 asks for a
stable set, then yield; `IWIKI_SYNC_MAX_ASK=0` → ask once then yield) but the yield
is now guaranteed regardless of wiki/index changes.

**Trade-off (accepted):** dropping the reconcile means that after a genuine ingest
the nag yields within `≤ MAX_ASK` stops instead of immediately. With `MAX_ASK = 2`
that is at most two extra prompts — acceptable, and far better than an unbounded
loop.

### 3. Remove the orphaned `wiki_sig` / `asked_wiki`

The reconcile was the sole consumer of `wiki_sig()` and the `asked_wiki` session
field. Removing it orphans both, so remove them too (cleanup of code this change
makes unused — not unrelated refactoring):

- `iwiki_common.py`: delete the `wiki_sig()` function; remove `asked_wiki` from
  `_SESSION_DEFAULT`. (`wiki_pages()` stays — `iwiki-bootstrap.py` still uses it.)
- `iwiki-sync.py`: remove the `wsig = iw.wiki_sig()` call and all `asked_wiki`
  reads/writes; update the module docstring and the loop-safety comment (no more
  "a `wiki_sig` shift counts as ingest").
- `iwiki-bootstrap.py`: remove `asked_wiki: ""` from the session-init dict.

`read_session` only copies keys present in `_SESSION_DEFAULT`, so an old session
file that still has `asked_wiki` is simply ignored — backward-compatible.

### 4. Version bump + docs

- Bump `plugin/iwiki/.claude-plugin/plugin.json` `0.5.4 → 0.5.5` (the cache key is
  the version, so the bump resyncs the in-cache hook copy).
- Update `docs/wiki/iwiki.md` "Automation Hooks" section: drop the "`wiki_sig`
  shift between asks counts as the ingest having happened" sentence; state that the
  nag yields after `IWIKI_SYNC_MAX_ASK` asks for a stable set, and that
  agent-instruction / root meta-doc files are excluded from the documentable set.
  Reindex after the edit.

## Out of scope

- Reworking how the nag attributes changes (the `_pending` set logic is unchanged
  apart from the `is_documentable` exclusion).
- Detecting a "real ingest" precisely (the dropped reconcile tried to; the hard cap
  replaces the need).
- The pre-existing `links.py` false-positive broken-link issue (bash `[[ ]]` in
  code fences) — tracked separately from this loop fix.

## Testing / success criteria

New `tests/test_iwiki_hooks.py` (imports `iwiki_common` via a `sys.path` insert of
`plugin/iwiki/hooks`; `iwiki_common` is stdlib-only, no httpx):

1. **is_documentable exclusions:** `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`,
   `subdir/CLAUDE.md`, root `README.md` → `False`; `docs/README.md`, `lib/foo.sh`,
   `iclaude.sh` → `True`; `docs/wiki/x.md`, `commands/y.md` → `False` (existing
   excludes still hold).
2. **decide_nag bound:** starting from a fresh session, calling `decide_nag` with
   the SAME `sig` returns `"ask"` exactly `MAX_ASK` times (counting the first), then
   `"yield"` on every subsequent call — and never resets, no matter how many times
   it is called.
3. **decide_nag reset on change:** a different `sig` resets `count` to 1 and returns
   `"ask"`.
4. **No wiki input:** `decide_nag`'s signature takes no wiki/index state, so by
   construction wiki churn cannot affect the yield (covered by 2).

Manual: in a temp project containing only `CLAUDE.md`, a Stop with the new
`is_documentable` produces an empty pending set → no nag.
