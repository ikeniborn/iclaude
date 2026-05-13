# Graph Integration into Downstream Skills — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire `graph_initialized`/`graph_fresh`/`graph_god_nodes` from `project_context` into brainstorming, architecture-documentation, and prd-generator — following the existing `wiki_initialized` pattern.

**Architecture:** Additive edits to 4 SKILL.md files. No new abstractions. `graphify-context` already exports `fresh` in its output schema — only context-awareness needs to propagate it. Then each downstream skill gets a `IF graph_initialized` block modelled on its existing `IF wiki_initialized` block.

**Known constraint:** Current graphify does not write `built_at_commit` into `GRAPH_REPORT.md`. `graphify-context` therefore returns `fresh` as a string `"unknown—..."` instead of a boolean. context-awareness must normalize this: propagate `graph_fresh: false` only when `graph_context.fresh === false` (explicit boolean false); propagate `graph_fresh: null` otherwise. Downstream skills warn only when `graph_fresh === false`, not when `null`.

**Tech Stack:** Markdown SKILL.md files. Verification via `grep`. No build step.

---

## File Map

| File | Action | What changes |
|------|--------|-------------|
| `.nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md` | Modify lines 99–102, 135–138, 344–347 | Add `graph_fresh` propagation + schema |
| `.nvm-isolated/.claude-isolated/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/brainstorming/SKILL.md` | Modify line 72 block | Add hybrid graph logic to Step 1 |
| `.nvm-isolated/.claude-isolated/skills/architecture-documentation/SKILL.md` | Modify after line 591 | Add `IF graph_initialized` Query block |
| `.nvm-isolated/.claude-isolated/skills/prd-generator/SKILL.md` | Modify after line 798 | Add `IF graph_initialized` Query block |

---

## Task 1: Propagate `graph_fresh` through context-awareness

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md:99-102` (propagation block)
- Modify: `.nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md:135-138` (Quick Reference schema)
- Modify: `.nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md:344-347` (Example 4c)

- [ ] **Step 1: Add `graph_fresh` to propagation block (lines 99–102)**

The current block (lines 99–102):
```
       graph_initialized: true
       graph_god_nodes: [из graph_context.god_nodes]
       graph_communities: graph_context.communities
       graph_summary: graph_context.graph_summary
```

Replace with:
```
       graph_initialized: true
       graph_god_nodes: [из graph_context.god_nodes]
       graph_communities: graph_context.communities
       graph_summary: graph_context.graph_summary
       graph_fresh: graph_context.fresh если typeof === boolean, иначе null
```

Note: graphify currently does not write `built_at_commit` to GRAPH_REPORT.md, so `graph_context.fresh` arrives as a string `"unknown—..."`. Normalize to `null` in that case — do NOT propagate the raw string.

- [ ] **Step 2: Verify propagation block**

```bash
grep -n "graph_fresh\|graph_context.fresh" \
  .nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md
```

Expected: 1+ lines containing `graph_fresh: graph_context.fresh`

- [ ] **Step 3: Add `graph_fresh` to Quick Reference JSON (lines 135–138)**

Current block:
```json
    "graph_initialized": true|false,
    "graph_god_nodes": ["ComponentA (20 edges)", "ComponentB (13 edges)"],
    "graph_communities": 0,
    "graph_summary": "структурный контекст из knowledge graph" | null
```

Replace with:
```json
    "graph_initialized": true|false,
    "graph_fresh": true|false|null,
    "graph_god_nodes": ["ComponentA (20 edges)", "ComponentB (13 edges)"],
    "graph_communities": 0,
    "graph_summary": "структурный контекст из knowledge graph" | null
```

- [ ] **Step 4: Add `graph_fresh` to Example 4c (lines 344–347)**

Current block:
```json
    "graph_initialized": true,
    "graph_god_nodes": ["PIIProxyHandler (20 edges)", "TestShouldRedact (13 edges)", "presidio_mask() (8 edges)"],
    "graph_communities": 8,
    "graph_summary": "Ядро — PIIProxyHandler соединяет HTTP-слой с presidio_mask(). 8 сообществ: HTTP-обработчики, маскирование, тесты паттернов, false-positive тесты."
```

Replace with:
```json
    "graph_initialized": true,
    "graph_fresh": null,
    "graph_god_nodes": ["PIIProxyHandler (20 edges)", "TestShouldRedact (13 edges)", "presidio_mask() (8 edges)"],
    "graph_communities": 8,
    "graph_summary": "Ядро — PIIProxyHandler соединяет HTTP-слой с presidio_mask(). 8 сообществ: HTTP-обработчики, маскирование, тесты паттернов, false-positive тесты."
```

- [ ] **Step 5: Verify all three occurrences**

```bash
grep -n "graph_fresh" .nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md
```

Expected: 3 lines (propagation block, Quick Reference JSON, Example 4c)

- [ ] **Step 6: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md
git commit -m "feat(skills): propagate graph_fresh from graphify-context into project_context"
```

---

## Task 2: Add hybrid graph logic to brainstorming Step 1

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/brainstorming/SKILL.md:72`

- [ ] **Step 1: Add graph block to "Understanding the idea" section**

Current text at line 72:
```
- Check out the current project state first (files, docs, recent commits)
```

Replace with:
```
- Check out the current project state first (files, docs, recent commits)
- If `project_context.graph_initialized` is true: use the graph for structural context.
  - **Always (passive):** Note god nodes as likely integration touch points — list them in your Step 1 summary as "Key components: [god nodes]"
  - **If graph is explicitly stale** (`graph_fresh === false`, boolean): warn the user — "Graph may be stale — run `/graphify --update` for accurate results" — then continue; stale graph > no graph. If `graph_fresh === null` (staleness unknown — graphify didn't write commit hash), skip the warning.
  - **If the brainstorm topic names a god node** (case-insensitive, whole-word match): call `Skill("graphify-context", args='explain "<ComponentName>"')` and include the result in Step 1 context.
  - **Else if the topic involves integration/dependencies/architecture** (keywords: integrate, depend, connect, affect, impact, extend, add to): call `Skill("graphify-context", args='query "<topic>" --budget 1000')` and include the result in Step 1 context.
  - Only one active Skill call per Step 1 — explain takes priority over query.
```

- [ ] **Step 2: Verify insertion**

```bash
grep -n "graph_initialized\|graph_fresh\|god_nodes\|graphify-context" \
  .nvm-isolated/.claude-isolated/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/brainstorming/SKILL.md
```

Expected: 4+ matching lines within 10 lines of each other

- [ ] **Step 3: Verify "Check out the current project state" is still present**

```bash
grep -n "Check out the current project state" \
  .nvm-isolated/.claude-isolated/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/brainstorming/SKILL.md
```

Expected: exactly 1 line

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/brainstorming/SKILL.md
git commit -m "feat(skills): add hybrid graph context to brainstorming Step 1"
```

---

## Task 3: Add graph block to architecture-documentation

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/architecture-documentation/SKILL.md:591` (after wiki Query block)

- [ ] **Step 1: Add graph Query block after wiki Query block**

Current text ending at line 591:
```
  - Если в wiki нет ответа → продолжить Phase 1 в стандартном режиме
```

Insert after that line:

```

IF project_context.graph_initialized == true:
  Использовать graph данные для обогащения Phase 1:
  - graph_god_nodes → использовать как "Core Components" в arch diagram (самые связанные узлы)
  - graph_communities → использовать как модульную структуру (community label → module name)
  - graph_summary → использовать как structural overview paragraph в Phase 1 discovery
  IF project_context.graph_fresh === false:
    Добавить NOTE в output: "Architecture graph may be stale — run /graphify --update"
  # graph_fresh === null означает неизвестно (graphify не пишет commit hash) — не предупреждать
```

- [ ] **Step 2: Verify insertion**

```bash
grep -n "graph_initialized\|graph_god_nodes\|graph_communities\|graph_fresh" \
  .nvm-isolated/.claude-isolated/skills/architecture-documentation/SKILL.md
```

Expected: 4+ lines in a contiguous block around line 592+

- [ ] **Step 3: Verify wiki block untouched**

```bash
grep -n "wiki_initialized" .nvm-isolated/.claude-isolated/skills/architecture-documentation/SKILL.md
```

Expected: same lines as before (584, 596) — no changes

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/architecture-documentation/SKILL.md
git commit -m "feat(skills): add IF graph_initialized block to architecture-documentation"
```

---

## Task 4: Add graph block to prd-generator

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/prd-generator/SKILL.md:798` (after wiki Query block)

- [ ] **Step 1: Add graph Query block after wiki Query block**

Current text ending at line 798:
```
  - Если wiki нет данных → продолжить стандартный Questionnaire без изменений
```

Insert after that line:

```

IF project_context.graph_initialized == true:
  В раздел "Architecture / Technical Context" PRD:
  - graph_god_nodes → вставить как "Ключевые компоненты системы" (с числом рёбер)
  - graph_summary → вставить как структурный обзор архитектуры
  - graph_communities → упомянуть количество модулей/сообществ
  IF project_context.graph_fresh === false:
    Добавить NOTE: "Данные о графе могут быть устаревшими — запусти /graphify --update"
  # graph_fresh === null означает неизвестно — не предупреждать
```

- [ ] **Step 2: Verify insertion**

```bash
grep -n "graph_initialized\|graph_god_nodes\|graph_summary\|graph_fresh" \
  .nvm-isolated/.claude-isolated/skills/prd-generator/SKILL.md
```

Expected: 4+ lines in a contiguous block around line 799+

- [ ] **Step 3: Verify wiki block untouched**

```bash
grep -n "wiki_initialized" .nvm-isolated/.claude-isolated/skills/prd-generator/SKILL.md
```

Expected: same lines as before (790, 803) — no changes

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/prd-generator/SKILL.md
git commit -m "feat(skills): add IF graph_initialized block to prd-generator"
```

---

## Verification: End-to-End Check

After all 4 tasks:

- [ ] **Verify graph_fresh propagation chain is complete**

```bash
echo "=== graphify-context exports fresh ===" && \
grep -n '"fresh"' .nvm-isolated/.claude-isolated/skills/graphify-context/SKILL.md && \
echo "=== context-awareness propagates graph_fresh ===" && \
grep -n "graph_fresh" .nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md && \
echo "=== brainstorming uses graph_initialized ===" && \
grep -n "graph_initialized" .nvm-isolated/.claude-isolated/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/brainstorming/SKILL.md && \
echo "=== arch-docs uses graph_initialized ===" && \
grep -n "graph_initialized" .nvm-isolated/.claude-isolated/skills/architecture-documentation/SKILL.md && \
echo "=== prd-generator uses graph_initialized ===" && \
grep -n "graph_initialized" .nvm-isolated/.claude-isolated/skills/prd-generator/SKILL.md
```

Expected: each section shows 1+ matching lines

- [ ] **Verify wiki consumers unchanged**

```bash
grep -c "wiki_initialized" \
  .nvm-isolated/.claude-isolated/skills/architecture-documentation/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/prd-generator/SKILL.md
```

Expected: `architecture-documentation/SKILL.md:2` and `prd-generator/SKILL.md:2` (same counts as before)
