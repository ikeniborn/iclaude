---
review:
  spec_hash: 912ca31ec8396669
  last_run: 2026-06-17
  chain:
    intent: docs/superpowers/intents/2026-06-17-iwiki-intent.md
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  section_hashes:
    Summary:                                                941f3f12689bbc41
    Key decisions:                                          4473de6c34f9ee44
    File layout:                                            abbf7778469c64ea
    Components:                                             a92f2b86341b4222
    "Engine (Python + uv) — does ONLY embed + search":      2f897e242d204068
    "Skills (Claude = brain)":                              4ae03ad686879b1c
    Commands:                                               ccefe1af2afeb7b5
    Hooks:                                                  317cb274237ea70c
    Install:                                                1e868e8afc0c2d54
    Data flow:                                              55ddbcc270c9e93f
    "Migration: lat → iwiki":                               69095667429384dc
    Error handling & stop rules:                            9d743f4618135532
    Health metrics (from intent):                           c06cb0c4fa34d7cb
    Out of scope (v1):                                      b80297b960d9a0bf
    "Verification (no functional tests — project rule)":    ff71d70a00c27785
  findings:
    - id: F-001
      phase: coverage
      severity: WARNING
      section: Key decisions
      section_hash: 4473de6c34f9ee44
      text: >-
        The intent's Hard constraint reads "Backend is switchable: Anthropic AND
        OpenAI-compatible ... for both generation and embeddings." The spec
        narrows this to OpenAI-compatible only ("No backend enum"). The narrowing
        is defensible (Anthropic exposes no embeddings endpoint), but the spec
        does not explicitly note that it drops the Anthropic backend named in the
        intent. State the divergence (and its rationale) so coverage is traceable.
      verdict: fixed
      verdict_at: 2026-06-17
    - id: F-002
      phase: consistency
      severity: INFO
      section: Health metrics (from intent)
      section_hash: c06cb0c4fa34d7cb
      text: >-
        Index size cap is stated as "~8 MB" in §Components/§Error handling
        (`status` warns above ~8 MB) but as "≤ ~8 MB" in §Health metrics, while
        the intent's target is "≤ ~10 MB". All are soft caps and roughly aligned,
        but the 8 vs 10 MB figures differ between spec and intent. Align on one
        number or note 8 MB as the tightened spec target.
      verdict: fixed
      verdict_at: 2026-06-17
---

# Design: iwiki — embedding-based documentation agent replacing lat.md

**Date:** 2026-06-17
**Status:** draft (awaiting user review)
**Intent:** [docs/superpowers/intents/2026-06-17-iwiki-intent.md](../intents/2026-06-17-iwiki-intent.md)

## Summary

iwiki replaces `lat.md` (external Node binary + MCP server) with a self-contained
documentation agent shipped as an in-repo Claude Code plugin. Claude is the brain:
skills drive ingest/query/lint reasoning and content generation. A thin Python
engine does only what Claude cannot — call the embedding API and run vector search
over an index. The wiki lives in `docs/wiki/` (hard rule); the index is committed to
git.

## Key decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Architecture | Skill-driven + thin embedding engine | Claude reasons/generates; engine = embed + ANN only. Minimal duplicated logic. |
| Engine runtime | Python 3.12 + uv | Reuses the `lib/graphify` install pattern; uv already present. |
| Index storage | JSONL + int8-quantized vectors | git-diffable, no binary blobs, brute-force cosine is fine for the iclaude docs size. |
| Chunking | Split on `##` only; chunks never cross section boundaries; overlapping sub-chunks within a long section | Stable section units; overlap preserves context for long sections without leaking across topics. |
| Related articles | Vector neighbours, fallback to `[[refs]]` graph | Semantic first; explicit links cover what embeddings miss. |
| Ingest semantics | Generate wiki from source (obsidian-ai-wiki style) | Full replacement: produces docs + index, not just an indexer. |
| Wiki location | `docs/wiki/` — **hard rule** | Single canonical home for all wiki content. |
| Packaging | In-repo `plugin/iwiki/` + repo-root marketplace | Develop and publish from one place. |
| External API config | `IWIKI_LLM_BASE_URL` + `IWIKI_LLM_KEY` + `IWIKI_EMBED_MODEL` | OpenAI-compatible endpoint; base URL covers any provider. No backend enum. **Divergence from intent:** the intent named "Anthropic AND OpenAI-compatible" backends; we drop the Anthropic-native path because Anthropic exposes no embeddings endpoint. An Anthropic-compatible gateway is still reachable via `IWIKI_LLM_BASE_URL`. |
| lat → iwiki migration | No migration — regenerate wiki from source | Clean cutover; no stale hand-written carry-over. |

## File layout

```
plugin/iwiki/
  .claude-plugin/plugin.json        # plugin manifest
  skills/
    iwiki-ingest/SKILL.md
    iwiki-query/SKILL.md
    iwiki-lint/SKILL.md
  commands/
    iwiki-ingest.md                 # /iwiki-ingest
    iwiki-query.md                  # /iwiki-query
    iwiki-lint.md                   # /iwiki-lint
  hooks/                            # optional UserPromptSubmit hint ("run iwiki-query first")
  engine/                           # Python + uv thin engine
    pyproject.toml
    iwiki_engine/...
.claude-plugin/marketplace.json     # repo root; source: "./plugin/iwiki"
lib/iwiki/install.sh                # --install-iwiki (uv, Python 3.12; graphify pattern)
docs/wiki/                          # HARD RULE: all wiki content lives here
docs/wiki/.iwiki/index.jsonl        # committed embedding index
docs/wiki/.iwiki/log.jsonl          # ingest operation log
```

## Components

### Engine (Python + uv) — does ONLY embed + search

A thin CLI (`iwiki-engine`) with no LLM reasoning. Subcommands:

- `index <wiki-dir>` — split `docs/wiki/*.md` on `##` headings into sections (lat
  style: leading paragraph + body). Sections never overlap across boundaries. A
  section longer than `IWIKI_CHUNK_SIZE` is split into overlapping sub-chunks
  (`IWIKI_CHUNK_OVERLAP`); short sections stay a single chunk. Embed each chunk's
  full text, hash `heading + body`, write `index.jsonl`, drop entries for removed
  chunks. Incremental: unchanged chunks (matching hash) are not re-embedded.
- `search "<query>" [-k N] [--threshold T]` — embed the query, brute-force cosine
  over the index, print JSON: `[{id, file, heading, score}]`. Returns up to
  `IWIKI_TOP_K` (default 8) results above `IWIKI_SCORE_THRESHOLD` (default 0.2).
- `related <section-id>` — nearest neighbours by vector similarity; falls back to
  traversing the `[[refs]]` link graph up to `IWIKI_GRAPH_DEPTH` hops when vector
  neighbours are sparse (powers "related articles").
- `status` — index size, chunk count, staleness (chunks whose source hash drifted);
  warns if the index exceeds the ~8 MB cap.

**Index entry (JSONL, one line per section):**

```json
{"id": "docs/wiki/architecture.md#Entry Point", "file": "docs/wiki/architecture.md",
 "heading": "Entry Point", "chunk": 0, "hash": "<sha of heading + body>",
 "dim": 1536, "scale": 0.0123, "q": [/* int8 quantized vector */]}
```

A single-chunk section uses `chunk: 0`; a long section split into sub-chunks gets
`chunk: 0,1,2…` under the same `heading`.

Vectors are quantized float32 → int8 with a per-vector scale factor, keeping the
committed index small and git-diffable.

**Backend config (OpenAI-compatible):**

```bash
ICLAUDE_IWIKI_LLM_BASE_URL="https://api.openai.com/v1"   # any compatible endpoint
ICLAUDE_IWIKI_LLM_KEY="sk-..."
ICLAUDE_IWIKI_EMBED_MODEL="text-embedding-3-small"
# optional: ICLAUDE_IWIKI_EMBED_DIMENSIONS (default 1536)
```

**Tuning parameters (all optional, sensible defaults):**

| Variable | Default | Meaning |
|----------|---------|---------|
| `IWIKI_CHUNK_SIZE` | 512 (tokens) | Max chunk size within one `##` section before sub-splitting. |
| `IWIKI_CHUNK_OVERLAP` | 64 (tokens) | Overlap between sub-chunks inside a long section. |
| `IWIKI_TOP_K` | 8 | Max results returned by `search`. |
| `IWIKI_SCORE_THRESHOLD` | 0.2 | Minimum cosine score; weaker matches dropped. |
| `IWIKI_GRAPH_DEPTH` | 2 | Max `[[refs]]` hops for the `related` graph fallback. |

Set in `.claude_config` (chmod 600), documented in `docs/CONFIGURATION.md`.

### Skills (Claude = brain)

- **iwiki-ingest** *(Guarded zone)* — Claude reads the source path, generates or
  updates a wiki page in `docs/wiki/` (markdown + `[[refs]]`, lat-compatible style),
  shows a diff, then runs `iwiki-engine index` and appends to `log.jsonl`. Sending
  document content to the embedding API is a consented egress path.
- **iwiki-query** — runs `iwiki-engine search`, reads the returned sections from
  `docs/wiki/`, and answers with source links plus related articles
  (`iwiki-engine related`). Covers all retrieval; no separate search skill.
- **iwiki-lint** *(report-only)* — scans `docs/wiki/` for broken `[[refs]]`, orphan
  pages, stale pages (source changed since the page was written), and gaps (source
  files with no wiki page). Produces a report; makes no edits.

### Commands

`/iwiki-ingest`, `/iwiki-query`, `/iwiki-lint` — thin slash commands that invoke the
matching skill.

### Hooks

- Optional `UserPromptSubmit` hint analogous to lat's "run lat search first",
  nudging "run iwiki-query/search before starting work".
- The engine reads only `docs/wiki/` and the explicitly passed source path; it
  refuses paths matching secret patterns. Existing `block-secrets` / `redact-secrets`
  PreToolUse hooks are untouched and still apply.

### Install

`./iclaude.sh --install-iwiki` — installs the engine via uv + Python 3.12, mirroring
`lib/graphify/install.sh`. Lazy / on-demand — no cost added to `iclaude.sh` startup.

## Data flow

```
ingest:  source path → Claude generates → docs/wiki/page.md (diff shown, consented)
                     → iwiki-engine index (embed changed sections) → index.jsonl + log.jsonl

query:   question → iwiki-engine search (embed query, cosine) → top-k section ids
                  → Claude reads those sections from docs/wiki/ → answer + [[links]] + related
```

## Migration: lat → iwiki

One-way cutover, proposal-first (per intent Autonomy Zones).

- **Phase A — build alongside lat (no removal).** Implement the plugin + engine.
  Generate `docs/wiki/` fresh from the iclaude sources via `iwiki-ingest` (no content
  carried over from `lat.md/`). Verify `/iwiki-query` and `/iwiki-lint` work over the
  iclaude docs and that `iclaude.sh` starts with no regression.
- **Phase B — cutover (HUMAN CHECKPOINT).** Remove `lib/lat/`, the lat skills
  (`lat-search`, `lat-check`, `lat-init`, `lat-md`, `update-docs`), the
  `--install-lat` / `--lat-*` flags, and the lat MCP wiring. Rewrite the CLAUDE.md
  post-task checklist (lat → iwiki) and the lat-md reference section. Delete
  `lat.md/`. This is irreversible — requires explicit approval.

## Error handling & stop rules

- Missing `IWIKI_LLM_KEY` / `IWIKI_LLM_BASE_URL`, or unreachable backend → engine
  exits non-zero; the skill halts with a clear message (intent Stop Rule).
- `iwiki-ingest` proposing to delete an existing wiki page → escalate, no
  auto-delete (intent Stop Rule).
- Index exceeds the ~8 MB cap → `status` warns; ingest still succeeds.

## Health metrics (from intent)

- Startup speed — lazy load, no `iclaude.sh` regression.
- Isolation — everything under `.nvm-isolated/` / the repo; no leaks into other
  projects' `.claude/`.
- Privacy — document egress to the embedding API is consented, not silent.
- Repo size — int8 quantization + per-section granularity keep the index ≤ 8 MB.
  This 8 MB cap is a deliberately tightened spec target (the intent's stated target
  is ~10 MB); `status` warns above 8 MB.
- Security hooks keep working — engine never reads secrets, never bypasses hooks.
- Controllability — read scope configurable via env vars and
  `.iwikiinclude` / `.iwikiexclude`.

## Out of scope (v1)

- Dependency graph over docs (intent stretch goal) — only if it does not delay the
  core ingest/query path.
- Permanent lat/iwiki coexistence — the cutover is one-way.
- graphify overlap — graphify (code-structure graph) stays separate.

## Verification (no functional tests — project rule)

- `bash -n` on bash modules; `ruff` + `mypy` on the Python engine.
- Run real commands: `--install-iwiki`, `/iwiki-ingest` a sample source file (inspect
  diff + `index.jsonl`), `/iwiki-query` a question (inspect answer + links),
  `/iwiki-lint` (inspect report), `iwiki-engine status` (inspect size/staleness).
- Confirm `iclaude.sh` starts unchanged with iwiki installed.
