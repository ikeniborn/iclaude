---
review:
  plan_hash: 82f6bc2121fd7241
  spec_hash: 5741cfcb62dbeabf
  last_run: 2026-06-22
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings: []
chain:
  intent: docs/superpowers/intents/2026-06-17-iwiki-intent.md
  spec:   docs/superpowers/specs/2026-06-22-iwiki-evaluation-improvements-design.md
---

# iwiki Plugin Improvements (Phase B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the defects found in the iwiki plugin evaluation, add an engine test suite, and harden robustness — without changing search behaviour.

**Architecture:** Pure-Python engine changes under `plugin/iwiki/engine/iwiki_engine/`, a new offline `pytest` suite under `plugin/iwiki/engine/tests/`, one hardening edit to the hook helper `plugin/iwiki/hooks/iwiki_common.py`, documentation alignment in two skills, and content fixes to `docs/wiki/` via the plugin itself.

**Tech Stack:** Python ≥ 3.12, `httpx` (runtime), `pytest` (dev-only), `uv` runner.

**Source spec:** `docs/superpowers/specs/2026-06-22-iwiki-evaluation-improvements-design.md`

## Global Constraints

- Python `>=3.12` (engine `requires-python`).
- Runtime dependencies stay **`httpx>=0.27` only**. `pytest` is added as a **dev-only** dependency group, never to `[project.dependencies]`.
- **No test calls the real embedding API.** All API paths are mocked/monkeypatched or use synthetic vectors.
- Engine and tests run via uv: `uv run --project plugin/iwiki/engine <cmd>`.
- Canonical test command (run from repo root):
  `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests -v`
- Phase A (evaluation) is complete in the spec — this plan implements Phase B only.
- Decoupling from iclaude and marketplace publication are **out of scope** (future spec2).

---

### Task 1: Test scaffold + code-aware link parsing (P1)

The link parser treats `[[...]]` inside code (e.g. bash `[[ $# -gt 0 ]]`) as a wiki-link,
causing false "broken" refs in `lint` and noise in `related`'s graph BFS. Fix the parser
to ignore Markdown code, and stand up the pytest dev dependency + first test file.

**Files:**
- Modify: `plugin/iwiki/engine/pyproject.toml`
- Modify: `plugin/iwiki/engine/iwiki_engine/links.py`
- Create: `plugin/iwiki/engine/tests/test_links.py`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `iwiki_engine.links.parse_links(content: str) -> list[str]` — unchanged signature; now ignores fenced/inline code. Also `iwiki_engine.links._strip_code(content: str) -> str` (internal helper). The pytest dev group + `tests/` directory used by all later tasks.

- [ ] **Step 1: Add the pytest dev dependency group**

In `plugin/iwiki/engine/pyproject.toml`, insert this top-level table immediately before the `[tool.ruff]` line:

```toml
[dependency-groups]
dev = ["pytest>=8"]
```

- [ ] **Step 2: Sync the env and confirm pytest is available**

Run: `uv sync --project plugin/iwiki/engine`
Then: `uv run --project plugin/iwiki/engine pytest --version`
Expected: prints a `pytest 8.x.y` version line, exit 0.

- [ ] **Step 3: Write the failing test**

Create `plugin/iwiki/engine/tests/test_links.py`:

```python
from iwiki_engine.links import parse_links


def test_ignores_fenced_code_block():
    md = (
        "See [[real-page]] for details.\n\n"
        "```bash\n"
        "if [[ $# -gt 0 ]]; then echo hi; fi\n"
        '[[ -d "$LIB_DIR/<name>" ]]\n'
        "```\n"
    )
    assert parse_links(md) == ["real-page"]


def test_ignores_inline_code():
    md = "Use `[[ -d x ]]` in bash, but link to [[guide]] here."
    assert parse_links(md) == ["guide"]


def test_alias_form_returns_target():
    assert parse_links("[[core|the core module]]") == ["core"]


def test_dedup_preserves_order():
    md = "[[a]] then [[b]] then [[a]] again, and [[c]]."
    assert parse_links(md) == ["a", "b", "c"]


def test_section_ref_target_kept_whole():
    assert parse_links("[[nvm#Claude Binary Detection]]") == ["nvm#Claude Binary Detection"]
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_links.py -v`
Expected: `test_ignores_fenced_code_block` and `test_ignores_inline_code` FAIL (current parser returns the bash `[[...]]` tokens too). The other three PASS.

- [ ] **Step 5: Implement the fix**

Replace the entire contents of `plugin/iwiki/engine/iwiki_engine/links.py` with:

```python
"""Parse [[target]] / [[target|alias]] wiki-links from markdown, ignoring code."""
from __future__ import annotations
import re

_LINK = re.compile(r"\[\[([^\]|]+)(?:\|[^\]]*)?\]\]")
# Fenced code: ``` or ~~~ opener, lazily to a matching closer on its own line.
_FENCE = re.compile(r"^[ \t]*(```|~~~).*?^[ \t]*\1[ \t]*$", re.DOTALL | re.MULTILINE)
# Inline code spans: `...`
_INLINE = re.compile(r"`[^`]*`")


def _strip_code(content: str) -> str:
    """Drop fenced code blocks and inline code spans so [[...]] inside code
    (e.g. bash `[[ $# -gt 0 ]]`) is not mistaken for a wiki-link."""
    content = _FENCE.sub("", content)
    content = _INLINE.sub("", content)
    return content


def parse_links(content: str) -> list[str]:
    """Return the target part of every [[...]] link, de-duplicated, order-preserving.
    Links inside Markdown code (fenced or inline) are ignored."""
    seen: dict[str, None] = {}
    for m in _LINK.finditer(_strip_code(content)):
        seen.setdefault(m.group(1).strip(), None)
    return list(seen)
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_links.py -v`
Expected: all 5 tests PASS.

- [ ] **Step 7: Confirm the real-world false positives are gone**

Run: `uv run --project plugin/iwiki/engine python3 -m iwiki_engine --wiki-dir docs/wiki lint`
Expected: the `broken` array no longer contains `"$# -gt 0"` or `-d "$LIB_DIR/<name>"`. (Orphan/stale entries may remain — fixed in Task 6.)

- [ ] **Step 8: Commit**

```bash
git add plugin/iwiki/engine/pyproject.toml plugin/iwiki/engine/iwiki_engine/links.py plugin/iwiki/engine/tests/test_links.py
git commit -m "fix(iwiki): ignore [[...]] inside code when parsing wiki-links"
```

---

### Task 2: Embedding retry with bounded backoff (P5)

`embed_texts` fails on the first transient backend error. Add bounded exponential
backoff for timeouts, connection errors, and HTTP 5xx. 4xx and other errors fail fast.

**Files:**
- Modify: `plugin/iwiki/engine/iwiki_engine/embed.py`
- Create: `plugin/iwiki/engine/tests/test_embed.py`

**Interfaces:**
- Consumes: `iwiki_engine.config.Config` (existing dataclass).
- Produces: `iwiki_engine.embed.embed_texts(cfg, texts) -> list[list[float]]` — unchanged signature, now retries. New module-level `embed._MAX_ATTEMPTS = 3`, `embed._BACKOFF_BASE = 0.5`, and `embed._is_transient(exc) -> bool`. Module imports `time` (monkeypatched in tests).

- [ ] **Step 1: Write the failing test**

Create `plugin/iwiki/engine/tests/test_embed.py`:

```python
import httpx
import pytest
from iwiki_engine import embed as embed_mod
from iwiki_engine.embed import embed_texts, EmbedError
from iwiki_engine.config import Config


def _cfg():
    return Config(base_url="http://x", api_key="k", embed_model="m", dimensions=0,
                  chunk_size=512, chunk_overlap=64, top_k=8, score_threshold=0.2,
                  graph_depth=2, include=[], exclude=[])


class _Resp:
    def __init__(self, data):
        self._data = data

    def raise_for_status(self):
        pass

    def json(self):
        return {"data": self._data}


def test_retries_transient_then_succeeds(monkeypatch):
    calls = {"n": 0}

    def fake_post(*a, **k):
        calls["n"] += 1
        if calls["n"] < 3:
            raise httpx.ConnectError("boom")
        return _Resp([{"index": 0, "embedding": [0.1, 0.2]}])

    monkeypatch.setattr(embed_mod.httpx, "post", fake_post)
    monkeypatch.setattr(embed_mod.time, "sleep", lambda s: None)
    assert embed_texts(_cfg(), ["hello"]) == [[0.1, 0.2]]
    assert calls["n"] == 3


def test_gives_up_after_max_attempts(monkeypatch):
    calls = {"n": 0}

    def fake_post(*a, **k):
        calls["n"] += 1
        raise httpx.ConnectError("down")

    monkeypatch.setattr(embed_mod.httpx, "post", fake_post)
    monkeypatch.setattr(embed_mod.time, "sleep", lambda s: None)
    with pytest.raises(EmbedError):
        embed_texts(_cfg(), ["hello"])
    assert calls["n"] == 3


def test_4xx_not_retried(monkeypatch):
    calls = {"n": 0}
    req = httpx.Request("POST", "http://x/embeddings")

    def fake_post(*a, **k):
        calls["n"] += 1
        resp = httpx.Response(400, request=req)
        raise httpx.HTTPStatusError("bad", request=req, response=resp)

    monkeypatch.setattr(embed_mod.httpx, "post", fake_post)
    monkeypatch.setattr(embed_mod.time, "sleep", lambda s: None)
    with pytest.raises(EmbedError):
        embed_texts(_cfg(), ["hello"])
    assert calls["n"] == 1
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_embed.py -v`
Expected: `test_retries_transient_then_succeeds` FAILS (current code raises `EmbedError` on the first `ConnectError`, so `calls["n"] == 1`, not 3). `test_4xx_not_retried` passes; `test_gives_up_after_max_attempts` fails on the `calls["n"] == 3` assertion.

- [ ] **Step 3: Implement the retry**

Replace the entire contents of `plugin/iwiki/engine/iwiki_engine/embed.py` with:

```python
"""OpenAI-compatible embeddings client. Batches inputs; respects HTTPS_PROXY.

Transient backend failures (timeouts, connection errors, HTTP 5xx) are retried
with bounded exponential backoff before surfacing as EmbedError.
"""
from __future__ import annotations
import time
import httpx
from .config import Config

_MAX_ATTEMPTS = 3
_BACKOFF_BASE = 0.5  # seconds; doubled each retry


class EmbedError(RuntimeError):
    """Raised when the embedding backend is unreachable or errors (stop rule)."""


def _is_transient(exc: httpx.HTTPError) -> bool:
    """Timeouts, connection/transport failures, and HTTP 5xx are worth retrying."""
    if isinstance(exc, httpx.HTTPStatusError):
        return exc.response.status_code >= 500
    return isinstance(exc, httpx.TransportError)


def embed_texts(cfg: Config, texts: list[str]) -> list[list[float]]:
    """Return one float vector per input text. Raises EmbedError on failure."""
    if not texts:
        return []
    url = f"{cfg.base_url}/embeddings"
    payload: dict = {"model": cfg.embed_model, "input": texts}
    if cfg.dimensions:
        payload["dimensions"] = cfg.dimensions
    headers = {"Authorization": f"Bearer {cfg.api_key}"}
    last: httpx.HTTPError | None = None
    for attempt in range(_MAX_ATTEMPTS):
        try:
            resp = httpx.post(url, json=payload, headers=headers, timeout=60.0)
            resp.raise_for_status()
            data = resp.json().get("data", [])
            return [row["embedding"] for row in sorted(data, key=lambda r: r["index"])]
        except httpx.HTTPError as e:
            last = e
            if attempt + 1 < _MAX_ATTEMPTS and _is_transient(e):
                time.sleep(_BACKOFF_BASE * (2 ** attempt))
                continue
            break
    raise EmbedError(f"embedding backend unreachable: {last}") from last
```

Note: in httpx, `TimeoutException` is a subclass of `TransportError`, so the single
`isinstance(exc, httpx.TransportError)` check covers timeouts and connection errors.

- [ ] **Step 4: Run the test to verify it passes**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_embed.py -v`
Expected: all 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add plugin/iwiki/engine/iwiki_engine/embed.py plugin/iwiki/engine/tests/test_embed.py
git commit -m "feat(iwiki): retry transient embedding-backend failures with backoff"
```

---

### Task 3: Hardening — related.py file read + iwiki_common session warning (P5)

Two fail-soft hardening fixes: `related._graph_neighbours` opens files without a guard
(an existing-but-unreadable path raises); and `iwiki_common.read_session` silently
swallows a corrupt state file. Make the first skip unreadable paths, and the second
warn on `stderr` while still returning defaults.

**Files:**
- Modify: `plugin/iwiki/engine/iwiki_engine/related.py`
- Modify: `plugin/iwiki/hooks/iwiki_common.py`
- Create: `plugin/iwiki/engine/tests/test_related.py`
- Create: `plugin/iwiki/engine/tests/test_iwiki_common.py`

**Interfaces:**
- Consumes: `iwiki_engine.store.Record`, `quantize`; `iwiki_engine.related.related`, `_graph_neighbours`; `iwiki_common.read_session`, `session_path`.
- Produces: unchanged public signatures. `_graph_neighbours` now skips paths that raise `OSError` on read. `read_session` now emits one `stderr` warning on a non-`FileNotFoundError` failure.

- [ ] **Step 1: Write the failing tests**

Create `plugin/iwiki/engine/tests/test_related.py`:

```python
from iwiki_engine.store import Record, quantize
from iwiki_engine.related import related, _graph_neighbours


def _rec(id, file, vec):
    scale, q = quantize(vec)
    return Record(id=id, file=file, heading=id.split("#")[-1], chunk=0,
                  hash="h", dim=len(vec), scale=scale, q=q)


def test_vector_neighbours_ranked_and_self_excluded():
    recs = [
        _rec("a.md#A", "a.md", [1.0, 0.0]),
        _rec("b.md#B", "b.md", [0.9, 0.1]),   # close to A
        _rec("c.md#C", "c.md", [0.0, 1.0]),   # orthogonal to A
    ]
    out = related("a.md#A", recs, top_k=2, graph_depth=2)
    ids = [d["id"] for d in out["vector"]]
    assert ids[0] == "b.md#B"
    assert "a.md#A" not in ids


def test_graph_skips_unreadable_path(tmp_path):
    # A path that exists but cannot be read as a file (a directory) must be
    # skipped by the BFS, not raise IsADirectoryError.
    d = tmp_path / "weird.md"
    d.mkdir()
    assert _graph_neighbours(str(d), depth=1) == []
```

Create `plugin/iwiki/engine/tests/test_iwiki_common.py`:

```python
import contextlib
import io
import os
import sys

# iwiki_common lives in the plugin's hooks/ dir, not the engine package.
_HOOKS = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "hooks"))
sys.path.insert(0, _HOOKS)
import iwiki_common  # noqa: E402


def test_read_session_warns_on_corrupt_file(tmp_path, monkeypatch):
    state = tmp_path / "iwiki-session.json"
    state.write_text("{not valid json", encoding="utf-8")
    monkeypatch.setattr(iwiki_common, "session_path", lambda: str(state))
    err = io.StringIO()
    with contextlib.redirect_stderr(err):
        out = iwiki_common.read_session()
    # fail-soft preserved: defaults returned
    assert out["session_id"] == ""
    assert out["count"] == 0
    # no longer silent
    assert "iwiki" in err.getvalue().lower()


def test_read_session_silent_when_absent(tmp_path, monkeypatch):
    missing = tmp_path / "nope.json"
    monkeypatch.setattr(iwiki_common, "session_path", lambda: str(missing))
    err = io.StringIO()
    with contextlib.redirect_stderr(err):
        out = iwiki_common.read_session()
    assert out["session_id"] == ""
    assert err.getvalue() == ""   # absent state is normal — stay quiet
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_related.py plugin/iwiki/engine/tests/test_iwiki_common.py -v`
Expected: `test_graph_skips_unreadable_path` ERRORS/FAILS (current `open(dir)` raises `IsADirectoryError`); `test_read_session_warns_on_corrupt_file` FAILS (current code swallows silently → empty stderr). The two other tests PASS.

- [ ] **Step 3: Fix related.py**

In `plugin/iwiki/engine/iwiki_engine/related.py`, replace the `_graph_neighbours` loop body. Change these lines:

```python
        for f in frontier:
            if not os.path.exists(f):
                continue
            for link in parse_links(open(f, encoding="utf-8").read()):
```

to:

```python
        for f in frontier:
            try:
                content = open(f, encoding="utf-8").read()
            except OSError:
                continue
            for link in parse_links(content):
```

(The `os.path.exists` check is now subsumed by the `try/except` — a missing file raises `FileNotFoundError`, an `OSError`.)

- [ ] **Step 4: Fix iwiki_common.read_session**

In `plugin/iwiki/hooks/iwiki_common.py`, add `import sys` to the import block (after `import subprocess`):

```python
import shutil
import subprocess
import sys
```

Then replace `read_session`:

```python
def read_session() -> dict:
    out = dict(_SESSION_DEFAULT)
    try:
        with open(session_path(), encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            out.update({k: data[k] for k in _SESSION_DEFAULT if k in data})
    except FileNotFoundError:
        pass  # first run: no state yet — expected, stay silent
    except Exception as e:
        print(f"iwiki: ignoring unreadable session state ({e})", file=sys.stderr)
    return out
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_related.py plugin/iwiki/engine/tests/test_iwiki_common.py -v`
Expected: all 4 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add plugin/iwiki/engine/iwiki_engine/related.py plugin/iwiki/hooks/iwiki_common.py plugin/iwiki/engine/tests/test_related.py plugin/iwiki/engine/tests/test_iwiki_common.py
git commit -m "fix(iwiki): skip unreadable files in graph BFS; warn on corrupt session state"
```

---

### Task 4: Characterization tests for chunk / store / search / lint (P2)

Lock the behaviour of the pure engine modules with offline tests. No production code
changes here — these close the coverage gap and guard future edits. The lint test also
adds a page-level regression for P1 (Task 1).

**Files:**
- Create: `plugin/iwiki/engine/tests/test_store.py`
- Create: `plugin/iwiki/engine/tests/test_chunk.py`
- Create: `plugin/iwiki/engine/tests/test_search.py`
- Create: `plugin/iwiki/engine/tests/test_lint.py`

**Interfaces:**
- Consumes: `iwiki_engine.store` (`quantize`, `dequantize`, `cosine`, `Record`), `iwiki_engine.chunk.chunk_markdown`, `iwiki_engine.search.search`, `iwiki_engine.lint.lint`.
- Produces: `tests/test_lint.py` with the `_wiki(tmp_path, pages)` fixture helper, reused/extended in Task 5.

- [ ] **Step 1: Write the store tests**

Create `plugin/iwiki/engine/tests/test_store.py`:

```python
from iwiki_engine.store import quantize, dequantize, cosine


def test_quantize_dequantize_roundtrip():
    vec = [0.1, -0.5, 0.9, -1.0, 0.0]
    scale, q = quantize(vec)
    out = dequantize(scale, q)
    assert all(abs(a - b) <= scale for a, b in zip(vec, out))


def test_quantize_zero_vector():
    scale, q = quantize([0.0, 0.0, 0.0])
    assert q == [0, 0, 0]
    assert scale == 1.0


def test_cosine_identical_is_one():
    assert abs(cosine([1.0, 2.0, 3.0], [1.0, 2.0, 3.0]) - 1.0) < 1e-9


def test_cosine_zero_vector_is_zero():
    assert cosine([0.0, 0.0], [1.0, 1.0]) == 0.0
```

- [ ] **Step 2: Write the chunk tests**

Create `plugin/iwiki/engine/tests/test_chunk.py`:

```python
from iwiki_engine.chunk import chunk_markdown


def test_splits_on_h2_headings():
    md = "intro ignored\n\n## First\nbody one\n\n## Second\nbody two\n"
    chunks = chunk_markdown("f.md", md, size=512, overlap=64)
    assert [c.heading for c in chunks] == ["First", "Second"]
    assert chunks[0].id == "f.md#First"


def test_content_before_first_heading_ignored():
    assert chunk_markdown("f.md", "preamble only, no headings", size=512, overlap=64) == []


def test_long_section_splits_with_overlap_and_indexes():
    body = " ".join(str(i) for i in range(20))
    chunks = chunk_markdown("f.md", f"## H\n{body}\n", size=8, overlap=2)
    assert len(chunks) > 1
    assert all(c.heading == "H" for c in chunks)
    assert [c.chunk for c in chunks] == list(range(len(chunks)))
```

- [ ] **Step 3: Write the search tests**

Create `plugin/iwiki/engine/tests/test_search.py`:

```python
from iwiki_engine.store import Record, quantize
from iwiki_engine.search import search


def _rec(id, vec):
    scale, q = quantize(vec)
    return Record(id=id, file=id.split("#")[0], heading="H", chunk=0,
                  hash="h", dim=len(vec), scale=scale, q=q)


def test_threshold_filters_low_scores():
    recs = [_rec("a.md#A", [1.0, 0.0]), _rec("b.md#B", [0.0, 1.0])]
    out = search([1.0, 0.0], recs, top_k=10, threshold=0.5)
    assert [d["id"] for d in out] == ["a.md#A"]   # B is orthogonal → filtered


def test_top_k_limits_and_orders_by_score():
    recs = [_rec("a.md#A", [1.0, 0.0]),
            _rec("b.md#B", [0.9, 0.1]),
            _rec("c.md#C", [0.8, 0.2])]
    out = search([1.0, 0.0], recs, top_k=2, threshold=0.0)
    assert [d["id"] for d in out] == ["a.md#A", "b.md#B"]
```

- [ ] **Step 4: Write the lint tests**

Create `plugin/iwiki/engine/tests/test_lint.py`:

```python
import os
from iwiki_engine.lint import lint


def _wiki(tmp_path, pages: dict) -> str:
    wd = tmp_path / "wiki"
    wd.mkdir()
    for name, body in pages.items():
        (wd / name).write_text(body, encoding="utf-8")
    return str(wd)


def test_absent_wiki_is_noop(tmp_path):
    assert lint(str(tmp_path / "nope")) == {"wiki_present": False}


def test_detects_broken_ref(tmp_path):
    wd = _wiki(tmp_path, {"a.md": "## A\nlink to [[missing]] here\n"})
    out = lint(wd)
    assert any(b["ref"] == "missing" for b in out["broken"])


def test_code_fence_ref_not_broken(tmp_path):
    # page-level regression for P1: bash [[...]] in a fence is not a broken ref
    wd = _wiki(tmp_path, {
        "a.md": "## A\n```bash\nif [[ -d x ]]; then :; fi\n```\n[[b]]\n",
        "b.md": "## B\nbody\n",
    })
    assert lint(wd)["broken"] == []


def test_detects_orphan(tmp_path):
    wd = _wiki(tmp_path, {"a.md": "## A\nno links\n", "b.md": "## B\nno links\n"})
    out = lint(wd)
    assert set(out["orphans"]) == {
        os.path.normpath(os.path.join(wd, "a.md")),
        os.path.normpath(os.path.join(wd, "b.md")),
    }
```

- [ ] **Step 5: Run the full suite to verify everything passes**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests -v`
Expected: every test from Tasks 1–4 PASSES (no failures, no errors). `test_code_fence_ref_not_broken` passes because Task 1 fixed the parser.

- [ ] **Step 6: Commit**

```bash
git add plugin/iwiki/engine/tests/test_store.py plugin/iwiki/engine/tests/test_chunk.py plugin/iwiki/engine/tests/test_search.py plugin/iwiki/engine/tests/test_lint.py
git commit -m "test(iwiki): characterization tests for chunk/store/search/lint"
```

---

### Task 5: Config message (P7) + log schema doc & tolerance (P6)

Clarify the missing-config error to name the env vars. The two skills already emit the
canonical log record `{op, source, page, date}`; document that schema explicitly and lock
`lint`'s tolerance of legacy/malformed records.

**Files:**
- Modify: `plugin/iwiki/engine/iwiki_engine/config.py`
- Create: `plugin/iwiki/engine/tests/test_config.py`
- Modify: `plugin/iwiki/engine/tests/test_lint.py` (add one tolerance test)
- Modify: `plugin/iwiki/skills/iwiki-init/SKILL.md`
- Modify: `plugin/iwiki/skills/iwiki-ingest/SKILL.md`

**Interfaces:**
- Consumes: `iwiki_engine.config.Config.load`, `iwiki_engine.lint.lint`, the `_wiki` helper from Task 4.
- Produces: no new public symbols. Error text now contains `IWIKI_LLM_BASE_URL` and `IWIKI_LLM_KEY` plus the phrase "environment variable".

- [ ] **Step 1: Write the failing config test**

Create `plugin/iwiki/engine/tests/test_config.py`:

```python
import pytest
from iwiki_engine.config import Config, ConfigError


def test_missing_config_names_env_vars(monkeypatch):
    monkeypatch.delenv("IWIKI_LLM_BASE_URL", raising=False)
    monkeypatch.delenv("IWIKI_LLM_KEY", raising=False)
    with pytest.raises(ConfigError) as ei:
        Config.load()
    msg = str(ei.value)
    assert "IWIKI_LLM_BASE_URL" in msg
    assert "IWIKI_LLM_KEY" in msg
    assert "environment variable" in msg.lower()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_config.py -v`
Expected: FAILS on the `"environment variable" in msg.lower()` assertion (current message says only "add them to .claude_config"). The two var-name assertions already pass.

- [ ] **Step 3: Fix the config message**

In `plugin/iwiki/engine/iwiki_engine/config.py`, replace the `ConfigError` raise:

```python
        if not base_url or not api_key:
            raise ConfigError(
                f"{url_var} and {key_var} must be set as environment variables "
                "(e.g. exported from .claude_config). Halting."
            )
```

- [ ] **Step 4: Run it to verify it passes**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_config.py -v`
Expected: PASS.

- [ ] **Step 5: Add the log-tolerance test**

Append to `plugin/iwiki/engine/tests/test_lint.py` (add `import json` at the top, after `import os`):

```python
def test_stale_ignores_legacy_and_malformed_log_records(tmp_path):
    wd = _wiki(tmp_path, {"a.md": "## A\nbody\n"})
    iwiki = os.path.join(wd, ".iwiki")
    os.makedirs(iwiki, exist_ok=True)
    with open(os.path.join(iwiki, "log.jsonl"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps({"op": "init", "scope": "x", "note": "legacy"}) + "\n")
        fh.write("not json at all\n")
    out = lint(wd)
    assert out["wiki_present"] is True
    assert out["stale"] == []   # records lacking source/page are tolerated, ignored
```

- [ ] **Step 6: Run the lint tests to verify they pass**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests/test_lint.py -v`
Expected: all lint tests PASS, including the new tolerance test.

- [ ] **Step 7: Document the canonical log schema in both skills**

In `plugin/iwiki/skills/iwiki-init/SKILL.md`, immediately after the `printf ... >> docs/wiki/.iwiki/log.jsonl` block (around line 63), add:

```markdown
   Canonical log record: `{op, source, page, date}` (`note` optional). Use exactly
   these keys — `lint`'s stale check reads `source`/`page` and ignores records
   missing them. Do not introduce alternative keys (e.g. `scope`).
```

In `plugin/iwiki/skills/iwiki-ingest/SKILL.md`, add the same paragraph immediately after its `printf ... >> docs/wiki/.iwiki/log.jsonl` block (around line 47).

- [ ] **Step 8: Commit**

```bash
git add plugin/iwiki/engine/iwiki_engine/config.py plugin/iwiki/engine/tests/test_config.py plugin/iwiki/engine/tests/test_lint.py plugin/iwiki/skills/iwiki-init/SKILL.md plugin/iwiki/skills/iwiki-ingest/SKILL.md
git commit -m "fix(iwiki): clarify config error; document canonical log schema"
```

---

### Task 6: Content fixes + documentation refresh (P3, P4) + final verification

Resolve the live-wiki findings using the plugin itself, refresh the engine's own wiki
page for the Phase B code changes, and verify the whole effort: clean lint + green suite.
This task needs `IWIKI_LLM_*` configured and makes real embedding calls (re-indexing).

**Files:**
- Modify: `docs/wiki/launcher.md` (re-ingest from current source)
- Modify: `docs/wiki/langfuse-capture.md` (re-ingest from current source)
- Modify: one hub page to add an incoming `[[html-report]]` reference (P4)
- Modify: `docs/wiki/iwiki.md` (reflect Phase B engine changes)
- Updated by tooling: `docs/wiki/.iwiki/index.jsonl`, `docs/wiki/.iwiki/log.jsonl`

**Interfaces:**
- Consumes: the `iwiki:iwiki-ingest` skill and the engine `lint`/`index` subcommands.
- Produces: a clean `lint` report (empty `broken`, `orphans`, `stale`).

- [ ] **Step 1: Re-ingest the two stale pages**

Invoke the ingest skill for each stale source (review and accept each diff):
- `/iwiki-ingest lib/launcher/launch.sh`  → updates `docs/wiki/launcher.md`
- `/iwiki-ingest lib/pii-proxy/langfuse_emitter.py`  → updates `docs/wiki/langfuse-capture.md`

- [ ] **Step 2: Pick the best host page for the html-report link**

Run: `uv run --project plugin/iwiki/engine python3 -m iwiki_engine --wiki-dir docs/wiki related "docs/wiki/html-report.md#Reference Recipes"`
Read the top `vector` neighbour's `file`. That page is the most topically related host for the incoming link.

- [ ] **Step 3: Add the incoming reference (P4)**

In the host page chosen in Step 2 (default to `docs/wiki/command.md` if the result is ambiguous), add a natural sentence or a "See also" line containing `[[html-report]]` where it reads sensibly. Keep it to one line; do not restructure the page.

- [ ] **Step 4: Refresh the engine's wiki page for the Phase B changes**

Invoke: `/iwiki-ingest plugin/iwiki/engine`
Review the diff to `docs/wiki/iwiki.md` so it reflects: code-aware link parsing, embedding retry/backoff, and the related/session hardening. Accept the diff.

- [ ] **Step 5: Re-index and run the health check**

Run: `uv run --project plugin/iwiki/engine python3 -m iwiki_engine --wiki-dir docs/wiki index`
Then: `uv run --project plugin/iwiki/engine python3 -m iwiki_engine --wiki-dir docs/wiki lint`
Expected: `broken` is `[]`; `orphans` no longer lists `docs/wiki/html-report.md`; `stale` no longer lists `launcher.md` or `langfuse-capture.md`. If any remain, fix the specific page (re-ingest the named source, or add the missing ref) and re-run.

- [ ] **Step 6: Run the full test suite one last time**

Run: `uv run --project plugin/iwiki/engine pytest plugin/iwiki/engine/tests -v`
Expected: all tests PASS (Tasks 1–5).

- [ ] **Step 7: Bump the plugin version**

In `plugin/iwiki/.claude-plugin/plugin.json`, bump `"version"` from `0.5.5` to `0.6.0` (engine fixes + new test suite + hardening warrant a minor bump).

- [ ] **Step 8: Commit**

```bash
git add docs/wiki plugin/iwiki/.claude-plugin/plugin.json
git commit -m "docs(iwiki): refresh stale pages, fix html-report orphan, bump to 0.6.0"
```

---

## Self-Review

**Spec coverage (spec §5 B1–B5, §6 testing, §7 success criteria):**
- B1 code-aware parsing → Task 1. ✓
- B2 engine test suite (links/chunk/store/search/lint/embed) → Tasks 1, 2, 4. ✓
- B3 embed retry → Task 2; related.py skip + iwiki_common stderr → Task 3. ✓
- B4 log schema (P6) + config message (P7) → Task 5. ✓
- B5 content (P3 stale re-ingest, P4 orphan link) → Task 6. ✓
- §6 testing strategy (offline tests; functional lint re-run; embed retry via mock; related skip test; iwiki_common stderr test) → Tasks 2–6. ✓
- §7 success criteria (lint 0 false broken; stale shrunk; orphan gone; pytest green incl. code-fence case; embed retry tested; log schema; config names env vars) → Tasks 1, 5, 6. ✓
- Doc-currency mandate (CLAUDE.md) for the engine changes → Task 6 Step 4. ✓

**Placeholder scan:** No "TBD/TODO/handle edge cases". Every code step shows full code. The one runtime-determined value (html-report host page) is resolved by an explicit `related` command in Task 6 Step 2 with a concrete default. ✓

**Type/name consistency:** `parse_links`, `_strip_code`, `embed_texts`, `_is_transient`, `_MAX_ATTEMPTS`, `_BACKOFF_BASE`, `_graph_neighbours`, `read_session`, `session_path`, `Record`, `quantize`, `lint`, `_wiki` used consistently across tasks. Test command identical everywhere. ✓
