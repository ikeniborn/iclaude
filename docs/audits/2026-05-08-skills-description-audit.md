# Skills Description Audit

**Дата:** 2026-05-08
**Scope:** `.nvm-isolated/.claude-isolated/skills/*/SKILL.md` (13 скиллов)
**Цель:** устранить противоречия и двусмысленности в `description` frontmatter, чтобы каждый навык однозначно определялся при обращении.

---

## 1. Сводная таблица проблем

| # | Skill | Severity | Проблема | Тип |
|---|-------|----------|----------|-----|
| 1 | `graphify` | **HIGH** | Триггер "any question about a codebase" перехватывает запросы, адресованные `graphify-context`, `llm-wiki`, `context-awareness` | Overlap |
| 2 | `context-awareness` | **HIGH** | "Автоматическое определение контекста проекта. Поиск по документации." — нет триггерных фраз, ни одного "use when" | Underspecified |
| 3 | `git-workflow` | **HIGH** | "Стандартизированный git workflow с Conventional Commits" — не описано **когда** активировать | Underspecified |
| 4 | `mermaid-obsidian` | **MED** | "Always use this skill even if user just says 'draw'" конфликтует с `prd-generator` и `architecture-documentation`, которые сами генерят Mermaid | Overlap |
| 5 | `architecture-documentation` ⟷ `prd-generator` | **MED** | Оба создают Markdown + Mermaid. Граница (arch vs product) неявная | Overlap |
| 6 | `agent-builder` ⟷ `prompt-verifier` | **LOW** | Оба трогают `AGENT.md` / `SKILL.md`; нет явной фразы "не для создания/не для верификации" | Boundary |
| 7 | `llm-wiki` | **LOW** | Нет триггерных глаголов уровня MCP (только "когда нужно создать, обновить") | Weak triggers |
| 8 | `agent-builder` | **LOW** | Не сказано, что **не** для верификации существующих агентов | Boundary |
| 9 | `toon-skill` | INFO | `user-invocable: false` — internal API, описание адекватно | OK |
| 10 | `compact-session` | INFO | Эталон: явные триггерные фразы в кавычках | OK |

---

## 2. Эталонные образцы (не трогать)

- **`mermaid-obsidian`** — explicit triggers ("draw a diagram", "create a flowchart", ...), охватывает все типы, явно объясняет приоритет.
- **`compact-session`** — список триггерных фраз в кавычках + slash-команда + альтернативный путь (".jsonl path").
- **`graphify-context`** — "Use when ... — especially at brainstorming Step 1" + явное отличие от `graphify` ("without rebuilding").

Структура эталона:
```
Use when <ситуация>. Triggers: "<phrase1>", "<phrase2>", ... .
NOT for <границы>. Differs from <similar-skill>: <разница>.
```

---

## 3. Детальный разбор + предложенные description

### 3.1 `graphify` (HIGH — overlap)

**Текущий:**
> any input (code, docs, papers, images, videos) to knowledge graph. Use when user asks any question about a codebase, documents, or project content — especially if `${GRAPHIFY_OUT:-graphify-out}/` exists, treat the question as a /graphify query.

**Проблема:** "any question about a codebase" перехватывает запросы, для которых уже есть специализированные навыки (`graphify-context` — чтение готового графа; `llm-wiki` — синтез wiki; `context-awareness` — детект языка/framework). Использование "treat the question as a /graphify query" агрессивно расширяет область.

**Предложенный:**
```
Build knowledge graph from a folder of files (code, docs, papers, images, videos) — community detection, audit trail, three outputs (HTML, GraphRAG JSON, GRAPH_REPORT.md). Use when user types /graphify, asks to "build/rebuild/update the graph", or graph artifacts are missing in ${GRAPHIFY_OUT:-graphify-out}/. NOT for querying an existing graph — use graphify-context. NOT for project-language detection — use context-awareness.
```

---

### 3.2 `context-awareness` (HIGH — underspecified)

**Текущий:**
> Автоматическое определение контекста проекта. Поиск по документации.

**Проблема:** ни одного "use when". Фраза "Поиск по документации" пересекается с `llm-wiki` и `graphify-context`. `user-invocable: false` — навык активируется автоматически, тем более нужны чёткие триггеры.

**Предложенный:**
```
Detect project language, framework, package manager, lint/test commands and locate CLAUDE.md / PRD docs at task start (Phase 0). Use when starting any task, switching project, or before running syntax/test checks. NOT for querying knowledge graph (graphify-context) and NOT for wiki synthesis (llm-wiki).
```

---

### 3.3 `git-workflow` (HIGH — underspecified)

**Текущий:**
> Стандартизированный git workflow с Conventional Commits

**Проблема:** нет триггеров. SKILL.md внутри упоминает Phase 1.5 / 5A / 5B, но `description` это не отражает.

**Предложенный:**
```
Standardized git workflow with Conventional Commits. Use when creating a feature branch, staging commits, opening a PR, or when user says "commit", "create branch", "open PR", "fix commit message". Enforces commit prefix (feat/fix/docs/...), branch naming, PR template.
```

---

### 3.4 `mermaid-obsidian` (MED — overlap)

**Текущий (фрагмент):**
> Always use this skill even if the user just says "draw" or "diagram" without specifying Mermaid explicitly — if they're working in Obsidian, Mermaid is the right tool.

**Проблема:** агрессивный перехват. `prd-generator` и `architecture-documentation` сами строят Mermaid внутри своих pipeline — формально каждый запрос на их работу содержит "diagram", и `mermaid-obsidian` будет конкурировать.

**Предложенный (изменить только финальную фразу):**
```
... Always use this skill when user asks to draw/fix a standalone diagram in Obsidian. NOT for diagrams embedded inside PRD documents (use prd-generator) or architecture YAML (use architecture-documentation) — those skills generate Mermaid internally.
```

---

### 3.5 `architecture-documentation` ⟷ `prd-generator` (MED)

**Текущие:**
- `architecture-documentation`: "Generate detailed architectural documentation in YAML and TOON formats with component dependencies and relationships"
- `prd-generator`: "Автоматизированное создание Product Requirements Document (PRD) с интерактивными вопросами, AI-генерацией 14 разделов и 5 Mermaid диаграмм"

**Проблема:** оба создают Markdown + Mermaid. Граница "что описываем — компоненты vs продукт" не сформулирована.

**Предложенные:**

`architecture-documentation`:
```
Generate developer-facing architecture docs (component graph, dependencies, data flows) in YAML + TOON + Mermaid. Use when user asks to "document architecture", "map components/dependencies", "build module diagram". NOT for product/feature requirements — use prd-generator.
```

`prd-generator`:
```
Generate Product Requirements Document (PRD) — 14 sections + 5 Mermaid diagrams via interactive Q&A. Use when user asks to "write PRD", "draft product spec", "describe product requirements". NOT for technical architecture docs — use architecture-documentation.
```

---

### 3.6 `agent-builder` ⟷ `prompt-verifier` (LOW)

**Предложенные:**

`agent-builder`:
```
Interactively scaffold a NEW Claude Code sub-agent (AGENT.md with valid frontmatter, role docs, IO examples, schema validation). Use when user asks to "create/scaffold/build agent", "new sub-agent". NOT for editing existing AGENT.md/SKILL.md/CLAUDE.md — use prompt-verifier.
```

`prompt-verifier`:
```
Verify and rewrite EXISTING instruction files (CLAUDE.md, AGENT.md, SKILL.md) against 7 formatting rules. Use when user asks to "review/fix/audit prompt", "agent ignores rules", "refactor instructions", before committing changes to instruction files. NOT for creating new agents — use agent-builder.
```

---

### 3.7 `llm-wiki` (LOW)

**Предложенный:**
```
Build and maintain Obsidian wiki from raw sources (code, docs, papers) — extract, synthesize, deduplicate domain knowledge. Use when user asks to "build/update/refresh wiki", "ingest new sources into vault", "synthesize knowledge by domain". NOT for live codebase queries — use graphify-context.
```

---

### 3.8 `compact-session` / `graphify-context` / `mermaid-obsidian` (эталоны)

Без правок описания. Опционально — добавить к `mermaid-obsidian` границу из § 3.4.

---

### 3.9 `toon-skill` (info, не трогать)

`user-invocable: false`, internal helper для inter-skill comms. Описание адекватно.

---

## 4. Универсальные правила description

1. **Pattern:** `<что делает>. Use when <триггеры>. NOT for <боундари>.`
2. Триггерные фразы — в кавычках, минимум 3-5 шт.
3. Указывать соседние навыки + явно различать.
4. Slash-команда (если есть) — упоминать в description, не только в `trigger:`.
5. Длина: 1-3 предложения. Очень короткое (<15 слов) описание = недостаточно для роутинга.
6. Глагол в начале (Build / Generate / Detect / Verify / Query) — не существительное.

---

## 5. Матрица "после правок" — проверка отсутствия overlap

| Запрос пользователя | Должен сработать |
|---|---|
| "построй граф проекта" | `graphify` |
| "как X связан с Y?" / "архитектура модуля Foo" | `graphify-context` |
| "обнови wiki по домену auth" | `llm-wiki` |
| "какой framework тут?" / Phase 0 старт задачи | `context-awareness` |
| "нарисуй flowchart деплоя" | `mermaid-obsidian` |
| "задокументируй архитектуру" | `architecture-documentation` |
| "напиши PRD на feature X" | `prd-generator` |
| "создай sub-agent test-runner" | `agent-builder` |
| "проверь мой CLAUDE.md" | `prompt-verifier` |
| "проанализируй session" | `compact-session` |
| "сделай commit / открой PR" | `git-workflow` |
| (internal) JSON↔TOON | `toon-skill` (не user-invocable) |

После правок — single-skill match для каждой строки.

---

## 6. Рекомендуемый порядок применения

1. HIGH (3 шт): `graphify`, `context-awareness`, `git-workflow` — без них роутинг ломается.
2. MED (2 шт): `mermaid-obsidian` финальная фраза, пара `architecture-documentation`/`prd-generator`.
3. LOW (3 шт): `agent-builder`, `prompt-verifier`, `llm-wiki`.

Каждая правка — single-line edit в frontmatter поле `description:`. Тело SKILL.md не трогать.
