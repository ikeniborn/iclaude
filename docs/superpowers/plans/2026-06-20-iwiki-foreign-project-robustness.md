---
chain:
  intent: null
  spec: docs/superpowers/specs/2026-06-20-iwiki-foreign-project-robustness-design.md
review:
  plan_hash: d195f0a6ec6f1961
  spec_hash: 3802024b5343a98e
  last_run: 2026-06-20
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - id: F-001
      phase: consistency
      severity: WARNING
      section: "## File Structure"
      section_hash: f7409106521c16ab
      text: >-
        File Structure (line 17) said lint.py imports "Stdlib + `.links` + `.chunk`
        only", but the actual lint.py code (Task 1 Step 3) imports only
        `from .links import parse_links` and inlines
        `_H2 = re.compile(r"^##\s+(.*?)\s*$", re.MULTILINE)` instead of importing it
        from `.chunk`. RESOLVED: the bullet now reads "Stdlib + `.links` only (the
        `## heading` regex is inlined to match `chunk._H2`, so `.chunk` is not
        imported)", matching the code. Verified against the real chunk.py (line 7):
        `_H2` is the identical pattern, so the inlined copy is behaviourally correct.
      verdict: accepted
    - id: F-002
      phase: consistency
      severity: INFO
      section: "## Task 1: Engine `lint` subcommand"
      section_hash: c0c11ef2fd98d352
      text: >-
        Task 1 Step 5a's prose anchor previously said `from .related import do_related`,
        but the real line in __main__.py (line 15) is `from .related import related as
        do_related`. RESOLVED: the prose anchor now reads "after the existing
        `from .related import related as do_related` line", matching the verified source.
        INFO only — no implementation impact.
      verdict: accepted
---

# iwiki Foreign-Project Robustness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the iwiki plugin from erroring (exit 2) in a project that has no `docs/wiki/`, by moving lint into a config-free engine subcommand and guarding the skills/mandate.

**Architecture:** Add a dependency-free `lint` module to `iwiki_engine` that returns a JSON health report and exits 0 even when the wiki is absent. Rewrite the `iwiki-lint` skill to call it (no model-composed `ugrep`). Add absent-wiki guards to the `iwiki-query` / `iwiki-ingest` skill bash. Make the global isolated `CLAUDE.md` iwiki mandate conditional on `docs/wiki/` existing.

**Tech Stack:** Python 3.12 (stdlib only — no new deps), `uv` runner, markdown skills, pytest (system `python3 -m pytest`).

**Spec:** `docs/superpowers/specs/2026-06-20-iwiki-foreign-project-robustness-design.md`

---

## File Structure

- **Create** `plugin/iwiki/engine/iwiki_engine/lint.py` — the deterministic checks (broken-links, orphans, stale). Stdlib + `.links` only (the `## heading` regex is inlined to match `chunk._H2`, so `.chunk` is not imported), so it loads without `httpx` and runs config-free. One responsibility: compute the health report dict.
- **Modify** `plugin/iwiki/engine/iwiki_engine/__main__.py` — wire a `lint` subcommand, dispatched before `Config.load()` (like `status`).
- **Create** `tests/test_iwiki_lint.py` — pytest unit tests importing `iwiki_engine.lint` directly (no `httpx`, no uv needed).
- **Modify** `plugin/iwiki/skills/iwiki-lint/SKILL.md` — call the engine `lint`, format JSON; keep `gaps` advisory.
- **Modify** `plugin/iwiki/skills/iwiki-query/SKILL.md`, `plugin/iwiki/skills/iwiki-ingest/SKILL.md` — absent-wiki guard at the top of the engine bash block.
- **Modify** `.nvm-isolated/.claude-isolated/CLAUDE.md` — conditional mandate + corrected engine-CLI enumeration.
- **Modify** `plugin/iwiki/.claude-plugin/plugin.json` — version `0.5.3 → 0.5.4`.
- **Update** `docs/wiki/iwiki.md` — via the `iwiki:iwiki-ingest` skill (final task).

---

## Task 1: Engine `lint` subcommand

**Files:**
- Create: `plugin/iwiki/engine/iwiki_engine/lint.py`
- Test: `tests/test_iwiki_lint.py`
- Modify: `plugin/iwiki/engine/iwiki_engine/__main__.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_iwiki_lint.py`:

```python
"""Unit tests for the config-free iwiki_engine.lint subcommand."""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..",
                                "plugin", "iwiki", "engine"))
from iwiki_engine.lint import lint  # noqa: E402


def test_missing_wiki_dir(tmp_path):
    # Directory does not exist at all → clean no-op, never an error.
    assert lint(str(tmp_path / "nope")) == {"wiki_present": False}


def test_empty_wiki_dir(tmp_path):
    # Dir exists but holds no *.md outside .iwiki/ → still a clean no-op.
    (tmp_path / ".iwiki").mkdir()
    (tmp_path / ".iwiki" / "index.jsonl").write_text("")
    assert lint(str(tmp_path)) == {"wiki_present": False}


def test_broken_link_and_orphan(tmp_path):
    # a links to b#Missing (bad heading) and b#Real (good). b links nowhere.
    (tmp_path / "a.md").write_text(
        "# A\n\n## Intro\n\n[[b#Missing]] and [[b#Real]]\n")
    (tmp_path / "b.md").write_text("# B\n\n## Real\n\nbody\n")
    res = lint(str(tmp_path))
    assert res["wiki_present"] is True
    assert res["pages"] == 2
    refs = {r["ref"] for r in res["broken"]}
    assert "b#Missing" in refs
    assert "b#Real" not in refs
    # b is referenced by a; a is referenced by no other page → orphan.
    assert res["orphans"] == [os.path.join(str(tmp_path), "a.md")]


def test_missing_target_file_is_broken(tmp_path):
    (tmp_path / "a.md").write_text("# A\n\n## S\n\n[[ghost#X]]\n")
    res = lint(str(tmp_path))
    assert {"page": os.path.join(str(tmp_path), "a.md"),
            "ref": "ghost#X"} in res["broken"]


def test_stale_when_source_newer_than_page(tmp_path):
    (tmp_path / "p.md").write_text("# P\n\n## S\n\nx\n")
    iwiki = tmp_path / ".iwiki"
    iwiki.mkdir()
    src = tmp_path / "src.sh"
    src.write_text("echo hi\n")
    rec = {"op": "ingest", "source": str(src), "page": str(tmp_path / "p.md"),
           "date": "2026-06-20"}
    (iwiki / "log.jsonl").write_text(json.dumps(rec) + "\n")
    os.utime(str(tmp_path / "p.md"), (1000, 1000))
    os.utime(str(src), (2000, 2000))
    res = lint(str(tmp_path))
    assert {"page": str(tmp_path / "p.md"), "source": str(src)} in res["stale"]
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m pytest tests/test_iwiki_lint.py -v`
Expected: collection error / FAIL — `ModuleNotFoundError: No module named 'iwiki_engine.lint'`.

- [ ] **Step 3: Create the lint module**

Create `plugin/iwiki/engine/iwiki_engine/lint.py`:

```python
"""Deterministic, config-free wiki health checks — no embedding call.

Mirrors the `status` subcommand's contract: stdlib only (plus the in-package
link/heading parsers), so it imports without httpx and runs in any project.
An absent or empty docs/wiki/ is a clean no-op ({"wiki_present": false}), never
an error — this is the fix for the exit-2 seen in foreign projects.
"""
from __future__ import annotations

import glob
import json
import os
import re

from .links import parse_links

_H2 = re.compile(r"^##\s+(.*?)\s*$", re.MULTILINE)


def _pages(wiki_dir: str) -> list[str]:
    """All docs/wiki/**/*.md (normalised), excluding the .iwiki index dir."""
    files = glob.glob(os.path.join(wiki_dir, "**", "*.md"), recursive=True)
    return sorted(os.path.normpath(f) for f in files if "/.iwiki/" not in f)


def _headings(content: str) -> set[str]:
    return {m.group(1).strip() for m in _H2.finditer(content)}


def _resolve(slug: str, wiki_dir: str) -> str:
    """A link target (slug or path) → the wiki file it points at.
    'b' → <wiki>/b.md; 'sub/p' → <wiki>/sub/p.md; '*.md' → joined as-is."""
    t = slug.strip()
    if not t.endswith(".md"):
        t += ".md"
    return os.path.normpath(os.path.join(wiki_dir, t))


def _stale(wiki_dir: str) -> list[dict]:
    """Pages whose source changed after the last ingest, via .iwiki/log.jsonl
    (mtime-based; no git). Deduped by page, first hit wins."""
    log = os.path.join(wiki_dir, ".iwiki", "log.jsonl")
    if not os.path.isfile(log):
        return []
    out: list[dict] = []
    seen: set[str] = set()
    try:
        lines = open(log, encoding="utf-8").read().splitlines()
    except Exception:
        return []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except Exception:
            continue
        src, page = rec.get("source"), rec.get("page")
        if not src or not page or page in seen:
            continue
        if os.path.isfile(src) and os.path.isfile(page):
            try:
                if os.path.getmtime(src) > os.path.getmtime(page):
                    out.append({"page": page, "source": src})
                    seen.add(page)
            except Exception:
                pass
    return out


def lint(wiki_dir: str) -> dict:
    """Health report over docs/wiki/. Absent/empty wiki → {"wiki_present": false}."""
    if not os.path.isdir(wiki_dir):
        return {"wiki_present": False}
    pages = _pages(wiki_dir)
    if not pages:
        return {"wiki_present": False}

    content = {p: open(p, encoding="utf-8").read() for p in pages}
    headings = {p: _headings(c) for p, c in content.items()}

    broken: list[dict] = []
    referenced_by: dict[str, set[str]] = {}
    for page, c in content.items():
        for ref in parse_links(c):
            slug, _, heading = ref.partition("#")
            target = _resolve(slug, wiki_dir)
            referenced_by.setdefault(target, set()).add(page)
            if not os.path.isfile(target):
                broken.append({"page": page, "ref": ref})
                continue
            if heading:
                hs = headings.get(target)
                if hs is None:  # target exists but outside the page set
                    try:
                        hs = _headings(open(target, encoding="utf-8").read())
                    except Exception:
                        hs = set()
                if heading.strip() not in hs:
                    broken.append({"page": page, "ref": ref})

    orphans = [p for p in pages if not (referenced_by.get(p, set()) - {p})]
    return {"wiki_present": True, "pages": len(pages),
            "broken": broken, "orphans": orphans, "stale": _stale(wiki_dir)}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m pytest tests/test_iwiki_lint.py -v`
Expected: PASS (5 passed).

- [ ] **Step 5: Wire the `lint` subcommand into the CLI**

Modify `plugin/iwiki/engine/iwiki_engine/__main__.py`.

5a. Add the import next to the other engine imports (after the existing `from .related import related as do_related` line):

```python
from .related import related as do_related
from .lint import lint as do_lint
```

5b. Add the command function after `cmd_status` (after its `return 0`):

```python
def cmd_lint(wiki_dir: str) -> int:
    print(json.dumps(do_lint(wiki_dir), ensure_ascii=False))
    return 0
```

5c. Register the subparser — add after `sub.add_parser("status")`:

```python
    sub.add_parser("status")
    sub.add_parser("lint")
```

5d. Dispatch `lint` config-free, before `Config.load()`. Change the dispatch block so it reads:

```python
    try:
        if args.cmd == "status":
            return cmd_status(args.wiki_dir)
        if args.cmd == "lint":
            return cmd_lint(args.wiki_dir)
        cfg = Config.load()
        if args.cmd == "index":
            return cmd_index(cfg, args.wiki_dir)
```

- [ ] **Step 6: CLI smoke test (config-free + healthy wiki)**

Run (absent wiki → clean exit 0):

```bash
TMP=$(mktemp -d)
uv run --project plugin/iwiki/engine python3 -m iwiki_engine --wiki-dir "$TMP/none" lint; echo "exit: $?"
```
Expected: `{"wiki_present": false}` then `exit: 0`.

Run (real iclaude wiki):

```bash
uv run --project plugin/iwiki/engine python3 -m iwiki_engine --wiki-dir docs/wiki lint; echo "exit: $?"
```
Expected: a JSON object with `"wiki_present": true`, a `pages` count, and `broken`/`orphans`/`stale` arrays; `exit: 0`.

- [ ] **Step 7: Commit**

```bash
git add plugin/iwiki/engine/iwiki_engine/lint.py \
        plugin/iwiki/engine/iwiki_engine/__main__.py \
        tests/test_iwiki_lint.py
git commit -m "feat(iwiki): add config-free engine lint subcommand

Deterministic broken-link/orphan/stale checks; absent or empty docs/wiki/
returns {\"wiki_present\": false} and exits 0 instead of erroring."
```

---

## Task 2: Rewrite the `iwiki-lint` skill to call the engine

**Files:**
- Modify: `plugin/iwiki/skills/iwiki-lint/SKILL.md`

- [ ] **Step 1: Replace the body (everything after the frontmatter)**

Keep the existing frontmatter (`name`, `description`) unchanged. Replace the body
(`# iwiki-lint` onward) with:

````markdown
# iwiki-lint

Report `docs/wiki/` health by calling the engine's deterministic `lint` check.
Makes NO edits. The engine ships with this plugin, so this works in any project.

## Steps

1. Run the engine `lint` from the current project root:
   ```bash
   # CLAUDE_PLUGIN_ROOT is set for hooks but NOT in the Bash tool — fall back to
   # the in-repo engine, then the newest cached one.
   ENG="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/engine}"
   [ -f "$ENG/pyproject.toml" ] || ENG="plugin/iwiki/engine"
   [ -f "$ENG/pyproject.toml" ] || ENG="$(ls -d "$CLAUDE_CONFIG_DIR"/plugins/cache/*/iwiki/*/engine 2>/dev/null | sort -V | tail -1)"
   UV="${UV_BIN:-}"; [ -x "$UV" ] || UV="$(command -v uv)"; [ -x "$UV" ] || UV="$CLAUDE_CONFIG_DIR/../bin/uv"
   "$UV" run --project "$ENG" python3 -m iwiki_engine --wiki-dir docs/wiki lint
   ```
   This prints one JSON object. It always exits 0 (a real config/engine failure
   prints `HALT:` — see the Stop rule).

2. **If `wiki_present` is `false`:** print one line —
   "No `docs/wiki/` here yet — run `/iwiki-init` to bootstrap one." — and stop.

3. **Otherwise** format a markdown report from the JSON, grouped by category, each
   with its `page` / `ref` reference:
   - **Broken links** — every `{page, ref}` in `broken`.
   - **Orphans** — every path in `orphans`.
   - **Stale** — every `{page, source}` in `stale` (source changed after ingest).
   End with a one-line summary count per category.

4. **Gaps (advisory, only when `wiki_present` is true).** Optionally note source
   areas with no wiki page. Bound the scan to the set `iwiki-init` uses — immediate
   subdirs of `src/` / `lib/` / `app/` / `packages/` / `cmd/` plus root entry-point
   scripts (`*.sh`, `main.*`, `index.*`, `app.*`, `cli.*`) that exist. List
   candidates only; do not treat them as errors.

## Stop rule

If the engine prints `HALT:` (missing `IWIKI_LLM_*` is not needed for `lint`, but a
genuine engine error may still surface), report it and stop.
````

- [ ] **Step 2: Validate the skill bash block syntactically**

Run:

```bash
sed -n '/```bash/,/```/p' plugin/iwiki/skills/iwiki-lint/SKILL.md | sed '/```/d' | bash -n - && echo "bash -n OK"
```
Expected: `bash -n OK` (no syntax errors).

- [ ] **Step 3: Commit**

```bash
git add plugin/iwiki/skills/iwiki-lint/SKILL.md
git commit -m "refactor(iwiki): iwiki-lint skill calls engine lint, no composed ugrep"
```

---

## Task 3: Absent-wiki guards in `iwiki-query` and `iwiki-ingest`

**Files:**
- Modify: `plugin/iwiki/skills/iwiki-query/SKILL.md`
- Modify: `plugin/iwiki/skills/iwiki-ingest/SKILL.md`

- [ ] **Step 1: Guard the `iwiki-query` engine bash**

In `plugin/iwiki/skills/iwiki-query/SKILL.md`, insert the guard as the first line
inside the step-1 ```bash block (immediately before the `ENG=` line):

```bash
   [ -d docs/wiki ] || { echo "iwiki: no docs/wiki/ here — run /iwiki-init to create one."; exit 0; }
   # CLAUDE_PLUGIN_ROOT is set for hooks but NOT in the Bash tool — fall back to
   # the in-repo engine, then the newest cached one. Reused by step 4 below.
   ENG="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/engine}"
```

- [ ] **Step 2: Guard the `iwiki-ingest` index bash**

In `plugin/iwiki/skills/iwiki-ingest/SKILL.md`, insert the same guard as the first
line inside the step-4 ```bash block (immediately before the `ENG=` line). The page
is written in step 3 first, so this guard only fires defensively when there is truly
no wiki to index:

```bash
   [ -d docs/wiki ] || { echo "iwiki: no docs/wiki/ here — run /iwiki-init to create one."; exit 0; }
   # Resolve the engine project. CLAUDE_PLUGIN_ROOT is set for hooks but NOT in
   # the Bash tool, so fall back to the in-repo copy, then the newest cached one.
   ENG="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/engine}"
```

- [ ] **Step 3: Validate both bash blocks syntactically**

Run:

```bash
for s in query ingest; do
  sed -n '/```bash/,/```/p' "plugin/iwiki/skills/iwiki-$s/SKILL.md" | sed '/```/d' | bash -n - \
    && echo "iwiki-$s bash -n OK"
done
```
Expected: `iwiki-query bash -n OK` and `iwiki-ingest bash -n OK`.

- [ ] **Step 4: Commit**

```bash
git add plugin/iwiki/skills/iwiki-query/SKILL.md plugin/iwiki/skills/iwiki-ingest/SKILL.md
git commit -m "fix(iwiki): guard query/ingest skills when docs/wiki/ is absent"
```

---

## Task 4: Conditional iwiki mandate in the global isolated CLAUDE.md

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/CLAUDE.md`

- [ ] **Step 1: Make "Getting Started" conditional**

Replace the line:

```markdown
1. Run `/iwiki-query` → retrieve relevant `docs/wiki/` sections; `/iwiki-lint` → check doc health.
```

with:

```markdown
1. **If the project has a `docs/wiki/`**, run `/iwiki-query` → retrieve relevant `docs/wiki/` sections; `/iwiki-lint` → check doc health. (No `docs/wiki/` → skip; iwiki is not set up in this project.)
```

- [ ] **Step 2: Make "Keep Docs Current" conditional**

Replace the line:

```markdown
**After every change that alters functionality, architecture, or behavior, update the project docs via iwiki — before responding to the user.**
```

with:

```markdown
**After every change that alters functionality, architecture, or behavior — and only in a project that already has a `docs/wiki/` — update the project docs via iwiki before responding to the user.**
```

- [ ] **Step 3: Correct the engine-CLI enumeration**

Replace the sentence:

```markdown
The `iwiki_engine` CLI exposes ONLY `index | search | related | status` (there is NO `lint` subcommand — lint is skill-side).
```

with:

```markdown
The `iwiki_engine` CLI exposes `index | search | related | status | lint` (`lint` is config-free, like `status`, and is what `/iwiki-lint` calls).
```

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/CLAUDE.md
git commit -m "docs(iwiki): gate global iwiki mandate on docs/wiki/, fix CLI enumeration"
```

---

## Task 5: Version bump + wiki doc refresh

**Files:**
- Modify: `plugin/iwiki/.claude-plugin/plugin.json`
- Update: `docs/wiki/iwiki.md` (via skill)

- [ ] **Step 1: Bump the plugin version**

In `plugin/iwiki/.claude-plugin/plugin.json`, change:

```json
  "version": "0.5.3"
```

to:

```json
  "version": "0.5.4"
```

(The plugin-cache key is the version, so the bump resyncs the in-cache copy.)

- [ ] **Step 2: Refresh the wiki page for iwiki**

Invoke the `iwiki:iwiki-ingest` skill on `plugin/iwiki` to regenerate/update
`docs/wiki/iwiki.md` so it documents the new engine `lint` subcommand and the
absent-wiki behaviour. Show the diff per the skill's guardrails.

- [ ] **Step 3: Run the new lint over the iclaude wiki**

Invoke the `iwiki:iwiki-lint` skill (now the engine path). Confirm: no broken
links, report prints cleanly, exit 0.

- [ ] **Step 4: Commit**

```bash
git add plugin/iwiki/.claude-plugin/plugin.json docs/wiki/
git commit -m "chore(iwiki): bump plugin 0.5.3 -> 0.5.4, refresh docs/wiki/iwiki.md"
```

---

## Final Verification

- [ ] `python3 -m pytest tests/test_iwiki_lint.py -v` → all pass.
- [ ] `uv run --project plugin/iwiki/engine python3 -m iwiki_engine --wiki-dir /tmp/none lint` → `{"wiki_present": false}`, exit 0.
- [ ] `uv run --project plugin/iwiki/engine python3 -m iwiki_engine --wiki-dir docs/wiki lint` → `wiki_present: true` report, exit 0.
- [ ] `bash -n` clean for the edited skill bash blocks (lint / query / ingest).
- [ ] Global isolated `CLAUDE.md` shows the conditional mandate + the `... | lint` enumeration.
- [ ] `plugin.json` version is `0.5.4`.
- [ ] `/iwiki-lint` over `docs/wiki/` reports no broken refs.

## Notes / non-obvious points

- `lint.py` must NOT import `.embed` or `.config` (those pull `httpx`); it stays
  stdlib + `.links`. This keeps the pytest unit test importable in system `python3`
  and honours the config-free promise.
- `lint` is dispatched in `main()` **before** `Config.load()`, exactly like
  `status`, so a missing `IWIKI_LLM_*` never turns lint into a `HALT`.
- The `iwiki-ingest` guard is defensive only — step 3 writes the page first, so by
  the step-4 index `docs/wiki/` exists. It exists to avoid a stray engine spin-up,
  not to block legitimate first-page creation.
- Per spec F-001: the project root `CLAUDE.md` has no engine-subcommand enumeration,
  so it needs no edit — only the global isolated `CLAUDE.md` (Task 4).
