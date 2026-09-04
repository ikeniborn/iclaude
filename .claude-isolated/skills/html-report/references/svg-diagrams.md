# SVG Flow & Diagram Grammar

The high-fidelity recipe for **pipelines, loops, state machines, and labeled flows** —
anything where positioned nodes connect with directional, possibly looping, arrows.
This is the format that makes a report read like an architecture doc, not a slide.

Use this when the flex `.rpt-flow` / `.rpt-states` recipes (`css-diagrams.md`) are too
flat: you need a loop-back edge, a non-adjacent connector, a labeled branch, or a node
with a colored status bar. Everything is inline and theme-aware — CSS custom props
cascade into inline SVG, so `fill="var(--surface)"` / `stroke="var(--line)"` just work.

## Why SVG over flex here

Flex flows can only draw left-to-right adjacency. SVG gives you absolute coordinates
(`viewBox`), so you can route an edge from the last node back to the first (retry loop),
fan one node out to two terminal states (PASS / FAIL branches), and label any edge by
stamping text on an opaque background patch over the line.

## Step 1 — shared `<defs>` (define once, near top of `<body>`)

One hidden SVG holds the dropshadow filter and one arrow marker per semantic color.
Every diagram below references these by id.

```html
<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs>
  <filter id="dropshadow" x="-20%" y="-20%" width="140%" height="160%">
    <feDropShadow dx="0" dy="2.5" stdDeviation="3.5" flood-color="var(--shadow)" flood-opacity="1"/>
  </filter>
  <marker id="arr"     markerUnits="userSpaceOnUse" markerWidth="12" markerHeight="12" refX="9" refY="4" orient="auto"><path d="M0,0 L9,4 L0,8 Z" fill="var(--line)"/></marker>
  <marker id="arrA"    markerUnits="userSpaceOnUse" markerWidth="12" markerHeight="12" refX="9" refY="4" orient="auto"><path d="M0,0 L9,4 L0,8 Z" fill="var(--accent)"/></marker>
  <marker id="arrOk"   markerUnits="userSpaceOnUse" markerWidth="12" markerHeight="12" refX="9" refY="4" orient="auto"><path d="M0,0 L9,4 L0,8 Z" fill="var(--ok)"/></marker>
  <marker id="arrTerm" markerUnits="userSpaceOnUse" markerWidth="12" markerHeight="12" refX="9" refY="4" orient="auto"><path d="M0,0 L9,4 L0,8 Z" fill="var(--danger)"/></marker>
</defs></svg>
```

## Step 2 — the SVG style block (add to the inline `<style>`)

```css
figure.diagram{ margin:1.2rem 0; }
figure.diagram svg{ width:100%; height:auto; display:block; overflow:visible; }
figcaption{ color:var(--muted); font-size:.85rem; margin-top:.35rem; text-align:center; }

/* node card — rounded surface + dropshadow, accent-bar stripe on the left */
.card{ fill:var(--surface); stroke:var(--border); stroke-width:1.5; filter:url(#dropshadow); transition:stroke .15s, stroke-width .15s; }
.node:hover .card{ stroke:var(--accent); stroke-width:2.5; }
.bar-accent{ fill:var(--accent); } .bar-ok{ fill:var(--ok); }
.bar-warn{ fill:var(--warn); } .bar-term{ fill:var(--danger); }
.t-title{ fill:var(--fg); font:600 14px system-ui, sans-serif; }
.t-sub{ fill:var(--muted); font:11px system-ui, sans-serif; }
.t-mono{ font-family:ui-monospace, monospace; }
text{ pointer-events:none; }

/* connectors — static, accent-dashed, and animated "marching ants" */
.conn{ fill:none; stroke:var(--line); stroke-width:2; }
.conn-a{ fill:none; stroke:var(--accent); stroke-width:2; stroke-dasharray:5 5; }
.conn-term{ fill:none; stroke:var(--danger); stroke-width:2.2; }
.flow{ fill:none; stroke:var(--accent); stroke-width:2.6; stroke-dasharray:8 6; animation:dash 1.1s linear infinite; }
.flow-ok{ fill:none; stroke:var(--ok); stroke-width:2.6; stroke-dasharray:8 6; animation:dash 1.1s linear infinite; }
@keyframes dash{ to{ stroke-dashoffset:-14; } }
@media (prefers-reduced-motion: reduce){ .flow,.flow-ok{ animation:none; } }

/* edge labels — opaque patch behind text so it sits cleanly over a line */
.lbl-bg{ fill:var(--bg); }
.lbl{ fill:var(--fg); font:11px system-ui, sans-serif; }
/* dashed container for a sub-region (e.g. a loop body) */
.boundary-rect{ fill:none; stroke:var(--accent); stroke-width:1.6; stroke-dasharray:7 6; opacity:.85; }
```

## Step 3 — node primitive (copy per node)

A node = `<g class="node">` holding a `.card` rect, a colored status bar, and two text
lines. Pick the bar color by node semantics: `bar-accent` (LLM/active), `bar-ok`
(deterministic/success), `bar-warn` (guard/caution), `bar-term` (terminal/danger).

```html
<g class="node">
  <rect class="card" x="48" y="150" width="150" height="60" rx="12"/>
  <rect class="bar-ok" x="56" y="162" width="5" height="36" rx="2.5"/>
  <text class="t-title" x="123" y="176" text-anchor="middle">lint</text>
  <text class="t-sub"   x="123" y="194" text-anchor="middle">det · security-first</text>
</g>
```

## Step 4 — connectors & labels

```html
<!-- straight animated edge between two nodes -->
<path class="flow" marker-end="url(#arrA)" d="M198,180 H209"/>

<!-- labeled branch: opaque patch, then text centered on it -->
<rect class="lbl-bg" x="300" y="385" width="92" height="18"/>
<text class="lbl" x="346" y="398" text-anchor="middle">verify PASS</text>

<!-- loop-back edge (last node → first), rounded corners via Q -->
<path class="conn-a" marker-end="url(#arrA)"
      d="M795,210 V300 Q795,312 783,312 L135,312 Q123,312 123,300 V214"/>
```

## Full example — labeled retry loop with two terminal branches

A complete `<figure>`: a row of phase nodes inside a dashed loop boundary, a retry edge
looping back, and the loop fanning out to a success node and a terminal node.

```html
<figure class="diagram">
<svg viewBox="0 0 920 360" role="img" aria-label="Pipeline loop with PASS and terminal branches">
  <!-- loop boundary + its label (label patch sits over the dashed border) -->
  <rect class="boundary-rect" x="24" y="20" width="872" height="190" rx="16"/>
  <rect class="lbl-bg" x="40" y="12" width="280" height="18"/>
  <text class="lbl" x="48" y="25" font-weight="600">LOOP · cycle = 1 … MAX_STEPS</text>

  <!-- phase nodes -->
  <g class="node"><rect class="card" x="48"  y="60" width="150" height="60" rx="12"/><rect class="bar-accent" x="56"  y="72" width="5" height="36" rx="2.5"/><text class="t-title" x="123" y="86" text-anchor="middle">PLAN</text><text class="t-sub" x="123" y="104" text-anchor="middle">LLM → IR</text></g>
  <g class="node"><rect class="card" x="384" y="60" width="150" height="60" rx="12"/><rect class="bar-ok"     x="392" y="72" width="5" height="36" rx="2.5"/><text class="t-title" x="459" y="86" text-anchor="middle">interpret</text><text class="t-sub" x="459" y="104" text-anchor="middle">det</text></g>
  <g class="node"><rect class="card" x="720" y="60" width="150" height="60" rx="12"/><rect class="bar-ok"     x="728" y="72" width="5" height="36" rx="2.5"/><text class="t-title" x="795" y="86" text-anchor="middle">verify</text><text class="t-sub" x="795" y="104" text-anchor="middle">gate</text></g>

  <!-- forward edges -->
  <path class="flow" marker-end="url(#arrA)" d="M198,90 H377"/>
  <path class="flow" marker-end="url(#arrA)" d="M534,90 H713"/>

  <!-- retry loop back -->
  <path class="conn-a" marker-end="url(#arrA)" d="M795,120 V165 Q795,177 783,177 L135,177 Q123,177 123,165 V124"/>
  <rect class="lbl-bg" x="396" y="168" width="128" height="18"/>
  <text class="lbl" x="460" y="181" text-anchor="middle">fail → retry</text>

  <!-- branches out of the loop -->
  <path class="flow-ok"   marker-end="url(#arrOk)"   d="M460,210 C460,250 300,250 250,262"/>
  <path class="conn-term" marker-end="url(#arrTerm)" d="M460,210 C460,250 660,250 690,262"/>
  <rect class="lbl-bg" x="300" y="232" width="92" height="18"/><text class="lbl" x="346" y="245" text-anchor="middle">verify PASS</text>
  <rect class="lbl-bg" x="548" y="232" width="120" height="18"/><text class="lbl" x="608" y="245" text-anchor="middle">exhaust / break</text>

  <!-- terminal nodes -->
  <g class="node"><rect class="card" x="70"  y="264" width="360" height="60" rx="14"/><rect class="bar-ok"   x="78"  y="278" width="5" height="32" rx="2.5"/><text class="t-title" x="250" y="298" text-anchor="middle">answer ×1</text></g>
  <g class="node"><rect class="card" x="500" y="264" width="360" height="60" rx="14"/><rect class="bar-term" x="508" y="278" width="5" height="32" rx="2.5"/><text class="t-title t-mono" x="680" y="298" text-anchor="middle">CLARIFICATION</text></g>
</svg>
<figcaption>Caption the diagram with the env vars / invariants it encodes.</figcaption>
</figure>
```

## Layout tips

- **Coordinate math, not guessing.** Pick a node width (e.g. 150) and a gap (e.g. 18);
  next node `x = prev.x + width + gap`. Edge `d="M{prev.x+width},{cy} H{next.x}"`.
- **`viewBox` sets the aspect**; `svg{width:100%}` scales it responsively. Height in
  the viewBox is your true canvas height — leave ~20px margin so dropshadows aren't clipped
  (`overflow:visible` on the svg also prevents clipping).
- **Center text** with `text-anchor="middle"` at the node's horizontal center
  (`x = card.x + width/2`); title baseline ≈ card top + 28, sub ≈ + 46.
- **Pill/state node**: same `.card` rect with a large `rx` (≈ height/2) for a rounded
  capsule — use for state-machine nodes (see the transition diagram pattern).
- Always set `role="img"` and a descriptive `aria-label` on each `<svg>`.

## This is still a guarded zone

SVG is the `svg-fallback.md` escalation path. When you use it, **log** that CSS flex
could not express the structure (loop-back / branch / non-adjacent edge). An inline
`<script>` is NOT needed for any diagram here — they are fully static + CSS-animated.
Add `<script>` only for true graph interactivity, under the `svg-fallback.md` bounds.
