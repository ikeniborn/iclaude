# Task Execution Template (Lite) v2.0 (Structured Output)

**Назначение:** Упрощенный шаблон для точечных доработок и небольших задач без декомпозиции на фазы.

---

## Конфигурация
- Режим: последовательное выполнение
- Thinking: enabled для критичных шагов (PRD, решения, риски)
- Structured Output: enabled (для планирования и validation)
- Валидация: critical_only (блокирующая для acceptance/PRD)
- Среда: локальная разработка (без /opt/, без запущенных сервисов)
- Git: обязателен (branch → commit → push)

## Принципы
1. **PRD Compliance** - все решения ДОЛЖНЫ соответствовать PRD из `docs/prd`
2. **Acceptance Criteria** - все критерии ДОЛЖНЫ быть выполнены
3. **Structured Plan** - план проходит JSON Schema validation
4. **Approval Gate** - plan ДОЛЖЕН быть согласован перед выполнением
5. **Минималистичный код** - код должен быть самодокументируемым
6. **Один коммит** - все изменения в одном git commit

---

## Задачи

1. Изучи шаблоны /home/ikeniborn/Documents/Notes/Work/ИИ/Prompt/Системные промты/template
2. Обдумай вариант реалиализации skillы для сlaude code в изолированной среде для оптимизации шабонов.
3. Задача оптимизировать шабон, уменьшив контекс и использовать типовые скилы в процессе раоыт с промтом .

---

## Процесс

### PHASE 1: АНАЛИЗ

---

#### **Шаг 1. [THINKING - ОБЯЗАТЕЛЬНО] Загрузить и изучить PRD**

```xml
<thinking>
ЗАДАЧА: [краткое описание от пользователя]
PRD СЕКЦИИ: [какие секции релевантны]
ACCEPTANCE CRITERIA: [идентифицировать из задачи]
ALIGNMENT: [проверить соответствие задачи PRD]
</thinking>
```

**Действия:**
- Прочитать `docs/prd` релевантные секции
- Проверить alignment задачи с PRD
- Идентифицировать acceptance criteria

**Exit Condition:**
- ✓ PRD прочитан
- ✓ Acceptance criteria идентифицированы

**Violation Action:**
- PRD конфликт → STOP, спросить пользователя

---

#### **Шаг 2. [THINKING - ОБЯЗАТЕЛЬНО] Проанализировать текущее состояние**

```xml
<thinking>
КОНТЕКСТ: [текущее состояние кодовой базы]
ROOT CAUSES: [что нужно изменить]
КОМПОНЕНТЫ: [какие файлы/модули затронуты]
СЛОЖНОСТЬ: [оценка объема работы]
</thinking>
```

**Действия:**
- Определить root causes
- Идентифицировать компоненты для изменения
- Оценить сложность

**Exit Condition:**
- ✓ Root causes определены
- ✓ Компоненты идентифицированы

---

#### **Шаг 3. ЗАДАТЬ УТОЧНЯЮЩИЕ ВОПРОСЫ (если требуется)**

**Когда спрашивать:**
- При неясности требований → СТОП и спросить
- При конфликте с PRD → СТОП и спросить

**Формат вопроса:**
```
❓ ТРЕБУЕТСЯ УТОЧНЕНИЕ
Неясно: [что конкретно]
Варианты: [опции]
Вопрос: [конкретный вопрос]
```

---

#### **Шаг 4. [THINKING - ОБЯЗАТЕЛЬНО] Обдумать решение**

```xml
<thinking>
КОНТЕКСТ: [текущая ситуация]
ЗАДАЧА: [что нужно сделать]
ОПЦИИ: [варианты с плюсами/минусами]
ВЫБОР: [вариант N] потому что [обоснование]
РИСКИ: [что может пойти не так]
ПРОВЕРКА: [как валидируем результат]
</thinking>
```

---

#### **Шаг 5. [STRUCTURED OUTPUT - BLOCKING] Создать план**

**Blocking:** `true`
**Output:** `required`
**Validation:** `critical`

**ОБЯЗАТЕЛЬНО вывести JSON:**

```json
{
  "task_plan": {
    "task_name": "string - краткое название задачи",
    "prd_sections": ["FR-XXX", "NFR-YYY"],

    "problem": "Описание проблемы, которую решаем",
    "solution": "Выбранный подход к решению",

    "acceptance_criteria": [
      "AC1: Критерий 1",
      "AC2: Критерий 2"
    ],

    "files_to_change": [
      {
        "file_path": "backend/app/services/service.py",
        "change_type": "modify",
        "description": "Добавить метод calculate_total"
      },
      {
        "file_path": "backend/app/api/v1/endpoints/facts.py",
        "change_type": "modify",
        "description": "Использовать новый метод"
      }
    ],

    "execution_steps": [
      {
        "step_number": 1,
        "description": "Git: создать ветку feature/task-name",
        "actions": ["git checkout master", "git checkout -b feature/task-name"],
        "validation": "git branch --show-current"
      },
      {
        "step_number": 2,
        "description": "Модифицировать service.py",
        "actions": [
          "Добавить метод calculate_total",
          "Реализовать логику подсчета"
        ],
        "validation": "python -m py_compile backend/app/services/service.py"
      },
      {
        "step_number": 3,
        "description": "Обновить endpoint facts.py",
        "actions": ["Использовать service.calculate_total"],
        "validation": "python -m py_compile backend/app/api/v1/endpoints/facts.py"
      },
      {
        "step_number": 4,
        "description": "Git: commit и push",
        "actions": [
          "git add [files]",
          "git commit -m 'feat: add calculate_total method'",
          "git push -u origin feature/task-name"
        ],
        "validation": "git log -1"
      }
    ],

    "risks": [
      {
        "risk": "Может сломать существующую логику",
        "mitigation": "Проверить существующие вызовы"
      }
    ],

    "validation": {
      "syntax_checks": [
        "python -m py_compile backend/app/services/service.py",
        "python -m py_compile backend/app/api/v1/endpoints/facts.py"
      ],
      "functional_checks": [
        "Проверить что calculate_total работает",
        "Проверить что endpoint возвращает корректные данные"
      ],
      "prd_compliance_checks": [
        "Проверить соответствие FR-XXX"
      ]
    },

    "git": {
      "branch_name": "feature/task-name",
      "base_branch": "master",
      "commit_type": "feat",
      "commit_summary": "add calculate_total method"
    }
  }
}
```

**JSON Schema:**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "task_plan": {
      "type": "object",
      "properties": {
        "task_name": {"type": "string", "minLength": 5},
        "prd_sections": {
          "type": "array",
          "minItems": 1,
          "items": {"type": "string"}
        },
        "problem": {"type": "string", "minLength": 10},
        "solution": {"type": "string", "minLength": 10},

        "acceptance_criteria": {
          "type": "array",
          "minItems": 1,
          "items": {"type": "string"}
        },

        "files_to_change": {
          "type": "array",
          "minItems": 1,
          "items": {
            "type": "object",
            "properties": {
              "file_path": {"type": "string"},
              "change_type": {
                "type": "string",
                "enum": ["create", "modify", "delete"]
              },
              "description": {"type": "string"}
            },
            "required": ["file_path", "change_type", "description"]
          }
        },

        "execution_steps": {
          "type": "array",
          "minItems": 2,
          "items": {
            "type": "object",
            "properties": {
              "step_number": {"type": "integer", "minimum": 1},
              "description": {"type": "string"},
              "actions": {
                "type": "array",
                "minItems": 1,
                "items": {"type": "string"}
              },
              "validation": {"type": "string"}
            },
            "required": ["step_number", "description", "actions", "validation"]
          }
        },

        "risks": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "risk": {"type": "string"},
              "mitigation": {"type": "string"}
            },
            "required": ["risk", "mitigation"]
          }
        },

        "validation": {
          "type": "object",
          "properties": {
            "syntax_checks": {
              "type": "array",
              "minItems": 1,
              "items": {"type": "string"}
            },
            "functional_checks": {
              "type": "array",
              "items": {"type": "string"}
            },
            "prd_compliance_checks": {
              "type": "array",
              "items": {"type": "string"}
            }
          },
          "required": ["syntax_checks", "functional_checks", "prd_compliance_checks"]
        },

        "git": {
          "type": "object",
          "properties": {
            "branch_name": {"type": "string", "pattern": "^feature/"},
            "base_branch": {"type": "string"},
            "commit_type": {
              "type": "string",
              "enum": ["feat", "fix", "refactor", "docs", "chore", "test"]
            },
            "commit_summary": {"type": "string", "maxLength": 72}
          },
          "required": ["branch_name", "base_branch", "commit_type", "commit_summary"]
        }
      },
      "required": [
        "task_name", "prd_sections", "problem", "solution",
        "acceptance_criteria", "files_to_change", "execution_steps",
        "validation", "git"
      ]
    }
  },
  "required": ["task_plan"]
}
```

**Затем вывести Markdown:**

```
═══════════════════════════════════════════════════════════
                         ПЛАН
═══════════════════════════════════════════════════════════

📋 ЗАДАЧА: {task_name}
📖 PRD: ✓ {prd_sections joined}

───────────────────────────────────────────────────────────

ПРОБЛЕМА:
{problem}

РЕШЕНИЕ:
{solution}

───────────────────────────────────────────────────────────

ФАЙЛЫ ДЛЯ ИЗМЕНЕНИЯ:

{для каждого file в files_to_change}
- {file_path} [{change_type}]
  └─ {description}

───────────────────────────────────────────────────────────

ШАГИ ВЫПОЛНЕНИЯ:

{для каждого step в execution_steps}
{step_number}. {description}
   Действия: {actions joined}
   Проверка: {validation}

───────────────────────────────────────────────────────────

ACCEPTANCE CRITERIA:

{для каждого criterion в acceptance_criteria}
- [ ] {criterion}

───────────────────────────────────────────────────────────

РИСКИ:

{для каждого risk в risks}
- {risk}
  → Митигация: {mitigation}

───────────────────────────────────────────────────────────

ВАЛИДАЦИЯ:

Syntax Checks:
{для каждой check в validation.syntax_checks}
- {check}

Functional Checks:
{для каждой check в validation.functional_checks}
- {check}

PRD Compliance:
{для каждой check в validation.prd_compliance_checks}
- {check}

───────────────────────────────────────────────────────────

GIT:

- Branch: {git.branch_name}
- Base: {git.base_branch}
- Commit: {git.commit_type}: {git.commit_summary}

═══════════════════════════════════════════════════════════
```

**Exit Conditions:**
- ✓ JSON Schema validation PASSED
- ✓ План содержит минимум 2 шага
- ✓ Все обязательные поля заполнены
- ✓ Markdown план выведен

**Violation Action:**
- Schema validation error → STOP, исправить структуру, RETRY

---

### PHASE 2: СОГЛАСОВАНИЕ

---

#### **[STRUCTURED OUTPUT - APPROVAL GATE] Получение подтверждения**

**Blocking:** `true`
**Output:** `required`

**ОБЯЗАТЕЛЬНО вывести:**

```
═══════════════════════════════════════════════════════════
            ⏸️  ТРЕБУЕТСЯ ПОДТВЕРЖДЕНИЕ
═══════════════════════════════════════════════════════════

План задачи создан и готов к выполнению.

📊 СТАТИСТИКА ПЛАНА:
- Файлов к изменению: {files_to_change.length}
- Шагов выполнения: {execution_steps.length}
- Acceptance Criteria: {acceptance_criteria.length}
- Рисков: {risks.length}

⚠️ ВНИМАНИЕ:
План будет выполнен автоматически после подтверждения.
Все изменения будут закоммичены в ветку {git.branch_name}.

───────────────────────────────────────────────────────────

ВОПРОС: Подтверждаете выполнение плана?

Ответьте:
- "да" / "yes" / "подтверждаю" - начать выполнение
- "нет" / "no" / "стоп" - остановить
- "изменить [что]" - внести корректировки в план

═══════════════════════════════════════════════════════════
```

**СТОП: Дождаться ответа пользователя**

**После получения подтверждения:**

ОБЯЗАТЕЛЬНО вывести JSON:
```json
{
  "approval": {
    "approved": true,
    "timestamp": "2025-11-17T10:30:00Z",
    "user_response": "да",
    "can_proceed_to_execution": true
  }
}
```

**Exit Conditions:**
- ✓ approval.approved = true
- ✓ can_proceed_to_execution = true

**Violation Action:**
- approved = false → STOP, НЕ выполнять план
- Запрос изменений → Вернуться к Phase 1, Шаг 5 (пересоздать план)

---

### PHASE 3: ВЫПОЛНЕНИЕ

**Entry Conditions:**
- ✓ approval.can_proceed_to_execution = true
- ✓ task_plan валидирован

---

#### **Шаг 1. Выполнение шагов**

Для каждого `step` в `task_plan.execution_steps[]`:

**a) Выполнить действия**
   - Следовать `step.actions[]`
   - Достичь результата из `step.description`

**Правила комментирования кода:**

✅ **ПИСАТЬ комментарии ТОЛЬКО для:**
1. Сложной бизнес-логики, которая неочевидна из кода (алгоритмы, формулы)
2. Критичных решений и их обоснования (почему выбран этот подход)
3. Workarounds и временных решений (FIXME, TODO с объяснением)
4. API endpoints - краткое описание назначения (1-2 строки)
5. Регулярные выражения и сложные SQL запросы
6. Docstrings для публичных функций/классов (краткие, без очевидностей)

❌ **НЕ ПИСАТЬ комментарии для:**
1. Очевидных операций (например: `# Создаем пользователя` над `user = User()`)
2. Переменных с понятными именами (код должен быть самодокументируемым)
3. Пересказа кода на естественном языке
4. Закомментированного кода (удалять, не оставлять)
5. Устаревших комментариев (обновлять или удалять)
6. Дублирования информации из type hints

**b) Валидация шага**
   ```bash
   # Выполнить команду из step.validation
   ```

**c) Вывести статус**
   ```
   ✓ Шаг {step_number} выполнен: {description}
   ```

**Exit Conditions:**
- ✓ Все шаги из task_plan.execution_steps выполнены
- ✓ Каждый step.validation пройден
- ✓ НЕ запускались сервисы/интеграционные тесты

---

### PHASE 4: ВАЛИДАЦИЯ (БЛОКИРУЮЩАЯ)

**Entry Conditions:**
- ✓ Все шаги выполнения завершены

---

#### **[STRUCTURED OUTPUT - BLOCKING] Критичные проверки**

**Blocking:** `true`
**Output:** `required`
**Validation:** `critical`

**ОБЯЗАТЕЛЬНО вывести JSON:**

```json
{
  "validation_results": {
    "acceptance_criteria": {
      "total": 2,
      "met": 2,
      "not_met": 0,
      "details": [
        {
          "criterion": "AC1: Service должен обрабатывать запросы",
          "status": "met",
          "evidence": "Метод calculate_total создан и работает"
        },
        {
          "criterion": "AC2: API endpoint должен использовать новый метод",
          "status": "met",
          "evidence": "Endpoint обновлен, использует service.calculate_total"
        }
      ]
    },

    "prd_compliance": {
      "compliant": true,
      "conflicts": [],
      "checks_performed": [
        {
          "prd_section": "FR-XXX",
          "requirement": "Система должна рассчитывать общую сумму",
          "status": "compliant",
          "evidence": "Метод calculate_total реализует требование"
        }
      ]
    },

    "syntax_checks": {
      "total_files": 2,
      "passed": 2,
      "failed": 0,
      "details": [
        {
          "file": "backend/app/services/service.py",
          "status": "passed",
          "command": "python -m py_compile backend/app/services/service.py"
        },
        {
          "file": "backend/app/api/v1/endpoints/facts.py",
          "status": "passed",
          "command": "python -m py_compile backend/app/api/v1/endpoints/facts.py"
        }
      ]
    },

    "functional_checks": {
      "total": 2,
      "passed": 2,
      "failed": 0,
      "details": [
        {
          "check": "Проверить что calculate_total работает",
          "status": "passed",
          "evidence": "Метод вызывается, возвращает корректный результат"
        },
        {
          "check": "Проверить что endpoint возвращает корректные данные",
          "status": "passed",
          "evidence": "Endpoint использует новый метод"
        }
      ]
    },

    "overall_status": "PASSED",
    "can_proceed_to_finalization": true,
    "blocking_issues": []
  }
}
```

**JSON Schema:**
```json
{
  "type": "object",
  "properties": {
    "validation_results": {
      "type": "object",
      "properties": {
        "acceptance_criteria": {
          "type": "object",
          "properties": {
            "total": {"type": "integer", "minimum": 1},
            "met": {"type": "integer"},
            "not_met": {"type": "integer"},
            "details": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "criterion": {"type": "string"},
                  "status": {"type": "string", "enum": ["met", "not_met"]},
                  "evidence": {"type": "string"}
                },
                "required": ["criterion", "status", "evidence"]
              }
            }
          },
          "required": ["total", "met", "not_met", "details"]
        },

        "prd_compliance": {
          "type": "object",
          "properties": {
            "compliant": {"type": "boolean"},
            "conflicts": {
              "type": "array",
              "items": {"type": "string"}
            },
            "checks_performed": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "prd_section": {"type": "string"},
                  "requirement": {"type": "string"},
                  "status": {"type": "string", "enum": ["compliant", "non_compliant"]},
                  "evidence": {"type": "string"}
                },
                "required": ["prd_section", "requirement", "status", "evidence"]
              }
            }
          },
          "required": ["compliant", "conflicts", "checks_performed"]
        },

        "syntax_checks": {
          "type": "object",
          "properties": {
            "total_files": {"type": "integer"},
            "passed": {"type": "integer"},
            "failed": {"type": "integer"},
            "details": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "file": {"type": "string"},
                  "status": {"type": "string", "enum": ["passed", "failed"]},
                  "command": {"type": "string"}
                },
                "required": ["file", "status", "command"]
              }
            }
          },
          "required": ["total_files", "passed", "failed", "details"]
        },

        "functional_checks": {
          "type": "object",
          "properties": {
            "total": {"type": "integer"},
            "passed": {"type": "integer"},
            "failed": {"type": "integer"},
            "details": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "check": {"type": "string"},
                  "status": {"type": "string", "enum": ["passed", "failed"]},
                  "evidence": {"type": "string"}
                },
                "required": ["check", "status", "evidence"]
              }
            }
          },
          "required": ["total", "passed", "failed", "details"]
        },

        "overall_status": {"type": "string", "enum": ["PASSED", "FAILED"]},
        "can_proceed_to_finalization": {"type": "boolean"},
        "blocking_issues": {
          "type": "array",
          "items": {"type": "string"}
        }
      },
      "required": [
        "acceptance_criteria", "prd_compliance", "syntax_checks",
        "functional_checks", "overall_status", "can_proceed_to_finalization", "blocking_issues"
      ]
    }
  },
  "required": ["validation_results"]
}
```

**Validation Rules:**
```javascript
// Логика определения overall_status
validation_results.overall_status = "PASSED" if (
  acceptance_criteria.met === acceptance_criteria.total &&
  prd_compliance.compliant === true &&
  syntax_checks.failed === 0 &&
  functional_checks.failed === 0
) else "FAILED"

validation_results.can_proceed_to_finalization = (overall_status === "PASSED")

// Blocking issues
if (acceptance_criteria.not_met > 0) {
  blocking_issues.push(`${not_met} acceptance criteria not met`)
}
if (!prd_compliance.compliant) {
  blocking_issues.push("PRD compliance failed")
}
if (syntax_checks.failed > 0) {
  blocking_issues.push(`${failed} syntax checks failed`)
}
```

**Затем вывести Markdown:**

```
═══════════════════════════════════════════════════════════
              ВАЛИДАЦИЯ ЗАВЕРШЕНА
═══════════════════════════════════════════════════════════

ACCEPTANCE CRITERIA: {met}/{total}

{для каждого criterion в acceptance_criteria.details}
[{status === "met" ? "✓" : "✗"}] {criterion}
    └─ {evidence}

───────────────────────────────────────────────────────────

PRD COMPLIANCE: {compliant ? "✓ COMPLIANT" : "✗ NON-COMPLIANT"}

{для каждой check в prd_compliance.checks_performed}
[{status === "compliant" ? "✓" : "✗"}] {prd_section}: {requirement}
    └─ {evidence}

{если conflicts не пусто}
⚠️ КОНФЛИКТЫ:
{для каждого conflict}
- {conflict}

───────────────────────────────────────────────────────────

SYNTAX CHECKS: {passed}/{total_files}

{для каждого file в syntax_checks.details}
[{status === "passed" ? "✓" : "✗"}] {file}

───────────────────────────────────────────────────────────

FUNCTIONAL CHECKS: {functional_checks.passed}/{functional_checks.total}

{для каждой check в functional_checks.details}
[{status === "passed" ? "✓" : "✗"}] {check}
    └─ {evidence}

───────────────────────────────────────────────────────────

РЕЗУЛЬТАТ: {overall_status}
Переход к финализации: {can_proceed_to_finalization ? "ALLOWED" : "BLOCKED"}

{если blocking_issues не пусто}
🛑 БЛОКИРУЮЩИЕ ПРОБЛЕМЫ:
{для каждой issue}
- {issue}

═══════════════════════════════════════════════════════════
```

**Exit Conditions:**
- ✓ overall_status = "PASSED"
- ✓ can_proceed_to_finalization = true
- ✓ blocking_issues = []

**Violation Action:**
- overall_status = "FAILED" → BLOCKING, исправить проблемы
- can_proceed_to_finalization = false → STOP
- Max 2 попытки исправления, затем STOP, спросить пользователя

---

### PHASE 5: ФИНАЛИЗАЦИЯ

**Entry Conditions:**
- ✓ validation_results.can_proceed_to_finalization = true

---

#### **Шаг 1. Обновить документацию PRD (если требуется)**

Если задача меняет функциональность, задокументированную в PRD:
- Обновить релевантные секции в `docs/prd`
- Добавить версионирование изменений

---

#### **Шаг 2. [STRUCTURED OUTPUT] Подготовить changelog entry**

**Output:** `required`

**ОБЯЗАТЕЛЬНО вывести JSON:**

```json
{
  "changelog_entry": {
    "category": "Features",
    "title": "Добавлен метод calculate_total",

    "changes": [
      "✨ Создан метод calculate_total в service",
      "🔧 Обновлен endpoint для использования нового метода"
    ],

    "user_impact": "Пользователи получат более точный расчет общей суммы",

    "technical_details": {
      "files_changed": [
        "backend/app/services/service.py",
        "backend/app/api/v1/endpoints/facts.py"
      ],
      "prd_sections": ["FR-XXX"],
      "commits": []
    },

    "breaking_changes": null
  }
}
```

**Затем вывести Markdown:**

```markdown
### [Features] Добавлен метод calculate_total

**Изменения:**
- ✨ Создан метод calculate_total в service
- 🔧 Обновлен endpoint для использования нового метода

**Влияние на пользователей:**
Пользователи получат более точный расчет общей суммы

**Технические детали:**
- Файлы: `backend/app/services/service.py`, `backend/app/api/v1/endpoints/facts.py`
- PRD: FR-XXX
- Commits: (будет добавлено после git commit)

**Breaking Changes:** Нет
```

---

#### **Шаг 3. [STRUCTURED OUTPUT] Git commit и push**

**Blocking:** `true`
**Output:** `required`

**Действия:**

```bash
# Получить файлы из task_plan.files_to_change
git add {files}

# Commit message из task_plan.git
git commit -m "{commit_type}: {commit_summary}

{детальное описание изменений}

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Push
git push -u origin {branch_name}
```

**ОБЯЗАТЕЛЬНО вывести JSON:**

```json
{
  "git_commit": {
    "branch": "feature/task-name",
    "commit_hash": "abc123def456",
    "commit_type": "feat",
    "commit_summary": "add calculate_total method",
    "files_committed": [
      "backend/app/services/service.py",
      "backend/app/api/v1/endpoints/facts.py"
    ],
    "commit_status": "success",
    "pushed": true,
    "push_status": "success"
  }
}
```

**Exit Conditions:**
- ✓ commit_status = "success"
- ✓ pushed = true
- ✓ push_status = "success"

**Violation Action:**
- commit_status = "failed" → STOP, проверить git ошибку
- push_status = "failed" → STOP, проверить git push ошибку

---

#### **Шаг 4. [STRUCTURED OUTPUT] Вывести SUMMARY**

**Output:** `required`

**ОБЯЗАТЕЛЬНО вывести JSON:**

```json
{
  "task_summary": {
    "task_name": "Добавлен метод calculate_total",
    "status": "completed",

    "changes_made": [
      "Создан метод calculate_total в service.py",
      "Обновлен endpoint facts.py для использования нового метода"
    ],

    "files_changed": [
      {
        "file": "backend/app/services/service.py",
        "change_type": "modify",
        "description": "Добавлен метод calculate_total"
      },
      {
        "file": "backend/app/api/v1/endpoints/facts.py",
        "change_type": "modify",
        "description": "Использует service.calculate_total"
      }
    ],

    "acceptance_criteria_met": [
      "AC1: Service должен обрабатывать запросы",
      "AC2: API endpoint должен использовать новый метод"
    ],

    "prd_compliance": "compliant",

    "decisions": [
      {
        "decision": "Использовать метод в service вместо дублирования логики",
        "rationale": "DRY принцип, легче тестировать"
      }
    ],

    "git_info": {
      "branch": "feature/task-name",
      "base_branch": "master",
      "commit_hash": "abc123def",
      "pushed": true
    },

    "changelog_ready": true,

    "next_steps": [
      "Создать PR из feature/task-name в master",
      "Добавить changelog entry в GitHub Release"
    ]
  }
}
```

**Затем вывести Markdown:**

```
═══════════════════════════════════════════════════════════
                ✅ ЗАДАЧА ЗАВЕРШЕНА
═══════════════════════════════════════════════════════════

СТАТУС: ✓ COMPLETED

───────────────────────────────────────────────────────────

СДЕЛАНО:

{для каждого change в changes_made}
- {change}

───────────────────────────────────────────────────────────

ФАЙЛЫ:

{для каждого file в files_changed}
- {file.file} [{file.change_type}]
  └─ {file.description}

───────────────────────────────────────────────────────────

ACCEPTANCE CRITERIA:

{для каждого criterion в acceptance_criteria_met}
✓ {criterion}

───────────────────────────────────────────────────────────

PRD COMPLIANCE: ✓ {prd_compliance}

───────────────────────────────────────────────────────────

РЕШЕНИЯ:

{для каждого decision в decisions}
- {decision.decision}
  └─ Обоснование: {decision.rationale}

───────────────────────────────────────────────────────────

GIT:

- Branch: {git_info.branch}
- Base: {git_info.base_branch}
- Commit: {git_info.commit_hash}
- Status: {git_info.pushed ? "✓ pushed" : "⏳ not pushed"}

───────────────────────────────────────────────────────────

CHANGELOG ENTRY:

{changelog entry из шага 2}

───────────────────────────────────────────────────────────

NEXT STEPS:

{для каждого step в next_steps}
- [ ] {step}

═══════════════════════════════════════════════════════════
```

**Exit Conditions:**
- ✓ Summary JSON сгенерирован
- ✓ Markdown display выведен
- ✓ Задача ЗАВЕРШЕНА

---

## Error Handling

**PRD_CONFLICT:**
- Action: STOP
- Message: "❌ ОШИБКА: Конфликт с PRD\nПроблема: {описание}\nДействие: Уточнить у пользователя"

**JSON_SCHEMA_VALIDATION_ERROR:**
- Action: STOP
- Message: "❌ ОШИБКА: Structured Output не прошел валидацию\nПроблема: {schema error}\nКонтекст: {шаг}\nДействие: RETRY с исправлением"

**ACCEPTANCE_FAIL:**
- Action: RETRY (max 2 attempts)
- Message: "⚠️ Acceptance criteria не выполнены\nНе выполнено: {список}\nДействие: Исправить, попытка {N}/2"

**SYNTAX_ERROR:**
- Action: STOP
- Message: "❌ ОШИБКА: Syntax error\nФайл: {file}\nОшибка: {error}\nДействие: Исправить немедленно"

**APPROVAL_REJECTED:**
- Action: STOP
- Message: "🛑 План отклонен пользователем\nДействие: Завершение работы"

**VALIDATION_FAILED:**
- Action: BLOCKING
- Message: "🛑 VALIDATION FAILED\nПроблемы: {blocking_issues}\nДействие: Исправить ошибки"

**GIT_COMMIT_FAILED:**
- Action: STOP
- Message: "❌ ОШИБКА: Git commit failed\nОшибка: {error}\nДействие: Проверить git status"

---

## Startup Sequence

**КРИТИЧНО - выполнить СТРОГО в этом порядке:**

1. ✓ Прочитать задачи из промпта
2. ✓ **ПЕРВЫМ ДЕЛОМ** загрузить PRD из `docs/prd`
3. ✓ Шаг 1: THINKING - анализ PRD
4. ✓ Шаг 2: THINKING - анализ кодовой базы
5. ✓ Шаг 3: Задать вопросы (если требуется)
6. ✓ Шаг 4: THINKING - обдумать решение
7. ✓ Шаг 5: STRUCTURED OUTPUT - создать план (JSON validation)
8. ✓ Phase 2: STRUCTURED OUTPUT - approval gate
9. ✓ Phase 3: Выполнение шагов
10. ✓ Phase 4: STRUCTURED OUTPUT - валидация (BLOCKING)
11. ✓ Phase 5 Шаг 1: Обновить PRD (если требуется)
12. ✓ Phase 5 Шаг 2: STRUCTURED OUTPUT - changelog
13. ✓ Phase 5 Шаг 3: STRUCTURED OUTPUT - git commit
14. ✓ Phase 5 Шаг 4: STRUCTURED OUTPUT - summary

**Enforcement:**
- НЕ пропускать ни одного шага
- НЕ менять порядок
- При конфликте с PRD - немедленная ОСТАНОВКА
- При schema validation error - STOP, RETRY
- При validation FAILED - BLOCKING

---

## Важные напоминания

### ✅ ВСЕГДА ДЕЛАЙТЕ:
- ✓ Используйте THINKING для reasoning
- ✓ Используйте STRUCTURED OUTPUT для validation
- ✓ План ДОЛЖЕН быть согласован перед выполнением
- ✓ Проверяйте acceptance criteria ОБЯЗАТЕЛЬНО
- ✓ Проверяйте PRD compliance ОБЯЗАТЕЛЬНО
- ✓ Делайте git commit и push
- ✓ Генерируйте changelog entry

### ❌ НИКОГДА НЕ ДЕЛАЙТЕ:
- ❌ НЕ пропускайте approval gate
- ❌ НЕ пропускайте structured output validation
- ❌ НЕ продолжайте при schema validation errors
- ❌ НЕ продолжайте при validation FAILED
- ❌ НЕ начинайте выполнение без подтверждения пользователя
- ❌ НЕ пропускайте acceptance criteria проверку

---

## Преимущества v2.0

### Structured Output обеспечивает:
1. ✅ **Гарантию полноты плана** (все обязательные поля через schema)
2. ✅ **Программный approval gate** (approval.approved boolean)
3. ✅ **Полную валидацию** (acceptance, PRD, syntax, functional)
4. ✅ **Enforcement git commit** (commit_hash validation)
5. ✅ **Структурированный changelog** (category, changes, impact)
6. ✅ **Детальный summary** (все секции обязательны)

### vs v1.0:
- ❌ v1.0: Claude мог пропустить план
- ✅ v2.0: Schema validation ОШИБКА если план неполный

- ❌ v1.0: Claude мог проигнорировать "СТОП"
- ✅ v2.0: STRUCTURED approval gate с boolean

- ❌ v1.0: Claude мог пропустить acceptance criteria
- ✅ v2.0: BLOCKING если acceptance_criteria.not_met > 0

- ❌ v1.0: Claude мог забыть git commit
- ✅ v2.0: STRUCTURED OUTPUT с commit_hash валидацией

---

## Версия
**Template Version:** 2.0
**Дата:** 2025-11-17
**Изменения:**
- Добавлен structured output для плана, approval gate, validation, git commit, changelog, summary
- Усилен enforcement через JSON Schema
- Добавлена программная approval gate
- Улучшена валидация (acceptance, PRD, syntax, functional)
- Добавлены строгие entry/exit conditions
