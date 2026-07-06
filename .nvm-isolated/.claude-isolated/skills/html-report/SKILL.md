---
name: html-report
description: "Use when the user asks for a standalone or self-contained HTML report, an offline .html file, a human-readable report that opens by double-click in a browser, expandable/interactive HTML tables, or block / transition / C4 / architectural diagrams rendered in HTML (NOT Mermaid), or a dark/light themed report. Triggers on phrases like 'сделай html-отчёт', 'standalone html report', 'expandable html table', 'C4 diagram as html', 'offline report I can open in browser'. Produces ONE self-contained .html in docs/reports/ with zero external dependencies. NOT for Mermaid diagrams (use mermaid-obsidian) or Mermaid embedded in PRD/architecture docs (use prd-generator / architecture-documentation)."
version: 1.1.0
---

# Standalone HTML Reports

Generate ONE self-contained `.html` file that opens offline by double-click and shows
the requested data as styled tables and CSS diagrams with simple dynamics and a
dark/light theme toggle. Complements `mermaid-obsidian` (machine/context format) by
producing the human-readable artifact.

## Hard Constraints (NEVER violate)

1. **Zero-dependency.** No `<script src>`, no `<link rel=stylesheet href>`, no `src=`
   / `href=` pointing at `http`/`https`/`//`/any CDN, no external images. Everything
   inline.
2. **Offline.** The file must open from `file://` by double-click — no localhost, no
   fetch.
3. **Single self-contained file.** One `.html`, no sibling assets.
4. **Both themes mandatory.** Every report ships dark AND light palettes plus a
   working toggle (see `references/themes.md`).
5. **Output directory.** Default target is `docs/reports/` in the project where the
   skill runs (the current working directory's project root). If the caller passed an
   EXPLICIT output path (e.g. an IDD `check-*` command), write to that path instead.
   Create the target directory if it does not exist. Never invent an unrequested path.
   In `mode: chain` (`references/chain-report.md`) the skill creates/merges the single
   caller-supplied `<topic>-results.html`; an existing such file passed as a merge
   source is caller-supplied (Full zone), NOT a proposal-first default `docs/reports/`
   file.

If faithful display would require an external resource, **escalate** — do not
inline-fetch and do not silently drop the element.

## Workflow

1. Parse the request → list the data points, the named diagrams, and the data sources.
2. Read ONLY the sources the user named. If the source choice is ambiguous, **ask
   first** (proposal-first). If a source is unreadable or contradicts the request,
   **halt** — do not fabricate data (trust is the priority).
3. Pick a recipe per item and read the matching reference file:
   - tables / block / transition / C4 / report components (note, badge, lead) → `references/css-diagrams.md`
   - pipeline / loop / state-machine with labeled, looping, or non-adjacent edges → `references/svg-diagrams.md`
   - any dynamic (expand, hover, animation) → `references/dynamics.md`
   - theme palettes + toggle → `references/themes.md` (always)
   - arbitrary node-edge graph / free connector / data plot → `references/svg-fallback.md`
   - chain report (multi-tab IDD→SDD, `mode: chain`) → `references/chain-report.md`

   **Gold-standard reference** — for the full SVG node grammar, animated connectors, C4,
   two-axis tables, badges, and `.note` callouts, study the in-skill `references/`
   files (`svg-diagrams.md`, `svg-fallback.md`, `css-diagrams.md`) before assembling a
   non-trivial architecture report.
4. Assemble ONE HTML document:
   - `<head>`: a single inline `<style>` (theme custom-props + recipe CSS + dynamics).
   - `<body>`: semantic HTML5 (`<table>` / `<figure>` / `<details>`), the theme-toggle
     control, and EVERY named data point + diagram (drop nothing).
   - Add an SVG / bounded inline `<script>` block ONLY if a node-edge graph needs it,
     and **log** the specific structure CSS could not express.
5. **Self-validate** the assembled string (checklist below) BEFORE writing.
6. Write the file to the target directory — `docs/reports/` by default, or the
   explicit caller-supplied path when one was passed (create the directory if
   missing). If the caller passed the path, overwriting that path is **Full** zone
   (proceed — it is a regenerated artifact). Otherwise, if the target file already
   exists, **ask first** before overwriting (proposal-first).
   In `mode: chain`, do NOT regenerate the whole file: follow the first-run vs.
   update merge flow in `references/chain-report.md` (read the existing
   caller-supplied `<topic>-results.html`, replace only the owned tab's marked
   region, preserve the other three tabs). Creating and merging the unified
   caller-supplied file are both Full zone.
7. Report to the user: file path, file size, and any guarded-zone logs (inline script
   used / size warning).

## Self-Validation Checklist (run before writing)

Reject and fix the assembled HTML if any fails:

- [ ] No `src=` or `href=` referencing `http`, `https`, `//`, or a CDN host.
- [ ] No `<script src=...>` and no `<link rel="stylesheet" href=...>`.
- [ ] Exactly one `.html`, no references to sibling files.
- [ ] Both theme custom-prop sets present AND the toggle control is wired.
- [ ] Every requested data point and every named diagram is present.
- [ ] Flows with retry/branch/non-adjacent edges use the `svg-diagrams.md` grammar
      (node cards + arrow markers), not a flat flex row that drops the loop/branch.
- [ ] Shared `<defs>` (dropshadow + arrow markers) present if any SVG diagram is used.
- [ ] File size ≤ 5 MB — if larger, **warn** the user (soft limit).
- [ ] Output path is under `docs/reports/` OR equals the explicit caller-supplied path — never an unrequested location.

**`mode: chain` only** (see `references/chain-report.md`):

- [ ] All four `<!-- TAB:{intent,spec,plan,result} START/END -->` pairs present, correctly ordered, non-overlapping.
- [ ] Exactly one `.tab-radio` carries `checked` (exactly one active pane).
- [ ] Theme toggle present and its `body:has(#theme-toggle…)` selectors intact alongside the tab `body:has(#tab-…)` selectors.
- [ ] On update: the three non-owned panes are byte-identical to the pre-existing file (only the owned region + the single `checked` attribute changed).

## Autonomy Zones

| Zone | Action |
|------|--------|
| Full — generating HTML, choosing CSS layout, picking the diagram type; writing to an output path EXPLICITLY passed by the calling command, including merging one tab into an existing caller-supplied `mode: chain` file | proceed, no pause |
| Guarded — using inline `<script>`/`<canvas>`/SVG, or approaching 5 MB | proceed, but **log** the structure CSS can't express / **warn** on size |
| Proposal-first — which data sources to read; overwriting an existing default `docs/reports/` file with no caller path | **ask before acting** |
| No-go — writing/deleting a file outside `docs/reports/` with NO caller-supplied path; fetching any external resource | **refuse** |

> These zones OVERRIDE subagent-driven-development's "don't pause" default. Treat
> proposal-first and no-go points as HUMAN CHECKPOINTS.
