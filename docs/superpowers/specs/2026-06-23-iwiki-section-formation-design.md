---
review:
  spec_hash: d359692ad940a1c6
  last_run: 2026-06-23
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - id: F-005
      phase: clarity
      severity: INFO
      section: "Testing"
      section_hash: 2fc6bd8588bd7ed0
      text: >-
        §Testing asserts "body word-splitting is unchanged vs. the old slice
        boundaries". The split *algorithm* (size/overlap arithmetic in
        _split_section) is indeed unchanged, but the *input* differs: the old code
        split section_text = "## {heading}\n\n{body}", whose word stream is
        ["##", <heading words>, <body words>], while §C step 6 splits `body` only.
        For a multi-chunk section the slice boundaries over the body therefore shift
        by (1 + heading-word-count) tokens, so the literal "old slice boundaries" are
        not reproduced. Ambiguous between "algorithm unchanged" (true) and "boundaries
        unchanged" (false); a DoD test written to the literal wording would fail.
        Minor; resolved by clarifying the test asserts the splitting *logic*, not
        identical boundary offsets.
      verdict: open
      verdict_at: null
chain:
  intent: null
---
# iwiki section-formation: depth rule, validation, vector annotation

## Overview

Three coupled changes around the notion of a well-formed `##` section in
`docs/wiki/` pages:

- **A** — make explicit, in the authoring skills (docs), that pages are `##`-only
  and always lead with a `# Title` + a first `## Overview` section that summarizes
  all the page's sections.
- **B** — enforce the structural rules with a blocking `PreToolUse` hook, plus fold
  the same checks into `lint` for non-interactive review.
- **C** — give every content section's vectors whole-article context by prefixing
  each sub-chunk with the page title + the authored `## Overview` body + the section
  heading + the section lead, before embedding.

The three are sequenced **A → C → B**: C defines the canonical Overview / lead /
heading parsing that B reuses.

## Background — current behaviour (verified)

- `chunk.py` splits a page **only** on `##` (`_H2 = ^##\s+`). `###`+ headings are
  **not** section boundaries — they fold into the parent section body. Content
  before the first `##` is **silently dropped** from the index.
- Per section, `section_text = "## {heading}\n\n{body}"` is split by words into
  overlapping sub-chunks (`IWIKI_CHUNK_SIZE=512`, `IWIKI_CHUNK_OVERLAP=64`,
  `step = size - overlap`). The `## {heading}` prefix lands **only in sub-chunk 0**;
  sub-chunks 1+ lose the heading.
- `embed.py` embeds exactly `chunk.text` — **no** page title, summary, or parent
  context is mixed in. There is no "whole-article annotation" in section vectors.
- `index.jsonl` stores per-chunk `Record`s only (`id, file, heading, chunk, hash,
  dim, scale, q`); no chunk text and no page-level annotation are persisted. Reuse in
  `cmd_index` is purely per-chunk by `hash`.
- `lint.py` checks broken `[[refs]]`, orphans, and stale pages only. **No** check of
  heading depth, lead paragraph, dropped pre-`##` text, or a missing Overview.
- iwiki hooks (`bootstrap`, `recall`, `reindex`, `sync`) are all fail-soft and
  **never block** an edit.

## Requirements

### A — explicit depth rule + Overview mandate (docs only)

Files: `plugin/iwiki/skills/iwiki-ingest/SKILL.md`,
`plugin/iwiki/skills/iwiki-init/SKILL.md`.

Add to the authoring rules (next to "One `##` section per concept…"):

- Use **only `##`** for sections. `###` and deeper are not indexed as separate
  units — they fold into the parent `##` section, and **B blocks** their creation.
- Put **no indexable content before the first `##`**, except a single `#` H1 title.
- Every page leads with `# Title` then a **first `## Overview` section** that
  summarizes all of the page's sections in ≈≤400 characters. The authoring model
  (the same iclaude/Claude agent that writes the page) authors this Overview as part
  of normal wiki authoring — **no external/automated summarizer is involved**. The
  engine reuses the Overview body to give every other section's vectors whole-article
  context (see C).

No code change. Zero runtime risk.

### C — annotation prefix from the authored Overview section

File: `plugin/iwiki/engine/iwiki_engine/chunk.py` (refactor `chunk_markdown`). No
LLM call, no new model, no new API endpoint, no cache file — the summary already
lives in the page content as the `## Overview` section.

1. Extract **page_title** once per file: the first `^#\s+` (H1) line before the
   first `##` (later or duplicate `#` lines are ignored); fallback to a humanized
   form of the file's basename. B's `pre_h2_text` already constrains pre-`##` content
   to a single H1, so the engine only sees this documented shape.
2. Identify the **Overview section**: the `##` section whose heading matches the
   reserved name (default `Overview`, case-insensitive). Its body becomes
   `article_summary`, collapsed to a single line and truncated to
   `IWIKI_SUMMARY_MAX_CHARS` (default 400). No Overview section present →
   `article_summary = ""` (graceful; B/lint flags it).
3. **Exclude the Overview section from the index** — it yields no chunks / `Record`s
   of its own; it is consumed *only* as the `article_summary` source. This is fixed
   in the harness: the authoring rules (A) state the section is not indexed, and
   `chunk_markdown` skips it when emitting chunks.
4. Per **content section** (every `##` except Overview), compute `heading`, `body`,
   and `lead` = the section's first paragraph (body up to the first blank line),
   truncated to **≤250 characters**. The `lead` doubles as the **section summary**:
   the per-section digest that binds a split section's sub-chunks together (see
   Effects).
5. Build the prefix:
   `"# {page_title}\n{article_summary}\n## {heading}\n{lead}"` (omit empty lines).
6. Split the **body** (not `section_text`) into words → overlapping sub-chunks with
   the existing `size`/`overlap` logic (unchanged).
7. Each sub-chunk's embedded text = `prefix + "\n\n" + " ".join(piece)`.
8. Hash on the **final** text (`_hash(text)`), so reuse correctly invalidates when
   the prefix (title, Overview, or lead) changes.

Effects:
- Every content vector now carries page title + whole-article summary + section
  heading + section lead. A query distinguishes articles even at the sub-section
  level — the goal.
- The Overview section is **not** a search result on its own; its text reaches the
  index only as the per-section prefix, so article-level queries match the content
  sections (no redundant "Overview" hits).
- **Multi-chunk sections stay bound.** The full prefix — `article_summary` (article
  summary) + `lead` (section summary) + heading — is prepended to **every** sub-chunk
  of a section, not only sub-chunk 0. When a section exceeds the chunk size and splits
  into overlapping pieces, all pieces share identical article- and section-level
  context, so they embed near each other; the word-level `overlap` then bridges
  adjacent pieces. Two sub-chunks of a section are connected by *section summary +
  article summary*.
- Also fixes the lost-heading-in-sub-chunks-1+ quirk: every sub-chunk carries the
  heading.
- Reuse: editing a content section re-embeds only that section; editing the
  `## Overview` changes `article_summary` → re-embeds every content section; editing
  the H1 re-embeds the whole page.
- **Migration:** the first `index` after this change is a full re-embed (every hash
  changed). One-time cost — surface it in the ingest/init report.
- Minor: a content sub-chunk 0 contains its lead twice (in the prefix and at the
  start of the body); the Overview body may also echo a section's lead. Harmless for
  embeddings; not deduplicated.
- Edge: a page with only an Overview and no content sections produces **zero**
  chunks; lint's advisories surface such degenerate pages.

### B — blocking section-formation validation

Shared validator (engine, config-free): new
`plugin/iwiki/engine/iwiki_engine/validate.py`, `validate_page(content) -> list[finding]`,
stdlib-only (same contract as `lint.py`). Finding types:

| Type | Condition | Enforcement |
|------|-----------|-------------|
| `deep_heading` | a line matching `^###+\s` | **blocks** |
| `pre_h2_text` | non-empty content before the first `##`, other than a single `# H1` line | **blocks** |
| `missing_overview` | the first `##` section is not the reserved `Overview` (or none exists) | advisory |
| `missing_lead` | a `##` section whose first paragraph is empty | advisory |
| `long_lead` | a section's first paragraph > 250 characters | advisory |

- Fold these findings into `lint.lint()` so they show in `/iwiki-lint`.
- Add a `validate` subcommand (config-free, like `lint`/`status`).

Blocking hook: new `plugin/iwiki/hooks/iwiki-validate.py`, `PreToolUse` on
`Write|Edit|MultiEdit`.

- Acts only on paths inside `docs/wiki/` (excluding the `.iwiki/` index dir).
- Mirrors the heading/lead regexes inline (same convention as `lint.py`, which
  inlines `chunk._H2` behind a *keep-in-sync* comment to stay stdlib-only), so it
  needs no engine/`uv` spawn on every edit.
- **Blocks (exit 2)** only on structural violations that break the index:
  `deep_heading` and `pre_h2_text`. `missing_overview` / `missing_lead` / `long_lead`
  are **advisory** (surfaced via `lint`), not blocking — they are quality nits, not
  index-correctness bugs.
- Kill-switch: `IWIKI_VALIDATE_SECTIONS=0`. **Fail-open** on any internal error
  (same posture as `idd-gate.py`).
- Register in `plugin/iwiki/hooks/hooks.json` under a new `PreToolUse` block.

This deviates from iwiki's "hooks never block" convention — an explicit choice. The
kill-switch and fail-open posture bound the blast radius.

## Configuration

- `IWIKI_SUMMARY_MAX_CHARS` (default `400`) — cap on the Overview body when used as
  the per-section annotation prefix.
- Reserved Overview heading name (default `Overview`, case-insensitive) — a module
  constant in `chunk.py`/`validate.py` (kept in sync like `_H2`).

No new credentials, model, or endpoint: the existing `IWIKI_LLM_*` embeddings config
is unchanged, and summary generation is **authoring-time**, done by the agent writing
the page — the engine only reads the resulting `## Overview` text.

## Testing

- `plugin/iwiki/engine/tests/test_validate.py` (new): one case per finding type
  (incl. `missing_overview`) plus a clean page producing no findings.
- `plugin/iwiki/engine/tests/test_chunk.py` (update): the Overview body **and** the
  section lead are present in **every** sub-chunk of a multi-chunk content section;
  the Overview section produces **no** chunks (excluded from the index); the heading
  is present in every sub-chunk; the hash changes when the Overview / title / lead
  changes; the body-splitting *logic* (`_split_section` size/overlap arithmetic) is
  unchanged — boundaries do shift because the new code splits `body` alone, not
  `"## {heading}\n\n{body}"`; a page with no `## Overview` yields no summary line
  (graceful).
- `plugin/iwiki/engine/tests/test_lint.py` (update): section findings folded into the
  lint report.
- Hook smoke test (manual, mirrors the `block-secrets` pattern in CLAUDE.md):
  ```bash
  echo '{"tool_name":"Write","tool_input":{"file_path":"docs/wiki/x.md","content":"## A\n### too deep\n"}}' \
    | python3 plugin/iwiki/hooks/iwiki-validate.py; echo "exit: $?"
  ```
  Expect a block (exit 2) naming the `deep_heading` violation. A second case covers
  the other blocking path, `pre_h2_text`:
  ```bash
  echo '{"tool_name":"Write","tool_input":{"file_path":"docs/wiki/x.md","content":"# T\n\nstray prose before any section\n\n## A\n"}}' \
    | python3 plugin/iwiki/hooks/iwiki-validate.py; echo "exit: $?"
  ```
  Expect a block (exit 2) naming the `pre_h2_text` violation.

## Implementation order

1. **A** — docs rule (depth + Overview mandate) in both authoring skills.
2. **C** — `chunk.py` refactor + `test_chunk.py` update. Defines canonical Overview /
   lead / heading parsing.
3. **B** — `validate.py` + `lint` fold + `validate` subcommand + blocking hook +
   `hooks.json` registration + `test_validate.py` + `test_lint.py` update.

## Post-task (per project CLAUDE.md)

- Update `docs/wiki/` via `iwiki:iwiki-ingest` for the changed engine/hooks.
- Run `/iwiki-lint` — no broken `[[refs]]`, no orphan/stale pages.

## Rejected alternatives

- **Index-time LLM summarization** — generating the article summary in the engine at
  `index` time. Rejected: needs a separate chat model (`IWIKI_SUMMARY_MODEL`) and
  endpoint (the embeddings model cannot generate text), adds per-page cost, and
  introduces summary staleness/caching. Superseded by the authored `## Overview`
  section, which costs nothing extra at index time and lives in the page content.
- **Separate `summaries.jsonl` cache file** — unnecessary once the summary is the
  authored `## Overview` section read straight from the page.
- **C: static `lead`-only prefix (no whole-article summary)** — gives section but not
  article context; superseded by the Overview-based prefix.
- **B: advisory-only `lint` / `sync`-hook nag** — chosen blocking `PreToolUse`
  instead, per explicit decision (structural findings only).
