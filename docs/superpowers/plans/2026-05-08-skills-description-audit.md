# Skills Description Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `description:` frontmatter in 9 SKILL.md files to eliminate trigger overlap so each user request matches exactly one skill.

**Architecture:** Single-line YAML frontmatter edits. No code, no runtime logic, no body changes. One atomic commit. Verification via Python YAML parse + manual routing-matrix grep.

**Tech Stack:** YAML frontmatter, `python3 -c "import yaml"`, `grep`, `git`.

**Spec:** `docs/superpowers/specs/2026-05-08-skills-description-audit-design.md`

**Base path:** `.nvm-isolated/.claude-isolated/skills/`

---

## File Structure

All edits in existing files — no new files.

| File | Field | Edit type |
|---|---|---|
| `skills/graphify/SKILL.md` | `description:` | replace value |
| `skills/context-awareness/SKILL.md` | `description:` | replace value |
| `skills/git-workflow/SKILL.md` | `description:` | replace value |
| `skills/mermaid-obsidian/SKILL.md` | `description:` | replace tail sentence |
| `skills/architecture-documentation/SKILL.md` | `description:` | replace value |
| `skills/prd-generator/SKILL.md` | `description:` | replace value |
| `skills/agent-builder/SKILL.md` | `description:` | replace value |
| `skills/prompt-verifier/SKILL.md` | `description:` | replace value |
| `skills/llm-wiki/SKILL.md` | `description:` | replace value |

---

### Task 1: graphify

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/graphify/SKILL.md` (line 3)

- [ ] **Step 1: Apply edit**

Use Edit tool. Old string:

```
description: "any input (code, docs, papers, images, videos) to knowledge graph. Use when user asks any question about a codebase, documents, or project content - especially if ${GRAPHIFY_OUT:-graphify-out}/ exists, treat the question as a /graphify query."
```

New string:

```
description: "Build knowledge graph from a folder of files (code, docs, papers, images, videos) — community detection, audit trail, three outputs (HTML, GraphRAG JSON, GRAPH_REPORT.md). Use when user types /graphify, asks to \"build/rebuild/update the graph\", or graph artifacts are missing in ${GRAPHIFY_OUT:-graphify-out}/. NOT for querying an existing graph — use graphify-context. NOT for project-language detection — use context-awareness."
```

- [ ] **Step 2: Verify**

Run: `head -5 .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md`
Expected: new description on line 3, `trigger: /graphify` line preserved.

---

### Task 2: context-awareness

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md` (line 3)

- [ ] **Step 1: Apply edit**

Old string:

```
description: Автоматическое определение контекста проекта. Поиск по документации.
```

New string:

```
description: Detect project language, framework, package manager, lint/test commands and locate CLAUDE.md / PRD docs at task start (Phase 0). Use when starting any task, switching project, or before running syntax/test checks. NOT for querying knowledge graph (graphify-context) and NOT for wiki synthesis (llm-wiki).
```

- [ ] **Step 2: Verify**

Run: `head -5 .nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md`
Expected: new description on line 3, `user-invocable: false` preserved on line 4.

---

### Task 3: git-workflow

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/git-workflow/SKILL.md` (line 3)

- [ ] **Step 1: Apply edit**

Old string:

```
description: Стандартизированный git workflow с Conventional Commits
```

New string:

```
description: Standardized git workflow with Conventional Commits. Use when creating a feature branch, staging commits, opening a PR, or when user says "commit", "create branch", "open PR", "fix commit message". Enforces commit prefix (feat/fix/docs/...), branch naming, PR template.
```

- [ ] **Step 2: Verify**

Run: `head -5 .nvm-isolated/.claude-isolated/skills/git-workflow/SKILL.md`
Expected: new description on line 3.

---

### Task 4: mermaid-obsidian (tail sentence only)

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/mermaid-obsidian/SKILL.md` (line 3, tail)

Replace **only the final sentence** of the description. Preserve everything before "Always use this skill...".

- [ ] **Step 1: Apply edit**

Old string:

```
Always use this skill even if the user just says "draw" or "diagram" without specifying Mermaid explicitly — if they're working in Obsidian, Mermaid is the right tool.
```

New string:

```
Always use this skill when user asks to draw/fix a standalone diagram in Obsidian. NOT for diagrams embedded inside PRD documents (use prd-generator) or architecture YAML (use architecture-documentation) — those skills generate Mermaid internally.
```

- [ ] **Step 2: Verify**

Run: `head -5 .nvm-isolated/.claude-isolated/skills/mermaid-obsidian/SKILL.md`
Expected: description starts with original "Use this skill whenever..." and ends with new sentence about NOT for PRD/architecture.

---

### Task 5: architecture-documentation

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/architecture-documentation/SKILL.md` (line 3)

- [ ] **Step 1: Apply edit**

Old string:

```
description: Generate detailed architectural documentation in YAML and TOON formats with component dependencies and relationships
```

New string:

```
description: Generate developer-facing architecture docs (component graph, dependencies, data flows) in YAML + TOON + Mermaid. Use when user asks to "document architecture", "map components/dependencies", "build module diagram". NOT for product/feature requirements — use prd-generator.
```

- [ ] **Step 2: Verify**

Run: `head -5 .nvm-isolated/.claude-isolated/skills/architecture-documentation/SKILL.md`
Expected: new description on line 3, `user-invocable: true` preserved on line 4.

---

### Task 6: prd-generator

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/prd-generator/SKILL.md` (line 3)

- [ ] **Step 1: Apply edit**

Old string:

```
description: Автоматизированное создание Product Requirements Document (PRD) с интерактивными вопросами, AI-генерацией 14 разделов и 5 Mermaid диаграмм
```

New string:

```
description: Создание Product Requirements Document (PRD) — 14 разделов + 5 Mermaid-диаграмм через интерактивный Q&A. Использовать когда пользователь просит "написать PRD", "составить product spec", "описать требования к продукту". НЕ для технической архитектуры — использовать architecture-documentation.
```

- [ ] **Step 2: Verify**

Run: `head -5 .nvm-isolated/.claude-isolated/skills/prd-generator/SKILL.md`
Expected: new description on line 3.

---

### Task 7: agent-builder

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/agent-builder/SKILL.md` (line 3)

- [ ] **Step 1: Apply edit**

Old string:

```
description: Интерактивное создание Claude Code sub-agents с корректным frontmatter, документацией роли, примерами IO и валидацией по официальной схеме
```

New string:

```
description: Интерактивное создание НОВОГО Claude Code sub-agent (AGENT.md с валидным frontmatter, документацией роли, IO-примерами, валидацией по схеме). Использовать когда пользователь просит "создать/собрать/построить агента", "новый sub-agent". НЕ для редактирования существующих AGENT.md/SKILL.md/CLAUDE.md — использовать prompt-verifier.
```

- [ ] **Step 2: Verify**

Run: `head -5 .nvm-isolated/.claude-isolated/skills/agent-builder/SKILL.md`
Expected: new description on line 3.

---

### Task 8: prompt-verifier

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/prompt-verifier/SKILL.md` (line 3)

- [ ] **Step 1: Apply edit**

Old string:

```
description: Верификация и адаптация промтов (CLAUDE.md, AGENT.md, инструкций) для максимального соблюдения агентом
```

New string:

```
description: Верификация и переписывание СУЩЕСТВУЮЩИХ инструкционных файлов (CLAUDE.md, AGENT.md, SKILL.md) против 7 правил форматирования. Использовать когда пользователь просит "проверить/исправить/проаудитить промт", "агент игнорирует правила", "отрефакторить инструкции", перед коммитом изменений в инструкционные файлы. НЕ для создания новых агентов — использовать agent-builder.
```

- [ ] **Step 2: Verify**

Run: `head -5 .nvm-isolated/.claude-isolated/skills/prompt-verifier/SKILL.md`
Expected: new description on line 3.

---

### Task 9: llm-wiki

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md` (line 3)

- [ ] **Step 1: Apply edit**

Old string:

```
description: Поддержка и развитие базы знаний (вики) по доменам знаний — извлечение, синтез и поддержка wiki из raw-источников. Используется когда нужно создать, обновить вики по доменам.
```

New string:

```
description: Создание и поддержка Obsidian-вики из raw-источников (код, docs, papers) — извлечение, синтез, дедупликация знаний по доменам. Использовать когда пользователь просит "построить/обновить/освежить вики", "загрузить новые источники в vault", "синтезировать знания по домену". НЕ для live-запросов к кодовой базе — использовать graphify-context.
```

- [ ] **Step 2: Verify**

Run: `head -5 .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md`
Expected: new description on line 3.

---

### Task 10: YAML syntax check (all 13 skills)

**Files:**
- Read-only: all `.nvm-isolated/.claude-isolated/skills/*/SKILL.md`

- [ ] **Step 1: Run YAML parse on every SKILL.md**

Run:

```bash
for f in .nvm-isolated/.claude-isolated/skills/*/SKILL.md; do
  python3 -c "
import yaml, sys
content = open('$f').read()
parts = content.split('---', 2)
if len(parts) < 3:
    print('NO FRONTMATTER: $f'); sys.exit(1)
yaml.safe_load(parts[1])
" || echo "FAIL: $f"
done
```

Expected: zero `FAIL` lines, zero `NO FRONTMATTER` lines, exit 0.

- [ ] **Step 2: Confirm all 9 edited descriptions parse**

Run:

```bash
for f in graphify context-awareness git-workflow mermaid-obsidian architecture-documentation prd-generator agent-builder prompt-verifier llm-wiki; do
  python3 -c "
import yaml
content = open('.nvm-isolated/.claude-isolated/skills/$f/SKILL.md').read()
fm = yaml.safe_load(content.split('---', 2)[1])
print('$f:', fm.get('description', 'MISSING')[:60])
"
done
```

Expected: 9 lines, each with first 60 chars of new description (no `MISSING`).

---

### Task 11: Routing matrix verification

Manual grep — for each request, confirm exactly one skill matches.

- [ ] **Step 1: Build description corpus**

Run:

```bash
for f in .nvm-isolated/.claude-isolated/skills/*/SKILL.md; do
  python3 -c "
import yaml
fm = yaml.safe_load(open('$f').read().split('---', 2)[1])
print('$f', '|', fm.get('description', ''))
"
done > /tmp/skills-desc.txt
wc -l /tmp/skills-desc.txt
```

Expected: 13 lines (one per skill).

- [ ] **Step 2: Grep each routing trigger**

Run each grep — expect output to point to exactly one skill (or one skill + clear `NOT for ...` mentions in others):

```bash
grep -i 'build/rebuild/update the graph' /tmp/skills-desc.txt    # → graphify
grep -i 'exploring project architecture' /tmp/skills-desc.txt    # → graphify-context
grep -i 'построить/обновить/освежить вики' /tmp/skills-desc.txt  # → llm-wiki
grep -i 'Detect project language' /tmp/skills-desc.txt           # → context-awareness
grep -i 'standalone diagram in Obsidian' /tmp/skills-desc.txt    # → mermaid-obsidian
grep -i 'document architecture' /tmp/skills-desc.txt             # → architecture-documentation
grep -i 'написать PRD' /tmp/skills-desc.txt                       # → prd-generator
grep -i 'создать/собрать/построить агента' /tmp/skills-desc.txt  # → agent-builder
grep -i 'проверить/исправить/проаудитить промт' /tmp/skills-desc.txt  # → prompt-verifier
grep -i 'analyze session\|compact session' /tmp/skills-desc.txt  # → compact-session
grep -i 'commit.*create branch.*open PR\|Conventional Commits' /tmp/skills-desc.txt  # → git-workflow
```

Expected: each grep returns exactly one matching skill path. If any grep returns 0 hits or 2+ hits without explicit `NOT for ...` discrimination, fix the description before proceeding.

- [ ] **Step 3: Cleanup**

Run: `rm /tmp/skills-desc.txt`

---

### Task 12: Commit

- [ ] **Step 1: Stage 9 modified files**

Run:

```bash
git add \
  .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/context-awareness/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/git-workflow/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/mermaid-obsidian/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/architecture-documentation/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/prd-generator/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/agent-builder/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/prompt-verifier/SKILL.md \
  .nvm-isolated/.claude-isolated/skills/llm-wiki/SKILL.md
```

- [ ] **Step 2: Verify staged diff**

Run: `git diff --cached --stat`
Expected: exactly 9 files changed; line counts roughly +9 / -9 (one description line each).

Run: `git diff --cached | grep -E '^[+-]' | grep -v '^[+-]{3}' | grep -v '^[+-]description'`
Expected: empty output (only `description:` lines changed).

- [ ] **Step 3: Commit**

Run:

```bash
git commit -m "$(cat <<'EOF'
docs(skills): clarify description frontmatter for routing

Rewrite description: in 9 SKILL.md files to eliminate trigger
overlap. Each user request now matches exactly one skill via
explicit "Use when ..." phrases and "NOT for ... — use <other>"
discriminators.

Spec: docs/superpowers/specs/2026-05-08-skills-description-audit-design.md
Audit: docs/audits/2026-05-08-skills-description-audit.md

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Verify commit**

Run: `git log -1 --stat`
Expected: 9 SKILL.md files, conventional commit message starting `docs(skills):`.

---

## Success Criteria

1. 9 files modified, exactly one `description:` line each.
2. YAML syntax check (Task 10) passes for all 13 SKILL.md.
3. Routing matrix (Task 11) — every grep returns exactly one skill.
4. One atomic commit `docs(skills): clarify description frontmatter for routing`.

## Rollback

`git revert <hash>` — single commit restores all original descriptions.
