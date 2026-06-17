# Themes & Toggle

Pure-CSS dark/light theming via a checkbox hack. Zero JS. Every recipe colors itself
from the shared custom properties below, so one toggle reskins the whole report.

## Custom properties + toggle

Place the toggle control inside `<body>` (typically first, before the report).
`body:has(#theme-toggle:checked)` flips the palette on `<body>` itself, so the page
background AND every descendant inherit the new theme. (A sibling selector like
`#theme-toggle:checked ~ *` would skip `<body>` and the inherited `color`, leaving the
page background and text stuck on the light palette.)

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
/* Dark = Catppuccin Mocha; :checked flips the whole palette on <body> */
body:has(#theme-toggle:checked){
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
