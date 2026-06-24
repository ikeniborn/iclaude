# Chain Report (multi-tab IDD→SDD merge)

`mode: chain` produces ONE unified report for a whole IDD→SDD chain with four
switchable tabs — **Intent / Spec / Plan / Result** — that the four `check-*`
commands fill incrementally. Each command owns ONE tab and updates only that tab;
the other three are preserved verbatim across runs. Default `standalone` mode (no
`mode` passed) is unchanged — this file applies only when the caller passes
`mode: chain`.

## Caller contract

A `check-*` command invokes the skill with:

- `mode: chain` — selects this code path.
- `tab: intent | spec | plan | result` — exactly one; the tab this run owns.
- `target: docs/superpowers/reports/<topic>-results.html` — the unified file
  (caller-supplied path ⇒ **Full** zone: create/merge without asking; see
  "Autonomy" below).
- The same inline data blocks the command passes today (requirements summary,
  diagrams, check results). Content is unchanged — it now lands in one tab's
  region instead of being a whole file.

The skill never reads chain sources itself; all tab content arrives inline. The
ONLY file the skill reads in this mode is the existing `target` (its own prior
output), as a merge source.

## Document skeleton + boundary markers

The unified file is one self-contained zero-JS HTML. Tab regions are delimited by
**exact HTML-comment markers** so the skill can replace one tab byte-precisely and
leave the rest untouched:

```html
<body>
  <input type="checkbox" id="theme-toggle" hidden>
  <input type="radio" name="chain-tab" id="tab-intent" class="tab-radio" hidden checked>
  <input type="radio" name="chain-tab" id="tab-spec"   class="tab-radio" hidden>
  <input type="radio" name="chain-tab" id="tab-plan"   class="tab-radio" hidden>
  <input type="radio" name="chain-tab" id="tab-result" class="tab-radio" hidden>
  <header>
    <label for="theme-toggle" class="theme-btn" title="Toggle dark/light">🌙 / ☀️</label>
    <h1>…chain topic…</h1>
  </header>
  <nav class="chain-tabs">
    <label for="tab-intent">Intent</label>
    <label for="tab-spec">Spec</label>
    <label for="tab-plan">Plan</label>
    <label for="tab-result">Result</label>
  </nav>
  <!-- TAB:intent START -->
  <section class="tab-pane" id="pane-intent"> …intent content OR placeholder… </section>
  <!-- TAB:intent END -->
  <!-- TAB:spec START -->
  <section class="tab-pane" id="pane-spec"> … </section>
  <!-- TAB:spec END -->
  <!-- TAB:plan START -->
  <section class="tab-pane" id="pane-plan"> … </section>
  <!-- TAB:plan END -->
  <!-- TAB:result START -->
  <section class="tab-pane" id="pane-result"> … </section>
  <!-- TAB:result END -->
</body>
```

### Marker rules (MUST)

- Markers are the exact literal strings `<!-- TAB:<id> START -->` and
  `<!-- TAB:<id> END -->`, one pair per tab, in the order intent → spec → plan →
  result, never nested, never reordered.
- On update the skill replaces ONLY the bytes strictly between a tab's START and
  END markers (the markers themselves stay). Everything outside the four marked
  regions — `<head>`/`<style>`, the theme toggle, the radios, header, nav,
  scripts — is preserved byte-for-byte, with ONE exception: the `checked`
  attribute moves to the owning tab's radio (below).
- All four marker pairs are emitted on the FIRST run even when three panes are
  placeholders, so every later update finds its region.

### Decision: markers, not id-parsing

Boundary markers beat extracting by `id="pane-spec"`: the skill assembles HTML as
a string with no DOM library, so a `START…END` slice (`indexOf`-style) is
unambiguous and survives arbitrary inner-HTML changes, nested `<section>` /
`<details>`, and content that would confuse a naive tag matcher. id-parsing is the
fallback only when a marker pair is missing (treated as corruption — see Flows).

## Zero-JS tab switcher

Built on the same checkbox-hack as the theme toggle (`themes.md`), generalized to a
radio group. The four radios share `name="chain-tab"`, so radio semantics enforce
exactly one active tab for free:

```css
.tab-pane{ display:none; }
body:has(#tab-intent:checked) #pane-intent,
body:has(#tab-spec:checked)   #pane-spec,
body:has(#tab-plan:checked)   #pane-plan,
body:has(#tab-result:checked) #pane-result{ display:block; }

/* active-tab label highlight, same has() pattern */
.chain-tabs label{ cursor:pointer; padding:.4rem .9rem; border:1px solid var(--border);
  border-bottom:none; border-radius:8px 8px 0 0; background:var(--surface); color:var(--muted); }
body:has(#tab-intent:checked) label[for="tab-intent"],
body:has(#tab-spec:checked)   label[for="tab-spec"],
body:has(#tab-plan:checked)   label[for="tab-plan"],
body:has(#tab-result:checked) label[for="tab-result"]{ color:var(--accent); border-color:var(--accent); font-weight:600; }
```

The tab radio group is **independent** of the theme toggle (`#theme-toggle`): the
`body:has()` selectors for tabs and for theme compose without interfering, so a
report can be dark AND on the Plan tab simultaneously. The default-active tab is the
one the current run just updated, so the user lands on fresh content (move the single
`checked` to the owning radio).

## Placeholder for unchecked tabs

A stage not yet run gets this pane on first-run skeleton creation (Russian, matching
report language):

```html
<section class="tab-pane" id="pane-spec">
  <p class="note">Этап ещё не проверен.</p>
</section>
```

When that stage later runs, its placeholder region is replaced with real content via
its markers.

## Flows

### First run (target absent)

Assemble the full envelope (head/style + theme toggle + radios + nav + all four
marker pairs). The caller's `tab` gets real content; the other three get the
placeholder. Set `checked` on the caller's radio. Self-validate; write.

### Update (target present)

1. Read the existing file as a string.
2. Locate the caller's `<!-- TAB:<tab> START -->` / `<!-- TAB:<tab> END -->`.
3. Replace the inter-marker slice with the freshly assembled pane content.
4. Move the single `checked` attribute to this tab's radio; clear it on the others.
5. Do NOT re-render `<head>`, the other three panes, or scripts.
6. Self-validate; write.

### Corruption (any of the 4 marker pairs missing / duplicated / out of order)

Rebuild the whole envelope from skeleton, carrying over each sibling pane's content
where its markers are still intact, placeholder otherwise, then insert the caller's
fresh pane. **Log** the recovery (guarded behavior — structure had to be rebuilt).
Self-validate; write.

## Autonomy

The unified `target` is caller-supplied ⇒ **Full** zone: create on first run and
merge on update, both without a proposal-first pause. The existing report read as a
merge source is itself caller-supplied — overwriting it is Full, NOT the
proposal-first "overwriting an existing default `docs/reports/` file" case (which
applies only when the skill chose the default path with no caller path).

## Self-validation (chain mode — in addition to the base checklist)

- [ ] All four `<!-- TAB:{intent,spec,plan,result} START/END -->` pairs present,
      correctly ordered, non-overlapping.
- [ ] Exactly one `.tab-radio` carries `checked` (exactly one active pane).
- [ ] Theme toggle present and its `body:has(#theme-toggle…)` selectors intact
      alongside the tab `body:has(#tab-…)` selectors (toggle not clobbered by merge).
- [ ] On update: the three non-owned panes are byte-identical to the pre-existing
      file (only the owned region + the single `checked` attribute changed).
