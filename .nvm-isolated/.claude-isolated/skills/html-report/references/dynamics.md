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

## Tabbed panes — radio group + `:has`

Zero-JS tabs: a radio group (one shared `name`, so exactly one is `checked`) plus
`body:has(#tab-…:checked) #pane-…{display:block}` toggles which pane shows. Same
checkbox-hack as the theme toggle (`themes.md`); the two groups compose without
interfering.

```html
<input type="radio" name="tabs" id="tab-a" hidden checked>
<input type="radio" name="tabs" id="tab-b" hidden>
<nav><label for="tab-a">A</label><label for="tab-b">B</label></nav>
<section class="tab-pane" id="pane-a">…</section>
<section class="tab-pane" id="pane-b">…</section>
```
```css
.tab-pane{ display:none; }
body:has(#tab-a:checked) #pane-a, body:has(#tab-b:checked) #pane-b{ display:block; }
```

Full IDD→SDD chain-report merge contract (boundary markers, per-tab update,
placeholder) → `chain-report.md`.
