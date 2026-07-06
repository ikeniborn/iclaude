---
review:
  intent_hash: 4a41fdc55cf0e921
  last_run: 2026-06-17
  phases:
    structure:    { status: passed }
    completeness: { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
    alignment:    { status: passed }
  findings:
    - id: F-001
      phase: clarity
      severity: WARNING
      section: Desired Outcomes
      section_hash: 536c8331c53a0df9
      text: "'effective information display' / 'more effectively' — vague qualifier, no measurable criterion. Fixed: rephrased to measurable criteria (no item dropped; CSS-cannot-express trigger for SVG/canvas/JS)."
      verdict: fixed
      verdict_at: 2026-06-17
---
# Intent: html-report-skill

**Date:** 2026-06-17
**Status:** approved

## Objective
Add a skill that generates standalone, human-readable HTML reports on request —
tables, block diagrams, C4 and other architectural diagrams, plus dynamic
elements (expand/collapse, hover highlight, animated transitions). It complements
(does NOT replace) existing visualization skills: Mermaid is a machine-readable
context format, while HTML is human-readable. The current pain is that reading
information is uncomfortable without rich diagrams and dynamics; Mermaid/Excalidraw
do not cover that need. Built on plain HTML + CSS, no frameworks.

## Desired Outcomes
- On request, produces a single `.html` file that opens in a browser with no
  server and no internet.
- Renders tables, block diagrams, transition diagrams, C4 and other architectural
  diagrams — drawn primarily with CSS.
- Includes dynamics: click expands a block, hover highlights, transitions are
  animated.
- Contains every data point and diagram named in the request (none dropped);
  styling is limited to readable defaults (legible size, adequate contrast) plus
  the mandatory dark/light themes — no custom UI/UX beyond that.

## Health Metrics
- **Zero-dependency** (hard): no `<script src>`, no `<link href>` to a CDN, no
  external images. Everything inline.
- **Offline** (hard): opens by double-click from `file://`, no localhost.
- **File size** (soft): warn the user when a single file grows beyond 5 MB.
- **Compatibility**: target current Chrome / Firefox.
- **Self-containment** (hard): one file, no sibling assets.

## Strategic Context
- Interacts with: user request text, which names the allowed data sources. Reads
  only the sources the user indicates.
- Does NOT integrate with `mermaid-obsidian`, `graphify`, or `lat-md` — standalone
  skill.
- Generated files live in `docs/`.
- Priority trade-off: **trust** (accuracy of the data shown in the report).

## Constraints
### Steering (behavioral guidance)
- Use semantic HTML5 (`<table>`, `<figure>`, `<details>`) instead of a `<div>` soup.
- Draw diagrams primarily with pure CSS (grid / flex / borders).
- SVG, `<canvas>`, and inline `<script>` are allowed only when CSS alone cannot
  represent the structure (arbitrary node–edge graphs, free-form connectors, large
  data plots); otherwise prefer CSS.

### Hard (architectural enforcement)
- Only inline resources — no external `src` / `href` of any kind.
- Single self-contained file, no sibling assets.
- Must open offline via `file://`.
- Both dark and light themes are mandatory in every generated report.

## Autonomy Zones
- Full autonomy (reversible, low risk): generating the HTML, choosing CSS layout,
  selecting the diagram type for the data.
- Guarded (log + confidence threshold): including `<script>` / `<canvas>` (log the
  specific structure CSS cannot express); approaching the 5 MB size limit (warn).
- Proposal-first (needs approval): choosing data sources to read; overwriting an
  existing file in `docs/`.
- No autonomy (human only): writing or deleting files outside `docs/`; fetching any
  external resource.

> These zones OVERRIDE subagent-driven-development's "continuous execution,
> don't pause" default. Any task touching proposal-first / no-go decisions
> is marked HUMAN CHECKPOINT in the plan.

## Stop Rules
- Halt if: a requested data source cannot be read or contradicts the request
  (trust is the priority — do not fabricate report data).
- Escalate if: faithful display requires an external resource (would violate
  zero-dependency), or the file exceeds 5 MB.
- Done when: on a test request, the skill emits one `.html` that opens by
  double-click in Chrome and shows a table + a C4 diagram + an expandable block,
  with zero external requests in the Network tab and a working dark/light theme
  toggle.
