---
review:
  plan_hash: db208f133e37a242
  spec_hash: acd7a09e2c309560
  last_run: 2026-06-17
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings: []
result_check:
  verdict: OK
  plan_hash: db208f133e37a242
  last_run: 2026-06-17
chain:
  intent: docs/superpowers/intents/2026-06-17-html-report-skill-intent.md
  spec:   docs/superpowers/specs/2026-06-17-html-report-skill-design.md
---
# html-report Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **No-Tests note (project CLAUDE.md, overrides TDD):** This deliverable is a set of
> markdown skill files — there is no runtime to unit-test. Verification is done by
> *running the skill for real* (generating a sample `.html`) and observing behavior
> (open in browser, inspect Network tab, grep the file). Do NOT add a test framework
> or red→green tests.

**Goal:** Add a `html-report` skill that generates standalone, offline, single-file HTML reports (styled tables, CSS block/transition/C4 diagrams, expand/hover/animated dynamics, dark/light toggle) on request.

**Architecture:** Thin `SKILL.md` (trigger, hard rules, workflow, self-validation checklist) + four on-demand `references/` files (themes, css-diagrams, dynamics, svg-fallback). Output is one `.html` written to `docs/`. Behavioral skill — no runtime hook; enforcement is the self-validation step plus autonomy-zone checkpoints written into `SKILL.md`.

**Tech Stack:** Markdown (skill files); generated artifact is plain HTML5 + CSS (custom properties, grid/flex, pseudo-elements, `@keyframes`, checkbox-hack), inline `<svg>` + bounded inline `<script>` only for node-edge fallback.

**Spec:** [docs/superpowers/specs/2026-06-17-html-report-skill-design.md](../specs/2026-06-17-html-report-skill-design.md)

---

## File Structure

All under the isolated skills dir (auto-discovered, no manifest edit):

- Create: `.nvm-isolated/.claude-isolated/skills/html-report/SKILL.md` — trigger frontmatter, hard rules, workflow, self-validation checklist, autonomy zones.
- Create: `.nvm-isolated/.claude-isolated/skills/html-report/references/themes.md` — dark/light palettes + checkbox-hack toggle CSS.
- Create: `.nvm-isolated/.claude-isolated/skills/html-report/references/css-diagrams.md` — 4 recipes (table, block/flow, transition/state, C4).
- Create: `.nvm-isolated/.claude-isolated/skills/html-report/references/dynamics.md` — `<details>` expand, `:hover` highlight, `@keyframes` transitions.
- Create: `.nvm-isolated/.claude-isolated/skills/html-report/references/svg-fallback.md` — node-edge graphs/plots via inline SVG + bounded inline JS.
- Verify artifact (transient): `docs/_html-report-smoke.html` — generated during verification, then deleted.

Each task creates one focused file. Files that change together (the recipes) stay in one reference; theming is split out because every recipe depends on it.

---

## Task 1: Skill manifest — SKILL.md

**Files:**
- Create: `.nvm-isolated/.claude-isolated/skills/html-report/SKILL.md`

- [ ] **Step 1: Create the skill directory**

Run:
```bash
mkdir -p .nvm-isolated/.claude-isolated/skills/html-report/references
```
Expected: directories created, no output.

- [ ] **Step 2: Write SKILL.md**

Create `.nvm-isolated/.claude-isolated/skills/html-report/SKILL.md` with exactly:

````markdown
---
name: html-report
description: "Use when the user asks for a standalone or self-contained HTML report, an offline .html file, a human-readable report that opens by double-click in a browser, expandable/interactive HTML tables, or block / transition / C4 / architectural diagrams rendered in HTML (NOT Mermaid), or a dark/light themed report. Triggers on phrases like 'сделай html-отчёт', 'standalone html report', 'expandable html table', 'C4 diagram as html', 'offline report I can open in browser'. Produces ONE self-contained .html in docs/ with zero external dependencies. NOT for Mermaid diagrams (use mermaid-obsidian) or Mermaid embedded in PRD/architecture docs (use prd-generator / architecture-documentation)."
version: 1.0.0
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

If faithful display would require an external resource, **escalate** — do not
inline-fetch and do not silently drop the element.

## Workflow

1. Parse the request → list the data points, the named diagrams, and the data sources.
2. Read ONLY the sources the user named. If the source choice is ambiguous, **ask
   first** (proposal-first). If a source is unreadable or contradicts the request,
   **halt** — do not fabricate data (trust is the priority).
3. Pick a recipe per item and read the matching reference file:
   - tables / block / transition / C4 → `references/css-diagrams.md`
   - any dynamic (expand, hover, animation) → `references/dynamics.md`
   - theme palettes + toggle → `references/themes.md` (always)
   - arbitrary node-edge graph / free connector / data plot → `references/svg-fallback.md`
4. Assemble ONE HTML document:
   - `<head>`: a single inline `<style>` (theme custom-props + recipe CSS + dynamics).
   - `<body>`: semantic HTML5 (`<table>` / `<figure>` / `<details>`), the theme-toggle
     control, and EVERY named data point + diagram (drop nothing).
   - Add an SVG / bounded inline `<script>` block ONLY if a node-edge graph needs it,
     and **log** the specific structure CSS could not express.
5. **Self-validate** the assembled string (checklist below) BEFORE writing.
6. Write the file to `docs/`. If the target file already exists, **ask first** before
   overwriting (proposal-first).
7. Report to the user: file path, file size, and any guarded-zone logs (inline script
   used / size warning).

## Self-Validation Checklist (run before writing)

Reject and fix the assembled HTML if any fails:

- [ ] No `src=` or `href=` referencing `http`, `https`, `//`, or a CDN host.
- [ ] No `<script src=...>` and no `<link rel="stylesheet" href=...>`.
- [ ] Exactly one `.html`, no references to sibling files.
- [ ] Both theme custom-prop sets present AND the toggle control is wired.
- [ ] Every requested data point and every named diagram is present.
- [ ] File size ≤ 5 MB — if larger, **warn** the user (soft limit).

## Autonomy Zones

| Zone | Action |
|------|--------|
| Full — generating HTML, choosing CSS layout, picking the diagram type | proceed, no pause |
| Guarded — using inline `<script>`/`<canvas>`/SVG, or approaching 5 MB | proceed, but **log** the structure CSS can't express / **warn** on size |
| Proposal-first — which data sources to read; overwriting an existing `docs/` file | **ask before acting** |
| No-go — writing/deleting any file outside `docs/`; fetching any external resource | **refuse** |

> These zones OVERRIDE subagent-driven-development's "don't pause" default. Treat
> proposal-first and no-go points as HUMAN CHECKPOINTS.
````

- [ ] **Step 3: Validate frontmatter + markdown**

Run:
```bash
head -5 .nvm-isolated/.claude-isolated/skills/html-report/SKILL.md
awk 'NR==1{exit !/^---$/}' .nvm-isolated/.claude-isolated/skills/html-report/SKILL.md && echo "frontmatter-start-ok"
```
Expected: first line `---`, `name: html-report` present, prints `frontmatter-start-ok`.

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/html-report/SKILL.md
git commit -m "feat(skill): add html-report SKILL.md manifest"
```

---

## Task 2: Theme reference — references/themes.md

**Files:**
- Create: `.nvm-isolated/.claude-isolated/skills/html-report/references/themes.md`

- [ ] **Step 1: Write themes.md**

Create the file with exactly:

````markdown
# Themes & Toggle

Pure-CSS dark/light theming via a checkbox hack. Zero JS. Every recipe colors itself
from the shared custom properties below, so one toggle reskins the whole report.

## Custom properties + toggle

Place the toggle control as the FIRST element inside `<body>`, before the report, so
`#theme-toggle:checked ~ *` reaches every sibling.

```html
<input type="checkbox" id="theme-toggle" hidden>
<label for="theme-toggle" class="theme-btn" title="Toggle dark/light">🌙 / ☀️</label>
<main class="report">
  <!-- report content -->
</main>
```

```css
/* Light = default palette on :root */
:root{
  --bg:#fafafa; --surface:#ffffff; --fg:#333344;
  --accent:#5c6bc0; --border:#d0d0e0; --line:#888888;
  --zebra:#f3f3f8; --ok:#43a047; --warn:#fb8c00; --danger:#e53935;
}
/* Dark = Catppuccin Mocha; :checked flips the whole palette */
#theme-toggle:checked ~ *{
  --bg:#1e1e2e; --surface:#313244; --fg:#cdd6f4;
  --accent:#89b4fa; --border:#45475a; --line:#888888;
  --zebra:#282838; --ok:#a6e3a1; --warn:#f9e2af; --danger:#f38ba8;
}
body{
  margin:0; padding:1.5rem;
  font:16px/1.55 system-ui, sans-serif;
  background:var(--bg); color:var(--fg);
  transition:background .3s, color .3s;
}
.theme-btn{
  position:sticky; top:.5rem; float:right;
  cursor:pointer; user-select:none;
  padding:.25rem .6rem; border:1px solid var(--border); border-radius:6px;
  background:var(--surface);
}
```

Notes:
- `--line:#888888` is a mid-tone connector color — legible (~4:1) on both themes. Do
  not use dark (`#333`) or light (`#ccc`) connectors; they vanish on one theme.
- Light is the default; the toggle has no persistence (no JS/localStorage). The spec
  requires a *working* toggle, not persistence.
- Keep contrast adequate: body text on `--bg`, headings/accents on `--accent`.
````

- [ ] **Step 2: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/html-report/references/themes.md
git commit -m "feat(skill): add html-report themes reference"
```

---

## Task 3: Diagram recipes — references/css-diagrams.md

**Files:**
- Create: `.nvm-isolated/.claude-isolated/skills/html-report/references/css-diagrams.md`

- [ ] **Step 1: Write css-diagrams.md**

Create the file with exactly:

````markdown
# CSS Diagram Recipes

Four pure-CSS recipes. Each is semantic HTML + theme-aware CSS (uses the custom props
from `themes.md`: `--bg --surface --fg --accent --border --line --zebra`). Prefer
these over any `<div>` soup. Escalate to `svg-fallback.md` only when a structure
cannot be drawn with grid/flex/borders (arbitrary node→edge graphs, free connectors).

## 1. Table (`<table>`)

```html
<table class="rpt-table">
  <thead><tr><th>Module</th><th>Lines</th><th>Owner</th></tr></thead>
  <tbody>
    <tr><td>core</td><td>320</td><td>A</td></tr>
    <tr><td>proxy</td><td>540</td><td>B</td></tr>
  </tbody>
</table>
```

```css
.rpt-table{ border-collapse:collapse; width:100%; background:var(--surface); }
.rpt-table th, .rpt-table td{ border:1px solid var(--border); padding:.5rem .75rem; text-align:left; }
.rpt-table thead th{ position:sticky; top:0; background:var(--accent); color:var(--bg); }
.rpt-table tbody tr:nth-child(even){ background:var(--zebra); }
.rpt-table tbody tr:hover{ outline:2px solid var(--accent); outline-offset:-2px; }
```

## 2. Block / flow (grid + flex)

```html
<figure class="rpt-flow">
  <div class="node">Input</div>
  <div class="arrow"></div>
  <div class="node">Process</div>
  <div class="arrow"></div>
  <div class="node">Output</div>
</figure>
```

```css
.rpt-flow{ display:flex; align-items:center; gap:0; margin:1rem 0; flex-wrap:wrap; }
.rpt-flow .node{
  background:var(--surface); color:var(--fg);
  border:1px solid var(--border); border-radius:8px; padding:.6rem 1rem;
}
.rpt-flow .arrow{ flex:0 0 2.5rem; height:2px; background:var(--line); position:relative; }
.rpt-flow .arrow::after{
  content:""; position:absolute; right:0; top:-4px;
  border:5px solid transparent; border-left-color:var(--line);
}
```

For an expandable block, wrap node detail in `<details>` (see `dynamics.md`).

## 3. Transition / state (flex row + animated active state)

```html
<figure class="rpt-states">
  <div class="state active">Idle</div>
  <div class="edge" data-label="start"></div>
  <div class="state">Running</div>
  <div class="edge" data-label="done"></div>
  <div class="state">Done</div>
</figure>
```

```css
.rpt-states{ display:flex; align-items:center; gap:0; flex-wrap:wrap; margin:1rem 0; }
.rpt-states .state{
  border:2px solid var(--border); border-radius:999px; padding:.5rem 1rem;
  background:var(--surface);
}
.rpt-states .state.active{ border-color:var(--accent); animation:pulse 1.6s ease-in-out infinite; }
.rpt-states .edge{ flex:0 0 3rem; height:2px; background:var(--line); position:relative; }
.rpt-states .edge::before{
  content:attr(data-label); position:absolute; top:-1.2rem; left:50%;
  transform:translateX(-50%); font-size:.75rem; color:var(--fg);
}
.rpt-states .edge::after{
  content:""; position:absolute; right:0; top:-4px;
  border:5px solid transparent; border-left-color:var(--line);
}
@keyframes pulse{ 0%,100%{ box-shadow:0 0 0 0 var(--accent); } 50%{ box-shadow:0 0 0 4px transparent; } }
```

## 4. C4 (nested boundaries)

Context ⊃ Container ⊃ Component as nested `<figure>`/`<div>` boxes. Boundaries are
borders; nodes are grid cells. Node-edge links BETWEEN containers (free connectors)
escalate to `svg-fallback.md`.

```html
<figure class="rpt-c4">
  <div class="boundary" data-label="System Context">
    <div class="boundary" data-label="Container: API">
      <div class="comp">Auth</div>
      <div class="comp">Router</div>
    </div>
    <div class="boundary" data-label="Container: Store">
      <div class="comp">DB</div>
    </div>
  </div>
</figure>
```

```css
.rpt-c4 .boundary{
  border:2px dashed var(--accent); border-radius:10px;
  padding:1.6rem 1rem .8rem; margin:.6rem; position:relative;
  display:flex; flex-wrap:wrap; gap:.6rem;
}
.rpt-c4 .boundary::before{
  content:attr(data-label); position:absolute; top:-.7rem; left:.8rem;
  background:var(--bg); padding:0 .4rem; font-size:.8rem; color:var(--accent);
}
.rpt-c4 .comp{
  background:var(--surface); border:1px solid var(--border); border-radius:6px;
  padding:.5rem .8rem; min-width:5rem; text-align:center;
}
```
````

- [ ] **Step 2: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/html-report/references/css-diagrams.md
git commit -m "feat(skill): add html-report css-diagrams reference"
```

---

## Task 4: Dynamics reference — references/dynamics.md

**Files:**
- Create: `.nvm-isolated/.claude-isolated/skills/html-report/references/dynamics.md`

- [ ] **Step 1: Write dynamics.md**

Create the file with exactly:

````markdown
# Dynamics (pure CSS)

Three dynamics, all zero-JS. They color from the `themes.md` custom props.

## Expand / collapse — `<details>` / `<summary>`

```html
<details class="rpt-exp">
  <summary>Module: proxy (click to expand)</summary>
  <div class="body">
    <p>Handles HTTP/HTTPS proxy, CA injection, OAuth-compatible HTTPS.</p>
  </div>
</details>
```

```css
.rpt-exp{ border:1px solid var(--border); border-radius:8px; margin:.5rem 0; background:var(--surface); }
.rpt-exp > summary{ cursor:pointer; padding:.6rem .9rem; font-weight:600; color:var(--accent); }
.rpt-exp[open] > summary{ border-bottom:1px solid var(--border); }
.rpt-exp .body{ padding:.6rem .9rem; }
```

## Hover highlight

Already shown for tables (`tbody tr:hover`). Generic node highlight:

```css
.hl{ transition:transform .15s, box-shadow .15s; }
.hl:hover{ transform:translateY(-2px); box-shadow:0 4px 12px rgba(0,0,0,.25); }
```

## Animated transitions

Use CSS `transition` for state changes driven by `:hover`/`:target`, and `@keyframes`
for continuous motion (e.g. the `pulse` on an active state in `css-diagrams.md`). Keep
durations modest (.15s–.4s for transitions; ≥1s loops for keyframes) so motion reads
as informative, not distracting.

```css
/* :target — clicking an anchor link highlights the referenced section */
.rpt-target:target{ outline:2px solid var(--accent); animation:flash .8s ease-out; }
@keyframes flash{ from{ background:var(--accent); } to{ background:transparent; } }
```
````

- [ ] **Step 2: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/html-report/references/dynamics.md
git commit -m "feat(skill): add html-report dynamics reference"
```

---

## Task 5: SVG fallback reference — references/svg-fallback.md

**Files:**
- Create: `.nvm-isolated/.claude-isolated/skills/html-report/references/svg-fallback.md`

- [ ] **Step 1: Write svg-fallback.md**

Create the file with exactly:

````markdown
# SVG / Bounded-JS Fallback

Use ONLY when CSS cannot draw the structure: arbitrary node→edge graphs, free-form
connectors between non-adjacent nodes, or data plots. Everything is inline. When you
use this fallback, **log** the specific structure CSS could not express (guarded zone).

## Inline SVG node-edge graph

SVG colors must reference the theme. CSS custom props DO cascade into inline SVG, so
use `stroke="var(--line)"` / `fill="var(--surface)"`.

```html
<figure class="rpt-graph">
  <svg viewBox="0 0 200 120" width="320" role="img" aria-label="dependency graph">
    <line x1="40" y1="30" x2="150" y2="90" stroke="var(--line)" stroke-width="2"/>
    <line x1="40" y1="30" x2="150" y2="30" stroke="var(--line)" stroke-width="2"/>
    <circle cx="40"  cy="30" r="16" fill="var(--surface)" stroke="var(--accent)" stroke-width="2"/>
    <circle cx="150" cy="30" r="16" fill="var(--surface)" stroke="var(--accent)" stroke-width="2"/>
    <circle cx="150" cy="90" r="16" fill="var(--surface)" stroke="var(--accent)" stroke-width="2"/>
  </svg>
</figure>
```

## Bounded inline `<script>` (allowed HERE ONLY)

An inline `<script>` is permitted only to wire interactivity for the SVG it
accompanies — e.g. node hover-highlight or click-to-expand on a graph node. Bounds:

- MUST NOT fetch data, load a framework, or reference any external code.
- MUST stay small (~30 lines max).
- Operates only on elements already present in the document.

```html
<script>
  // hover-highlight graph nodes — SVG cannot do :hover restyle of linked edges alone
  document.querySelectorAll('.rpt-graph circle').forEach(function (n) {
    n.addEventListener('mouseenter', function () { n.setAttribute('stroke-width', '4'); });
    n.addEventListener('mouseleave', function () { n.setAttribute('stroke-width', '2'); });
  });
</script>
```

If interactivity is NOT required, omit the `<script>` entirely — a static inline
`<svg>` is the preferred, fully zero-JS form.
````

- [ ] **Step 2: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/html-report/references/svg-fallback.md
git commit -m "feat(skill): add html-report svg-fallback reference"
```

---

## Task 6: Verification — exercise the skill against the done-criterion

This task verifies the deliverable by *running it for real*, per the project No-Tests
rule. The done-criterion (from the spec): one `.html` that opens by double-click in
Chrome and shows a table + a C4 diagram + an expandable block, with zero external
requests and a working dark/light toggle.

**Files:**
- Verify artifact (transient): `docs/_html-report-smoke.html`

- [ ] **Step 1: Generate a smoke report using ONLY the skill files**

Acting as the skill, assemble `docs/_html-report-smoke.html` containing: the
`themes.md` toggle + custom props in one inline `<style>`; one Table recipe; one C4
recipe; one `<details>` expandable block. No external `src`/`href`. Write the file.

- [ ] **Step 2: Verify zero external dependencies (the hard constraint)**

Run:
```bash
grep -nE 'src=|href=|<link|<script[^>]*src' docs/_html-report-smoke.html | grep -vE 'href="#' || echo "NO-EXTERNAL-REFS"
```
Expected: prints `NO-EXTERNAL-REFS` (only in-page `href="#..."` anchors, if any, are allowed).

- [ ] **Step 3: Verify required elements present**

Run:
```bash
grep -c 'rpt-table'  docs/_html-report-smoke.html
grep -c 'rpt-c4'     docs/_html-report-smoke.html
grep -c '<details'   docs/_html-report-smoke.html
grep -c 'theme-toggle' docs/_html-report-smoke.html
```
Expected: each prints ≥ 1 (table, C4, expandable block, toggle all present).

- [ ] **Step 4: Verify size soft-limit logic**

Run:
```bash
test "$(stat -c%s docs/_html-report-smoke.html)" -le 5242880 && echo "SIZE-OK (<=5MB)"
```
Expected: prints `SIZE-OK (<=5MB)`.

- [ ] **Step 5: Open in browser, confirm offline render + toggle**

Run:
```bash
echo "Open via file://, check Network tab = 0 external requests, click the 🌙/☀️ toggle:"
echo "file://$(pwd)/docs/_html-report-smoke.html"
```
Expected: report renders offline; table + C4 + expandable block visible; clicking the
toggle flips dark↔light; browser Network tab shows zero external requests. (Manual
visual confirmation — this is the done-criterion.)

- [ ] **Step 6: Remove the transient artifact**

Run:
```bash
rm -f docs/_html-report-smoke.html
```
Expected: smoke file removed (it was a verification artifact, not a deliverable).

- [ ] **Step 7: Validate doc-graph integrity (project post-task checklist)**

The skill is standalone and does NOT integrate with `lat-md` (per spec), so no
`lat.md/` section is required. Run the link/code-ref check to confirm nothing broke:
```bash
lat check
```
Expected: passes (no new broken links or code refs).

- [ ] **Step 8: Commit verification cleanup (if anything staged)**

```bash
git add -A
git commit -m "chore(skill): verify html-report generates valid offline report" --allow-empty
```

---

## Self-Review (completed by plan author)

**Spec coverage:**
- Architecture & file layout → Tasks 1–5 create exactly the spec's `SKILL.md` + 4 references. ✓
- Workflow (parse→read→recipe→assemble→self-validate→write→report) → SKILL.md §Workflow (Task 1). ✓
- Self-validation checklist + hard constraints → SKILL.md (Task 1) + verified in Task 6 steps 2–4. ✓
- Themes & checkbox-hack toggle → Task 2 + verified Task 6 step 5. ✓
- 4 diagram recipes → Task 3. ✓
- Dynamics (`<details>`, hover, `@keyframes`) → Task 4. ✓
- SVG + bounded inline `<script>` (≤30 lines, no fetch/framework, SVG-only) → Task 5 (matches F-001 fix). ✓
- Autonomy zones → SKILL.md §Autonomy Zones (Task 1). ✓
- Name `html-report` + trigger + delineation from mermaid-obsidian → SKILL.md frontmatter (Task 1). ✓
- Done-criterion (table + C4 + expandable, offline, toggle, 0 external) → Task 6. ✓

**Placeholder scan:** No TBD/TODO; every file step contains complete content. ✓

**Type/name consistency:** CSS class names consistent across files — `rpt-table`,
`rpt-flow`, `rpt-states`, `rpt-c4`, `rpt-exp`, `rpt-graph`; custom props
`--bg/--surface/--fg/--accent/--border/--line/--zebra/--ok/--warn/--danger` defined in
themes.md (Task 2) and consumed in Tasks 3–5; `#theme-toggle` defined in Task 2,
checked in Task 6 step 3. ✓
