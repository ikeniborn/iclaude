# Bug: ingest log writes `page` as a basename → stop-hook covered-check is dead, nag loops

## Affected components

- **Hook (consumer):** `iclaude/plugin/iwiki/hooks/iwiki_common.py` — `covered_sources()` (lines 330–348), `_fresh()` (287–295)
- **Engine (consumer):** `ai-wiki-plugin/engine/iwiki_engine/lint.py` — `_stale()` (73–103)
- **Producer (writer):** `ai-wiki-plugin/skills/iwiki-ingest/SKILL.md` — step 5, log line (line 68)

## Symptom

The `iwiki-sync.py` stop hook blocks the stop on every turn (re-asking up to `MAX_ASK`, then again on any further edit) with:

```
[iwiki] Source changed this turn ... installation.md is stale — re-run iwiki-ingest (covers: docs/README.ru.md)
```

Meanwhile `iwiki_engine ... lint` reports `stale: []` — clean. The "hook nags / lint is silent" contradiction is misleading and prevents closing the turn.

## Reproduction

1. A project with `docs/wiki/`.
2. Change a documentable source (e.g. `docs/README.ru.md`).
3. Create/update a wiki page `docs/wiki/installation.md`.
4. Append the ingest log exactly as the skill instructs: `{"source":"docs/README.ru.md","page":"installation.md","src_hash":"<matching>"}` (basename `page`).
5. End the turn → the hook nags even though the page is fresh and `src_hash` matches. Repeat edits → the nag never clears.

## Root cause

The ingest log stores `page` as a **basename** (`installation.md`), while both freshness functions resolve it as **repo-relative from cwd**:

- `covered_sources()` (`iwiki_common.py:343`):

  ```python
  if os.path.isfile(src) and os.path.isfile(page) and _fresh(src, page, rec.get("src_hash")):
      covered.add(src)
  ```

  `os.path.isfile("installation.md")` from the project root is **False** (the file lives at `docs/wiki/installation.md`), so the source is **never** added to `covered` → it stays in `_pending()` → nag.

- The engine `_stale()` (`lint.py:96`) does the **same** `os.path.isfile(page)` check without `join(wiki_dir, …)`. But its default is the opposite: a record whose `page` is not found is **silently skipped** (`continue`) → it never enters `stale` → the log looks clean.

Net: the **same broken path**, two opposite defaults — the hook treats "page not found" as "not covered" (nags), the engine treats it as "nothing to check" (stays quiet). The covered mechanism (`covered_sources`) is therefore **effectively dead for every page under `docs/wiki/`**; it would only ever match a basename file sitting in the repo root. The intended guard — "the nag clears when the documentation is actually done" — does not work; only the emergency `MAX_ASK` bound holds.

Contrast: the engine's link resolver (`lint._resolve`, `lint.py:43-49`) correctly does `os.path.join(wiki_dir, t)`. The stale/covered path does not. The resolution is inconsistent within the same module.

## Expected behaviour

A fresh page (page exists, `src_hash` matches) → the source counts as covered → the hook does not nag. `covered_sources()` and `_stale()` must resolve `page` the same way regardless of whether the log stored a basename or a repo-relative path.

## Fix options

1. **Resolve `page` on read (recommended).** In `covered_sources()` and `_stale()`, resolve `page` to an existing file: if `isfile(page)` is false, try `os.path.join(WIKI_DIR, page)` (mirroring `lint._resolve`). Backward-compatible with both old basename records and full-path records. Fixes the root on both reader sides; no log migration needed.
2. **Normalise the producer.** Have the `iwiki-ingest` skill (SKILL.md step 5) write `page` as `docs/wiki/<topic>.md`. Simple, but does not heal already-accumulated basename records or any third-party writers.
3. **Both** — producer writes the full path + readers tolerate either (future-proof).

Recommendation: **option 1 + 2.** Option 1 is mandatory (the covered mechanism must be revived, including for old logs); option 2 removes the input ambiguity.

## Acceptance criteria

- `covered_sources()` returns a source when its latest ingest record points at an existing, fresh page under `docs/wiki/`, with `page` written as a basename **and** as a repo-relative path.
- After a correct ingest + lint, the stop hook does not block the stop (pending is empty), without relying on `MAX_ASK`.
- `_stale()` and `covered_sources()` give a consistent verdict for the same record (inverses of each other, as their docstrings promise).
- Regression test in `iclaude/tests/test_iwiki_hooks.py`: an ingest record with a basename `page` under `docs/wiki/` → the source is covered.
- Old logs with basename `page` keep working (no migration).

## Notes

- The kill switch `IWIKI_AUTO_SYNC=0` silences the hook, but that is a workaround, not a fix.
- Current workaround applied in `mcp-ai-wiki`: an extra ingest record with `page=docs/wiki/installation.md` was appended — this heals only that one page, not the root cause.
- The bug is cross-repo: the reader fix lives in `iclaude` (hook) and `ai-wiki-plugin` (engine); the producer fix lives in `ai-wiki-plugin` (skill).
