# Graphify GRAPHIFY_OUT Hardcode Audit & Fix

**Date:** 2026-05-07  
**Status:** Approved  
**Scope:** Audit graphify integration in iclaude; fix all hardcoded `.graphify/` paths in skill files

---

## Problem

Three skill files reference the graphify output directory as a hardcoded literal (`.graphify/`) instead of reading the `GRAPHIFY_OUT` environment variable. If a user sets `GRAPHIFY_OUT=my-graph/`, these skills fail to find the graph.

### Affected files

| File | Lines | Hardcode |
|------|-------|---------|
| `graphify-context/SKILL.md` | 3, 45, 116, 148, 153 | `.graphify/GRAPH_REPORT.md` |
| `context-awareness/SKILL.md` | 96 | `.graphify/GRAPH_REPORT.md` |
| `graphify/SKILL.md` | 3 (description) | `graphify-out/` |

### What works correctly

- `lib/graphify/install.sh`, `lib/graphify/status.sh`, `iclaude.sh` — all use `${GRAPHIFY_OUT}`
- Python blocks in `graphify/SKILL.md` — use `os.environ.get('GRAPHIFY_OUT', 'graphify-out')`
- `settings.json` `env.GRAPHIFY_OUT` — dynamically synced by `_sync_graphify_env_to_settings()` in `lib/launcher/launch.sh` before each Claude Code launch; NOT a hardcode
- `.gitignore` — contains `graphify-out/` (default path only; `.graphify/` is intentionally in git)

---

## Design

### Approach: Step 0 — Resolve GRAPHIFY_OUT (consistent with graphify/SKILL.md Step 0.5 pattern)

Before any path check in skill files, resolve GRAPHIFY_OUT to a local variable:

```bash
GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")
```

Use `{GOUT}` in all subsequent path references within the skill. (`{GOUT}` is pseudocode in skill instruction prose — Claude resolves it by running the bash line above.)

---

## Changes

### File 1: `graphify-context/SKILL.md`

**Change 1a** — description (line 3):  
Remove hardcoded path reference.  
`Reads .graphify/ knowledge graph without rebuilding it.`  
→ `Reads project knowledge graph without rebuilding it.`

**Change 1b** — add Step 0 block before Phase 0:
```
## Step 0: Resolve graph output dir

```bash
GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")
```
Use `{GOUT}` in all path checks below.
```

**Change 1c** — Phase 0 IF condition (line 45):  
`IF exists {CWD}/.graphify/GRAPH_REPORT.md:`  
→ `IF exists {CWD}/{GOUT}/GRAPH_REPORT.md:`

**Change 1d** — integration section IF condition (line 116):  
`IF exists {CWD}/.graphify/GRAPH_REPORT.md:`  
→ `IF exists {CWD}/{GOUT}/GRAPH_REPORT.md:`

**Change 1e** — examples comment (line 148):  
`# → просто читать .graphify/GRAPH_REPORT.md, не вызывать CLI`  
→ `# → просто читать {GOUT}/GRAPH_REPORT.md, не вызывать CLI`

**Change 1f** — "когда НЕ использовать" (line 153):  
`` - Граф отсутствует (`.graphify/` нет) — нечего запрашивать ``  
→ `` - Граф отсутствует (`{GOUT}/` нет) — нечего запрашивать ``

---

### File 2: `context-awareness/SKILL.md`

**Change 2a** — add GOUT resolution at start of `### 6. Graph Detection`:

After the opening paragraph, before the IF block, add:
```
Сначала resolve выходную директорию: `GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")`
```

**Change 2b** — IF condition (line 96):  
`IF exists {CWD}/.graphify/GRAPH_REPORT.md:`  
→ `IF exists {CWD}/{GOUT}/GRAPH_REPORT.md:`

*Note: line 325 (`.graphify/` in project tree example) stays — it's an illustrative example of a specific iclaude config, not a path check.*

---

### File 3: `graphify/SKILL.md`

**Change 3a** — description (line 3):  
`especially if graphify-out/ exists, treat the question as a /graphify query.`  
→ `especially if ${GRAPHIFY_OUT:-graphify-out}/ exists, treat the question as a /graphify query.`

---

## Success Criteria

1. All three files changed as specified
2. `grep -rn '\.graphify/' skills/graphify-context/ skills/context-awareness/` returns zero path-check matches (description/example refs OK)
3. `grep -n 'graphify-out/' skills/graphify/SKILL.md | head -3` — description line shows `${GRAPHIFY_OUT:-graphify-out}`, not bare `graphify-out/`
4. Changing `GRAPHIFY_OUT=mydir` in settings.json and running context-awareness would correctly look for `{CWD}/mydir/GRAPH_REPORT.md`
