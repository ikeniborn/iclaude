---
chain:
  intent: null
review:
  spec_hash: 3802024b5343a98e
  last_run: 2026-06-20
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - id: F-001
      phase: coverage
      severity: WARNING
      section: "### 5. Versioning + docs"
      section_hash: 7a02e5cad1f9885f
      text: >-
        Decision 5 says to "update the project CLAUDE.md ... the 'NO lint subcommand'
        line is obsolete", but that exact line ("CLI exposes ONLY index | search |
        related | status ... there is NO lint subcommand") lives in the GLOBAL isolated
        CLAUDE.md (.nvm-isolated/.claude-isolated/CLAUDE.md line 32), not the project
        CLAUDE.md. The project root CLAUDE.md contains no such enumeration. Section 4
        edits the same global file but only for the "mandate" steps (lines 7/13/24-29),
        not line 32. As written the obsolete-line edit is mis-routed and the real line
        may be left stale. Fix: retarget the line-32 update to the global isolated
        CLAUDE.md (fold into Section 4) or correct the file reference in Section 5.
      verdict: accepted
      verdict_at: 2026-06-20
      resolution: >-
        Resolved. Body re-edited: §Design 4 now explicitly targets the global isolated
        .nvm-isolated/.claude-isolated/CLAUDE.md and adds a bullet to update the stale
        "exposes ONLY index | search | related | status ... NO lint subcommand"
        enumeration. §Design 5 now states the correction lives in §Design 4 and that the
        project root CLAUDE.md needs no such edit (it has no engine-subcommand
        enumeration). Verified: grep finds the obsolete line only in the global file
        (line 32), none in the project root CLAUDE.md. Section hash changed
        78ddd6ffe25bc0c0 -> 7a02e5cad1f9885f.
    - id: F-002
      phase: clarity
      severity: INFO
      section: "### 2. Skill `iwiki-lint` — rewrite to call the engine"
      section_hash: 08ef5a33e15ad674
      text: >-
        The advisory "gaps" pass is described as "a short heuristic pass over top-level
        source areas (lib/, root entry-points) with no page" but gives no DoD / explicit
        boundary for what counts as a top-level source area in an arbitrary project. It
        is explicitly optional/advisory, so this is informational only — but the term is
        unbounded for a universal (foreign-project) skill.
      verdict: accepted
      verdict_at: 2026-06-20
      resolution: >-
        Resolved. §Design 2 now bounds "source area" to the same set iwiki-init uses:
        immediate subdirs of src/ / lib/ / app/ / packages/ / cmd/ plus root entry-point
        scripts that exist — so the term is no longer open-ended for a foreign project.
        Section hash changed 5ca1008da876442f -> 08ef5a33e15ad674.
---

# iwiki: robustness in projects without docs/wiki/

**Date:** 2026-06-20
**Status:** design
**Topic:** iwiki plugin fails (exit 2) when run in a project that has no `docs/wiki/`

## Problem

When the iwiki plugin is enabled globally and a session opens in a *different*
project that has no `docs/wiki/`, an iwiki operation fails hard:

```
indexed: 0 chunks (0 reused, 0 embedded), 0 bytes
=== status ===
{"chunks": 0, "files": 0, "bytes": 0, "over_cap": false}
=== orphan recheck ===
ugrep: warning: *.md: No such file or directory     # exit 2
```

The error surfaces to the user and blocks the turn.

## Root cause

Two compounding defects:

1. **No precondition guard for an absent/empty wiki.** The `iwiki-lint` skill (and
   the lint step inside `iwiki-init`) describes its orphan / broken-link checks in
   *prose*. The model composes the shell itself — typically `index` → `status` →
   an `ugrep '*.md'` "orphan recheck". With no `docs/wiki/` present, `ugrep`/`grep`
   exit `2` on "no files matched / file not found", and bash surfaces that as a
   hard error. The engine parts run fine (they already tolerate an empty wiki and
   report `0 chunks`); the failure is entirely in the model-composed grep step.

2. **iwiki activates in projects that never opted in.** The SessionStart bootstrap
   nudge fires in any project with documentable source, and the global isolated
   `CLAUDE.md` mandates running `/iwiki-lint` / `iwiki-ingest` "after every change"
   in *any* project. Together they push the assistant to run iwiki where there is
   no wiki, triggering defect (1).

The other hooks are already guarded: `iwiki-recall` returns early on
`not index_exists()`, `iwiki-sync` (Stop) returns early on `not wiki_present()`,
`iwiki-reindex` only acts on wiki-page edits. The gap is the skill side.

## Decisions (locked)

- **Scope:** opt-in / stay quiet. iwiki does not produce errors where there is no
  `docs/wiki/`; the bootstrap nudge stays as a soft `/iwiki-init` suggestion.
- **lint mechanism:** move the deterministic checks into the engine as a real
  `lint` subcommand. The skill calls it and formats the JSON — no model-composed
  shell, so the exit-2 class is eliminated at the source.
- **gaps check:** stays advisory in the skill (it needs source-tree heuristics the
  universal engine should not embed).
- **global CLAUDE.md:** make the iwiki mandate conditional on `docs/wiki/` existing.

## Design

### 1. Engine: new `lint` subcommand (config-free)

Add `lint` to `iwiki_engine.__main__` alongside `index | search | related |
status`. Like `status`, it makes **no embedding call** and needs no
`IWIKI_LLM_*` config, so it runs anywhere.

Behaviour:

- **Wiki absent or empty** (`docs/wiki/` missing, or no `*.md` outside `.iwiki/`):
  print `{"wiki_present": false}` and **exit 0**. This is the core fix — absence is
  a clean no-op, never an error.
- **Wiki present:** run the deterministic, wiki-only checks and print a JSON report,
  **exit 0**:
  - **broken-links** — for every `[[target#Heading]]` in every page, resolve the
    target file (slug → `<wiki>/<slug>.md`, or a path already ending in `.md`) and,
    when a `#Heading` is given, confirm a matching `## Heading` exists in that file.
    Reuses `links.parse_links` (split its result on the first `#`) and `chunk._H2`
    (to enumerate a page's `## headings`). A link with no `#Heading` only checks
    file existence.
  - **orphans** — pages no *other* page links to (resolved target set).
  - **stale** — read `.iwiki/log.jsonl`; for each `{source, page}` record where both
    paths still exist, flag the page when `mtime(source) > mtime(page)`. mtime-based,
    no git dependency. Deduped by page.

JSON shape:

```json
{"wiki_present": true,
 "pages": 12,
 "broken":  [{"page": "docs/wiki/a.md", "ref": "b#Missing"}],
 "orphans": ["docs/wiki/x.md"],
 "stale":   [{"page": "docs/wiki/y.md", "source": "lib/y.sh"}]}
```

The engine stays dependency-free (no new deps; no git). A genuine config/engine
HALT still exits non-zero with `HALT:` — only the *missing-wiki* case is the new
clean exit.

### 2. Skill `iwiki-lint` — rewrite to call the engine

Replace the prose checks with: resolve `ENG` (existing 3-tier fallback) → run
`lint` → parse the JSON → print a grouped markdown report (broken / orphans /
stale, with `file#Heading` references) and a one-line summary count. No `ugrep`,
no composed glob.

- `wiki_present: false` → print one line ("no `docs/wiki/` here — run `/iwiki-init`
  to create one") and stop.
- **gaps** (advisory) — only when the wiki is present: a short heuristic pass over
  top-level source areas with no page. Bounded to the same set `iwiki-init` uses —
  immediate subdirs of `src/`/`lib/`/`app/`/`packages/`/`cmd/` plus root entry-point
  scripts that exist — so "source area" is not open-ended in a foreign project.
  Kept in the skill, clearly optional.

### 3. Opt-in guards in the other skills

`iwiki-query` and `iwiki-ingest`: add a precondition at the top of their bash —
if `docs/wiki/` is absent, print a one-line hint and `exit 0` (do not spin up the
engine). `iwiki-init` is the only skill that legitimately runs without a wiki (it
creates it) — left as-is. Hooks already guarded; the bootstrap nudge stays.

### 4. Global isolated CLAUDE.md mandate

In the global isolated `.nvm-isolated/.claude-isolated/CLAUDE.md`:

- Make the "Getting Started" and "Keep Docs Current (MANDATORY)" iwiki steps
  **conditional on `docs/wiki/` existing** in the current project. Removes the
  original trigger in foreign projects.
- Update the now-stale engine-CLI enumeration ("exposes ONLY
  `index | search | related | status` … there is NO `lint` subcommand"): the engine
  now exposes `index | search | related | status | lint`, and lint is engine-side.

(Editing the user's private global instructions — done with explicit consent.)

### 5. Versioning + docs

- Bump plugin `0.5.3 → 0.5.4` (`plugin/iwiki/.claude-plugin/plugin.json`). The
  cache key is the version, so a bump resyncs the in-cache copy.
- Update `docs/wiki/iwiki.md` via `iwiki:iwiki-ingest`; run `/iwiki-lint` (now the
  engine subcommand).
- The stale "NO lint subcommand" enumeration is corrected in §Design 4 (it lives
  in the global isolated `CLAUDE.md`, not the project root `CLAUDE.md` — the latter
  has no engine-subcommand enumeration, so no edit is needed there).

## Out of scope

- Auto-bootstrapping a wiki in foreign projects (egress consent; the soft nudge
  stays).
- A marker-file opt-in mechanism (`.iwiki-enabled`) — not needed once the guards
  and conditional mandate are in place.
- Moving `gaps` or any source-tree heuristic into the engine.

## Testing / success criteria

1. **No-wiki no-op:** `iwiki_engine --wiki-dir <tmp-without-wiki> lint` →
   `{"wiki_present": false}`, exit 0.
2. **Empty wiki:** `docs/wiki/` exists but holds no `*.md` → same clean result.
3. **Healthy wiki (iclaude):** `lint` returns broken/orphans/stale arrays, exit 0.
4. **Broken ref detection:** inject `[[nonexistent#Heading]]` into a temp page →
   it appears in `broken`.
5. **Stale detection:** `touch` a logged source newer than its page → appears in
   `stale`.
6. **Skill bash:** `bash -n` over every edited skill bash block; manual run of the
   rewritten `iwiki-lint` against a no-wiki dir prints the hint and exits 0.
