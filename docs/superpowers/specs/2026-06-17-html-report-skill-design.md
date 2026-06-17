---
review:
  spec_hash: acd7a09e2c309560
  last_run: 2026-06-17
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - id: F-001
      phase: clarity
      severity: WARNING
      section: Diagram Recipes
      section_hash: e94bcae79342a1b3
      text: "'tiny inline <script>' — no size/scope criterion for what counts as 'tiny'. Fixed: bounded to SVG-only interactivity wiring, no fetch/framework/external code, ~30 lines max; layout comment updated to 'bounded inline JS' for consistency."
      verdict: fixed
      verdict_at: 2026-06-17
chain:
  intent: docs/superpowers/intents/2026-06-17-html-report-skill-intent.md
---
# Design: html-report skill

**Date:** 2026-06-17
**Status:** approved (brainstorming)
**Intent:** [docs/superpowers/intents/2026-06-17-html-report-skill-intent.md](../intents/2026-06-17-html-report-skill-intent.md)

## Objective

A skill that generates standalone, human-readable HTML reports on request — styled
tables, block / transition / C4 and other architectural diagrams, plus dynamic
elements (expand/collapse, hover highlight, animated transitions). Complements (does
NOT replace) `mermaid-obsidian`: Mermaid is machine/context format, HTML is the
human-readable one. Built on plain HTML + CSS, no frameworks.

## Architecture & File Layout

```
.nvm-isolated/.claude-isolated/skills/html-report/
├── SKILL.md                      # thin: frontmatter trigger, hard rules, workflow, self-checklist
└── references/
    ├── css-diagrams.md           # 4 recipes: table, block/flow, transition/state, C4
    ├── themes.md                 # dark + light palettes + CSS checkbox-hack toggle
    ├── dynamics.md               # <details> expand, :hover highlight, CSS keyframe transitions
    └── svg-fallback.md           # node-edge graphs / plots via inline SVG (+ bounded inline JS, here only)
```

- **Packaging:** thin `SKILL.md` + `references/` (progressive disclosure). `SKILL.md`
  loads always; it states the hard constraints, the workflow, the self-validation
  checklist, and names which reference file to read per request. Reference files are
  read on demand — a table request never loads C4/SVG material.
- **Output:** a single `.html` file written to `docs/` only.
- **Registration:** dropping the directory under
  `.nvm-isolated/.claude-isolated/skills/html-report/` is enough — skills are
  auto-discovered, no manifest edit.

## Workflow (request → validated .html)

```
1. Parse request → extract: data points, named diagrams, data sources.
2. Read ONLY sources the user named (proposal-first if source choice ambiguous → ask).
   STOP if a source is unreadable / contradicts the request → halt, no fabrication
   (trust is the priority).
3. Pick a recipe per item; read the matching references/ file(s).
4. Assemble a single HTML document:
   - <head>: inline <style> (themes + recipe CSS + dynamics), nothing external.
   - <body>: semantic HTML5 (<table>/<figure>/<details>), the theme-toggle control,
     every named data point + diagram (none dropped).
   - SVG / inline JS block ONLY if a node-edge graph needs it → log the structure
     CSS cannot express.
5. Self-validate (checklist below) on the assembled string BEFORE writing the file.
6. Write to docs/. Overwriting an existing file → proposal-first (confirm).
7. Report: file path, size, any guarded-zone logs (script used / >5 MB warning).
```

**Self-validation checklist (step 5, run on the assembled string before write):**

- No `src=` / `href=` pointing at `http`/`https`/`//`/CDN; no `<script src>`, no
  `<link rel=stylesheet href>`.
- Both theme custom-prop sets present + toggle wired.
- Each requested data point + diagram name present.
- Size: warn if >5 MB.

## Themes & Toggle (`references/themes.md`)

Mechanism: pure-CSS checkbox hack. Zero JS for theming.

```html
<input type="checkbox" id="theme-toggle" hidden>
<label for="theme-toggle" class="theme-btn">🌙 / ☀️</label>
<main class="report"> … </main>
```

```css
/* default = light, via CSS custom props on :root */
:root{ --bg:#fafafa; --fg:#333344; --accent:#5c6bc0; --border:#d0d0e0; --line:#888888; }
/* :checked flips the whole palette — one toggle, all colors follow */
#theme-toggle:checked ~ * { --bg:#1e1e2e; --fg:#cdd6f4; --accent:#89b4fa; --border:#45475a; }
body{ background:var(--bg); color:var(--fg); transition:background .3s,color .3s; }
```

- Every recipe colors itself from the shared custom-prop set → one toggle reskins
  tables, blocks, diagrams together.
- Palettes: dark = Catppuccin Mocha, light = clean minimal (reuse `mermaid-obsidian`
  pairs for cross-skill consistency). `--line:#888888` mid-tone connector — legible
  on both themes.
- Initial theme: light default. Toggle persists only within the page session (no JS /
  localStorage) — intent requires a *working* toggle, not persistence.
- Contrast: each palette pair meets readable defaults (legible size + adequate
  contrast); no custom UI beyond that.

## Diagram Recipes (`references/css-diagrams.md`, `dynamics.md`, `svg-fallback.md`)

Each recipe = semantic HTML skeleton + theme-aware CSS (custom props above) + the
dynamic it supports. All four are pure CSS; SVG escalates only for free-form
node-edge.

| Recipe | HTML | CSS technique | Dynamic |
|--------|------|---------------|---------|
| **Table** | `<table><thead><tbody>` | zebra rows, `position:sticky` header, cell borders from `--border` | `:hover` row highlight |
| **Block / flow** | `<figure>` + nested `<div>` grid | `display:grid`/`flex`, arrows via `::after` border-triangles | `<details>`/`<summary>` expand block |
| **Transition / state** | `<ol>`/`<div>` states + labeled edges | flex row + `::after` connectors, `@keyframes` pulse on active | animated transition on `:target`/`:hover` |
| **C4** | nested `<figure>`/`<div>` (context ⊃ container ⊃ component) | nested grid containers, boundary borders | `<details>` collapse a boundary; node-edge links between containers → SVG fallback |

Rules baked into the recipes:

- **Semantic-first:** `<table>`/`<figure>`/`<details>`, no div-soup.
- **CSS-first:** grid / flex / borders / pseudo-elements before anything else.
- **SVG-fallback** (`svg-fallback.md`): only when CSS cannot draw the structure —
  arbitrary node→edge graphs, free connectors, data plots. Inline `<svg>`; an inline
  `<script>` is allowed **here only** and is bounded: it may only wire interactivity
  for the SVG it accompanies (e.g. node hover-highlight, click-to-expand on a graph
  node). It must not fetch data, load a framework, reference external code, or exceed
  ~30 lines. The skill logs the specific structure CSS could not express (guarded
  zone).
- Every recipe pulls color from `--bg/--fg/--accent/--border/--line` → auto
  theme-correct, no per-recipe theme code.

## Hard-Constraint Enforcement & Autonomy Zones

The skill is behavioral (prompt-based) — no runtime hook. Enforcement is the explicit
self-validation step plus autonomy-zone checkpoints written into `SKILL.md`.

**Hard constraints → how enforced (step 5 self-validate, before write):**

| Constraint | Check (on the assembled HTML string) |
|------------|--------------------------------------|
| Zero-dependency | reject any `src=`/`href=` at `http`/`https`/`//`/CDN; reject `<script src>`, `<link href>` |
| Offline `file://` | implied by zero-dep — all `<style>`/`<svg>`/`<script>` inline; no fetch |
| Single self-contained file | one `.html`, no sibling asset writes |
| Both themes mandatory | assert dark + light custom-prop sets + toggle present |
| Size (soft) | warn if >5 MB |

If any hard check fails → do not write; report what failed. If faithful display needs
an external resource → escalate (intent Stop Rule), do not silently inline-fetch.

**Autonomy zones (from intent) → behavior in SKILL.md:**

| Zone | Action |
|------|--------|
| Full (gen HTML, CSS layout, diagram-type choice) | proceed, no pause |
| Guarded (use `<script>`/`<canvas>`/SVG; near 5 MB) | proceed + **log** the structure CSS can't express / size warn |
| Proposal-first (which sources to read; overwrite an existing `docs/` file) | **ask before** |
| No-go (write/delete outside `docs/`; fetch external) | **refuse** |

These override subagent-driven-development's "don't pause" default — proposal-first /
no-go steps are marked HUMAN CHECKPOINT in the plan.

## Name & Trigger

- **Skill name:** `html-report`.
- **Frontmatter `description` (trigger), EN:** use when the user asks for a standalone
  / self-contained HTML report, an offline `.html`, a human-readable report that opens
  by double-click, expandable/interactive HTML tables or diagrams, C4 / block /
  transition diagrams *in HTML* (not Mermaid), or a dark/light themed report. Example
  phrases: "сделай html-отчёт", "standalone html report", "expandable html table",
  "C4 diagram as html", "offline report I can open in browser".
- **Delineation:** NOT `mermaid-obsidian` (machine/context Mermaid for Obsidian); NOT
  `prd-generator` / `architecture-documentation` (those embed Mermaid in docs).
  Standalone — does NOT integrate with `graphify` / `lat-md` / `mermaid-obsidian`.

## Done Criterion (from intent)

On a test request, the skill emits one `.html` that opens by double-click in Chrome
and shows a table + a C4 diagram + an expandable block, with zero external requests in
the Network tab and a working dark/light theme toggle.
