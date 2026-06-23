# html-report Skill

## Overview

`.claude-isolated/skills/html-report/` is a Claude Code skill (v1.0.0) that generates ONE self-contained `.html` report — opens offline by double-click, zero external dependencies, with styled tables, CSS/SVG diagrams, simple dynamics, and a dark/light theme toggle. Human-readable counterpart to the machine-format `mermaid-obsidian`. Covers the five hard constraints, reference recipes, themes, the SVG grammar, workflow, self-validation, and autonomy zones.

## Hard Constraints

The skill enforces five non-negotiable constraints (NEVER violated). **Zero-dependency** — no `<script src>`, no `<link rel=stylesheet href>`, no `src`/`href` to `http`/`https`/`//`/any CDN, no external images; everything inline. **Offline** — the file opens from `file://` by double-click, no localhost, no fetch. **Single self-contained file** — one `.html`, no sibling assets. **Both themes mandatory** — every report ships dark AND light palettes plus a working toggle. **Output directory** — the default target is `docs/reports/` in the running project (created if missing). If faithful display would need an external resource, the skill escalates rather than inline-fetching or silently dropping the element.

## Output Path and Caller Override

`docs/reports/` is the DEFAULT, not the only, location. If the caller passes an EXPLICIT output path (e.g. an IDD `check-*` command), the skill writes to that path instead, creating the directory if missing. It never invents an unrequested path. This distinction drives the autonomy zones: writing to a caller-supplied path (including overwriting it — it is a regenerated artifact) is the Full zone and proceeds; only overwriting an existing default `docs/reports/` file with no caller path is proposal-first.

## Reference Recipes

`SKILL.md` routes each requested item to a reference file under `references/`. Recipes are theme-aware — they color from the shared CSS custom properties so one toggle reskins the whole report. The skill reads only the references its requested items need (`themes.md` always).

| Reference | Covers |
|-----------|--------|
| `references/themes.md` | Dark/light palettes via a checkbox hack (zero JS), full custom-prop set, `color-mix` shade derivation, radial-gradient body wash. Read always. |
| `references/css-diagrams.md` | Pure-CSS recipes: `<table>`, flex block/transition flows, nested-boundary C4, and report components (`.note` callout, `.badge` pills, `.lead`/`.sub` typography, `<details>`). |
| `references/svg-diagrams.md` | High-fidelity SVG grammar for pipelines/loops/state machines with labeled, looping, or non-adjacent edges. |
| `references/dynamics.md` | Zero-JS dynamics: `<details>` expand/collapse, hover highlight, `:target` flash, `@keyframes`. |
| `references/svg-fallback.md` | Lower-level escape for arbitrary node→edge graphs, free connectors, data plots — plus the bounded inline-`<script>` rules. |

The SVG grammar (`svg-diagrams.md`) is the high-fidelity path that makes a report read like an architecture doc; `svg-fallback.md` is the escape for graphs that don't fit that grammar. The gold standard for a non-trivial architecture report is the in-skill `references/` files themselves (study them before assembling).

## Themes and Toggle

Pure-CSS dark/light theming via a checkbox hack — zero JS, no persistence (the spec requires a *working* toggle, not localStorage). `body:has(#theme-toggle:checked)` flips the palette on `<body>` itself so the background and every descendant inherit the new theme (a sibling `~ *` selector would miss `<body>` and leave it stuck light). Light is the default `:root` palette; dark is Catppuccin Mocha. A full custom-prop set carries `--muted` (secondary text), `--shadow` (rgba for box/drop shadows), `--accent-2` (deeper accent), `--line` (mid-tone connector legible on both themes), and `-2` darker status shades (`--ok-2 --warn-2 --danger-2`). Shades are DERIVED with `color-mix`, never hardcoded, so they recompute on toggle.

## CSS Diagram Recipes

Pure-CSS, semantic-HTML diagrams preferred over `<div>` soup. The `<table>` recipe uses `border-spacing:0` + `overflow:hidden` on a rounded shadowed wrapper to clip header corners, with `rowspan` grouping, sticky accent header, zebra rows, and `color-mix` hover. Block flows (`.rpt-flow`) and state/transition rows (`.rpt-states`, with an animated `pulse` active state) draw left-to-right adjacency in flex. C4 (`.rpt-c4`) nests Context ⊃ Container ⊃ Component as dashed-boundary `<figure>` boxes with `color-mix`-tinted fills and accent-bordered component cards. Report components — `.lead`/`.sub` typography, `.note` callout, `.badge` pills (`.llm`/`.det`), and `<details>` — make the output read like a document. Free connectors between non-adjacent boxes escalate to SVG.

## SVG Flow Grammar

The high-fidelity path for pipelines, loops, state machines, and labeled flows — anything where positioned nodes connect with directional, possibly looping arrows. Used when the flat flex recipes drop a loop-back edge, a non-adjacent connector, a labeled branch, or a status bar. CSS custom props cascade into inline SVG, so `fill="var(--surface)"` just works. Structure: one shared hidden `<defs>` (dropshadow filter + one arrow marker per semantic color), an SVG `<style>` block (`.card` node + colored status bars + static/`marching-ants` animated connectors, the animation `prefers-reduced-motion`-guarded), a reusable node-card primitive copied per node, and connectors/edge-labels (opaque `.lbl-bg` patch behind text over a line, loop-back paths via `Q` corners). Coordinates are computed, not guessed; `viewBox` sets the aspect and `svg{width:100%}` scales responsively; each `<svg>` carries `role="img"` + a descriptive `aria-label`.

## Dynamics

Three dynamics, all zero-JS, colored from the theme props. `<details>`/`<summary>` for expand/collapse; `:hover` highlight (lift + shadow, or table-row tint); and animated transitions — CSS `transition` for `:hover`/`:target`-driven state changes and `@keyframes` for continuous motion (e.g. the active-state `pulse`, a `:target` flash on an anchored section). Durations stay modest (.15s–.4s transitions; ≥1s loops) so motion reads as informative. An inline `<script>` is never needed for a diagram; it is permitted ONLY under `svg-fallback.md` bounds (≤30 lines, no fetch, no framework, operates only on present elements) to wire SVG-graph interactivity CSS alone cannot express.

## Workflow

The skill parses the request into data points, named diagrams, and sources; reads ONLY the named sources (asks first if the source choice is ambiguous, halts rather than fabricating if a source is unreadable or contradicts the request); picks a recipe per item and reads the matching reference; assembles ONE HTML document (single inline `<style>` in `<head>`; semantic `<body>` with the toggle and EVERY data point + diagram, dropping nothing); self-validates against the checklist; then writes to the target directory (default `docs/reports/`, or the caller-supplied path). It reports back the file path, file size, and any guarded-zone logs.

## Self-Validation Checklist

Before writing, the skill rejects and fixes the assembled HTML if any check fails: no `src`/`href` to `http`/`https`/`//`/CDN; no `<script src>` or `<link rel=stylesheet href>`; exactly one `.html` with no sibling-file references; both theme custom-prop sets present AND the toggle wired; every requested data point and named diagram present; flows with retry/branch/non-adjacent edges use the SVG grammar (node cards + arrow markers) instead of a flat flex row that drops the loop/branch; shared `<defs>` present if any SVG is used; file size ≤ 5 MB (warn over the soft limit); and the output path under `docs/reports/` OR equal to the explicit caller-supplied path.

## Autonomy Zones

Four zones override subagent-driven-development's "don't pause" default; proposal-first and no-go are HUMAN CHECKPOINTS. **Full** — generating HTML, choosing CSS layout, picking the diagram type, and writing to a path the calling command explicitly passed — proceeds with no pause. **Guarded** — using inline `<script>`/`<canvas>`/SVG, or approaching 5 MB — proceeds but logs the structure CSS can't express / warns on size. **Proposal-first** — which sources to read, and overwriting an existing default `docs/reports/` file when no caller path was given — asks before acting. **No-go** — writing/deleting a file outside `docs/reports/` with no caller-supplied path, or fetching any external resource — refuses.

See also: [[architecture]], [[iwiki]], [[caveman]]
