---
review:
  spec_hash: 85e3c417218e5f1f
  last_run: 2026-06-24
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - id: F-001
      phase: coverage
      severity: WARNING
      section: "A. covered_sources() — new helper in iwiki_common.py"
      section_hash: 68eb4549aa6bb84c
      text: >-
        Spec claimed the helper and /iwiki-lint "never disagree about a given
        source", but lint._stale dedups by page (first-wins) while the helper
        dedups by source (last-wins) — different axes. Reworded to state the
        shared freshness threshold precisely and explain the two dedup axes are
        not in tension (lint reports stale pages; the helper classifies sources).
      verdict: fixed
      verdict_at: 2026-06-24
    - id: F-002
      phase: clarity
      severity: WARNING
      section: "A. covered_sources() — new helper in iwiki_common.py"
      section_hash: 68eb4549aa6bb84c
      text: >-
        Pseudocode predicate "op == ingest (or any record carrying source+page)"
        was ambiguous. lint._stale filters on neither op nor anything but
        source+page presence; changed the helper to the same predicate (every
        record carrying both source and page) so the two never diverge on which
        records count.
      verdict: fixed
      verdict_at: 2026-06-24
chain:
  intent: null
---
# iwiki Stop nag: clear when the wiki is actually current, not when the ask budget runs out

## Overview

The iwiki `Stop` hook (`plugin/iwiki/hooks/iwiki-sync.py`) nags the agent to update
`docs/wiki/` whenever a documentable source changed this session. Its "pending" set is
`(working ∪ committed) − wip` plus the agent's explicit edits — purely *what changed*.
It never subtracts *what has already been documented*. The hook has no notion of a source
being "covered". The only thing that silences a stable nag is the `MAX_ASK` re-ask bound:
the hook **gives up**, it does not **recognise completion**. So an agent that ran
`iwiki-ingest`, regenerated the page, committed everything, and passed `/iwiki-lint` clean
is still nagged — until the bound is exhausted. Re-running ingest only re-embeds identical
content; the nag fires again regardless.

This spec makes the nag's pending set subtract sources that are **already documented and
fresh**, reusing the exact provenance the engine's `lint` already uses
(`docs/wiki/.iwiki/log.jsonl` + page-vs-source mtime). It also stops counting **test files**
as documentable (iwiki generates no page for tests, so they can never become "covered" and
nag forever), and **groups** the nag message by target page so N sources mapping to one page
read as one action, not N. `MAX_ASK` stays as a defence-in-depth backstop but now rarely
fires, because real completion clears the nag first.

Two files change: `plugin/iwiki/hooks/iwiki_common.py` and
`plugin/iwiki/hooks/iwiki-sync.py`. The engine is untouched.

## Background — root cause (verified)

- **The nag is change-driven only.** `iwiki-sync.py:_pending()` computes
  `git_delta = (changed_sources() ∪ committed_sources(head)) − wip` and
  `edits_pending = edits ∩ universe`, then returns the existing files of
  `git_delta ∪ edits_pending`. No step asks whether a source already has an up-to-date
  wiki page.
- **The bound is ask-count, not work-state.** `decide_nag()` (`iwiki_common.py:278`) asks a
  stable signature at most `MAX_ASK` (default 2) times, then yields. The docstring is explicit
  that "no wiki/index state feeds it" — by design, so the hook's own reindex cannot reset the
  bound. The side effect is that a *finished* task is silenced the same way an *ignored* one
  is: by exhausting the budget.
- **`committed_sources` makes it sticky for the whole session.** Once a source is committed
  during the session it stays in `committed_sources(baseline_head..HEAD)` until session end.
  So even after the wiki is updated and committed, the source remains "pending" and the nag
  keeps firing (bounded by `MAX_ASK`). This is the reported symptom: wiki current and
  committed, lint clean, PR open — nag still fires every Stop until it gives up.
- **The provenance the hook ignores already exists.** The `iwiki-ingest` skill appends
  `{"op":"ingest","source":"<src>","page":"<page>","date":"..."}` to
  `docs/wiki/.iwiki/log.jsonl` (skill step 5). The engine's `lint._stale()`
  (`engine/iwiki_engine/lint.py:51`) reads exactly this log and flags a page stale when
  `mtime(source) > mtime(page)`. The hook reimplements only the *change* half of the
  staleness question and skips the *covered* half that `lint` already answers.
- **Tests are documentable but unpageable.** `is_documentable()` (`iwiki_common.py:149`)
  accepts `.py`/`.md`/`.ts`/… and only excludes the wiki/IDD/command/VCS prefixes and
  agent-instruction / root-meta basenames. Nothing excludes `tests/`. iwiki does not generate
  a wiki page for test files, so a changed test can never appear in the log as "covered" and
  nags every session until `MAX_ASK` yields. The triggering session listed
  `tests/api/test_mcp_auth.py`, `tests/e2e/test_mcp_e2e.py`, `tests/unit/test_mcp_server.py`.
- **N sources → 1 page granularity mismatch.** `src/paw/mcp/{tools,server,auth}.py` and
  `src/paw/main.py` are all documented by one page (`mcp.md`). The nag lists each source as a
  separate "run ingest for each changed source" item — four items for one ingest. One
  re-ingest of `mcp.md` makes the page newer than all four sources at once.

## The fix

### A. `covered_sources()` — new helper in `iwiki_common.py`

A stdlib, fail-soft reader of the ingest log that returns the set of repo-relative source
paths currently covered by a fresh page. Mirrors `lint._stale()` but answers the inverse
question (covered, not stale) and lives in the hook so no engine/uv spawn is needed.

```
covered_sources() -> set[str]:
    log = docs/wiki/.iwiki/log.jsonl
    if not a file: return set()
    covered = set()
    for each json line carrying both "source" and "page":   # same predicate as lint._stale
        src, page = rec["source"], rec["page"]
        if src and page and isfile(src) and isfile(page):
            if mtime(page) >= mtime(src):   # page is at least as new as the source
                covered.add(src)
            else:
                covered.discard(src)        # a later edit re-staled it
    return covered
```

- **Record predicate matches lint.** `lint._stale()` reads every log record that carries both
  `source` and `page` (it filters on neither `op` nor anything else — `lint.py:71`); the helper
  uses the same predicate so the two never diverge on *which records count*.
- **Last record wins per source.** Iterating in file order and add/discard per record resolves
  each source to its most recent ingest: a source ingested, then edited again (re-staled) ends
  up *not* covered. (This is a per-*source* resolution; `lint._stale` dedups its *output* per
  *page*, first-record-wins — a different axis, because lint reports stale pages while the helper
  classifies sources. They are not in tension: both apply the one freshness threshold below.)
- **Freshness threshold is identical to lint** (`mtime(page) ≥ mtime(source)` is the exact
  inverse of lint's stale test `mtime(source) > mtime(page)`), so for any one `(source, page)`
  pair the helper calls "covered" exactly the pairs lint would *not* call stale.
- **Path domains match.** The skill writes `source` repo-relative (it runs from project root);
  `_pending` produces repo-relative git paths; `cd_project()` has already set cwd to the
  project root. `mtime` is read on those repo-relative paths from the same cwd.
- **Fail-soft.** Any error (missing log, unreadable, bad json, mtime race) → treat as
  "nothing covered" → return `set()`. That direction over-nags rather than dropping a real
  nag, and the over-nag is bounded by `MAX_ASK`.

### B. `is_documentable()` excludes tests

Extend the existing exclusion logic so a test path is not documentable (iwiki has no test
pages). Exclude when any path segment is `tests`, `test`, `__tests__`, or `spec`, or the
basename matches a common test pattern: `conftest.py`, `test_*.py`, `*_test.py`,
`*.test.{js,ts}`, `*.spec.{js,ts}`.

- Implemented as a small `_is_test_path(p)` predicate checked inside `is_documentable`, kept
  next to the existing `EXCLUDE_*` constants for the same surgical style.
- This change is shared by every caller of `is_documentable` — `changed_sources`,
  `committed_sources`, the PostToolUse `edits` recorder, and `has_documentable_source`. That
  is correct and intended: tests should not arm the nag, should not be recorded as edits, and
  should not by themselves trigger the bootstrap "you have source but no wiki" nudge.

### C. `_pending()` subtracts covered + page-grouped message

In `iwiki-sync.py`:

```
covered = iw.covered_sources()
pending = sorted(p for p in (git_delta | edits_pending)
                 if os.path.exists(p) and p not in covered)
```

The nag message groups pending sources by their target page using the same log map:

- Sources with a known page in the log → one line per page:
  `- docs/wiki/<page>.md is stale — re-run iwiki-ingest (covers: a.py, b.py, c.py)`
- Sources with no log entry (never ingested) → one block:
  `- new, needs a wiki page — run iwiki-ingest: <files>`

The existing 12-item cap and "…and N more" overflow are kept, applied to the grouped lines.

`MAX_ASK` / `decide_nag` are unchanged and retained: a source the user deliberately won't
document (or a genuine edge where coverage can't be detected) still yields after the bound, so
the stop is never wedged. With covered-subtraction in front of it, the common path clears the
nag by completion long before the bound is reached.

## Data flow

```
iwiki-ingest (skill) ── writes ──▶ docs/wiki/.iwiki/log.jsonl  {source, page}
                                   regenerates page  (mtime(page) ↑)
                                            │
Stop hook (iwiki-sync.py):                  ▼
  git_delta      = (changed ∪ committed) − wip
  covered        = covered_sources(log)         ◀── reads log + mtimes (stdlib)
  pending        = (git_delta ∪ edits) − covered − tests(via is_documentable)
        │
        ├── empty  → reset asked_sig/count, exit silently
        └── nonempty → decide_nag (MAX_ASK backstop) → grouped-by-page block
```

## Edge cases

| Case | Behaviour |
|---|---|
| Source edited again after ingest | `mtime(src) > mtime(page)` → not covered → nag (correct: it *is* stale) |
| 4 sources → 1 page, page re-ingested | page newer than all 4 → all 4 drop from pending in one shot; message already one line |
| Source committed during session, wiki updated + committed | covered → not pending → **nag clears** (the bug, fixed) |
| Test file changed | excluded by `is_documentable` → never pending |
| `log.jsonl` absent or corrupt | `covered_sources()` → `set()` → current behaviour (nothing subtracted) |
| Worktree checkout perturbs mtimes (known lint caveat) | helper fail-soft / over-nag, bounded by `MAX_ASK`; never drops a real nag |
| Page deleted but log still references it | `isfile(page)` false → source not covered → nag to re-create (correct) |

## Verification

1. **`covered_sources()` unit** (temp wiki + log fixture):
   - log maps `a.py → p.md`, `touch p.md` after `a.py` → `a.py` in covered;
   - `touch a.py` after `p.md` → `a.py` not covered (re-staled);
   - log references a page not on disk → not covered;
   - corrupt / empty / missing log → `set()`.
2. **`is_documentable` unit**: `tests/x.py`, `src/test_foo.py`, `pkg/foo_test.py`,
   `conftest.py`, `a.spec.ts`, `b.test.js` → `False`; `src/paw/main.py`,
   `lib/iwiki/detect.sh` → `True`. Regression: the existing wiki/IDD/command/root-meta
   exclusions still hold.
3. **`_pending` scenario**: fixture session where 4 sources of one page changed and the page
   was re-ingested (page mtime newest) → `_pending == []`; same 4 changed but page *not*
   re-ingested → `_pending` lists the 4, and the rendered message is **one** page-grouped
   line.
4. **Regression**: `wip` baseline subtraction and `committed_sources` evasion-catch still
   work (a committed-but-undocumented source still nags; a baseline-WIP file the agent never
   touched still does not).
5. **End-to-end smoke** (manual, reload-dependent like all hook changes): in a project with a
   wiki, change a source → Stop nags; run ingest for it → next Stop is silent.

## Scope / non-goals

- **Not** changing `decide_nag`/`MAX_ASK` semantics — kept as the wedge backstop.
- **Not** changing the engine (`lint`, `index`, log format). The hook reads the existing log;
  no new subcommand, no new log keys.
- **Not** changing the batched-reindex path (`wiki_dirty` → one `index` at Stop).
- **Not** touching the other four hooks (bootstrap / recall / validate / reindex) beyond the
  shared `is_documentable` test-exclusion they already call.
- **Not** addressing the mtime-in-fresh-worktree fragility at its root (a known `lint`
  caveat); the helper just fails toward over-nagging there.

## Branch / PR / version

- Branch `dev-fix-iwiki-sync-nag` (dash, not slash: the existing `dev` branch occupies
  `refs/heads/dev` and blocks a `dev/` namespace — repo convention, cf. `dev-fix-iwiki-…`),
  created from up-to-date `origin/dev`. No worktree (work in place, per request).
- PR opened against `dev`.
- Bump the iwiki plugin version so the cached hook copy resyncs (cached hooks are keyed by
  version; without a bump the live session keeps the old `iwiki-sync.py`).
