# Skills Description Audit — Design Spec

**Date:** 2026-05-08
**Source audit:** `docs/audits/2026-05-08-skills-description-audit.md`
**Scope:** 9 правок в `description:` frontmatter SKILL.md (8 unique skills + финальная фраза в `mermaid-obsidian`).
**Goal:** устранить overlap/underspecified триггеры, чтобы каждый user-запрос матчил ровно один skill.

---

## 1. Архитектура

Single-line edits в YAML frontmatter поле `description:` для 9 файлов. Тело SKILL.md не трогать. Никакого кода, никакой рантайм-логики.

**Language policy (option C из брейншторма):**
- HIGH severity (3 skills) → English (унификация для критичных триггеров).
- MED + LOW (5 skills) → сохранить язык оригинала (4 ru, 1 en).
- `mermaid-obsidian` — английский (оригинал), правится только финальная фраза.

---

## 2. Затронутые файлы

| File | Severity | Lang | Тип правки |
|---|---|---|---|
| `skills/graphify/SKILL.md` | HIGH | en | full rewrite description |
| `skills/context-awareness/SKILL.md` | HIGH | en | full rewrite |
| `skills/git-workflow/SKILL.md` | HIGH | en | full rewrite |
| `skills/mermaid-obsidian/SKILL.md` | MED | en | replace tail sentence |
| `skills/architecture-documentation/SKILL.md` | MED | en | full rewrite |
| `skills/prd-generator/SKILL.md` | MED | ru | full rewrite |
| `skills/agent-builder/SKILL.md` | LOW | ru | full rewrite |
| `skills/prompt-verifier/SKILL.md` | LOW | ru | full rewrite |
| `skills/llm-wiki/SKILL.md` | LOW | ru | full rewrite |

Все пути относительно `.nvm-isolated/.claude-isolated/`.

---

## 3. Финальные тексты description

### 3.1 `graphify` (HIGH, en)

```
Build knowledge graph from a folder of files (code, docs, papers, images, videos) — community detection, audit trail, three outputs (HTML, GraphRAG JSON, GRAPH_REPORT.md). Use when user types /graphify, asks to "build/rebuild/update the graph", or graph artifacts are missing in ${GRAPHIFY_OUT:-graphify-out}/. NOT for querying an existing graph — use graphify-context. NOT for project-language detection — use context-awareness.
```

### 3.2 `context-awareness` (HIGH, en)

```
Detect project language, framework, package manager, lint/test commands and locate CLAUDE.md / PRD docs at task start (Phase 0). Use when starting any task, switching project, or before running syntax/test checks. NOT for querying knowledge graph (graphify-context) and NOT for wiki synthesis (llm-wiki).
```

### 3.3 `git-workflow` (HIGH, en)

```
Standardized git workflow with Conventional Commits. Use when creating a feature branch, staging commits, opening a PR, or when user says "commit", "create branch", "open PR", "fix commit message". Enforces commit prefix (feat/fix/docs/...), branch naming, PR template.
```

### 3.4 `mermaid-obsidian` (MED, en — only tail sentence)

Заменить **последнее предложение** description (начиная с "Always use this skill even if the user just says..."):

```
Always use this skill when user asks to draw/fix a standalone diagram in Obsidian. NOT for diagrams embedded inside PRD documents (use prd-generator) or architecture YAML (use architecture-documentation) — those skills generate Mermaid internally.
```

Остальное description оставить как есть.

### 3.5 `architecture-documentation` (MED, en)

```
Generate developer-facing architecture docs (component graph, dependencies, data flows) in YAML + TOON + Mermaid. Use when user asks to "document architecture", "map components/dependencies", "build module diagram". NOT for product/feature requirements — use prd-generator.
```

### 3.6 `prd-generator` (MED, ru)

```
Создание Product Requirements Document (PRD) — 14 разделов + 5 Mermaid-диаграмм через интерактивный Q&A. Использовать когда пользователь просит "написать PRD", "составить product spec", "описать требования к продукту". НЕ для технической архитектуры — использовать architecture-documentation.
```

### 3.7 `agent-builder` (LOW, ru)

```
Интерактивное создание НОВОГО Claude Code sub-agent (AGENT.md с валидным frontmatter, документацией роли, IO-примерами, валидацией по схеме). Использовать когда пользователь просит "создать/собрать/построить агента", "новый sub-agent". НЕ для редактирования существующих AGENT.md/SKILL.md/CLAUDE.md — использовать prompt-verifier.
```

### 3.8 `prompt-verifier` (LOW, ru)

```
Верификация и переписывание СУЩЕСТВУЮЩИХ инструкционных файлов (CLAUDE.md, AGENT.md, SKILL.md) против 7 правил форматирования. Использовать когда пользователь просит "проверить/исправить/проаудитить промт", "агент игнорирует правила", "отрефакторить инструкции", перед коммитом изменений в инструкционные файлы. НЕ для создания новых агентов — использовать agent-builder.
```

### 3.9 `llm-wiki` (LOW, ru)

```
Создание и поддержка Obsidian-вики из raw-источников (код, docs, papers) — извлечение, синтез, дедупликация знаний по доменам. Использовать когда пользователь просит "построить/обновить/освежить вики", "загрузить новые источники в vault", "синтезировать знания по домену". НЕ для live-запросов к кодовой базе — использовать graphify-context.
```

---

## 4. Верификация (option B)

### 4.1 YAML syntax check

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

Ожидание: zero "FAIL" lines.

### 4.2 Routing matrix (manual)

Для каждого запроса проверить, что ровно один skill содержит matching trigger phrase в обновлённом description:

| # | Запрос пользователя | Ожидаемый skill | Match признак |
|---|---|---|---|
| 1 | "построй граф проекта" | `graphify` | "build/rebuild/update the graph" |
| 2 | "как X связан с Y?" / "архитектура модуля Foo" | `graphify-context` | "Use when exploring project architecture" (без правок) |
| 3 | "обнови wiki по домену auth" | `llm-wiki` | "построить/обновить/освежить вики" |
| 4 | "какой framework тут?" / Phase 0 | `context-awareness` | "Detect project language, framework" |
| 5 | "нарисуй flowchart деплоя" | `mermaid-obsidian` | "draw/fix a standalone diagram in Obsidian" |
| 6 | "задокументируй архитектуру" | `architecture-documentation` | "document architecture" |
| 7 | "напиши PRD на feature X" | `prd-generator` | "написать PRD" |
| 8 | "создай sub-agent test-runner" | `agent-builder` | "создать/собрать/построить агента" |
| 9 | "проверь мой CLAUDE.md" | `prompt-verifier` | "проверить/исправить/проаудитить промт" |
| 10 | "проанализируй session" | `compact-session` | (без правок, эталон) |
| 11 | "сделай commit / открой PR" | `git-workflow` | "commit", "create branch", "open PR" |
| 12 | (internal) JSON↔TOON | `toon-skill` | `user-invocable: false` |

Проверка ручная: для каждой строки grep описания всех 13 skills на ключевую фразу — должен быть единственный hit (или явное "NOT for ..." разграничение в конкурентах).

---

## 5. Rollback

Все правки — single-line edits в frontmatter. Один коммит → `git revert <hash>` восстанавливает состояние.

---

## 6. Out of scope

- Тело SKILL.md.
- Skills `compact-session`, `graphify-context`, `toon-skill` — эталоны / internal, не трогать.
- `_shared/` — не skill, пропустить.
- Изменения в `settings.json`, hooks, или CLAUDE.md.

---

## 7. Success criteria

1. 9 файлов изменены ровно в одной строке (`description:`).
2. YAML syntax check passes для всех 13 SKILL.md.
3. Routing matrix § 4.2 — ровно один skill матчит каждый из 12 запросов.
4. Один atomic commit с conventional message `docs(skills): clarify description frontmatter for routing`.
