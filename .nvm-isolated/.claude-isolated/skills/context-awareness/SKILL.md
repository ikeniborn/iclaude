---
name: context-awareness
description: Detect project language, framework, package manager, lint/test commands and locate CLAUDE.md / PRD docs at task start (Phase 0). Also detects lat.md/ documentation graph and graphify knowledge graph, surfacing their summaries as project context. Use when starting any task, switching project, or before running syntax/test checks. NOT for deep semantic doc search (lat-search) and NOT for graph queries (graphify-context) — this skill only detects availability + a quick summary.
user-invocable: false
agent: Explore
# version: 1.3.0
# tags: context, detection, project, language, framework, lat, graphify
# dependencies: [lat-search, graphify-context]
# files: templates: ./templates/*.json, shared: ../_shared/syntax-commands.json
---

# Context Awareness

Автоматическое определение языка, framework, наличия PRD, документационного графа `lat.md/` и knowledge graph `graphify` в проекте.

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

См. `@shared:syntax-commands.json` для mapping language → syntax check command.

### 5. lat.md Detection

Документационный граф `lat.md/` — cross-linked markdown, описывающий архитектуру,
дизайн-решения и тест-спеки. Единственный источник документационного контекста проекта.

```
IF exists {CWD}/lat.md/ (директория с .md-файлами):
  1. Прочитать {CWD}/lat.md/lat.md (корневой индекс)
     → извлечь синтезированный обзор проекта (leading paragraph)
     → извлечь список секций из [[refs]] в блоке "## Sections"
  2. (опционально, если LAT_LLM_KEY задан и нужен более точный обзор)
     Skill(skill="lat-search", args='search "ключевые компоненты и архитектура проекта"')
     → использовать результат как lat_summary вместо корневого индекса
  3. Добавить в project_context:
       lat_initialized: true
       lat_sections: [список id из [[refs]], напр. ["architecture", "proxy", ...]]
       lat_index_path: "lat.md/lat.md"
       lat_summary: <обзор из корневого индекса или результат lat-search>

ELSE:
  lat_initialized: false
  lat_sections: []
  lat_index_path: null
  lat_summary: null
```

**Назначение:** Централизует проверку доступности документационного графа —
downstream-навыки (brainstorming, prd-generator) используют
`project_context.lat_initialized` вместо самостоятельной проверки файла.
Корневой индекс `lat.md/lat.md` читается напрямую (дёшево, без LLM-ключа);
`lat-search` оставлен как опциональный точечный поиск по секциям внутри задачи.

### 6. Graph Detection (graphify)

Сначала resolve выходную директорию (для iclaude `GRAPHIFY_OUT=.graphify`):

```bash
GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")
```

Проверить наличие knowledge graph в корне проекта:

```
IF exists {CWD}/{GOUT}/GRAPH_REPORT.md:
  Skill(skill="graphify-context")
  → добавить результат в project_context:
       graph_initialized: true
       graph_god_nodes: [из graph_context.god_nodes]
       graph_communities: graph_context.communities
       graph_summary: graph_context.graph_summary
       graph_fresh: graph_context.fresh если typeof === boolean, иначе null

ELSE:
  graph_initialized: false
  graph_god_nodes: []
  graph_communities: 0
  graph_summary: null
```

**Назначение:** Централизует проверку графа — brainstorming и другие навыки используют
`project_context.graph_initialized` вместо самостоятельной проверки файлов.
Дополняет lat.md: lat.md даёт синтезированную прозу (что и почему),
граф — структурные связи (как компоненты соединены).

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
    "syntax_command": "@shared:syntax-commands[language].syntax",
    "code_style": "pep8|prettier|gofmt|none",
    "lat_initialized": true|false,
    "lat_sections": ["architecture", "proxy", "pii-proxy"],
    "lat_index_path": "lat.md/lat.md" | null,
    "lat_summary": "синтезированный обзор из lat.md" | null,
    "graph_initialized": true|false,
    "graph_fresh": true|false|null,
    "graph_god_nodes": ["ComponentA (20 edges)", "ComponentB (13 edges)"],
    "graph_communities": 0,
    "graph_summary": "структурный контекст из knowledge graph" | null
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
    "code_style": "pep8"
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
    "code_style": "prettier"
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
    "code_style": "gofmt"
  }
}
```

---

### Example 4: Bash Script Project — без lat.md

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
    "lat_initialized": false,
    "lat_sections": [],
    "lat_index_path": null,
    "lat_summary": null
  }
}
```

---

### Example 4b: Bash Script Project — с инициализированной lat.md

**Project structure:**
```
/home/user/iclaude/
├── iclaude.sh
├── lib/
│   └── proxy/...
├── docs/
│   ├── PROXY.md
│   └── ROUTER.md
└── lat.md/
    ├── lat.md          ← корневой индекс + [[refs]] на секции
    ├── architecture.md
    ├── proxy.md
    └── pii-proxy.md
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
    "lat_initialized": true,
    "lat_sections": ["architecture", "launch-flow", "proxy", "pii-proxy", "router", "sandbox", "security", "isolation", "oauth"],
    "lat_index_path": "lat.md/lat.md",
    "lat_summary": "iclaude — bash-обёртка для Claude Code: HTTP/HTTPS-прокси, изолированная NVM-среда, OAuth-обновление токенов, Claude Code Router, PII-прокси (Presidio), microVM-песочница, security-хуки."
  }
}
```

---

### Example 4c: Bash Script Project — с lat.md и knowledge graph

**Project structure:**
```
/home/user/iclaude/
├── iclaude.sh
├── lib/
├── docs/
├── lat.md/
│   ├── lat.md          ← корневой индекс
│   ├── architecture.md
│   └── pii-proxy.md
└── .graphify/          ← GRAPHIFY_OUT=.graphify for this project
    ├── graph.json      ← 167 nodes · 244 edges
    ├── GRAPH_REPORT.md ← god nodes + communities
    └── cache/ast/
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
    "lat_initialized": true,
    "lat_sections": ["architecture", "launch-flow", "proxy", "pii-proxy", "router", "sandbox", "security", "isolation", "oauth"],
    "lat_index_path": "lat.md/lat.md",
    "lat_summary": "iclaude — bash-обёртка для Claude Code: прокси, NVM, OAuth, PII-маскирование, microVM, security-хуки.",
    "graph_initialized": true,
    "graph_fresh": null,
    "graph_god_nodes": ["PIIProxyHandler (20 edges)", "TestShouldRedact (13 edges)", "presidio_mask() (8 edges)"],
    "graph_communities": 8,
    "graph_summary": "Ядро — PIIProxyHandler соединяет HTTP-слой с presidio_mask(). 8 сообществ: HTTP-обработчики, маскирование, тесты паттернов, false-positive тесты."
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

**Used by:**
- `adaptive-workflow` - Selects complexity based on project type
- `lsp-integration` - Determines which LSP server to install
- `validation-framework` - Chooses appropriate validation commands
- `code-review` - Applies language-specific review rules

**Delegates to:**
- `lat-search` - Targeted semantic/locate search over `lat.md/` sections (optional, in-task)
- `graphify-context` - Structural queries over the knowledge graph (god nodes, paths, communities)

**Provides:**
- `language` → Enables language-specific tooling
- `framework` → Enables framework-specific patterns
- `prd_path` → Enables PRD-driven validation
- `syntax_command` → Enables pre-commit syntax checks
- `lat_initialized` / `lat_summary` → Enables doc-graph-aware context without re-checking files
- `graph_initialized` / `graph_summary` → Enables structure-aware context without re-checking files

---

🤖 Generated with Claude Code

**Author:** ikeniborn
**License:** MIT

## Changelog

### 1.3.0 (2026-06-07)
- Заменён мёртвый detect `.wiki/` + `llm-wiki` на `lat.md/` detection (читает корневой индекс `lat.md/lat.md`)
- Поля `wiki_*` → `lat_*` (`lat_initialized`, `lat_sections`, `lat_index_path`, `lat_summary`)
- `graphify` detection дополнен: lat.md = проза, graph = структура
- `lat-search` и `graphify-context` оформлены как delegates; добавлены в dependencies

### 1.2.0 (2026-02-19)

### 1.1.0 (2026-01-25)
- Добавлено: 5 примеров (Python FastAPI, TypeScript React, Go with PRD, Bash, multi-language)
- Обновлены references на @shared:
- Улучшена документация detection алгоритмов

### 1.0.0 (2025-XX-XX)
- Initial release
