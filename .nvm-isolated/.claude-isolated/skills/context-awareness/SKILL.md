---
name: context-awareness
description: Автоматическое определение контекста проекта. Поиск по документации.
user-invocable: false
agent: Explore
# version: 1.2.0
# tags: context, detection, project, language, framework
# dependencies: []
# files: templates: ./templates/*.json, shared: ../_shared/syntax-commands.json
---

# Context Awareness

Автоматическое определение языка, framework, наличия PRD и других характеристик проекта.

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

### 5. Wiki Detection

```
Проверить наличие wiki в корне проекта:

IF exists {CWD}/.wiki/.config/domain-map.json:
  1. Прочитать {CWD}/.wiki/.config/domain-map.json
     → извлечь список domains[].id
  2. Прочитать {CWD}/.wiki/.config/index.md
     → получить перечень документированных страниц
  3. Skill(skill="llm-wiki", args='query "ключевые компоненты и архитектура проекта"')
     → добавить синтезированный контекст как wiki_summary
  4. Добавить в project_context:
       wiki_initialized: true
       wiki_domains: [список id из domain-map]
       wiki_index_path: ".wiki/.config/index.md"
       wiki_summary: <результат query или null если wiki пустая>

ELSE:
  wiki_initialized: false
  wiki_domains: []
  wiki_index_path: null
  wiki_summary: null
```

**Назначение:** Централизует проверку доступности wiki — downstream-навыки используют
`project_context.wiki_initialized` вместо самостоятельной проверки файла.

### 6. Graph Detection

```
Проверить наличие knowledge graph в корне проекта:

Сначала resolve выходную директорию: GOUT=$(echo "${GRAPHIFY_OUT:-graphify-out}")

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
Дополняет wiki: wiki даёт синтезированную прозу, граф — структурные связи.

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
    "wiki_initialized": true|false,
    "wiki_domains": ["domain-id-1", "domain-id-2"],
    "wiki_index_path": ".wiki/.config/index.md" | null,
    "wiki_summary": "синтезированный контекст из wiki" | null,
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

### Example 4: Bash Script Project — без wiki

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
    "wiki_domains": [],
    "wiki_index_path": null,
    "wiki_summary": null
  }
}
```

---

### Example 4b: Bash Script Project — с инициализированной wiki

**Project structure:**
```
/home/user/iclaude/
├── iclaude.sh
├── lib/
│   └── proxy/...
├── docs/
│   ├── PROXY.md
│   └── ROUTER.md
└── .wiki/
    └── .config/
        ├── domain-map.json   ← домен "iclaude"
        └── index.md          ← 12 документированных страниц
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
    "wiki_domains": ["iclaude"],
    "wiki_index_path": ".wiki/.config/index.md",
    "wiki_summary": "iclaude — bash-обёртка для Claude Code: прокси-менеджмент, изолированная среда NVM, OAuth-обновление токенов, PII-маскирование. Ключевые компоненты: proxy-mgmt, oauth-handler, pii-proxy, router-integration."
  }
}
```

---

### Example 4c: Bash Script Project — с wiki и knowledge graph

**Project structure:**
```
/home/user/iclaude/
├── iclaude.sh
├── lib/
├── docs/
├── .wiki/
│   └── .config/
│       ├── domain-map.json   ← домен "iclaude"
│       └── index.md
└── .graphify/
    ├── graph.json            ← 167 nodes · 244 edges
    ├── GRAPH_REPORT.md       ← god nodes + communities
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
    "wiki_initialized": true,
    "wiki_domains": ["iclaude"],
    "wiki_index_path": ".wiki/.config/index.md",
    "wiki_summary": "iclaude — bash-обёртка для Claude Code: прокси-менеджмент, NVM, OAuth, PII-маскирование.",
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

**Provides:**
- `language` → Enables language-specific tooling
- `framework` → Enables framework-specific patterns
- `prd_path` → Enables PRD-driven validation
- `syntax_command` → Enables pre-commit syntax checks
- `docs_llms_path` → Enables automatic project documentation loading

---

🤖 Generated with Claude Code

**Author:** ikeniborn
**License:** MIT

## Changelog

### 1.2.0 (2026-02-19)

### 1.1.0 (2026-01-25)
- Добавлено: 5 примеров (Python FastAPI, TypeScript React, Go with PRD, Bash, multi-language)
- Обновлены references на @shared:
- Улучшена документация detection алгоритмов

### 1.0.0 (2025-XX-XX)
- Initial release
