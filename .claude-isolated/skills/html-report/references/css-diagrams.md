# CSS Diagram Recipes

Pure-CSS recipes + report components. Each is semantic HTML + theme-aware CSS (uses the
custom props from `themes.md`: `--bg --surface --fg --muted --accent --border --line
--zebra --shadow --ok/-2 --warn/-2 --danger`). Prefer these over any `<div>` soup.
Escalate to `svg-diagrams.md` for pipelines/loops/state machines with labeled or
looping edges, and to `svg-fallback.md` for arbitrary node→edge graphs / free connectors.

## 1. Table (`<table>`)

Use `border-spacing:0` + `overflow:hidden` on a rounded, shadowed wrapper so the radius
clips the header corners. `rowspan` groups related rows (a file with many models); inline
`<code>`/`<span class="badge">` enrich cells (see Components below).

```html
<table class="rpt-table">
  <thead><tr><th>File</th><th>Model</th><th>Parts</th></tr></thead>
  <tbody>
    <tr><td rowspan="2"><code>ir_models.py</code></td><td><code>IntentSpec</code></td><td>PredExpr, Constraint</td></tr>
    <tr><td><code>PlanIR</code></td><td>Step, RowSet, ComputeStep</td></tr>
    <tr><td><code>verify.py</code></td><td><code>verify()</code></td><td>criteria + refs <span class="badge det">det</span></td></tr>
  </tbody>
</table>
```

```css
.rpt-table{ border-collapse:separate; border-spacing:0; width:100%; background:var(--surface);
  margin:1rem 0; font-size:.92rem; border:1px solid var(--border); border-radius:10px;
  overflow:hidden; box-shadow:0 2px 12px var(--shadow); }
.rpt-table th, .rpt-table td{ border-bottom:1px solid var(--border); padding:.5rem .75rem; text-align:left; vertical-align:top; }
.rpt-table tbody tr:last-child td{ border-bottom:none; }
.rpt-table thead th{ background:var(--accent); color:var(--bg); position:sticky; top:0; }
.rpt-table tbody tr:nth-child(even){ background:var(--zebra); }
.rpt-table tbody tr:hover{ background:color-mix(in srgb, var(--accent) 14%, var(--surface)); }
.rpt-table td code{ white-space:nowrap; }
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

Give each `comp` a name in `<b>` + a `<span class="sub">` role line, and an accent
`border-left` so it reads as a component card. Tint the boundary fill with `color-mix`.

```html
<figure class="rpt-c4">
  <div class="boundary" data-label="System · harness">
    <div class="comp"><b>main.py</b><br><span class="sub">entry · training-loop</span></div>
    <div class="boundary" data-label="agent/ · pipeline">
      <div class="comp"><b>orchestrator.py</b><br><span class="sub">run_agent()</span></div>
      <div class="comp"><b>verify.py</b><br><span class="sub">quality-gate</span></div>
    </div>
    <div class="boundary" data-label="External · VM">
      <div class="comp"><b>VM RPC</b><br><span class="sub">SQL · files</span></div>
    </div>
  </div>
</figure>
```

```css
.rpt-c4 .boundary{
  border:1.6px dashed var(--accent); border-radius:12px;
  padding:1.8rem 1rem 1rem; margin:.7rem 0; position:relative;
  display:flex; flex-wrap:wrap; gap:.6rem;
  background:color-mix(in srgb, var(--accent) 5%, transparent);
}
.rpt-c4 .boundary::before{
  content:attr(data-label); position:absolute; top:-.7rem; left:.9rem;
  background:var(--bg); padding:0 .45rem; font-size:.8rem; color:var(--accent); font-weight:600;
}
.rpt-c4 .comp{
  background:var(--surface); border:1px solid var(--border); border-radius:8px;
  padding:.55rem .85rem; min-width:6rem; font-size:.85rem; box-shadow:0 1px 6px var(--shadow);
  border-left:4px solid var(--accent);
}
.rpt-c4 .comp b{ color:var(--accent); }
```

## 5. Report components (callout, badge, typography)

Small reusable pieces that make a report read like a document. All theme-aware.

```html
<p class="lead">One-line thesis of the report, slightly larger.</p>
<p class="sub">metadata · branch <code>x</code> · generated 2026-06-18 · sources: <code>a.py</code></p>

<div class="note"><b>Key invariant:</b> <code>answer()</code> is called exactly once per task.</div>

<details>
  <summary>Phase details (click to expand)</summary>
  <ul class="tight"><li><b>INTENT</b> — frozen after first pass.</li></ul>
</details>

<span class="badge llm">LLM</span> <span class="badge det">deterministic</span>
```

```css
.lead{ font-size:1.08rem; }
.sub{ color:var(--muted); font-size:.95rem; }
.note{ border-left:4px solid var(--accent); padding:.55rem 1rem; margin:1rem 0;
  background:color-mix(in srgb, var(--accent) 8%, var(--surface)); border-radius:0 8px 8px 0;
  box-shadow:0 1px 8px var(--shadow); }
details{ background:var(--surface); border:1px solid var(--border); border-radius:10px;
  padding:.7rem 1rem; margin:.7rem 0; box-shadow:0 1px 8px var(--shadow); }
details summary{ cursor:pointer; font-weight:600; color:var(--accent); }
details[open] summary{ margin-bottom:.55rem; }
ul.tight li{ margin:.28rem 0; }
.badge{ display:inline-block; font-size:.72rem; padding:.05rem .5rem; border-radius:999px; border:1px solid var(--border); }
.badge.llm{ color:var(--warn-2); border-color:var(--warn); }
.badge.det{ color:var(--ok-2);  border-color:var(--ok); }
```
