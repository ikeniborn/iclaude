# html-report Skill

`.claude-isolated/skills/html-report/` is a Claude Code skill that generates ONE self-contained `.html` report — opens offline by double-click, zero external dependencies, with styled tables, CSS/SVG diagrams, and a dark/light theme toggle. It is the human-readable counterpart to the machine-format `mermaid-obsidian` skill.

## Purpose and Hard Constraints

The skill produces a single offline artifact in `docs/`. Four constraints are non-negotiable: **zero-dependency** (no `<script src>`, `<link href>`, CDN, or external images — everything inline), **offline** (must open from `file://`, no localhost/fetch), **single self-contained file** (one `.html`, no sibling assets), and **both themes mandatory** (every report ships dark AND light palettes plus a working toggle). If faithful display would need an external resource, the skill escalates rather than inlining a fetch or silently dropping the element.

## Reference Recipes

`SKILL.md` routes each requested item to a reference file under `references/`. Recipes are theme-aware — they color from the shared CSS custom properties so one toggle reskins the whole report.

| Reference | Covers |
|-----------|--------|
| `references/themes.md` | Dark/light palettes (checkbox-hack toggle, zero JS), full custom-prop set (`--muted --shadow --accent-2`, `-2` status shades), `color-mix` shade derivation, radial-gradient body wash. Read always. |
| `references/css-diagrams.md` | Pure-CSS recipes: `<table>` (separate-border radius + sticky accent header + rowspan + `color-mix` hover), flex block/transition flows, nested-boundary C4, and report components (`.note` callout, `.badge` pills, `.lead`/`.sub` typography, `<details>`). |
| `references/svg-diagrams.md` | SVG flow grammar for pipelines/loops/state machines with labeled, looping, or non-adjacent edges: shared `<defs>` (dropshadow + colored arrow markers), reusable node-card primitive with status bars, animated marching-ants connectors (`prefers-reduced-motion` guarded), loop-back paths, edge-label patches. |
| `references/dynamics.md` | Zero-JS dynamics: `<details>` expand/collapse, hover highlight, `:target` flash, `@keyframes`. |
| `references/svg-fallback.md` | Lower-level escape for arbitrary node→edge graphs / free connectors / data plots, plus the bounded inline-`<script>` rules (≤30 lines, no fetch, operates only on present elements). |

The SVG grammar (`svg-diagrams.md`) is the high-fidelity path that makes a report read like an architecture doc; `svg-fallback.md` is the escape for graphs that don't fit that grammar. A polished end-to-end gold-standard example is referenced at `ecom1-agent/docs/agent-architecture.html`.

## Workflow and Autonomy Zones

The skill parses the request into data points + named diagrams + sources, reads ONLY the named sources (halts rather than fabricating if a source is unreadable or contradicts the request), picks a recipe per item, assembles one HTML document, self-validates against a checklist, then writes to `docs/`.

The self-validation checklist (run before writing) rejects external `src`/`href`/CDN refs, any `<script src>`/`<link rel=stylesheet href>`, sibling-file references, a missing theme set or unwired toggle, dropped data points/diagrams, flat flows that lose a loop/branch edge (should use the SVG grammar), missing shared `<defs>` when SVG is used, and warns over a 5 MB soft limit.

Autonomy zones override the "don't pause" default: **full** (generating HTML, CSS layout, diagram type) proceeds; **guarded** (inline `<script>`/`<canvas>`/SVG, or nearing 5 MB) proceeds but logs/warns; **proposal-first** (which sources to read, overwriting an existing `docs/` file) asks first; **no-go** (writing/deleting outside `docs/`, fetching any external resource) refuses.

See also: [[architecture]], [[graphify]], [[iwiki]]
