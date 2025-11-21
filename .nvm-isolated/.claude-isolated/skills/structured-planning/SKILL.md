---
name: Structured Planning
description: Создание структурированных планов задач с JSON Schema валидацией и Markdown форматированием
version: 1.0.0
author: Claude Code Team
tags: [planning, json-schema, structured-output, validation, task-management]
dependencies: [thinking-framework]
---

# Structured Planning

Автоматизация создания детальных, структурированных планов задач с JSON Schema валидацией. Этот скил обеспечивает консистентный формат планирования для любых проектов, гарантируя полноту и правильность планов через программную валидацию.

## Когда использовать этот скил

Используй этот скил когда нужно:
- Создать структурированный план задачи с JSON валидацией
- Спланировать execution steps для задачи
- Определить файлы для изменения (create/modify/delete)
- Идентифицировать риски и митигации
- Спланировать валидацию результатов (syntax, functional, PRD compliance)
- Подготовить git workflow (branch, commit type)
- Обеспечить полноту плана (acceptance criteria, все обязательные секции)

Скил автоматически вызывается при запросах типа:
- "Создай план для добавления новой функции X"
- "Спланируй задачу с валидацией acceptance criteria"
- "Подготовь структурированный план с execution steps"
- "Создай JSON план для рефакторинга модуля Y"

## Контекст проекта

### Философия Structured Planning

**Принципы:**
- **Программная валидация:** JSON Schema гарантирует полноту плана
- **Mandatory outputs:** План ОБЯЗАТЕЛЬНО содержит все критичные секции
- **Approval gate ready:** План готов для программного approval gate
- **Self-contained:** План содержит ВСЮ информацию для выполнения
- **Traceable:** Каждый шаг имеет validation command

### Архитектура плана

```
task_plan
├── Метаданные (task_name, prd_sections)
├── Контекст (problem, solution)
├── Acceptance Criteria (минимум 1 критерий)
├── Файлы (files_to_change с change_type)
├── Шаги выполнения (execution_steps с validation)
├── Риски (risks с mitigation)
├── Валидация (syntax/functional/PRD checks)
└── Git (branch, commit type, summary)
```

### Типы изменений файлов

- **create:** Создание нового файла (для новых модулей, функций)
- **modify:** Изменение существующего файла (большинство задач)
- **delete:** Удаление файла (удаление deprecated кода)

### Типы commit (Conventional Commits)

- **feat:** Новая функциональность
- **fix:** Исправление ошибки
- **refactor:** Рефакторинг без изменения функциональности
- **docs:** Только документация
- **chore:** Обслуживание, CI/CD, зависимости
- **test:** Добавление или исправление тестов

## Шаблоны

### Шаблон 1: Полный JSON Plan

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
        "file_path": "path/to/file.py",
        "change_type": "modify",
        "description": "Краткое описание изменения"
      }
    ],

    "execution_steps": [
      {
        "step_number": 1,
        "description": "Что делаем на этом шаге",
        "actions": ["Действие 1", "Действие 2"],
        "validation": "command для проверки шага"
      }
    ],

    "risks": [
      {
        "risk": "Что может пойти не так",
        "mitigation": "Как предотвратить или минимизировать"
      }
    ],

    "validation": {
      "syntax_checks": [
        "python -m py_compile file.py"
      ],
      "functional_checks": [
        "Проверка функциональности"
      ],
      "prd_compliance_checks": [
        "Проверка соответствия PRD"
      ]
    },

    "git": {
      "branch_name": "feature/task-name",
      "base_branch": "master",
      "commit_type": "feat",
      "commit_summary": "краткое описание (max 72 chars)"
    }
  }
}
```

### Шаблон 2: JSON Schema для валидации

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
            "branch_name": {"type": "string", "pattern": "^(feature|fix|refactor|docs|chore|test)/"},
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

### Шаблон 3: Markdown Output для плана

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

### Шаблон 4: Execution Step Template

```json
{
  "step_number": N,
  "description": "Что делаем (например: Git: создать ветку)",
  "actions": [
    "git checkout master",
    "git checkout -b feature/task-name"
  ],
  "validation": "git branch --show-current"
}
```

**Типичные validation commands:**
- **Git:** `git branch --show-current`, `git log -1`, `git status`
- **Python:** `python -m py_compile <file>`, `pytest tests/`
- **JavaScript:** `node --check <file>`, `npm test`
- **TypeScript:** `tsc --noEmit <file>`
- **Bash:** `bash -n <file>`

### Шаблон 5: File Change Template

```json
{
  "file_path": "path/to/file",
  "change_type": "modify",
  "description": "Краткое описание изменения"
}
```

**Примеры:**
```json
[
  {
    "file_path": "backend/app/services/service.py",
    "change_type": "create",
    "description": "Создать новый сервис для обработки заказов"
  },
  {
    "file_path": "backend/app/api/v1/endpoints/orders.py",
    "change_type": "modify",
    "description": "Добавить endpoint GET /orders/{id}"
  },
  {
    "file_path": "backend/app/deprecated/old_service.py",
    "change_type": "delete",
    "description": "Удалить deprecated сервис"
  }
]
```

---

## Phase-Based Planning

### Когда использовать Phase-Based Planning

Используй phase-based planning когда задача:
- **Слишком большая** для одного коммита (>5 файлов, >3 компонентов)
- **Логически разбивается** на независимые части (backend → frontend, setup → implementation)
- **Требует промежуточных коммитов** (для review, для безопасности)
- **Имеет естественные границы** (Phase 1: Git Setup, Phase 2: Backend, Phase 3: Frontend)

**Процесс:**
1. **Planning Stage**: Используй task-decomposition skill → создается `plans/` директория с master plan и phase files
2. **Execution Stage**: Для каждой фазы используй phase-execution skill → выполнение одной фазы с отдельным коммитом

### Шаблон 6: Phase Metadata JSON (для парсинга phase files)

**Назначение:** Парсинг phase file в structured format для выполнения.

```json
{
  "phase_metadata": {
    "phase_number": 1,
    "phase_name": "Git Setup + Component A",
    "total_phases": 3,
    "goal": "Создать ветку и реализовать компонент A",

    "context": {
      "branch_name": "feature/task-name",
      "base_branch": "master",
      "previous_changes_summary": "N/A (первая фаза)",
      "dependencies": []
    },

    "steps": [
      {
        "step_number": 1,
        "step_name": "Создать git ветку",
        "actions": [
          "git checkout master",
          "git checkout -b feature/task-name",
          "git push -u origin feature/task-name"
        ],
        "expected_result": "Ветка создана и запушена",
        "affected_files": []
      },
      {
        "step_number": 2,
        "step_name": "Создать service",
        "actions": [
          "Создать backend/app/services/service_a.py",
          "Реализовать основные методы"
        ],
        "expected_result": "Service создан с базовой логикой",
        "affected_files": ["backend/app/services/service_a.py"]
      }
    ],

    "completion_criteria": [
      "Service создан и протестирован",
      "Syntax check passed",
      "Git commit сделан"
    ],

    "commit_message": {
      "type": "feat",
      "summary": "add service A with basic logic",
      "body": "- Created service A\n- Implemented basic methods"
    },

    "risks": [
      {
        "risk": "Конфликт с существующим сервисом",
        "mitigation": "Проверить namespace перед созданием"
      }
    ],

    "validation": {
      "syntax_checks": [
        "python -m py_compile backend/app/services/service_a.py"
      ],
      "functional_checks": [
        "Проверить импорт service",
        "Проверить основные методы"
      ]
    }
  }
}
```

### Шаблон 7: Phase Metadata JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "phase_metadata": {
      "type": "object",
      "properties": {
        "phase_number": {"type": "integer", "minimum": 1},
        "phase_name": {"type": "string", "minLength": 5},
        "total_phases": {"type": "integer", "minimum": 1},
        "goal": {"type": "string", "minLength": 10},

        "context": {
          "type": "object",
          "properties": {
            "branch_name": {"type": "string"},
            "base_branch": {"type": "string"},
            "previous_changes_summary": {"type": "string"},
            "dependencies": {
              "type": "array",
              "items": {"type": "integer"}
            }
          },
          "required": ["branch_name", "base_branch", "previous_changes_summary", "dependencies"]
        },

        "steps": {
          "type": "array",
          "minItems": 1,
          "items": {
            "type": "object",
            "properties": {
              "step_number": {"type": "integer"},
              "step_name": {"type": "string"},
              "actions": {
                "type": "array",
                "minItems": 1,
                "items": {"type": "string"}
              },
              "expected_result": {"type": "string"},
              "affected_files": {
                "type": "array",
                "items": {"type": "string"}
              }
            },
            "required": ["step_number", "step_name", "actions", "expected_result", "affected_files"]
          }
        },

        "completion_criteria": {
          "type": "array",
          "minItems": 1,
          "items": {"type": "string"}
        },

        "commit_message": {
          "type": "object",
          "properties": {
            "type": {"type": "string", "enum": ["feat", "fix", "refactor", "docs", "chore", "test"]},
            "summary": {"type": "string", "maxLength": 72},
            "body": {"type": "string"}
          },
          "required": ["type", "summary", "body"]
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
              "items": {"type": "string"}
            },
            "functional_checks": {
              "type": "array",
              "items": {"type": "string"}
            }
          },
          "required": ["syntax_checks", "functional_checks"]
        }
      },
      "required": [
        "phase_number", "phase_name", "total_phases", "goal",
        "context", "steps", "completion_criteria", "commit_message", "validation"
      ]
    }
  },
  "required": ["phase_metadata"]
}
```

### Шаблон 8: Task Decomposition JSON

**Назначение:** Декомпозиция задачи на 2-5 логических фаз для phase-based execution.

```json
{
  "task_decomposition": {
    "task_name": "Добавить аутентификацию пользователей",
    "prd_sections": ["FR-XXX", "NFR-YYY"],
    "base_branch": "master",
    "feature_branch": "feature/user-authentication",
    "total_phases": 3,

    "phases": [
      {
        "phase_number": 1,
        "name": "Git Setup + Backend Models",
        "goal": "Создать ветку и базовые модели пользователя",
        "affected_files": [
          "backend/app/models/user.py",
          "backend/app/schemas/user.py"
        ],
        "steps": [
          {
            "step_number": 1,
            "step_name": "Создать git ветку",
            "actions": [
              "git checkout -b feature/user-authentication",
              "git push -u origin feature/user-authentication"
            ],
            "expected_result": "Ветка создана и запушена"
          },
          {
            "step_number": 2,
            "step_name": "Создать User model",
            "actions": [
              "Создать backend/app/models/user.py",
              "Реализовать User SQLAlchemy model"
            ],
            "expected_result": "User model создан"
          },
          {
            "step_number": 3,
            "step_name": "Создать User schemas",
            "actions": [
              "Создать backend/app/schemas/user.py",
              "Реализовать UserCreate, UserRead schemas"
            ],
            "expected_result": "Schemas созданы"
          }
        ],
        "completion_criteria": [
          "User model создан",
          "Schemas созданы",
          "Syntax checks passed"
        ],
        "commit_type": "feat",
        "commit_summary": "add user model and schemas",
        "estimated_time": "30-45 min",
        "risks": [
          {
            "risk": "Конфликт с существующей user table",
            "mitigation": "Проверить database schema перед созданием"
          }
        ]
      }
    ],

    "acceptance_criteria_mapping": [
      {
        "criterion": "AC1: Пользователи могут регистрироваться",
        "mapped_to_phases": [1, 2]
      },
      {
        "criterion": "AC2: Пользователи могут входить в систему",
        "mapped_to_phases": [2, 3]
      }
    ],

    "global_risks": [
      {
        "risk": "Изменения могут сломать существующую аутентификацию",
        "mitigation": "Запустить полный test suite после каждой фазы"
      }
    ],

    "validation": {
      "all_acceptance_criteria_covered": true,
      "phases_logically_complete": true,
      "dependencies_minimal": true,
      "phase_count_adequate": true
    }
  }
}
```

### Шаблон 9: Task Decomposition JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "task_decomposition": {
      "type": "object",
      "properties": {
        "task_name": {"type": "string", "minLength": 5, "maxLength": 100},
        "prd_sections": {
          "type": "array",
          "minItems": 1,
          "items": {"type": "string"}
        },
        "base_branch": {"type": "string"},
        "feature_branch": {"type": "string", "pattern": "^feature/"},
        "total_phases": {"type": "integer", "minimum": 2, "maximum": 5},

        "phases": {
          "type": "array",
          "minItems": 2,
          "maxItems": 5,
          "items": {
            "type": "object",
            "properties": {
              "phase_number": {"type": "integer", "minimum": 1},
              "name": {"type": "string", "minLength": 10, "maxLength": 80},
              "goal": {"type": "string", "minLength": 20},
              "affected_files": {
                "type": "array",
                "minItems": 1,
                "items": {"type": "string"}
              },
              "steps": {
                "type": "array",
                "minItems": 3,
                "maxItems": 7,
                "items": {
                  "type": "object",
                  "properties": {
                    "step_number": {"type": "integer"},
                    "step_name": {"type": "string"},
                    "actions": {
                      "type": "array",
                      "minItems": 1,
                      "items": {"type": "string"}
                    },
                    "expected_result": {"type": "string"}
                  },
                  "required": ["step_number", "step_name", "actions", "expected_result"]
                }
              },
              "completion_criteria": {
                "type": "array",
                "minItems": 2,
                "items": {"type": "string"}
              },
              "commit_type": {
                "type": "string",
                "enum": ["feat", "fix", "refactor", "docs", "chore", "test", "perf"]
              },
              "commit_summary": {"type": "string", "maxLength": 72},
              "estimated_time": {"type": "string"},
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
              }
            },
            "required": [
              "phase_number", "name", "goal", "affected_files",
              "steps", "completion_criteria", "commit_type", "commit_summary"
            ]
          }
        },

        "acceptance_criteria_mapping": {
          "type": "array",
          "minItems": 1,
          "items": {
            "type": "object",
            "properties": {
              "criterion": {"type": "string"},
              "mapped_to_phases": {
                "type": "array",
                "minItems": 1,
                "items": {"type": "integer"}
              }
            },
            "required": ["criterion", "mapped_to_phases"]
          }
        },

        "global_risks": {
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
            "all_acceptance_criteria_covered": {"type": "boolean"},
            "phases_logically_complete": {"type": "boolean"},
            "dependencies_minimal": {"type": "boolean"},
            "phase_count_adequate": {"type": "boolean"}
          },
          "required": [
            "all_acceptance_criteria_covered",
            "phases_logically_complete",
            "dependencies_minimal",
            "phase_count_adequate"
          ]
        }
      },
      "required": [
        "task_name", "prd_sections", "total_phases", "phases",
        "acceptance_criteria_mapping", "validation"
      ]
    }
  },
  "required": ["task_decomposition"]
}
```

### Шаблон 10: Master Plan Generation

**Назначение:** Генерация master-plan.md из task_decomposition JSON.

**Входные данные:** `task_decomposition` JSON
**Выходной файл:** `plans/master-plan.md`

```markdown
# Master Plan: {task_name}

## Metadata
- **Дата создания:** {YYYY-MM-DD HH:MM}
- **PRD секции:** {prd_sections joined}
- **Ветка:** {feature_branch}
- **База:** {base_branch}

## Общий обзор

### Проблема
{извлечь из thinking: ROOT CAUSES}

### Решение
{извлечь из thinking: общий подход}

### Затронутые компоненты
{для каждой уникальной affected_files из всех фаз}
- {component} - {описание}

## Декомпозиция на фазы

{для каждой phase в phases[]}
### Phase {phase_number}: {name}
**Цель:** {goal}
**Файлы:** {affected_files joined}
**Шаги:** {steps.length} шагов
**Время:** ~{estimated_time}
**Детали:** `plans/phase-{phase_number}-{slug}.md`

## Общие риски

{для каждого risk в global_risks}
- {risk} → {mitigation}

## Acceptance Criteria Mapping

{для каждого mapping в acceptance_criteria_mapping}
- [ ] {criterion} → Phase {mapped_to_phases joined}

## Общая валидация

После выполнения всех фаз проверить:
- Все acceptance criteria выполнены
- Все тесты проходят
- PRD требования соблюдены
```

### Шаблон 11: Phase File Generation

**Назначение:** Генерация phase-N-slug.md из task_decomposition.phases[N] JSON.

**Входные данные:** `task_decomposition.phases[N]` JSON
**Выходной файл:** `plans/phase-{N}-{slug}.md`

**Правила slug generation:**
- Взять `phase.name`, убрать "Phase N: "
- Lowercase, заменить пробелы на дефисы
- Удалить спецсимволы
- Пример: "Git Setup + Component A" → "git-setup-component-a"

```markdown
# Phase {phase_number}: {name}

## Цель
{goal}

## Контекст
- **Номер фазы:** {phase_number} из {total_phases}
- **Ветка:** {feature_branch} {если phase_number > 1, иначе "будет создана"}
- **Предыдущие изменения:** {для фазы 1: "N/A", для остальных: summary из предыдущих фаз}
- **Зависимости:** {анализ зависимостей от предыдущих фаз}

## Основные шаги

{для каждого step в steps[]}
### {step_number}. {step_name}

**Действия:**
{для каждого action в actions[]}
- {action}

**Файлы:** `{затронутые файлы из affected_files}`

**Ожидаемый результат:** {expected_result}

## Критерии завершения

{для каждого criterion в completion_criteria}
- [ ] {criterion}

## Commit Message

```
{commit_type}: {commit_summary}

{Детальное описание:
- сгенерировать на основе steps[].actions
- что было добавлено
- что было изменено
- что было удалено}
```

## Риски фазы

{для каждого risk в risks}
- {risk} → {mitigation}

## Валидация

**Syntax Check:**
{для каждого файла в affected_files}
- {команда проверки синтаксиса для этого типа файла}

**Functional Check:**
{сгенерировать на основе expected_result из steps}
- {как проверить каждый expected_result}

**PRD Compliance:**
{для критериев из acceptance_criteria_mapping, покрытых этой фазой}
- {как проверить соответствие PRD}
```

### Шаблон 12: Phase Context Check

**Назначение:** Проверка контекста ветки перед выполнением фазы > 1.

**Когда использовать:** Перед выполнением Phase 2, 3, 4, 5 (НЕ для Phase 1).

**THINKING template:**
```xml
<thinking>
ПРОВЕРКА КОНТЕКСТА ВЕТКИ:
Текущая ветка: [git branch --show-current]
Ожидаемая ветка: [phase_metadata.context.branch_name]

Коммиты в ветке: [git log --oneline {base_branch}..HEAD]

Изменения в ветке: [git diff {base_branch}...HEAD --stat]

АНАЛИЗ:
- Предыдущие фазы выполнены? [проверить по коммитам]
- Есть незакоммиченные изменения? [git status]
- Готовы к выполнению текущей фазы? [да/нет]
</thinking>
```

**Actions:**
```bash
# Проверить текущую ветку
git branch --show-current

# Проверить статус
git status

# Проверить коммиты
git log --oneline {base_branch}..HEAD
```

**Exit Conditions:**
- ✓ На правильной ветке
- ✓ Нет незакоммиченных изменений
- ✓ Предыдущие фазы выполнены (по коммитам)

**Violation Action:**
- Неправильная ветка → STOP, использовать error-handling: WRONG_BRANCH
- Незакоммиченные изменения → STOP, использовать error-handling: UNCOMMITTED_CHANGES
- Предыдущие фазы не выполнены → STOP, выполнить предыдущие фазы сначала

---

## Проверочный чеклист

После создания structured plan проверь:

**Обязательные секции:**
- [ ] `task_plan` присутствует
- [ ] `task_name` минимум 5 символов
- [ ] `prd_sections` минимум 1 секция
- [ ] `problem` минимум 10 символов
- [ ] `solution` минимум 10 символов
- [ ] `acceptance_criteria` минимум 1 критерий
- [ ] `files_to_change` минимум 1 файл
- [ ] `execution_steps` минимум 2 шага
- [ ] `validation` содержит все 3 типа checks
- [ ] `git` секция полная

**Качество плана:**
- [ ] JSON Schema validation PASSED
- [ ] Acceptance criteria конкретные и проверяемые
- [ ] Каждый execution_step имеет validation command
- [ ] Риски идентифицированы с mitigation
- [ ] Branch name соответствует паттерну (feature/, fix/, etc)
- [ ] Commit summary max 72 символа
- [ ] Markdown план выведен после JSON

**Выполнимость:**
- [ ] Шаги последовательные и логичные
- [ ] Validation commands реальные (не placeholder)
- [ ] Files_to_change содержат реальные пути
- [ ] Syntax checks соответствуют языкам проекта

## Связанные скилы

**Universal skills:**
- **thinking-framework**: используется перед планированием для analysis
- **validation-framework**: использует план для валидации результатов
- **approval-gates**: программная проверка плана перед выполнением
- **git-workflow**: использует git секцию плана для commit

**Phase-based workflow skills:**
- **task-decomposition**: использует Шаблоны 8-11 для декомпозиции задач на фазы и генерации master plan + phase files
- **phase-execution**: использует Шаблоны 6-7, 12 для парсинга и выполнения phase files

## Примеры использования

### Пример 1: Простая задача (добавление метода)

**Запрос:**
```
Создай план для добавления метода calculate_total в сервис BudgetService.
Метод должен суммировать amounts из списка BudgetFact.
```

**Claude использует structured-planning скил:**

1. **Thinking:** Анализирует требования, определяет acceptance criteria
2. **JSON Plan:**
```json
{
  "task_plan": {
    "task_name": "Добавить метод calculate_total в BudgetService",
    "prd_sections": ["FR-042"],

    "problem": "Нужно рассчитывать общую сумму бюджетных фактов",
    "solution": "Создать метод calculate_total который принимает список BudgetFact и возвращает сумму",

    "acceptance_criteria": [
      "AC1: Метод calculate_total существует в BudgetService",
      "AC2: Метод корректно суммирует amounts"
    ],

    "files_to_change": [
      {
        "file_path": "backend/app/services/budget_service.py",
        "change_type": "modify",
        "description": "Добавить метод calculate_total"
      }
    ],

    "execution_steps": [
      {
        "step_number": 1,
        "description": "Git: создать feature branch",
        "actions": ["git checkout master", "git checkout -b feature/calculate-total"],
        "validation": "git branch --show-current"
      },
      {
        "step_number": 2,
        "description": "Реализовать метод calculate_total",
        "actions": [
          "Добавить метод в BudgetService class",
          "Реализовать логику sum(fact.amount for fact in facts)"
        ],
        "validation": "python -m py_compile backend/app/services/budget_service.py"
      },
      {
        "step_number": 3,
        "description": "Git commit и push",
        "actions": [
          "git add backend/app/services/budget_service.py",
          "git commit -m 'feat: add calculate_total method to BudgetService'",
          "git push -u origin feature/calculate-total"
        ],
        "validation": "git log -1"
      }
    ],

    "risks": [
      {
        "risk": "Метод может получить None вместо numbers",
        "mitigation": "Добавить валидацию типов и обработку None"
      }
    ],

    "validation": {
      "syntax_checks": ["python -m py_compile backend/app/services/budget_service.py"],
      "functional_checks": ["Проверить что calculate_total(facts) возвращает корректную сумму"],
      "prd_compliance_checks": ["Проверить соответствие FR-042"]
    },

    "git": {
      "branch_name": "feature/calculate-total",
      "base_branch": "master",
      "commit_type": "feat",
      "commit_summary": "add calculate_total method to BudgetService"
    }
  }
}
```

3. **Markdown Display:** Выводит читаемый план с секциями

### Пример 2: Сложная задача (рефакторинг с несколькими файлами)

**Запрос:**
```
Создай план для рефакторинга OrderService: вынести validation logic в отдельный класс OrderValidator.
Это затронет order_service.py, endpoints/orders.py и нужно создать новый validators/order_validator.py
```

**Claude использует structured-planning скил:**

```json
{
  "task_plan": {
    "task_name": "Рефакторинг: выделить OrderValidator из OrderService",
    "prd_sections": ["NFR-015"],

    "problem": "OrderService содержит бизнес-логику и валидацию, что нарушает Single Responsibility Principle",
    "solution": "Создать OrderValidator класс, переместить туда всю валидацию, обновить OrderService и endpoints",

    "acceptance_criteria": [
      "AC1: OrderValidator класс создан с методами validate_order, validate_amount",
      "AC2: OrderService использует OrderValidator вместо inline validation",
      "AC3: Orders endpoints обновлены для использования нового валидатора",
      "AC4: Все тесты проходят"
    ],

    "files_to_change": [
      {
        "file_path": "backend/app/validators/order_validator.py",
        "change_type": "create",
        "description": "Создать OrderValidator с методами валидации"
      },
      {
        "file_path": "backend/app/services/order_service.py",
        "change_type": "modify",
        "description": "Удалить inline validation, использовать OrderValidator"
      },
      {
        "file_path": "backend/app/api/v1/endpoints/orders.py",
        "change_type": "modify",
        "description": "Обновить endpoints для использования OrderValidator"
      }
    ],

    "execution_steps": [
      {
        "step_number": 1,
        "description": "Git: создать refactor branch",
        "actions": ["git checkout master", "git checkout -b refactor/order-validator"],
        "validation": "git branch --show-current"
      },
      {
        "step_number": 2,
        "description": "Создать OrderValidator класс",
        "actions": [
          "Создать validators/order_validator.py",
          "Реализовать validate_order method",
          "Реализовать validate_amount method"
        ],
        "validation": "python -m py_compile backend/app/validators/order_validator.py"
      },
      {
        "step_number": 3,
        "description": "Рефакторить OrderService",
        "actions": [
          "Импортировать OrderValidator",
          "Удалить inline validation methods",
          "Использовать validator.validate_order()"
        ],
        "validation": "python -m py_compile backend/app/services/order_service.py"
      },
      {
        "step_number": 4,
        "description": "Обновить endpoints",
        "actions": [
          "Импортировать OrderValidator",
          "Обновить create_order endpoint",
          "Обновить update_order endpoint"
        ],
        "validation": "python -m py_compile backend/app/api/v1/endpoints/orders.py"
      },
      {
        "step_number": 5,
        "description": "Git commit и push",
        "actions": [
          "git add .",
          "git commit -m 'refactor: extract OrderValidator from OrderService'",
          "git push -u origin refactor/order-validator"
        ],
        "validation": "git log -1"
      }
    ],

    "risks": [
      {
        "risk": "Можем сломать существующую валидацию при переносе",
        "mitigation": "Переносить методы один за другим, проверять syntax после каждого"
      },
      {
        "risk": "Циклические импорты если OrderValidator импортирует Order models",
        "mitigation": "Использовать TYPE_CHECKING для импортов типов"
      }
    ],

    "validation": {
      "syntax_checks": [
        "python -m py_compile backend/app/validators/order_validator.py",
        "python -m py_compile backend/app/services/order_service.py",
        "python -m py_compile backend/app/api/v1/endpoints/orders.py"
      ],
      "functional_checks": [
        "Проверить что OrderValidator.validate_order работает",
        "Проверить что OrderService использует валидатор",
        "Проверить что endpoints работают корректно"
      ],
      "prd_compliance_checks": [
        "Проверить соответствие NFR-015 (Single Responsibility)"
      ]
    },

    "git": {
      "branch_name": "refactor/order-validator",
      "base_branch": "master",
      "commit_type": "refactor",
      "commit_summary": "extract OrderValidator from OrderService"
    }
  }
}
```

## Часто задаваемые вопросы

**Q: Сколько execution_steps должно быть минимум?**

A: Минимум 2 шага (enforced JSON Schema). Обычно:
- 1-2 шага для git branch/setup
- N шагов для изменений файлов
- 1 шаг для git commit/push

**Q: Что если задача НЕ требует PRD секций?**

A: Все равно укажи `prd_sections: ["N/A"]` или общую секцию типа `["General"]`. Schema требует минимум 1 элемент.

**Q: Как писать acceptance criteria?**

A: Формат: `"AC{N}: {конкретное утверждение что должно быть true}"`. Примеры:
- ✅ "AC1: Функция calculate_total существует и принимает list[BudgetFact]"
- ✅ "AC2: Endpoint GET /orders/{id} возвращает 404 если заказ не найден"
- ❌ "AC1: Все работает" (слишком общее)
- ❌ "Добавить функцию" (не утверждение, а действие)

**Q: Validation command должна быть реальной командой?**

A: Да! Для syntax checks - обязательно реальная команда (python -m py_compile, node --check, etc). Для functional checks может быть описание проверки.

**Q: Что если не знаю точные пути файлов при планировании?**

A: Используй best guess на основе архитектуры проекта. Примеры:
- Backend: `backend/app/services/`, `backend/app/api/v1/endpoints/`
- Frontend: `frontend/src/components/`, `frontend/src/services/`

Можно уточнить пути во время выполнения.

**Q: Сколько рисков идентифицировать?**

A: Минимум 0 (не enforced schema), но рекомендуется 1-3 самых вероятных риска. Фокус на technical risks (не бизнес risks).

**Q: Git branch name должен строго соответствовать паттерну?**

A: Да! Schema enforces pattern `^(feature|fix|refactor|docs|chore|test)/`. Примеры:
- ✅ `feature/calculate-total`
- ✅ `fix/null-pointer-in-validator`
- ✅ `refactor/extract-order-validator`
- ❌ `my-branch` (нет префикса)
- ❌ `feature-calculate-total` (не `/`)

**Q: Что если JSON Schema validation failed?**

A: STOP немедленно, исправить структуру JSON, RETRY. Типичные ошибки:
- Пропущена обязательная секция
- execution_steps < 2
- commit_summary > 72 символа
- branch_name не соответствует паттерну
- prd_sections пустой массив

**Q: Markdown план обязателен после JSON?**

A: Да! Exit condition плана: `Markdown план выведен`. Это делает план читаемым для пользователя.

**Q: Когда использовать phase-based planning вместо обычного task_plan?**

A: Используй phase-based planning когда:
- Задача слишком большая для одного коммита (>5 файлов)
- Задача логически разбивается на независимые части (backend → frontend)
- Нужны промежуточные коммиты для безопасности или review
- Есть естественные границы (setup → implementation → testing)

Используй обычный task_plan для простых задач (1-3 файла, 2-4 шага).

**Q: Сколько фаз должно быть в task_decomposition?**

A: Минимум 2, максимум 5 (enforced JSON Schema). Типичное распределение:
- **2 фазы:** Git Setup + Implementation
- **3 фазы:** Git Setup + Backend + Frontend
- **4 фазы:** Git Setup + Models + API + Tests
- **5 фаз:** Git Setup + Models + Services + API + Integration

Если нужно >5 фаз - задача слишком большая, разбей на несколько отдельных задач.

**Q: Сколько шагов должно быть в одной фазе?**

A: Минимум 3, максимум 7 (enforced JSON Schema). Если нужно >7 шагов - фаза слишком большая, разбей на 2 фазы.

**Q: Как генерировать slug для phase файла?**

A: Алгоритм:
1. Взять `phase.name`, убрать "Phase N: " префикс
2. Lowercase: "Git Setup + Component A" → "git setup + component a"
3. Заменить пробелы на дефисы: "git setup + component a" → "git-setup-+-component-a"
4. Удалить спецсимволы: "git-setup-+-component-a" → "git-setup-component-a"

Результат: `plans/phase-1-git-setup-component-a.md`

**Q: phase_metadata vs task_plan - в чем разница?**

A:
- **task_plan**: Используется для simple/single-phase tasks. Содержит все шаги в одном плане.
- **phase_metadata**: Используется для parsing phase files. Содержит шаги ОДНОЙ фазы из multi-phase task.

**task_decomposition** → создает master plan + N phase files → каждый phase file парсится в **phase_metadata** при выполнении.

**Q: Можно ли изменить phase files после генерации?**

A: Да! Phase files - это обычные Markdown файлы. Можно:
- Редактировать шаги
- Добавлять/удалять actions
- Изменять completion_criteria
- Обновлять commit messages

Просто сохрани изменения и используй обновленный phase file для выполнения.
