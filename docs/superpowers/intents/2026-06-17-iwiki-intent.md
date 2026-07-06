---
review:
  intent_hash: b824c2700d8598f0
  last_run: 2026-06-17
  phases:
    structure:    { status: passed }
    completeness: { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
    alignment:    { status: passed }
  section_hashes:
    Objective:         4c12e41248b89127
    Desired Outcomes:  7075db2a168dca33
    Health Metrics:    8ec0b14a5ce087d9
    Strategic Context: 1c6fbe6ce782d0cb
    Constraints:       56a3dc27e26add3e
    Autonomy Zones:    7c942823955546ad
    Stop Rules:        838bb38214341a72
  findings:
    - id: F-001
      phase: clarity
      severity: WARNING
      section: Desired Outcomes
      section_hash: 7075db2a168dca33
      text: >-
        "within N seconds" leaves N unspecified — not measurable. Set a target
        (e.g. < 30s for a typical file) or drop the time bound from the outcome.
      verdict: fixed
      verdict_at: 2026-06-17
    - id: F-002
      phase: clarity
      severity: WARNING
      section: Health Metrics
      section_hash: 8ec0b14a5ce087d9
      text: >-
        "the embedding index ... must stay bounded" has no concrete cap. Name a
        threshold (size or per-doc vector count) so the metric is measurable.
      verdict: fixed
      verdict_at: 2026-06-17
    - id: F-003
      phase: consistency
      severity: WARNING
      section: Objective
      section_hash: 4c12e41248b89127
      text: >-
        "no external dependencies" sits in tension with "embeddings require an
        API". The doc reconciles it (Health Metrics names the API as a consented
        runtime path), but scope the phrase to "no external tooling/binary/MCP"
        to remove the apparent contradiction.
      verdict: fixed
      verdict_at: 2026-06-17
    - id: F-004
      phase: alignment
      severity: INFO
      section: Desired Outcomes
      section_hash: 7075db2a168dca33
      text: >-
        User framed dependency-graph generation as optional ("как вариант"). It
        is not represented as a Desired Outcome. Acceptable (optional), but flag
        for brainstorm to decide in/out of v1 scope.
      verdict: fixed
      verdict_at: 2026-06-17
---

# Intent: iwiki — embedding-based documentation agent replacing lat.md

**Date:** 2026-06-17
**Status:** approved

## Objective

iclaude currently relies on `lat.md` (external Node 22 binary + MCP server) as its documentation
knowledge layer. This is an external dependency that must be installed, kept in PATH, and wired
through MCP/hooks — it is hard to verify, has no semantic embedding search, and its graph is purely
link-based (no meaning-aware retrieval).

iwiki replaces it with a **self-contained, verified documentation agent** that improves project
documentation quality through high-quality wiki processing (ingest/query/lint), **semantic search
via embeddings**, and a more efficient documentation graph — **with no external tooling dependency**
(no installed binary or MCP server like lat.md; the only external call is the embedding/LLM API, a
consented runtime path), fully integrated into the iclaude project. The design is adapted from the
`obsidian-ai-wiki` agent
(ingest/query/lint/fix workflows, domain = source-folder → wiki-folder) but retargeted from Obsidian
to the Claude Code harness, and extended with embedding-based retrieval that the reference agent lacks.

It is needed now because `lat.md` is an external, hard-to-verify dependency, and the project wants a
controlled, embedding-capable documentation agent it owns end-to-end.

## Desired Outcomes

- `/iwiki-ingest <path>` creates/updates wiki pages within seconds (target < 30s for a typical
  source file) and shows a diff of changes
- `/iwiki-query "question"` returns an answer plus links to the source sections in the project docs
- Embedding search finds a section by **meaning** (no exact word match required) and also surfaces
  **related articles** that may influence understanding of the answer
- `lat.md` is removed from dependencies — the project runs on its own iwiki agent
- `/iwiki-lint` produces a report (gaps, outdated content, broken links) over the documentation
- Wiki pages use markdown with `[[...]]` wiki-links (compatible with the familiar lat-style syntax)
- *(optional / stretch for v1)* a dependency graph over the docs is generated and queryable,
  complementing the embedding search — included only if it does not delay the core ingest/query path

## Health Metrics

- **Startup speed of `iclaude.sh`** — the agent must not slow down launch (lazy/on-demand load)
- **Isolation** — everything lives under `.nvm-isolated/`; no leaks into `.claude/` of other open
  projects (the failure mode that removed bwrap in 2026-03)
- **Privacy / API posture** — embeddings require an API; document-content egress to that API is a
  controlled, consented path, not silent
- **Repo size** — the embedding index is committed to git; its size stays bounded by a concrete cap
  (target: index ≤ ~10 MB for the iclaude docs set, e.g. quantized vectors and/or a per-doc vector
  cap) so it never bloats the repository
- **Security hooks (`block-secrets` / `redact-secrets`) keep working** — the agent never reads
  `.env` / secrets, and never bypasses the existing PreToolUse hooks
- **Controllability** — which directories are read is configurable via environment variables and
  `.iwikiinclude` / `.iwikiexclude` files

## Strategic Context

- **Interacts with / replaces:** `lib/lat/` (install.sh, check.sh, mcp.sh, detect.sh) and the lat
  skills (`lat-search`, `lat-check`, `lat-init`, `lat-md`, `update-docs`); the CLAUDE.md post-task
  checklist ("update lat.md + lat-check"); security hooks; status line; isolated environment.
- **iwiki fully replaces lat.md** — `lib/lat/` and the lat skills are removed (no permanent
  coexistence). Migration is a one-way cutover.
- **Independent from graphify** — graphify (code-structure knowledge graph) and iwiki (documentation
  wiki + embedding graph) remain separate, non-overlapping systems.
- **Priority trade-off:** **trust (documentation quality / accuracy) + speed (query / indexing)**.
  Cost (API tokens) is secondary for v1.

## Constraints

### Steering (behavioral guidance)
- Minimalism — reuse the patterns of the existing iclaude modules; no speculative abstraction.
- Documentation and code comments in English; user dialog in Russian.
- Wiki format is markdown with `[[...]]` wiki-links, compatible with the familiar lat syntax.

### Hard (architectural enforcement)
- Implementation language: **Python and/or Node** (embeddings need them); not pure bash.
- Everything installs under `.nvm-isolated/` — no global installs.
- Backend is switchable: **Anthropic** and **OpenAI-compatible** (configurable base URL + API key)
  for both generation and embeddings.
- **No functional tests** (project rule) — only lint / type-check / validation (`bash -n`, `ruff`,
  `mypy`, `tsc --noEmit`, etc.); verify by running real commands.
- Packaged as a **Claude Code plugin** (`plugin.json` + marketplace entry), not only a bash module —
  skills, hooks, and harness wiring included for marketplace publication.

## Autonomy Zones

- **Full autonomy** (reversible, low risk): reading docs, generating embeddings, building/refreshing
  the index, `/iwiki-query`, `/iwiki-lint` reports.
- **Guarded** (log + confidence threshold): `/iwiki-ingest` writing/updating wiki pages — must emit a
  diff and append to an operation log (`.iwiki/log.jsonl`).
- **Proposal-first** (needs approval): removing `lib/lat/` and the lat skills (irreversible project
  change); writing API keys into config.
- **No autonomy** (human only): sending document content to an external API without explicit consent
  (privacy); git commits / pushes.

> These zones OVERRIDE subagent-driven-development's "continuous execution, don't pause" default.
> Any task touching proposal-first / no-go decisions is marked HUMAN CHECKPOINT in the plan.

## Stop Rules

- **Halt if:** the embedding API key is missing or the backend is unreachable.
- **Escalate if:** ingest wants to delete an existing wiki page.
- **Done when:** `/iwiki-ingest` and `/iwiki-query` work over the iclaude docs, `lat.md` is removed
  from dependencies, and `iclaude.sh` starts with no regression.
