---
review:
  spec_hash: 5741cfcb62dbeabf
  last_run: 2026-06-22
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - id: F-001
      phase: clarity
      severity: WARNING
      section: "B3 — Robustness hardening (P5)"
      section_hash: e3aa8276e04fa2a0
      text: >-
        Two of B3's three sub-items have no acceptance criterion / DoD. §6 and §7
        only cover the embed.py retry path (via test_embed.py). The
        related.py:29 try/except skip and the iwiki_common.py "replace silent
        except with stderr warning" fixes have no explicit verification in
        Testing Strategy or Success Criteria. Add a check (e.g. a unit/assertion
        that an unreadable file is skipped, and that the swallowed exception now
        emits stderr) or state that they are verified by code review only.
      verdict: fixed
      verdict_at: 2026-06-22
    - id: F-002
      phase: clarity
      severity: WARNING
      section: "B4 — Log schema + config message (P6, P7)"
      section_hash: c1cb9c1acf62efd1
      text: >-
        The config-message fix (P7) in B4 has no acceptance criterion. §7's
        relevant line covers only the log.jsonl schema (P6); the "clarify the
        config.py error to name the env vars" change has no DoD. Add an
        acceptance check (e.g. error text references IWIKI_LLM_BASE_URL /
        IWIKI_LLM_KEY) or note it is verified by inspection.
      verdict: fixed
      verdict_at: 2026-06-22
  chain:
    intent: docs/superpowers/intents/2026-06-17-iwiki-intent.md
---

# iwiki Plugin — Evaluation & Improvements (Phases A + B)

**Date:** 2026-06-22
**Status:** design / awaiting plan
**Scope:** `plugin/iwiki/` (engine, hooks, skills, commands) within the iclaude repo.

## 1. Background

`iwiki` is an in-repo Claude Code plugin (`iwiki@iclaude`, v0.5.5, MIT) that maintains
an embedding-indexed documentation wiki under `docs/wiki/`. Components: a Python
engine (`index|search|related|status|lint`), four automation hooks
(bootstrap/recall/reindex/sync), four skills, and four commands.

This work was triggered by a request to (1) run the installed plugin and evaluate the
effectiveness of every component, (2) identify problem areas, (3) describe improvement
steps, and (4) consider publishing to the official Anthropic marketplace.

By decision during brainstorming, the request is split into two specs:

- **This spec (spec1):** empirical evaluation (Phase A) + concrete improvements (Phase B).
- **Follow-up (spec2):** decouple the plugin from iclaude and publish standalone to the
  official Anthropic marketplace. Only a blocker list is captured here (§8) — no design.

## 2. Goals / Non-goals

**Goals**
- Document an empirical, reproducible assessment of each component (Phase A).
- Fix the concrete defects found, add an engine test suite, and harden robustness
  (Phase B, "Approach 2" from brainstorming).

**Non-goals**
- Decoupling from iclaude or marketplace publication (spec2).
- Search-algorithm tuning (threshold/chunk/re-rank). Retrieval is measurably strong
  (8/8 top-1 correct in the eval below); tuning without a relevance benchmark is
  speculative (YAGNI).

## 3. Phase A — Empirical Evaluation (current state)

Run from repo root with `IWIKI_LLM_*` set in the environment. Engine invocation:
`uv run --project plugin/iwiki/engine python3 -m iwiki_engine --wiki-dir docs/wiki <subcommand>`.

### 3.1 Scorecard

| Component | Verdict | Evidence |
|-----------|---------|----------|
| `status` | OK | `{"chunks":137,"files":23,"bytes":595132,"over_cap":false}` |
| `search` | Strong | 8/8 test queries returned the correct page at rank 1; scores 0.47–0.73 |
| `related` (vector) | OK | neighbours score 0.65–0.70 |
| `related` (graph BFS) | Weak | returns `graph: []` when a section's `[[refs]]` live in a different section (e.g. a trailing "See also"); the graph is file-level while search is section-level |
| `lint` | Works but inaccurate | 2 false-positive "broken" refs, 1 orphan, 2 stale (see §4) |
| `recall` hook | OK | synthetic `UserPromptSubmit` payload injected the correct `oauth.md` sections |
| bootstrap / reindex / sync hooks | OK (static) | loop-safe, fail-soft, individually kill-switchable |

### 3.2 Search relevance battery (rank-1 result per query)

| Query | Rank-1 page | Score |
|-------|-------------|-------|
| OAuth token refresh | `oauth.md#Automatic Token Refresh` | 0.726 |
| PII masking with Presidio | `pii-proxy.md#Masking Levels` | 0.621 |
| Firecracker microVM isolation | `sandbox.md#Configuration Variables` | 0.621 |
| router DeepSeek/OpenRouter/Ollama | `router.md#Status` | 0.487 |
| iwiki embedding model/dimensions | `iwiki.md#Engine Sync (uv)` | 0.508 |
| secrets redaction | `pii-proxy.md#Regex Patterns` | 0.645 |
| status line context/cache | `statusline.md#Data Sources and Capabilities` | 0.671 |
| LSP install (ts/python) | `lsp.md#Installation` | 0.650 |
| caveman compression rules | `caveman.md#Language Preservation` | 0.589 |

Every query's top result is the correct page. Scores plateau near ~0.73 (a property of
the embedding model + int8 quantization), well above the default `0.2` threshold.

## 4. Problem Inventory (prioritized)

| ID | Severity | Problem | Where | Status |
|----|----------|---------|-------|--------|
| P1 | High | `[[...]]` inside fenced/inline code is parsed as a wiki-link, producing false "broken" refs and polluting graph BFS | `engine/iwiki_engine/links.py` | reproduced via `lint` (`[[$# -gt 0]]`, `[[-d "$LIB_DIR/<name>"]]` in `architecture.md`) |
| P2 | High | No tests and no dev dependencies for the engine | `engine/` | confirmed (no `test_*`, no dev deps in `pyproject.toml`) |
| P3 | Medium | Wiki pages lag their sources | `launcher.md`, `langfuse-capture.md` | reported by `lint` stale (detector is correct) |
| P4 | Low | Orphan page (no incoming links) | `html-report.md` | reported by `lint` orphan |
| P5 | Medium | Fragility: no retry on embedding calls; bare `open()` in BFS; silent `except Exception: pass` | `embed.py`, `related.py:29`, `iwiki_common.py` | static audit |
| P6 | Low | `log.jsonl` has no fixed schema (3 distinct key-sets observed: `source`/`page`/`scope`) | skills' log writes → `docs/wiki/.iwiki/log.jsonl` | confirmed |
| P7 | Low | Config error message names `.claude_config` but the values are read from env vars | `config.py` | static audit |

## 5. Phase B — Improvement Design

### B1 — Code-aware link parsing (P1) — core fix

`parse_links` must ignore `[[...]]` that appear inside Markdown code. Preprocess the
content before applying `_LINK`:

1. Strip fenced code blocks (lines delimited by ``` ``` ``` ``` / `~~~`).
2. Strip inline code spans (`` `...` ``).
3. Run the existing `_LINK` regex on the remaining prose.

This fixes both consumers of `parse_links`: `lint` (false broken refs) and `related`'s
graph BFS (precision). Real wiki-links in prose are unaffected.

**Verify:** re-run `lint` → the two bash-syntax broken refs disappear; unit test feeds a
Markdown sample with `[[real-link]]` in prose plus `[[ -d x ]]` in a ```bash fence and
asserts only `real-link` is returned.

### B2 — Engine test suite (P2)

Add a dev dependency group with `pytest` to `engine/pyproject.toml`, and a
`engine/tests/` package. None of the tests call the real embedding API.

- `test_links.py` — fenced/inline stripping (B1), alias form `[[t|a]]`, dedup + order.
- `test_chunk.py` — split on `##`, overlap behaviour, empty input and no-heading input.
- `test_store.py` — int8 quantize↔dequantize roundtrip within tolerance; cosine,
  including the zero-vector → `0.0` edge case.
- `test_search.py` — threshold filtering and top-k ordering using synthetic vectors.
- `test_lint.py` — broken/orphan/stale detection on a temporary wiki fixture.
- `test_embed.py` — `embed.py` against a mocked `httpx` transport (success + retry path).

**Run:** `uv run --project plugin/iwiki/engine pytest`.

### B3 — Robustness hardening (P5)

- `embed.py` — retry transient failures (timeout, connection error, HTTP 5xx) with
  bounded exponential backoff (≤ 3 attempts); preserve the existing `EmbedError` contract
  for terminal failures.
- `related.py:29` — wrap the per-file read in `try/except` and skip unreadable files,
  matching `lint`'s fail-soft behaviour.
- `iwiki_common.py` — replace the silent `except Exception: pass` blocks in session I/O
  and project chdir with a one-line `stderr` warning; keep the fail-soft (never-block)
  behaviour.

### B4 — Log schema + config message (P6, P7)

- Define one canonical `log.jsonl` record: `{op, source, page, date, note?}`. Only
  `iwiki-init` and `iwiki-ingest` write the log; align both skills' log-write steps to
  this shape and document it.
- `config.py` — clarify the error to name the env vars (`IWIKI_LLM_BASE_URL`,
  `IWIKI_LLM_KEY`) as the primary source, with `.claude_config` as the convenience
  location.

### B5 — Content fixes (P3, P4)

- P3 — re-ingest `launcher.md` and `langfuse-capture.md` from their newer sources using
  the plugin itself (`/iwiki-ingest`), then re-run `lint` to confirm they drop off the
  stale list.
- P4 — add an incoming `[[html-report]]` reference from the most relevant hub page
  (`command.md` or `architecture.md`) so the page is no longer an orphan. (Decision:
  add the link rather than declare it standalone.)

## 6. Testing Strategy

- Unit tests (B2) gate engine changes; all run offline (no embedding API).
- Functional verification re-runs the Phase A commands: `lint` (false broken refs gone,
  stale list shrunk), `status`, and the search battery (still rank-1 correct).
- `embed.py` retry is covered by a mocked-failure unit test rather than a live call.
- `related.py`'s unreadable-file skip (B3) is covered by a unit test that points the
  graph BFS at a missing/unreadable file and asserts it is skipped without error.
- `iwiki_common.py`'s replacement of silent `except` with a `stderr` warning (B3) is
  verified by a unit test (corrupt session-state file → defaults returned **and** a
  warning is emitted on `stderr`).

## 7. Success Criteria (acceptance)

- `/iwiki-lint` reports zero false-positive broken refs; `launcher.md` and
  `langfuse-capture.md` no longer appear as stale after re-ingest; `html-report.md` is no
  longer an orphan.
- `uv run --project plugin/iwiki/engine pytest` is green and includes the B1 code-fence
  case plus `store`/`chunk`/`search`/`lint` coverage.
- The `embed.py` retry path is exercised by a test.
- New `log.jsonl` entries conform to the single schema.
- `config.py`'s missing-config error message names `IWIKI_LLM_BASE_URL` and
  `IWIKI_LLM_KEY` (verified by inspection / a string assertion).

## 8. Marketplace Readiness — spec2 pointer (blockers only)

For the eventual standalone publication to the official Anthropic marketplace, the known
blockers to capture in spec2 are:

- A standalone repository with its own `marketplace.json`/plugin manifest, `README`, and
  `LICENSE` (already MIT).
- A self-contained `uv` bootstrap inside the plugin — today the bootstrap lives in
  iclaude's `lib/iwiki/install.sh`; the plugin must install its engine without iclaude.
- CI that runs the new engine test suite (depends on B2).
- A version/changelog policy.

Non-blockers: the engine already reads configuration from environment variables
(`.claude_config` is only a convenience), and the demo wiki's `[[core]]`/`[[nvm]]`/
`[[launcher]]` cross-references are iclaude *content*, not plugin code.

## 9. Out of Scope

- Phase C (decoupling + publication) — spec2.
- Approach 3 search-algorithm tuning (threshold/chunk/re-rank, file-level graph rewrite).
  The only measured weakness, graph-`related` precision, is addressed indirectly by B1.
