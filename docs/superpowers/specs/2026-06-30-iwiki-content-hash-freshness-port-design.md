---
chain:
  intent: null
review:
  spec_hash: 46590f57fe2de22d
  last_run: 2026-06-30
  phases:
    structure:   { status: passed }
    coverage:    { status: passed }
    clarity:     { status: passed }
    consistency: { status: passed }
  section_hashes:
    Problem: da7fa7e0a6482f57
    "What ports (and only this)": e1eb8c824cfc7b1a
    "Feature design": 1cbbf81723eeefda
    "Log record": ad2840cfd8d88d71
    "Freshness predicate (the invariant)": f1eeb1bd98d8fc33
    "Backward / forward compatibility": a06261362c60f8b7
    "Files changed": c990d93165d86ffa
    "Explicitly NOT touched": 15781caf25f6856a
    Verification: 30020994ef252c69
    "Behavioural checks (covered by the new tests)": e084cb43817d7495
    "Out of scope": e5ffaad14cd7eece
    "Workflow note": 835cab1ea0494981
  findings: []
---

# Port content-hash freshness from `ai-wiki-plugin` into `plugin/iwiki`

**Date:** 2026-06-30
**Status:** approved (design)
**Scope:** `plugin/iwiki` only
**Source of the enhancement:** `/home/ikeniborn/Documents/Project/ai-wiki-plugin` (standalone repo, v0.6.5). "Copy from standalone" below means copying the file from this path into the matching `plugin/iwiki/...` path.

## Problem

The standalone `ai-wiki-plugin` repo received an enhancement that the bundled
`iclaude/plugin/iwiki` copy lacks: **content-addressed staleness detection**.

Today, "is this wiki page stale for its source?" is decided purely by mtime:
`mtime(page) >= mtime(source)` means fresh. mtime is an unreliable proxy — it
produces false staleness on `git reset`/`git checkout`, same-day edits, and file
copies, where the byte content is unchanged but the timestamp moved. This drives
spurious lint "stale" reports and spurious Stop-hook nags.

The enhancement records a content hash of each source at ingest time and compares
by hash, falling back to mtime only when the hash is absent or the source is
unreadable.

## What ports (and only this)

A diff of the two trees surfaces three classes of difference. **Only class 1 is
in scope.**

1. **Content-hash freshness feature** — the genuine enhancement. PORT.
2. **Standalone de-specialization** — engine path `plugin/iwiki/engine` → `engine`,
   removal of `.claude_config` / `lib/iwiki/detect.sh` / "iclaude" references,
   `test_chunk.py` sample text. These adapt the plugin to live at a repo root and
   are WRONG for iclaude (where the engine genuinely lives at `plugin/iwiki/engine`
   and the iclaude references are correct). DO NOT PORT.
3. **Distribution metadata** — `plugin.json` version bump + homepage/repository
   URLs, new `marketplace.json`. Standalone-repo packaging, not wanted in iclaude.
   DO NOT PORT. (No version bump.)

## Feature design

### Log record

`docs/wiki/.iwiki/log.jsonl` ingest/init records gain one optional key:

```
{"op":"ingest","source":"<src>","page":"<page>","date":"<YYYY-MM-DD>","src_hash":"<16 hex>"}
```

`src_hash` = `sha256(raw source bytes).hexdigest()[:16]`. The key is **optional**:
records written before this change (no `src_hash`) keep working via the mtime path.
No migration, no backfill.

### Freshness predicate (the invariant)

Two call sites — the engine lint and the hook — must share one freshness rule,
implemented as **exact mirrors**:

```python
def _src_hash(src):
    # sha256 of source raw bytes, first 16 hex chars; None if unreadable.
    try:
        with open(src, "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()[:16]
    except OSError:
        return None

def _fresh(src, page, src_hash):
    # Content-addressed when the record carries src_hash AND the source is
    # readable; otherwise mtime (page >= source).
    if src_hash:
        cur = _src_hash(src)
        if cur is not None:
            return cur == src_hash
    return os.path.getmtime(page) >= os.path.getmtime(src)
```

- `lint._stale` reports a page stale iff `not _fresh(...)`.
- `iwiki_common.covered_sources` calls a source covered iff `_fresh(...)` —
  the exact inverse of `_stale`, preserved.

### Backward / forward compatibility

- Old records (no `src_hash`) → mtime path → identical to current behaviour.
- Unreadable source despite a recorded `src_hash` → `_src_hash` returns `None` →
  mtime path. Never crashes; helpers stay fail-soft.

## Files changed

Approach: **hybrid**. Files whose only divergence from standalone is the feature
are copied wholesale (zero transcription risk); files where the feature is
interleaved with class-2 de-specialization get surgical edits that take the
feature and leave iclaude's paths/text intact.

| File | Method | Change |
|---|---|---|
| `engine/iwiki_engine/lint.py` | copy from standalone | add `_src_hash`, `_fresh`; `_stale` uses `_fresh` |
| `engine/tests/test_lint.py` | copy from standalone | `import hashlib` + 4 new tests |
| `engine/tests/test_iwiki_common.py` | copy from standalone | `import hashlib` + 2 new tests |
| `hooks/iwiki_common.py` | surgical edit | add `_src_hash`, `_fresh`, `_ingest_records`; refactor `source_page_map` + `covered_sources` to use them. **Keep** the existing docstring (lib/iwiki, iclaude layout) and the `plugin/iwiki/engine` engine-path candidate |
| `skills/iwiki-ingest/SKILL.md` | surgical edit | step-5 log block writes `src_hash` via `sha256sum '<src>' \| cut -c1-16`; updated canonical-record note. **Keep** `ENG="plugin/iwiki/engine"` fallback and the "not just iclaude" wording |
| `skills/iwiki-init/SKILL.md` | surgical edit | same step-5 log block + note. **Keep** `ENG="plugin/iwiki/engine"` fallback |

`hashlib` is already imported in `hooks/iwiki_common.py` — no new import there.
The three copied files carry their own `import hashlib`.

### Explicitly NOT touched

- `engine/iwiki_engine/config.py` (keep `.claude_config` wording)
- `engine/tests/test_chunk.py` (keep iclaude sample text)
- `hooks/iwiki_common.py` docstring + `_engine_project` candidate paths
- `skills/*` engine-path fallbacks and iclaude references
- `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
- `README.md`

## Verification

1. `uv run --project plugin/iwiki/engine pytest` — full suite green, including the
   6 new tests (4 in `test_lint.py`, 2 in `test_iwiki_common.py`).
2. `grep -n 'plugin/iwiki/engine' plugin/iwiki/hooks/iwiki_common.py plugin/iwiki/skills/*/SKILL.md`
   — confirms class-2 paths were NOT regressed to `engine`.
3. `grep -rn 'src_hash' plugin/iwiki` — confirms feature landed in lint, hook, and
   both ingest/init skills.

### Behavioural checks (covered by the new tests)

- hash match with page mtime OLDER than source → fresh / not stale / covered
  (the cure case for git-reset and same-day edits).
- hash mismatch with page mtime NEWER than source → stale / not covered.
- no `src_hash` in record → unchanged mtime behaviour.
- `src_hash` present but source unreadable → mtime fallback.

## Out of scope

- `lib/iwiki` (only `detect.sh` + `install.sh`; no engine copy).
- Any change outside `plugin/iwiki`.
- Plugin version bump and marketplace/distribution metadata.

## Workflow note

iclaude carries a long-lived `dev` branch beyond `master`. Per project rules, the
work branch base (`dev` vs `master`), the PR target, and whether to use a
`wk-dev-*` worktree are user decisions to be confirmed at implementation kickoff,
not assumed here.
