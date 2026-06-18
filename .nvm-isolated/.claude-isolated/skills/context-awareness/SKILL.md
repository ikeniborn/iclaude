---
name: context-awareness
description: Detect project language, framework, package manager, lint/test commands and locate CLAUDE.md / PRD docs at task start (Phase 0). Also detects the docs/wiki/ iwiki documentation graph, surfacing its summary as project context. Use when starting any task, switching project, or before running syntax/test checks. NOT for deep semantic doc search (iwiki-query) — this skill only detects availability + a quick summary.
user-invocable: false
agent: Explore
# version: 1.4.0
# tags: context, detection, project, language, framework, lat
# dependencies: [iwiki:iwiki-query]
# files: templates: ./templates/*.json, shared: ../_shared/syntax-commands.json
---

# Context Awareness

Автоматическое определение языка, framework, наличия PRD и документационного графа `docs/wiki/` в проекте.

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

### 5. iwiki Detection

Документационный граф `docs/wiki/` — embedding-граф страниц, описывающих архитектуру,
дизайн-решения и ключевые компоненты. Единственный источник документационного контекста проекта.

```
IF exists {CWD}/docs/wiki/ (директория с .md-файлами):
  1. Прочитать {CWD}/docs/wiki/index.md (корневой индекс)
     → извлечь синтезированный обзор проекта (leading paragraph)
     → извлечь список страниц из индекса
  2. (опционально, если нужен более точный обзор)
     Skill(skill="iwiki:iwiki-query", args='ключевые компоненты и архитектура проекта')
     → использовать результат как wiki_summary вместо корневого индекса
  3. Добавить в project_context:
       wiki_initialized: true
       wiki_index_path: "docs/wiki/index.md"
       wiki_summary: <обзор из корневого индекса или результат iwiki-query>

ELSE:
  wiki_initialized: false
  wiki_index_path: null
  wiki_summary: null
```

**Назначение:** Централизует проверку доступности документационного графа —
downstream-навыки (brainstorming, prd-generator) используют
`project_context.wiki_initialized` вместо самостоятельной проверки файла.
Корневой индекс `docs/wiki/index.md` читается напрямую (дёшево);
`iwiki:iwiki-query` — опциональный семантический поиск по секциям внутри задачи.

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
    "wiki_index_path": "docs/wiki/index.md" | null,
    "wiki_summary": "синтезированный обзор из docs/wiki" | null
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

### Example 4: Bash Script Project — без docs/wiki

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
    "wiki_index_path": null,
    "wiki_summary": null
  }
}
```

---

### Example 4b: Bash Script Project — с инициализированной docs/wiki

**Project structure:**
```
/home/user/iclaude/
├── iclaude.sh
├── lib/
│   └── proxy/...
└── docs/
    ├── PROXY.md
    ├── ROUTER.md
    └── wiki/
        ├── index.md    ← корневой индекс
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
    "wiki_initialized": true,
    "wiki_index_path": "docs/wiki/index.md",
    "wiki_summary": "iclaude — bash-обёртка для Claude Code: HTTP/HTTPS-прокси, изолированная NVM-среда, OAuth-обновление токенов, Claude Code Router, PII-прокси (Presidio), microVM-песочница, security-хуки."
  }
}
```

---

### Example 4c: Bash Script Project — с docs/wiki

**Project structure:**
```
/home/user/iclaude/
├── iclaude.sh
├── lib/
├── docs/
│   └── wiki/
│       ├── index.md    ← корневой индекс
│       ├── architecture.md
│       └── pii-proxy.md
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
    "wiki_index_path": "docs/wiki/index.md",
    "wiki_summary": "iclaude — bash-обёртка для Claude Code: прокси, NVM, OAuth, PII-маскирование, microVM, security-хуки."
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
- `iwiki:iwiki-query` - Targeted semantic search over `docs/wiki/` pages (optional, in-task)

**Provides:**
- `language` → Enables language-specific tooling
- `framework` → Enables framework-specific patterns
- `prd_path` → Enables PRD-driven validation
- `syntax_command` → Enables pre-commit syntax checks
- `wiki_initialized` / `wiki_summary` → Enables doc-graph-aware context without re-checking files

---

🤖 Generated with Claude Code

**Author:** ikeniborn
**License:** MIT

## Changelog

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
