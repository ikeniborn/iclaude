# Graphify: Fix chunk files written to wrong directory

**Date:** 2026-05-06  
**Status:** Approved

## Problem

When `GRAPHIFY_OUT` is set to a non-default value (e.g. `.graphify`) in `.claude_config`, semantic extraction chunk files (`.graphify_chunk_NN.json`) are written to `graphify-out/` instead of the configured directory.

**Root cause:** Subagents spawned via the Agent tool do not inherit environment variables from the parent session. The subagent prompt contains no instruction about where to write the chunk file. Python code inside the subagent falls back to the default:

```python
GOUT = os.environ.get('GRAPHIFY_OUT', 'graphify-out')
```

The orchestrator uses `.graphify` (from env), but subagents use `graphify-out` (fallback).

**Affected step:** SKILL.md Step B2 — subagent prompt template.  
**Not affected:** All other outputs (graph.json, GRAPH_REPORT.md, etc.) are written by the orchestrator, which has `GRAPHIFY_OUT` in env.

## Solution: Variant A — Explicit path in subagent prompt

The orchestrator resolves the chunk output path before dispatching subagents and passes it as a literal string (not an env var reference) in the subagent prompt.

No absolute project paths appear in SKILL.md — only relative paths using the `GRAPHIFY_OUT` value.

## Design

### Change 1 — Step B2: subagent prompt template

Add as the **first line** of the subagent prompt (before all other instructions), substituting `CHUNK_OUTPUT_PATH` with the literal value before dispatch:

```
Save your JSON output using the Write tool to this exact path: CHUNK_OUTPUT_PATH
Do not write to any other path or directory.
```

Where the orchestrator substitutes `CHUNK_OUTPUT_PATH` → `${GRAPHIFY_OUT}/.graphify_chunk_${NN}.json` (the current string value of `GRAPHIFY_OUT`, not the variable name) for each chunk before calling the Agent tool.

Example: if `GRAPHIFY_OUT=.graphify` and chunk number is `01`, the subagent receives:
```
Save your JSON output using the Write tool to this exact path: .graphify/.graphify_chunk_01.json
Do not write to any other path or directory.
```

Relative path works because subagents inherit CWD from the parent session.

### Change 2 — Step B3: dispatch note

Add a note to clarify the substitution requirement:

```
Note: substitute the actual value of GRAPHIFY_OUT (e.g. ".graphify"), not the variable name,
when constructing CHUNK_OUTPUT_PATH for each subagent prompt.
```

## Affected files

| File | Change |
|------|--------|
| `.nvm-isolated/.claude-isolated/skills/graphify/SKILL.md` | Step B2 prompt template + Step B3 note |

## Success criteria

- `.graphify_chunk_*.json` files appear in `${GRAPHIFY_OUT}/` (e.g. `.graphify/`)
- No chunk files in `graphify-out/` when `GRAPHIFY_OUT` is set to a different value
- Works for any `GRAPHIFY_OUT` value (relative or absolute)
- No absolute project paths introduced into SKILL.md
