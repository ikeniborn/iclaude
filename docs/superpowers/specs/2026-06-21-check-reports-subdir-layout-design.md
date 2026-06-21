---
date: 2026-06-21
topic: check-reports-subdir-layout
status: draft
chain:
  intent: null
review:
  spec_hash: f468f072b9fc86fb
  last_run: 2026-06-21
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings: []
---

# Design: Split check-* HTML reports into per-artifact subdirectories

## Problem

The four IDD check commands (`check-intent`, `check-spec`, `check-plan`,
`check-result`) all write their HTML report into a single flat directory
`docs/superpowers/reports/`. As the number of artifacts grows, this directory
mixes intent, spec, plan, and result reports together with no structure, making
it hard to locate a given report and visually noisy.

## Goal

Route each command's report into a dedicated subdirectory of
`docs/superpowers/reports/`, one subdirectory per artifact kind.

## Path scheme

| Command        | Old output path                              | New output path                                       |
|----------------|----------------------------------------------|-------------------------------------------------------|
| `check-intent` | `reports/<name>-check.html`                  | `reports/intents/<name>-check.html`                   |
| `check-spec`   | `reports/<name>-check.html`                  | `reports/specs/<name>-check.html`                     |
| `check-plan`   | `reports/<name>-check.html`                  | `reports/plans/<name>-check.html`                     |
| `check-result` | `reports/<name>-result-check.html`           | `reports/results/<name>-result-check.html`            |

`<name>` is the artifact basename without `.md` (unchanged by this work). The
in-parentheses filename example in each command stays as-is — only the directory
changes.

## Scope of changes

Four command files under `.nvm-isolated/.claude-isolated/commands/`, one line
each (the "Выход: …" artifact-parameter bullet):

- `check-intent.md:145`
- `check-spec.md:141`
- `check-plan.md:142`
- `check-result.md:98`

Each bullet currently reads (translated): *Output: `docs/superpowers/reports/<basename>-check.html` … Create the directory `docs/superpowers/reports/`, if it does not exist.* Both the output path and the "create directory" instruction are updated to the matching subdirectory.

## Migration

The one existing flat report is moved into its new home:

```
git mv docs/superpowers/reports/2026-06-17-iwiki-result-check.html \
       docs/superpowers/reports/results/
```

## Non-goals

- No changes to hooks (`idd-gate.py`, `idd-nudge.py`), `CLAUDE.md`, the
  `html-report` skill, or any bash module — none reference the reports path
  (verified by `grep -rn "superpowers/reports"`).
- No pre-created empty `intents/`/`specs/`/`plans/` directories — git does not
  track empty dirs, and each command already creates its target directory on
  demand. `results/` comes into existence via the `git mv` above.
- Filename conventions (the `-check` / `-result-check` suffixes, date prefix,
  basename) are unchanged.
- These command files are outside the iwiki doc-graph scope (commands/ is
  excluded), so no `iwiki-ingest` / `iwiki-lint` follow-up is required.

## Verification

1. `grep -rn "superpowers/reports/" .nvm-isolated/.claude-isolated/commands/`
   shows exactly four paths, each with its subdirectory; no bare flat
   `reports/<name>` path remains.
2. `ls docs/superpowers/reports/results/` lists the migrated file; the flat
   `reports/2026-06-17-iwiki-result-check.html` no longer exists.
