---
result_check:
  verdict: OK
  plan_hash: 6faa67d9a6c9e5f6
  last_run: 2026-06-23
review:
  plan_hash: 6faa67d9a6c9e5f6
  spec_hash: a02ff76606a6a317
  last_run: 2026-06-23
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - id: F-001
      phase: verifiability
      severity: INFO
      section: "Task 8: Full suite + migration note"
      section_hash: ac8e2b892c62b5be
      text: >-
        Step 3 instructs to invoke iwiki-ingest on the changed engine sources but
        leaves the exact ingest invocation as a prose comment rather than a runnable
        command; the verifiable command shown is the lint run. Non-blocking — the
        post-task doc step is intentionally human-driven (per project CLAUDE.md).
      verdict: open
      verdict_at: null
    - id: F-002
      phase: consistency
      severity: INFO
      section: "Task 3: Chunker — title + Overview prefix, Overview excluded (C)"
      section_hash: 6ffc447bf718332f
      text: >-
        chunk._lead caps the lead at LEAD_MAX=250 while validate._lead does NOT cap
        before its long_lead>250 comparison. This is correct-by-design (the chunker
        truncates for embedding; the validator measures the authored length to flag
        long_lead) but the two _lead helpers are intentionally non-identical despite
        sharing a name — worth a keep-in-sync note. No behavioral defect.
      verdict: open
      verdict_at: null
chain:
  intent: null
  spec: docs/superpowers/specs/2026-06-23-iwiki-section-formation-design.md
---
# iwiki section-formation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make iwiki wiki pages `##`-only with a mandatory authored `## Overview` summary, prefix every content section's vectors with page title + Overview summary + heading + section lead (so split sections stay semantically bound), and enforce the structural rules with a blocking PreToolUse hook plus advisory lint.

**Architecture:** Three coupled changes, sequenced A → C → B. **A** is docs-only (authoring rules in two skills). **C** refactors the engine chunker (`chunk.py`) to extract the authored `## Overview` body as the article summary, exclude that section from the index, and prefix it (with the section lead) onto every other section's sub-chunks before embedding. **B** adds a stdlib-only validator (`validate.py`) shared by `lint` and a new `validate` subcommand, plus a fail-open blocking `PreToolUse` hook. No external model, endpoint, or cache — the summary is authored in-page by the same agent that writes the wiki.

**Tech Stack:** Python 3 (stdlib `re`/`hashlib`/`os`, no new deps), `uv` for the engine venv, `pytest` for tests, Claude Code hooks (JSON-on-stdin, exit 2 = block).

**Spec:** `docs/superpowers/specs/2026-06-23-iwiki-section-formation-design.md`

**Branch:** `dev-iwiki-section-formation` (already created; base `dev`, PR → `dev`).

**Test command (from repo root):**
```bash
uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/<file> -v
```

---

## File Structure

| File | Responsibility | Change |
|------|----------------|--------|
| `plugin/iwiki/skills/iwiki-ingest/SKILL.md` | per-page authoring rules | modify (A) |
| `plugin/iwiki/skills/iwiki-init/SKILL.md` | batch authoring rules | modify (A) |
| `plugin/iwiki/engine/iwiki_engine/config.py` | env config | modify — add `summary_max` (C) |
| `plugin/iwiki/engine/iwiki_engine/chunk.py` | markdown → chunks | refactor — title/Overview/prefix (C) |
| `plugin/iwiki/engine/iwiki_engine/__main__.py` | CLI | modify — pass `summary_max`, add `validate` subcommand (C/B) |
| `plugin/iwiki/engine/iwiki_engine/validate.py` | section-formation checks (stdlib) | create (B) |
| `plugin/iwiki/engine/iwiki_engine/lint.py` | health report | modify — fold section findings (B) |
| `plugin/iwiki/hooks/iwiki-validate.py` | blocking PreToolUse hook | create (B) |
| `plugin/iwiki/hooks/hooks.json` | hook registration | modify — add PreToolUse (B) |
| `plugin/iwiki/engine/tests/test_chunk.py` | chunk tests | modify (C) |
| `plugin/iwiki/engine/tests/test_config.py` | config tests | modify (C) |
| `plugin/iwiki/engine/tests/test_validate.py` | validator tests | create (B) |
| `plugin/iwiki/engine/tests/test_lint.py` | lint tests | modify (B) |

---

## Task 1: Authoring rules — depth + Overview mandate (A)

**Files:**
- Modify: `plugin/iwiki/skills/iwiki-ingest/SKILL.md` (Steps → step 2 area)
- Modify: `plugin/iwiki/skills/iwiki-init/SKILL.md` (Steps → step 3 area)

Docs-only. No test; verify by reading the diff.

- [ ] **Step 1: Edit `iwiki-ingest/SKILL.md`**

Replace this line in the `## Steps` section (step 2):

```markdown
2. Decide the target wiki page: `docs/wiki/<topic>.md` (create or update).
   One `##` section per concept; lead each section with a ≤250-char paragraph.
   Cross-link related pages with `[[file#Heading]]`.
```

with:

```markdown
2. Decide the target wiki page: `docs/wiki/<topic>.md` (create or update).
   Page structure (REQUIRED — the engine and the section-formation hook depend on it):
   - Use **only `##`** for sections — never `###` or deeper. Deeper headings are not
     indexed as separate units and the validation hook blocks them; flatten them into
     the `##` section's prose.
   - Put **no content before the first `##`** except a single `#` H1 title — text
     before the first `##` is dropped from the index.
   - Lead with `# Title`, then a **first `## Overview` section** that summarizes all of
     the page's sections in ≈≤400 characters. You author this Overview yourself as part
     of writing the page (no separate summarizer). The engine reuses the Overview body
     to give every other section's vectors whole-article context, and the Overview
     section itself is NOT indexed as its own searchable section.
   - One `##` section per concept; lead each section with a ≤250-char paragraph (it
     doubles as the section summary that binds the section's chunks).
   Cross-link related pages with `[[file#Heading]]`.
```

- [ ] **Step 2: Edit `iwiki-init/SKILL.md`**

Replace this text in step 3 (`Generate each page`):

```markdown
3. **Generate each page.** For every area, follow the `iwiki-ingest` authoring
   rules: read the real source, write `docs/wiki/<slug>.md` with one `##` section
   per concept, each section led by a ≤250-char paragraph, cross-linking related
   pages with `[[<page>#<Heading>]]`. English prose. Accurate to the code — do not
   invent. Show a brief diff/summary per page as you go.
```

with:

```markdown
3. **Generate each page.** For every area, follow the `iwiki-ingest` authoring
   rules: read the real source, write `docs/wiki/<slug>.md` as `# Title` + a first
   `## Overview` section (≈≤400-char summary of all the page's sections, authored by
   you) + one `##` section per concept, each led by a ≤250-char paragraph. Use **only
   `##`** — never `###` or deeper, and no content before the first `##` except the
   `# Title`. Cross-link related pages with `[[<page>#<Heading>]]`. English prose.
   Accurate to the code — do not invent. Show a brief diff/summary per page as you go.
```

- [ ] **Step 3: Verify the edits read correctly**

Run: `git diff --stat plugin/iwiki/skills/`
Expected: both `SKILL.md` files listed as modified.

- [ ] **Step 4: Commit**

```bash
git add plugin/iwiki/skills/iwiki-ingest/SKILL.md plugin/iwiki/skills/iwiki-init/SKILL.md
git commit -m "docs(iwiki): mandate ##-only pages with an authored ## Overview summary section"
```

---

## Task 2: Config — `summary_max` (C)

**Files:**
- Modify: `plugin/iwiki/engine/iwiki_engine/config.py`
- Test: `plugin/iwiki/engine/tests/test_config.py`

- [ ] **Step 1: Write the failing test**

Append to `plugin/iwiki/engine/tests/test_config.py`:

```python
def test_summary_max_default_and_override(monkeypatch):
    monkeypatch.setenv("IWIKI_LLM_BASE_URL", "https://x/v1")
    monkeypatch.setenv("IWIKI_LLM_KEY", "k")
    monkeypatch.delenv("IWIKI_SUMMARY_MAX_CHARS", raising=False)
    assert Config.load().summary_max == 400
    monkeypatch.setenv("IWIKI_SUMMARY_MAX_CHARS", "250")
    assert Config.load().summary_max == 250
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_config.py::test_summary_max_default_and_override -v`
Expected: FAIL — `AttributeError: 'Config' object has no attribute 'summary_max'`.

- [ ] **Step 3: Add the field to `Config`**

In `plugin/iwiki/engine/iwiki_engine/config.py`, add a field to the dataclass (after `chunk_overlap: int`):

```python
    chunk_overlap: int
    summary_max: int
```

and in `Config.load()`'s `return Config(...)` block, add after the `chunk_overlap=...` line:

```python
            chunk_overlap=int(getenv("IWIKI_CHUNK_OVERLAP", "64")),
            summary_max=int(getenv("IWIKI_SUMMARY_MAX_CHARS", "400")),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_config.py -v`
Expected: PASS (both config tests).

- [ ] **Step 5: Commit**

```bash
git add plugin/iwiki/engine/iwiki_engine/config.py plugin/iwiki/engine/tests/test_config.py
git commit -m "feat(iwiki): add IWIKI_SUMMARY_MAX_CHARS config (default 400)"
```

---

## Task 3: Chunker — title + Overview prefix, Overview excluded (C)

**Files:**
- Modify: `plugin/iwiki/engine/iwiki_engine/chunk.py` (full rewrite of the module)
- Modify: `plugin/iwiki/engine/iwiki_engine/__main__.py:36` (pass `summary_max`)
- Test: `plugin/iwiki/engine/tests/test_chunk.py`

- [ ] **Step 1: Write the failing tests**

Append to `plugin/iwiki/engine/tests/test_chunk.py`:

```python
PAGE = (
    "# Proxy Management\n\n"
    "## Overview\n"
    "iclaude routes Claude Code via an HTTPS proxy with OAuth refresh.\n\n"
    "## TLS Handling\n"
    "The proxy terminates TLS using a local CA.\n\n"
    "## OAuth Refresh\n"
    "Tokens refresh before expiry.\n"
)


def test_overview_section_is_not_indexed():
    chunks = chunk_markdown("proxy.md", PAGE, size=512, overlap=64)
    assert "Overview" not in {c.heading for c in chunks}
    assert {c.heading for c in chunks} == {"TLS Handling", "OAuth Refresh"}


def test_prefix_carries_title_overview_and_lead():
    chunks = chunk_markdown("proxy.md", PAGE, size=512, overlap=64)
    tls = next(c for c in chunks if c.heading == "TLS Handling")
    assert tls.text.startswith("# Proxy Management\n")
    assert "iclaude routes Claude Code via an HTTPS proxy" in tls.text  # article summary
    assert "## TLS Handling" in tls.text                                # heading
    assert "The proxy terminates TLS using a local CA." in tls.text     # lead


def test_prefix_on_every_subchunk_of_a_split_section():
    body = " ".join(str(i) for i in range(40))
    md = f"# T\n\n## Overview\nsumm of all.\n\n## Big\n{body}\n"
    chunks = chunk_markdown("f.md", md, size=8, overlap=2)
    big = [c for c in chunks if c.heading == "Big"]
    assert len(big) > 1
    assert all(c.text.startswith("# T\n") for c in big)
    assert all("summ of all." in c.text for c in big)   # article summary in every piece
    assert all("## Big" in c.text for c in big)          # section heading in every piece


def test_title_falls_back_to_humanized_basename():
    md = "## Overview\nsumm.\n\n## A\nbody.\n"   # no H1
    chunks = chunk_markdown("my-page.md", md, size=512, overlap=64)
    assert chunks[0].text.startswith("# my page\n")


def test_no_overview_yields_no_summary_line():
    md = "# T\n\n## A\nbody alpha.\n"
    chunks = chunk_markdown("f.md", md, size=512, overlap=64)
    # prefix is title + heading + lead only; no blank summary line injected
    assert chunks[0].text.startswith("# T\n## A\nbody alpha.\n\n")


def test_hash_changes_when_overview_changes():
    a = chunk_markdown("f.md", "# T\n\n## Overview\nsumm one.\n\n## A\nbody.\n",
                       size=512, overlap=64)
    b = chunk_markdown("f.md", "# T\n\n## Overview\nsumm two.\n\n## A\nbody.\n",
                       size=512, overlap=64)
    assert a[0].hash != b[0].hash
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_chunk.py -v`
Expected: the six new tests FAIL (Overview currently indexed, no prefix); the three original tests still PASS.

- [ ] **Step 3: Rewrite `chunk.py`**

Replace the entire contents of `plugin/iwiki/engine/iwiki_engine/chunk.py` with:

```python
"""Split markdown on ## headings into sections, then into overlapping sub-chunks.

Each content section's sub-chunks are prefixed with the page title, the authored
``## Overview`` summary, the section heading, and the section lead, so every vector
carries whole-article + whole-section context. The first ``## Overview`` section is
the summary source and is itself excluded from the index.
"""
from __future__ import annotations
import hashlib
import os
import re
from dataclasses import dataclass

_H1 = re.compile(r"^#\s+(.*?)\s*$", re.MULTILINE)
_H2 = re.compile(r"^##\s+(.*?)\s*$", re.MULTILINE)

OVERVIEW_HEADING = "overview"   # reserved first section; its body is the article summary
LEAD_MAX = 250                  # section lead (= section summary) char cap


@dataclass
class Chunk:
    file: str
    heading: str
    chunk: int           # sub-chunk index within the section (0-based)
    text: str            # prefix + body slice (the text that gets embedded)
    hash: str            # sha256(text)[:16]

    @property
    def id(self) -> str:
        return f"{self.file}#{self.heading}"


def _hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def _split_section(words: list[str], size: int, overlap: int) -> list[list[str]]:
    if len(words) <= size:
        return [words]
    step = max(1, size - overlap)
    return [words[i:i + size] for i in range(0, len(words), step) if words[i:i + size]]


def _page_title(content: str, file: str) -> str:
    """First ``# H1`` before the first ``##``; fallback to a humanized basename."""
    h2 = _H2.search(content)
    head = content[:h2.start()] if h2 else content
    m = _H1.search(head)
    if m and m.group(1).strip():
        return m.group(1).strip()
    stem = os.path.splitext(os.path.basename(file))[0]
    return stem.replace("-", " ").replace("_", " ").strip()


def _lead(body: str) -> str:
    """First paragraph of a section body (up to the first blank line), capped."""
    para: list[str] = []
    for ln in body.splitlines():
        if not ln.strip():
            if para:
                break
            continue
        para.append(ln.strip())
    return " ".join(para)[:LEAD_MAX]


def _sections(content: str) -> list[tuple[str, str]]:
    """[(heading, body), ...] split on ``##``. Pre-``##`` content is ignored."""
    out: list[tuple[str, str]] = []
    ms = list(_H2.finditer(content))
    for i, m in enumerate(ms):
        start = m.end()
        end = ms[i + 1].start() if i + 1 < len(ms) else len(content)
        out.append((m.group(1).strip(), content[start:end].strip()))
    return out


def chunk_markdown(file: str, content: str, size: int, overlap: int,
                   summary_max: int = 400) -> list[Chunk]:
    """Return chunks for one markdown file.

    The first ``## Overview`` section (case-insensitive) is the article-summary
    source and is NOT itself indexed; every other section's sub-chunks are prefixed
    with title + article summary + heading + lead, then word-split with overlap.
    """
    out: list[Chunk] = []
    title = _page_title(content, file)
    secs = _sections(content)
    article_summary = ""
    if secs and secs[0][0].lower() == OVERVIEW_HEADING:
        article_summary = " ".join(secs[0][1].split())[:summary_max]
        secs = secs[1:]                       # exclude Overview from the index
    for heading, body in secs:
        lead = _lead(body)
        prefix = "\n".join(
            ln for ln in (f"# {title}", article_summary, f"## {heading}", lead) if ln
        )
        for ci, piece in enumerate(_split_section(body.split(), size, overlap)):
            text = prefix + "\n\n" + " ".join(piece)
            out.append(Chunk(file=file, heading=heading, chunk=ci,
                             text=text, hash=_hash(text)))
    return out
```

- [ ] **Step 4: Pass `summary_max` from the indexer**

In `plugin/iwiki/engine/iwiki_engine/__main__.py`, change line 36 inside `cmd_index`:

```python
        chunks.extend(chunk_markdown(md, content, cfg.chunk_size, cfg.chunk_overlap))
```

to:

```python
        chunks.extend(chunk_markdown(md, content, cfg.chunk_size,
                                     cfg.chunk_overlap, cfg.summary_max))
```

- [ ] **Step 5: Run the chunk tests to verify they pass**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_chunk.py -v`
Expected: PASS — all nine tests (three original + six new).

- [ ] **Step 6: Run the full engine suite (no regressions)**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests -q`
Expected: PASS — all tests green.

- [ ] **Step 7: Commit**

```bash
git add plugin/iwiki/engine/iwiki_engine/chunk.py \
        plugin/iwiki/engine/iwiki_engine/__main__.py \
        plugin/iwiki/engine/tests/test_chunk.py
git commit -m "feat(iwiki): prefix section vectors with title + ## Overview summary + lead; exclude Overview from index"
```

---

## Task 4: Validator module (B)

**Files:**
- Create: `plugin/iwiki/engine/iwiki_engine/validate.py`
- Test: `plugin/iwiki/engine/tests/test_validate.py`

- [ ] **Step 1: Write the failing tests**

Create `plugin/iwiki/engine/tests/test_validate.py`:

```python
from iwiki_engine.validate import validate_page


def _types(content):
    return {f["type"] for f in validate_page(content)}


CLEAN = (
    "# T\n\n## Overview\nsummary of all sections.\n\n"
    "## A\nlead alpha.\n\n## B\nlead beta.\n"
)


def test_clean_page_has_no_findings():
    assert validate_page(CLEAN) == []


def test_deep_heading_is_blocking():
    fs = [f for f in validate_page("## Overview\ns.\n\n## A\nx.\n\n### too deep\n")
          if f["type"] == "deep_heading"]
    assert fs and fs[0]["severity"] == "block"


def test_pre_h2_text_is_blocking():
    fs = [f for f in validate_page("# T\n\nstray prose\n\n## Overview\ns.\n\n## A\nx.\n")
          if f["type"] == "pre_h2_text"]
    assert fs and fs[0]["severity"] == "block"


def test_single_h1_before_h2_is_allowed():
    assert "pre_h2_text" not in _types(CLEAN)


def test_missing_overview_is_advisory():
    fs = [f for f in validate_page("# T\n\n## A\nlead.\n") if f["type"] == "missing_overview"]
    assert fs and fs[0]["severity"] == "advisory"


def test_missing_lead_is_advisory():
    fs = [f for f in validate_page("## Overview\ns.\n\n## A\n\n## B\nlead.\n")
          if f["type"] == "missing_lead"]
    assert fs and fs[0]["severity"] == "advisory"


def test_long_lead_is_advisory():
    long = "x " * 200  # > 250 chars
    fs = [f for f in validate_page(f"## Overview\ns.\n\n## A\n{long}\n")
          if f["type"] == "long_lead"]
    assert fs and fs[0]["severity"] == "advisory"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_validate.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'iwiki_engine.validate'`.

- [ ] **Step 3: Create `validate.py`**

Create `plugin/iwiki/engine/iwiki_engine/validate.py`:

```python
"""Deterministic section-formation checks over a wiki page — stdlib only, no API.

Mirrors the structural rules the authoring skills mandate (see the section-formation
spec). Consumed by ``lint`` (folded into its report) and the ``validate`` subcommand.
The blocking subset (deep_heading, pre_h2_text) is mirrored inline by the
iwiki-validate PreToolUse hook; the advisory subset (missing_overview, missing_lead,
long_lead) is report-only.
"""
from __future__ import annotations
import re

OVERVIEW_HEADING = "overview"   # keep in sync with chunk.OVERVIEW_HEADING
LEAD_MAX = 250                  # keep in sync with chunk.LEAD_MAX

_DEEP = re.compile(r"^#{3,}\s", re.MULTILINE)   # ### or deeper
_H1_LINE = re.compile(r"^#\s+\S")               # a single-# H1 line
_H2 = re.compile(r"^##\s+(.*?)\s*$", re.MULTILINE)   # keep in sync with chunk._H2


def _sections(content: str) -> list[tuple[str, str]]:
    out: list[tuple[str, str]] = []
    ms = list(_H2.finditer(content))
    for i, m in enumerate(ms):
        start = m.end()
        end = ms[i + 1].start() if i + 1 < len(ms) else len(content)
        out.append((m.group(1).strip(), content[start:end].strip()))
    return out


def _lead(body: str) -> str:
    para: list[str] = []
    for ln in body.splitlines():
        if not ln.strip():
            if para:
                break
            continue
        para.append(ln.strip())
    return " ".join(para)


def validate_page(content: str) -> list[dict]:
    """Return a list of {type, severity, text} section-formation findings."""
    findings: list[dict] = []

    if _DEEP.search(content):
        findings.append({"type": "deep_heading", "severity": "block",
                         "text": "heading deeper than ## (###+); flatten to ##"})

    h2 = _H2.search(content)
    pre = content[:h2.start()] if h2 else content
    if any(ln.strip() and not _H1_LINE.match(ln) for ln in pre.splitlines()):
        findings.append({"type": "pre_h2_text", "severity": "block",
                         "text": "indexable text before the first ## (only a single # H1 allowed)"})

    secs = _sections(content)
    if not secs or secs[0][0].lower() != OVERVIEW_HEADING:
        findings.append({"type": "missing_overview", "severity": "advisory",
                         "text": "first ## section is not 'Overview'"})

    for heading, body in secs:
        lead = _lead(body)
        if not lead:
            findings.append({"type": "missing_lead", "severity": "advisory",
                             "text": f"section '{heading}' has no lead paragraph"})
        elif len(lead) > LEAD_MAX:
            findings.append({"type": "long_lead", "severity": "advisory",
                             "text": f"section '{heading}' lead exceeds {LEAD_MAX} chars"})
    return findings
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_validate.py -v`
Expected: PASS — all seven tests.

- [ ] **Step 5: Commit**

```bash
git add plugin/iwiki/engine/iwiki_engine/validate.py plugin/iwiki/engine/tests/test_validate.py
git commit -m "feat(iwiki): add config-free section-formation validator"
```

---

## Task 5: Fold validator findings into `lint` (B)

**Files:**
- Modify: `plugin/iwiki/engine/iwiki_engine/lint.py`
- Test: `plugin/iwiki/engine/tests/test_lint.py`

- [ ] **Step 1: Write the failing test**

Append to `plugin/iwiki/engine/tests/test_lint.py`:

```python
def test_section_findings_folded_into_report(tmp_path):
    # page with a ### deep heading and no ## Overview → both findings surface
    wd = _wiki(tmp_path, {"a.md": "## A\nlead.\n\n### deep\nx\n"})
    out = lint(wd)
    types = {f["type"] for f in out["sections"]}
    assert "deep_heading" in types
    assert "missing_overview" in types
    assert all("page" in f for f in out["sections"])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_lint.py::test_section_findings_folded_into_report -v`
Expected: FAIL — `KeyError: 'sections'`.

- [ ] **Step 3: Fold findings into `lint.py`**

In `plugin/iwiki/engine/iwiki_engine/lint.py`, add the import near the top (after `from .links import parse_links`):

```python
from .links import parse_links
from .validate import validate_page
```

Then in `lint()`, change the final `return` to compute and include section findings. Replace:

```python
    orphans = [p for p in pages if not (referenced_by.get(p, set()) - {p})]
    return {"wiki_present": True, "pages": len(pages),
            "broken": broken, "orphans": orphans, "stale": _stale(wiki_dir)}
```

with:

```python
    orphans = [p for p in pages if not (referenced_by.get(p, set()) - {p})]
    sections = [{"page": p, **f} for p, c in content.items()
                for f in validate_page(c)]
    return {"wiki_present": True, "pages": len(pages),
            "broken": broken, "orphans": orphans, "stale": _stale(wiki_dir),
            "sections": sections}
```

- [ ] **Step 4: Run the lint tests to verify they pass**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_lint.py -v`
Expected: PASS — all lint tests (existing + new). Existing tests don't assert on `sections`, so they stay green.

- [ ] **Step 5: Commit**

```bash
git add plugin/iwiki/engine/iwiki_engine/lint.py plugin/iwiki/engine/tests/test_lint.py
git commit -m "feat(iwiki): surface section-formation findings in lint report"
```

---

## Task 6: `validate` subcommand (B)

**Files:**
- Modify: `plugin/iwiki/engine/iwiki_engine/__main__.py`

The subcommand must be config-free (no `Config.load()`), like `lint`/`status`.

- [ ] **Step 1: Add the `cmd_validate` function**

In `plugin/iwiki/engine/iwiki_engine/__main__.py`, add after `cmd_lint` (around line 78):

```python
def cmd_validate(wiki_dir: str) -> int:
    from .validate import validate_page
    files = sorted(glob.glob(os.path.join(wiki_dir, "**", "*.md"), recursive=True))
    files = [f for f in files if "/.iwiki/" not in f]
    out = []
    for p in files:
        try:
            c = open(p, encoding="utf-8").read()
        except Exception:
            continue
        out += [{"page": p, **f} for f in validate_page(c)]
    print(json.dumps({"sections": out}, ensure_ascii=False))
    return 0
```

- [ ] **Step 2: Register the subparser**

In `main()`, after `sub.add_parser("lint")`, add:

```python
    sub.add_parser("lint")
    sub.add_parser("validate")
```

- [ ] **Step 3: Route it config-free**

In `main()`'s `try:` block, alongside the `status`/`lint` config-free routes, add the `validate` route BEFORE `cfg = Config.load()`:

```python
        if args.cmd == "lint":
            return cmd_lint(args.wiki_dir)
        if args.cmd == "validate":
            return cmd_validate(args.wiki_dir)
        cfg = Config.load()
```

- [ ] **Step 4: Verify it runs without API config**

Run (note: no `IWIKI_LLM_*` set — must still work):
```bash
mkdir -p /tmp/iwt/docs/wiki && printf '## A\nlead.\n\n### deep\nx\n' > /tmp/iwt/docs/wiki/a.md
env -u IWIKI_LLM_BASE_URL -u IWIKI_LLM_KEY \
  uv run --project plugin/iwiki/engine python3 -m iwiki_engine --wiki-dir /tmp/iwt/docs/wiki validate
```
Expected: JSON like `{"sections": [{"page": ".../a.md", "type": "deep_heading", ...}, {"type": "missing_overview", ...}]}` and exit 0 (no `HALT`).

- [ ] **Step 5: Commit**

```bash
git add plugin/iwiki/engine/iwiki_engine/__main__.py
git commit -m "feat(iwiki): add config-free 'validate' subcommand"
```

---

## Task 7: Blocking PreToolUse hook (B)

**Files:**
- Create: `plugin/iwiki/hooks/iwiki-validate.py`
- Modify: `plugin/iwiki/hooks/hooks.json`

- [ ] **Step 1: Create the hook**

Create `plugin/iwiki/hooks/iwiki-validate.py`:

```python
#!/usr/bin/env python3
"""PreToolUse hook — block wiki pages that break section-formation structure.

Blocks (exit 2) a Write/Edit/MultiEdit to a docs/wiki/ page whose RESULTING content
has a heading deeper than ## (deep_heading) or indexable text before the first ##
other than a single # H1 (pre_h2_text). Advisory findings (missing Overview, lead
length) are left to lint and never block.

Mirrors the engine validator's blocking regexes inline (same convention as lint.py
inlining chunk._H2) so the hook needs no uv/engine spawn on every edit.

Kill switch: IWIKI_VALIDATE_SECTIONS=0. Fails OPEN on any internal error (always
exit 0 unless a real violation is found) so it can never wedge an edit.
"""
from __future__ import annotations

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iwiki_common as iw  # type: ignore[import-not-found]  # noqa: E402

_DEEP = re.compile(r"^#{3,}\s", re.MULTILINE)
_H1_LINE = re.compile(r"^#\s+\S")
_H2 = re.compile(r"^##\s+", re.MULTILINE)


def _is_wiki_page(path: str) -> bool:
    if not path or not path.endswith(".md"):
        return False
    ap = os.path.abspath(path)
    root = os.path.abspath(iw.WIKI_DIR)
    if not (ap == root or ap.startswith(root + os.sep)):
        return False
    return os.sep + ".iwiki" + os.sep not in ap


def _post_edit_content(tool: str, ti: dict) -> str | None:
    """Resulting file content after the tool runs, or None if underivable."""
    if tool == "Write":
        return ti.get("content") or ""
    path = ti.get("file_path") or ""
    try:
        cur = open(path, encoding="utf-8").read()
    except Exception:
        cur = ""
    if tool == "Edit":
        old, new = ti.get("old_string", ""), ti.get("new_string", "")
        return cur.replace(old, new) if ti.get("replace_all") else cur.replace(old, new, 1)
    if tool == "MultiEdit":
        for e in ti.get("edits", []):
            old, new = e.get("old_string", ""), e.get("new_string", "")
            cur = cur.replace(old, new) if e.get("replace_all") else cur.replace(old, new, 1)
        return cur
    return None


def _blocking_violations(content: str) -> list[str]:
    out: list[str] = []
    if _DEEP.search(content):
        out.append("deep_heading: a heading deeper than ## (###+); flatten to ##")
    h2 = _H2.search(content)
    pre = content[:h2.start()] if h2 else content
    if any(ln.strip() and not _H1_LINE.match(ln) for ln in pre.splitlines()):
        out.append("pre_h2_text: text before the first ## (only a single # H1 allowed)")
    return out


def main() -> int:
    if os.environ.get("IWIKI_VALIDATE_SECTIONS", "1") == "0":
        return 0
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    if data.get("tool_name") not in ("Write", "Edit", "MultiEdit"):
        return 0
    try:
        iw.cd_project()
        ti = data.get("tool_input") or {}
        if not _is_wiki_page(ti.get("file_path") or ""):
            return 0
        content = _post_edit_content(data["tool_name"], ti)
        if content is None:
            return 0
        violations = _blocking_violations(content)
    except Exception:
        return 0  # fail open — never wedge an edit
    if violations:
        reason = ("iwiki section-formation blocked "
                  + os.path.basename(ti.get("file_path") or "page")
                  + ":\n  - " + "\n  - ".join(violations))
        print(reason, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Smoke-test the deep_heading block**

Run:
```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"docs/wiki/x.md","content":"## A\n### too deep\n"}}' \
  | python3 plugin/iwiki/hooks/iwiki-validate.py; echo "exit: $?"
```
Expected: prints `iwiki section-formation blocked x.md:` with a `deep_heading` line; `exit: 2`.

- [ ] **Step 3: Smoke-test the pre_h2_text block**

Run:
```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"docs/wiki/x.md","content":"# T\n\nstray prose before any section\n\n## A\n"}}' \
  | python3 plugin/iwiki/hooks/iwiki-validate.py; echo "exit: $?"
```
Expected: prints a `pre_h2_text` line; `exit: 2`.

- [ ] **Step 4: Smoke-test a clean page passes**

Run:
```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"docs/wiki/x.md","content":"# T\n\n## Overview\nsumm.\n\n## A\nlead.\n"}}' \
  | python3 plugin/iwiki/hooks/iwiki-validate.py; echo "exit: $?"
```
Expected: no output; `exit: 0`.

- [ ] **Step 5: Smoke-test the kill switch**

Run:
```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"docs/wiki/x.md","content":"## A\n### deep\n"}}' \
  | IWIKI_VALIDATE_SECTIONS=0 python3 plugin/iwiki/hooks/iwiki-validate.py; echo "exit: $?"
```
Expected: no output; `exit: 0` (kill switch disables the block).

- [ ] **Step 6: Smoke-test a non-wiki path is ignored**

Run:
```bash
echo '{"tool_name":"Write","tool_input":{"file_path":"src/foo.md","content":"### deep\n"}}' \
  | python3 plugin/iwiki/hooks/iwiki-validate.py; echo "exit: $?"
```
Expected: no output; `exit: 0` (only `docs/wiki/` is validated).

- [ ] **Step 7: Register the hook in `hooks.json`**

In `plugin/iwiki/hooks/hooks.json`, add a `PreToolUse` block inside `"hooks"` (place it before the existing `"PostToolUse"` key):

```json
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/iwiki-validate.py\"",
            "timeout": 10
          }
        ]
      }
    ],
```

- [ ] **Step 8: Validate the JSON**

Run: `python3 -c "import json; json.load(open('plugin/iwiki/hooks/hooks.json'))" && echo OK`
Expected: `OK`.

- [ ] **Step 9: Commit**

```bash
git add plugin/iwiki/hooks/iwiki-validate.py plugin/iwiki/hooks/hooks.json
git commit -m "feat(iwiki): blocking PreToolUse hook for section-formation (kill-switchable, fail-open)"
```

---

## Task 8: Full suite + migration note

**Files:** none (verification + operational note)

- [ ] **Step 1: Run the entire engine test suite**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests -q`
Expected: PASS — all tests green (chunk, config, validate, lint, plus the untouched store/search/related/embed/iwiki_common suites).

- [ ] **Step 2: Re-index this repo's wiki (one-time full re-embed)**

Because every chunk's hash changed (prefix added), the first index re-embeds all chunks. Run from repo root:
```bash
uv run --project plugin/iwiki/engine python3 -m iwiki_engine --wiki-dir docs/wiki index
```
Expected: `indexed: N chunks (0 reused, N embedded), <bytes>`. Note: this sends content to the embedding API (consented egress); requires `IWIKI_LLM_*` config.

> **Legacy-page rollout (corrected post-execution).** The repo's own `docs/wiki/` pages
> predated the convention. Beyond the `missing_overview` *advisory*, they also tripped the
> **BLOCKING** `pre_h2_text` finding (intro prose between the `# H1` and the first `##`) on
> 23 of 24 pages — so once the Task 7 PreToolUse hook is active, edits to those pages would
> have been blocked (`exit 2`) until migrated. This was resolved here, not deferred: all 23
> pages were migrated (fold the intro into a `## Overview` section, leaving only `# H1`
> before the first `##`) so `validate` now reports **0 blocking findings**. Operators of
> other repos: either migrate first, or set `IWIKI_VALIDATE_SECTIONS=0` to disable the hook
> during migration. Remaining `long_lead` advisories (an `## Overview` body may run to
> `summary_max≈400` while the lead cap is 250) are expected and non-blocking.

- [ ] **Step 3: Post-task docs (per project CLAUDE.md)**

Update the iwiki engine wiki page and lint:
```bash
# regenerate the engine page from the changed sources
# (invoke the iwiki-ingest skill on plugin/iwiki/engine/iwiki_engine/chunk.py and validate.py)
uv run --project plugin/iwiki/engine python3 -m iwiki_engine --wiki-dir docs/wiki lint
```
Expected: lint reports no broken `[[refs]]`, no orphan/stale pages (the new `sections` advisories for legacy pages are informational).

---

## Self-Review (completed during authoring)

- **Spec coverage:** A → Task 1; C → Tasks 2–3; B validator → Task 4; B lint fold → Task 5; B subcommand → Task 6; B hook → Task 7; migration + suite → Task 8. All spec sections mapped.
- **Placeholder scan:** no TBD/TODO; every code step shows full code; every run step shows the command + expected output.
- **Type consistency:** `chunk_markdown(file, content, size, overlap, summary_max=400)` signature consistent across Tasks 2/3 and the `__main__` caller; `OVERVIEW_HEADING`/`LEAD_MAX` mirrored (with keep-in-sync comments) between `chunk.py` and `validate.py`; finding dicts `{type, severity, text}` consistent across `validate.py`, `lint` fold, the subcommand, and the hook's inline mirror.
