# SVG / Bounded-JS Fallback

Use ONLY when CSS cannot draw the structure: arbitrary node→edge graphs, free-form
connectors between non-adjacent nodes, or data plots. Everything is inline. When you
use this fallback, **log** the specific structure CSS could not express (guarded zone).

> For **pipelines, loops, and state machines** (positioned nodes + directional/looping
> labeled edges), use the structured grammar in `svg-diagrams.md` instead — it has a
> reusable node-card + arrow-marker + animated-connector system. This file is the
> lower-level escape for graphs that don't fit that grammar.

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
