---
result_check:
  verdict: OK
  plan_hash: c8956000c445c61c
  last_run: 2026-06-24
review:
  plan_hash: c8956000c445c61c
  spec_hash: 85e3c417218e5f1f
  last_run: 2026-06-24
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - id: F-001
      phase: consistency
      severity: INFO
      section: "Task 2: source_page_map() + covered_sources() helpers"
      section_hash: c969661246b63b11
      text: >-
        covered_sources() factors the spec's section-A inline add/discard
        pseudocode into source_page_map() (last-record-wins) + a single
        per-source mtime check. Behaviourally equivalent (both resolve to the
        most-recent page per source); the plan's factoring is the authoritative,
        DRYer version. No action.
      verdict: accepted
      verdict_at: 2026-06-24
chain:
  intent: null
  spec: docs/superpowers/specs/2026-06-24-iwiki-sync-nag-covered-design.md
---
# iwiki Stop-nag: clear on completion (covered_sources) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the iwiki `Stop` hook stop nagging once the changed sources are actually documented (a fresh wiki page exists), instead of nagging until the `MAX_ASK` budget runs out.

**Architecture:** All new *pure* logic lands in `plugin/iwiki/hooks/iwiki_common.py` (stdlib-only, directly unit-testable): a `source_page_map()` / `covered_sources()` pair that reuses the existing `docs/wiki/.iwiki/log.jsonl` provenance (same freshness threshold as the engine's `lint._stale`), a `render_pending_listing()` that groups the nag by target page, and a test-path exclusion in `is_documentable()`. `iwiki-sync.py` becomes thin glue: `_pending()` subtracts `covered_sources()`, and `main()` renders the grouped message. The engine is untouched; the log format is unchanged.

**Tech Stack:** Python 3.12 (stdlib only — no httpx in the hook path), pytest 8, git, `gh` CLI.

## Global Constraints

- **Hook scripts are stdlib-only.** `iwiki_common.py` must import nothing beyond the Python stdlib (no httpx / no engine package) — it is imported directly by the tests via a `sys.path` insert with no venv. New stdlib imports allowed: `re`.
- **Fail-soft everywhere.** Every new helper must return a safe empty value (`{}`, `set()`, `""`) on any exception. A documentation helper must never wedge a stop. The safe direction on doubt is *over-nag* (subtract nothing), bounded by `MAX_ASK`.
- **Surgical scope.** Touch only `plugin/iwiki/hooks/iwiki_common.py`, `plugin/iwiki/hooks/iwiki-sync.py`, the two version manifests, and the three test files named below. Do **not** modify the engine (`plugin/iwiki/engine/**`), the log format, or `decide_nag`/`MAX_ASK`.
- **Repo-relative paths.** Sources are repo-relative (git output, `cwd == project root` after `cd_project()`); the log's `source`/`page` values are repo-relative (the ingest skill runs from project root). Compare and `getmtime` on those repo-relative paths as-is.
- **Freshness threshold == lint.** `covered ⇔ mtime(page) ≥ mtime(source)`, the exact inverse of `lint._stale`'s `mtime(source) > mtime(page)`. Record predicate == lint: any log record carrying both `source` and `page` (no `op` filter).
- **Version bump:** `0.6.2 → 0.6.3` in both `plugin/iwiki/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (cached hooks are keyed by version; without the bump the live session keeps the old script).
- **Branch / PR:** branch `dev-fix-iwiki-sync-nag` (already created, off `dev`); PR against `dev`.
- **Run tests with:** `pytest <path> -v` (pytest on `PATH` at `/home/ikeniborn/.local/bin/pytest`).

---

### Task 1: Exclude test files from `is_documentable()`

iwiki generates no wiki page for test files, so a changed test can never become "covered" and nags forever. Make test paths non-documentable.

**Files:**
- Modify: `plugin/iwiki/hooks/iwiki_common.py` (add `import re`; add `_TEST_SEGMENTS`, `_TEST_BASENAME_RE`, `_is_test_path()`; one guard line in `is_documentable`)
- Test: `tests/test_iwiki_hooks.py` (extend the existing `is_documentable` test)

**Interfaces:**
- Produces: `is_documentable(p: str) -> bool` now returns `False` for test paths. New module-private `_is_test_path(p: str) -> bool`.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_iwiki_hooks.py`:

```python
def test_is_documentable_excludes_tests():
    # Test directories anywhere in the path.
    assert iw.is_documentable("tests/test_x.py") is False
    assert iw.is_documentable("tests/api/test_mcp_auth.py") is False
    assert iw.is_documentable("src/__tests__/foo.ts") is False
    assert iw.is_documentable("pkg/spec/thing.js") is False
    # Test-shaped basenames in any directory.
    assert iw.is_documentable("src/test_foo.py") is False
    assert iw.is_documentable("pkg/foo_test.py") is False
    assert iw.is_documentable("conftest.py") is False
    assert iw.is_documentable("ui/button.test.ts") is False
    assert iw.is_documentable("ui/button.spec.js") is False
    # Non-test sources stay documentable (no false exclusion).
    assert iw.is_documentable("src/paw/main.py") is True
    assert iw.is_documentable("lib/iwiki/detect.sh") is True
    assert iw.is_documentable("latest/release.py") is True   # 'latest' != 'test' segment
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_iwiki_hooks.py::test_is_documentable_excludes_tests -v`
Expected: FAIL — e.g. `assert iw.is_documentable("tests/test_x.py") is False` fails (currently returns `True`).

- [ ] **Step 3: Write minimal implementation**

In `plugin/iwiki/hooks/iwiki_common.py`, add `import re` to the import block (alphabetical, after `import os`/`import shutil` — keep the existing order, just insert `re`). Then add this near the other `EXCLUDE_*` constants (just below `EXCLUDE_ROOT_DOCS`):

```python
# Test files are never wiki source — iwiki generates no page for tests, so a
# changed test could never become "covered" and would nag forever.
_TEST_SEGMENTS = {"tests", "test", "__tests__", "spec"}
_TEST_BASENAME_RE = re.compile(
    r"^(conftest\.py|test_.*\.py|.*_test\.py|.*\.test\.[jt]s|.*\.spec\.[jt]s)$")


def _is_test_path(p: str) -> bool:
    """A repo-relative path that is a test file (test dir segment, or a
    conventional test basename) — never wiki source."""
    parts = p.split("/")
    if any(seg in _TEST_SEGMENTS for seg in parts[:-1]):   # any dir segment
        return True
    return bool(_TEST_BASENAME_RE.match(parts[-1]))
```

In `is_documentable()`, add the guard immediately before the final `return True` (after the root-meta-doc check):

```python
    if _is_test_path(p):
        return False
    return True
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_iwiki_hooks.py -v`
Expected: PASS — both `test_is_documentable_excludes_tests` and the pre-existing `test_is_documentable_excludes_instruction_and_meta_docs` green (no regression).

- [ ] **Step 5: Commit**

```bash
git add plugin/iwiki/hooks/iwiki_common.py tests/test_iwiki_hooks.py
git commit -m "feat(iwiki): exclude test files from documentable sources"
```

---

### Task 2: `source_page_map()` + `covered_sources()` helpers

Read the ingest log to learn which sources have an up-to-date page, reusing the exact provenance `lint._stale` uses.

**Files:**
- Modify: `plugin/iwiki/hooks/iwiki_common.py` (add `LOG_REL` constant; add `source_page_map()` and `covered_sources()`)
- Test: `plugin/iwiki/engine/tests/test_iwiki_common.py` (fs-based, mirrors the existing `tmp_path`/`monkeypatch` idiom in that file)

**Interfaces:**
- Consumes: `WIKI_DIR` constant (already defined as `"docs/wiki"`).
- Produces:
  - `source_page_map() -> dict[str, str]` — `{source: most_recent_page}` from the log, last-record-wins, any record with both `source` and `page`. Fail-soft `{}`.
  - `covered_sources() -> set[str]` — sources whose mapped page exists and `mtime(page) ≥ mtime(source)`. Fail-soft `set()`.

- [ ] **Step 1: Write the failing test**

Add to `plugin/iwiki/engine/tests/test_iwiki_common.py` (it already imports `iwiki_common` and uses `tmp_path`/`monkeypatch`):

```python
import json as _json


def _setup_wiki(tmp_path, monkeypatch):
    """A project tree with docs/wiki/.iwiki/log.jsonl; cwd set to it."""
    monkeypatch.chdir(tmp_path)
    log = tmp_path / "docs" / "wiki" / ".iwiki" / "log.jsonl"
    log.parent.mkdir(parents=True)
    return log


def _write_log(log, records):
    log.write_text(
        "".join(_json.dumps(r) + "\n" for r in records), encoding="utf-8")


def test_source_page_map_last_record_wins(tmp_path, monkeypatch):
    log = _setup_wiki(tmp_path, monkeypatch)
    _write_log(log, [
        {"op": "ingest", "source": "a.py", "page": "docs/wiki/old.md"},
        {"op": "ingest", "source": "a.py", "page": "docs/wiki/new.md"},
        {"source": "b.py", "page": "docs/wiki/b.md"},  # no "op" → still counts
        {"op": "ingest", "page": "docs/wiki/x.md"},     # no source → skipped
        {"op": "ingest", "source": "c.py"},             # no page → skipped
        "",                                             # blank line tolerated
    ])
    assert iwiki_common.source_page_map() == {
        "a.py": "docs/wiki/new.md", "b.py": "docs/wiki/b.md"}


def test_source_page_map_missing_or_corrupt_log(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    assert iwiki_common.source_page_map() == {}          # no log at all
    log = _setup_wiki(tmp_path, monkeypatch)
    log.write_text("{not json\n", encoding="utf-8")
    assert iwiki_common.source_page_map() == {}           # corrupt → {}


def test_covered_sources_freshness(tmp_path, monkeypatch):
    log = _setup_wiki(tmp_path, monkeypatch)
    src = tmp_path / "a.py"
    page = tmp_path / "docs" / "wiki" / "a.md"
    src.write_text("x", encoding="utf-8")
    page.write_text("y", encoding="utf-8")
    _write_log(log, [{"op": "ingest", "source": "a.py", "page": "docs/wiki/a.md"}])

    # page newer than source → covered
    os.utime("a.py", (1000, 1000))
    os.utime("docs/wiki/a.md", (2000, 2000))
    assert iwiki_common.covered_sources() == {"a.py"}

    # source edited after ingest (source newer) → not covered (re-staled)
    os.utime("a.py", (3000, 3000))
    assert iwiki_common.covered_sources() == set()


def test_covered_sources_missing_page_on_disk(tmp_path, monkeypatch):
    log = _setup_wiki(tmp_path, monkeypatch)
    (tmp_path / "a.py").write_text("x", encoding="utf-8")
    # log references a page that does not exist on disk
    _write_log(log, [{"op": "ingest", "source": "a.py", "page": "docs/wiki/gone.md"}])
    assert iwiki_common.covered_sources() == set()
```

(Add `import os` at the top of the file if not already present — it is.)

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest plugin/iwiki/engine/tests/test_iwiki_common.py -v -k "source_page_map or covered_sources"`
Expected: FAIL — `AttributeError: module 'iwiki_common' has no attribute 'source_page_map'`.

- [ ] **Step 3: Write minimal implementation**

In `plugin/iwiki/hooks/iwiki_common.py`, add the constant next to `INDEX_REL` (line ~25):

```python
LOG_REL = os.path.join(WIKI_DIR, ".iwiki", "log.jsonl")
```

Add these two functions after `committed_sources()`:

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

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest plugin/iwiki/engine/tests/test_iwiki_common.py -v`
Expected: PASS — all four new tests plus the pre-existing `read_session` tests green.

- [ ] **Step 5: Commit**

```bash
git add plugin/iwiki/hooks/iwiki_common.py plugin/iwiki/engine/tests/test_iwiki_common.py
git commit -m "feat(iwiki): covered_sources from ingest-log provenance (mirrors lint._stale)"
```

---

### Task 3: `render_pending_listing()` — group the nag by target page

N sources that map to one page should read as one action, not N items.

**Files:**
- Modify: `plugin/iwiki/hooks/iwiki_common.py` (add `render_pending_listing()`)
- Test: `tests/test_iwiki_hooks.py` (pure, no fs)

**Interfaces:**
- Produces: `render_pending_listing(pending: list[str], page_map: dict[str, str], cap: int = 12) -> str` — the indented multi-line nag body. Sources with a known page are grouped one line per page; sources with no page are one "new" line. `cap` bounds rendered lines with an `…and N more` tail.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_iwiki_hooks.py`:

```python
def test_render_pending_listing_groups_by_page():
    pending = ["src/mcp/tools.py", "src/mcp/server.py", "src/main.py", "src/new.py"]
    page_map = {
        "src/mcp/tools.py": "docs/wiki/mcp.md",
        "src/mcp/server.py": "docs/wiki/mcp.md",
        "src/main.py": "docs/wiki/main.md",
        # src/new.py: absent → "new, needs a page"
    }
    out = iw.render_pending_listing(pending, page_map)
    # 3 sources of mcp.md collapse to ONE line listing all three.
    assert ("  - docs/wiki/mcp.md is stale — re-run iwiki-ingest "
            "(covers: src/mcp/server.py, src/mcp/tools.py)") in out
    assert "docs/wiki/main.md is stale" in out
    assert "new, needs a wiki page — run iwiki-ingest: src/new.py" in out
    # One line per page (not one per source): mcp.md appears once.
    assert out.count("docs/wiki/mcp.md is stale") == 1


def test_render_pending_listing_caps_overflow():
    pending = [f"f{i}.py" for i in range(20)]   # 20 unpaged sources → 1 "new" line
    page_map = {}
    out = iw.render_pending_listing(pending, page_map, cap=12)
    # 20 unpaged sources are one "new" line, so no overflow here:
    assert "…and" not in out
    # But 20 distinct pages → 20 lines, capped at 12 + tail:
    many = {f"f{i}.py": f"docs/wiki/p{i}.md" for i in range(20)}
    out2 = iw.render_pending_listing([f"f{i}.py" for i in range(20)], many, cap=12)
    assert out2.count(" is stale") == 12
    assert "…and 8 more" in out2
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_iwiki_hooks.py -v -k render_pending_listing`
Expected: FAIL — `AttributeError: module 'iwiki_common' has no attribute 'render_pending_listing'`.

- [ ] **Step 3: Write minimal implementation**

Add to `plugin/iwiki/hooks/iwiki_common.py` (after `source_page_map`/`covered_sources`):

```python
def render_pending_listing(pending: list[str], page_map: dict[str, str],
                           cap: int = 12) -> str:
    """Render the Stop-nag body, grouping pending sources by their target wiki
    page so N sources of one page read as one action. Sources with a known page
    → one line per page; sources with no page yet → one 'new' line. At most
    `cap` lines, with an '…and N more' overflow tail."""
    by_page: dict[str, list[str]] = {}
    new: list[str] = []
    for p in pending:
        page = page_map.get(p)
        if page:
            by_page.setdefault(page, []).append(p)
        else:
            new.append(p)
    lines: list[str] = []
    for page in sorted(by_page):
        srcs = ", ".join(sorted(by_page[page]))
        lines.append(
            f"  - {page} is stale — re-run iwiki-ingest (covers: {srcs})")
    if new:
        lines.append("  - new, needs a wiki page — run iwiki-ingest: "
                     + ", ".join(sorted(new)))
    shown = lines[:cap]
    more = "" if len(lines) == len(shown) \
        else f"\n  …and {len(lines) - len(shown)} more"
    return "\n".join(shown) + more
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_iwiki_hooks.py -v`
Expected: PASS — both new `render_pending_listing` tests plus all pre-existing hook tests.

- [ ] **Step 5: Commit**

```bash
git add plugin/iwiki/hooks/iwiki_common.py tests/test_iwiki_hooks.py
git commit -m "feat(iwiki): page-grouped Stop-nag listing renderer"
```

---

### Task 4: Wire the helpers into `iwiki-sync.py`

`_pending()` subtracts `covered_sources()`; `main()` renders the grouped message.

**Files:**
- Modify: `plugin/iwiki/hooks/iwiki-sync.py:51-61` (`_pending`) and `:99-109` (the message block in `main`)
- Test: `tests/test_iwiki_hooks.py` (load the hyphenated module via importlib; stub `sync.iw.*`)

**Interfaces:**
- Consumes: `iw.covered_sources()`, `iw.source_page_map()`, `iw.render_pending_listing()` (Tasks 2–3).
- Produces: `_pending(sess: dict) -> list[str]` now excludes covered sources; `main()` emits a page-grouped block.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_iwiki_hooks.py` (top-level, after the existing imports add the importlib loader once):

```python
import importlib.util

_SYNC_PATH = os.path.join(os.path.dirname(__file__), "..",
                          "plugin", "iwiki", "hooks", "iwiki-sync.py")
_sync_spec = importlib.util.spec_from_file_location("iwiki_sync", _SYNC_PATH)
sync = importlib.util.module_from_spec(_sync_spec)
_sync_spec.loader.exec_module(sync)


def test_pending_subtracts_covered(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    for name in ("a.py", "b.py"):
        (tmp_path / name).write_text("x", encoding="utf-8")
    monkeypatch.setattr(sync.iw, "changed_sources", lambda: ["a.py", "b.py"])
    monkeypatch.setattr(sync.iw, "committed_sources", lambda since: [])
    monkeypatch.setattr(sync.iw, "covered_sources", lambda: {"a.py"})
    sess = {"wip": [], "head": "", "edits": []}
    # a.py is covered → only b.py remains pending
    assert sync._pending(sess) == ["b.py"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_iwiki_hooks.py::test_pending_subtracts_covered -v`
Expected: FAIL — current `_pending` returns `["a.py", "b.py"]` (no covered subtraction).

- [ ] **Step 3: Write minimal implementation**

Replace `_pending` (`plugin/iwiki/hooks/iwiki-sync.py:51-61`) with:

```python
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
```

Replace the message block (`plugin/iwiki/hooks/iwiki-sync.py:99-109`, from `shown = pending[:12]` through the end of the `reason = (...)` assignment) with:

```python
        listing = iw.render_pending_listing(pending, iw.source_page_map())
        reason = (
            "[iwiki] Source changed this turn — update the wiki before finishing "
            "(docs/wiki/ must stay current):\n" + listing + "\n"
            "Re-run the iwiki:iwiki-ingest skill for each stale page (or to create "
            "a missing one), then /iwiki-lint. Skip files with no documentable "
            "behaviour change (pure formatting/typos)."
        )
```

(The `print(json.dumps({"decision": "block", "reason": reason}))` line below it is unchanged.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_iwiki_hooks.py -v`
Expected: PASS — `test_pending_subtracts_covered` green, all prior hook tests still green.

- [ ] **Step 5: Smoke-check the module loads and `main()` is import-safe**

Run: `python3 -c "import importlib.util, os; s=importlib.util.spec_from_file_location('s','plugin/iwiki/hooks/iwiki-sync.py'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print('ok', hasattr(m,'_pending'), hasattr(m,'main'))"`
Expected: `ok True True`

- [ ] **Step 6: Commit**

```bash
git add plugin/iwiki/hooks/iwiki-sync.py tests/test_iwiki_hooks.py
git commit -m "feat(iwiki): Stop-nag subtracts covered sources + page-grouped message"
```

---

### Task 5: Bump the plugin version (cache resync)

Cached hook copies are keyed by version; without a bump the live session keeps the old `iwiki-sync.py`.

**Files:**
- Modify: `plugin/iwiki/.claude-plugin/plugin.json` (`"version": "0.6.2"` → `"0.6.3"`)
- Modify: `.claude-plugin/marketplace.json` (the iwiki entry `"version": "0.6.2"` → `"0.6.3"`)

- [ ] **Step 1: Edit both manifests**

Set the iwiki `version` to `0.6.3` in both files. (In `marketplace.json` the bump applies to the iwiki plugin entry — line ~10 per the current file.)

- [ ] **Step 2: Verify both parse and agree**

Run:
```bash
python3 -c "import json; a=json.load(open('plugin/iwiki/.claude-plugin/plugin.json'))['version']; print('plugin.json', a); assert a=='0.6.3'"
python3 -c "import json; m=json.load(open('.claude-plugin/marketplace.json')); vs=[p.get('version') for p in m.get('plugins',[]) if p.get('name')=='iwiki']; print('marketplace iwiki', vs); assert vs==['0.6.3'], vs"
```
Expected: `plugin.json 0.6.3` and `marketplace iwiki ['0.6.3']`, no AssertionError.

> If the marketplace JSON shape differs (e.g. the iwiki entry is keyed differently), adjust the one-liner to locate the iwiki entry — the deliverable is "both manifests read 0.6.3".

- [ ] **Step 3: Commit**

```bash
git add plugin/iwiki/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(iwiki): bump plugin to 0.6.3 (resync cached Stop hook)"
```

---

### Task 6: Full verification, docs refresh, and PR

**Files:**
- Test: all three test files; docs via iwiki (only if `docs/wiki/` documents the hooks)

- [ ] **Step 1: Run the whole hook/common test surface**

Run:
```bash
pytest tests/test_iwiki_hooks.py plugin/iwiki/engine/tests/test_iwiki_common.py -v
```
Expected: PASS — all tests, no failures, no errors.

- [ ] **Step 2: Engine regression (untouched, but confirm nothing broke via shared import)**

Run: `pytest plugin/iwiki/engine/tests/ -q`
Expected: PASS (engine code unchanged; this confirms the shared `iwiki_common` import still loads cleanly).

- [ ] **Step 3: Refresh the wiki page for the changed hooks (only if one exists)**

Check whether the hooks are documented:
```bash
ls docs/wiki/ 2>/dev/null && grep -rl "iwiki-sync\|iwiki_common\|Stop hook" docs/wiki/ 2>/dev/null || echo "no hook wiki page — skip"
```
- If a page is listed: invoke the `iwiki:iwiki-ingest` skill on `plugin/iwiki/hooks/iwiki-sync.py` (and `iwiki_common.py`) to regenerate it, then run `/iwiki-lint` and confirm clean (no broken refs / orphans).
- If `no hook wiki page — skip`: no doc change needed (record that in the PR body).

- [ ] **Step 4: Push and open the PR against `dev`**

```bash
git push -u origin dev-fix-iwiki-sync-nag
gh pr create --base dev --title "fix(iwiki): Stop-nag clears on completion, not on ask-budget" \
  --body "$(cat <<'BODY'
## Summary
The iwiki Stop hook nagged to update docs/wiki/ until the MAX_ASK budget ran
out, even after the wiki was current (ingested, committed, lint clean). Root
cause: `_pending` was change-driven only and never subtracted already-documented
sources.

## Changes
- `covered_sources()` / `source_page_map()` in `iwiki_common.py` reuse the
  existing `docs/wiki/.iwiki/log.jsonl` provenance (same freshness threshold as
  the engine's `lint._stale`); `_pending` subtracts covered sources, so the nag
  clears when the work is actually done.
- `is_documentable()` excludes test files (iwiki has no test pages → previously
  permanent false positives).
- Stop-nag message is grouped by target page (N sources of one page → one line).
- `MAX_ASK` retained as a wedge backstop; engine and log format untouched.
- Plugin bumped 0.6.2 → 0.6.3 to resync the cached hook.

Spec: docs/superpowers/specs/2026-06-24-iwiki-sync-nag-covered-design.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"
```
Expected: PR created against `dev`; note the PR URL.

> Per memory: pushing `dev`-family branches may auto-create a version-bump commit; the local branch can stay one commit ahead — do not force a re-push to "fix" that.

---

## Self-Review

**Spec coverage:**
- R1 root cause → Task 4 (`_pending` subtracts covered) + the spec doc. ✓
- R2 `covered_sources` (log + lint threshold) → Task 2. ✓
- R3 exclude tests → Task 1. ✓
- R4 `_pending` subtracts covered → Task 4. ✓
- R5 page-grouped message → Task 3 (+ wired in Task 4). ✓
- R6 keep MAX_ASK backstop → unchanged; explicitly not touched (Task 4 leaves `decide_nag`). ✓
- R7 surgical / engine untouched → Global Constraints + Task 6 step 2 confirms engine green. ✓
- R8 version bump → Task 5. ✓
- Success criteria (ingest → silent; tests don't nag; N→1; lint/hook agree; commit-evasion + wip intact) → covered by Tasks 1–4 tests; commit-evasion/wip regression guarded by the unchanged `_pending` set-math + the existing `decide_nag` tests.

**Placeholder scan:** No TBD/TODO; every code step shows complete code. The one conditional (Task 6 step 3 docs) has explicit both-branch instructions.

**Type consistency:** `covered_sources() -> set[str]`, `source_page_map() -> dict[str,str]`, `render_pending_listing(pending, page_map, cap=12) -> str`, `_is_test_path(p) -> bool` — names and signatures match across Tasks 1–4 and their call sites in `iwiki-sync.py`. `_pending(sess) -> list[str]` signature unchanged.
