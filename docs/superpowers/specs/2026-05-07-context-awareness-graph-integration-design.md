# Design: Graph Integration into Downstream Skills

**Date:** 2026-05-07  
**Status:** Approved  
**Scope:** 5 SKILL.md files — additive only, no deletions, no refactoring

## Problem

`context-awareness` populates `project_context` with graph fields (`graph_initialized`, `graph_summary`, `graph_god_nodes`, `graph_communities`) but zero downstream skills consume them. `wiki_initialized` is consumed by 2 skills (architecture-documentation, prd-generator); graph fields are dead data. `brainstorming` ignores the graph entirely at Step 1.

## Goal

Graph data in `project_context` is actively used by brainstorming, architecture-documentation, and prd-generator. Staleness is surfaced to downstream consumers. No new abstractions introduced.

## Approach: Wiki Pattern (Option A)

Follow the existing `IF wiki_initialized` pattern in each skill. Add `graph_fresh` to propagate the staleness check graphify-context already performs.

---

## Changes

### 1. `graphify-context/SKILL.md` — export `fresh` in output

Phase 0 already performs `built_at_commit == git HEAD` staleness check. Change: include `fresh: bool` in the `graph_context` output object.

```json
{
  "graph_context": {
    "initialized": true,
    "fresh": true,
    "god_nodes": [...],
    "communities": 8,
    "graph_summary": "..."
  }
}
```

**Why:** Downstream skills need to warn users about stale graphs. Without this, they have no signal.

---

### 2. `context-awareness/SKILL.md` — add `graph_fresh` to project_context

Phase 6 already calls `Skill("graphify-context")`. Change: propagate `graph_context.fresh` into `project_context`.

```json
{
  "project_context": {
    "graph_initialized": true,
    "graph_god_nodes": [...],
    "graph_communities": 8,
    "graph_summary": "...",
    "graph_fresh": true
  }
}
```

Schema section (Quick Reference JSON) updated to include `graph_fresh: true|false`.

---

### 3. `brainstorming/SKILL.md` — hybrid graph logic at Step 1

Add after context-awareness call in "Explore project context":

```
IF project_context.graph_initialized:
  # Always: read god_nodes as likely integration touch points
  IF NOT project_context.graph_fresh:
    warn user: "Graph may be stale — run /graphify --update for accurate results"
    # Still proceed — stale graph > no graph

  # Detect match: topic names a god node → explain
  # Match = case-insensitive, whole-word (not substring of common words like "main")
  IF brainstorm topic contains a name from graph_god_nodes:
    Skill("graphify-context", args='explain "<ComponentName>"')
    → include result in Step 1 context

  # Detect match: topic involves integration/dependency/architecture → query
  ELSE IF topic keywords match [integrate, depend, connect, affect, impact, add to, extend]:
    Skill("graphify-context", args='query "<topic>" --budget 1000')
    → include result in Step 1 context

  # Passive: always show god nodes as likely touch points in Step 1 output
  Note: "Key components (god nodes): <god_nodes list>"
```

**Why:** God nodes = highest-betweenness nodes = most likely to be affected by any change. Showing them passively costs nothing. Active query only when topic overlaps.

---

### 4. `architecture-documentation/SKILL.md` — add graph block

Existing pattern (lines ~584, ~596):
```
IF project_context.wiki_initialized == true:
  ... enrich with wiki_summary
```

Add immediately after:
```
IF project_context.graph_initialized == true:
  Use graph_god_nodes as "Core Components" section of architecture diagram
  Use graph_communities as module structure (community label → module name)
  Use graph_summary as structural overview paragraph
  IF NOT project_context.graph_fresh:
    Add NOTE: "Architecture graph may be stale — run /graphify --update"
```

---

### 5. `prd-generator/SKILL.md` — add graph block

Existing pattern (lines ~790, ~803):
```
IF project_context.wiki_initialized == true:
  ... enrich Background section
```

Add immediately after:
```
IF project_context.graph_initialized == true:
  In "Architecture / Technical Context" PRD section:
  → Insert graph_god_nodes as "Key Components"
  → Insert graph_summary as structural overview
  IF NOT project_context.graph_fresh:
    Add NOTE: "Graph data may be stale"
```

---

## Files Changed

| File | Change type | Lines estimate |
|------|-------------|----------------|
| `graphify-context/SKILL.md` | Add `fresh` to output schema | +3 |
| `context-awareness/SKILL.md` | Add `graph_fresh` to project_context schema + Phase 6 propagation | +5 |
| `brainstorming/SKILL.md` | Add hybrid graph block to Step 1 | +15 |
| `architecture-documentation/SKILL.md` | Add `IF graph_initialized` block after wiki block | +8 |
| `prd-generator/SKILL.md` | Add `IF graph_initialized` block after wiki block | +6 |

Total: ~37 lines added, 0 deleted.

## Non-Goals

- No `knowledge_context` unified abstraction
- No changes to agent-builder, compact-session, or other skills
- No changes to graph building pipeline
- No migration of existing `wiki_initialized` consumers

## Success Criteria

1. `brainstorming` Step 1 mentions god nodes when `graph_initialized: true`
2. `brainstorming` calls `graphify-context explain/query` when topic matches
3. `architecture-documentation` includes god nodes in arch diagram when graph present
4. `prd-generator` includes graph_summary in Architecture section when graph present
5. Stale graph triggers visible warning in all three downstream skills
6. All existing `wiki_initialized` behaviour unchanged
