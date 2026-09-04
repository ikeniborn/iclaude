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

Carry a full set: `--muted` (secondary text), `--shadow` (rgba for box-/drop-shadows),
and `-2` darker variants of status colors (`--ok-2 --warn-2 --danger-2`) for text/badges
that need contrast. `--accent-2` is a deeper accent for gradients/hover.

```css
/* Light = default palette on :root */
:root{
  --bg:#f6f7fb; --surface:#ffffff; --fg:#2b2b3a; --muted:#6b6b80;
  --accent:#5c6bc0; --accent-2:#3949ab; --border:#d6d8e6; --line:#9aa0b4; --zebra:#eef0f8;
  --ok:#43a047; --ok-2:#2e7d32; --warn:#fb8c00; --warn-2:#ef6c00; --danger:#e53935; --danger-2:#c62828;
  --shadow:rgba(40,40,80,.18);
}
/* Dark = Catppuccin Mocha; :checked flips the whole palette on <body> */
body:has(#theme-toggle:checked){
  --bg:#181825; --surface:#262637; --fg:#cdd6f4; --muted:#a6adc8;
  --accent:#89b4fa; --accent-2:#5e95f0; --border:#3a3b52; --line:#6c7086; --zebra:#21222f;
  --ok:#a6e3a1; --ok-2:#74c46e; --warn:#f9e2af; --warn-2:#f5c95b; --danger:#f38ba8; --danger-2:#e8638a;
  --shadow:rgba(0,0,0,.45);
}
body{
  margin:0 auto; padding:1.5rem 2rem 4rem; max-width:1080px;
  font:16px/1.55 system-ui, sans-serif;
  /* subtle accent-tinted radial wash over the base bg — optional but lifts the page */
  background:
    radial-gradient(1200px 500px at 100% -10%, color-mix(in srgb,var(--accent) 10%, transparent), transparent),
    var(--bg);
  color:var(--fg);
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
- `--line` is a mid-tone connector color — legible (~4:1) on both themes. Do not use
  dark (`#333`) or light (`#ccc`) connectors; they vanish on one theme.
- **Derive shades, don't hardcode them.** `color-mix(in srgb, var(--accent) 14%, var(--surface))`
  gives a theme-correct tint for hover rows, note backgrounds, boundary fills — it
  recomputes on toggle, so you never maintain a second dark value.
- `--shadow` is an rgba so shadows are visible on both themes; feed it to CSS
  `box-shadow` AND the SVG `feDropShadow flood-color` (see `svg-diagrams.md`).
- Light is the default; the toggle has no persistence (no JS/localStorage). The spec
  requires a *working* toggle, not persistence.
- Keep contrast adequate: body text on `--bg`, headings/accents on `--accent`, secondary
  text on `--muted`, status text on the `-2` variants.
