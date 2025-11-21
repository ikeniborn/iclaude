# Task Execution Template v3.1 (User-Friendly)

## Назначение

Выполнение **ОДНОЙ фазы** из готового phase file с автоматическими проверками, валидацией и git commit.

**Для пользователя:** Просто укажите путь к phase file. Claude автоматически выполнит фазу с проверками на каждом этапе.

---

## 📋 Входные данные

**Какую фазу выполнить:**

```
Выполни Phase 2 из plans/phase-2-backend-api.md
```

ИЛИ

```
Выполни следующую фазу из plans/phase-3-frontend-integration.md
```

**Требования к phase file:**
- Файл должен существовать в `plans/` директории
- Создан через task-planning-template-v3.md
- Содержит валидный phase metadata JSON

---

## ⚙️ Конфигурация (для Claude)

<details>
<summary>Внутренние настройки (автоматические)</summary>

- **Skills:** phase-execution, validation-framework, git-workflow, thinking-framework, error-handling
- **Checkpoints:** 2 BLOCKING checkpoints (загрузка + выполнение)
- **Structured Output:** JSON validation для всех ключевых шагов
- **Git:** Checkpoint → Execute → Validate → Commit (push опционально)
- **Branch Safety:** Проверка branch context, dependencies, uncommitted changes

</details>

---

## 🔄 Workflow (выполняется автоматически)

Claude автоматически выполнит следующую последовательность:

### 1️⃣ CHECKPOINT 1: ЗАГРУЗКА И АНАЛИЗ

**Что Claude сделает:**
- Прочитает phase file
- Извлечет phase metadata (цель, шаги, критерии)
- Проверит branch context (правильная ветка, нет uncommitted changes)
- Проверит dependencies (предыдущие фазы completed)
- Выведет результат проверки

**Пример вывода:**
```
═══════════════════════════════════════════════════════════
      CHECKPOINT 1: ЗАГРУЗКА И АНАЛИЗ
═══════════════════════════════════════════════════════════

[✓] Phase file прочитан: plans/phase-2-backend-api.md (127 строк)
[✓] Phase metadata валиден: 5 steps, 3 completion criteria
[✓] Branch context: feature/auth-system, clean working directory
[✓] Dependencies resolved: User model exists, RefreshToken model exists

РЕЗУЛЬТАТ: ✓ PASSED
Переход к execution: ALLOWED
═══════════════════════════════════════════════════════════
```

**Если CHECKPOINT FAILED:**
- Claude остановится и покажет проблему
- Нужно исправить проблему и попробовать снова

---

### 2️⃣ ВЫПОЛНЕНИЕ STEPS

**Что Claude сделает:**
- Выполнит каждый step из phase metadata последовательно
- Для каждого step: выполнит actions + запустит validation
- Выведет статус каждого шага

**Пример вывода:**
```
Выполняю Phase 2, Step 1: Создать JWTService

Действия:
1. Создать backend/app/services/jwt_service.py ✓
2. Реализовать generate_token() method ✓
3. Реализовать validate_token() method ✓

Validation: python -m pytest tests/services/test_jwt_service.py
→ Output: 3 passed in 0.12s ✓

✓ Шаг 1 выполнен: Создать JWTService для генерации токенов

---

Выполняю Phase 2, Step 2: Реализовать POST /auth/login endpoint
...
```

---

### 3️⃣ CHECKPOINT 2: ПРОВЕРКА ВЫПОЛНЕНИЯ

**Что Claude сделает:**
- Проверит все completion criteria из phase metadata
- Запустит syntax checks для измененных файлов
- Выведет результат проверки

**Пример вывода:**
```
═══════════════════════════════════════════════════════════
     CHECKPOINT 2: ВЫПОЛНЕНИЕ (Phase 2)
═══════════════════════════════════════════════════════════

COMPLETION CRITERIA: 3/3 ✓

[✓] POST /auth/login возвращает access_token и refresh_token
    Evidence: curl test passed, tokens returned

[✓] POST /auth/refresh генерирует новый access_token
    Evidence: curl test passed

[✓] POST /auth/logout invalidates refresh_token
    Evidence: curl test passed

SYNTAX CHECKS: ✓ All passed (2 files)

РЕЗУЛЬТАТ: ✓ COMPLETED
Переход к commit: ALLOWED
═══════════════════════════════════════════════════════════
```

**Если CHECKPOINT FAILED:**
- Claude покажет какие критерии не выполнены
- Исправит проблемы автоматически (max 2 попытки)
- Или остановится если не может исправить

---

### 4️⃣ GIT COMMIT

**Что Claude сделает:**
- Создаст commit с сообщением из phase metadata
- Использует Conventional Commits format
- Выведет commit hash

**Пример вывода:**
```
GIT COMMIT:
- Branch: feature/auth-system
- Commit: abc123def456
- Type: feat
- Summary: add JWT authentication endpoints

Files committed:
- backend/app/services/jwt_service.py (create, +45 lines)
- backend/app/api/v1/endpoints/auth.py (create, +78 lines)
- backend/app/core/security.py (modify, +12/-3 lines)

✓ Commit created successfully
```

---

### 5️⃣ PHASE SUMMARY

**Что Claude сделает:**
- Выведет итоговый summary фазы
- Покажет следующую фазу (если есть)

**Пример вывода:**
```
═══════════════════════════════════════════════════════════
       ✅ PHASE 2 ЗАВЕРШЕНА
═══════════════════════════════════════════════════════════

СТАТУС: ✓ COMPLETED

PHASE: 2/3 - Backend API + JWT Logic

ИЗМЕНЕНИЯ:
- backend/app/services/jwt_service.py (create, +45)
- backend/app/api/v1/endpoints/auth.py (create, +78)
- backend/app/core/security.py (modify, +12/-3)

COMPLETION CRITERIA: ✓ 3/3 выполнены

GIT:
- Branch: feature/auth-system
- Commit: abc123def456
- Type: feat
- Summary: add JWT authentication endpoints

NEXT PHASE:
→ Phase 3: Frontend Integration
  File: plans/phase-3-frontend-integration.md

  Для выполнения:
  "Выполни Phase 3 из plans/phase-3-frontend-integration.md"

═══════════════════════════════════════════════════════════
```

---

## 🔧 Технические детали (для разработчиков)

<details>
<summary>Детали реализации workflow</summary>

### CHECKPOINT 1: ЗАГРУЗКА И АНАЛИЗ (BLOCKING)

**[INTERNAL] Phase Analysis Thinking**

Используй **thinking-framework Шаблон 7: Phase Analysis Thinking**

```xml
<thinking>
PHASE FILE: [путь]
НОМЕР ФАЗЫ: [N/total]

ЦЕЛЬ: [из phase_metadata.goal]
ЗАВИСИМОСТИ: [из phase_metadata.context.dependencies]
ПРЕДЫДУЩИЕ ИЗМЕНЕНИЯ: [из phase_metadata.context.previous_changes_summary]

STEPS OVERVIEW: [краткий список из phase_metadata.steps]
COMPLETION CRITERIA: [из phase_metadata.completion_criteria]

РИСКИ: [из phase_metadata.risks]
МИТИГАЦИЯ: [как избежать]

BRANCH CHECK:
- Current branch: [git branch --show-current]
- Expected: [phase_metadata.context.branch_name]
- Uncommitted changes: [git status --porcelain]

DEPENDENCIES RESOLVED:
- [Check каждая dependency]

ГОТОВНОСТЬ: [READY/BLOCKED]
</thinking>
```

**[INTERNAL] Checkpoint Validation**

Используй **validation-framework Шаблон 5: Checkpoint Validation**

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
        "details": "plans/phase-2-backend-api.md (127 строк)"
      },
      {
        "check_id": 2,
        "check_name": "Phase metadata parsed",
        "status": "passed",
        "details": "phase_metadata JSON валиден"
      },
      {
        "check_id": 3,
        "check_name": "Branch context valid",
        "status": "passed",
        "details": "feature/auth-system, clean"
      },
      {
        "check_id": 4,
        "check_name": "Dependencies resolved",
        "status": "passed",
        "details": "User model exists, RefreshToken model exists"
      }
    ],
    "overall_result": "PASSED",
    "can_proceed_to_execution": true,
    "blocking_issues": []
  }
}
```

**Markdown Output:**

```
═══════════════════════════════════════════════════════════
      CHECKPOINT 1: ЗАГРУЗКА И АНАЛИЗ
═══════════════════════════════════════════════════════════

[✓] Check 1: Phase file прочитан
    Details: plans/phase-2-backend-api.md (127 строк)

[✓] Check 2: Phase metadata parsed
    Details: phase_metadata JSON валиден

[✓] Check 3: Branch context valid
    Details: feature/auth-system, clean working directory

[✓] Check 4: Dependencies resolved
    Details: User model exists, RefreshToken model exists

РЕЗУЛЬТАТ: ✓ PASSED
Переход к execution: ALLOWED
═══════════════════════════════════════════════════════════
```

**Exit Conditions:**
- ✓ overall_result = "PASSED"
- ✓ can_proceed_to_execution = true
- ✓ blocking_issues = []

**Violation Action:**
Используй **error-handling Шаблон 13: CHECKPOINT_FAILED** → BLOCKING

</details>

<details>
<summary>Execution Steps (детали)</summary>

**[INTERNAL] Используй phase-execution Шаблон 4: Execution Steps**

**Для каждого step в phase_metadata.steps[]:**

1. **Thinking (ОБЯЗАТЕЛЬНО):** Проанализируй step перед выполнением
2. **Execute actions:** Выполни все actions из step.actions[]
3. **Validate step:** Запусти команду из step.validation (если указана)
4. **Output status:** `✓ Шаг {N} выполнен: {description}`

**Пример:**

```
Выполняю Phase 2, Step 1: Создать JWTService

Действия:
1. Создать backend/app/services/jwt_service.py ✓
2. Реализовать generate_token() method ✓
3. Реализовать validate_token() method ✓

Validation: python -m pytest tests/services/test_jwt_service.py
→ Output: 3 passed in 0.12s ✓

✓ Шаг 1 выполнен: Создать JWTService для генерации токенов
```

**Exit Conditions:**
- ✓ Все steps выполнены
- ✓ Каждый step.validation пройден

</details>

<details>
<summary>CHECKPOINT 2: ВЫПОЛНЕНИЕ (детали)</summary>

**[INTERNAL] Используй validation-framework Шаблон 8: Completion Status Validation**

**ОБЯЗАТЕЛЬНО вывести JSON:**

```json
{
  "completion_status": {
    "phase_number": 2,
    "phase_name": "Backend API + JWT Logic",
    "criteria_total": 3,
    "criteria_met": 3,
    "criteria_not_met": [],
    "criteria_details": [
      {
        "criterion": "POST /auth/login возвращает access_token",
        "status": "met",
        "evidence": "curl test passed"
      }
    ],
    "syntax_checks": {
      "required": true,
      "files_checked": ["backend/app/services/jwt_service.py"],
      "all_passed": true,
      "failures": []
    },
    "overall_status": "COMPLETED",
    "can_proceed_to_commit": true,
    "blocking_issues": []
  }
}
```

**Markdown Output:**

```
═══════════════════════════════════════════════════════════
     CHECKPOINT 2: ВЫПОЛНЕНИЕ (Phase 2)
═══════════════════════════════════════════════════════════

COMPLETION CRITERIA: 3/3 ✓

[✓] Criterion 1: POST /auth/login возвращает access_token
    Evidence: curl test passed

SYNTAX CHECKS: ✓ All passed (2 files)

РЕЗУЛЬТАТ: ✓ COMPLETED
Переход к commit: ALLOWED
═══════════════════════════════════════════════════════════
```

**Exit Conditions:**
- ✓ overall_status = "COMPLETED"
- ✓ can_proceed_to_commit = true
- ✓ criteria_met = criteria_total

**Violation Action:**
Используй **error-handling Шаблон 10: PHASE_COMPLETION_CRITERIA_NOT_MET** → BLOCKING, RETRY (max 2)

</details>

<details>
<summary>Git Commit (детали)</summary>

**[INTERNAL] Используй git-workflow Шаблон 5: Phase Commit + Шаблон 6: Git Commit Validation**

**Действия:**
1. Stage all modified/created files
2. Create commit с message из phase_metadata.commit_message
3. Validate через git_commit JSON

**ОБЯЗАТЕЛЬНО вывести JSON:**

```json
{
  "git_commit": {
    "branch": "feature/auth-system",
    "commit_hash": "abc123def456",
    "commit_type": "feat",
    "commit_summary": "add JWT authentication endpoints",
    "commit_body": "- Implement JWTService\n- Add login, refresh, logout endpoints",
    "files_committed": [
      "backend/app/services/jwt_service.py",
      "backend/app/api/v1/endpoints/auth.py"
    ],
    "commit_status": "success",
    "pushed": false,
    "push_status": null
  }
}
```

**Exit Conditions:**
- ✓ commit_status = "success"
- ✓ commit_hash recorded

**Violation Action:**
Используй **error-handling Шаблон 7: GIT_COMMIT_FAILED** → STOP

</details>

<details>
<summary>Phase Summary (детали)</summary>

**[INTERNAL] Используй phase-execution Шаблон 7: Phase Summary**

**ОБЯЗАТЕЛЬНО вывести JSON:**

```json
{
  "phase_summary": {
    "phase_number": 2,
    "phase_name": "Backend API + JWT Logic",
    "status": "COMPLETED",
    "commit_hash": "abc123def456",
    "files_changed": [
      {
        "file": "backend/app/services/jwt_service.py",
        "change_type": "create",
        "lines_added": 45
      }
    ],
    "completion_criteria_met": 3,
    "total_completion_criteria": 3,
    "next_phase": {
      "phase_number": 3,
      "phase_name": "Frontend Integration",
      "file": "plans/phase-3-frontend-integration.md"
    }
  }
}
```

**Markdown Summary:**

```
═══════════════════════════════════════════════════════════
       ✅ PHASE 2 ЗАВЕРШЕНА
═══════════════════════════════════════════════════════════

СТАТУС: ✓ COMPLETED

PHASE: 2/3 - Backend API + JWT Logic

ИЗМЕНЕНИЯ:
- backend/app/services/jwt_service.py (create, +45)

COMPLETION CRITERIA: ✓ 3/3 выполнены

GIT:
- Branch: feature/auth-system
- Commit: abc123def456

NEXT PHASE:
→ Phase 3: Frontend Integration
  File: plans/phase-3-frontend-integration.md

═══════════════════════════════════════════════════════════
```

</details>

<details>
<summary>Error Handling (детали)</summary>

**[INTERNAL] Используй error-handling skill при любых ошибках**

**Phase-specific error types:**
- **PHASE_FILE_NOT_FOUND** (Шаблон 8) → STOP
- **PHASE_FILE_PARSE_ERROR** (Шаблон 9) → STOP
- **PHASE_COMPLETION_CRITERIA_NOT_MET** (Шаблон 10) → BLOCKING, RETRY (max 2)
- **WRONG_BRANCH** (Шаблон 11) → STOP/BLOCKING
- **UNCOMMITTED_CHANGES** (Шаблон 12) → STOP/BLOCKING
- **CHECKPOINT_FAILED** (Шаблон 13) → BLOCKING
- **ENTRY_CONDITION_VIOLATION** (Шаблон 16) → STOP/BLOCKING
- **GIT_COMMIT_FAILED** (Шаблон 7) → STOP

**Формат error message:**

```
🚨 ОШИБКА: {Type}

Проблема: [описание]
Контекст: [где произошло]
Действие: [STOP/RETRY/BLOCKING]
```

</details>

---

## 📚 FAQ

**Q: Что если phase file не существует?**

A: Claude остановится с ошибкой PHASE_FILE_NOT_FOUND и попросит проверить путь.

**Q: Можно ли пропустить checkpoints?**

A: НЕТ! Checkpoints **обязательны** и **блокирующие**. Checkpoint 1 гарантирует что phase file валиден и branch context правильный. Checkpoint 2 гарантирует что все completion criteria выполнены перед commit.

**Q: Что если checkpoint failed?**

A: Claude STOP немедленно (BLOCKING). Показывает какие checks failed, нужно исправить и попробовать снова.

**Q: Phase file должен быть в plans/ директории?**

A: Рекомендуется, но не обязательно. Можно указать любой путь: `plans/phase-2.md` или `docs/phases/phase-2.md`.

**Q: Можно ли выполнить несколько фаз сразу?**

A: НЕТ! Этот template выполняет ОДНУ фазу за раз. Для всех фаз нужно запустить template несколько раз:
1. "Выполни Phase 1 из plans/phase-1.md" → commit
2. "Выполни Phase 2 из plans/phase-2.md" → commit
3. "Выполни Phase 3 из plans/phase-3.md" → commit

Это обеспечивает atomic commits и rollback capability.

**Q: Что если Phase N зависит от Phase N-1, но Phase N-1 не завершен?**

A: Checkpoint 1 проверит dependencies (Check 4: Dependencies resolved). Если Phase N-1 не завершен → ENTRY_CONDITION_VIOLATION → STOP. Нужно вернуться к Phase N-1 и завершить его полностью.

**Q: Syntax checks происходят автоматически?**

A: ДА, если `phase_metadata.validation.syntax_check_required = true`. Claude запустит syntax check для всех файлов в `validation.files_to_check[]`.

**Q: Phase commit должен быть pushed немедленно?**

A: НЕ обязательно! `git_commit.pushed` может быть `false`. Можно push после каждой фазы или batch push всех фаз в конце.

---

## 📝 Version

**Template Version:** 3.1 (User-Friendly)
**Дата:** 2025-11-21
**Changelog:**
- v3.1: User-friendly интерфейс
  - Секция "## 📋 Входные данные" для пользователя
  - Workflow описан естественным языком
  - Skills используются автоматически (скрыты в `<details>`)
  - Маркеры [INTERNAL] для инструкций Claude
  - Примеры вывода для каждого этапа
- v3.0: Первая skills-based версия
  - Рефакторинг из 1157 строк в 541 строку
  - Автоматизация через phase-execution skill
