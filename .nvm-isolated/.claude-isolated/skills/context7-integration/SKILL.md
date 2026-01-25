---
name: Context7 Integration
description: Автоматическая загрузка документации библиотек через Context7 MCP плагин
version: 1.1.0
tags: [context7, documentation, libraries, mcp, api-docs]
dependencies: [context-awareness]
files:
  templates: ./templates/*.json
  schemas: ./schemas/*.json
  examples: ./examples/*.md
  shared: ../_shared/library-priority.json
user-invocable: false
changelog:
  - version: 1.1.0
    date: 2026-01-25
    changes:
      - "Добавлено: 3 примера (Plugin Not Available, Budget Exhausted, Version-Specific Query)"
      - "Обновлены references на @shared:"
      - "Улучшена документация error handling"
---

# Context7 Integration

Автоматическая загрузка документации библиотек через Context7 MCP плагин во время PHASE 0 workflow.

## Когда использовать

- **Автоматически** в начале КАЖДОЙ задачи (PHASE 0)
- После `@skill:context-awareness` и `@skill:lsp-integration`
- Когда обнаружены зависимости в манифестах (package.json, requirements.txt, и т.д.)
- Перед началом планирования (до `@skill:structured-planning`)

**Auto-trigger:** Всегда активируется после lsp-integration в PHASE 0.

**Условия активации:**
- Context7 MCP plugin установлен и доступен
- Обнаружены манифесты с зависимостями
- Не блокирует workflow при недоступности плагина

## Алгоритм работы

### Обзор (5 фаз)

```
PHASE 0: Plugin Check
├─ Проверка доступности Context7 MCP
└─ Если недоступен → return PLUGIN_NOT_AVAILABLE

PHASE 1: Library Detection
├─ Чтение манифестов (package.json, requirements.txt, go.mod, Cargo.toml)
├─ Извлечение имен библиотек
├─ Разделение prod/dev dependencies
└─ Если нет библиотек → return NO_LIBRARIES_DETECTED

PHASE 2: Budget Initialization
├─ Инициализация: max_calls=3, calls_used=0
└─ Создание структуры отслеживания

PHASE 3: Library Prioritization
├─ Scoring algorithm: framework(10) + keywords(5) + common(3) + prod(2)
├─ Сортировка по убыванию score
└─ Выбор top 3 библиотек

PHASE 4: Context7 Query Loop
├─ Для каждой библиотеки в priority:
│   ├─ resolve-library-id() → calls_used++
│   ├─ Если найден → query-docs() → calls_used++
│   ├─ Если calls_remaining == 0 → break
│   └─ Если calls_remaining == 1 → warning
└─ Return результаты

PHASE 5: Output Generation
└─ Генерация JSON по схеме @schema:context7-output
```

## Plugin Availability Detection

**Метод 1: Попытка тестового вызова (рекомендуется)**

```javascript
try {
  // Попытка вызова Context7 функции
  await mcp__plugin_context7_context7__resolve_library_id({
    libraryName: "test",
    query: "test query"
  });
  plugin_available = true;
} catch (error) {
  if (error.message.includes("function not found") ||
      error.message.includes("tool not found")) {
    plugin_available = false;
    return {
      library_docs: {
        budget_status: {calls_used: 0, calls_remaining: 0, exhausted: false},
        libraries: [],
        skipped_libraries: [],
        status: "PLUGIN_NOT_AVAILABLE"
      }
    };
  }
  // Другие ошибки - пробрасываем дальше
  throw error;
}
```

**Метод 2: Проверка списка MCP серверов (если API доступен)**

```bash
# Если есть API для получения списка активных MCP серверов
list_mcp_servers() | grep -q "context7"
```

**Важно:** При недоступности плагина:
- Немедленно вернуть `PLUGIN_NOT_AVAILABLE`
- НЕ блокировать workflow
- Показать информационное сообщение пользователю
- Продолжить к следующей skill (adaptive-workflow)

## Library Detection Patterns

### JavaScript/TypeScript (package.json)

**Production dependencies:**
```bash
jq -r '.dependencies | keys[]' package.json
```

**Development dependencies:**
```bash
jq -r '.devDependencies | keys[]' package.json
```

**Пример вывода:**
```
react
express
next
axios
```

### Python (requirements.txt)

**Парсинг requirements.txt:**
```bash
grep -E '^[a-zA-Z0-9_-]+' requirements.txt | sed 's/[=<>].*//'
```

**Пример файла:**
```
fastapi==0.104.1
pytest>=7.4.0
pydantic~=2.5.0
```

**Вывод:**
```
fastapi
pytest
pydantic
```

### Python (pyproject.toml)

**Парсинг зависимостей:**
```bash
# Для dependencies
grep -A 100 '^\[project.dependencies\]' pyproject.toml | \
  grep -E '^\s*"[^"]+"' | \
  sed 's/"//g; s/,$//' | \
  awk '{print $1}'
```

**Пример:**
```toml
[project.dependencies]
fastapi = "^0.104.1"
pytest = ">=7.4.0"
```

### Go (go.mod)

**Парсинг зависимостей:**
```bash
grep -E '^\s+[a-z]' go.mod | awk '{print $1}'
```

**Пример файла:**
```
module github.com/user/project

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/stretchr/testify v1.8.4
)
```

**Вывод:**
```
github.com/gin-gonic/gin
github.com/stretchr/testify
```

### Rust (Cargo.toml)

**Парсинг зависимостей:**
```bash
grep -E '^\[dependencies\]' -A 100 Cargo.toml | \
  grep -E '^[a-zA-Z]' | \
  awk -F'=' '{print $1}' | \
  tr -d ' '
```

**Пример файла:**
```toml
[dependencies]
tokio = { version = "1.0", features = ["full"] }
serde = "1.0"
actix-web = "4.4"
```

**Вывод:**
```
tokio
serde
actix-web
```

## Prioritization Algorithm

### Scoring System

**Формула оценки:**
```
score = 0
if library == project_context.framework  → score += 10
if library in user_task_keywords          → score += 5
if library in _shared/library-priority.json → score += 3
if library in production_dependencies     → score += 2
```

**Priority selection:**
```
sorted_libraries = sort_by_score_descending(all_libraries)
priority_libraries = sorted_libraries[:3]  # Top 3 max (budget constraint)
```

### Keyword Extraction

**Алгоритм:**
```javascript
function extractKeywords(userTaskDescription) {
  // Нормализация
  const text = userTaskDescription.toLowerCase();

  // Разбиение на слова
  const words = text.split(/\s+/);

  // Фильтрация стоп-слов
  const stopWords = ['add', 'create', 'implement', 'fix', 'update',
                     'with', 'using', 'for', 'to', 'the', 'a', 'an'];
  const filtered = words.filter(w =>
    !stopWords.includes(w) && w.length > 3
  );

  return filtered;
}
```

**Пример:**
```
Task: "Add JWT authentication to FastAPI app"
Keywords: ['authentication', 'fastapi', 'app']

Matches:
- "fastapi" → exact match (framework)
- "jose" → substring match with "jwt" (authentication library)
```

### Worked Example

**Scenario:**
```
Task: "Add authentication to Express.js app"
Detected libraries: [express, jest, lodash, passport, dotenv]
Framework: express
```

**Scoring:**
```
express:
  - framework match: +10
  - in task ("Express"): +5
  - common library: +3
  - production dependency: +2
  → Total: 20

passport:
  - in task ("authentication"): +5
  - production dependency: +2
  → Total: 7

lodash:
  - common library: +3
  - production dependency: +2
  → Total: 5

jest:
  - dev dependency: 0
  → Total: 0

dotenv:
  - production dependency: +2
  → Total: 2
```

**Priority (top 3):** `[express, passport, lodash]`

**Budget execution:**
```
Call 1: resolve-library-id("express") → /expressjs/express (calls_used: 1)
Call 2: query-docs("/expressjs/express", "auth") → docs (calls_used: 2)
Call 3: resolve-library-id("passport") → /jaredhanson/passport (calls_used: 3)
BUDGET EXHAUSTED (calls_remaining: 0)

Result:
- Fetched: express (full docs)
- Skipped: passport (no budget for query-docs), lodash (no budget)
```

## Budget Management

### Structure

```json
{
  "max_calls": 3,
  "calls_used": 0,
  "calls_remaining": 3,
  "queries": []
}
```

### Rules

1. **Total budget: 3 calls** (combined `resolve-library-id` + `query-docs`)
2. **Each call counts** (даже неудачные вызовы считаются согласно документации Context7)
3. **Warning threshold: 2 calls** (при calls_used >= 2 показывать предупреждение)
4. **Stop at 3 calls** (при calls_remaining == 0 прекратить запросы)

### Call Tracking

**При каждом вызове:**
```javascript
function recordCall(toolName, libraryName, success, result) {
  budget.calls_used++;
  budget.calls_remaining = budget.max_calls - budget.calls_used;
  budget.queries.push({
    callNumber: budget.calls_used,
    tool: toolName,  // 'resolve-library-id' or 'query-docs'
    libraryName: libraryName,
    success: success,
    result: result,
    timestamp: new Date().toISOString()
  });

  // Warning при приближении к лимиту
  if (budget.calls_remaining === 1) {
    budget.warning = `Context7 budget: ${budget.calls_used}/3 calls used. 1 call remaining.`;
  }

  // Exhausted при достижении лимита
  if (budget.calls_remaining === 0) {
    budget.exhausted = true;
    budget.warning = `Context7 budget exhausted (3/3 calls)`;
  }
}
```

### Budget Enforcement

```javascript
function canMakeCall() {
  return budget.calls_remaining > 0;
}

// В Query Loop
for (const library of priorityLibraries) {
  if (!canMakeCall()) {
    skippedLibraries.push({
      library_name: library.name,
      reason: "Budget exhausted"
    });
    break;  // Прекратить обработку
  }

  // Resolve library ID
  const libId = await resolveLibraryId(library.name);
  recordCall('resolve-library-id', library.name, !!libId, libId);

  if (!libId) {
    skippedLibraries.push({
      library_name: library.name,
      reason: "Not found in Context7"
    });
    continue;
  }

  if (!canMakeCall()) {
    skippedLibraries.push({
      library_name: library.name,
      reason: "Budget exhausted (resolved but no budget for docs)"
    });
    break;
  }

  // Query docs
  const docs = await queryDocs(libId, query);
  recordCall('query-docs', library.name, !!docs, docs);

  if (docs) {
    libraries.push({
      library_id: libId,
      library_name: library.name,
      docs_summary: docs.summary,
      code_examples: docs.examples || [],
      relevant_sections: docs.sections || [],
      query_used: query
    });
  }
}
```

## Query Construction

### resolve-library-id Query

**Формат:**
```javascript
{
  libraryName: "<название библиотеки>",
  query: "<контекст + задача>"
}
```

**Примеры:**
```javascript
// Python FastAPI
{
  libraryName: "fastapi",
  query: "FastAPI web framework for building APIs with Python"
}

// JavaScript React
{
  libraryName: "react",
  query: "React library for building user interfaces"
}

// Go Gin
{
  libraryName: "gin",
  query: "Gin HTTP web framework for Go"
}
```

**Best practices:**
- Включать основное назначение библиотеки
- Упоминать язык программирования для уникальности
- НЕ включать код или секретные данные

### query-docs Query

**Формат:**
```javascript
{
  libraryId: "/org/project",
  query: "<конкретный вопрос или задача>"
}
```

**Примеры:**
```javascript
// Аутентификация в FastAPI
{
  libraryId: "/tiangolo/fastapi",
  query: "How to implement JWT authentication in FastAPI with dependencies"
}

// React hooks
{
  libraryId: "/facebook/react",
  query: "React useEffect cleanup function best practices"
}

// Express middleware
{
  libraryId: "/expressjs/express",
  query: "Express middleware for authentication and authorization"
}
```

**Best practices:**
- Быть конкретным (не "auth", а "JWT authentication")
- Упоминать задачу пользователя
- Запрашивать примеры кода ("how to", "examples")
- НЕ включать секретные данные

## Error Handling

### Scenario A: resolve-library-id Returns Empty

**Условие:** Context7 не нашел библиотеку

**Action:**
```javascript
const libId = await resolveLibraryId(libraryName, query);
recordCall('resolve-library-id', libraryName, false, null);

if (!libId) {
  skippedLibraries.push({
    library_name: libraryName,
    reason: "Not found in Context7"
  });
  continue;  // Переход к следующей библиотеке
}
```

**Важно:** Вызов всё равно считается (calls_used++), согласно документации Context7.

### Scenario B: query-docs Network Error

**Условие:** Timeout или сетевая ошибка

**Action:**
```javascript
try {
  const docs = await queryDocs(libId, query);
  recordCall('query-docs', libraryName, true, docs);
} catch (error) {
  recordCall('query-docs', libraryName, false, error.message);

  if (error.message.includes('timeout') || error.message.includes('network')) {
    skippedLibraries.push({
      library_name: libraryName,
      reason: `Network error: ${error.message}`
    });
    continue;  // Переход к следующей библиотеке
  }

  // Другие ошибки - пробрасываем
  throw error;
}
```

**Важно:** Неудачный вызов всё равно считается (calls_used++).

### Scenario C: Plugin Not Available

**Условие:** Context7 MCP plugin не установлен

**Action:**
```javascript
// При первоначальной проверке
if (!isContext7Available()) {
  return {
    library_docs: {
      budget_status: {
        calls_used: 0,
        calls_remaining: 0,
        exhausted: false
      },
      libraries: [],
      skipped_libraries: [],
      status: "PLUGIN_NOT_AVAILABLE"
    }
  };
}
```

**User message:**
```
ℹ️ Context7 plugin not installed. Continuing without library docs.

To enable: Install Context7 MCP server
```

**Workflow:** Продолжить к `adaptive-workflow` (не блокировать).

### Scenario D: No Libraries Detected

**Условие:** Нет манифестов или нет зависимостей

**Action:**
```javascript
if (detectedLibraries.length === 0) {
  return {
    library_docs: {
      budget_status: {
        calls_used: 0,
        calls_remaining: 0,
        exhausted: false
      },
      libraries: [],
      skipped_libraries: [],
      status: "NO_LIBRARIES_DETECTED"
    }
  };
}
```

**User message:** (silent skip, no output)

**Workflow:** Продолжить к `adaptive-workflow`.

## Output Format

### JSON Schema

Используй шаблон: `@template:context7-output`

Валидация: `@schema:context7-output`

**Структура:**
```json
{
  "library_docs": {
    "budget_status": {
      "calls_used": 2,
      "calls_remaining": 1,
      "exhausted": false,
      "warning": "Context7 budget: 2/3 calls used"
    },
    "libraries": [
      {
        "library_id": "/tiangolo/fastapi",
        "library_name": "fastapi",
        "docs_summary": "FastAPI provides...",
        "code_examples": ["@app.get('/items')"],
        "relevant_sections": ["Dependencies", "Security"],
        "query_used": "JWT authentication in FastAPI"
      }
    ],
    "skipped_libraries": [
      {
        "library_name": "pytest",
        "reason": "Budget exhausted"
      }
    ],
    "status": "PARTIAL"
  }
}
```

### Status Values

- `SUCCESS`: Все priority библиотеки успешно загружены
- `PARTIAL`: Некоторые библиотеки загружены, некоторые пропущены (бюджет/ошибки/не найдены)
- `FAILED`: Все запросы провалились (сетевые/API ошибки)
- `PLUGIN_NOT_AVAILABLE`: Context7 MCP plugin не установлен
- `NO_LIBRARIES_DETECTED`: Нет зависимостей в конфигах

### Field Descriptions

**budget_status:**
- `calls_used`: Количество использованных вызовов (0-3)
- `calls_remaining`: Количество оставшихся вызовов (0-3)
- `exhausted`: true если все 3 вызова использованы
- `warning`: Предупреждение при приближении к лимиту

**libraries[] item:**
- `library_id`: Context7 ID (/org/project или /org/project/version)
- `library_name`: Имя библиотеки из манифеста
- `docs_summary`: Краткое содержание документации
- `code_examples`: Массив примеров кода из документации
- `relevant_sections`: Названия релевантных секций документации
- `query_used`: Запрос, отправленный в Context7

**skipped_libraries[] item:**
- `library_name`: Имя пропущенной библиотеки
- `reason`: Причина (Budget exhausted | Not found | Network error | Low priority)

## Integration with Workflow

### PHASE 0 Data Flow

```
context-awareness → {project_context}
                ↓
lsp-integration → {lsp_status}
                ↓
context7-integration → {library_docs}  [NEW]
                ↓
adaptive-workflow → {complexity}
```

### Input from context-awareness

```json
{
  "project_context": {
    "language": "python",
    "framework": "fastapi",
    "detected_files": {
      "config": ["requirements.txt", "pyproject.toml"],
      "source_dirs": ["src/", "app/"],
      "test_dirs": ["tests/"]
    }
  }
}
```

### Output to structured-planning

```json
{
  "library_docs": {
    "libraries": [
      {
        "library_id": "/tiangolo/fastapi",
        "docs_summary": "FastAPI routing...",
        "code_examples": ["@app.get(...)", "Depends(...)"]
      }
    ]
  }
}
```

### Benefits for Planning

**structured-planning может использовать library_docs для:**

1. **Execution steps:** Ссылаться на официальную документацию
   ```
   "Step 2: Configure FastAPI dependencies (see library_docs.libraries[0].code_examples)"
   ```

2. **Implementation notes:** Включать примеры кода
   ```
   "Use Depends() pattern from library_docs for dependency injection"
   ```

3. **Risks:** Упоминать gotchas из документации
   ```
   "Risk: FastAPI async routes require await (library_docs.relevant_sections['Async'])"
   ```

4. **Validation:** Сверяться с best practices
   ```
   "Validate approach against library_docs.docs_summary recommendations"
   ```

## Security Guidelines

### Что НЕ включать в запросы

**НИКОГДА не отправляйте:**
- API keys (`sk-ant-xxx`, `OPENAI_API_KEY=...`)
- Пароли (`password=secret123`)
- Credentials (`username:password@host`)
- Personal data (emails, phone numbers)
- Содержимое файлов (может содержать секреты)

### Safe Query Examples

**✓ Безопасные запросы:**
```
"How to implement JWT authentication in FastAPI"
"React useEffect cleanup function best practices"
"Express middleware for authentication"
"Go Gin route parameter validation"
```

**✗ Небезопасные запросы:**
```
"Connect to database with password=secret123"
"API key sk-ant-xxx usage in Python"
"Use token Bearer eyJhbGciOiJIUzI1..."
"My credentials are admin:P@ssw0rd"
```

### Input Sanitization

**Рекомендуется:**
```javascript
function sanitizeQuery(query) {
  // Удалить потенциальные секреты
  const patterns = [
    /sk-ant-[a-zA-Z0-9_-]+/g,  // Anthropic keys
    /OPENAI_API_KEY\s*=\s*[^\s]+/g,  // Env vars
    /password\s*[:=]\s*[^\s]+/gi,  // Passwords
    /token\s*[:=]\s*[^\s]+/gi,  // Tokens
    /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g  // Emails
  ];

  let sanitized = query;
  patterns.forEach(pattern => {
    sanitized = sanitized.replace(pattern, '[REDACTED]');
  });

  return sanitized;
}
```

## Version Handling

### Version Detection from Manifests

Когда библиотеки имеют ограничения версий в манифестах, извлекаем и используем для Context7 запросов.

#### JavaScript/TypeScript (package.json)

```json
{
  "dependencies": {
    "react": "^18.2.0",
    "express": "~4.18.2",
    "next": "14.0.0"
  }
}
```

**Extraction:**
```bash
# Извлечь версию для конкретного пакета
jq -r '.dependencies["react"]' package.json
# Output: ^18.2.0

# Очистить от префиксов ^, ~, >=
echo "^18.2.0" | sed 's/^[\^~>=]*\s*//'
# Output: 18.2.0
```

#### Python (requirements.txt)

```
fastapi==0.104.1
django>=4.2.0
pytest~=7.4.0
```

**Extraction:**
```bash
# Извлечь версию для fastapi
grep "^fastapi" requirements.txt | sed 's/^[^=<>]*[=<>]*\s*//'
# Output: 0.104.1
```

#### Python (pyproject.toml)

```toml
[project.dependencies]
fastapi = "^0.104.1"
django = ">=4.2.0"
```

**Extraction:**
```bash
# Извлечь версию
grep 'fastapi.*=' pyproject.toml | sed 's/.*=\s*"\(.*\)"/\1/' | sed 's/^[\^~>=]*//'
# Output: 0.104.1
```

#### Go (go.mod)

```
require (
    github.com/gin-gonic/gin v1.9.1
    github.com/stretchr/testify v1.8.4
)
```

**Extraction:**
```bash
# Извлечь версию для gin
grep "github.com/gin-gonic/gin" go.mod | awk '{print $2}' | sed 's/^v//'
# Output: 1.9.1
```

#### Rust (Cargo.toml)

```toml
[dependencies]
tokio = { version = "1.35.0", features = ["full"] }
serde = "1.0"
```

**Extraction:**
```bash
# Извлечь версию для tokio
grep -A 1 '^tokio.*=' Cargo.toml | grep 'version' | sed 's/.*version\s*=\s*"\(.*\)".*/\1/'
# Output: 1.35.0
```

### Version-Specific Queries

#### Scenario 1: User mentions version explicitly

```
Task: "Migrate to FastAPI 0.100.0"
Pattern: /FastAPI\s*[@v]?\s*\d+(\.\d+)*/i
Extracted: "0.100.0"

Library ID: /tiangolo/fastapi/v0.100.0
Query: "FastAPI 0.100.0 migration guide deprecated features"
```

#### Scenario 2: Manifest specifies version

```
requirements.txt: fastapi==0.104.1
Detected version: 0.104.1

Try: /tiangolo/fastapi/v0.104.1
Fallback: /tiangolo/fastapi (if version-specific not found)
```

#### Scenario 3: Version range in manifest

```
package.json: "react": "^18.2.0"
Detected version: 18.2.0 (strip ^)

Try: /facebook/react/v18.2.0
Fallback: /facebook/react
```

### Fallback Strategy

```
1. Extract version from manifest or task
   ├─ package.json: "react": "^18.2.0" → version: 18.2.0
   ├─ requirements.txt: fastapi==0.104.1 → version: 0.104.1
   └─ User task: "migrate to v14" → version: 14

2. Construct version-specific library ID
   libraryId = /org/project/v{version}

3. Call resolve-library-id(libraryName, query)
   ├─ Context7 returns library ID
   └─ Check if returned ID contains version

4. Decision:
   if (returnedId.includes(version)):
     use versionSpecificId  // /org/project/v14.0.0
   else:
     use genericId  // /org/project (latest version)

5. Query docs with selected ID
   query-docs(selectedId, query)
```

### Implementation

```javascript
function extractVersion(constraint) {
  // Remove version prefixes: ^, ~, >=, <=, >
  const cleaned = constraint.replace(/^[\^~><=]+\s*/, '');

  // Extract version pattern: 1.2.3, 14.0, etc.
  const match = cleaned.match(/(\d+(?:\.\d+)*)/);
  return match ? match[1] : null;
}

function detectVersionFromTask(task, libraryName) {
  // Pattern: "migrate to FastAPI 0.100" or "use React v18"
  const pattern = new RegExp(
    `${libraryName}\\s*[@v]?\\s*(\\d+(?:\\.\\d+)*)`,
    'i'
  );
  const match = task.match(pattern);
  return match ? match[1] : null;
}

async function resolveLibraryWithVersion(library, userTask, manifest) {
  let version = null;

  // Priority 1: User explicitly mentions version in task
  version = detectVersionFromTask(userTask, library.name);

  // Priority 2: Version in manifest
  if (!version && library.constraint) {
    version = extractVersion(library.constraint);
  }

  // Resolve library ID
  const result = await resolveLibraryId(library.name, buildQuery(library, userTask));

  // If version detected and Context7 returned version-specific ID, use it
  if (version && result.library_id.includes(`/v${version}`)) {
    return result.library_id;  // /tiangolo/fastapi/v0.104.1
  }

  // Otherwise use generic ID (latest version)
  return result.library_id;  // /tiangolo/fastapi
}
```

### Version Examples

#### Example 1: Specific version in task

```
Task: "Upgrade to Next.js 14"
Manifest: package.json has "next": "^13.5.0"

Process:
1. detectVersionFromTask() → "14"
2. resolve-library-id("next", "Next.js 14 upgrade guide")
3. Context7 returns: /vercel/next.js/v14.0.0
4. Use version-specific ID
5. query-docs("/vercel/next.js/v14.0.0", "Next.js 14 new features migration")
```

#### Example 2: Version from manifest only

```
Task: "Add FastAPI endpoints"
Manifest: requirements.txt has "fastapi==0.104.1"

Process:
1. extractVersion("==0.104.1") → "0.104.1"
2. resolve-library-id("fastapi", "FastAPI web framework")
3. Context7 returns: /tiangolo/fastapi (generic, not version-specific)
4. Use generic ID (Context7 doesn't have v0.104.1 specific docs)
5. query-docs("/tiangolo/fastapi", "FastAPI routing endpoints")
```

#### Example 3: Version range fallback

```
Task: "Fix React hooks issue"
Manifest: package.json has "react": "^18.2.0"

Process:
1. extractVersion("^18.2.0") → "18.2.0"
2. resolve-library-id("react", "React library")
3. Context7 returns: /facebook/react (no specific v18.2.0)
4. Fallback to generic ID
5. query-docs("/facebook/react", "React hooks best practices")
```

## Language Support

### Supported Languages and Manifests

| Language | Manifest Files | Parsing Method | Common Libraries |
|----------|----------------|----------------|------------------|
| JavaScript | package.json | jq | react, express, next, vue, axios |
| TypeScript | package.json | jq | react, express, next, vue, axios, zod |
| Python | requirements.txt, pyproject.toml | grep/sed | fastapi, django, flask, pytest, sqlalchemy |
| Go | go.mod | grep/awk | gin, echo, fiber, gorm, cobra |
| Rust | Cargo.toml | grep/awk | tokio, serde, actix-web, diesel, clap |
| Java | pom.xml, build.gradle | xml/gradle parser | spring, hibernate, junit |
| C# | *.csproj | xml parser | asp.net, entity-framework |

**Note:** Для Java и C# требуется более сложный парсинг XML. Можно использовать `xmllint` или `xpath` для extraction.

## Examples

### Example 1: Plugin Not Available (Graceful Degradation)

**Scenario:** Context7 MCP plugin не установлен, workflow продолжается без блокировки

**Initial state:**
```bash
# Проверка доступности Context7
try {
  await mcp__plugin_context7_context7__resolve_library_id({
    libraryName: "test",
    query: "test"
  });
} catch (error) {
  # Error: function not found
  plugin_available = false
}
```

**Output:**
```json
{
  "library_docs": {
    "budget_status": {
      "calls_used": 0,
      "calls_remaining": 0,
      "exhausted": false
    },
    "libraries": [],
    "skipped_libraries": [],
    "status": "PLUGIN_NOT_AVAILABLE"
  }
}
```

**User message:**
```
ℹ️ Context7 plugin not installed. Continuing without library docs.

To enable: Install Context7 MCP server
```

**Result:** Workflow продолжается к adaptive-workflow, task выполняется без library docs.

---

### Example 2: Budget Exhausted Mid-Query (Partial Results)

**Scenario:** Top 3 библиотеки приоритизированы, но бюджет исчерпан после первой библиотеки

**Project state:**
```
Task: "Add authentication to Express.js app"
Detected libraries: [express, passport, bcrypt, jest, dotenv]
Framework: express
```

**Prioritization:**
```
express: 20 (framework + task + common + prod)
passport: 7 (task + prod)
bcrypt: 5 (common + prod)
```

**Execution:**
```json
{
  "budget_status": {
    "calls_used": 0,
    "calls_remaining": 3
  }
}
```

**Call 1:** `resolve-library-id("express")` → `/expressjs/express` (calls_used: 1)

**Call 2:** `query-docs("/expressjs/express", "authentication middleware")` → Success (calls_used: 2)

**Call 3:** `resolve-library-id("passport")` → `/jaredhanson/passport` (calls_used: 3)

**Budget exhausted:** calls_remaining = 0

**Output:**
```json
{
  "library_docs": {
    "budget_status": {
      "calls_used": 3,
      "calls_remaining": 0,
      "exhausted": true,
      "warning": "Context7 budget exhausted (3/3 calls)"
    },
    "libraries": [
      {
        "library_id": "/expressjs/express",
        "library_name": "express",
        "docs_summary": "Express provides middleware-based routing for Node.js applications...",
        "code_examples": [
          "app.use(express.json())",
          "app.get('/protected', authMiddleware, handler)"
        ],
        "relevant_sections": ["Middleware", "Routing", "Error Handling"],
        "query_used": "Express middleware for authentication and authorization"
      }
    ],
    "skipped_libraries": [
      {"library_name": "passport", "reason": "Budget exhausted (resolved but no budget for docs)"},
      {"library_name": "bcrypt", "reason": "Budget exhausted"}
    ],
    "status": "PARTIAL"
  }
}
```

**Result:** Express docs загружены успешно, passport и bcrypt пропущены из-за бюджета. structured-planning всё ещё может использовать Express docs для планирования.

---

### Example 3: Version-Specific Query (Next.js 14 Upgrade)

**Scenario:** Пользователь хочет обновить Next.js до версии 14, Context7 возвращает version-specific docs

**Task:** "Upgrade to Next.js 14"

**Manifest (package.json):**
```json
{
  "dependencies": {
    "next": "^13.5.0",
    "react": "^18.2.0"
  }
}
```

**Library detection:**
```
Detected: [next, react]
Priority: next (20 - framework + task match), react (12 - common + prod)
```

**Version extraction:**
```javascript
detectVersionFromTask("Upgrade to Next.js 14", "next") → "14"
```

**Call 1:** `resolve-library-id("next", "Next.js 14 upgrade guide")`
- Context7 returns: `/vercel/next.js/v14.0.0` (version-specific)
- calls_used: 1

**Call 2:** `query-docs("/vercel/next.js/v14.0.0", "Next.js 14 new features migration breaking changes")`
- Context7 returns: Docs for version 14 specifically
- calls_used: 2

**Call 3:** `resolve-library-id("react", "React library for UI")`
- Context7 returns: `/facebook/react`
- calls_used: 3

**Budget exhausted**

**Output:**
```json
{
  "library_docs": {
    "budget_status": {
      "calls_used": 3,
      "calls_remaining": 0,
      "exhausted": true,
      "warning": "Context7 budget exhausted (3/3 calls)"
    },
    "libraries": [
      {
        "library_id": "/vercel/next.js/v14.0.0",
        "library_name": "next",
        "docs_summary": "Next.js 14 introduces Turbopack, Server Actions stable, Partial Prerendering...",
        "code_examples": [
          "// Server Actions (stable in v14)",
          "export async function createUser(data) { 'use server'; ... }",
          "// Partial Prerendering",
          "export const experimental_ppr = true"
        ],
        "relevant_sections": [
          "Migration Guide v13 → v14",
          "Breaking Changes",
          "Turbopack",
          "Server Actions"
        ],
        "query_used": "Next.js 14 new features migration breaking changes"
      }
    ],
    "skipped_libraries": [
      {"library_name": "react", "reason": "Budget exhausted (resolved but no budget for docs)"}
    ],
    "status": "PARTIAL"
  }
}
```

**Result:** Version-specific Next.js 14 docs успешно загружены, structured-planning может использовать migration guide и breaking changes для планирования обновления.

---

## FAQ

**Q: Что делать, если Context7 plugin не установлен?**
A: Skill автоматически обнаружит недоступность и вернет `PLUGIN_NOT_AVAILABLE`. Workflow продолжится без блокировки. Пользователь увидит информационное сообщение.

**Q: Почему лимит 3 вызова?**
A: Это ограничение Context7 MCP plugin. Согласно документации: "Do not call this tool more than 3 times per question." Лимит применяется к комбинации `resolve-library-id` + `query-docs`.

**Q: Считаются ли неудачные вызовы?**
A: Да. Даже если `resolve-library-id` не находит библиотеку, вызов считается. Это важно для корректного budget tracking.

**Q: Как обрабатываются версии библиотек?**
A: Если в манифесте указана версия (например, `fastapi==0.104.1`), skill пытается запросить version-specific library ID (`/tiangolo/fastapi/v0.104.1`). Если не найден, используется generic ID (`/tiangolo/fastapi`).

**Q: Что если обнаружено 10 библиотек?**
A: Prioritization algorithm выбирает top 3 на основе scoring. Остальные добавляются в `skipped_libraries` с reason "Low priority".

**Q: Можно ли увеличить бюджет?**
A: Нет. 3-call limit - это ограничение Context7 API. При попытке сделать 4-й вызов Context7 вернет ошибку.

**Q: Как узнать, какой query был отправлен?**
A: Поле `query_used` в output содержит фактический запрос. Также budget.queries[] содержит историю всех вызовов.

**Q: Работает ли skill без Context7?**
A: Да, skill gracefully degraded. При недоступности плагина возвращает `PLUGIN_NOT_AVAILABLE` и workflow продолжается.

**Q: Как skill определяет приоритет библиотек?**
A: См. раздел "Prioritization Algorithm". Framework получает наивысший score (10), затем keywords из задачи (5), затем common libraries (3), затем prod dependencies (2).

**Q: Что означает status PARTIAL?**
A: Некоторые библиотеки успешно загружены, но часть пропущена из-за бюджета, ошибок или отсутствия в Context7.

## Related Skills

- **context-awareness**: Предоставляет `project_context.detected_files.config` для detection
- **structured-planning**: Использует `library_docs` для улучшения execution plans
- **code-review**: Может сверяться с library best practices из docs_summary
- **validation-framework**: Может использовать примеры кода для проверки правильности реализации

---

🤖 Generated with Claude Code

**Author:** ikeniborn
**License:** MIT
