---
name: Structured Planning
description: Создание планов задач с адаптивной JSON Schema
version: 2.1.0
tags: [planning, json-schema, structured-output, skill-generation]
dependencies: [thinking-framework, adaptive-workflow, skill-generator]
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

---

## Skill Generator Integration (Domain-Specific Skills)

**Активируется когда:** Обнаружена потребность в domain-specific skill, который отсутствует в проекте

Когда structured-planning планирует задачу для определенного фреймворка/технологии (FastAPI, React, PostgreSQL и т.д.) и обнаруживает, что соответствующий domain skill не существует в `.claude/skills/`, предлагает автоматически создать его через skill-generator.

### Зачем создавать domain skills:

**1. Консистентность паттернов:**
- Единый подход к работе с технологией в проекте
- Стандартизированные naming conventions, структура файлов
- Переиспользуемые templates и schemas

**2. Лучшее качество execution steps:**
- Специализированные action templates для технологии
- Framework-specific validation commands
- Best practices из опыта команды

**3. Accelerated development:**
- Один раз описать паттерны → использовать во всех задачах
- Автоматическая валидация через JSON schema
- Готовые examples для типичных сценариев

### Когда предлагать создание skill:

**Триггеры:**

1. **Framework detection:**
   - Задача включает работу с фреймворком (FastAPI, React, Django)
   - Фреймворк используется в проекте (определено из context-awareness)
   - Skill `{framework}-development` не существует в `.claude/skills/`

2. **Technology pattern:**
   - Повторяющиеся паттерны в execution_steps (например, "Create API endpoint" × 3)
   - Паттерн характерен для технологии (GraphQL resolvers, WebSocket handlers, DB migrations)
   - Соответствующий skill отсутствует

3. **Complex integration:**
   - Интеграция между технологиями (FastAPI + PostgreSQL, React + WebSocket)
   - Integration skill отсутствует (например, `api-database-integration`)

**НЕ предлагать если:**
- Задача разовая (нет повторяющихся паттернов)
- Технология используется впервые (нет достаточного опыта для формализации)
- Generic skill подходит (например, `code-review` вместо `fastapi-code-review`)

### Алгоритм интеграции:

```python
# Step 1: Detect missing domain skills during planning
def detect_missing_skills(task_context, execution_steps):
    # Извлечь используемые технологии из task
    technologies = extract_technologies(task_context)  # ["FastAPI", "PostgreSQL", "pytest"]

    # Проверить существование domain skills
    missing_skills = []
    for tech in technologies:
        skill_name = f"{tech.lower()}-development"
        if not skill_exists(f".claude/skills/{skill_name}/"):
            # Проверить, есть ли паттерны для этой технологии
            pattern_count = count_patterns(execution_steps, tech)
            if pattern_count >= 2:  # Минимум 2 использования паттерна
                missing_skills.append({
                    "technology": tech,
                    "skill_name": skill_name,
                    "pattern_count": pattern_count,
                    "example_actions": get_example_actions(execution_steps, tech)
                })

    return missing_skills

# Step 2: Offer skill generation
IF missing_skills is not empty:
    FOR EACH missing_skill in missing_skills:
        # Вывести предложение (non-blocking)
        output_recommendation = f"""
        💡 **Recommendation: Create '{missing_skill.skill_name}' skill**

        This task uses {missing_skill.technology} {missing_skill.pattern_count} times.
        Creating a domain skill would provide:
        - Consistent {missing_skill.technology} patterns
        - Framework-specific validation
        - Reusable templates for future tasks

        **Generate now:** `/skill-generator`
        **Or skip** and use generic approach for this task.
        """

        # НЕ блокировать execution
        # Structured-planning продолжает работу с generic approach
        # User может запустить /skill-generator позже

# Step 3: Enhanced planning with domain skills (future tasks)
IF domain_skill_exists(f".claude/skills/{tech}-development/"):
    # Использовать templates из domain skill
    # Обогащать execution_steps domain-specific actions
    # Применять domain-specific validation
```

### Пример: FastAPI project без fastapi-development skill

**Задача:** "Create user authentication API with JWT"

**structured-planning обнаруживает:**
- Technology: FastAPI (из context-awareness)
- Pattern: "Create API endpoint" × 3 (login, register, refresh_token)
- Missing skill: `fastapi-development`

**Вывод рекомендации:**

```markdown
💡 **Recommendation: Create 'fastapi-development' skill**

This task uses FastAPI 3 times:
- POST /auth/login endpoint
- POST /auth/register endpoint
- POST /auth/refresh endpoint

Creating a domain skill would provide:
- Consistent FastAPI router patterns
- Pydantic model templates
- pytest integration test patterns

**Generate now:** `/skill-generator`

**Skip and continue:** Using generic approach for this task.
```

**Если user выбирает генерацию:**

```bash
# User запускает
/skill-generator

# Interactive questionnaire:
Q1: Skill name? → fastapi-development
Q2: Skill type? → system (not user-invocable)
Q3: Description? → FastAPI REST API development patterns
Q4: Dependencies? → api-development, validation-framework
Q5: Complexity levels? → No (single approach)
Q6: Output format? → JSON
Q7: Templates needed? → endpoint, pydantic-model, test
Q8: Additional features? → examples, rules

# skill-generator creates:
✅ .claude/skills/fastapi-development/SKILL.md
✅ .claude/skills/fastapi-development/templates/endpoint.json
✅ .claude/skills/fastapi-development/templates/pydantic-model.json
✅ .claude/skills/fastapi-development/templates/test.json
✅ .claude/skills/fastapi-development/schemas/*.schema.json
✅ .claude/skills/fastapi-development/examples/basic-crud.md
✅ .claude/skills/fastapi-development/rules/fastapi-best-practices.md
```

**На следующих задачах с FastAPI:**

structured-planning автоматически использует `fastapi-development` skill:
- Применяет endpoint template из skill
- Использует Pydantic model patterns
- Добавляет pytest validation commands

### Типичные domain skills для разных стеков:

| Stack | Domain Skills | Когда создавать |
|-------|--------------|-----------------|
| **FastAPI + PostgreSQL** | `fastapi-development`, `postgresql-management`, `api-database-integration` | При 2+ API endpoints, 2+ migrations |
| **React + TypeScript** | `react-development`, `typescript-patterns`, `component-library` | При 3+ components, типизация |
| **Django + Celery** | `django-development`, `celery-tasks`, `django-testing` | При 2+ views, 2+ async tasks |
| **Next.js + Prisma** | `nextjs-development`, `prisma-orm`, `api-routes` | При 3+ pages, 2+ API routes |
| **Vue + Vuex** | `vue-development`, `vuex-store`, `vue-testing` | При 3+ components, state management |

### Преимущества approach:

**1. Progressive skill building:**
- Начинаем с generic skills (code-review, git-workflow)
- Постепенно добавляем domain skills по мере понимания проекта
- Domain skills эволюционируют с опытом команды

**2. Non-intrusive recommendations:**
- structured-planning НЕ блокирует execution
- Рекомендация показывается, но можно пропустить
- User решает, создавать skill или нет

**3. Reusability:**
- Domain skill создается один раз
- Используется во всех будущих задачах с технологией
- Улучшается на основе feedback

**4. Team alignment:**
- Domain skills документируют паттерны команды
- Newcomers изучают best practices через skill examples
- Консистентность кодовой базы

### Backward Compatibility:

- Skill-generator integration полностью опциональная
- Без skill-generator structured-planning работает с generic approach
- Рекомендации не блокируют workflow
- Существующие проекты без domain skills продолжают работать

### Next Steps (для user):

**После получения рекомендации создать domain skill:**

1. Запустить `/skill-generator`
2. Ответить на интерактивные вопросы
3. Проверить сгенерированные файлы
4. Customize templates под паттерны проекта
5. Commit skill в git
6. Использовать в следующих задачах автоматически
