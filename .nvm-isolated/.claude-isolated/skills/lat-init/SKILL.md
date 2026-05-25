---
name: lat-init
description: >-
  Initialize lat.md/ documentation graph in a project via iclaude. Use when
  the user asks to set up lat.md in a project, or when CLAUDE.md says
  "run --lat-init".
---

# lat-init

Initialize `lat.md/` in the current project via iclaude.

## How to run

From the project directory (not the iclaude dir):

```bash
cd /path/to/your-project
/path/to/iclaude.sh --lat-init
```

Or if iclaude is on PATH:

```bash
iclaude.sh --lat-init
```

## What it does

1. Runs `lat init` in `$LAUNCH_DIR` (creates `lat.md/` scaffold)
2. Cleans up per-project artifacts iclaude manages centrally:
   - Removes `.claude/skills/lat-md/` (skill lives in iclaude isolated dir)
   - Removes `.mcp.json` (MCP registered via iclaude `inject_lat_mcp`)
   - Strips lat hooks from `.claude/settings.json`

## Prerequisites

lat must be installed: `./iclaude.sh --install-lat`

If not installed, `--lat-init` exits with error:
```
lat not installed. Run: ./iclaude.sh --install-lat
```

## After init

- MCP server wires automatically on next `./iclaude.sh` launch (when `lat.md/` is detected)
- Run `lat-check` skill to validate links after editing `lat.md/` files
- Run `lat-search` skill to find sections

## When to use

- Setting up lat.md documentation in a new project
- User asks "initialize lat" or "set up lat.md"
