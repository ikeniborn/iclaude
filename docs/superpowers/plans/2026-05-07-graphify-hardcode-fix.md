# Graphify GRAPHIFY_OUT Hardcode Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all hardcoded `.graphify/` path references in skill files with `{GOUT}` resolved from `${GRAPHIFY_OUT}` env var.

**Architecture:** Each skill file gets a Step 0 block that runs `GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")` before any path check. All subsequent references to `.graphify/` use `{GOUT}/` instead. This mirrors the existing Step 0.5 pattern in `graphify/SKILL.md` (which uses the same `-graphify-out` default). The `GRAPHIFY_OUT` env var is always populated in Claude Code sessions via `_sync_graphify_env_to_settings()` in `lib/launcher/launch.sh` — the fallback is a safety net only.

**Tech Stack:** Markdown (skill instruction files), bash grep for verification

---

## File Map

| File | Action | Changes |
|------|--------|---------|
| `.nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md` | Modify | 6 edits: description, add Step 0 block, 4× path replacement |
| `.nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md` | Modify | 2 edits: add GOUT resolution line, 1× path replacement |
| `.nvm-isolated/.claude-isolated/skills/graphify/SKILL.md` | Modify | 1 edit: description line 3 |

---

### Task 1: Fix `graphify-context/SKILL.md` description

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md:3`

- [ ] **Step 1: Edit description to remove hardcoded path**

In `.nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md`, change line 3:

Old:
```
description: Use when exploring project architecture, component relationships, or codebase structure — especially at brainstorming Step 1 or when the user asks how parts of the system connect. Reads .graphify/ knowledge graph without rebuilding it.
```

New:
```
description: Use when exploring project architecture, component relationships, or codebase structure — especially at brainstorming Step 1 or when the user asks how parts of the system connect. Reads project knowledge graph (path from GRAPHIFY_OUT) without rebuilding it.
```

- [ ] **Step 2: Verify**

```bash
head -5 .nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md
```

Expected: line 3 contains `path from GRAPHIFY_OUT`, no `.graphify/`.

---

### Task 2: Add Step 0 to `graphify-context/SKILL.md`

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md` — insert before Phase 0

- [ ] **Step 1: Insert Step 0 block before `## Phase 0: Определение наличия графа`**

Insert this block immediately before the line `## Phase 0: Определение наличия графа`:

```markdown
## Step 0: Resolve graph output dir

```bash
GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")
```

Use `{GOUT}` as the graph directory in all path checks below. (`{GOUT}` is pseudocode — substitute the printed value literally.)

```

- [ ] **Step 2: Verify block present**

```bash
grep -n "GOUT=" .nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md
```

Expected: one match showing `GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")`.

---

### Task 3: Replace hardcoded paths in `graphify-context/SKILL.md`

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md` — lines 45, 116, 148, 153 (line numbers shift after Task 2 insert; locate by content)

- [ ] **Step 1: Replace Phase 0 IF condition**

Find:
```
IF exists {CWD}/.graphify/GRAPH_REPORT.md:
  1. Прочитать GRAPH_REPORT.md
```

Replace with:
```
IF exists {CWD}/{GOUT}/GRAPH_REPORT.md:
  1. Прочитать {GOUT}/GRAPH_REPORT.md
```

- [ ] **Step 2: Replace integration section IF condition**

Find (in `## Интеграция с context-awareness`):
```
IF exists {CWD}/.graphify/GRAPH_REPORT.md:
  Skill(skill="graphify-context")
```

Replace with:
```
IF exists {CWD}/{GOUT}/GRAPH_REPORT.md:
  Skill(skill="graphify-context")
```

- [ ] **Step 3: Replace examples comment**

Find:
```
# → просто читать .graphify/GRAPH_REPORT.md, не вызывать CLI
```

Replace with:
```
# → просто читать {GOUT}/GRAPH_REPORT.md, не вызывать CLI
```

- [ ] **Step 4: Replace "когда НЕ использовать" entry**

Find:
```
- Граф отсутствует (`.graphify/` нет) — нечего запрашивать
```

Replace with:
```
- Граф отсутствует (`{GOUT}/` нет) — нечего запрашивать
```

- [ ] **Step 5: Verify no remaining hardcoded path checks**

```bash
grep -n '\.graphify/' .nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md
```

Expected: zero matches.

- [ ] **Step 6: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md
git commit -m "fix(graphify-context): resolve GRAPHIFY_OUT before path checks, remove hardcoded .graphify/"
```

---

### Task 4: Fix `context-awareness/SKILL.md`

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md` — `### 6. Graph Detection` section

- [ ] **Step 1: Add GOUT resolution line in Graph Detection section**

Find the opening of Graph Detection (the line after ` ```\nПроверить наличие knowledge graph в корне проекта:`):

Old content inside the code block:
```
Проверить наличие knowledge graph в корне проекта:

IF exists {CWD}/.graphify/GRAPH_REPORT.md:
```

Replace with:
```
Проверить наличие knowledge graph в корне проекта:

Сначала resolve выходную директорию: GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")

IF exists {CWD}/{GOUT}/GRAPH_REPORT.md:
```

- [ ] **Step 2: Verify change**

```bash
grep -n 'GOUT\|\.graphify/GRAPH_REPORT' .nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md
```

Expected:
- One match for `GOUT=$(echo`
- Zero matches for `.graphify/GRAPH_REPORT`

- [ ] **Step 3: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md
git commit -m "fix(context-awareness): resolve GRAPHIFY_OUT before graph detection path check"
```

---

### Task 5: Fix `graphify/SKILL.md` description

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/graphify/SKILL.md:3`

- [ ] **Step 1: Update description trigger condition**

In `.nvm-isolated/.claude-isolated/skills/graphify/SKILL.md`, change line 3:

Old:
```
description: "any input (code, docs, papers, images, videos) to knowledge graph. Use when user asks any question about a codebase, documents, or project content - especially if graphify-out/ exists, treat the question as a /graphify query."
```

New:
```
description: "any input (code, docs, papers, images, videos) to knowledge graph. Use when user asks any question about a codebase, documents, or project content - especially if ${GRAPHIFY_OUT:-graphify-out}/ exists, treat the question as a /graphify query."
```

- [ ] **Step 2: Verify**

```bash
head -5 .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md
```

Expected: description contains `${GRAPHIFY_OUT:-graphify-out}/`, not bare `graphify-out/`.

- [ ] **Step 3: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md
git commit -m "fix(graphify): reference GRAPHIFY_OUT in skill description trigger condition"
```

---

### Task 6: Final audit

- [ ] **Step 1: Check no remaining hardcodes in all three files**

```bash
grep -rn '\.graphify/' \
  .nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md
```

Expected: zero matches (or only in comments/examples that are clearly illustrative, not path checks).

- [ ] **Step 2: Confirm GOUT pattern present in both consuming skills**

```bash
grep -rn 'GOUT' \
  .nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md
```

Expected: at least 1 match per file showing `GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")`.

- [ ] **Step 3: Confirm description field fixed in graphify/SKILL.md**

```bash
grep 'GRAPHIFY_OUT' .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md | head -3
```

Expected: description line shows `${GRAPHIFY_OUT:-graphify-out}`.
