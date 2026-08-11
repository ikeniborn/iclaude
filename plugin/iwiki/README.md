# iwiki

**Your codebase, documented and searchable — automatically.**

iwiki turns source files into a connected knowledge base (`docs/wiki/`) you can
ask questions against in plain language. It reads your code, writes a short
linked page per component, and keeps those pages current as the code changes —
so the team's understanding of *why* the system works the way it does stops
living only in people's heads.

## What you get

- **Ask, don't grep.** "How does auth work?" returns the relevant wiki sections,
  not a wall of file matches.
- **Always-current docs.** When code changes, iwiki flags the affected page and
  offers to refresh it — docs stop rotting silently.
- **A linked map.** Pages reference each other (`[[wiki-links]]`), so one answer
  pulls in its neighbours — the design decisions, not just the syntax.
- **Health checks.** Find broken links, orphaned pages, stale docs, and
  undocumented code in one report.

## How it works

iwiki sends each source file to an **embeddings API** (any OpenAI-compatible
endpoint) to make it semantically searchable. It does **not** rewrite your code
— it only reads source and writes Markdown under `docs/wiki/`.

## Commands

| Command | What it does |
|---|---|
| `/iwiki-init` | Build the whole `docs/wiki/` from scratch — scans sources, generates a page each, indexes. Run once. |
| `/iwiki-ingest <path>` | Generate or refresh the wiki page for one source file/dir, then re-index. |
| `/iwiki-query <question>` | Answer a question from the wiki via semantic search. |
| `/iwiki-lint` | Report wiki health: broken links, orphans, stale pages, doc gaps. |

## Automation (runs by itself)

Once enabled, iwiki works in the background — no command needed:

| When | What happens |
|---|---|
| Session start | Establishes a baseline of what changed since last time. |
| You ask a question | Surfaces matching wiki sections into context. |
| Before a file write | Validates wiki page section structure. |
| After a file write | Marks the wiki for a refresh. |
| Session end | Re-indexes wiki changes and offers to update pages for sources you touched. |

Every automation is fail-soft (never blocks your work) and individually
switchable off — see `IWIKI_AUTO_*` below.

## Setup

### 1. Required — point iwiki at an embeddings API

iwiki halts until these two are set. Export them in your shell profile or
`.claude_config`:

```bash
export IWIKI_LLM_BASE_URL="https://api.openai.com/v1"   # any OpenAI-compatible endpoint
export IWIKI_LLM_KEY="sk-..."                           # your API key
```

### 2. Optional — tune behaviour

All optional. Defaults are sensible; change only if you have a reason.

**Embedding model**

| Variable | Default | Meaning |
|---|---|---|
| `IWIKI_EMBED_MODEL` | `text-embedding-3-small` | Embedding model name. |
| `IWIKI_EMBED_DIMENSIONS` | `1536` | Vector size. Must match the model. |

**What gets documented (scope)**

By default the whole project is in scope. A single `.iwikiignore` file in the
project root narrows it — same syntax as `.gitignore`, applied in **two** places:

- **Index**: drops matching `docs/wiki/*.md` pages from the embedding index.
- **Hooks**: drops matching source files from the "needs a wiki page" nag, so a
  path you exclude from the index also stops pinning the Stop-hook reminder.

Both match against repo-relative paths. Rules:

- One pattern per line; `#` comments and blank lines are ignored.
- Real gitignore semantics (via `pathspec`): a bare name matches at any depth,
  a leading `/` anchors to the root, a trailing `/` matches a directory subtree,
  `!` re-includes, and `**` works as in `.gitignore`.
- The file is read relative to the engine's / hook's working directory (the
  project root). The built-in hard excludes (the wiki itself, tests,
  `CLAUDE.md`/`AGENTS.md`, repo-root `README.md`, …) always apply on top.

```gitignore
# .iwikiignore
command.md            # drop docs/wiki/command.md (index) at any depth
experiments/          # ignore a source subtree (no nag, not indexed)
!docs/wiki/keep.md    # re-include after a broader ignore
```

A commented template is **created on install/update** (`iclaude --install-iwiki`)
at the project root, idempotent — an existing `.iwikiignore` is never touched.
See `.iwikiignore.example` for a fuller reference.

**Search quality**

| Variable | Default | Meaning |
|---|---|---|
| `IWIKI_TOP_K` | `8` | Max results per query. |
| `IWIKI_SCORE_THRESHOLD` | `0.2` | Min similarity to count as a match (0–1). Raise for fewer/tighter hits. |
| `IWIKI_GRAPH_DEPTH` | `2` | How many link-hops to pull in around a hit. |

**Indexing internals** (rarely changed)

| Variable | Default | Meaning |
|---|---|---|
| `IWIKI_CHUNK_SIZE` | `512` | Tokens per indexed chunk. |
| `IWIKI_CHUNK_OVERLAP` | `64` | Token overlap between chunks. |
| `IWIKI_SUMMARY_MAX_CHARS` | `400` | Max length of a page summary. |

**Automation kill-switches** (set to `0` to disable)

| Variable | Default | Disables |
|---|---|---|
| `IWIKI_AUTO_BOOTSTRAP` | `1` | Session-start baseline. |
| `IWIKI_AUTO_QUERY` | `1` | Auto-recall of wiki sections on your prompts. |
| `IWIKI_AUTO_REINDEX` | `1` | Marking the wiki dirty after edits. |
| `IWIKI_AUTO_SYNC` | `1` | Session-end re-index + update prompt. |
| `IWIKI_VALIDATE_SECTIONS` | `1` | Pre-write section-structure check. |
| `IWIKI_SYNC_MAX_ASK` | `2` | *(not a switch)* Times the session-end hook re-asks about the same pending set before yielding. |

**Environment**

| Variable | Default | Meaning |
|---|---|---|
| `UV_BIN` | *(from PATH)* | Path to the `uv` binary, if not on `PATH`. |

## Requirements

- [`uv`](https://docs.astral.sh/uv/) — runs the Python engine (auto-detected on `PATH`, or set `UV_BIN`).
- An OpenAI-compatible embeddings endpoint (`IWIKI_LLM_BASE_URL` + `IWIKI_LLM_KEY`).

## Quick start

```bash
export IWIKI_LLM_BASE_URL="https://api.openai.com/v1"
export IWIKI_LLM_KEY="sk-..."
# then, in your project:
/iwiki-init               # build the wiki once
/iwiki-query "how does X work?"
```

## Versioning

The plugin version lives in two files kept in lockstep — `.claude-plugin/plugin.json`
and the `iwiki` entry in the repo-root `.claude-plugin/marketplace.json`. They
**must** match: Claude Code caches user-scope plugins by version, so a drift would
freeze the cache and stop hook/skill fixes from reaching other projects.

Every version bump is manual: edit both files together. `scripts/bump-changed-plugins.py`
can bump the patch of every plugin whose `source` files changed between two commits, and
`scripts/check-plugin-version-sync.sh` reports a drift between the two files — both are
run by hand now that the `dev` branch and its pre-push hook are gone.
