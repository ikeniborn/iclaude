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
