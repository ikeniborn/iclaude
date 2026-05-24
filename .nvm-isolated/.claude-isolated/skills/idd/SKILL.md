---
name: idd
description: Use when the user types "/idd", asks to "capture intent before brainstorming", requests an "intent doc", or is starting non-trivial feature work (new module, new CLI flag, API change, architectural decision) before running /brainstorm.
---

# IDD — Intent-Driven Design

## Overview

IDD captures *why* before *how*. Run before `/brainstorm` to anchor the spec to real objectives — preventing specs that are precisely wrong (right HOW, wrong WHAT/WHY).

## When to use / When not to use

| Trigger | Action |
|---------|--------|
| New module / new CLI flag / API change / arch decision | Run IDD |
| Hotfix / typo / formatting change | Skip |
| Intent doc already exists in `docs/superpowers/intents/` | Skip → go to /brainstorm |
| "It's small" / "I already know what to build" | Run IDD anyway |

## Process

### Step 0: Load project context via lat.md (if available)

Before asking any questions, check whether `lat_search` MCP tool is available. If yes, load context in parallel:

1. `lat_search <topic>` — existing documentation for this topic
2. `lat_refs <topic>` — components that reference this area (dependency map)

Store results as **lat_context** for use in Steps 1–6 below.

Present to user:

```
📚 Контекст из lat.md:
[найденные секции, или "Документация по теме не найдена"]

🔗 Компоненты, которые ссылаются на эту область:
[список, или "Зависимостей не найдено"]
```

If `lat_search` is unavailable or returns no results — skip silently. Do not block or mention the absence.

---

### Steps 1–6: Six questions (one at a time)

Ask each question **one at a time**. Wait for the user's answer before proceeding. Do not batch.

For each question, if **lat_context** contains relevant information — show it as a hint before asking. If lat_context is empty — ask the plain question.

---

**Q1 — Objective:** What problem does this solve, and why now?

> *If lat_context has relevant docs:*
> "Из существующей документации по «[topic]»: [краткая выжимка — что уже задокументировано, какие решения приняты].
> Что именно нужно изменить или добавить, и почему сейчас?"

---

**Q2 — Desired Outcomes:** What observable, user-facing states confirm success?

*(No lat enrichment — outcomes are user-defined, not derivable from existing docs.)*

---

**Q3 — Health Metrics:** What must not degrade?

> *If lat_refs returned components:*
> "Эти компоненты ссылаются на данную область: [список из lat_refs].
> Что из них нельзя сломать? Какие метрики должны остаться стабильными?"
>
> *(Goodhart's Law: name the metrics that stay stable even if the feature ships.)*

---

**Q4 — Strategic Context:** What systems, modules, or people interact with this? Priority trade-off: trust / speed / cost?

> *If lat_context has architecture sections:*
> "Из документации по архитектуре: [релевантный фрагмент].
> Что ещё взаимодействует с этой областью? Какой приоритет — доверие / скорость / стоимость?"

---

**Q5 — Constraints:** What steering constraints (behavioral guidance) apply? What hard constraints (architectural or forbidden) apply?

> *If lat_context has decisions or constraints sections:*
> "Существующие архитектурные решения по теме: [фрагмент из lat].
> Какие из них остаются в силе? Что добавляется как новое ограничение?"

---

**Q6 — Autonomy & Stop Rules:** For each decision type, which autonomy zone applies: full / guarded / proposal-first / no-go? What conditions halt, escalate, or mark completion?

*(No lat enrichment — autonomy policy is defined by the user per feature.)*

---

### After all six answers

**Validation checklist** — verify before presenting the doc:
1. All sections filled — no empty bullets?
2. Every constraint maps to steering OR hard (not both)?
3. Autonomy zones cover all decision types in this feature?
4. Stop Rules include at least one "Done when:" criterion?

Fix any failures inline, then present.

**Write the intent doc** using the template below. Fill each section with the user's answers verbatim or lightly edited for clarity.

**File path:** `docs/superpowers/intents/YYYY-MM-DD-<topic>-intent.md`

Commit:
```bash
git add docs/superpowers/intents/ && git commit -m "docs(idd): add intent doc for <topic>"
```

**User review gate:**
1. Show a summary of the written document.
2. Ask: "Review the intent doc. Approve it or request changes."
3. On approval: update `Status: draft` → `Status: approved`, re-commit.
4. On changes requested: edit → re-show → repeat.
5. Only after approval: "Intent doc approved. Run /brainstorm next."

## Intent doc template

```markdown
# Intent: <topic>

**Date:** YYYY-MM-DD
**Status:** draft

## Objective
[Answer to Q1]

## Desired Outcomes
- [observable state 1]
- [observable state 2]

## Health Metrics
- [metric that must not degrade]

## Strategic Context
- Interacts with: [modules / agents / humans]
- Priority trade-off: [trust | speed | cost]

## Constraints
### Steering (behavioral guidance)
- [guideline 1]

### Hard (architectural enforcement)
- [restriction 1]

## Autonomy Zones
- Full autonomy (reversible, low risk): [decision types]
- Guarded (log + confidence threshold): [decision types]
- Proposal-first (needs approval): [decision types]
- No autonomy (human only): [decision types]

## Stop Rules
- Halt if: [condition]
- Escalate if: [condition]
- Done when: [completion criterion]
```

## Common mistakes

- **"It's a small change"** — A new CLI flag is a CLI API change. Still run IDD. Intent docs take 5 minutes and prevent hours of misaligned work.
- **"Let me ask one clarifying question and proceed"** — Asking scope is not capturing intent. Scope answers WHAT; intent captures WHY, outcomes, and stop conditions.
- **"lat not available"** — Skip Step 0 silently. Never block IDD or mention the absence of lat context. The process works without it.
