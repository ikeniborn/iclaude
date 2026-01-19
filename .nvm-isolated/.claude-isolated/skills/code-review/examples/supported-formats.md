# Supported Architecture Formats

Адаптивный парсер code-review skill поддерживает множество форматов архитектурной документации. Формат автоматически определяется при парсинге.

---

## Format 1: iclaude Schema (Native)

**Приоритет:** Highest (рекомендуемый формат)

**Расширения:** `.yaml`, `.yml`, `.json`

**Структура:**

```yaml
# docs/architecture/overview.yaml
project:
  id: my-project
  name: My Project
  description: Project description

layers:
  - id: cli
    name: CLI Layer
    description: Command-line interface layer
  - id: core
    name: Core Layer
    description: Business logic layer
  - id: infrastructure
    name: Infrastructure Layer
    description: Low-level utilities

components:
  - id: main-component
    name: Main Component
    description: Entry point for the application
    layer: cli
    type: module
    file_path: src/main.sh:1-100
    dependencies:
      - component_id: core-service
        type: required
        description: Core business logic

  - id: core-service
    name: Core Service
    layer: core
    type: service
    file_path: src/core/service.sh:200-350
    dependencies:
      - component_id: database-client
        type: required

  - id: database-client
    name: Database Client
    layer: infrastructure
    type: client
    file_path: src/infra/db.sh:10-150
    dependencies: []
```

**Обязательные поля:**
- `project.id` - уникальный идентификатор проекта
- `components[]` - массив компонентов
- `components[].id` - уникальный ID компонента
- `components[].dependencies[]` - зависимости (может быть пустым)
- `layers[]` - определение слоев архитектуры

**Опциональные поля:**
- `components[].file_path` - путь к файлу (для Component Validation)
- `components[].layer` - принадлежность к слою (для Layer Boundary checks)
- `dependencies[].type` - тип зависимости (required, optional, etc.)

**Автоопределение:**
- Проверка наличия `project.id`, `components[]`, `layers[]`

**Нормализация:** Нет необходимости (уже в целевом формате)

---

## Format 2: Generic Schema (Minimal)

**Приоритет:** Medium

**Расширения:** `.json`, `.yaml`, `.yml`

**Структура:**

```json
// docs/architecture/architecture.json
{
  "components": [
    {
      "id": "service-a",
      "name": "Service A",
      "dependencies": ["service-b", "service-c"]
    },
    {
      "id": "service-b",
      "name": "Service B",
      "dependencies": []
    },
    {
      "id": "service-c",
      "name": "Service C",
      "dependencies": ["service-b"]
    }
  ]
}
```

**Обязательные поля:**
- `components[]` - массив компонентов
- `components[].id` - уникальный ID
- `components[].dependencies` - массив ID зависимостей (может быть пустым)

**Опциональные поля:**
- `layers[]` - слои (если отсутствует, Layer Boundary checks пропускаются)
- `components[].file_path` - путь к файлу

**Автоопределение:**
- Проверка наличия `components[]` без других признаков iclaude/C4/ADR

**Нормализация:**
```javascript
{
  components: input.components,
  layers: input.layers || [],
  layer_levels: input.layer_levels || {}
}
```

---

## Format 3: C4 Model

**Приоритет:** High

**Расширения:** `.yaml`, `.yml`, `.json`

**Структура:**

```yaml
# docs/architecture/c4-model.yaml
model:
  softwareSystems:
    - id: api-system
      name: API System
      description: Main API service
      containers:
        - id: web-api
          name: Web API
          technology: Node.js
          file_path: src/api/server.ts:1-500

        - id: background-worker
          name: Background Worker
          technology: Python
          file_path: src/worker/main.py:1-300

  relationships:
    - source: web-api
      destination: database
      description: Reads from and writes to
      technology: PostgreSQL

    - source: background-worker
      destination: web-api
      description: Triggers API endpoints
```

**Обязательные поля (C4):**
- `model.softwareSystems[]` ИЛИ `model.containers[]`
- `relationships[]` - связи между компонентами

**Автоопределение:**
- Проверка наличия `model.softwareSystems`, `model.containers`, или `model.people`

**Нормализация в iclaude формат:**

```javascript
// softwareSystems → components (layer: "system")
// containers → components (layer: "container")
// relationships → dependencies

{
  components: [
    ...model.softwareSystems.map(sys => ({
      id: sys.id,
      name: sys.name,
      layer: "system",
      type: "system",
      file_path: sys.file_path || "",
      dependencies: relationships
        .filter(r => r.source === sys.id)
        .map(r => ({ component_id: r.destination, type: "required" }))
    })),
    ...model.containers.map(container => ({
      id: container.id,
      name: container.name,
      layer: "container",
      type: "container",
      file_path: container.file_path || "",
      dependencies: relationships
        .filter(r => r.source === container.id)
        .map(r => ({ component_id: r.destination, type: "required" }))
    }))
  ],
  layers: [
    { id: "system", name: "System Layer" },
    { id: "container", name: "Container Layer" }
  ],
  layer_levels: {
    "system": 1,
    "container": 2
  }
}
```

---

## Format 4: Markdown with Frontmatter

**Приоритет:** Low (fallback)

**Расширения:** `.md`

**Структура:**

```markdown
---
components:
  - id: auth-service
    name: Authentication Service
    layer: core
    file_path: src/auth/service.ts:1-200
    dependencies:
      - component_id: database
      - component_id: cache

  - id: database
    name: Database Client
    layer: infrastructure
    file_path: src/db/client.ts:1-150
    dependencies: []

  - id: cache
    name: Redis Cache
    layer: infrastructure
    file_path: src/cache/redis.ts:1-100
    dependencies: []

layers:
  - id: core
  - id: infrastructure
---

# Architecture Documentation

## Components

### Auth Service
Handles user authentication and authorization...

### Database
PostgreSQL client wrapper...
```

**Обязательные поля (YAML frontmatter):**
- `components[]` - массив компонентов (в frontmatter)
- Frontmatter должен начинаться с `---` и заканчиваться `---`

**Автоопределение:**
- Проверка расширения `.md`
- Извлечение YAML frontmatter между `---`

**Нормализация:**
- Извлечение frontmatter → конвертация YAML → JSON
- Парсинг как Generic Schema

---

## Format 5: ADR (Architecture Decision Records)

**Приоритет:** Low (информационный формат)

**Расширения:** `.json`, `.yaml`, `.yml`

**Структура:**

```yaml
# docs/architecture/adr-001.yaml
decision:
  id: adr-001
  title: Use microservices architecture
  status: accepted
  date: 2024-01-15

context: >
  We need to scale individual services independently

decision: >
  Adopt microservices architecture with HTTP/gRPC communication

consequences:
  - Improved scalability
  - Increased operational complexity
  - Need for service discovery

components_affected:
  - api-gateway
  - user-service
  - payment-service
```

**Автоопределение:**
- Проверка наличия `decision`, `status`, `context`

**Нормализация:**
- ADR формат НЕ подходит для dependency validation
- Возвращает `{"error": "ADR format not suitable for dependency checks"}`
- Рекомендует использовать iclaude или C4 формат

---

## Priority Order

При наличии нескольких файлов парсер проверяет в порядке приоритета:

1. **iclaude schema** (overview.yaml, architecture.yaml) → Полная поддержка всех проверок
2. **C4 model** (c4-model.yaml) → Поддержка после нормализации
3. **Generic schema** (components.json) → Минимальная поддержка
4. **Markdown frontmatter** (ARCHITECTURE.md) → Fallback
5. **ADR** → Не поддерживается для validation

---

## File Search Locations

Парсер ищет файлы в следующих директориях (в порядке):

1. `docs/architecture/`
2. `docs/arch/`
3. `architecture/`
4. `.arch/`
5. `docs/`

**Поддерживаемые имена файлов:**
- `overview.yaml` / `overview.yml` (iclaude)
- `architecture.yaml` / `architecture.yml` (generic)
- `architecture.json` (generic/iclaude)
- `components.json` (generic)
- `c4-model.yaml` / `c4-model.yml` (C4)
- `ARCHITECTURE.md` / `architecture.md` (markdown)

---

## Converter Tools

### YAML → JSON

**Приоритет конверторов:**

1. **yq** (рекомендуется)
   ```bash
   npm install -g yq
   yq eval -o=json overview.yaml
   ```

2. **Python PyYAML** (fallback)
   ```bash
   pip install PyYAML
   python3 -c "import yaml, json; print(json.dumps(yaml.safe_load(open('overview.yaml'))))"
   ```

### Markdown Frontmatter → YAML

**Встроенная функция:**
```bash
# Извлекает YAML между --- и ---
awk '/^---$/{flag=!flag;next}flag' ARCHITECTURE.md
```

---

## Validation Coverage by Format

| Feature | iclaude | C4 | Generic | Markdown | ADR |
|---------|---------|----|---------|---------|----|
| Referential Integrity | ✅ | ✅ | ✅ | ✅ | ❌ |
| Circular Dependencies | ✅ | ✅ | ✅ | ✅ | ❌ |
| Layer Boundaries | ✅ | ⚠️ | ⚠️ | ⚠️ | ❌ |
| Component Validation | ✅ | ✅ | ⚠️ | ⚠️ | ❌ |
| Auto-generation fallback | ✅ | ✅ | ✅ | ✅ | ✅ |

**Легенда:**
- ✅ Полная поддержка
- ⚠️ Частичная поддержка (зависит от наличия опциональных полей)
- ❌ Не поддерживается

---

## Migration Guide

### От Generic к iclaude Schema

```bash
# Исходный generic format
{
  "components": [
    {"id": "a", "dependencies": ["b"]},
    {"id": "b", "dependencies": []}
  ]
}

# Миграция в iclaude format
{
  "project": {
    "id": "my-project",
    "name": "My Project"
  },
  "layers": [
    {"id": "default", "name": "Default Layer"}
  ],
  "components": [
    {
      "id": "a",
      "name": "Component A",
      "layer": "default",
      "type": "module",
      "file_path": "src/a.sh:1-100",
      "dependencies": [
        {"component_id": "b", "type": "required"}
      ]
    },
    {
      "id": "b",
      "name": "Component B",
      "layer": "default",
      "type": "module",
      "file_path": "src/b.sh:1-50",
      "dependencies": []
    }
  ]
}
```

### От C4 к iclaude Schema

**Используйте встроенный конвертор:**
```bash
source lib/adaptive-architecture-parser.sh
convert_c4_to_normalized "$(cat c4-model.yaml | yq eval -o=json)"
```

---

## Custom Format Support

Если ваш формат не распознается автоматически:

**Option 1:** Добавить schema detection в `lib/schema-detector.sh`

```bash
# Добавить в detect_schema_type()
if echo "$json_content" | jq -e '.myCustomField' &>/dev/null; then
  echo "mycustom"
  return 0
fi
```

**Option 2:** Конвертировать в iclaude формат вручную

```bash
# Написать скрипт конвертации
./convert-to-iclaude.sh custom-format.yaml > docs/architecture/overview.yaml
```

**Option 3:** Запустить architecture-documentation skill

```bash
# Автоматическая генерация из кода
@skill:architecture-documentation --generate
```

---

## Troubleshooting

### Ошибка: "Unknown schema"

```json
{
  "available": false,
  "reason": "unknown_schema",
  "action": "generate"
}
```

**Решение:**
1. Проверить структуру файла (должен содержать `components[]`)
2. Добавить обязательные поля (id, dependencies)
3. Запустить `@skill:architecture-documentation --generate`

### Ошибка: "No YAML parser available"

```bash
{"error": "No YAML parser available (install yq or Python PyYAML)"}
```

**Решение:**
```bash
# Option 1: yq (рекомендуется)
npm install -g yq

# Option 2: Python PyYAML
pip install PyYAML
```

### Ошибка: "No architecture files found"

```json
{
  "available": false,
  "reason": "no_architecture_files",
  "action": "generate"
}
```

**Решение:**
1. Создать `docs/architecture/overview.yaml`
2. Запустить `@skill:architecture-documentation --generate`

---

## Recommended Format

**Для новых проектов:** iclaude schema (overview.yaml)

**Преимущества:**
- Полная поддержка всех проверок
- Нативный формат для code-review
- Поддержка слоев и типов зависимостей
- Автоматическая генерация через architecture-documentation skill

**Template:**

```yaml
# docs/architecture/overview.yaml
project:
  id: ${PROJECT_NAME}
  name: ${PROJECT_TITLE}
  description: ${PROJECT_DESC}

layers:
  - id: cli
    name: CLI Layer
  - id: core
    name: Core Layer
  - id: infrastructure
    name: Infrastructure Layer

components:
  - id: ${COMPONENT_ID}
    name: ${COMPONENT_NAME}
    description: ${COMPONENT_DESC}
    layer: ${LAYER_ID}
    type: module
    file_path: ${FILE}:${START_LINE}-${END_LINE}
    dependencies:
      - component_id: ${DEP_ID}
        type: required
```
