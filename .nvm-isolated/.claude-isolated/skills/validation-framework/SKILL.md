---
name: Validation Framework
description: Комплексная валидация результатов задач через acceptance criteria, PRD compliance, syntax и functional checks
version: 1.0.0
author: Claude Code Team
tags: [validation, testing, acceptance-criteria, prd-compliance, syntax-checks, quality-assurance]
dependencies: [structured-planning, error-handling]
---

# Validation Framework

Автоматизация комплексной валидации результатов выполнения задач. Этот скил обеспечивает структурированную проверку acceptance criteria, PRD compliance, синтаксиса кода и функциональности через JSON Schema валидацию с блокирующими ошибками.

## Когда использовать этот скил

Используй этот скил когда нужно:
- Валидировать acceptance criteria после выполнения задачи
- Проверить PRD compliance (соответствие требованиям)
- Выполнить syntax checks для измененных файлов
- Провести functional checks (проверки функциональности)
- Определить blocking issues (блокирующие проблемы)
- Принять решение о возможности продолжения (can_proceed_to_finalization)
- Получить структурированный отчет о валидации с JSON Schema

Скил автоматически вызывается при запросах типа:
- "Провалидируй acceptance criteria для выполненной задачи"
- "Проверь PRD compliance и syntax checks"
- "Выполни комплексную валидацию результатов"
- "Определи blocking issues перед финализацией"

## Контекст проекта

### Философия Validation Framework

**Принципы:**
- **Blocking validation:** Критичные ошибки БЛОКИРУЮТ продолжение
- **Four-layer validation:** Acceptance → PRD → Syntax → Functional
- **Programmatic decision:** Решение о продолжении программное (boolean)
- **Evidence-based:** Каждая проверка требует evidence (доказательство)
- **Fail-fast:** STOP немедленно при critical failures

### Архитектура валидации

```
validation_results
├── acceptance_criteria (CRITICAL)
│   ├── total, met, not_met
│   └── details[] (criterion, status, evidence)
├── prd_compliance (CRITICAL)
│   ├── compliant (boolean)
│   ├── conflicts[]
│   └── checks_performed[]
├── syntax_checks (BLOCKING)
│   ├── total_files, passed, failed
│   └── details[] (file, status, command)
├── functional_checks (STANDARD)
│   ├── total, passed, failed
│   └── details[] (check, status, evidence)
├── overall_status (PASSED | FAILED)
├── can_proceed_to_finalization (boolean)
└── blocking_issues[] (messages)
```

### Уровни критичности

- **CRITICAL:** Acceptance criteria, PRD compliance - STOP при failure
- **BLOCKING:** Syntax checks - BLOCKING до исправления
- **STANDARD:** Functional checks - желательны но не блокируют

### Validation Logic

```javascript
// Определение overall_status
overall_status = "PASSED" if (
  acceptance_criteria.met === acceptance_criteria.total &&
  prd_compliance.compliant === true &&
  syntax_checks.failed === 0 &&
  functional_checks.failed === 0
) else "FAILED"

// Разрешение продолжения
can_proceed_to_finalization = (overall_status === "PASSED")

// Блокирующие проблемы
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

## Шаблоны

### Шаблон 1: Полный JSON Validation Results

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

### Шаблон 2: JSON Schema для валидации

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

### Шаблон 3: Syntax Check Commands по языкам

```bash
# Python
python -m py_compile <file.py>
python -m compileall <directory>
flake8 <file.py>  # Linting (опционально)
mypy <file.py>    # Type checking (опционально)

# JavaScript
node --check <file.js>
eslint <file.js>  # Linting

# TypeScript
tsc --noEmit <file.ts>
tsc --noEmit --project tsconfig.json  # Для проекта

# Bash
bash -n <file.sh>
shellcheck <file.sh>  # Linting

# Go
go build <file.go>
gofmt -l <file.go>

# Rust
rustc --crate-type lib <file.rs>
cargo check

# Java
javac <File.java>

# C/C++
gcc -fsyntax-only <file.c>
g++ -fsyntax-only <file.cpp>
```

### Шаблон 4: Markdown Output для валидации

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

### Шаблон 5: Acceptance Criterion Template

```json
{
  "criterion": "AC{N}: {Конкретное утверждение что должно быть true}",
  "status": "met",
  "evidence": "{Доказательство выполнения}"
}
```

**Примеры хороших acceptance criteria:**
```json
[
  {
    "criterion": "AC1: Функция calculate_total существует в BudgetService",
    "status": "met",
    "evidence": "Метод определен на строке 42 в budget_service.py"
  },
  {
    "criterion": "AC2: Endpoint GET /orders/{id} возвращает 404 для несуществующего заказа",
    "status": "met",
    "evidence": "Проверено вручную: curl возвращает 404"
  }
]
```

**Примеры плохих acceptance criteria:**
```json
[
  {
    "criterion": "Все работает",  // ❌ Слишком общее
    "criterion": "Добавить функцию"  // ❌ Действие, не утверждение
  }
]
```

### Шаблон 6: PRD Compliance Check Template

```json
{
  "prd_section": "FR-XXX",
  "requirement": "Краткое описание требования из PRD",
  "status": "compliant",
  "evidence": "Как реализация соответствует требованию"
}
```

**Пример:**
```json
{
  "prd_section": "FR-042",
  "requirement": "Система должна рассчитывать общую сумму бюджетных фактов",
  "status": "compliant",
  "evidence": "Метод calculate_total принимает список BudgetFact и возвращает sum(fact.amount for fact in facts)"
}
```

## Проверочный чеклист

После создания validation_results проверь:

**JSON Schema:**
- [ ] JSON Schema validation PASSED
- [ ] Все обязательные секции присутствуют
- [ ] `total` = `met` + `not_met` для acceptance_criteria
- [ ] `total_files` = `passed` + `failed` для syntax_checks
- [ ] `total` = `passed` + `failed` для functional_checks
- [ ] `overall_status` либо "PASSED" либо "FAILED"
- [ ] `can_proceed_to_finalization` это boolean

**Acceptance Criteria:**
- [ ] Каждый criterion имеет evidence
- [ ] Criteria конкретные и проверяемые (не "все работает")
- [ ] Status либо "met" либо "not_met"
- [ ] Если not_met > 0, добавлено в blocking_issues

**PRD Compliance:**
- [ ] Каждая check_performed имеет prd_section reference
- [ ] Requirement соответствует PRD
- [ ] Evidence показывает как реализация соответствует
- [ ] Если compliant = false, есть conflicts[]
- [ ] Если compliant = false, добавлено в blocking_issues

**Syntax Checks:**
- [ ] Commands реальные (не placeholder)
- [ ] Commands соответствуют языкам файлов
- [ ] Если failed > 0, добавлено в blocking_issues
- [ ] Status либо "passed" либо "failed"

**Functional Checks:**
- [ ] Checks описывают функциональность, не синтаксис
- [ ] Evidence показывает фактическую проверку
- [ ] Status либо "passed" либо "failed"

**Overall Logic:**
- [ ] overall_status = "PASSED" только если ВСЕ проверки passed
- [ ] can_proceed_to_finalization = true только если overall_status = "PASSED"
- [ ] blocking_issues пустой если overall_status = "PASSED"
- [ ] Markdown output выведен после JSON

## Связанные скилы

- **structured-planning**: план содержит validation секцию для этого скила
- **error-handling**: использует validation results для определения action
- **approval-gates**: может требовать validation перед approval

## Примеры использования

### Пример 1: Валидация простой задачи (все PASSED)

**Контекст:**
Выполнена задача "Добавить метод calculate_total в BudgetService".
Acceptance criteria:
- AC1: Метод существует
- AC2: Метод корректно суммирует

**Claude использует validation-framework скил:**

```json
{
  "validation_results": {
    "acceptance_criteria": {
      "total": 2,
      "met": 2,
      "not_met": 0,
      "details": [
        {
          "criterion": "AC1: Метод calculate_total существует в BudgetService",
          "status": "met",
          "evidence": "Метод определен на строке 42 в budget_service.py"
        },
        {
          "criterion": "AC2: Метод корректно суммирует amounts",
          "status": "met",
          "evidence": "Метод реализует sum(fact.amount for fact in facts), протестировано вручную"
        }
      ]
    },

    "prd_compliance": {
      "compliant": true,
      "conflicts": [],
      "checks_performed": [
        {
          "prd_section": "FR-042",
          "requirement": "Система должна рассчитывать общую сумму бюджетных фактов",
          "status": "compliant",
          "evidence": "Метод calculate_total реализует требование"
        }
      ]
    },

    "syntax_checks": {
      "total_files": 1,
      "passed": 1,
      "failed": 0,
      "details": [
        {
          "file": "backend/app/services/budget_service.py",
          "status": "passed",
          "command": "python -m py_compile backend/app/services/budget_service.py"
        }
      ]
    },

    "functional_checks": {
      "total": 1,
      "passed": 1,
      "failed": 0,
      "details": [
        {
          "check": "Проверить что calculate_total(facts) возвращает корректную сумму",
          "status": "passed",
          "evidence": "Вызван calculate_total([fact1, fact2]), вернул правильную сумму"
        }
      ]
    },

    "overall_status": "PASSED",
    "can_proceed_to_finalization": true,
    "blocking_issues": []
  }
}
```

**Результат:** Markdown display показывает ✓ PASSED, разрешено продолжение.

### Пример 2: Валидация с ошибками (FAILED)

**Контекст:**
Выполнена задача "Рефакторинг OrderValidator", но:
- Syntax error в одном файле
- Один acceptance criterion не выполнен

**Claude использует validation-framework скил:**

```json
{
  "validation_results": {
    "acceptance_criteria": {
      "total": 3,
      "met": 2,
      "not_met": 1,
      "details": [
        {
          "criterion": "AC1: OrderValidator класс создан",
          "status": "met",
          "evidence": "Класс определен в validators/order_validator.py"
        },
        {
          "criterion": "AC2: OrderService использует OrderValidator",
          "status": "met",
          "evidence": "Импорт добавлен, методы используют validator"
        },
        {
          "criterion": "AC3: Все тесты проходят",
          "status": "not_met",
          "evidence": "Тесты не запускались в этой среде (локальная разработка)"
        }
      ]
    },

    "prd_compliance": {
      "compliant": true,
      "conflicts": [],
      "checks_performed": [
        {
          "prd_section": "NFR-015",
          "requirement": "Код должен следовать Single Responsibility Principle",
          "status": "compliant",
          "evidence": "Валидация вынесена в отдельный класс OrderValidator"
        }
      ]
    },

    "syntax_checks": {
      "total_files": 3,
      "passed": 2,
      "failed": 1,
      "details": [
        {
          "file": "backend/app/validators/order_validator.py",
          "status": "passed",
          "command": "python -m py_compile backend/app/validators/order_validator.py"
        },
        {
          "file": "backend/app/services/order_service.py",
          "status": "failed",
          "command": "python -m py_compile backend/app/services/order_service.py"
        },
        {
          "file": "backend/app/api/v1/endpoints/orders.py",
          "status": "passed",
          "command": "python -m py_compile backend/app/api/v1/endpoints/orders.py"
        }
      ]
    },

    "functional_checks": {
      "total": 2,
      "passed": 2,
      "failed": 0,
      "details": [
        {
          "check": "OrderValidator.validate_order работает",
          "status": "passed",
          "evidence": "Метод определен и имеет корректную сигнатуру"
        },
        {
          "check": "OrderService использует валидатор",
          "status": "passed",
          "evidence": "Все методы сервиса вызывают validator.validate_order()"
        }
      ]
    },

    "overall_status": "FAILED",
    "can_proceed_to_finalization": false,
    "blocking_issues": [
      "1 acceptance criteria not met",
      "1 syntax checks failed"
    ]
  }
}
```

**Результат:**
```
═══════════════════════════════════════════════════════════
              ВАЛИДАЦИЯ ЗАВЕРШЕНА
═══════════════════════════════════════════════════════════

ACCEPTANCE CRITERIA: 2/3

[✓] AC1: OrderValidator класс создан
    └─ Класс определен в validators/order_validator.py
[✓] AC2: OrderService использует OrderValidator
    └─ Импорт добавлен, методы используют validator
[✗] AC3: Все тесты проходят
    └─ Тесты не запускались в этой среде

───────────────────────────────────────────────────────────

PRD COMPLIANCE: ✓ COMPLIANT

[✓] NFR-015: Код должен следовать Single Responsibility Principle
    └─ Валидация вынесена в отдельный класс

───────────────────────────────────────────────────────────

SYNTAX CHECKS: 2/3

[✓] backend/app/validators/order_validator.py
[✗] backend/app/services/order_service.py
[✓] backend/app/api/v1/endpoints/orders.py

───────────────────────────────────────────────────────────

FUNCTIONAL CHECKS: 2/2

[✓] OrderValidator.validate_order работает
    └─ Метод определен и имеет корректную сигнатуру
[✓] OrderService использует валидатор
    └─ Все методы сервиса вызывают validator.validate_order()

───────────────────────────────────────────────────────────

РЕЗУЛЬТАТ: FAILED
Переход к финализации: BLOCKED

🛑 БЛОКИРУЮЩИЕ ПРОБЛЕМЫ:
- 1 acceptance criteria not met
- 1 syntax checks failed

═══════════════════════════════════════════════════════════
```

**Action:** BLOCKING - исправить syntax error в order_service.py, затем RETRY валидацию.

---

## Phase-Based Validation

### Когда использовать Phase-Based Validation

Используй phase-based validation при работе с фазами:
- **After Phase Loading** (Checkpoint 1): Проверка что phase file корректно загружен
- **After Phase Execution** (Checkpoint 2): Проверка что все шаги выполнены
- **After Phase Completion**: Валидация completion criteria
- **After All Phases**: File existence checks для созданных планов

### Шаблон 5: Checkpoint Validation JSON

**Назначение:** Валидация checkpoint перед переходом к следующей phase/stage.

```json
{
  "checkpoint": {
    "checkpoint_id": 1,
    "checkpoint_name": "ЗАГРУЗКА И АНАЛИЗ",

    "checks": [
      {
        "check_id": 1,
        "check_name": "Phase file прочитан",
        "status": "passed",
        "details": "plans/phase-1-git-setup.md (87 строк)"
      },
      {
        "check_id": 2,
        "check_name": "Phase metadata извлечен",
        "status": "passed",
        "details": "5 шагов, 3 критерия завершения"
      },
      {
        "check_id": 3,
        "check_name": "Контекст проверен",
        "status": "passed",
        "details": "Ветка feature/task-name создана"
      },
      {
        "check_id": 4,
        "check_name": "Нет незакоммиченных изменений",
        "status": "passed",
        "details": "git status: clean"
      },
      {
        "check_id": 5,
        "check_name": "На правильной ветке",
        "status": "passed",
        "details": "feature/task-name (ожидалось: feature/task-name)"
      }
    ],

    "overall_result": "PASSED",
    "can_proceed_to_execution": true,
    "blocking_issues": []
  }
}
```

### Шаблон 6: Checkpoint Validation JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "checkpoint": {
      "type": "object",
      "properties": {
        "checkpoint_id": {"type": "integer"},
        "checkpoint_name": {"type": "string"},
        "checks": {
          "type": "array",
          "minItems": 1,
          "items": {
            "type": "object",
            "properties": {
              "check_id": {"type": "integer"},
              "check_name": {"type": "string"},
              "status": {"type": "string", "enum": ["passed", "failed"]},
              "details": {"type": "string"}
            },
            "required": ["check_id", "check_name", "status", "details"]
          }
        },
        "overall_result": {"type": "string", "enum": ["PASSED", "FAILED"]},
        "can_proceed_to_execution": {"type": "boolean"},
        "blocking_issues": {
          "type": "array",
          "items": {"type": "string"}
        }
      },
      "required": [
        "checkpoint_id", "checkpoint_name", "checks",
        "overall_result", "can_proceed_to_execution", "blocking_issues"
      ]
    }
  },
  "required": ["checkpoint"]
}
```

**Validation Logic:**
```javascript
// Определение overall_result
overall_result = checks.every(c => c.status === "passed") ? "PASSED" : "FAILED"

// Разрешение продолжения
can_proceed_to_execution = (overall_result === "PASSED")

// Блокирующие проблемы
if (overall_result === "FAILED") {
  blocking_issues = checks
    .filter(c => c.status === "failed")
    .map(c => c.check_name)
}
```

### Шаблон 7: Completion Status Validation JSON

**Назначение:** Валидация completion criteria после выполнения фазы.

```json
{
  "completion_status": {
    "phase_number": 1,
    "phase_name": "Git Setup + Component A",

    "steps_completed": [
      {
        "step_number": 1,
        "step_name": "Создать git ветку",
        "status": "completed",
        "files_changed": [],
        "syntax_check": "passed"
      },
      {
        "step_number": 2,
        "step_name": "Создать service",
        "status": "completed",
        "files_changed": ["backend/app/services/service_a.py"],
        "syntax_check": "passed"
      }
    ],

    "completion_criteria_status": [
      {
        "criterion": "Service создан и протестирован",
        "status": "met",
        "evidence": "Файл создан, импорт работает"
      },
      {
        "criterion": "Syntax check passed",
        "status": "met",
        "evidence": "Все файлы прошли python -m py_compile"
      },
      {
        "criterion": "Git commit сделан",
        "status": "pending",
        "evidence": "Будет выполнен в Phase 3"
      }
    ],

    "all_steps_completed": true,
    "all_syntax_checks_passed": true,
    "ready_for_commit": true,
    "blocking_issues": []
  }
}
```

### Шаблон 8: Completion Status JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "completion_status": {
      "type": "object",
      "properties": {
        "phase_number": {"type": "integer"},
        "phase_name": {"type": "string"},

        "steps_completed": {
          "type": "array",
          "minItems": 1,
          "items": {
            "type": "object",
            "properties": {
              "step_number": {"type": "integer"},
              "step_name": {"type": "string"},
              "status": {"type": "string", "enum": ["completed", "failed", "skipped"]},
              "files_changed": {
                "type": "array",
                "items": {"type": "string"}
              },
              "syntax_check": {"type": "string", "enum": ["passed", "failed", "skipped"]}
            },
            "required": ["step_number", "step_name", "status", "files_changed", "syntax_check"]
          }
        },

        "completion_criteria_status": {
          "type": "array",
          "minItems": 1,
          "items": {
            "type": "object",
            "properties": {
              "criterion": {"type": "string"},
              "status": {"type": "string", "enum": ["met", "not_met", "pending"]},
              "evidence": {"type": "string"}
            },
            "required": ["criterion", "status", "evidence"]
          }
        },

        "all_steps_completed": {"type": "boolean"},
        "all_syntax_checks_passed": {"type": "boolean"},
        "ready_for_commit": {"type": "boolean"},
        "blocking_issues": {
          "type": "array",
          "items": {"type": "string"}
        }
      },
      "required": [
        "phase_number", "steps_completed", "completion_criteria_status",
        "all_steps_completed", "all_syntax_checks_passed", "ready_for_commit", "blocking_issues"
      ]
    }
  },
  "required": ["completion_status"]
}
```

**Validation Logic:**
```javascript
// Все шаги завершены
all_steps_completed = steps_completed.every(s => s.status === "completed")

// Все syntax checks прошли
all_syntax_checks_passed = steps_completed.every(s => s.syntax_check === "passed")

// Критерии, помеченные "pending", разрешены (выполнятся позже)
const non_pending_criteria = completion_criteria_status.filter(c => c.status !== "pending")
const all_non_pending_met = non_pending_criteria.every(c => c.status === "met")

// Готовность к коммиту
ready_for_commit = all_steps_completed && all_syntax_checks_passed && all_non_pending_met
```

### Шаблон 9: Phase Summary Validation JSON

**Назначение:** Валидация phase summary после завершения фазы.

```json
{
  "phase_summary": {
    "phase_number": 1,
    "phase_name": "Git Setup + Component A",
    "status": "completed",

    "steps_executed": [
      {
        "step_number": 1,
        "step_name": "Создать git ветку",
        "status": "completed"
      },
      {
        "step_number": 2,
        "step_name": "Создать service",
        "status": "completed"
      }
    ],

    "files_changed": [
      {
        "file_path": "backend/app/services/service_a.py",
        "change_type": "created",
        "description": "Service A с базовой логикой"
      }
    ],

    "completion_criteria_met": [
      "Service создан и протестирован",
      "Syntax check passed"
    ],

    "git_info": {
      "branch": "feature/task-name",
      "commit_hash": "abc123def",
      "commit_message": "feat: add service A with basic logic"
    },

    "next_step": {
      "has_next_phase": true,
      "next_phase_number": 2,
      "next_phase_file": "plans/phase-2-api-endpoints.md",
      "command": "Выполни фазу: plans/phase-2-api-endpoints.md"
    }
  }
}
```

### Шаблон 10: File Existence Checks

**Назначение:** Проверка существования созданных файлов планов после task decomposition.

**Actions:**
```bash
# Проверить директорию plans/
ls -la plans/

# Проверить master plan
test -f plans/master-plan.md && echo "✓ master-plan.md exists" || echo "✗ master-plan.md missing"

# Проверить phase files
for i in {1..N}; do
  test -f plans/phase-${i}-*.md && echo "✓ phase-${i} exists" || echo "✗ phase-${i} missing"
done

# Подсчитать файлы
file_count=$(ls plans/*.md | wc -l)
expected_count=$((total_phases + 1))  # N phase files + 1 master plan

if [ $file_count -eq $expected_count ]; then
  echo "✓ All files verified: $file_count files"
else
  echo "✗ File count mismatch: expected $expected_count, got $file_count"
fi
```

**Validation JSON:**
```json
{
  "file_verification": {
    "directory": "plans/",
    "directory_exists": true,
    "master_plan": {
      "file": "plans/master-plan.md",
      "exists": true,
      "size_bytes": 12456
    },
    "phase_files": [
      {
        "file": "plans/phase-1-git-setup-component-a.md",
        "exists": true,
        "size_bytes": 8723
      },
      {
        "file": "plans/phase-2-api-endpoints.md",
        "exists": true,
        "size_bytes": 9512
      }
    ],
    "total_files": 3,
    "expected_files": 3,
    "all_files_verified": true,
    "missing_files": []
  }
}
```

**Exit Conditions:**
- ✓ `directory_exists` = true
- ✓ `master_plan.exists` = true
- ✓ All `phase_files[].exists` = true
- ✓ `total_files` === `expected_files`
- ✓ `all_files_verified` = true
- ✓ `missing_files` = []

**Violation Action:**
- File missing → STOP, использовать error-handling: FILE_CREATE_FAIL
- Directory missing → STOP, создать directory и повторить
- File count mismatch → STOP, проверить task_decomposition.total_phases

---

## Часто задаваемые вопросы

**Q: Что если acceptance criterion субъективный (например "код читаемый")?**

A: Сделать объективным through evidence:
- ✅ "AC1: Код следует PEP 8 style guide" + evidence: "flake8 passed"
- ❌ "AC1: Код красивый" (субъективно, нет evidence)

**Q: Syntax check failed - можно ли продолжить?**

A: НЕТ! Syntax checks BLOCKING. can_proceed_to_finalization = false если syntax_checks.failed > 0.

**Q: Functional check failed - блокирует ли продолжение?**

A: ДА! По логике валидации functional_checks.failed > 0 → overall_status = "FAILED" → BLOCKING.

**Q: PRD compliance failed но все остальные checks passed - можно продолжить?**

A: НЕТ! PRD compliance CRITICAL. compliant = false → overall_status = "FAILED" → BLOCKING.

**Q: Что если нет PRD для проекта?**

A: Используй общие best practices как "requirements":
```json
{
  "prd_section": "General",
  "requirement": "Код должен быть читаемым и maintainable",
  "status": "compliant",
  "evidence": "Код следует стилю проекта, имеет понятные имена"
}
```

**Q: Сколько попыток исправления перед STOP?**

A: Max 2 попытки. После 2 failed validations → STOP, спросить пользователя.

**Q: Что делать если validation_results не проходит JSON Schema?**

A: STOP немедленно, исправить структуру, RETRY. Типичные ошибки:
- Пропущена обязательная секция
- total != met + not_met
- status не enum value ("met"/"not_met")
- evidence пустой string

**Q: Нужно ли выполнять functional checks если syntax checks failed?**

A: Можно пропустить functional, но ОБЯЗАТЕЛЬНО указать в JSON:
```json
"functional_checks": {
  "total": 0,
  "passed": 0,
  "failed": 0,
  "details": []
}
```

**Q: Как проверять acceptance criteria для которых нет автоматического теста?**

A: Ручная проверка с описанием evidence:
```json
{
  "criterion": "AC1: UI кнопка отображается корректно",
  "status": "met",
  "evidence": "Проверено вручную в браузере: кнопка видна, кликабельна, правильный цвет"
}
```

**Q: overall_status = "PASSED" но blocking_issues не пустой - ошибка?**

A: ДА! Это нарушение validation logic. Если overall_status = "PASSED", то blocking_issues ДОЛЖЕН быть пустым массивом. JSON Schema validation поймает это через логику.
