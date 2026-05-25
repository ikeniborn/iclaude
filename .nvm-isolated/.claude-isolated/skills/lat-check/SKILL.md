---
name: lat-check
description: >-
  Run lat check portably in any project launched via iclaude. Validates all
  wiki links and code refs in lat.md/. Use when CLAUDE.md says "run lat check"
  or after editing lat.md/ files.
---

# lat-check

Run `lat check` portably using the binary resolver, from the project directory.

## How to run

Prefer the runner script when available:

```bash
"${CLAUDE_CONFIG_DIR}/scripts/lat-runner.sh" check
```

Alternative when `NPM_CONFIG_PREFIX` is exported:

```bash
"${NPM_CONFIG_PREFIX}/bin/lat" check
```

Always run from the project directory (not the iclaude dir). `LAUNCH_DIR` is the project root.

## Exit codes

- `0` — all wiki links and code refs valid; nothing to fix
- `1` — broken refs found; output lists each broken link with file path and line number

## When to use

- CLAUDE.md post-task checklist says "Run `lat check`"
- After creating or editing `lat.md/` files
- Before committing changes in a project with `lat.md/`

Do NOT run `lat check` via bare `Bash(lat check)` — the binary is not on PATH outside iclaude context.
