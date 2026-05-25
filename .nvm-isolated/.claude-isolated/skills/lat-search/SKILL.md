---
name: lat-search
description: >-
  Find lat.md sections and run semantic search portably in any project via
  iclaude. Use when CLAUDE.md says "run lat search" or when you need to locate
  documentation sections before starting work.
---

# lat-search

Run lat search, locate, refs, and section commands portably.

## Binary resolution

```bash
_lat="${CLAUDE_CONFIG_DIR}/scripts/lat-runner.sh"
# fallback: "${NPM_CONFIG_PREFIX}/bin/lat"
```

Always run from the project directory (`$LAUNCH_DIR`).

## Commands

```bash
# Semantic search (requires LAT_LLM_KEY in .claude_config)
"$_lat" search "your natural language query"

# Find section by name — no LLM key needed
"$_lat" locate "Section Name"

# Show section content
"$_lat" section path/to/file#Heading

# Find what references a section
"$_lat" refs path/to/file#Heading

# Expand [[refs]] in a prompt to file locations
"$_lat" expand "prompt text with [[Section Name]]"
```

## If LAT_LLM_KEY is not set

`lat search` requires an LLM key. If not available, use `lat locate` as a fallback (no key needed):

```bash
"${CLAUDE_CONFIG_DIR}/scripts/lat-runner.sh" locate "Section Name"
```

Inform the user: "LAT_LLM_KEY not set — using `lat locate` instead of `lat search`. Set `LAT_LLM_KEY` in `.claude_config` for semantic search."

## When to use

- CLAUDE.md "Before starting work" says "run `lat search`"
- You need to find documentation sections relevant to a task
- You need to expand `[[refs]]` to file locations

Do NOT run `lat search` via bare `Bash(lat search)` — the binary is not on PATH outside iclaude context.
