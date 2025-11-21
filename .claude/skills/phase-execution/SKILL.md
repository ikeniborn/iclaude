---
name: Phase Execution
description: Автоматизация выполнения одной фазы из готового phase file с checkpoint validation и structured output
version: 1.0.0
author: Claude Code Team
tags: [phase-based, execution, checkpoint, validation, workflow]
dependencies: [thinking-framework, validation-framework, git-workflow, error-handling]
---

# Phase Execution

Автоматизация выполнения ОДНОЙ фазы из готового phase file. Этот скил parse phase file, проходит 2 обязательных checkpoint, выполняет steps, валидирует completion criteria и создает git commit с structured output.

## Когда использовать этот скил

Используй этот скил когда:
- Нужно выполнить конкретную фазу из готового phase-N-slug.md file
- Phase file уже создан (task-decomposition завершен)
- Нужна автоматизация: parse → validate → execute → commit → summary
- Требуется mandatory checkpoint validation между этапами

Скил автоматически вызывается при запросах типа:
- "Выполни Phase 2 из plans/phase-2-backend-api.md"
- "Execute следующую фазу"
- "Продолжи с Phase N"

## Контекст проекта

### Философия Phase Execution

**Принципы:**
- **One phase at a time:** Выполняем ОДНУ фазу полностью, затем commit
- **Checkpoint-driven:** 2 mandatory checkpoints (Loading, Execution)
- **Structured output:** JSON validation для git_commit, completion_status, phase_summary
- **Branch safety:** Branch context check перед началом
- **Atomic commits:** Каждая фаза = отдельный git commit

### Workflow Overview

```
1. CHECKPOINT 1: ЗАГРУЗКА И АНАЛИЗ
   ├─ Read phase file
   ├─ Parse phase_metadata JSON
   ├─ Validate branch context
   └─ [BLOCKING] Все checks passed

2. EXECUTION
   ├─ Execute steps from phase_metadata.steps[]
   ├─ Validate each step
   └─ Complete all steps

3. CHECKPOINT 2: ВЫПОЛНЕНИЕ
   ├─ Validate completion_status
   ├─ Verify all criteria met
   └─ [BLOCKING] Ready to commit

4. GIT COMMIT
   ├─ Create commit with phase changes
   ├─ Validate git_commit JSON
   └─ Push (optional)

5. PHASE SUMMARY
   ├─ Generate phase_summary JSON
   └─ Output structured results
```

### Dependencies

**Required skills:**
- **thinking-framework**: Phase Analysis Thinking (Шаблон 7) перед началом
- **validation-framework**: Checkpoint Validation (Шаблон 5), Completion Status (Шаблон 7)
- **git-workflow**: Phase Commit (Шаблон 5), Git Commit Validation (Шаблон 6), Branch Context Check (Шаблон 7)
- **error-handling**: Phase-based error types (Шаблон 8-16)

## Шаблоны

### Шаблон 1: Phase File Reading

**Действия:**
1. Прочитать phase file (например: `plans/phase-2-backend-api.md`)
2. Найти секцию `## Phase Metadata (JSON)`
3. Извлечь JSON блок между triple backticks

**Команды:**
```bash
# Check phase file exists
test -f plans/phase-2-backend-api.md && echo "✓ File exists" || echo "✗ File not found"
```

**Exit Conditions:**
- ✓ Phase file прочитан
- ✓ Phase metadata секция найдена

**Violation Action:**
Используй error-handling skill:
- File not found → PHASE_FILE_NOT_FOUND (Шаблон 8) → STOP
- File read error → FILE_READ_ERROR → STOP

---

### Шаблон 2: Phase Metadata Parsing

**Действия:**
1. Извлечь JSON из phase_metadata секции
2. Parse JSON в объект
3. Валидировать структуру (phase_number, phase_name, goal, steps[], etc)

**JSON Structure:**
```json
{
  "phase_metadata": {
    "phase_number": 2,
    "phase_name": "Backend API + JWT Logic",
    "total_phases": 3,
    "goal": "Реализовать login, refresh, logout endpoints",
    "context": {
      "branch_name": "feature/auth-system",
      "base_branch": "master",
      "previous_changes_summary": "Phase 1 создал User и RefreshToken models",
      "dependencies": ["User model", "RefreshToken model"]
    },
    "steps": [
      {
        "step_number": 1,
        "description": "Создать JWTService для генерации токенов",
        "actions": [
          "Создать backend/app/services/jwt_service.py",
          "Реализовать generate_token() method",
          "Реализовать validate_token() method"
        ],
        "validation": "python -m pytest tests/services/test_jwt_service.py"
      }
    ],
    "completion_criteria": [
      "POST /auth/login возвращает access_token и refresh_token",
      "POST /auth/refresh генерирует новый access_token",
      "POST /auth/logout invalidates refresh_token"
    ],
    "commit_message": {
      "type": "feat",
      "summary": "add JWT authentication endpoints",
      "body": "- Implement JWTService\n- Add login, refresh, logout endpoints\n- Add JWT middleware"
    },
    "risks": [
      "JWT SECRET_KEY может быть hardcoded",
      "Password hashing может быть слабым"
    ],
    "validation": {
      "syntax_check_required": true,
      "files_to_check": [
        "backend/app/services/jwt_service.py",
        "backend/app/api/v1/endpoints/auth.py"
      ]
    }
  }
}
```

**Exit Conditions:**
- ✓ JSON parsed успешно
- ✓ Обязательные поля присутствуют (phase_number, phase_name, goal, steps, commit_message)

**Violation Action:**
Используй error-handling skill:
- JSON parse error → PHASE_FILE_PARSE_ERROR (Шаблон 9) → STOP
- Missing required fields → PHASE_FILE_PARSE_ERROR → STOP

---

### Шаблон 3: CHECKPOINT 1 - ЗАГРУЗКА И АНАЛИЗ

**[BLOCKING] Обязательная точка проверки перед началом выполнения.**

Используй validation-framework skill (Шаблон 5: Checkpoint Validation).

**Checkpoint JSON:**
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
        "details": "phase_metadata JSON валиден, все обязательные поля присутствуют"
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

**Verification Output (Markdown):**
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
Используй error-handling skill:
- overall_result = "FAILED" → CHECKPOINT_FAILED (Шаблон 13) → BLOCKING
- Branch context check failed → WRONG_BRANCH (Шаблон 11) или UNCOMMITTED_CHANGES (Шаблон 12) → STOP
- Dependencies not resolved → ENTRY_CONDITION_VIOLATION (Шаблон 16) → STOP

---

### Шаблон 4: Execution Steps

**Действия:**
1. Для каждого `step` в `phase_metadata.steps[]`:
   - **a) Thinking (ОБЯЗАТЕЛЬНО):**
     Используй thinking-framework skill (Phase Analysis Thinking может быть адаптирован для step-level)
   - **b) Выполнить actions:**
     Следовать `step.actions[]` по порядку
   - **c) Валидация шага:**
     Выполнить команду из `step.validation` (если есть)
   - **d) Вывести статус:**
     `✓ Шаг {step_number} выполнен: {description}`

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
- ✓ Каждый step.validation пройден (если указан)

**Violation Action:**
- Step validation failed → Используй error-handling skill → RETRY или STOP
- Action execution error → STOP, анализировать проблему

---

### Шаблон 5: CHECKPOINT 2 - ВЫПОЛНЕНИЕ

**[BLOCKING] Обязательная точка проверки перед git commit.**

Используй validation-framework skill (Шаблон 8: Completion Status Validation).

**Completion Status JSON:**
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

**Verification Output (Markdown):**
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
- ✓ blocking_issues = []
- ✓ criteria_met = criteria_total

**Violation Action:**
Используй error-handling skill:
- overall_status != "COMPLETED" → PHASE_COMPLETION_CRITERIA_NOT_MET (Шаблон 10) → BLOCKING, RETRY (max 2)
- syntax_checks.all_passed = false → SYNTAX_ERROR (Шаблон 4) → STOP

---

### Шаблон 6: Git Commit

Используй git-workflow skill (Шаблон 5: Phase Commit, Шаблон 6: Git Commit Validation).

**Действия:**
1. Stage all modified/created files
2. Create commit с message из `phase_metadata.commit_message`
3. Валидировать commit через git_commit JSON
4. (Optional) Push к remote

**Git Commit JSON:**
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

**Violation Action:**
Используй error-handling skill:
- commit_status = "failed" → GIT_COMMIT_FAILED (Шаблон 7) → STOP

---

### Шаблон 7: Phase Summary

**Phase Summary JSON:**
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
      },
      {
        "file": "backend/app/core/security.py",
        "change_type": "modify",
        "lines_added": 12,
        "lines_removed": 3
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

**Exit Conditions:**
- ✓ Phase summary JSON создан
- ✓ Markdown summary выведен

---

## Проверочный чеклист

После завершения phase execution проверь:

**Phase File:**
- [ ] Phase file прочитан полностью
- [ ] phase_metadata JSON распарсен успешно
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
- [ ] Все completion_criteria выполнены (criteria_met = criteria_total)
- [ ] Syntax checks passed (all_passed = true)
- [ ] Нет blocking_issues

**Git:**
- [ ] Git commit создан (commit_status = success)
- [ ] commit_hash записан
- [ ] Правильная ветка (branch = phase_metadata.context.branch_name)

**Summary:**
- [ ] phase_summary JSON создан
- [ ] Markdown summary выведен
- [ ] Next phase указан (если есть)

## Связанные скилы

- **thinking-framework**: Phase Analysis Thinking (Шаблон 7) перед выполнением
- **validation-framework**: Checkpoint Validation (Шаблон 5), Completion Status (Шаблон 8)
- **git-workflow**: Phase Commit (Шаблон 5), Git Commit Validation (Шаблон 6), Branch Context Check (Шаблон 7)
- **error-handling**: PHASE_FILE_NOT_FOUND (Шаблон 8), PHASE_FILE_PARSE_ERROR (Шаблон 9), PHASE_COMPLETION_CRITERIA_NOT_MET (Шаблон 10), WRONG_BRANCH (Шаблон 11), UNCOMMITTED_CHANGES (Шаблон 12), CHECKPOINT_FAILED (Шаблон 13), ENTRY_CONDITION_VIOLATION (Шаблон 16)
- **task-decomposition**: Phase files созданы этим скилом

## Часто задаваемые вопросы

**Q: Можно ли пропустить checkpoints?**

A: НЕТ! Checkpoints **обязательны** и **блокирующие**. Checkpoint 1 (ЗАГРУЗКА) гарантирует что phase file валиден и branch context правильный. Checkpoint 2 (ВЫПОЛНЕНИЕ) гарантирует что все completion criteria выполнены перед commit.

**Q: Что если checkpoint failed?**

A: STOP немедленно (BLOCKING). Checkpoint failure означает что критичная проверка не прошла:
- Checkpoint 1 failed → исправить phase file / branch context / dependencies
- Checkpoint 2 failed → завершить недостающие критерии, затем RETRY

**Q: Phase file должен быть в конкретной директории?**

A: Рекомендуется `plans/` или `phases/` директория в корне проекта. Phase file naming convention: `phase-{N}-{slug}.md` где slug = lowercase-hyphenated-name.

**Q: Как phase-execution знает какие файлы commit'ить?**

A: Phase execution commit'ит ВСЕ измененные файлы в working directory. Branch context check (Checkpoint 1) гарантирует что нет uncommitted changes ДО начала выполнения фазы, поэтому все changes после выполнения относятся к текущей фазе.

**Q: Можно ли выполнить несколько фаз сразу?**

A: НЕТ! Phase-execution выполняет ОДНУ фазу за раз. Для выполнения всех фаз нужно:
1. Выполнить Phase 1 → commit
2. Выполнить Phase 2 → commit
3. Выполнить Phase N → commit

Это обеспечивает atomic commits и возможность rollback отдельных фаз.

**Q: Что если Phase N зависит от Phase N-1, но Phase N-1 не завершен?**

A: Checkpoint 1 проверит dependencies (Check 4: Dependencies resolved). Если Phase N-1 не завершен → ENTRY_CONDITION_VIOLATION (error-handling Шаблон 16) → STOP. Нужно вернуться к Phase N-1 и завершить его полностью.

**Q: Phase metadata JSON слишком большой - можно сокращать?**

A: НЕТ! phase_metadata JSON должен содержать ВСЕ необходимые поля:
- phase_number, phase_name, total_phases, goal (обязательные)
- context (branch_name, dependencies, previous_changes_summary)
- steps[] (минимум 3, максимум 7 steps)
- completion_criteria[] (минимум 1 criterion)
- commit_message (type, summary, body)

Это обеспечивает полную автоматизацию execution.

**Q: Syntax checks происходят автоматически?**

A: ДА, если `phase_metadata.validation.syntax_check_required = true`. Phase-execution запустит syntax check для всех файлов в `validation.files_to_check[]`. Если syntax check failed → SYNTAX_ERROR (error-handling Шаблон 4) → STOP.

**Q: Phase commit должен быть pushed немедленно?**

A: НЕ обязательно! `git_commit.pushed` может быть `false`. Рекомендуется:
- Push после каждой фазы (для backup)
- Или batch push всех фаз в конце (если быстрая задача)
- Обязательно push перед PR creation

**Q: Phase summary JSON нужен или можно пропустить?**

A: **Обязателен!** Phase summary:
- Документирует результаты фазы
- Указывает next phase для продолжения
- Используется для отчетности (сколько фаз completed, сколько осталось)
- Помогает восстановить контекст после перерыва

**Q: Можно ли модифицировать phase file во время выполнения?**

A: НЕТ! Phase file - read-only reference во время execution. Если нужны изменения в плане фазы:
1. STOP execution
2. Модифицировать phase file (изменить steps, criteria, etc)
3. Restart phase execution с обновленным phase file
