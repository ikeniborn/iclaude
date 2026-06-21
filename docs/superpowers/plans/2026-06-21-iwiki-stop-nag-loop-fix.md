---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-06-21-iwiki-stop-nag-loop-design.md
review:
  plan_hash: 79af3d27e955691e
  spec_hash: 70806bbac29924e6
  last_run: 2026-06-21
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings: []
---
# iwiki Stop-hook nag loop fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the iwiki `iwiki-sync.py` (Stop hook) from nagging forever by excluding agent-instruction / root meta-doc files from the documentable set and replacing the unreliable `wiki_sig` reconcile with a pure, hard ask-count cap.

**Architecture:** Two pure functions are added to `plugin/iwiki/hooks/iwiki_common.py` and unit-tested: `is_documentable` gains basename/root exclusions, and a new `decide_nag(sess, sig, max_ask)` encapsulates the ask/yield decision with no wiki-state input. The Stop hook (`iwiki-sync.py`) is rewritten to call `decide_nag`; the now-orphaned `wiki_sig()` / `asked_wiki` are removed from `iwiki_common.py` and `iwiki-bootstrap.py`. Then the plugin version is bumped and the wiki page is updated + reindexed.

**Tech Stack:** Python 3 (stdlib only — `iwiki_common` has no `httpx` dependency), pytest, bash. Claude Code plugin hooks.

---

## File Structure

| File | Responsibility | Change |
|------|----------------|--------|
| `tests/test_iwiki_hooks.py` | Unit tests for the two pure helpers (`is_documentable`, `decide_nag`) | **Create** |
| `plugin/iwiki/hooks/iwiki_common.py` | Shared helpers: add exclude constants, extend `is_documentable`, add `decide_nag`, delete `wiki_sig`, drop `asked_wiki` default | **Modify** |
| `plugin/iwiki/hooks/iwiki-sync.py` | Stop hook: rewrite decision block to use `decide_nag`, drop `wsig`/`asked_wiki`, update docstrings | **Modify** |
| `plugin/iwiki/hooks/iwiki-bootstrap.py` | SessionStart hook: drop `asked_wiki` from the session-init dict | **Modify** |
| `plugin/iwiki/.claude-plugin/plugin.json` | Plugin manifest — version bump resyncs the in-cache hook copy | **Modify** |
| `docs/wiki/iwiki.md` | Wiki page "Automation Hooks" section — describe new behaviour | **Modify** |

---

## Task 1: `is_documentable` exclusions (TDD)

Add `EXCLUDE_BASENAMES` / `EXCLUDE_ROOT_DOCS` and extend `is_documentable` so agent-instruction files (any directory) and root-level meta-docs are never treated as wiki source. This is defect 1 from the spec.

**Files:**
- Create: `tests/test_iwiki_hooks.py`
- Modify: `plugin/iwiki/hooks/iwiki_common.py:37` (constants near `SOURCE_EXTS`) and `plugin/iwiki/hooks/iwiki_common.py:142-151` (`is_documentable`)

- [ ] **Step 1: Write the failing test**

Create `tests/test_iwiki_hooks.py`:

```python
"""Unit tests for the pure helpers in the iwiki Stop/Sync hooks.

iwiki_common is stdlib-only (no httpx), so it imports cleanly via a sys.path
insert of the plugin hooks dir — no engine venv needed.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..",
                                "plugin", "iwiki", "hooks"))
import iwiki_common as iw  # noqa: E402


def test_is_documentable_excludes_instruction_and_meta_docs():
    # Agent-instruction basenames are excluded in ANY directory.
    assert iw.is_documentable("CLAUDE.md") is False
    assert iw.is_documentable("AGENTS.md") is False
    assert iw.is_documentable("GEMINI.md") is False
    assert iw.is_documentable("subdir/CLAUDE.md") is False
    # Root meta-docs are excluded only at the repo root.
    assert iw.is_documentable("README.md") is False
    # A subdir README.md may still document a component → kept.
    assert iw.is_documentable("docs/README.md") is True
    # Ordinary source stays documentable.
    assert iw.is_documentable("lib/foo.sh") is True
    assert iw.is_documentable("iclaude.sh") is True
    # Pre-existing prefix excludes still hold.
    assert iw.is_documentable("docs/wiki/x.md") is False
    assert iw.is_documentable("commands/y.md") is False
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_iwiki_hooks.py::test_is_documentable_excludes_instruction_and_meta_docs -v`
Expected: FAIL — `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` / `subdir/CLAUDE.md` / `README.md` currently return `True` (a `.md` not under an excluded prefix), so the first assertion fails.

- [ ] **Step 3: Add the exclude constants**

In `plugin/iwiki/hooks/iwiki_common.py`, immediately after the `SOURCE_EXTS` line (currently line 37):

```python
SOURCE_EXTS = (".sh", ".py", ".js", ".ts", ".md")

# Agent-instruction files are never wiki source — excluded in ANY directory.
EXCLUDE_BASENAMES = ("CLAUDE.md", "AGENTS.md", "GEMINI.md")
# Project meta-docs are not wiki source at the repo ROOT (a subdir README.md may
# still document a component, so it stays documentable).
EXCLUDE_ROOT_DOCS = ("README.md", "CHANGELOG.md", "CONTRIBUTING.md", "LICENSE.md")
```

- [ ] **Step 4: Extend `is_documentable`**

Replace the body of `is_documentable` (currently lines 142-151) so the basename checks run after the existing prefix/substr checks, and update the docstring (closes finding F-001):

```python
def is_documentable(p: str) -> bool:
    """A repo-relative path that the wiki should describe: a source ext, outside
    the wiki/IDD/command/VCS noise, and not an agent-instruction file (any dir)
    or a repo-root meta-doc. Existence is checked separately by callers."""
    if not p.endswith(SOURCE_EXTS):
        return False
    if p.startswith(EXCLUDE_PREFIXES):
        return False
    if any(s in p for s in EXCLUDE_SUBSTR):
        return False
    base = os.path.basename(p)
    if base in EXCLUDE_BASENAMES:
        return False
    if "/" not in p and base in EXCLUDE_ROOT_DOCS:   # repo-root only (git uses '/')
        return False
    return True
```

- [ ] **Step 5: Run test to verify it passes**

Run: `python3 -m pytest tests/test_iwiki_hooks.py::test_is_documentable_excludes_instruction_and_meta_docs -v`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add tests/test_iwiki_hooks.py plugin/iwiki/hooks/iwiki_common.py
git commit -m "fix(iwiki): exclude instruction/root meta-docs from documentable set"
```

---

## Task 2: `decide_nag` pure decision function (TDD)

Add the pure ask/yield decision function that bounds the nag purely by ask count — no wiki-state input — so wiki/index churn between asks can no longer reset the counter. This is the core of defect 2.

**Files:**
- Modify: `tests/test_iwiki_hooks.py` (append tests)
- Modify: `plugin/iwiki/hooks/iwiki_common.py` (add `decide_nag` near the other session helpers, e.g. after `signature` at the end of the file)

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_iwiki_hooks.py`:

```python
def test_decide_nag_bounds_stable_sig():
    # Fresh session, stable sig: "ask" exactly MAX_ASK times (the first ask is
    # counted), then "yield" on every subsequent call — and it never resets.
    sess = {}
    actions = []
    for _ in range(6):
        action, sess = iw.decide_nag(sess, "deadbeef", 2)
        actions.append(action)
    assert actions == ["ask", "ask", "yield", "yield", "yield", "yield"]


def test_decide_nag_max_ask_zero():
    # MAX_ASK=0 → ask once, then yield forever.
    sess = {}
    a1, sess = iw.decide_nag(sess, "x", 0)
    a2, sess = iw.decide_nag(sess, "x", 0)
    a3, sess = iw.decide_nag(sess, "x", 0)
    assert [a1, a2, a3] == ["ask", "yield", "yield"]


def test_decide_nag_resets_on_changed_sig():
    # A different sig resets count to 1 and asks again.
    sess = {}
    _, sess = iw.decide_nag(sess, "A", 2)
    _, sess = iw.decide_nag(sess, "A", 2)
    action, sess = iw.decide_nag(sess, "B", 2)
    assert action == "ask"
    assert sess["asked_sig"] == "B"
    assert sess["count"] == 1
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 -m pytest tests/test_iwiki_hooks.py -k decide_nag -v`
Expected: FAIL — `AttributeError: module 'iwiki_common' has no attribute 'decide_nag'`.

- [ ] **Step 3: Implement `decide_nag`**

In `plugin/iwiki/hooks/iwiki_common.py`, add at the end of the file (after `signature`):

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

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -m pytest tests/test_iwiki_hooks.py -v`
Expected: PASS (all 4 tests — the Task 1 test plus the 3 new ones).

- [ ] **Step 5: Commit**

```bash
git add tests/test_iwiki_hooks.py plugin/iwiki/hooks/iwiki_common.py
git commit -m "feat(iwiki): add pure decide_nag ask/yield helper with hard cap"
```

---

## Task 3: Rewrite `iwiki-sync.py` to use `decide_nag`

Replace the `wiki_sig`-based reconcile block in the Stop hook with a call to `decide_nag`, and remove every `wsig` / `asked_wiki` read and write. Update the module docstring and the loop-safety comment so they no longer claim a `wiki_sig` shift counts as an ingest.

**Files:**
- Modify: `plugin/iwiki/hooks/iwiki-sync.py:26-29` (module docstring), `:84-111` (decision block)

- [ ] **Step 1: Update the module docstring loop-safety line**

In `plugin/iwiki/hooks/iwiki-sync.py`, replace the final docstring paragraph (currently lines 26-28):

```python
Loop-safe (C): the same unchanged set re-asks at most MAX_ASK times, then yields
to avoid wedging the stop; a change in `wiki_sig` between asks counts as "ingest
happened" and clears the nag. Fail-soft and kill-switchable (IWIKI_AUTO_SYNC=0).
```

with:

```python
Loop-safe (C): the same unchanged set re-asks at most MAX_ASK times via the pure
decide_nag bound, then yields so the stop is never wedged. The bound is the ask
count alone — no wiki/index state feeds it, so the hook's own reindex can no
longer reset it. Fail-soft and kill-switchable (IWIKI_AUTO_SYNC=0).
```

- [ ] **Step 2: Replace the decision block**

In `main()`, replace the empty-pending reset and the whole `sig`/`wsig` block (currently lines 85-111):

```python
        # 2. Source-change nag.
        pending = _pending(sess)
        if not pending:
            sess["asked_sig"] = ""
            sess["asked_wiki"] = ""
            sess["count"] = 0
            iw.write_session(sess)
            return 0

        sig = iw.signature(pending)
        wsig = iw.wiki_sig()
        if sig == sess.get("asked_sig"):
            if wsig != sess.get("asked_wiki"):
                # wiki changed since we asked → ingest happened → reconcile.
                sess["asked_sig"] = ""
                sess["asked_wiki"] = ""
                sess["count"] = 0
                iw.write_session(sess)
                return 0
            if sess.get("count", 0) >= MAX_ASK:
                # Ignored repeatedly → yield so the stop is not wedged.
                return 0
            sess["count"] = sess.get("count", 0) + 1
        else:
            sess["asked_sig"] = sig
            sess["count"] = 1
        sess["asked_wiki"] = wsig
        iw.write_session(sess)
```

with:

```python
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
```

(The directive-building block that follows — `shown = pending[:12]` through the `print(json.dumps(...))` — is unchanged.)

- [ ] **Step 3: Verify the hook compiles and references are gone**

Run:
```bash
python3 -m py_compile plugin/iwiki/hooks/iwiki-sync.py && echo "compile OK"
grep -n "wiki_sig\|asked_wiki\|wsig" plugin/iwiki/hooks/iwiki-sync.py || echo "no orphan refs"
```
Expected: `compile OK` then `no orphan refs`.

- [ ] **Step 4: Verify the unit tests still pass**

Run: `python3 -m pytest tests/test_iwiki_hooks.py -v`
Expected: PASS (unchanged — sync.py is integration code, but this confirms the import graph is intact).

- [ ] **Step 5: Smoke-test the Stop hook end to end (no wedge)**

This proves the rewritten hook yields. Run from the repo root:

```bash
CLAUDE_CONFIG_DIR=$(mktemp -d) IWIKI_SYNC_MAX_ASK=2 bash -c '
  for i in 1 2 3 4; do
    echo "{}" | python3 plugin/iwiki/hooks/iwiki-sync.py
    echo "--- stop $i rc=$? ---"
  done'
```
Expected: the loop completes (no hang). Because this repo has real documentable changes only if the tree is dirty, the exact `block`/empty output varies; the success criterion is that all four invocations return promptly and the script never errors. If a `{"decision":"block",...}` is printed, it must stop appearing by the 3rd or 4th invocation (MAX_ASK=2 → at most 2 asks for a stable set).

- [ ] **Step 6: Commit**

```bash
git add plugin/iwiki/hooks/iwiki-sync.py
git commit -m "fix(iwiki): bound Stop nag with pure decide_nag, drop wiki_sig reconcile"
```

---

## Task 4: Remove the orphaned `wiki_sig()` / `asked_wiki`

Task 3 removed the only consumer of `wiki_sig()` and the `asked_wiki` session field. Remove them now (cleanup of code this change made unused — not unrelated refactoring). `wiki_pages()` stays: `iwiki-bootstrap.py` still uses it.

**Files:**
- Modify: `plugin/iwiki/hooks/iwiki_common.py:190-205` (delete `wiki_sig`), `:243` (drop `asked_wiki` from `_SESSION_DEFAULT`)
- Modify: `plugin/iwiki/hooks/iwiki-bootstrap.py:57-66` (drop `asked_wiki` from the session-init dict)

- [ ] **Step 1: Delete `wiki_sig()` from `iwiki_common.py`**

Remove the entire function (currently lines 190-205):

```python
def wiki_sig() -> str:
    """A cheap fingerprint of the wiki's current state (page mtimes + index
    mtime). Changes whenever any page is written or the index is refreshed — the
    sync hook uses a shift here to detect that an ingest happened between asks."""
    parts: list[str] = []
    for p in sorted(wiki_pages()):
        try:
            parts.append(f"{p}:{int(os.path.getmtime(p))}")
        except Exception:
            pass
    if index_exists():
        try:
            parts.append(f"idx:{int(os.path.getmtime(INDEX_REL))}")
        except Exception:
            pass
    return hashlib.sha256("\n".join(parts).encode("utf-8")).hexdigest()[:16]
```

(Leave the blank line so `wiki_pages()` above and `has_documentable_source()` below stay separated by one blank line, matching the file's style.)

- [ ] **Step 2: Drop `asked_wiki` from `_SESSION_DEFAULT`**

In `_SESSION_DEFAULT`, remove the `asked_wiki` line (currently line 243). The dict becomes:

```python
_SESSION_DEFAULT = {
    "session_id": "",    # owning session; baseline reset only on a NEW id (resume-safe)
    "head": "",          # baseline HEAD at session start
    "wip": [],           # pre-existing dirty documentable files → not the agent's
    "edits": [],         # documentable sources the agent edited this session (F)
    "wiki_dirty": False, # a wiki page changed → needs one batched reindex at Stop
    "asked_sig": "",     # signature of the last nagged pending set (C dedup)
    "count": 0,          # consecutive nags for the same set (C bound vs wedge)
}
```

(`read_session` copies only keys present in `_SESSION_DEFAULT`, so an old session file that still carries `asked_wiki` is simply ignored — backward-compatible.)

- [ ] **Step 3: Drop `asked_wiki` from the bootstrap session-init dict**

In `plugin/iwiki/hooks/iwiki-bootstrap.py`, remove the `"asked_wiki": "",` line from the `iw.write_session({...})` call (currently line 64). The dict becomes:

```python
            iw.write_session({
                "session_id": sid,
                "head": head,
                "wip": iw.changed_sources(),
                "edits": [],
                "wiki_dirty": False,
                "asked_sig": "",
                "count": 0,
            })
```

- [ ] **Step 4: Verify both modules compile and no orphan refs remain**

Run:
```bash
python3 -m py_compile plugin/iwiki/hooks/iwiki_common.py plugin/iwiki/hooks/iwiki-bootstrap.py && echo "compile OK"
grep -rn "wiki_sig\|asked_wiki" plugin/iwiki/hooks/ || echo "no orphan refs"
```
Expected: `compile OK` then `no orphan refs`.

- [ ] **Step 5: Verify the unit tests still pass**

Run: `python3 -m pytest tests/test_iwiki_hooks.py -v`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add plugin/iwiki/hooks/iwiki_common.py plugin/iwiki/hooks/iwiki-bootstrap.py
git commit -m "refactor(iwiki): drop orphaned wiki_sig() and asked_wiki session field"
```

---

## Task 5: Version bump

Bump the plugin version so the cache key changes and the in-cache hook copy resyncs (the cache is keyed by version).

**Files:**
- Modify: `plugin/iwiki/.claude-plugin/plugin.json:4`

- [ ] **Step 1: Bump the version**

Change `"version": "0.5.4"` to `"version": "0.5.5"` in `plugin/iwiki/.claude-plugin/plugin.json`.

- [ ] **Step 2: Verify the JSON is valid**

Run: `python3 -c "import json; print(json.load(open('plugin/iwiki/.claude-plugin/plugin.json'))['version'])"`
Expected: `0.5.5`

- [ ] **Step 3: Commit**

```bash
git add plugin/iwiki/.claude-plugin/plugin.json
git commit -m "chore(iwiki): bump plugin 0.5.4 -> 0.5.5 to resync cached hooks"
```

---

## Task 6: Update `docs/wiki/iwiki.md` + reindex

Update the "Automation Hooks" section so it no longer claims a `wiki_sig` shift counts as an ingest, and states the new behaviour (yield after `IWIKI_SYNC_MAX_ASK` asks; instruction / root meta-doc files excluded from the documentable set). Then reindex and lint per the project post-task checklist.

**Files:**
- Modify: `docs/wiki/iwiki.md:49` (the `iwiki-sync.py (Stop)` bullet)

- [ ] **Step 1: Update the sync-hook bullet**

In `docs/wiki/iwiki.md`, replace the `iwiki-sync.py (Stop)` bullet (currently line 49) — specifically the sentence fragment "…the same unchanged set re-asks at most `IWIKI_SYNC_MAX_ASK` times (default 2, then yields, so the stop is never wedged), and a `wiki_sig` shift between asks counts as the ingest having happened." — with:

```markdown
- **`iwiki-sync.py` (Stop)** — runs the batched `index` once if any wiki page changed this session, then nags about undocumented sources. The change-set is the session's own work: `(uncommitted ∪ committed-this-session) − baseline WIP`, plus the recorded `edits` — so it catches code committed before the stop (no commit-evasion) and excludes pre-existing WIP (no false positives). Agent-instruction files (`CLAUDE.md`/`AGENTS.md`/`GEMINI.md`, any directory) and repo-root meta-docs (`README.md`/`CHANGELOG.md`/…) are excluded from the documentable set, so a committed instruction file never pins the nag. Blocks the stop and injects a directive to run [[iwiki]]'s ingest skill plus `/iwiki-lint`; the same unchanged set re-asks at most `IWIKI_SYNC_MAX_ASK` times (default 2) via the pure `decide_nag` bound, then yields so the stop is never wedged — the bound is the ask count alone, so the hook's own reindex can no longer reset it. State lives in `$CLAUDE_CONFIG_DIR/.cache/iwiki-session.json`. Kill switch: `IWIKI_AUTO_SYNC=0`.
```

- [ ] **Step 2: Reindex the wiki**

Reindex so semantic search reflects the edited page. Use the engine `index` via the same uv/engine resolution the skills use:

```bash
uv run --project plugin/iwiki/engine python3 -m iwiki_engine --wiki-dir docs/wiki index
```
Expected: exit 0 (the index in `docs/wiki/.iwiki/index.jsonl` is rebuilt). If `uv`/engine is unavailable in this environment, run the `iwiki:iwiki-ingest` skill on `docs/wiki/iwiki.md` instead.

- [ ] **Step 3: Lint the wiki**

Run `/iwiki-lint` (or the engine lint subcommand) and confirm no broken `[[refs]]`, no orphan/stale pages introduced by the edit:

```bash
uv run --project plugin/iwiki/engine python3 -m iwiki_engine --wiki-dir docs/wiki lint
```
Expected: no new `broken` entries; `iwiki.md` is not reported as orphan/stale.

- [ ] **Step 4: Commit**

```bash
git add docs/wiki/iwiki.md docs/wiki/.iwiki/index.jsonl
git commit -m "docs(iwiki): describe decide_nag bound + instruction-file exclusion"
```

---

## Final verification

- [ ] **Run the full new test file:**

Run: `python3 -m pytest tests/test_iwiki_hooks.py -v`
Expected: 4 passed.

- [ ] **Confirm no orphan references anywhere in the hooks:**

Run: `grep -rn "wiki_sig\|asked_wiki\|wsig" plugin/iwiki/hooks/ || echo "clean"`
Expected: `clean`.

- [ ] **Manual check (spec success criterion):** in a temp project containing only `CLAUDE.md`, a Stop with the new `is_documentable` produces an empty pending set → no nag.

```bash
TMP=$(mktemp -d); cd "$TMP"; git init -q; echo "# rules" > CLAUDE.md; git add -A; git commit -qm init
CLAUDE_PROJECT_DIR="$TMP" CLAUDE_CONFIG_DIR=$(mktemp -d) \
  bash -c 'mkdir -p docs/wiki; echo "{}" | python3 '"$OLDPWD"'/plugin/iwiki/hooks/iwiki-sync.py; echo "rc=$?"'
cd "$OLDPWD"
```
Expected: no `{"decision":"block",...}` line (empty pending set), `rc=0`. (`docs/wiki` is created so the hook does not early-return on "project does not use iwiki".)

---

## Self-Review notes

- **Spec coverage:** Design §1 → Task 1; §2 (`decide_nag` + sync rewrite) → Tasks 2–3; §3 (orphan removal) → Task 4; §4 (version bump + docs) → Tasks 5–6. Testing §1–4 → Tasks 1–2 unit tests; manual criterion → Final verification.
- **Type consistency:** `decide_nag(sess, sig, max_ask) -> (str, dict)` is defined once (Task 2) and called identically in Task 3 (`action, sess = iw.decide_nag(sess, sig, MAX_ASK)`). Session keys after Task 4: `session_id, head, wip, edits, wiki_dirty, asked_sig, count` — consistent across `_SESSION_DEFAULT` and the bootstrap init dict.
- **Finding F-001 (INFO):** addressed — `is_documentable` docstring updated in Task 1 Step 4.
- **Finding F-002 (INFO):** trace-only, no change required; the "ask exactly MAX_ASK times" semantics are pinned by `test_decide_nag_bounds_stable_sig`.
