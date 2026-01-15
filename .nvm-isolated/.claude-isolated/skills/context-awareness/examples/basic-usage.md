# Basic Usage Example - context-awareness

## Scenario

Автоматическое определение контекста проекта (язык, фреймворк, структура) для адаптации workflow под конкретный тип проекта.

**Use cases:**
- Начало работы с новым проектом
- Автоматический выбор language-specific tools
- Адаптация validation под тип проекта

---

## Input

```json
{
  "project_directory": "/home/user/projects/my-api",
  "scan_depth": "standard"
}
```

---

## Execution

context-awareness skill выполняет следующие шаги:

### Step 1: File Structure Scan
- Scan root directory for config files
- Found: `package.json`, `tsconfig.json`, `Dockerfile`

### Step 2: Language Detection
- Parse `package.json` → TypeScript (dependencies: typescript, @types/node)
- Parse `tsconfig.json` → confirm TypeScript

### Step 3: Framework Detection
- Parse `package.json` scripts
- Found: `"dev": "ts-node src/index.ts"`, `"start": "node dist/index.js"`
- No web framework detected (plain Node.js app)

### Step 4: Tooling Detection
- Found: `Dockerfile` → Docker used
- Found: `.github/workflows/ci.yml` → GitHub Actions CI
- Found: `jest.config.js` → Jest для testing

---

## Output

```json
{
  "project_context": {
    "language": "typescript",
    "runtime": "nodejs",
    "version": {
      "node": "18.20.8",
      "typescript": "5.3.3"
    },
    "framework": "none",
    "type": "backend_api",
    "structure": {
      "src": "src/",
      "tests": "tests/",
      "build": "dist/"
    },
    "tooling": {
      "package_manager": "npm",
      "containerization": "docker",
      "ci_cd": "github_actions",
      "testing": "jest",
      "linting": "eslint"
    },
    "entry_point": "src/index.ts"
  }
}
```

**Console output:**
```
✓ Project context detected:
  - Language: TypeScript 5.3.3
  - Runtime: Node.js 18.20.8
  - Type: Backend API
  - Testing: Jest
  - CI/CD: GitHub Actions

📦 Dependencies analyzed:
  - express: ^4.18.0
  - dotenv: ^16.0.0
  - typescript: ^5.3.3

🔍 Recommended skills:
  - lsp-integration (TypeScript LSP)
  - code-review (enhanced type checking)
  - pr-automation (GitHub CI/CD monitoring)
```

---

## Explanation

### Language Detection Strategies:

**By config files:**
- `package.json` + `tsconfig.json` → TypeScript
- `requirements.txt` + `setup.py` → Python
- `go.mod` → Go
- `Cargo.toml` → Rust
- `pom.xml` / `build.gradle` → Java

**By file extensions:**
- Majority `.ts` files → TypeScript
- Majority `.py` files → Python
- Majority `.go` files → Go

### Framework Detection:

```json
{
  "framework_patterns": {
    "fastapi": ["from fastapi import", "requirements.txt contains fastapi"],
    "django": ["INSTALLED_APPS", "django-admin"],
    "flask": ["from flask import", "app = Flask("],
    "express": ["require('express')", "app.listen("],
    "nextjs": ["next.config.js", "pages/"]
  }
}
```

### Integration with other skills:

**lsp-integration:**
```
IF project_context.language == "typescript":
  Recommend typescript-lsp plugin
  Check vtsls installation
```

**code-review:**
```
IF project_context.framework == "fastapi":
  Add FastAPI-specific checks:
    - Pydantic models validation
    - Async/await correctness
    - Dependency injection patterns
```

**structured-planning:**
```
IF project_context.tooling.testing == "jest":
  Validation steps: "npm test"
ELSE IF project_context.tooling.testing == "pytest":
  Validation steps: "pytest tests/"
```

### Python + FastAPI example:

```json
{
  "project_context": {
    "language": "python",
    "version": {"python": "3.11"},
    "framework": "fastapi",
    "type": "web_api",
    "structure": {
      "src": "app/",
      "tests": "tests/",
      "models": "app/models/"
    },
    "tooling": {
      "package_manager": "pip",
      "testing": "pytest",
      "linting": "ruff"
    },
    "entry_point": "app/main.py"
  }
}
```

---

## Related

- [context-awareness/SKILL.md](../SKILL.md)
- [adaptive-workflow/SKILL.md](../adaptive-workflow/SKILL.md)
- [lsp-integration/SKILL.md](../lsp-integration/SKILL.md)
