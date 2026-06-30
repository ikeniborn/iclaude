---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-06-30-iwiki-content-hash-freshness-port-design.md
review:
  plan_hash: af6f9cb06d18e442
  spec_hash: 46590f57fe2de22d
  last_run: 2026-06-30
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  section_hashes:
    "Global Constraints": cd0c2ab82149be39
    "Task 1: Engine lint — content-hash staleness": feffbf1d93b4b76c
    "Task 2: Stop-hook — content-hash coverage": 9d143b4eba381e12
    "Task 3: Skills — write `src_hash` into the ingest log": aa83a99dbad27ea1
    "Task 4: Full-suite verification": f77a4b2f2a23520e
    "Notes for the executor": a8f99912e0d5c75c
  findings: []
---

# iwiki Content-Hash Freshness Port — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port content-addressed staleness detection (a `src_hash` log field + a hash-with-mtime-fallback freshness test) from the standalone `ai-wiki-plugin` into `iclaude/plugin/iwiki`, replacing the mtime-only staleness check.

**Architecture:** Ingest/init skills record `sha256(source)[:16]` as `src_hash` in `docs/wiki/.iwiki/log.jsonl`. Two consumers — the engine lint (`_stale`) and the Stop-hook (`covered_sources`) — decide freshness via a shared predicate `_fresh(src, page, src_hash)`: compare by content hash when the record carries `src_hash` and the source is readable, else fall back to the existing `mtime(page) >= mtime(source)`. The predicate is implemented as exact mirrors in both files.

**Tech Stack:** Python 3.12, `uv`-managed engine project (`plugin/iwiki/engine`), pytest, Markdown SKILL docs.

## Global Constraints

- Scope is **`plugin/iwiki` only** — touch nothing outside it.
- `src_hash` = `sha256(source raw bytes).hexdigest()[:16]` (16 hex chars). Use this exact definition everywhere.
- `_fresh` in `engine/iwiki_engine/lint.py` and `hooks/iwiki_common.py` must be **exact mirrors** (same logic, same fallback).
- **Backward compatible:** records without `src_hash` keep the mtime path. No migration, no backfill.
- `covered_sources` stays the exact inverse of `lint._stale`.
- **Keep iclaude-specific code/text unchanged:** the `plugin/iwiki/engine` engine-path candidates in `hooks/iwiki_common.py` and every `SKILL.md`; the `.claude_config` wording in `config.py`; the `lib/iwiki` / "iclaude" references in docstrings and skill prose. Do **not** port the standalone's path/text de-specializations, version bump, or `marketplace.json`.
- Source of every ported block: `/home/ikeniborn/Documents/Project/ai-wiki-plugin` (v0.6.5).
- Already on branch `dev-iwiki-content-hash` (based on `origin/dev`). Commit each task; do not push (push only on explicit user request).
- Commit footer on every commit: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

### Task 1: Engine lint — content-hash staleness

**Files:**
- Modify: `plugin/iwiki/engine/iwiki_engine/lint.py`
- Test: `plugin/iwiki/engine/tests/test_lint.py`

**Interfaces:**
- Produces: `_src_hash(src: str) -> str | None`, `_fresh(src: str, page: str, src_hash: str | None) -> bool` (module-level in `lint.py`). `_stale` now reports a page iff `not _fresh(...)`.
- Consumes: nothing from other tasks.

Run all commands from the repo root `/home/ikeniborn/Documents/Project/iclaude`. The engine test command is:
`uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/<file> -v`

- [ ] **Step 1: Add the failing tests**

Append to `plugin/iwiki/engine/tests/test_lint.py`, and add `import hashlib` to the top of that file (it currently starts with `import json` / `import os`):

```python
import hashlib  # add to the existing import block at the top of the file
```

Append at the end of the file:

```python
def _h(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def _wiki_with_log(tmp_path, page_body, src_body, src_hash=None):
    """Wiki dir with one page, one source file, and a single ingest log record
    (absolute paths). Returns (wiki_dir, src_path, page_path)."""
    wd = tmp_path / "wiki"
    wd.mkdir()
    page = wd / "a.md"
    page.write_text(page_body, encoding="utf-8")
    src = tmp_path / "a.py"
    src.write_text(src_body, encoding="utf-8")
    iwiki = wd / ".iwiki"
    iwiki.mkdir()
    rec = {"op": "ingest", "source": str(src), "page": str(page)}
    if src_hash is not None:
        rec["src_hash"] = src_hash
    (iwiki / "log.jsonl").write_text(json.dumps(rec) + "\n", encoding="utf-8")
    return str(wd), str(src), str(page)


def test_stale_hash_match_overrides_older_page_mtime(tmp_path):
    # The cure case: page mtime OLDER than source, but src_hash matches the
    # current source → NOT stale (kills git-reset / same-day false positives).
    wd, src, page = _wiki_with_log(
        tmp_path, "## A\nbody\n", "print('x')\n", src_hash=_h("print('x')\n"))
    os.utime(src, (2000, 2000))
    os.utime(page, (1000, 1000))
    assert lint(wd)["stale"] == []


def test_stale_hash_mismatch_is_stale_even_if_page_newer(tmp_path):
    # Hash recorded for OLD content; source now differs → stale regardless of mtime.
    wd, src, page = _wiki_with_log(
        tmp_path, "## A\nbody\n", "new content\n", src_hash=_h("old content\n"))
    os.utime(src, (1000, 1000))
    os.utime(page, (2000, 2000))
    assert any(s["source"] == src for s in lint(wd)["stale"])


def test_stale_without_hash_uses_mtime(tmp_path):
    # No src_hash in the record → unchanged mtime behaviour.
    wd, src, page = _wiki_with_log(tmp_path, "## A\nbody\n", "x\n")
    os.utime(src, (2000, 2000))
    os.utime(page, (1000, 1000))
    assert any(s["source"] == src for s in lint(wd)["stale"])
    os.utime(page, (3000, 3000))
    assert lint(wd)["stale"] == []


def test_stale_hash_present_but_unreadable_falls_back_to_mtime(tmp_path, monkeypatch):
    # src_hash present but source unreadable (_src_hash → None) → mtime path.
    import iwiki_engine.lint as lintmod
    wd, src, page = _wiki_with_log(
        tmp_path, "## A\nbody\n", "x\n", src_hash="deadbeefdeadbeef")
    monkeypatch.setattr(lintmod, "_src_hash", lambda p: None)
    os.utime(src, (2000, 2000))
    os.utime(page, (1000, 1000))
    assert any(s["source"] == src for s in lint(wd)["stale"])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_lint.py -v`
Expected: FAIL. `test_stale_hash_match_overrides_older_page_mtime` fails (mtime-only `_stale` still flags it), and `test_stale_hash_present_but_unreadable_falls_back_to_mtime` errors at `monkeypatch.setattr(lintmod, "_src_hash", ...)` because `_src_hash` does not exist yet.

- [ ] **Step 3: Add `import hashlib` to lint.py**

In `plugin/iwiki/engine/iwiki_engine/lint.py`, the import block is `import glob` / `import json` / `import os` / `import re`. Add `import hashlib` right after `import glob`:

```python
import glob
import hashlib
import json
import os
import re
```

- [ ] **Step 4: Add the `_src_hash` and `_fresh` helpers**

Insert these two functions immediately **before** `def _stale(wiki_dir: str) -> list[dict]:`:

```python
def _src_hash(src: str) -> str | None:
    """sha256 of the source's raw bytes, first 16 hex chars. None when the file
    cannot be read — the caller then falls back to the mtime comparison."""
    try:
        with open(src, "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()[:16]
    except OSError:
        return None


def _fresh(src: str, page: str, src_hash: str | None) -> bool:
    """Is `page` current for `src`? Content-addressed when the log record
    carries `src_hash` and the source is readable; otherwise the page is fresh
    iff it is at least as new as the source by mtime (the prior behaviour)."""
    if src_hash:
        cur = _src_hash(src)
        if cur is not None:
            return cur == src_hash
    return os.path.getmtime(page) >= os.path.getmtime(src)
```

- [ ] **Step 5: Update `_stale` to use `_fresh`**

In `_stale`, update the docstring and the comparison. Change the docstring line:

```python
    """Pages whose source changed after the last ingest, via .iwiki/log.jsonl
    (content-hash with mtime fallback; no git). Deduped by page, first hit wins."""
```

And change the comparison inside the `try:` block from:

```python
                if os.path.getmtime(src) > os.path.getmtime(page):
```

to:

```python
                if not _fresh(src, page, rec.get("src_hash")):
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_lint.py -v`
Expected: PASS — all existing lint tests plus the 4 new ones.

- [ ] **Step 7: Commit**

```bash
git add plugin/iwiki/engine/iwiki_engine/lint.py plugin/iwiki/engine/tests/test_lint.py
git commit -m "feat(iwiki): content-hash staleness in engine lint

Record-driven src_hash freshness with mtime fallback, replacing the
mtime-only _stale check. Backward compatible: records without src_hash
keep the prior behaviour.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Stop-hook — content-hash coverage

**Files:**
- Modify: `plugin/iwiki/hooks/iwiki_common.py`
- Test: `plugin/iwiki/engine/tests/test_iwiki_common.py`

**Interfaces:**
- Consumes: the `_fresh` semantics defined in Task 1 (mirrored here, not imported).
- Produces: `_src_hash`, `_fresh`, `_ingest_records()` (generator yielding well-formed log records oldest-first) in `iwiki_common.py`. `source_page_map()` and `covered_sources()` keep their existing signatures and now read via `_ingest_records()` and `_fresh`.

`hashlib` is already imported in `iwiki_common.py` — do not add it there. The hook tests live in the engine test suite and `import iwiki_common`.

- [ ] **Step 1: Add the failing tests**

In `plugin/iwiki/engine/tests/test_iwiki_common.py`, add `import hashlib` to the top import block (the file currently starts with `import contextlib` / `import io` / `import json as _json` / `import os` / `import sys`). The helpers `_setup_wiki(tmp_path, monkeypatch)` and `_write_log(log, records)` already exist in this file. Append at the end:

```python
def test_covered_sources_hash_match_overrides_mtime(tmp_path, monkeypatch):
    # Cure case mirror of the engine test: page OLDER by mtime but hash matches
    # → still covered.
    log = _setup_wiki(tmp_path, monkeypatch)
    (tmp_path / "a.py").write_text("x", encoding="utf-8")
    (tmp_path / "docs" / "wiki" / "a.md").write_text("y", encoding="utf-8")
    h = hashlib.sha256(b"x").hexdigest()[:16]
    _write_log(log, [
        {"op": "ingest", "source": "a.py", "page": "docs/wiki/a.md", "src_hash": h}])
    os.utime("a.py", (3000, 3000))
    os.utime("docs/wiki/a.md", (1000, 1000))
    assert iwiki_common.covered_sources() == {"a.py"}


def test_covered_sources_hash_mismatch_not_covered(tmp_path, monkeypatch):
    # Page NEWER by mtime but hash differs → not covered.
    log = _setup_wiki(tmp_path, monkeypatch)
    (tmp_path / "a.py").write_text("x", encoding="utf-8")
    (tmp_path / "docs" / "wiki" / "a.md").write_text("y", encoding="utf-8")
    _write_log(log, [
        {"op": "ingest", "source": "a.py", "page": "docs/wiki/a.md",
         "src_hash": "0000000000000000"}])
    os.utime("a.py", (1000, 1000))
    os.utime("docs/wiki/a.md", (2000, 2000))
    assert iwiki_common.covered_sources() == set()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_iwiki_common.py -v`
Expected: FAIL. `test_covered_sources_hash_match_overrides_mtime` fails (mtime-only `covered_sources` does not mark the older page covered) and `test_covered_sources_hash_mismatch_not_covered` fails (mtime-only marks the newer page covered).

- [ ] **Step 3: Replace `source_page_map` and `covered_sources`**

In `plugin/iwiki/hooks/iwiki_common.py`, replace the entire existing `source_page_map` function **and** the existing `covered_sources` function (they are adjacent) with the following. Add the three new helpers above them. Note `json.loads` (matching this file's existing `import json`), and that the `plugin/iwiki/engine` path resolution elsewhere in the file is **not** touched.

Replace this exact block:

```python
def source_page_map() -> dict[str, str]:
    """Map each source → its most recent wiki page from the ingest log
    (docs/wiki/.iwiki/log.jsonl). Last record wins per source. Same record
    predicate as the engine's lint._stale: any record carrying both `source`
    and `page` counts (no `op` filter). Fail-soft → {}."""
    out: dict[str, str] = {}
    try:
        with open(LOG_REL, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except Exception:
        return out
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
            if not isinstance(rec, dict):
                continue
        except Exception:
            continue
        src, page = rec.get("source"), rec.get("page")
        if src and page:
            out[src] = page          # last record wins
    return out


def covered_sources() -> set[str]:
    """Sources already covered by a fresh wiki page: the source's most recent
    page (per source_page_map) exists on disk and is at least as new as the
    source. The freshness test mtime(page) >= mtime(source) is the exact
    inverse of lint._stale, so for any (source, page) pair this calls "covered"
    exactly the pairs lint would not call stale. Fail-soft → empty set (subtract
    nothing → safe over-nag, bounded by MAX_ASK)."""
    covered: set[str] = set()
    for src, page in source_page_map().items():
        try:
            if os.path.isfile(src) and os.path.isfile(page) \
                    and os.path.getmtime(page) >= os.path.getmtime(src):
                covered.add(src)
        except Exception:
            continue
    return covered
```

with this:

```python
def _src_hash(src: str) -> str | None:
    """sha256 of the source's raw bytes, first 16 hex chars; None if unreadable.
    Mirror of engine lint._src_hash."""
    try:
        with open(src, "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()[:16]
    except OSError:
        return None


def _fresh(src: str, page: str, src_hash: str | None) -> bool:
    """Is `page` current for `src`? Content-addressed when the record carries
    `src_hash` and the source is readable; else mtime (page >= source). The
    exact mirror of engine lint._fresh."""
    if src_hash:
        cur = _src_hash(src)
        if cur is not None:
            return cur == src_hash
    return os.path.getmtime(page) >= os.path.getmtime(src)


def _ingest_records():
    """Yield each well-formed log record (a dict carrying both `source` and
    `page`) from docs/wiki/.iwiki/log.jsonl, oldest first. Fail-soft → nothing."""
    try:
        with open(LOG_REL, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except Exception:
        return
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
            if not isinstance(rec, dict):
                continue
        except Exception:
            continue
        if rec.get("source") and rec.get("page"):
            yield rec


def source_page_map() -> dict[str, str]:
    """Map each source → its most recent wiki page from the ingest log
    (docs/wiki/.iwiki/log.jsonl). Last record wins per source. A record counts
    when it carries both `source` and `page`. Fail-soft → {}."""
    out: dict[str, str] = {}
    for rec in _ingest_records():
        out[rec["source"]] = rec["page"]          # last record wins
    return out


def covered_sources() -> set[str]:
    """Sources already covered by a fresh wiki page: the source's most recent
    log record names a page that exists on disk and is fresh for the source
    (hash match when the record has `src_hash`, else page mtime >= source).
    The freshness test is the exact inverse of lint._stale. Fail-soft → empty
    set (subtract nothing → safe over-nag, bounded by MAX_ASK)."""
    latest: dict[str, dict] = {}
    for rec in _ingest_records():
        latest[rec["source"]] = rec               # last record wins
    covered: set[str] = set()
    for src, rec in latest.items():
        page = rec["page"]
        try:
            if os.path.isfile(src) and os.path.isfile(page) \
                    and _fresh(src, page, rec.get("src_hash")):
                covered.add(src)
        except Exception:
            continue
    return covered
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_iwiki_common.py -v`
Expected: PASS — all existing hook tests plus the 2 new ones.

- [ ] **Step 5: Commit**

```bash
git add plugin/iwiki/hooks/iwiki_common.py plugin/iwiki/engine/tests/test_iwiki_common.py
git commit -m "feat(iwiki): content-hash coverage in Stop-hook

Mirror the engine's src_hash/_fresh freshness in covered_sources via a
shared _ingest_records reader. Keeps the plugin/iwiki/engine path
resolution and iclaude docstrings unchanged.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Skills — write `src_hash` into the ingest log

**Files:**
- Modify: `plugin/iwiki/skills/iwiki-ingest/SKILL.md`
- Modify: `plugin/iwiki/skills/iwiki-init/SKILL.md`

**Interfaces:**
- Produces the `src_hash` field that Task 1/Task 2 consume. No code, no test; verified by `grep`. Do **not** touch the `ENG="plugin/iwiki/engine"` fallback lines or any "iclaude" wording in these files.

- [ ] **Step 1: Update the iwiki-ingest log step**

In `plugin/iwiki/skills/iwiki-ingest/SKILL.md`, replace this exact block (step 5):

````markdown
   ```bash
   printf '{"op":"ingest","source":"<src>","page":"<page>","date":"<YYYY-MM-DD>"}\n' \
     >> docs/wiki/.iwiki/log.jsonl
   ```
   Canonical log record: `{op, source, page, date}` (`note` optional). Use exactly
   these keys — `lint`'s stale check reads `source`/`page` and ignores records
   missing them. Do not introduce alternative keys (e.g. `scope`).
````

with:

````markdown
   ```bash
   printf '{"op":"ingest","source":"<src>","page":"<page>","date":"<YYYY-MM-DD>","src_hash":"%s"}\n' \
     "$(sha256sum '<src>' | cut -c1-16)" \
     >> docs/wiki/.iwiki/log.jsonl
   ```
   Substitute `<src>` (same path in both the `source` field and the `sha256sum`
   argument), `<page>`, and `<YYYY-MM-DD>` literally; `src_hash` is filled by the
   shell. Canonical log record: `{op, source, page, date, src_hash}` (`note`
   optional). `src_hash` is the sha256 of the source's raw bytes, first 16 hex
   chars — `lint`'s stale check prefers it over mtime. Use exactly these keys;
   do not introduce alternatives (e.g. `scope`).
````

- [ ] **Step 2: Update the iwiki-init log step**

In `plugin/iwiki/skills/iwiki-init/SKILL.md`, replace this exact block (step 5):

````markdown
   ```bash
   printf '{"op":"init","source":"<src>","page":"<page>","date":"<YYYY-MM-DD>"}\n' \
     >> docs/wiki/.iwiki/log.jsonl
   ```
   Canonical log record: `{op, source, page, date}` (`note` optional). Use exactly
   these keys — `lint`'s stale check reads `source`/`page` and ignores records
   missing them. Do not introduce alternative keys (e.g. `scope`).
````

with:

````markdown
   ```bash
   printf '{"op":"init","source":"<src>","page":"<page>","date":"<YYYY-MM-DD>","src_hash":"%s"}\n' \
     "$(sha256sum '<src>' | cut -c1-16)" \
     >> docs/wiki/.iwiki/log.jsonl
   ```
   Substitute `<src>` (same path in both the `source` field and the `sha256sum`
   argument), `<page>`, and `<YYYY-MM-DD>` literally; `src_hash` is filled by the
   shell. Canonical log record: `{op, source, page, date, src_hash}` (`note`
   optional). `src_hash` is the sha256 of the source's raw bytes, first 16 hex
   chars — `lint`'s stale check prefers it over mtime. Use exactly these keys;
   do not introduce alternatives (e.g. `scope`).
````

- [ ] **Step 3: Verify the edits landed and nothing else moved**

```bash
grep -n 'src_hash' plugin/iwiki/skills/iwiki-ingest/SKILL.md plugin/iwiki/skills/iwiki-init/SKILL.md
grep -n 'ENG="plugin/iwiki/engine"' plugin/iwiki/skills/iwiki-ingest/SKILL.md plugin/iwiki/skills/iwiki-init/SKILL.md
```
Expected: first grep shows the new `src_hash` printf + note lines in both files; second grep still shows the `plugin/iwiki/engine` fallback intact in both.

- [ ] **Step 4: Commit**

```bash
git add plugin/iwiki/skills/iwiki-ingest/SKILL.md plugin/iwiki/skills/iwiki-init/SKILL.md
git commit -m "docs(iwiki): record src_hash in ingest/init log steps

ingest and init skills now append src_hash (sha256[:16]) to log.jsonl so
lint and the Stop-hook can compare by content hash. Engine-path fallbacks
and iclaude references unchanged.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Full-suite verification

**Files:** none modified — verification only.

- [ ] **Step 1: Run the full engine test suite**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests -q`
Expected: all tests pass, including the 6 new ones (4 in `test_lint.py`, 2 in `test_iwiki_common.py`).

- [ ] **Step 2: Guard against class-2 regressions**

```bash
grep -rn 'plugin/iwiki/engine' plugin/iwiki/hooks/iwiki_common.py plugin/iwiki/skills/*/SKILL.md
grep -rn 'src_hash' plugin/iwiki/engine/iwiki_engine/lint.py plugin/iwiki/hooks/iwiki_common.py plugin/iwiki/skills/iwiki-ingest/SKILL.md plugin/iwiki/skills/iwiki-init/SKILL.md
grep -n '.claude_config' plugin/iwiki/engine/iwiki_engine/config.py
```
Expected: first grep — `plugin/iwiki/engine` still present in the hook and all skills (not regressed to `engine`); second grep — `src_hash` present in lint, hook, and both skills; third grep — `.claude_config` wording still in `config.py`.

---

## Notes for the executor

- The `<src>`/`<page>`/`<YYYY-MM-DD>` tokens inside the SKILL.md `printf` blocks are intentional placeholders in the *runtime* skill instructions — leave them literal; they are not plan placeholders.
- After all tasks, the chain advances via `check-plan` (IDD gate). Expect a `/check-plan` run on this plan before execution proceeds, mirroring how `/check-spec` gated the spec.
- **Post-merge (outside this plan's `plugin/iwiki`-only scope):** the iclaude "Keep Docs Current" policy applies because engine/hook behaviour changed. After merge, refresh `docs/wiki/` via the `iwiki:iwiki-ingest` skill for `plugin/iwiki/engine/iwiki_engine/lint.py` and `plugin/iwiki/hooks/iwiki_common.py`, then run `iwiki:iwiki-lint`. Tracked separately from this spec's scope.
