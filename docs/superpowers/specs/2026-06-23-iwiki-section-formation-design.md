# iwiki section-formation: depth rule, validation, vector annotation

## Overview

Three coupled changes around the notion of a well-formed `##` section in
`docs/wiki/` pages:

- **A** — make the "max depth `##`" norm explicit in the authoring skills (docs).
- **B** — enforce section-formation rules with a blocking `PreToolUse` hook, plus
  fold the same checks into `lint` for non-interactive review.
- **C** — use the section's own structure (page title + heading + lead paragraph)
  to enrich every sub-chunk embedding, so retrieval has document context in each
  vector.

The three are sequenced **A → C → B**: C defines the canonical lead/heading parsing
that B reuses.

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
- `lint.py` checks broken `[[refs]]`, orphans, and stale pages only. **No** check of
  heading depth, lead paragraph, or dropped pre-`##` text.
- iwiki hooks (`bootstrap`, `recall`, `reindex`, `sync`) are all fail-soft and
  **never block** an edit.

## Requirements

### A — explicit depth rule (docs only)

Files: `plugin/iwiki/skills/iwiki-ingest/SKILL.md`,
`plugin/iwiki/skills/iwiki-init/SKILL.md`.

Add to the authoring rules (next to "One `##` section per concept…"):

- Use **only `##`** for sections. `###` and deeper are not indexed as separate
  units — they fold into the parent `##` section.
- Put **no indexable content before the first `##`**, except a single `#` H1 title.
  Text before the first `##` is dropped from the index.

No code change. Zero runtime risk.

### C — annotation prefix in section vectors

File: `plugin/iwiki/engine/iwiki_engine/chunk.py` (refactor `chunk_markdown`).

1. Extract **page_title** once per file: the first `^#\s+` (H1) line before the
   first `##`; fallback to a humanized form of the file's basename.
2. Per section, compute `heading`, `body`, and `lead` = the section's first
   paragraph (body up to the first blank line), truncated to **≤250 characters**.
3. Build `prefix = "# {page_title}\n## {heading}\n{lead}"` (strip empties).
4. Split the **body** (not `section_text`) into words → overlapping sub-chunks with
   the existing `size`/`overlap` logic (unchanged).
5. Each sub-chunk's embedded text = `prefix + "\n\n" + " ".join(piece)`.
6. Hash on the **final** text (`_hash(text)`), so reuse correctly invalidates when
   the prefix changes.

Effects:
- Fixes the lost-heading-in-sub-chunks-1+ quirk: every sub-chunk now carries page
  title + section heading + lead.
- Reuse is intact within a section. Editing a section's lead re-embeds only that
  section; editing the page H1 re-embeds the whole page.
- **Migration:** the first `index` after this change is a full re-embed (every hash
  changed). One-time cost — surface it in the ingest/init report.
- Minor: sub-chunk 0 contains the lead twice (in the prefix and at the start of the
  body). Harmless for embeddings; not deduplicated.

### B — blocking section-formation validation

Shared validator (engine, config-free): new
`plugin/iwiki/engine/iwiki_engine/validate.py`, `validate_page(content) -> list[finding]`,
stdlib-only (same contract as `lint.py`). Finding types:

| Type | Condition |
|------|-----------|
| `deep_heading` | a line matching `^###+\s` |
| `pre_h2_text` | non-empty content before the first `##`, other than a single `# H1` line |
| `missing_lead` | a `##` section whose first paragraph is empty |
| `long_lead` | a section's first paragraph > 250 characters |

- Fold these findings into `lint.lint()` so they show in `/iwiki-lint`.
- Add a `validate` subcommand (config-free, like `lint`/`status`).

Blocking hook: new `plugin/iwiki/hooks/iwiki-validate.py`, `PreToolUse` on
`Write|Edit|MultiEdit`.

- Acts only on paths inside `docs/wiki/` (excluding the `.iwiki/` index dir).
- Mirrors the heading/lead regexes inline (same convention as `iwiki-reindex.py`
  mirroring `_H2`), so it needs no engine/`uv` spawn on every edit.
- **Blocks (exit 2)** only on structural violations that break the index:
  `deep_heading` and `pre_h2_text`. `missing_lead` / `long_lead` are **advisory**
  (surfaced via `lint`), not blocking — they are quality nits, not index-correctness
  bugs.
- Kill-switch: `IWIKI_VALIDATE_SECTIONS=0`. **Fail-open** on any internal error
  (same posture as `idd-gate.py`).
- Register in `plugin/iwiki/hooks/hooks.json` under a new `PreToolUse` block.

This deviates from iwiki's "hooks never block" convention — an explicit choice. The
kill-switch and fail-open posture bound the blast radius.

## Testing

- `plugin/iwiki/engine/tests/test_validate.py` (new): one case per finding type plus
  a clean page producing no findings.
- `plugin/iwiki/engine/tests/test_chunk.py` (update): prefix present in **every**
  sub-chunk; heading present in every sub-chunk; hash changes when title or lead
  changes; body word-splitting unchanged vs. the old slice boundaries.
- `plugin/iwiki/engine/tests/test_lint.py` (update): section findings folded into the
  lint report.
- Hook smoke test (manual, mirrors the `block-secrets` pattern in CLAUDE.md):
  ```bash
  echo '{"tool_name":"Write","tool_input":{"file_path":"docs/wiki/x.md","content":"## A\n### too deep\n"}}' \
    | python3 plugin/iwiki/hooks/iwiki-validate.py; echo "exit: $?"
  ```
  Expect a block (exit 2) naming the `deep_heading` violation.

## Implementation order

1. **A** — docs rule in both authoring skills.
2. **C** — `chunk.py` refactor + `test_chunk.py` update. Defines canonical
   lead/heading parsing.
3. **B** — `validate.py` + `lint` fold + `validate` subcommand + blocking hook +
   `hooks.json` registration + `test_validate.py` + `test_lint.py` update.

## Post-task (per project CLAUDE.md)

- Update `docs/wiki/` via `iwiki:iwiki-ingest` for the changed engine/hooks.
- Run `/iwiki-lint` — no broken `[[refs]]`, no orphan/stale pages.

## Rejected alternatives

- **C: LLM-generated article summary** as the prefix — cost per page, summary
  storage + staleness, and any page edit forces a full re-embed.
- **B: advisory-only `lint` / `sync`-hook nag** — chosen blocking `PreToolUse`
  instead, per explicit decision.
