---
name: docker-skill
description: Create and manage optimized Docker images with best practices, multi-stage builds, security scanning (hadolint), and Docker Compose generation
version: 1.0.0
tags: [docker, containers, optimization, security, multi-stage, devops, automation, compose]
dependencies: [thinking-framework, validation-framework, context-awareness]
files:
  templates: ./templates/*.json
  schemas: ./schemas/*.schema.json
  examples: ./examples/*.md
  rules: ./rules/*.md
  dockerfile-templates: ./dockerfile-templates/*.Dockerfile
user-invocable: true
changelog:
  - version: 1.0.0
    date: 2026-01-26
    changes:
      - "Initial release"
      - "Interactive mode with AskUserQuestion for language/framework/optimization selection"
      - "Multi-stage build generation for Node.js/TypeScript and Python"
      - "Docker Compose generation for multi-container applications"
      - "hadolint integration for Dockerfile linting and security scanning"
      - "TOON support for vulnerability lists and layer optimization (40-50% token savings)"
      - "Best practices enforcement (10+ rules from Docker official docs + Habr)"
      - "5 operations: create-dockerfile, build-image, scan-image, optimize-layers, cleanup-images"
---

# docker-skill

**Автоматизация создания и управления оптимизированными Docker образами** с интеграцией best practices, multi-stage builds, security scanning (hadolint) и генерацией Docker Compose.

---

## Quick Reference

| Aspect | Details |
|--------|---------|
| **Primary Operations** | create-dockerfile, build-image, scan-image, optimize-layers, cleanup-images |
| **Supported Languages** | Node.js/TypeScript, Python (Go/Rust в v1.1.0) |
| **Input Format** | Interactive (AskUserQuestion) + JSON templates |
| **Output Format** | JSON with dockerfile_path, optimization_results, security_scan, build_info |
| **TOON Support** | hadolint_warnings, layers, violations (если >= 5 элементов) |
| **Dependencies** | thinking-framework (analysis), validation-framework (checks), context-awareness (language detection) |
| **Best Practices** | 10 правил (multi-stage, alpine, non-root, HEALTHCHECK, version pinning, etc.) |
| **Security Tools** | hadolint (Dockerfile linter), regex secrets detection |
| **Artifacts** | Dockerfile, .dockerignore, docker-compose.yml (опционально) |

---

## When to Use

### Auto-Invocation Triggers (Proactive)

Skill **автоматически вызывается** (опционально) если:

1. **Dockerfile отсутствует** в проекте И задача связана с деплоем/контейнеризацией
2. **docker-compose.yml отсутствует** И задача требует multi-container setup
3. **Dockerfile нарушает best practices** (обнаружено в code-review)
4. **Безопасность под вопросом** (Dockerfile использует :latest, root user, содержит secrets)

### Manual Invocation

Пользователь может запустить skill вручную через:
```bash
/docker-skill
```

После вызова будет задано 4-5 интерактивных вопросов для конфигурации.

---

## How It Works

### Workflow: 5 Phases

#### PHASE 1: Context Discovery

**Цель**: Определить язык проекта, фреймворк, структуру

**Actions**:
1. Вызвать `@skill:context-awareness` для определения:
   - Язык проекта (Node.js, Python, Go, Rust)
   - Фреймворк (Express, FastAPI, Django, Next.js)
   - Package manager (npm, yarn, pnpm, pip, poetry)
   - Entry point (package.json "main", main.py, index.ts)
2. Проверить наличие существующего Dockerfile
3. Определить необходимость multi-container setup (наличие БД, Redis, etc.)

**Output**:
```json
{
  "context": {
    "language": "nodejs",
    "framework": "express",
    "package_manager": "npm",
    "entry_point": "dist/index.js",
    "has_dockerfile": false,
    "multi_service_needed": true
  }
}
```

---

#### PHASE 2: Interactive Questionnaire

**Цель**: Собрать пользовательские предпочтения для генерации Dockerfile

**Actions**: Задать 4-5 вопросов через `AskUserQuestion`:

**Q1: Язык проекта**
- **Question**: "Выберите язык проекта для Dockerfile"
- **Options**:
  - `nodejs` - Node.js/TypeScript (multi-stage: deps → builder → runtime)
  - `python` - Python (multi-stage: builder → runtime)
- **Default**: Из context-awareness или первый вариант
- **Header**: "Language"

**Q2: Фреймворк (опционально)**
- **Question**: "Укажите фреймворк (опционально, для оптимизации Dockerfile)"
- **Type**: Text input (optional)
- **Examples**: express, fastapi, django, next.js, nestjs
- **Header**: "Framework"

**Q3: Уровень оптимизации**
- **Question**: "Выберите уровень оптимизации образа"
- **Options**:
  - `minimal` - Только базовые оптимизации (alpine, non-root)
  - `standard` - Рекомендуемый (multi-stage, layer caching, cleanup) **(Recommended)**
  - `aggressive` - Максимальная оптимизация (distroless, BuildKit, cache mounts)
- **Default**: `standard`
- **Header**: "Optimization"

**Q4: Docker Compose**
- **Question**: "Нужен Docker Compose для multi-container setup? (БД, Redis, сервисы)"
- **Options**:
  - `yes` - Создать docker-compose.yml с app + services
  - `no` - Только Dockerfile
- **Default**: Из context (если есть БД в зависимостях)
- **Header**: "Compose"

**Q5: Базовый образ (опционально)**
- **Question**: "Переопределить базовый образ? (по умолчанию: auto-detect для языка)"
- **Type**: Text input (optional)
- **Examples**: node:18-alpine3.18, python:3.11-slim, gcr.io/distroless/nodejs18
- **Header**: "Base Image"

**Output**: Сохранить ответы в `user_preferences` для PHASE 3.

---

#### PHASE 3: Template Generation

**Цель**: Сгенерировать Dockerfile, .dockerignore, docker-compose.yml

**Actions**:

1. **Выбрать Dockerfile template** на основе языка:
   - Node.js → `dockerfile-templates/nodejs.Dockerfile`
   - Python → `dockerfile-templates/python.Dockerfile`

2. **Применить multi-stage pattern** (если optimization_level != minimal):
   - Node.js: 3 стадии (deps, builder, runtime)
   - Python: 2 стадии (builder, runtime)

3. **Кастомизировать template**:
   - Подставить base_image (если override указан)
   - Добавить HEALTHCHECK (если optimization_level >= standard)
   - Добавить USER directive (non-root)
   - Применить version pinning (no :latest)

4. **Сгенерировать .dockerignore**:
   - Node.js: node_modules, .git, .env, *.log, tests/, *.md, .vscode, coverage/
   - Python: __pycache__, *.pyc, .git, .env, *.log, tests/, *.md, .vscode, .pytest_cache

5. **Сгенерировать docker-compose.yml** (если user_preferences.docker_compose = yes):
   - Использовать `templates/docker-compose-template.json`
   - Добавить app service (build: ., ports, environment)
   - Добавить дополнительные services (db, redis) если обнаружены в зависимостях
   - Настроить networks и volumes

6. **Записать файлы**:
   - `./Dockerfile`
   - `./.dockerignore`
   - `./docker-compose.yml` (если compose enabled)

**Output**:
```json
{
  "generation_results": {
    "dockerfile_generated": true,
    "dockerfile_path": "./Dockerfile",
    "dockerignore_path": "./.dockerignore",
    "docker_compose_path": "./docker-compose.yml",
    "base_image": "node:18-alpine3.18",
    "multi_stage": true,
    "stages": [
      {"name": "deps", "base": "node:18-alpine", "purpose": "Production dependencies"},
      {"name": "builder", "base": "node:18-alpine", "purpose": "TypeScript compilation"},
      {"name": "runtime", "base": "node:18-alpine", "purpose": "Final image"}
    ]
  }
}
```

---

#### PHASE 4: Security & Validation

**Цель**: Проверить Dockerfile на соответствие best practices и безопасность

**Actions**:

1. **hadolint scan** (если установлен):
   ```bash
   hadolint Dockerfile --format json
   ```
   - Парсить JSON output
   - Извлечь issues count, warnings list, severity levels

2. **Regex secrets detection**:
   - Сканировать Dockerfile на паттерны:
     - `API_KEY=`, `PASSWORD=`, `SECRET=`, `TOKEN=`
     - `aws_access_key`, `PRIVATE_KEY`, `ssh-rsa`
   - Если найдено → warnings + secrets_detected: true

3. **Best practices validation** (10 правил):
   - ✅ Multi-stage build (если >= 2 FROM)
   - ✅ Minimal base image (alpine, slim, distroless)
   - ✅ Non-root user (есть USER directive)
   - ✅ Layer optimization (RUN с &&)
   - ✅ .dockerignore exists
   - ✅ HEALTHCHECK configured
   - ✅ Version pinning (нет :latest)
   - ✅ Cleanup in RUN (rm cache)
   - ✅ COPY ordering (dependencies first)
   - ✅ No secrets in Dockerfile

4. **Подсчитать best_practices_followed** и **best_practices_violations**

**Output**:
```json
{
  "security_scan": {
    "hadolint_available": true,
    "hadolint_issues": 0,
    "hadolint_warnings": [],
    "non_root_user": true,
    "secrets_detected": false,
    "secrets_patterns": []
  },
  "validation_results": {
    "healthcheck_configured": true,
    "best_practices_followed": 10,
    "best_practices_violations": []
  }
}
```

---

#### PHASE 5: Build & Test (Optional)

**Цель**: Собрать образ, измерить размер, проверить HEALTHCHECK (только для operation=build-image)

**Actions**:

1. **Build Docker image**:
   ```bash
   docker build -t <project_name>:latest .
   ```
   - Засечь build time
   - Получить image ID и size

2. **Test HEALTHCHECK** (если configured):
   ```bash
   docker run -d --name test-<project_name> <project_name>:latest
   docker inspect --format='{{json .State.Health}}' test-<project_name>
   ```
   - Подождать 30-60 секунд
   - Проверить Health.Status = "healthy"
   - Cleanup: `docker rm -f test-<project_name>`

3. **Measure optimization impact**:
   - Сравнить size с базовым образом (e.g., node:18 = 1.1GB vs node:18-alpine = 180MB)
   - Подсчитать layers count
   - Оценить token savings через TOON (если applicable)

**Output**:
```json
{
  "build_info": {
    "build_executed": true,
    "build_success": true,
    "build_time": "45s",
    "image_id": "sha256:abc123...",
    "image_tags": ["myapp:latest"],
    "image_size": "185MB"
  },
  "optimization_results": {
    "layers_after": 12,
    "size_estimate": "185MB (vs 1.1GB with node:18 full image)",
    "size_reduction": "83%",
    "optimizations_applied": [
      "Multi-stage build",
      "Alpine base image",
      "Non-root user",
      "Layer caching",
      "npm cache clean"
    ]
  }
}
```

---

## Output Format

Skill возвращает **JSON структуру** согласно `templates/docker-output.json`:

```json
{
  "docker_operation": {
    "operation": "create-dockerfile | build-image | scan-image | optimize-layers | cleanup-images",
    "status": "success | partial | failed",

    "dockerfile_generated": true,
    "dockerfile_path": "./Dockerfile",
    "dockerignore_path": "./.dockerignore",
    "docker_compose_path": "./docker-compose.yml",

    "base_image": "node:18-alpine3.18",
    "multi_stage": true,
    "stages": [
      {"name": "deps", "base": "node:18-alpine", "purpose": "Production dependencies"},
      {"name": "builder", "base": "node:18-alpine", "purpose": "TypeScript compilation"},
      {"name": "runtime", "base": "node:18-alpine", "purpose": "Final image"}
    ],

    "optimization_results": {
      "layers_before": 0,
      "layers_after": 12,
      "layers_reduced": 0,
      "size_estimate": "185MB (vs 1.1GB full image)",
      "size_reduction": "83%",
      "optimizations_applied": ["Multi-stage build", "Alpine base", "Non-root user", ...]
    },

    "security_scan": {
      "hadolint_available": true,
      "hadolint_issues": 0,
      "hadolint_warnings": [],
      "non_root_user": true,
      "secrets_detected": false,
      "secrets_patterns": []
    },

    "build_info": {
      "build_executed": true,
      "build_success": true,
      "build_time": "45s",
      "image_id": "sha256:abc123...",
      "image_tags": ["myapp:latest"],
      "image_size": "185MB"
    },

    "validation_results": {
      "healthcheck_configured": true,
      "best_practices_followed": 10,
      "best_practices_violations": []
    },

    "next_steps": [
      "Review Dockerfile and docker-compose.yml",
      "Build image: docker-compose build",
      "Test locally: docker-compose up",
      "Push to registry: docker-compose push"
    ],

    "toon": {
      "hadolint_warnings_toon": "hadolint_warnings[5]{rule,severity,message,line}:\n  ...",
      "layers_toon": "layers[12]{instruction,size,cached}:\n  ...",
      "token_savings": "45%"
    }
  }
}
```

**TOON Support**: Применяется если >= 5 элементов в:
- `hadolint_warnings[]` - 40-50% token savings для списка предупреждений
- `stages[]` (в optimize-layers) - для анализа слоев
- `best_practices_violations[]` - для списка нарушений

---

## Operations

### 1. create-dockerfile

**Описание**: Генерация Dockerfile с multi-stage builds, .dockerignore, docker-compose.yml

**Phases**: 1-4 (Context → Interactive → Generation → Validation)

**Input**:
- `operation: "create-dockerfile"`
- Interactive questions (Q1-Q5)

**Output**:
- `Dockerfile` (multi-stage, optimized)
- `.dockerignore` (language-specific)
- `docker-compose.yml` (if requested)
- JSON output with paths, security_scan, validation_results

**Use Case**: Начальная контейнеризация проекта

---

### 2. build-image

**Описание**: Генерация + сборка Docker образа с измерением размера и тестированием

**Phases**: 1-5 (All phases including Build & Test)

**Input**:
- `operation: "build-image"`
- Interactive questions (Q1-Q5)

**Output**:
- Все артефакты из `create-dockerfile`
- `build_info` с image_id, size, build_time
- HEALTHCHECK test results

**Use Case**: Полный цикл - генерация + проверка работоспособности

---

### 3. scan-image

**Описание**: Только security scanning существующего Dockerfile (без генерации)

**Phases**: 4 only (Security & Validation)

**Input**:
- `operation: "scan-image"`
- Path to existing Dockerfile (default: ./Dockerfile)

**Output**:
- `security_scan` с hadolint results
- `validation_results` с best practices check

**Use Case**: Аудит существующего Dockerfile

---

### 4. optimize-layers

**Описание**: Анализ существующего Dockerfile + рекомендации по оптимизации

**Phases**: 1, 4 (Context + Validation) + custom optimization analysis

**Input**:
- `operation: "optimize-layers"`
- Path to existing Dockerfile

**Output**:
- `optimization_results` с layers_before, layers_after, optimizations_applied
- Rewritten Dockerfile (если пользователь подтвердит)

**Use Case**: Улучшение существующего Dockerfile

---

### 5. cleanup-images

**Описание**: Docker system cleanup с подтверждением

**Actions**:
1. Показать текущий disk usage: `docker system df`
2. Спросить подтверждение через AskUserQuestion
3. Выполнить: `docker system prune -a --volumes`
4. Показать освобожденное место

**Input**:
- `operation: "cleanup-images"`

**Output**:
- JSON с disk_space_freed, images_removed, volumes_removed

**Use Case**: Очистка неиспользуемых образов/контейнеров

---

## Best Practices (10 Rules)

Skill автоматически применяет best practices из **Docker Official Docs** + **Habr статья**:

### 1. Multi-Stage Builds

**Правило**: Использовать multi-stage builds для compiled languages (TypeScript, Python с build deps)

**Benefit**: Уменьшает размер образа на 60-80%

**Enforcement**: Skill auto-generates multi-stage для nodejs, python

**Example**:
```dockerfile
FROM node:18 AS builder
RUN npm run build

FROM node:18-alpine
COPY --from=builder /app/dist ./dist
```

---

### 2. Minimal Base Images

**Правило**: Предпочитать alpine, distroless, или scratch-based images

**Comparison**:
- node:18 = 1.1GB
- node:18-alpine = 180MB
- gcr.io/distroless/nodejs18 = 120MB

**Enforcement**: Skill defaults to alpine для nodejs/python

---

### 3. Non-Root User

**Правило**: Всегда запускать контейнер от non-root user

**Enforcement**: Skill adds USER directive automatically

**Example**:
```dockerfile
RUN adduser -D appuser
USER appuser
```

---

### 4. Layer Optimization

**Правило**: Объединять RUN команды через && для уменьшения слоев

**Bad**:
```dockerfile
RUN apt-get update
RUN apt-get install -y curl
RUN rm -rf /var/lib/apt/lists/*
```

**Good**:
```dockerfile
RUN apt-get update && \
    apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*
```

**Enforcement**: Skill templates follow this pattern

---

### 5. .dockerignore

**Правило**: Создать .dockerignore для исключения ненужных файлов

**Standard exclusions**:
```
node_modules
.git
.env
*.log
tests/
*.md
.vscode
```

**Enforcement**: Skill auto-generates .dockerignore

---

### 6. HEALTHCHECK

**Правило**: Добавить HEALTHCHECK для мониторинга контейнера

**Enforcement**: Skill adds HEALTHCHECK by default (configurable)

**Example**:
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

---

### 7. Version Pinning

**Правило**: Никогда не использовать :latest, пиннить конкретные версии

**Bad**: `FROM node:latest`
**Good**: `FROM node:18.20.0-alpine3.18`

**Enforcement**: Skill uses specific versions in templates

---

### 8. Cleanup in RUN

**Правило**: Удалять кэш package manager в той же RUN команде

**Enforcement**: Skill templates include cleanup

**Example**:
```dockerfile
RUN apt-get update && \
    apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*
```

---

### 9. COPY Ordering

**Правило**: Копировать dependencies (package.json) перед кодом для лучшего кэширования

**Good**:
```dockerfile
COPY package*.json ./
RUN npm ci
COPY . .
```

**Enforcement**: Skill templates follow this order

---

### 10. No Secrets in Dockerfile

**Правило**: Никогда не хардкодить secrets, использовать ENV или Docker secrets

**Detection**: Skill scans for patterns:
- API_KEY=
- PASSWORD=
- SECRET=
- TOKEN=
- aws_access_key

**Enforcement**: Skill warns if secrets detected

---

## Examples

See `examples/` directory for detailed walkthroughs:

- **@example:create-nodejs-app.md** - Create optimized Dockerfile for Express.js TypeScript app with Docker Compose
- **@example:optimize-existing-dockerfile.md** - Optimize existing Python Dockerfile (reduce from 1.2GB to 250MB)
- **@example:scan-security.md** - Scan Dockerfile with hadolint and detect secrets

---

## Workflow Integration

### Dependencies

Skill зависит от:
- **@skill:thinking-framework** - Analysis and reasoning (PHASE 1)
- **@skill:validation-framework** - Acceptance criteria validation (PHASE 4)
- **@skill:context-awareness** - Project language/framework detection (PHASE 1)

### Output Consumers

Выходные данные могут использоваться в:
- **@skill:code-review** - Dockerfile review с best practices check
- **@skill:validation-framework** - Проверка docker build success
- **CI/CD pipelines** - Автоматическая сборка образов

### Workflow Position

```
context-awareness → docker-skill → validation-framework → git-workflow
                         ↓
                    (Dockerfile generated + tested)
```

---

## References

### External Documentation
- **Docker Best Practices**: https://docs.docker.com/build/building/best-practices/
- **Habr статья**: https://habr.com/ru/companies/domclick/articles/546922/
- **hadolint**: https://github.com/hadolint/hadolint
- **Multi-stage builds**: https://docs.docker.com/build/building/multi-stage/
- **Docker Compose**: https://docs.docker.com/compose/

### Internal Skills
- **@skill:thinking-framework** - Structured reasoning
- **@skill:validation-framework** - Validation and acceptance criteria
- **@skill:context-awareness** - Project detection
- **@skill:toon-skill** - Token-efficient output formatting

### Shared Resources
- **@shared:TOON-REFERENCE.md** - TOON format specification
- **@shared:WORKFLOW-SKILLS-UNIVERSAL.md** - Universal workflow (PHASE 0-5)
- **@shared:GIT-CONVENTIONS.md** - Git commit conventions

### Templates
- **@template:docker-input.json** - Input structure for operations
- **@template:docker-output.json** - Output structure with all results
- **@template:docker-compose-template.json** - Multi-container setup template

### Dockerfile Templates
- **@dockerfile-template:nodejs.Dockerfile** - Node.js multi-stage (3 stages)
- **@dockerfile-template:python.Dockerfile** - Python multi-stage (2 stages)

### Rules
- **@rules:best-practices.md** - 10 Docker best practices with enforcement

---

## Version History

**v1.0.0** (2026-01-26):
- ✅ Initial release with interactive mode
- ✅ Node.js/TypeScript and Python support
- ✅ Multi-stage builds (3-stage nodejs, 2-stage python)
- ✅ Docker Compose generation
- ✅ hadolint integration for security scanning
- ✅ TOON support for vulnerability lists (40-50% token savings)
- ✅ 10 best practices enforcement
- ✅ 5 operations: create-dockerfile, build-image, scan-image, optimize-layers, cleanup-images

**Future Enhancements** (v1.1.0+):
- ✨ Go/Rust templates - scratch-based minimal images (<10MB)
- ✨ trivy integration - CVE vulnerability scanning
- ✨ docker scout - official Docker security tool
- ✨ Automatic optimization - analyze + suggest improvements with diff
- ✨ Registry operations - push to Docker Hub, ECR, GCR
- ✨ BuildKit features - cache mounts, secrets, SSH forwarding
- ✨ Kubernetes manifests - generate Deployment, Service, Ingress

---

**Status**: ✅ Ready for use
**Maintainer**: iclaude project
**License**: MIT
