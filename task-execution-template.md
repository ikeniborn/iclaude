# Task Execution Template v2.0 (Structured Output)

## Назначение
Этот шаблон используется для выполнения ОДНОЙ фазы из готового плана.
Входные данные: путь к phase file (например, `plans/phase-1-git-setup.md`)

## Конфигурация
- Режим: выполнение одной фазы
- Thinking: enabled, mode=interleaved (для критичных решений)
- Structured Output: enabled (для validation и enforcement)
- Валидация: syntax check, phase completion criteria
- Среда: локальная разработка (без /opt/, без запущенных сервисов)
- Git: branch → commit (push опционально)

## Принципы
1. **Один запуск = одна фаза** - выполнить только указанную фазу
2. **Следовать плану** - строго следовать шагам из phase file
3. **Structured Validation** - ключевые проверки через JSON Schema
4. **Минималистичный код** - код должен быть самодокументируемым
5. **Phase Commit** - каждая фаза завершается отдельным коммитом
6. **Контекстная работа** - учитывать изменения из предыдущих фаз

---

## Входные данные

**ОБЯЗАТЕЛЬНО:** Пользователь должен указать путь к phase file

Формат запроса:
```
Выполни фазу: plans/phase-1-git-setup.md
```

ИЛИ

```
Выполни фазу: plans/phase-2-backend-changes.md
```

---

## Процесс

### PHASE 1: ЗАГРУЗКА И АНАЛИЗ

**Entry Conditions:**
- ✓ Пользователь указал путь к phase file
- ✓ Phase file существует

---

#### **Шаг 1. [THINKING - ОБЯЗАТЕЛЬНО] Загрузка phase file**

```xml
<thinking>
PHASE FILE: [путь к файлу]
НОМЕР ФАЗЫ: [N из total]

ЧТЕНИЕ ПЛАНА:
[прочитать и проанализировать phase file]

ЦЕЛЬ ФАЗЫ: [из плана]
ОСНОВНЫЕ ШАГИ: [из плана]
ФАЙЛЫ ДЛЯ ИЗМЕНЕНИЯ: [из плана]
ЗАВИСИМОСТИ: [от каких фаз зависит]

ВЕТКА: [имя ветки из плана]
ПРЕДЫДУЩИЕ ИЗМЕНЕНИЯ: [из плана, если фаза > 1]
</thinking>
```

**Действия:**
- Прочитать указанный phase file
- Извлечь: цель, шаги, файлы, критерии, commit message
- Понять номер фазы и зависимости

---

#### **Шаг 2. [STRUCTURED OUTPUT] Парсинг phase file**

**ОБЯЗАТЕЛЬНО вывести JSON:**

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
      // ... все шаги из phase file
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

**JSON Schema:**
```json
{
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

**Exit Conditions:**
- ✓ Phase file прочитан
- ✓ JSON Schema validation PASSED
- ✓ Все обязательные поля извлечены

**Violation Action:**
- Schema validation error → STOP, проверить phase file формат
- Missing required fields → STOP, phase file неполный

---

#### **Шаг 3. [CONDITIONAL] Проверка контекста ветки (если фаза > 1)**

Если `phase_metadata.phase_number > 1`:

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

**Действия:**
```bash
# Проверить текущую ветку
git branch --show-current

# Проверить статус
git status

# Проверить коммиты
git log --oneline {base_branch}..HEAD
```

**Exit Condition:**
- ✓ На правильной ветке
- ✓ Нет незакоммиченных изменений
- ✓ Предыдущие фазы выполнены (по коммитам)

---

#### **Шаг 4. [CONDITIONAL] Git Setup (если Phase 1)**

Если `phase_metadata.phase_number == 1`:

```xml
<thinking>
GIT SETUP:
Ветка для создания: [phase_metadata.context.branch_name]
Базовая ветка: [phase_metadata.context.base_branch]

ДЕЙСТВИЯ:
1. Проверить текущую ветку
2. Создать новую ветку от базовой
3. Переключиться на новую ветку
</thinking>
```

**Действия:**
```bash
# Убедиться, что на базовой ветке
git checkout {base_branch}

# Создать новую ветку
git checkout -b {branch_name}
```

---

#### **CHECKPOINT 1: [MANDATORY OUTPUT + STRUCTURED]**

**Blocking:** `true`
**Output:** `required`

**ОБЯЗАТЕЛЬНО вывести JSON:**

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
        "check_name": "Контекст проверен / Git setup",
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

**JSON Schema:**
```json
{
  "type": "object",
  "properties": {
    "checkpoint": {
      "type": "object",
      "properties": {
        "checkpoint_id": {"type": "integer"},
        "checkpoint_name": {"type": "string"},
        "checks": {
          "type": "array",
          "minItems": 5,
          "maxItems": 5,
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

**Затем вывести Markdown:**

```
═══════════════════════════════════════════════════════════
            CHECKPOINT 1: ЗАГРУЗКА И АНАЛИЗ
═══════════════════════════════════════════════════════════

[✓] Phase file прочитан
    └─ plans/phase-1-git-setup.md (87 строк)

[✓] Phase metadata извлечен
    └─ 5 шагов, 3 критерия завершения

[✓] Контекст проверен / Git setup
    └─ Ветка feature/task-name создана

[✓] Нет незакоммиченных изменений
    └─ git status: clean

[✓] На правильной ветке
    └─ feature/task-name (ожидалось: feature/task-name)

───────────────────────────────────────────────────────────

РЕЗУЛЬТАТ: ✓ PASSED
Переход к выполнению: ALLOWED

═══════════════════════════════════════════════════════════
```

**Exit Conditions:**
- ✓ Все 5 checks = "passed"
- ✓ overall_result = "PASSED"
- ✓ can_proceed_to_execution = true
- ✓ blocking_issues = []

**Violation Action:**
- overall_result = "FAILED" → BLOCKING, исправить проблемы
- can_proceed_to_execution = false → STOP

---

### PHASE 2: ВЫПОЛНЕНИЕ ШАГОВ ФАЗЫ

**Entry Conditions:**
- ✓ Checkpoint 1: can_proceed_to_execution = true
- ✓ phase_metadata загружен

---

#### **Шаг 1. [THINKING - ОБЯЗАТЕЛЬНО] Планирование выполнения**

```xml
<thinking>
ПЛАН ВЫПОЛНЕНИЯ:

{для каждого step в phase_metadata.steps}
Шаг {step_number}: {step_name}
- Действия: {actions}
- Файлы: {affected_files}
- Ожидаемый результат: {expected_result}
- Подход: [как будем делать]

РИСКИ:
{для каждого risk в phase_metadata.risks}
- {risk} → {mitigation}

ВАЛИДАЦИЯ:
- Syntax check после каждого шага
- Проверка критериев завершения
</thinking>
```

---

#### **Шаг 2. Выполнение шагов последовательно**

Для каждого `step` в `phase_metadata.steps[]`:

**a) Выполнить действия**
   - Следовать `step.actions[]`
   - Изменить файлы из `step.affected_files[]`
   - Достичь `step.expected_result`
   - Использовать минималистичный стиль кода

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

**b) Syntax check**
   ```bash
   # Выполнить команды из phase_metadata.validation.syntax_checks[]
   ```

**c) Вывести статус шага**
   ```
   ✓ Шаг {step_number} выполнен: {step_name}
     - Изменены: {affected_files}
     - Syntax: ✓
   ```

---

#### **Шаг 3. [STRUCTURED OUTPUT] Проверка критериев завершения**

**Blocking:** `true`
**Output:** `required`

**ОБЯЗАТЕЛЬНО вывести JSON:**

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
      // ... все шаги
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

**JSON Schema:**
```json
{
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

**Validation Rules:**
```javascript
// Логика определения ready_for_commit
completion_status.all_steps_completed = steps_completed.every(s => s.status === "completed")
completion_status.all_syntax_checks_passed = steps_completed.every(s => s.syntax_check === "passed")

// Критерии, помеченные "pending", разрешены (выполнятся позже)
const non_pending_criteria = completion_criteria_status.filter(c => c.status !== "pending")
const all_non_pending_met = non_pending_criteria.every(c => c.status === "met")

completion_status.ready_for_commit =
  all_steps_completed && all_syntax_checks_passed && all_non_pending_met
```

**Затем вывести Markdown:**

```
═══════════════════════════════════════════════════════════
          КРИТЕРИИ ЗАВЕРШЕНИЯ: Phase {phase_number}
═══════════════════════════════════════════════════════════

ВЫПОЛНЕННЫЕ ШАГИ:

{для каждого step в steps_completed}
[{status ✓/✗}] Шаг {step_number}: {step_name}
    ├─ Файлы: {files_changed.length ? files_changed : "нет изменений"}
    └─ Syntax: {syntax_check}

───────────────────────────────────────────────────────────

КРИТЕРИИ ЗАВЕРШЕНИЯ:

{для каждого criterion в completion_criteria_status}
[{status === "met" ? "✓" : status === "pending" ? "⏳" : "✗"}] {criterion}
    └─ {evidence}

───────────────────────────────────────────────────────────

ВСЕ ШАГИ: {all_steps_completed ? "✓ COMPLETED" : "✗ INCOMPLETE"}
SYNTAX CHECKS: {all_syntax_checks_passed ? "✓ PASSED" : "✗ FAILED"}
ГОТОВНОСТЬ К КОММИТУ: {ready_for_commit ? "✓ READY" : "✗ NOT READY"}

{если blocking_issues.length > 0}
⚠️ БЛОКИРУЮЩИЕ ПРОБЛЕМЫ:
{для каждой issue}
- {issue}

═══════════════════════════════════════════════════════════
```

**Exit Conditions:**
- ✓ all_steps_completed = true
- ✓ all_syntax_checks_passed = true
- ✓ ready_for_commit = true
- ✓ blocking_issues = []

**Violation Action:**
- ready_for_commit = false → BLOCKING, исправить проблемы
- blocking_issues не пусто → STOP

---

#### **CHECKPOINT 2: [MANDATORY OUTPUT + STRUCTURED]**

**Blocking:** `true`
**Output:** `required`

**ОБЯЗАТЕЛЬНО вывести JSON:**

```json
{
  "checkpoint": {
    "checkpoint_id": 2,
    "checkpoint_name": "ВЫПОЛНЕНИЕ ШАГОВ ФАЗЫ",

    "checks": [
      {
        "check_id": 1,
        "check_name": "Все шаги выполнены",
        "status": "passed",
        "details": "5 из 5 шагов completed"
      },
      {
        "check_id": 2,
        "check_name": "Syntax check passed",
        "status": "passed",
        "details": "Все файлы прошли проверку"
      },
      {
        "check_id": 3,
        "check_name": "Критерии завершения",
        "status": "passed",
        "details": "2 met, 1 pending"
      },
      {
        "check_id": 4,
        "check_name": "Нет ошибок",
        "status": "passed",
        "details": "Нет blocking issues"
      }
    ],

    "overall_result": "PASSED",
    "can_proceed_to_commit": true,
    "blocking_issues": []
  }
}
```

**JSON Schema:** (аналогичная структура как в Checkpoint 1, но minItems: 4, maxItems: 4)

**Затем вывести Markdown display**

**Exit Conditions:**
- ✓ Все 4 checks = "passed"
- ✓ overall_result = "PASSED"
- ✓ can_proceed_to_commit = true

**Violation Action:**
- overall_result = "FAILED" → BLOCKING
- can_proceed_to_commit = false → STOP

---

### PHASE 3: ВАЛИДАЦИЯ И COMMIT

**Entry Conditions:**
- ✓ Checkpoint 2: can_proceed_to_commit = true
- ✓ completion_status.ready_for_commit = true

---

#### **Шаг 1. [THINKING - ОБЯЗАТЕЛЬНО] Финальная валидация**

```xml
<thinking>
ВАЛИДАЦИЯ ФАЗЫ:

Проверка 1: Syntax
- Файлы: {список из completion_status.steps_completed[].files_changed}
- Статус: {completion_status.all_syntax_checks_passed}

Проверка 2: Критерии завершения
{для каждого criterion в completion_status.completion_criteria_status}
- {criterion.criterion}: {criterion.status}

Проверка 3: План
- Все шаги из плана выполнены? {completion_status.all_steps_completed}
- Отклонения от плана? [если да, то какие и почему]

ГОТОВНОСТЬ К КОММИТУ: {completion_status.ready_for_commit}
</thinking>
```

---

#### **Шаг 2. Финальная валидация**

```bash
# Проверить статус
git status

# Проверить изменения
git diff

# Syntax check всех измененных файлов
{команды из phase_metadata.validation.syntax_checks[]}
```

---

#### **Шаг 3. [STRUCTURED OUTPUT + BLOCKING] Git commit**

**Blocking:** `true`
**Output:** `required`

**Действия:**

```bash
# Добавить файлы
git add {файлы из completion_status.steps_completed[].files_changed}

# Сделать коммит
git commit -m "{phase_metadata.commit_message.type}: {phase_metadata.commit_message.summary}

{phase_metadata.commit_message.body}"
```

**ОБЯЗАТЕЛЬНО вывести JSON:**

```json
{
  "git_commit": {
    "branch": "feature/task-name",
    "commit_hash": "abc123def456",
    "commit_type": "feat",
    "commit_summary": "add service A with basic logic",
    "files_committed": [
      "backend/app/services/service_a.py",
      "backend/app/schemas/schema_a.py"
    ],
    "commit_status": "success",
    "pushed": false
  }
}
```

**JSON Schema:**
```json
{
  "type": "object",
  "properties": {
    "git_commit": {
      "type": "object",
      "properties": {
        "branch": {"type": "string"},
        "commit_hash": {"type": "string", "pattern": "^[a-f0-9]{7,40}$"},
        "commit_type": {"type": "string", "enum": ["feat", "fix", "refactor", "docs", "chore", "test"]},
        "commit_summary": {"type": "string"},
        "files_committed": {
          "type": "array",
          "minItems": 0,
          "items": {"type": "string"}
        },
        "commit_status": {"type": "string", "enum": ["success", "failed"]},
        "pushed": {"type": "boolean"}
      },
      "required": [
        "branch", "commit_hash", "commit_type", "commit_summary",
        "files_committed", "commit_status", "pushed"
      ]
    }
  },
  "required": ["git_commit"]
}
```

**Exit Conditions:**
- ✓ commit_status = "success"
- ✓ commit_hash не пустой

**Violation Action:**
- commit_status = "failed" → STOP, проверить ошибку git

---

#### **Шаг 4. [STRUCTURED OUTPUT] Phase Summary**

**Output:** `required`

**ОБЯЗАТЕЛЬНО вывести JSON:**

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
      // ... все шаги
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

**Затем вывести Markdown:**

```
═══════════════════════════════════════════════════════════
              ✅ ФАЗА {phase_number} ЗАВЕРШЕНА
═══════════════════════════════════════════════════════════

ФАЗА: {phase_name}
СТАТУС: ✓ COMPLETED

───────────────────────────────────────────────────────────

ВЫПОЛНЕНО:

{для каждого step в steps_executed}
✓ Шаг {step_number}: {step_name}

───────────────────────────────────────────────────────────

ИЗМЕНЕНЫ ФАЙЛЫ:

{для каждого file в files_changed}
- {file_path}: [{change_type}] {description}

───────────────────────────────────────────────────────────

КРИТЕРИИ ЗАВЕРШЕНИЯ:

{для каждого criterion в completion_criteria_met}
✓ {criterion}

───────────────────────────────────────────────────────────

GIT COMMIT:

- Branch: {git_info.branch}
- Hash: {git_info.commit_hash}
- Message: {git_info.commit_message}

───────────────────────────────────────────────────────────

{если has_next_phase}
🚀 СЛЕДУЮЩИЙ ШАГ:

Для выполнения следующей фазы используйте:
"{next_step.command}"

{иначе}
🎉 ВСЕ ФАЗЫ ВЫПОЛНЕНЫ

Можно:
- Запушить ветку: git push -u origin {git_info.branch}
- Создать PR
- Обновить changelog

═══════════════════════════════════════════════════════════
```

**Exit Conditions:**
- ✓ Summary JSON сгенерирован
- ✓ Markdown display выведен
- ✓ Фаза ЗАВЕРШЕНА

---

## Error Handling

**PHASE_FILE_NOT_FOUND:**
- Action: STOP
- Message: "❌ ОШИБКА: Phase file не найден\nПуть: {path}\nДействие: Проверьте путь к файлу"

**PHASE_FILE_PARSE_ERROR:**
- Action: STOP
- Message: "❌ ОШИБКА: Не удалось распарсить phase file\nПроблема: {schema error}\nДействие: Проверьте формат phase file"

**JSON_SCHEMA_VALIDATION_ERROR:**
- Action: STOP
- Message: "❌ ОШИБКА: Structured Output не прошел валидацию\nПроблема: {schema error}\nКонтекст: {шаг}\nДействие: RETRY с исправлением"

**SYNTAX_ERROR:**
- Action: STOP
- Message: "❌ ОШИБКА: Syntax error в файле\nФайл: {file}\nОшибка: {error}\nДействие: Исправить немедленно, повторить валидацию"

**CRITERIA_NOT_MET:**
- Action: STOP
- Message: "❌ ОШИБКА: Критерии завершения не выполнены\nНе выполнено: {список}\nДействие: Исправить проблемы, повторить валидацию"

**WRONG_BRANCH:**
- Action: STOP
- Message: "❌ ОШИБКА: Не на той ветке\nТекущая: {current}\nОжидаемая: {expected}\nДействие: git checkout {expected} или выполнить Phase 1"

**UNCOMMITTED_CHANGES:**
- Action: STOP
- Message: "❌ ОШИБКА: Есть незакоммиченные изменения\nДействие: Закоммитить или сбросить изменения"

**GIT_COMMIT_FAILED:**
- Action: STOP
- Message: "❌ ОШИБКА: Git commit failed\nОшибка: {error}\nДействие: Проверить git status, исправить проблему"

**CHECKPOINT_FAILED:**
- Action: BLOCKING
- Message: "🛑 CHECKPOINT FAILED\nПроблемы: {blocking_issues}\nДействие: Исправить ошибки, НЕ продолжать"

---

## Startup Sequence

**КРИТИЧНО - выполнить СТРОГО в этом порядке:**

1. ✓ Получить путь к phase file от пользователя
2. ✓ Шаг 1: THINKING - анализ phase file
3. ✓ Шаг 2: STRUCTURED OUTPUT - парсинг phase file (JSON validation)
4. ✓ Шаг 3: Проверить контекст ветки (если фаза > 1)
5. ✓ Шаг 4: Git setup (если Phase 1)
6. ✓ CHECKPOINT 1: STRUCTURED validation
7. ✓ Phase 2 Шаг 1: THINKING - планирование выполнения
8. ✓ Phase 2 Шаг 2: Выполнение шагов по плану
9. ✓ Phase 2 Шаг 3: STRUCTURED OUTPUT - проверка критериев
10. ✓ CHECKPOINT 2: STRUCTURED validation
11. ✓ Phase 3 Шаг 1: THINKING - финальная валидация
12. ✓ Phase 3 Шаг 2: Финальная проверка
13. ✓ Phase 3 Шаг 3: STRUCTURED OUTPUT - git commit
14. ✓ Phase 3 Шаг 4: STRUCTURED OUTPUT - phase summary
15. ✓ **ОСТАНОВИТЬСЯ** - не выполнять следующую фазу автоматически!

**Enforcement:**
- НЕ пропускать ни одного шага
- НЕ менять порядок
- При schema validation error - STOP, RETRY
- При checkpoint FAILED - BLOCKING

---

## Важные напоминания

### ✅ ВСЕГДА ДЕЛАЙТЕ:
- ✓ Используйте THINKING для reasoning
- ✓ Используйте STRUCTURED OUTPUT для validation
- ✓ Проверяйте checkpoint перед переходом к следующей фазе
- ✓ Выполняйте syntax check после каждого шага
- ✓ Делайте git commit по завершении фазы
- ✓ Выводите phase summary

### ❌ НИКОГДА НЕ ДЕЛАЙТЕ:
- ❌ НЕ пропускайте checkpoints
- ❌ НЕ пропускайте structured output validation
- ❌ НЕ продолжайте при schema validation errors
- ❌ НЕ переходите к следующей фазе при checkpoint FAILED
- ❌ НЕ выполняйте следующую фазу автоматически
- ❌ НЕ пропускайте syntax check
- ❌ НЕ пропускайте git commit

---

## Преимущества v2.0

### Structured Output обеспечивает:
1. ✅ **Гарантию парсинга phase file** (все обязательные поля извлечены)
2. ✅ **Точно 5 checks** в Checkpoint 1 (minItems: 5, maxItems: 5)
3. ✅ **Точно 4 checks** в Checkpoint 2 (minItems: 4, maxItems: 4)
4. ✅ **Полноту completion criteria** (каждый критерий проверен)
5. ✅ **Программную валидацию git commit** (commit_hash не пустой, status = success)
6. ✅ **Структурированный summary** (все секции заполнены)

### vs v1.0:
- ❌ v1.0: Claude мог пропустить парсинг phase file
- ✅ v2.0: Schema validation ОШИБКА если поля пропущены

- ❌ v1.0: Claude мог не проверить критерии завершения
- ✅ v2.0: BLOCKING если ready_for_commit = false

- ❌ v1.0: Claude мог пропустить checkpoint
- ✅ v2.0: MANDATORY OUTPUT + schema validation

- ❌ v1.0: Claude мог забыть git commit
- ✅ v2.0: STRUCTURED OUTPUT с commit_hash валидацией

---

## Версия
**Template Version:** 2.0
**Дата:** 2025-11-17
**Изменения:**
- Добавлен structured output для phase parsing, checkpoints, completion criteria, git commit, summary
- Усилен enforcement через JSON Schema
- Добавлена программная валидация готовности к коммиту
- Улучшена валидация checkpoints
- Добавлены строгие entry/exit conditions
