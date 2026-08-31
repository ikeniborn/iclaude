---
name: context-awareness
description: Detect project language, framework, package manager, lint/test commands and locate CLAUDE.md / PRD docs at task start (Phase 0). Also detects the iwiki MCP domain for this project (doc summary), its specification mode, and its code-graph availability/state, surfacing them as project context. Use when starting any task, switching project, or before running syntax/test checks. NOT for deep semantic doc search (wiki_search), scenario lookup (wiki_spec_search/wiki_spec_context), or code-graph queries (wiki_code_search/wiki_code_context) — this skill only detects availability + a quick summary.
user-invocable: false
agent: Explore
# version: 1.7.2
# tags: context, detection, project, language, framework, lat
# dependencies: []
# files: templates: ./templates/*.json
---

# Context Awareness

Автоматическое определение языка, framework, наличия PRD и домена документации iwiki (MCP) для проекта.

## Когда использовать

- В начале КАЖДОЙ задачи (Phase 0)
- При переключении между проектами
- Когда нужно определить syntax check команду

## Алгоритм определения

### 1. Определение языка

```
Приоритет файлов:
1. package.json → JavaScript/TypeScript
2. requirements.txt, pyproject.toml → Python
3. go.mod → Go
4. Cargo.toml → Rust
5. *.sh в корне → Bash
```

### 2. Определение framework

```
Python:
- fastapi в dependencies → FastAPI
- django в dependencies → Django
- flask в dependencies → Flask

JavaScript:
- react в dependencies → React
- express в dependencies → Express
- next в dependencies → Next.js
```

### 3. Определение PRD

```
Пути для проверки:
- docs/prd/
- docs/PRD.md
- PRD.md
- docs/requirements/
```

### 4. Syntax Command Lookup

Mapping language → syntax check command:

| language | syntax_command |
|---|---|
| python | `python -m py_compile <file>` |
| javascript | `node --check <file>` |
| typescript | `npx tsc --noEmit` |
| go | `go vet ./...` |
| rust | `cargo check` |
| bash | `bash -n <file>` |

Если язык не определён — `syntax_command: null`, syntax-проверка пропускается.

### 5. iwiki Detection

Документационный граф проекта живёт в **MCP-сервере iwiki** (внешний central-store,
адресуется доменами). Единственный источник документационного контекста проекта.

```
1. Когда известны canonical topic и basename проекта, всегда проверить
   `$CLAUDE_CONFIG_DIR/state/iwiki-task-spool/<project>/<topic>.json`,
   even when iwiki is unavailable or the project domain is absent. Установить
   `task_delivery_pending: true when that queue file exists`; очередь не является
   durable status.

IF MCP-сервер iwiki подключён:
  2. wiki_status (на резолвленном сервере — см. multi-transport tool-name resolution в
     iwiki Project Binding из CLAUDE.md: `iwiki-remote`, иначе `iwiki-local`, иначе
     одиночный `iwiki`) → project_dir, список `domains`, действующая привязка
     read/write/primary. Скилл НИКОГДА не вызывает wiki_bind: привязку делает parent
     agent по тому же протоколу. Здесь только чтение.
  3. Если wiki_status вернул непустой `primary` (домен записи проекта):
       - <domain> ← primary
       - wiki_summary ← wiki_read_page(domain, "overview") (если есть)
         либо wiki_search('ключевые компоненты и архитектура проекта')
     Добавить в project_context:
       wiki_initialized: true
       wiki_domain: "<domain>"
       wiki_summary: <обзор страницы overview или результат wiki_search>
       task_topic: <canonical topic or null>
       task_page_slug: "reference/tasks/<topic>" | null
       task_page_found: true|false
       task_lifecycle: "in-progress|blocked|completion-pending|done" | null
       task_delivery_pending: true|false
     Из того же ответа `wiki_status` взять запись `specifications.domains[]`, чей
     `domain` совпадает с `primary` (дополнительный вызов не нужен):
       spec_mode: "<mode>" (disabled|optional|strict)
       spec_source: "<source>" (project|hosted_default|hosted_override|built_in_default)
       spec_projection_state: "<projection_state>" (disabled|absent|ready|stale|failed)
       spec_scenarios: <scenarios> (целое)
     Блок `specifications` отсутствует или в нём нет записи для `primary` →
     spec_mode: null, spec_source: null, spec_projection_state: null, spec_scenarios: null.
     Действующий режим берётся только отсюда: `[specifications] mode` из `.iwiki.toml`
     на hosted-транспорте не применяется (см. Keep Specifications Current в CLAUDE.md).
     Затем `wiki_code_status()` (read-only, тот же домен `primary`, на резолвленном
     code-graph сервере — `iwiki-local`, иначе одиночный `iwiki`, см. multi-transport
     tool-name resolution в CLAUDE.md). Ответ содержит `enabled`, `domain`, `state`,
     `fresh`, `revision`, `warnings`:
       code_graph_available: true только когда `state == "ready"` И `fresh == true`; иначе false
       code_graph_domain: "<domain>" (то же, что wiki_domain)
       code_graph_state: "<state из wiki_code_status>"
         (ready|missing_snapshot|disabled|source_unavailable|dirty|rebuilding|failed|incompatible)
       code_graph_fresh: <поле `fresh` из ответа> (false, если поля нет)
     `wiki_code_status` недоступен / вызов упал → code_graph_available: false, code_graph_state: null,
     code_graph_fresh: false, без блокировки остального Phase 0.
  4. Если `primary` пуст (привязка не выполнена или проект без .iwiki.toml):
       wiki_initialized: false
       wiki_domain: null
       wiki_summary: null
       task_topic: <canonical topic or null>
       task_page_slug: "reference/tasks/<topic>" | null
       task_page_found: false
       task_lifecycle: null
       task_delivery_pending: <spool result when topic known; otherwise false>
       spec_mode: null
       spec_source: null
       spec_projection_state: null
       spec_scenarios: null
       code_graph_available: false
       code_graph_domain: null
       code_graph_state: null
       code_graph_fresh: false

ELSE (сервер не подключён):
  wiki_initialized: false
  wiki_domain: null
  wiki_summary: null
  task_topic: <canonical topic or null>
  task_page_slug: "reference/tasks/<topic>" | null
  task_page_found: false
  task_lifecycle: null
  task_delivery_pending: <spool result when topic known; otherwise false>
  spec_mode: null
  spec_source: null
  spec_projection_state: null
  spec_scenarios: null
  code_graph_available: false
  code_graph_domain: null
  code_graph_state: null
  code_graph_fresh: false
```

При действующей привязке Phase 0 выводит точный контекст task page: определяет
канонический topic из запроса или уже контролируемых артефактов, читает
`reference/tasks/<topic>`, если topic известен. Независимо от доступности iwiki он
проверяет `$CLAUDE_CONFIG_DIR/state/iwiki-task-spool/<project>/<topic>.json`; очередь
показывает только `task_delivery_pending`, она не является durable status. Создание
страницы остаётся интерактивным действием parent agent по `task-ledger`, не действием
context-awareness.

**Назначение:** Централизует проверку доступности документационного графа —
downstream-навыки (brainstorming, prd-generator) используют
`project_context.wiki_initialized` вместо самостоятельной проверки.
`wiki_search` — опциональный семантический поиск по секциям внутри задачи.

**Границы:** скилл работает read-only против iwiki (`wiki_status`, `wiki_read_page`,
`wiki_search`, `wiki_code_status`). Ни `wiki_bind`, ни любой мутирующий вызов
(включая `wiki_code_index` и `wiki_spec_resolve`) из него не выполняется — привязка,
запись и перестроение графа принадлежат parent agent. `spec_*` — только доступность и
режим из `wiki_status`; поиск сценариев (`wiki_spec_search`, `wiki_spec_context`)
делает parent agent по задаче.

## Output

Используй шаблон: `@template:project-context`

## Quick Reference

```json
{
  "project_context": {
    "language": "python|javascript|typescript|go|rust|bash",
    "framework": "fastapi|django|react|express|none",
    "test_framework": "pytest|jest|go test|none",
    "has_prd": true|false,
    "prd_path": "docs/prd/" | null,
    "syntax_command": "<команда из таблицы Syntax Command Lookup>",
    "code_style": "pep8|prettier|gofmt|none",
    "wiki_initialized": true|false,
    "wiki_domain": "<имя домена iwiki>" | null,
    "wiki_summary": "синтезированный обзор из домена iwiki" | null,
    "spec_mode": "disabled|optional|strict" | null,
    "spec_source": "project|hosted_default|hosted_override|built_in_default" | null,
    "spec_projection_state": "disabled|absent|ready|stale|failed" | null,
    "spec_scenarios": <целое> | null,
    "code_graph_available": true|false,
    "code_graph_domain": "<имя домена iwiki>" | null,
    "code_graph_state": "ready|missing_snapshot|disabled|source_unavailable|dirty|rebuilding|failed|incompatible" | null,
    "code_graph_fresh": true|false,
    "task_topic": "<canonical topic>" | null,
    "task_page_slug": "reference/tasks/<topic>" | null,
    "task_page_found": true|false,
    "task_lifecycle": "in-progress|blocked|completion-pending|done" | null,
    "task_delivery_pending": true|false
  }
}
```

## Examples

### Example 1: Python FastAPI Project

**Project structure:**
```
/home/user/api-project/
├── requirements.txt (fastapi==0.104.1)
├── pyproject.toml
├── src/
│   └── main.py
├── tests/
└── docs/
    └── prd/
        └── API_SPEC.md
```

**Detection result:**
```json
{
  "project_context": {
    "language": "python",
    "framework": "fastapi",
    "test_framework": "pytest",
    "has_prd": true,
    "prd_path": "docs/prd/",
    "syntax_command": "python -m py_compile",
    "code_style": "pep8",
    "wiki_initialized": false,
    "wiki_domain": null,
    "wiki_summary": null,
    "task_topic": null,
    "task_page_slug": null,
    "task_page_found": false,
    "task_lifecycle": null,
    "task_delivery_pending": false
  }
}
```

---

### Example 2: TypeScript React Project

**Project structure:**
```
/home/user/web-app/
├── package.json (react: ^18.2.0, typescript: ^5.0.0)
├── tsconfig.json
├── src/
│   ├── App.tsx
│   └── components/
├── tests/
└── PRD.md
```

**Detection result:**
```json
{
  "project_context": {
    "language": "typescript",
    "framework": "react",
    "test_framework": "jest",
    "has_prd": true,
    "prd_path": "PRD.md",
    "syntax_command": "tsc --noEmit",
    "code_style": "prettier",
    "wiki_initialized": false,
    "wiki_domain": null,
    "wiki_summary": null,
    "task_topic": null,
    "task_page_slug": null,
    "task_page_found": false,
    "task_lifecycle": null,
    "task_delivery_pending": false
  }
}
```

---

### Example 3: Go Project with PRD

**Project structure:**
```
/home/user/go-service/
├── go.mod
├── main.go
├── internal/
│   └── handlers/
├── tests/
└── docs/
    └── requirements/
        └── SPEC.md
```

**Detection result:**
```json
{
  "project_context": {
    "language": "go",
    "framework": "none",
    "test_framework": "go test",
    "has_prd": true,
    "prd_path": "docs/requirements/",
    "syntax_command": "go build -o /dev/null",
    "code_style": "gofmt",
    "wiki_initialized": false,
    "wiki_domain": null,
    "wiki_summary": null,
    "task_topic": null,
    "task_page_slug": null,
    "task_page_found": false,
    "task_lifecycle": null,
    "task_delivery_pending": false
  }
}
```

---

### Example 4: Bash Script Project — без привязанного домена iwiki

**Project structure:**
```
/home/user/scripts/
├── deploy.sh
├── backup.sh
├── utils/
│   └── logger.sh
└── README.md
```

**Detection result:**
```json
{
  "project_context": {
    "language": "bash",
    "framework": "none",
    "test_framework": "none",
    "has_prd": false,
    "prd_path": null,
    "syntax_command": "bash -n",
    "code_style": "none",
    "wiki_initialized": false,
    "wiki_domain": null,
    "wiki_summary": null,
    "task_topic": null,
    "task_page_slug": null,
    "task_page_found": false,
    "task_lifecycle": null,
    "task_delivery_pending": false
  }
}
```

---

### Example 4b: Bash Script Project — с привязанным доменом iwiki

**Project structure:**
```
/home/user/iclaude/
├── iclaude.sh
├── lib/
│   └── proxy/...
└── docs/
    ├── PROXY.md
    └── ROUTER.md
```

**Detection result:**
```json
{
  "project_context": {
    "language": "bash",
    "framework": "none",
    "test_framework": "pytest",
    "has_prd": false,
    "prd_path": null,
    "syntax_command": "bash -n",
    "code_style": "none",
    "wiki_initialized": true,
    "wiki_domain": "iclaude",
    "wiki_summary": "iclaude — bash-обёртка для Claude Code: HTTP/HTTPS-прокси, изолированная NVM-среда, OAuth-обновление токенов, Claude Code Router, PII-прокси (Presidio), microVM-песочница, security-хуки.",
    "code_graph_available": false,
    "code_graph_domain": "iclaude",
    "code_graph_state": "missing_snapshot",
    "code_graph_fresh": false,
    "task_topic": "task-ledger-skill-parity",
    "task_page_slug": "reference/tasks/task-ledger-skill-parity",
    "task_page_found": true,
    "task_lifecycle": "in-progress",
    "task_delivery_pending": false
  }
}
```

---

### Example 4c: Bash Script Project — с привязанным доменом iwiki (минимальный)

**Project structure:**
```
/home/user/iclaude/
├── iclaude.sh
├── lib/
└── docs/
```

**Detection result:**
```json
{
  "project_context": {
    "language": "bash",
    "framework": "none",
    "test_framework": "pytest",
    "has_prd": false,
    "prd_path": null,
    "syntax_command": "bash -n",
    "code_style": "none",
    "wiki_initialized": true,
    "wiki_domain": "iclaude",
    "wiki_summary": "iclaude — bash-обёртка для Claude Code: прокси, NVM, OAuth, PII-маскирование, microVM, security-хуки.",
    "code_graph_available": false,
    "code_graph_domain": "iclaude",
    "code_graph_state": "missing_snapshot",
    "code_graph_fresh": false,
    "task_topic": "task-ledger-skill-parity",
    "task_page_slug": "reference/tasks/task-ledger-skill-parity",
    "task_page_found": true,
    "task_lifecycle": "in-progress",
    "task_delivery_pending": false
  }
}
```

---

### Example 5: Multi-Language Project (Python Backend + JS Frontend)

**Project structure:**
```
/home/user/fullstack-app/
├── backend/
│   ├── requirements.txt (fastapi)
│   └── src/
├── frontend/
│   ├── package.json (react)
│   └── src/
├── docs/
│   └── PRD.md
└── README.md
```

**Detection priority (root directory check first):**
```json
{
  "project_context": {
    "language": "python",
    "framework": "fastapi",
    "test_framework": "pytest",
    "has_prd": true,
    "prd_path": "docs/PRD.md",
    "syntax_command": "python -m py_compile",
    "code_style": "pep8",
    "notes": [
      "Multi-language project detected",
      "Frontend: JavaScript/React in frontend/ subdirectory",
      "Backend language (Python) selected as primary based on root-level requirements.txt"
    ]
  }
}
```

**Alternative detection (if invoked from frontend/ subdirectory):**
```json
{
  "project_context": {
    "language": "javascript",
    "framework": "react",
    "test_framework": "jest",
    "has_prd": true,
    "prd_path": "../docs/PRD.md",
    "syntax_command": "npx tsc --noEmit",
    "code_style": "prettier",
    "notes": [
      "Working directory: frontend/",
      "Root project has multi-language structure"
    ]
  }
}
```

---

## Integration with Other Skills

**Used by:** any task that needs the project's language, framework, test/syntax command,
or iwiki availability before acting — the caller reads `project_context` fields instead of
re-detecting them.

**Delegates to:**
- iwiki MCP `wiki_search` - Targeted semantic search over the project's iwiki domain (optional, in-task)

**Provides:**
- `language` → Enables language-specific tooling
- `framework` → Enables framework-specific patterns
- `prd_path` → Enables PRD-driven validation
- `syntax_command` → Enables pre-commit syntax checks
- `wiki_initialized` / `wiki_domain` / `wiki_summary` → Enables doc-graph-aware context without re-checking files
- `code_graph_available` / `code_graph_domain` / `code_graph_state` / `code_graph_fresh` → Enables `wiki_code_search`/`wiki_code_context`-first analysis without re-checking `wiki_code_status`
- `task_topic` / `task_page_slug` / `task_page_found` / `task_lifecycle` / `task_delivery_pending` → Enables `task-ledger` to resume a topic without re-deriving its state

---

🤖 Generated with Claude Code

**Author:** ikeniborn
**License:** MIT

## Changelog

### 1.7.2 (2026-08-25)
- `code_graph_available` now requires `fresh == true` alongside `state == "ready"`, matching
  the freshness gate `wiki_code_status` actually reports
- New field `code_graph_fresh`; `code_graph_state` vocabulary extended with `dirty`,
  `rebuilding`, `failed`, and `incompatible`

### 1.7.1 (2026-08-17)
- `wiki_status`/`wiki_code_status` calls now reference CLAUDE.md's multi-transport
  tool-name resolution instead of naming the server generically — dual-mode sessions
  expose `iwiki-local`/`iwiki-remote`, not a single `iwiki`

### 1.7.0 (2026-08-17)
- Code-graph detection added: `code_graph_available`, `code_graph_domain`, `code_graph_state` via read-only `wiki_code_status()` alongside the existing wiki detection
- `Границы` updated to list `wiki_code_status` among the read-only calls this skill makes

### 1.6.0 (2026-08-14)
- Task-ledger context added: `task_topic`, `task_page_slug`, `task_page_found`, `task_lifecycle`, `task_delivery_pending`
- Phase 0 probes the local spool at `$CLAUDE_CONFIG_DIR/state/iwiki-task-spool/<project>/<topic>.json` even when iwiki is unavailable

### 1.5.0 (2026-06-30)
- iwiki detection switched from `docs/wiki/` files to the iwiki MCP server (`wiki_status`)
- Output field `wiki_index_path` → `wiki_domain`; `iwiki:iwiki-query` delegate → MCP `wiki_search`

### 1.4.1 (2026-06-18)
- Удалён graphify knowledge-graph detection (Phase 6) и поля `graph_*` из output — graphify выпилен из проекта
- `graphify-context` убран из delegates

### 1.4.0 (2026-06-17)
- Заменён `lat.md/` detect на `docs/wiki/` detection (читает корневой индекс `docs/wiki/index.md`)
- Поля `lat_*` → `wiki_*` (`wiki_initialized`, `wiki_index_path`, `wiki_summary`)
- `graphify` detection дополнен: docs/wiki = проза, graph = структура
- `lat-search` заменён на `iwiki:iwiki-query` в delegates и dependencies

### 1.3.0 (2026-06-07)
- Заменён мёртвый detect `.wiki/` + `llm-wiki` на `lat.md/` detection (читал корневой индекс `lat.md/lat.md`)
- `lat-search` и `graphify-context` оформлены как delegates; добавлены в dependencies

### 1.2.0 (2026-02-19)

### 1.1.0 (2026-01-25)
- Добавлено: 5 примеров (Python FastAPI, TypeScript React, Go with PRD, Bash, multi-language)
- Обновлены references на @shared:
- Улучшена документация detection алгоритмов

### 1.0.0 (2025-XX-XX)
- Initial release
