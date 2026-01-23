---
name: Structured Planning
description: Создание планов задач с адаптивной JSON Schema
version: 2.3.0
tags: [planning, json-schema, structured-output, skill-generation, prd, toon]
dependencies: [thinking-framework, adaptive-workflow, skill-generator, prd-generator, toon-skill]
files:
  templates: ./templates/*.json
  schemas: ./schemas/*.json
  examples: ./examples/*.md
user-invocable: false
changelog:
  - version: 2.3.0
    date: 2026-01-23
    changes:
      - "**TOON Format Support**: Автоматическая генерация TOON для token efficiency"
      - "TOON для execution_steps[] и files_to_change[] (когда >= 5 элементов)"
      - "35-45% token savings для standard/complex tasks"
      - "100% backward compatibility (JSON остаётся primary format)"
      - "Special handling для nested actions[] (inline в description)"
      - "Integration examples для producers и consumers"
  - version: 2.2.0
    date: 2025-XX-XX
    changes:
      - "PRD Generator integration"
      - "Skill Generator recommendations"
      - "Context7 library documentation support"
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

---

## PRD Generator Integration (Product Requirements Documents)

**Активируется когда:** Complex задача с большим количеством требований и без существующего PRD

Когда structured-planning обнаруживает complex задачу (complexity_result.level == "complex") с множественными features/requirements, но проект не имеет Product Requirements Document, предлагает создать PRD через prd-generator BEFORE планирования для лучшей структуризации требований.

### Зачем создавать PRD перед планированием:

**1. Structured requirements:**
- Единый источник правды для всех требований
- 14 стандартных разделов (от Executive Summary до Appendices)
- 5 Mermaid диаграмм (Product Vision, User Journey, System Context, Feature Dependencies, Roadmap)
- Детальная спецификация каждой фичи (User Story + Acceptance Criteria)

**2. Better task plans:**
- structured-planning использует PRD как входные данные
- execution_steps создаются на основе Functional Requirements
- acceptance_criteria берутся из PRD §6 Feature Specifications
- Technical constraints учитываются из PRD §9 Technical Requirements

**3. Team alignment:**
- Product Manager, Designer, Developer работают с одним документом
- Newcomers быстро понимают product vision
- Stakeholders имеют comprehensive overview

**4. Long-term maintainability:**
- PRD эволюционирует с продуктом (UPDATE mode)
- Roadmap tracking из PRD §10
- Risk management из PRD §11

### Когда предлагать создание PRD:

**Триггеры:**

1. **Complex task with multiple features:**
   - complexity_result.level == "complex"
   - execution_steps содержат 5+ features (разные фичи, не steps одной фичи)
   - Каждая фича имеет собственные acceptance criteria

2. **New product/major feature:**
   - Задача начинается со слов "Create new product", "Build {product}", "Implement major feature"
   - Требуется business goals, target audience, roadmap
   - Нет существующего PRD в `docs/prd/`

3. **Feature-rich project without PRD:**
   - context-awareness определяет проект как feature-rich (10+ файлов, 3+ модулей)
   - `docs/prd/` отсутствует
   - task_plan содержит 3+ разных модулей/компонентов

**НЕ предлагать если:**
- Задача simple/minimal (1-2 файла, straightforward fix)
- PRD уже существует в `docs/prd/` (но можно предложить UPDATE)
- Задача purely technical (refactoring без новых features)
- Задача bug fix или minor enhancement

### Алгоритм интеграции:

```python
# Step 1: Detect need for PRD during planning
def check_prd_needed(task_context, complexity_result, execution_steps):
    # Проверить существование PRD
    prd_exists = os.path.exists("docs/prd/README.md")

    # Подсчитать количество features в execution_steps
    features = extract_features(execution_steps)  # ["User auth", "Dashboard", "Reports", "Notifications"]
    feature_count = len(features)

    # Определить масштаб задачи
    is_complex = complexity_result.level == "complex"
    is_feature_rich = feature_count >= 5
    is_new_product = task_context.task_name.lower().startswith(("create", "build", "implement major"))

    # Триггеры
    needs_prd = False
    reason = None

    if is_complex and is_feature_rich and not prd_exists:
        needs_prd = True
        reason = f"Complex task with {feature_count} features, no PRD exists"
    elif is_new_product and not prd_exists:
        needs_prd = True
        reason = "New product development, PRD recommended for requirements clarity"

    return needs_prd, reason, prd_exists

# Step 2: Offer PRD generation (non-blocking)
IF needs_prd:
    output_recommendation = f"""
    💡 **Recommendation: Create Product Requirements Document (PRD)**

    {reason}

    Creating a PRD would provide:
    - Structured requirements (14 sections)
    - Visual diagrams (5 Mermaid charts)
    - Detailed feature specs (User Stories + Acceptance Criteria)
    - Roadmap and risk analysis

    **Generate now:** `/prd-generator`

    **Or skip** and continue with ad-hoc planning for this task.
    """

    # НЕ блокировать execution
    # structured-planning продолжает без PRD
    # Но если PRD создан, использовать его данные

# Step 3: Use existing PRD (if available)
IF prd_exists:
    # Read PRD data
    prd_data = read_prd_documents("docs/prd/")

    # Enrich task_plan with PRD data:
    # 1. acceptance_criteria ← PRD §6 Feature Specifications
    # 2. risks ← PRD §11 Risks + add task-specific risks
    # 3. git.commit_summary ← Based on PRD §10 Roadmap phase
    # 4. execution_steps ← PRD §6 Functional Requirements breakdown
    # 5. Non-functional requirements ← PRD §7 NFR (performance, security)

    task_plan = {
        "task_name": task_context.task_name,
        "problem": task_context.problem,
        "solution": task_context.solution,
        "acceptance_criteria": prd_data.features[0].acceptance_criteria,  # From PRD
        "execution_steps": generate_steps_from_prd(prd_data.functional_requirements),
        "risks": prd_data.risks + task_specific_risks,
        "git": {
            "branch_name": f"feature/{slug(task_context.task_name)}",
            "commit_type": "feat",
            "commit_summary": f"Implement {prd_data.features[0].name} (Roadmap {prd_data.current_phase})"
        },
        "prd_reference": {
            "prd_path": "docs/prd/",
            "feature_file": f"docs/prd/06-functional-requirements/features/feature-{slug(task_context.task_name)}.md",
            "roadmap_phase": prd_data.current_phase
        }
    }
ELSE:
    # Генерировать task_plan с generic approach (текущее поведение)
```

### Пример: New SaaS product без PRD

**Задача:** "Create user management system with authentication, roles, permissions, audit logging, and user analytics"

**structured-planning обнаруживает:**
- Complexity: complex (определено adaptive-workflow)
- Features: 5 (authentication, roles, permissions, audit, analytics)
- PRD exists: No (docs/prd/ отсутствует)

**Вывод рекомендации:**

```markdown
💡 **Recommendation: Create Product Requirements Document (PRD)**

Complex task with 5 features, no PRD exists:
- User authentication
- Role management
- Permission system
- Audit logging
- User analytics

Creating a PRD would provide:
- Structured requirements (14 sections)
- Visual diagrams (5 Mermaid charts)
- Detailed feature specs (User Stories + Acceptance Criteria)
- Roadmap and risk analysis

**Generate now:** `/prd-generator`

**Or skip** and continue with ad-hoc planning for this task.
```

**Если user выбирает генерацию:**

```bash
# User запускает
/prd-generator

# Interactive questionnaire (12 questions):
Q1: Product Name? → User Management System
Q2: Product Type? → SaaS
Q3: Target Audience? → B2B SaaS customers, IT administrators
Q4: Business Goals? → Centralize user management, Reduce admin overhead by 50%, Improve security compliance
Q5: Success Metrics? → MAU, Admin time saved, Security incidents
Q6: Core Features? → Authentication, Roles, Permissions, Audit, Analytics
Q7: User Scenarios? → Admin creates user, User logs in, Admin assigns role, Compliance officer reviews audit logs
Q8: Tech Stack? → Backend: FastAPI + PostgreSQL, Frontend: React + TypeScript
Q9: Integrations? → SAML SSO, Active Directory, Okta
Q10: Timeline? → MVP (Q1 2026), Beta (Q2 2026), GA (Q3 2026)
Q11: Risks? → SAML integration complexity, AD sync performance
Q12: Target Directory? → docs/prd/

# prd-generator creates:
✅ docs/prd/README.md (navigation)
✅ docs/prd/01-executive-summary.md
✅ docs/prd/02-goals-and-scope.md
✅ docs/prd/03-product-overview.md
✅ docs/prd/04-target-audience.md (2 personas: IT Admin, Compliance Officer)
✅ docs/prd/05-business-requirements.md
✅ docs/prd/06-functional-requirements/overview.md
✅ docs/prd/06-functional-requirements/features/feature-authentication.md
✅ docs/prd/06-functional-requirements/features/feature-roles.md
✅ docs/prd/06-functional-requirements/features/feature-permissions.md
✅ docs/prd/06-functional-requirements/features/feature-audit.md
✅ docs/prd/06-functional-requirements/features/feature-analytics.md
✅ docs/prd/07-non-functional-requirements.md
✅ docs/prd/08-user-interface/design-guidelines.md
✅ docs/prd/09-technical-requirements/architecture.md
✅ docs/prd/10-roadmap.md
✅ docs/prd/11-risks.md
✅ docs/prd/12-testing.md
✅ docs/prd/13-launch-and-support.md
✅ docs/prd/14-appendices/glossary.md
✅ docs/prd/diagrams/product-vision.mmd
✅ docs/prd/diagrams/user-journey.mmd
✅ docs/prd/diagrams/system-context.mmd
✅ docs/prd/diagrams/feature-dependencies.mmd
✅ docs/prd/diagrams/roadmap-timeline.mmd
```

**После создания PRD, structured-planning использует его:**

```json
{
  "task_plan": {
    "task_name": "Implement user authentication",
    "problem": "Users need secure login mechanism",
    "solution": "SAML SSO + password-based auth with MFA",
    "acceptance_criteria": [
      "Given user enters valid credentials, when submits login form, then user is authenticated",
      "Given user has MFA enabled, when logs in, then OTP is required",
      "Given SAML is configured, when user clicks SSO, then redirected to IdP"
    ],
    "execution_steps": [
      {
        "step_number": 1,
        "description": "Create authentication endpoints (from PRD §6 feature-authentication.md)",
        "actions": [
          "POST /auth/login - Password-based authentication",
          "POST /auth/mfa/verify - MFA verification",
          "GET /auth/saml/redirect - SAML SSO redirect"
        ],
        "validation": "pytest tests/test_auth.py"
      },
      {
        "step_number": 2,
        "description": "Implement session management (from PRD §7 NFR: session timeout 30 min)",
        "actions": [
          "Create Redis session store",
          "Implement session refresh endpoint",
          "Add session cleanup cron job"
        ],
        "validation": "pytest tests/test_session.py"
      }
    ],
    "risks": [
      {"risk": "SAML integration complexity (from PRD §11)", "mitigation": "Use existing library (python-saml), allocate 2 weeks for testing"},
      {"risk": "MFA bypassed", "mitigation": "Add rate limiting + audit logging"}
    ],
    "git": {
      "branch_name": "feature/user-authentication",
      "commit_type": "feat",
      "commit_summary": "Implement user authentication (Roadmap MVP Q1 2026)"
    },
    "prd_reference": {
      "prd_path": "docs/prd/",
      "feature_file": "docs/prd/06-functional-requirements/features/feature-authentication.md",
      "roadmap_phase": "MVP (Q1 2026)"
    }
  }
}
```

### Workflow diagram:

```
User Task: "Create user management system..."
  ↓
adaptive-workflow → complexity = "complex"
  ↓
structured-planning → detect 5 features, no PRD
  ↓
💡 Recommend: /prd-generator
  ↓
┌─────────────────────┬──────────────────────┐
│ User skips          │ User creates PRD     │
│ (ad-hoc planning)   │ (/prd-generator)     │
├─────────────────────┼──────────────────────┤
│ structured-planning │ prd-generator runs   │
│ generates generic   │ → 14 sections + 5    │
│ task_plan           │ diagrams created     │
│                     │ ↓                    │
│                     │ structured-planning  │
│                     │ reads PRD data       │
│                     │ → enriched task_plan │
└─────────────────────┴──────────────────────┘
  ↓
Execution with task_plan
```

### Benefits of PRD-first approach:

**1. Front-loaded clarity:**
- Все требования документированы BEFORE coding
- Stakeholders align на Product Vision (PRD §3)
- Developer имеет complete context (PRD §6-§9)

**2. Reduced rework:**
- Acceptance Criteria из PRD (не придумываются на ходу)
- Non-functional requirements учтены (PRD §7: performance, security)
- Risks identified early (PRD §11)

**3. Consistency across tasks:**
- Следующие tasks тоже используют PRD
- Терминология консистентна (PRD §14 Glossary)
- Features координируются через PRD §10 Roadmap

**4. Traceable progress:**
- structured-planning ссылается на PRD feature file
- Commits включают roadmap phase
- Easy to track "Which features from PRD are implemented?"

### UPDATE mode (when PRD exists):

**Scenario:** PRD уже создан, но появились новые требования

```python
IF prd_exists:
    # Check if task adds new feature
    new_features = detect_new_features(task_context, prd_data.features)

    IF new_features:
        output_recommendation = f"""
        💡 **Recommendation: Update PRD with new features**

        This task introduces new features not in existing PRD:
        {new_features}

        **Update PRD:** `/prd-generator` (UPDATE mode)

        prd-generator will:
        - Preserve existing content
        - Add new feature files
        - Update diagrams (feature-dependencies, roadmap)
        - Smart merge with your custom changes

        **Or skip** and proceed with task-specific planning.
        """
```

### Backward Compatibility:

- PRD generator integration полностью опциональная
- Без PRD structured-planning работает с generic approach
- Рекомендации не блокируют workflow
- Существующие проекты без PRD продолжают работать

### When to use PRD vs ad-hoc planning:

| Factor | Use PRD | Use Ad-hoc Planning |
|--------|---------|---------------------|
| **Task complexity** | Complex (5+ features) | Simple/Standard (1-3 features) |
| **New product** | Yes (create PRD) | No (single feature addition) |
| **Stakeholder involvement** | High (PM, Design, Dev) | Low (dev-only task) |
| **Documentation needs** | Regulatory compliance, external docs | Internal implementation only |
| **Long-term project** | Yes (evolving requirements) | No (one-off task) |
| **Team size** | >3 people | 1-2 developers |

### Next Steps (для user):

**После получения рекомендации создать PRD:**

1. Запустить `/prd-generator`
2. Ответить на 12 интерактивных вопросов
3. Проверить сгенерированные 14 разделов + 5 диаграмм
4. Customize PRD (add specifics, refine personas)
5. Commit PRD в git
6. structured-planning автоматически использует PRD в следующих tasks

---

## TOON Format Support

**NEW in v2.3.0:** Автоматическая генерация TOON format для token-efficient structured output

### Когда генерируется TOON

Skill автоматически генерирует TOON format когда:
- `execution_steps.length >= 5` ИЛИ
- `files_to_change.length >= 5`

### Token Savings

**Типичная экономия:**
- 10 execution steps: **42% token reduction**
- 15 files to change: **38% token reduction**
- Combined (steps + files): **35-45% total savings**

### Output Structure (Hybrid JSON + TOON)

```json
{
  "task_plan": {
    "task_name": "Implement user authentication API",
    "problem": "Users need secure login mechanism",
    "solution": "JWT-based authentication with refresh tokens",
    "acceptance_criteria": ["AC1", "AC2", "AC3"],
    "files_to_change": [...],      // JSON (всегда присутствует)
    "execution_steps": [...],      // JSON (всегда присутствует)
    "risks": [...],
    "git": {...},
    "toon": {                      // TOON (опционально, если >= 5 элементов)
      "execution_steps_toon": "execution_steps[10]{step_number,description,validation}:\n  1,Create authentication endpoints (POST /auth/login POST /auth/refresh),pytest tests/test_auth.py\n  2,Implement JWT token generation using PyJWT library,pytest tests/test_jwt.py\n  3,Create user model with password hashing (bcrypt),pytest tests/test_user_model.py\n  4,Add Redis session store for refresh tokens,pytest tests/test_session.py\n  5,Implement token refresh endpoint,pytest tests/test_refresh.py\n  6,Add rate limiting to auth endpoints (10 req/min),pytest tests/test_rate_limit.py\n  7,Create middleware for token validation,pytest tests/test_middleware.py\n  8,Add password reset functionality,pytest tests/test_password_reset.py\n  9,Implement email verification flow,pytest tests/test_email_verify.py\n  10,Add audit logging for auth events,pytest tests/test_audit.py",
      "files_to_change_toon": "files_to_change[12]{file_path,change_type,description}:\n  src/api/auth.py,create,Authentication endpoints (login refresh logout)\n  src/models/user.py,create,User model with password hashing\n  src/utils/jwt.py,create,JWT token generation and validation\n  src/middleware/auth.py,create,Authentication middleware\n  src/services/email.py,modify,Add password reset and verification emails\n  src/config/redis.py,create,Redis session store configuration\n  src/api/rate_limit.py,create,Rate limiting decorator\n  tests/test_auth.py,create,Authentication endpoint tests\n  tests/test_jwt.py,create,JWT utility tests\n  tests/test_middleware.py,create,Middleware tests\n  requirements.txt,modify,Add PyJWT bcrypt redis dependencies\n  .env.example,modify,Add JWT_SECRET_KEY EMAIL_* config",
      "token_savings": "38.5%",
      "size_comparison": "JSON: 4200 tokens, TOON: 2583 tokens"
    }
  }
}
```

### Benefits

- **Backward Compatible**: JSON output неизменён (primary format)
- **Opt-in Optimization**: TOON добавляется только когда выгодно (>= 5 элементов)
- **Zero Breaking Changes**: Downstream consumers (phase-execution, validation-framework) читают JSON как раньше
- **Token Efficient**: 35-45% savings для standard/complex tasks

### Integration with Other Skills

**Producers (structured-planning):**
```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Generate JSON output (always)
const taskPlan = {
  task_name: "...",
  execution_steps: [...],  // 10 steps
  files_to_change: [...]   // 12 files
};

// Add TOON optimization (if threshold met)
if (taskPlan.execution_steps.length >= 5 || taskPlan.files_to_change.length >= 5) {

  const dataToConvert = {};
  taskPlan.toon = {};

  if (taskPlan.execution_steps.length >= 5) {
    // Simplified: only step_number, description, validation (actions inline in description)
    const stepsSimplified = taskPlan.execution_steps.map(step => ({
      step_number: step.step_number,
      description: `${step.description} (${step.actions.join(' ')})`,
      validation: step.validation
    }));

    taskPlan.toon.execution_steps_toon = arrayToToon('execution_steps', stepsSimplified,
      ['step_number', 'description', 'validation']);
    dataToConvert.execution_steps = taskPlan.execution_steps;
  }

  if (taskPlan.files_to_change.length >= 5) {
    taskPlan.toon.files_to_change_toon = arrayToToon('files_to_change', taskPlan.files_to_change,
      ['file_path', 'change_type', 'description']);
    dataToConvert.files_to_change = taskPlan.files_to_change;
  }

  const stats = calculateTokenSavings(dataToConvert);
  taskPlan.toon.token_savings = stats.savedPercent;
  taskPlan.toon.size_comparison = `JSON: ${stats.jsonTokens} tokens, TOON: ${stats.toonTokens} tokens`;
}

return { task_plan: taskPlan };
```

**Consumers (downstream skills like phase-execution, validation-framework):**
```javascript
import { toonToJson } from '../toon-skill/converters/toon-converter.mjs';

// Always read JSON (safest, backward compatible)
const executionSteps = taskPlanOutput.task_plan.execution_steps;

// Or prefer TOON if available (token efficient)
const executionSteps = taskPlanOutput.task_plan.toon?.execution_steps_toon
  ? toonToJson(taskPlanOutput.task_plan.toon.execution_steps_toon).execution_steps
  : taskPlanOutput.task_plan.execution_steps;
```

### Impact on Downstream Skills

**structured-planning используется многими skills:**
- **adaptive-workflow**: Читает task_plan для определения workflow mode
- **phase-execution**: Выполняет execution_steps
- **validation-framework**: Проверяет acceptance_criteria
- **git-workflow**: Использует git.branch_name и git.commit_summary

**Все downstream skills продолжают работать:**
- JSON output неизменён (100% backward compatible)
- TOON - дополнительное поле (opt-in)
- Никаких breaking changes

### Token Savings Examples

**Example 1: Standard task (10 steps, 12 files)**
- JSON: 4200 tokens
- TOON: 2583 tokens
- **Savings: 38.5% (1617 tokens saved)**

**Example 2: Complex task (15 steps, 20 files)**
- JSON: 6800 tokens
- TOON: 3876 tokens
- **Savings: 43% (2924 tokens saved)**

**Example 3: Minimal task (3 steps, 2 files)**
- JSON only: 850 tokens
- No TOON generation (below threshold)

### Special Handling: execution_steps.actions[]

**Challenge:** `execution_steps` содержит nested array `actions[]`:
```json
{
  "step_number": 1,
  "description": "Create authentication endpoints",
  "actions": ["POST /auth/login", "POST /auth/refresh", "POST /auth/logout"],
  "validation": "pytest tests/test_auth.py"
}
```

**Solution:** Inline actions в description при TOON generation:
```
execution_steps[10]{step_number,description,validation}:
  1,Create authentication endpoints (POST /auth/login POST /auth/refresh POST /auth/logout),pytest tests/test_auth.py
  ...
```

**Benefit:** Избегаем nested arrays (TOON лучше работает с табличными структурами)

### See Also

- **toon-skill** - Базовый навык для TOON API ([../toon-skill/SKILL.md](../toon-skill/SKILL.md))
- **TOON-PATTERNS.md** - Integration patterns ([../_shared/TOON-PATTERNS.md](../_shared/TOON-PATTERNS.md))
- **phase-execution** - Downstream consumer ([../phase-execution/SKILL.md](../phase-execution/SKILL.md))
- **validation-framework** - Uses acceptance_criteria ([../validation-framework/SKILL.md](../validation-framework/SKILL.md))
