# Task Execution Template v3.0 (Skills-Based)

## Назначение

Выполнение **ОДНОЙ фазы** из готового phase file с автоматизацией через **phase-execution skill**.

**Входные данные:** Путь к phase file (например, `plans/phase-2-backend-api.md`)

**Результат:** Phase executed → Checkpoint validation → Git commit → Phase summary

---

## Конфигурация

- **Режим:** Выполнение одной фазы (без планирования)
- **Skills:** phase-execution, validation-framework, git-workflow, thinking-framework, error-handling
- **Structured Output:** JSON validation для checkpoints, completion status, git commit
- **Git:** Branch context check → Execute → Commit (push опционально)

---

## Принципы

1. **Automated Workflow** - phase-execution skill автоматизирует весь процесс
2. **2 BLOCKING Checkpoints** - обязательная валидация до и после execution
3. **Structured Output** - JSON Schema validation для всех ключевых шагов
4. **Phase Isolation** - каждая фаза = отдельный commit, можно rollback
5. **Dependency Safety** - проверка что предыдущие фазы completed

---

## Workflow Overview

Этот template использует **phase-execution skill** (`.claude/skills/phase-execution/SKILL.md`) для автоматизации выполнения фазы.

```
1. CHECKPOINT 1: ЗАГРУЗКА И АНАЛИЗ (BLOCKING)
   ├─ Read phase file → phase-execution Шаблон 1
   ├─ Parse phase_metadata JSON → phase-execution Шаблон 2
   ├─ Phase Analysis Thinking → thinking-framework Шаблон 7
   ├─ Validate branch context → git-workflow Шаблон 7
   └─ Checkpoint validation → validation-framework Шаблон 5

2. EXECUTION
   ├─ Execute steps from phase_metadata.steps[]
   ├─ Validate each step
   └─ Complete all actions

3. CHECKPOINT 2: ВЫПОЛНЕНИЕ (BLOCKING)
   ├─ Validate completion_status → validation-framework Шаблон 8
   ├─ Syntax checks (if required)
   └─ All completion criteria met

4. GIT COMMIT
   ├─ Stage changes
   ├─ Create commit → git-workflow Шаблон 5
   └─ Validate git_commit JSON → git-workflow Шаблон 6

5. PHASE SUMMARY
   └─ Generate phase_summary JSON → phase-execution Шаблон 7
```

**Skill Dependencies:**
- **phase-execution** (main orchestrator)
- **thinking-framework** (Phase Analysis Thinking - Шаблон 7)
- **validation-framework** (Checkpoint - Шаблон 5, Completion Status - Шаблон 8)
- **git-workflow** (Phase Commit - Шаблон 5-7)
- **error-handling** (Phase errors - Шаблон 8-16)

---

## Входные данные

**Формат запроса:**

```
Выполни Phase 2 из plans/phase-2-backend-api.md
```

ИЛИ

```
Выполни следующую фазу из plans/phase-N-slug.md
```

**Phase File Requirements:**
- Должен содержать `## Phase Metadata (JSON)` секцию
- JSON должен быть валидным и содержать все обязательные поля
- Phase file должен быть создан через task-decomposition skill

---

## Процесс выполнения

### CHECKPOINT 1: ЗАГРУЗКА И АНАЛИЗ (BLOCKING)

**[ОБЯЗАТЕЛЬНЫЙ] Используй phase-execution Шаблон 3**

**Thinking (обязательно):**

Используй **thinking-framework Шаблон 7: Phase Analysis Thinking**

```xml
<thinking>
PHASE FILE: plans/phase-2-backend-api.md
НОМЕР ФАЗЫ: 2/3

ЦЕЛЬ: [из phase_metadata.goal]
ЗАВИСИМОСТИ: [из phase_metadata.context.dependencies]
ПРЕДЫДУЩИЕ ИЗМЕНЕНИЯ: [из phase_metadata.context.previous_changes_summary]

STEPS OVERVIEW: [краткий список из phase_metadata.steps]
COMPLETION CRITERIA: [из phase_metadata.completion_criteria]

РИСКИ: [из phase_metadata.risks]
МИТИГАЦИЯ: [как избежать рисков]

BRANCH CHECK:
- Current branch: [git branch --show-current]
- Expected: [phase_metadata.context.branch_name]
- Uncommitted changes: [git status --porcelain]

DEPENDENCIES RESOLVED:
- [Check каждая dependency из phase_metadata.context.dependencies]

ГОТОВНОСТЬ: [READY/BLOCKED]
</thinking>
```

**Checkpoint Validation:**

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
        "details": "На ветке feature/auth-system, нет uncommitted changes"
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

**Violation Action:** Используй **error-handling Шаблон 13: CHECKPOINT_FAILED** → BLOCKING

---

### EXECUTION: Выполнение Steps

Используй **phase-execution Шаблон 4: Execution Steps**

**Для каждого step в phase_metadata.steps[]:**

1. **Thinking (ОБЯЗАТЕЛЬНО):** Проанализируй step перед выполнением
2. **Execute actions:** Выполни все actions из step.actions[]
3. **Validate step:** Запусти команду из step.validation (если указана)
4. **Output status:** `✓ Шаг {N} выполнен: {description}`

**Пример выполнения:**

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
- ✓ Каждый step.validation пройден (если указан)

---

### CHECKPOINT 2: ВЫПОЛНЕНИЕ (BLOCKING)

**[ОБЯЗАТЕЛЬНЫЙ] Используй phase-execution Шаблон 5**

Используй **validation-framework Шаблон 8: Completion Status Validation**

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
        "criterion": "POST /auth/login возвращает access_token и refresh_token",
        "status": "met",
        "evidence": "curl test passed, tokens returned"
      },
      {
        "criterion": "POST /auth/refresh генерирует новый access_token",
        "status": "met",
        "evidence": "curl test passed, новый token сгенерирован"
      },
      {
        "criterion": "POST /auth/logout invalidates refresh_token",
        "status": "met",
        "evidence": "curl test passed, refresh_token invalid после logout"
      }
    ],
    "syntax_checks": {
      "required": true,
      "files_checked": [
        "backend/app/services/jwt_service.py",
        "backend/app/api/v1/endpoints/auth.py"
      ],
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

[✓] Criterion 1: POST /auth/login возвращает access_token и refresh_token
    Evidence: curl test passed

[✓] Criterion 2: POST /auth/refresh генерирует новый access_token
    Evidence: curl test passed

[✓] Criterion 3: POST /auth/logout invalidates refresh_token
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

**Violation Action:** Используй **error-handling Шаблон 10: PHASE_COMPLETION_CRITERIA_NOT_MET** → BLOCKING

---

### GIT COMMIT

Используй **git-workflow Шаблон 5: Phase Commit** + **Шаблон 6: Git Commit Validation**

**Действия:**

1. Stage all modified/created files
2. Create commit с message из phase_metadata.commit_message
3. Валидировать через git_commit JSON

**ОБЯЗАТЕЛЬНО вывести JSON:**

```json
{
  "git_commit": {
    "branch": "feature/auth-system",
    "commit_hash": "abc123def456",
    "commit_type": "feat",
    "commit_summary": "add JWT authentication endpoints",
    "commit_body": "- Implement JWTService\n- Add login, refresh, logout endpoints\n- Add JWT middleware",
    "files_committed": [
      "backend/app/services/jwt_service.py",
      "backend/app/api/v1/endpoints/auth.py",
      "backend/app/core/security.py"
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

**Violation Action:** Используй **error-handling Шаблон 7: GIT_COMMIT_FAILED** → STOP

---

### PHASE SUMMARY

Используй **phase-execution Шаблон 7: Phase Summary**

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
      },
      {
        "file": "backend/app/api/v1/endpoints/auth.py",
        "change_type": "create",
        "lines_added": 78
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

## Skills Reference

### Required Skills

1. **phase-execution** (`.claude/skills/phase-execution/SKILL.md`)
   - Шаблон 1: Phase File Reading
   - Шаблон 2: Phase Metadata Parsing
   - Шаблон 3: CHECKPOINT 1 - ЗАГРУЗКА
   - Шаблон 4: Execution Steps
   - Шаблон 5: CHECKPOINT 2 - ВЫПОЛНЕНИЕ
   - Шаблон 6: Git Commit
   - Шаблон 7: Phase Summary

2. **thinking-framework** (`.claude/skills/thinking-framework/SKILL.md`)
   - Шаблон 7: Phase Analysis Thinking

3. **validation-framework** (`.claude/skills/validation-framework/SKILL.md`)
   - Шаблон 5: Checkpoint Validation
   - Шаблон 8: Completion Status Validation

4. **git-workflow** (`.claude/skills/git-workflow/SKILL.md`)
   - Шаблон 5: Phase Commit
   - Шаблон 6: Git Commit Validation
   - Шаблон 7: Branch Context Check

5. **error-handling** (`.claude/skills/error-handling/SKILL.md`)
   - Шаблон 8: PHASE_FILE_NOT_FOUND
   - Шаблон 9: PHASE_FILE_PARSE_ERROR
   - Шаблон 10: PHASE_COMPLETION_CRITERIA_NOT_MET
   - Шаблон 11: WRONG_BRANCH
   - Шаблон 12: UNCOMMITTED_CHANGES
   - Шаблон 13: CHECKPOINT_FAILED
   - Шаблон 16: ENTRY_CONDITION_VIOLATION

---

## FAQ

**Q: Можно ли пропустить checkpoints?**

A: НЕТ! Checkpoints **обязательны** и **блокирующие** (BLOCKING). Checkpoint 1 гарантирует что phase file валиден и branch context правильный. Checkpoint 2 гарантирует что все completion criteria выполнены перед commit.

**Q: Что если checkpoint failed?**

A: STOP немедленно (BLOCKING). Checkpoint failure означает критичную проблему:
- Checkpoint 1 failed → исправить phase file / branch context / dependencies
- Checkpoint 2 failed → завершить недостающие критерии, затем RETRY

**Q: Phase file должен быть в конкретной директории?**

A: Рекомендуется `plans/` директория. Phase file naming: `phase-{N}-{slug}.md`

**Q: Можно ли выполнить несколько фаз сразу?**

A: НЕТ! Этот template выполняет ОДНУ фазу за раз. Для всех фаз:
1. Выполни Phase 1 → commit
2. Выполни Phase 2 → commit
3. Выполни Phase N → commit

Это обеспечивает atomic commits и rollback capability.

**Q: Что если Phase N зависит от Phase N-1, но Phase N-1 не завершен?**

A: Checkpoint 1 проверит dependencies (Check 4). Если Phase N-1 не завершен → ENTRY_CONDITION_VIOLATION (error-handling Шаблон 16) → STOP.

---

## Проверочный чеклист

После завершения phase execution:

**Phase File:**
- [ ] Phase file прочитан полностью
- [ ] phase_metadata JSON распарсен
- [ ] Все обязательные поля присутствуют

**Checkpoints:**
- [ ] Checkpoint 1 (ЗАГРУЗКА) пройден (overall_result = PASSED)
- [ ] Checkpoint 2 (ВЫПОЛНЕНИЕ) пройден (overall_status = COMPLETED)
- [ ] can_proceed_to_commit = true

**Execution:**
- [ ] Все steps выполнены по порядку
- [ ] Каждый step.validation пройден
- [ ] Все actions завершены успешно

**Completion:**
- [ ] Все completion_criteria выполнены
- [ ] Syntax checks passed (если required)
- [ ] Нет blocking_issues

**Git:**
- [ ] Git commit создан (commit_status = success)
- [ ] commit_hash записан
- [ ] Правильная ветка (branch = phase_metadata.context.branch_name)

**Summary:**
- [ ] phase_summary JSON создан
- [ ] Markdown summary выведен
- [ ] Next phase указан (если есть)

---

## Связанные Templates

- **task-planning-template-v3.md** - для создания phase files (decomposition)
- **task-lite-template-v3.md** - для простых задач (single-phase)
