---
name: Structured Planning
description: Создание планов задач с адаптивной JSON Schema
version: 2.0.0
tags: [planning, json-schema, structured-output]
dependencies: [thinking-framework, adaptive-workflow]
files:
  templates: ./templates/*.json
  schemas: ./schemas/*.json
  examples: ./examples/*.md
user-invocable: false
---

# Structured Planning v2.0

Адаптивное планирование с выбором схемы по сложности задачи.

## Когда использовать

- После analysis thinking
- Для создания плана выполнения

## Выбор шаблона

| Complexity | Template | Schema |
|------------|----------|--------|
| minimal | `@template:task-plan-lite` | Нет валидации |
| standard | `@template:task-plan` | `@schema:task-plan` |
| complex | `@template:task-plan` + phases | `@schema:task-plan` |

## Шаблоны

### Minimal (task-plan-lite)

```json
{
  "task_plan_lite": {
    "task_name": "string",
    "files": ["file1.py", "file2.py"],
    "steps": ["step1", "step2"],
    "validation": "syntax_command"
  }
}
```

### Standard/Complex (task-plan)

```json
{
  "task_plan": {
    "task_name": "string",
    "problem": "string",
    "solution": "string",
    "acceptance_criteria": ["AC1", "AC2"],
    "files_to_change": [
      {"file_path": "path", "change_type": "modify", "description": "desc"}
    ],
    "execution_steps": [
      {"step_number": 1, "description": "desc", "actions": ["a1"], "validation": "cmd"}
    ],
    "risks": [{"risk": "r", "mitigation": "m"}],
    "git": {
      "branch_name": "feature/x",
      "commit_type": "feat",
      "commit_summary": "summary"
    }
  }
}
```

## Ключевые правила

- `acceptance_criteria`: минимум 1
- `execution_steps`: минимум 1 (было 2)
- `branch_name`: pattern `^(feature|fix|refactor)/`
- `commit_summary`: max 72 символа
- `prd_sections`: ОПЦИОНАЛЬНО (не required)
- `risks`: ОПЦИОНАЛЬНО

## Markdown Output

После JSON всегда выводить читаемый план:

```
## План: {task_name}

**Файлы:** {N} файлов
**Шагов:** {M}

### Изменения
- {file1} — {description}
- {file2} — {description}

### Шаги
1. {step1}
2. {step2}

### Git
- Branch: {branch_name}
- Commit: {commit_type}: {commit_summary}
```

## Примеры

- Простая задача: `@example:simple-task`
- Рефакторинг: `@example:refactoring`
- Многофазная: `@example:multi-phase`

---

## Library Documentation Integration (Optional)

**Активируется когда:** `library_docs.loaded == true` (из context7-integration skill)

Когда Context7 доступен, structured-planning использует официальную документацию библиотек для обогащения execution_steps примерами кода и best practices.

### Что предоставляет Context7:

**1. Code Examples:**
- Официальные примеры использования API из документации
- Best practices для популярных фреймворков
- Готовые паттерны (authentication, data fetching, error handling)

**2. API References:**
- Актуальные сигнатуры методов
- Параметры функций с типами
- Return types и exceptions

**3. Framework Patterns:**
- Рекомендуемая структура проектов
- Настройка конфигураций
- Integration patterns

### Алгоритм интеграции:

```
IF library_docs.loaded == true:
  FOR EACH execution_step:
    1. Извлечь ключевые слова из step.description
       (например: "Create FastAPI endpoint" → keywords: ["FastAPI", "endpoint", "router"])
    2. Поиск в library_docs по ключевым словам
    3. Если найдены релевантные примеры:
       a. Добавить code_example в step.library_reference
       b. Добавить docs_url для дополнительной информации
    4. Enriched step содержит:
       - Оригинальные actions
       - Code example из документации
       - Ссылка на официальные доки
ELSE:
  Генерировать execution_steps без library_reference
  (fallback на базовые инструкции)
```

### Поддерживаемые библиотеки:

Context7 MCP plugin поддерживает документацию для 100+ популярных библиотек:

| Категория | Примеры библиотек |
|-----------|-------------------|
| Web Frameworks | FastAPI, Django, Flask, Express.js, Next.js |
| Data Science | pandas, numpy, scikit-learn, PyTorch, TensorFlow |
| Frontend | React, Vue, Angular, Svelte |
| Database | SQLAlchemy, Prisma, TypeORM, Mongoose |
| Testing | pytest, Jest, Mocha, Cypress |
| DevOps | Docker, Kubernetes, Terraform, Ansible |

**Note:** См. [@skill:context7-integration](../context7-integration/SKILL.md) для установки Context7 MCP plugin.

### Пример enriched execution step:

```json
{
  "step_number": 1,
  "description": "Create FastAPI endpoint for user login",
  "actions": [
    "Create file src/api/auth.py",
    "Add /login POST endpoint",
    "Implement JWT token generation"
  ],
  "validation": "Run pytest tests/test_auth.py",
  "library_reference": {
    "code_example": "@APIRouter.post('/login')\nasync def login(credentials: LoginRequest):\n    # Validate credentials\n    # Generate JWT token\n    return {'access_token': token}",
    "docs_url": "https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/",
    "framework": "FastAPI",
    "pattern": "OAuth2 with JWT"
  }
}
```

### Backward Compatibility:

- Context7 integration полностью опциональная
- Без Context7 skill работает с базовыми инструкциями
- Output формат одинаковый с/без Context7
- `library_reference` field добавляется только при library_docs available
