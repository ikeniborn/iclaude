---
name: Phase Execution
description: Автоматизация выполнения одной фазы из готового phase file с checkpoint validation и structured output
version: 1.2.0
author: Claude Code Team
tags: [phase-based, execution, checkpoint, validation, workflow]
dependencies: [thinking-framework, validation-framework, git-workflow, error-handling]
user-invocable: false
changelog:
  - version: 1.2.0
    date: 2026-01-25
    changes:
      - "Удалено: TOON Format Support дублирование (~148 строк)"
      - "Добавлено: References к @shared:TOON-REFERENCE.md, @shared:THINKING-PATTERNS.md, @shared:GIT-CONVENTIONS.md, @shared:TASK-STRUCTURE.md"
      - "Обновлено: Устаревшие references \"Шаблон N\" заменены на @shared: links"
      - "Добавлено: 7 complete working examples (simple, standard, complex, checkpoint failures, multi-step, complete workflow)"
      - "Добавлено: Skill-specific TOON usage notes для checkpoint.checks[] и files_changed[]"
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
- **thinking-framework**: `@shared:THINKING-PATTERNS.md#analysis` для phase analysis
- **validation-framework**: Checkpoint Validation, Completion Status
- **git-workflow**: `@shared:GIT-CONVENTIONS.md#conventional-commits` для phase commit
- **error-handling**: Phase-based error types

---

## References

**TOON Format:**
- Спецификация: `@shared:TOON-REFERENCE.md`
- Применение к checkpoint.checks[] и files_changed[]: см. Skill-specific TOON usage ниже

**Task Structure:**
- JSON schemas: `@shared:TASK-STRUCTURE.md#execution-step`
- Git commit schema: `@shared:TASK-STRUCTURE.md#git-commit`
- Completion status schema: `@shared:TASK-STRUCTURE.md#validation-result`

**Thinking Framework:**
- Analysis thinking: `@shared:THINKING-PATTERNS.md#analysis`
- Risk thinking для checkpoints: `@shared:THINKING-PATTERNS.md#risk`

**Git Conventions:**
- Commit message format: `@shared:GIT-CONVENTIONS.md#conventional-commits`
- Branch naming: `@shared:GIT-CONVENTIONS.md#branch-naming`
- Co-authored commits: `@shared:GIT-CONVENTIONS.md#co-authored-by`

---

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
- File not found → PHASE_FILE_NOT_FOUND → STOP
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
- JSON parse error → PHASE_FILE_PARSE_ERROR → STOP
- Missing required fields → PHASE_FILE_PARSE_ERROR → STOP

---

### Шаблон 3: CHECKPOINT 1 - ЗАГРУЗКА И АНАЛИЗ

**[BLOCKING] Обязательная точка проверки перед началом выполнения.**

Используй validation-framework skill.

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
- overall_result = "FAILED" → CHECKPOINT_FAILED → BLOCKING
- Branch context check failed → WRONG_BRANCH или UNCOMMITTED_CHANGES → STOP
- Dependencies not resolved → ENTRY_CONDITION_VIOLATION → STOP

---

### Шаблон 4: Execution Steps

**Действия:**
1. Для каждого `step` в `phase_metadata.steps[]`:
   - **a) Thinking (ОБЯЗАТЕЛЬНО):**
     Используй thinking-framework skill (`@shared:THINKING-PATTERNS.md#analysis`)
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

Используй validation-framework skill.

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
- overall_status != "COMPLETED" → PHASE_COMPLETION_CRITERIA_NOT_MET → BLOCKING, RETRY (max 2)
- syntax_checks.all_passed = false → SYNTAX_ERROR → STOP

---

### Шаблон 6: Git Commit

Используй git-workflow skill (`@shared:GIT-CONVENTIONS.md#conventional-commits`).

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
- commit_status = "failed" → GIT_COMMIT_FAILED → STOP

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

## Skill-Specific TOON Usage

**TOON генерируется для:**
- **checkpoint.checks[]** когда checks.length >= 5 (расширенные checkpoints)
- **phase_summary.files_changed[]** когда files_changed.length >= 5 (typical для standard/complex phases)

**Optimization pattern:**
```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Checkpoint output с TOON
const checkpoint = {
  checkpoint_id: 1,
  checkpoint_name: "ЗАГРУЗКА И АНАЛИЗ",
  checks: [...]  // 5+ elements
};

// Add TOON optimization
if (checkpoint.checks.length >= 5) {
  checkpoint.toon = {
    checks_toon: arrayToToon('checks', checkpoint.checks,
      ['check_id', 'check_name', 'status', 'details']),
    ...calculateTokenSavings({ checks: checkpoint.checks })
  };
}

// Phase summary output с TOON
const phaseSummary = {
  phase_number: 2,
  files_changed: [...]  // 7+ files
};

if (phaseSummary.files_changed.length >= 5) {
  // Normalize lines_removed field (default to 0)
  const filesNormalized = phaseSummary.files_changed.map(f => ({
    file: f.file,
    change_type: f.change_type,
    lines_added: f.lines_added,
    lines_removed: f.lines_removed || 0
  }));

  phaseSummary.toon = {
    files_changed_toon: arrayToToon('files_changed', filesNormalized,
      ['file', 'change_type', 'lines_added', 'lines_removed']),
    ...calculateTokenSavings({ files_changed: filesNormalized })
  };
}
```

**Token savings:**
- Checkpoint (5-6 checks): ~28-32% savings
- Files changed (7-15 files): ~32-40% savings
- Combined workflow: ~35-40% total reduction

См. `@shared:TOON-REFERENCE.md#token-savings` для детальной спецификации.

---

## Domain-Specific Examples

### Example 1: Simple Phase Execution (3-4 files)

**Phase file:** `plans/phase-1-database-models.md`

**Phase metadata:**
```json
{
  "phase_metadata": {
    "phase_number": 1,
    "phase_name": "Database Models",
    "total_phases": 3,
    "goal": "Create User and RefreshToken models",
    "steps": [
      {
        "step_number": 1,
        "description": "Create User model",
        "actions": [
          "Create models/user.py",
          "Add email, password_hash, created_at fields"
        ],
        "validation": "python -m pytest tests/models/test_user.py"
      },
      {
        "step_number": 2,
        "description": "Create RefreshToken model",
        "actions": [
          "Create models/refresh_token.py",
          "Add token, user_id, expires_at fields"
        ],
        "validation": "python -m pytest tests/models/test_refresh_token.py"
      }
    ],
    "completion_criteria": [
      "User model created with required fields",
      "RefreshToken model created with foreign key to User"
    ],
    "commit_message": {
      "type": "feat",
      "summary": "add User and RefreshToken database models",
      "body": "- Create User model with authentication fields\n- Create RefreshToken model for JWT refresh flow"
    }
  }
}
```

**Execution:**
```
Checkpoint 1: ЗАГРУЗКА И АНАЛИЗ
[✓] All checks passed

Step 1: Create User model
→ Created models/user.py ✓
→ Tests passed ✓

Step 2: Create RefreshToken model
→ Created models/refresh_token.py ✓
→ Tests passed ✓

Checkpoint 2: ВЫПОЛНЕНИЕ
[✓] Completion criteria: 2/2 met
[✓] Syntax checks: passed

Git Commit:
→ Commit hash: a1b2c3d
→ Files: models/user.py, models/refresh_token.py, tests/models/test_user.py, tests/models/test_refresh_token.py

Phase Summary:
✅ PHASE 1 ЗАВЕРШЕНА (4 files changed)
```

**Result:** Simple phase completed with 4 files. No TOON optimization (< 5 files threshold).

---

### Example 2: Standard Phase Execution (5-7 files, checkpoint validation)

**Phase file:** `plans/phase-2-backend-api.md`

**Phase metadata:**
```json
{
  "phase_metadata": {
    "phase_number": 2,
    "phase_name": "Backend API + JWT Logic",
    "total_phases": 3,
    "goal": "Implement authentication endpoints",
    "context": {
      "branch_name": "feature/auth-system",
      "dependencies": ["User model", "RefreshToken model"]
    },
    "steps": [
      {"step_number": 1, "description": "Create JWTService", "actions": ["..."], "validation": "pytest tests/services/test_jwt_service.py"},
      {"step_number": 2, "description": "Create auth endpoints", "actions": ["..."], "validation": "pytest tests/api/test_auth.py"},
      {"step_number": 3, "description": "Add JWT middleware", "actions": ["..."], "validation": "pytest tests/middleware/test_auth.py"}
    ],
    "completion_criteria": [
      "POST /auth/login returns tokens",
      "POST /auth/refresh generates new access_token",
      "POST /auth/logout invalidates refresh_token"
    ],
    "commit_message": {
      "type": "feat",
      "summary": "add JWT authentication endpoints",
      "body": "..."
    }
  }
}
```

**Execution:**
```
Checkpoint 1: ЗАГРУЗКА И АНАЛИЗ
[✓] Phase file read (127 lines)
[✓] Phase metadata parsed
[✓] Branch: feature/auth-system ✓
[✓] Dependencies: User model ✓, RefreshToken model ✓

Step 1: Create JWTService
→ Created services/jwt_service.py ✓
→ Tests passed (3 passed) ✓

Step 2: Create auth endpoints
→ Created api/v1/endpoints/auth.py ✓
→ Tests passed (5 passed) ✓

Step 3: Add JWT middleware
→ Created middleware/auth_middleware.py ✓
→ Tests passed (2 passed) ✓

Checkpoint 2: ВЫПОЛНЕНИЕ
[✓] Completion criteria: 3/3 met
  - POST /auth/login: ✓ (curl test passed)
  - POST /auth/refresh: ✓ (curl test passed)
  - POST /auth/logout: ✓ (curl test passed)
[✓] Syntax checks: 3 files passed

Git Commit:
→ Branch: feature/auth-system
→ Commit: b2c3d4e
→ Type: feat
→ Summary: add JWT authentication endpoints
→ Files committed: 6

Phase Summary (with TOON):
{
  "phase_summary": {
    "phase_number": 2,
    "status": "COMPLETED",
    "files_changed": [
      {"file": "services/jwt_service.py", "change_type": "create", "lines_added": 45},
      {"file": "api/v1/endpoints/auth.py", "change_type": "create", "lines_added": 78},
      {"file": "middleware/auth_middleware.py", "change_type": "create", "lines_added": 34},
      {"file": "tests/services/test_jwt_service.py", "change_type": "create", "lines_added": 56},
      {"file": "tests/api/test_auth.py", "change_type": "create", "lines_added": 89},
      {"file": "core/security.py", "change_type": "modify", "lines_added": 12, "lines_removed": 3}
    ],
    "toon": {
      "files_changed_toon": "files_changed[6]{file,change_type,lines_added,lines_removed}:\n  services/jwt_service.py,create,45,0\n  api/v1/endpoints/auth.py,create,78,0\n  middleware/auth_middleware.py,create,34,0\n  tests/services/test_jwt_service.py,create,56,0\n  tests/api/test_auth.py,create,89,0\n  core/security.py,modify,12,3",
      "token_savings": "31.2%"
    }
  }
}

✅ PHASE 2 ЗАВЕРШЕНА (6 files changed, 31.2% token savings)
```

**Result:** Standard phase with 6 files. TOON optimization applied (>= 5 files threshold). Token savings: 31.2%.

---

### Example 3: Complex Phase with TOON (10+ files)

**Phase file:** `plans/phase-2-refactor-auth-system.md`

**Phase metadata:**
```json
{
  "phase_metadata": {
    "phase_number": 2,
    "phase_name": "Authentication System Refactoring",
    "total_phases": 4,
    "goal": "Refactor monolithic auth module into services",
    "steps": [
      {"step_number": 1, "description": "Extract JWTService", "actions": ["..."]},
      {"step_number": 2, "description": "Extract PasswordHashService", "actions": ["..."]},
      {"step_number": 3, "description": "Extract EmailVerificationService", "actions": ["..."]},
      {"step_number": 4, "description": "Refactor auth endpoints to use services", "actions": ["..."]},
      {"step_number": 5, "description": "Update tests", "actions": ["..."]}
    ],
    "completion_criteria": [
      "All auth endpoints use new services",
      "All tests pass",
      "No circular dependencies"
    ],
    "commit_message": {
      "type": "refactor",
      "summary": "extract authentication services from monolithic module",
      "body": "..."
    }
  }
}
```

**Execution:**
```
Checkpoint 1: ЗАГРУЗКА И АНАЛИЗ
[✓] All 4 checks passed

Execution: 5 steps completed
→ Step 1: Extract JWTService ✓
→ Step 2: Extract PasswordHashService ✓
→ Step 3: Extract EmailVerificationService ✓
→ Step 4: Refactor auth endpoints ✓
→ Step 5: Update tests ✓

Checkpoint 2: ВЫПОЛНЕНИЕ
[✓] Completion criteria: 3/3 met

Git Commit:
→ Commit: c3d4e5f
→ Type: refactor

Phase Summary (with TOON):
{
  "phase_summary": {
    "phase_number": 2,
    "status": "COMPLETED",
    "commit_hash": "c3d4e5f",
    "files_changed": [
      {"file": "services/jwt_service.py", "change_type": "create", "lines_added": 67},
      {"file": "services/password_hash_service.py", "change_type": "create", "lines_added": 45},
      {"file": "services/email_verification_service.py", "change_type": "create", "lines_added": 89},
      {"file": "api/v1/endpoints/auth.py", "change_type": "modify", "lines_added": 34, "lines_removed": 156},
      {"file": "api/v1/endpoints/registration.py", "change_type": "modify", "lines_added": 23, "lines_removed": 78},
      {"file": "tests/services/test_jwt_service.py", "change_type": "create", "lines_added": 78},
      {"file": "tests/services/test_password_hash_service.py", "change_type": "create", "lines_added": 56},
      {"file": "tests/services/test_email_verification_service.py", "change_type": "create", "lines_added": 67},
      {"file": "tests/api/test_auth.py", "change_type": "modify", "lines_added": 45, "lines_removed": 23},
      {"file": "tests/api/test_registration.py", "change_type": "modify", "lines_added": 34, "lines_removed": 12},
      {"file": "models/user.py", "change_type": "modify", "lines_added": 12, "lines_removed": 5},
      {"file": "core/dependencies.py", "change_type": "modify", "lines_added": 23, "lines_removed": 8}
    ],
    "toon": {
      "files_changed_toon": "files_changed[12]{file,change_type,lines_added,lines_removed}:\n  services/jwt_service.py,create,67,0\n  services/password_hash_service.py,create,45,0\n  services/email_verification_service.py,create,89,0\n  api/v1/endpoints/auth.py,modify,34,156\n  api/v1/endpoints/registration.py,modify,23,78\n  tests/services/test_jwt_service.py,create,78,0\n  tests/services/test_password_hash_service.py,create,56,0\n  tests/services/test_email_verification_service.py,create,67,0\n  tests/api/test_auth.py,modify,45,23\n  tests/api/test_registration.py,modify,34,12\n  models/user.py,modify,12,5\n  core/dependencies.py,modify,23,8",
      "token_savings": "37.8%",
      "size_comparison": "JSON: 2120 tokens, TOON: 1319 tokens"
    }
  }
}

✅ PHASE 2 ЗАВЕРШЕНА (12 files changed, 37.8% token savings)
```

**Result:** Complex phase with 12 files. TOON optimization applied with significant token savings (37.8%).

---

### Example 4: Checkpoint 1 Failure (branch context check failed)

**Phase file:** `plans/phase-3-frontend-integration.md`

**Execution attempt:**
```
Checkpoint 1: ЗАГРУЗКА И АНАЛИЗ
[✓] Phase file read
[✓] Phase metadata parsed
[✗] Branch context valid: FAILED
    Details: Currently on branch 'develop', expected 'feature/auth-system'
[⏸️ ] Dependencies check: SKIPPED (blocked by previous failure)

Overall result: FAILED
Blocking issues:
  - Wrong branch: develop (expected: feature/auth-system)

❌ CHECKPOINT 1 FAILED - BLOCKING
Cannot proceed to execution.
```

**Error handling:**
```json
{
  "error": {
    "error_type": "WRONG_BRANCH",
    "severity": "BLOCKING",
    "message": "Phase expects branch 'feature/auth-system', currently on 'develop'",
    "resolution": "Switch to correct branch: git checkout feature/auth-system",
    "can_retry": true
  }
}
```

**Action:** User switches branch → Retry phase execution

**Result:** Checkpoint 1 failure due to branch mismatch. Execution stopped before any code changes.

---

### Example 5: Checkpoint 2 Failure (completion criteria not met)

**Phase file:** `plans/phase-2-backend-api.md`

**Execution:**
```
Checkpoint 1: ЗАГРУЗКА И АНАЛИЗ
[✓] All checks passed

Step 1: Create JWTService ✓
Step 2: Create auth endpoints ✓
Step 3: Add JWT middleware ✓

Checkpoint 2: ВЫПОЛНЕНИЕ
[✓] Criterion 1: POST /auth/login returns tokens
    Evidence: curl test passed
[✗] Criterion 2: POST /auth/refresh generates new access_token
    Evidence: FAILED - 401 Unauthorized (invalid refresh token)
[⏸️ ] Criterion 3: POST /auth/logout invalidates refresh_token
    Status: SKIPPED (blocked by previous failure)

Completion criteria: 1/3 met
Blocking issues:
  - POST /auth/refresh endpoint not working (401 error)

Overall status: INCOMPLETE
❌ CHECKPOINT 2 FAILED - BLOCKING
Cannot proceed to commit.
```

**Error handling:**
```json
{
  "error": {
    "error_type": "PHASE_COMPLETION_CRITERIA_NOT_MET",
    "severity": "BLOCKING",
    "message": "Only 1 of 3 completion criteria met",
    "failed_criteria": [
      {
        "criterion": "POST /auth/refresh generates new access_token",
        "evidence": "401 Unauthorized - invalid refresh token"
      }
    ],
    "resolution": "Fix /auth/refresh endpoint validation logic, then RETRY",
    "can_retry": true,
    "max_retries": 2
  }
}
```

**Action:** Fix refresh endpoint → Retry checkpoint 2 → Success → Commit

**Result:** Checkpoint 2 failure prevents premature commit. Issue fixed and retried successfully.

---

### Example 6: Multi-Step Execution with Validation

**Phase file:** `plans/phase-1-setup-project-structure.md`

**Phase metadata:**
```json
{
  "phase_metadata": {
    "phase_number": 1,
    "phase_name": "Setup Project Structure",
    "total_phases": 1,
    "goal": "Create FastAPI project structure",
    "steps": [
      {
        "step_number": 1,
        "description": "Create directory structure",
        "actions": [
          "Create app/api/v1/endpoints/",
          "Create app/core/",
          "Create app/models/",
          "Create app/services/",
          "Create tests/"
        ],
        "validation": "test -d app/api/v1/endpoints && echo 'Directories created'"
      },
      {
        "step_number": 2,
        "description": "Create configuration files",
        "actions": [
          "Create app/core/config.py",
          "Create app/main.py",
          "Create requirements.txt"
        ],
        "validation": "python -m py_compile app/main.py"
      },
      {
        "step_number": 3,
        "description": "Initialize git and create .gitignore",
        "actions": [
          "Create .gitignore with Python/FastAPI patterns",
          "git init (if not exists)",
          "git add .",
          "git commit -m 'Initial project structure'"
        ],
        "validation": "git log --oneline | head -1"
      }
    ],
    "completion_criteria": [
      "All directories created",
      "Configuration files exist",
      "Git initialized with initial commit"
    ],
    "commit_message": {
      "type": "feat",
      "summary": "setup FastAPI project structure",
      "body": "- Create directory structure\n- Add configuration files\n- Initialize git repository"
    }
  }
}
```

**Execution:**
```
Checkpoint 1: ЗАГРУЗКА И АНАЛИЗ
[✓] Phase file read
[✓] Phase metadata parsed
[✓] Branch context valid (master branch, clean)
[✓] No dependencies

Step 1: Create directory structure
→ Created app/api/v1/endpoints/ ✓
→ Created app/core/ ✓
→ Created app/models/ ✓
→ Created app/services/ ✓
→ Created tests/ ✓
→ Validation: Directories created ✓

Step 2: Create configuration files
→ Created app/core/config.py ✓
→ Created app/main.py ✓
→ Created requirements.txt ✓
→ Validation: python -m py_compile app/main.py
  Output: No syntax errors ✓

Step 3: Initialize git and create .gitignore
→ Created .gitignore ✓
→ Git init (already exists) ✓
→ Files staged ✓
→ Initial commit created ✓
→ Validation: git log shows initial commit ✓

Checkpoint 2: ВЫПОЛНЕНИЕ
[✓] Criterion 1: All directories created
    Evidence: 5 directories exist
[✓] Criterion 2: Configuration files exist
    Evidence: config.py, main.py, requirements.txt present
[✓] Criterion 3: Git initialized with initial commit
    Evidence: git log shows commit a1b2c3d

Completion criteria: 3/3 met ✓
Syntax checks: Not required
Overall status: COMPLETED ✓

Git Commit:
→ Branch: master
→ Commit: d4e5f6g
→ Type: feat
→ Summary: setup FastAPI project structure

Phase Summary:
✅ PHASE 1 ЗАВЕРШЕНА
Files changed: 8 (directories + files)
Next phase: None (single-phase task)
```

**Result:** Multi-step execution with validation at each step. All validations passed, checkpoints cleared, successful commit.

---

### Example 7: Complete Phase-Based Workflow (Phase 2 of 3)

**Context:** Task "Implement JWT authentication system" decomposed into 3 phases. Currently executing Phase 2.

**Previous state:**
- ✅ Phase 1 completed: Database models created (commit: a1b2c3d)
- ⏳ Phase 2 in progress: Backend API + JWT Logic
- ⏸️  Phase 3 pending: Frontend Integration

**Phase file:** `plans/phase-2-backend-api.md`

**Execution:**
```
═══════════════════════════════════════════════════════════
      PHASE EXECUTION: Phase 2 of 3
═══════════════════════════════════════════════════════════

Phase: Backend API + JWT Logic
Goal: Implement login, refresh, logout endpoints
Dependencies: User model, RefreshToken model (from Phase 1)
Branch: feature/auth-system

───────────────────────────────────────────────────────────
CHECKPOINT 1: ЗАГРУЗКА И АНАЛИЗ
───────────────────────────────────────────────────────────

[✓] Check 1: Phase file read
    Details: plans/phase-2-backend-api.md (127 lines)

[✓] Check 2: Phase metadata parsed
    Details: JSON valid, all required fields present

[✓] Check 3: Branch context valid
    Details: On feature/auth-system, clean working directory

[✓] Check 4: Dependencies resolved
    Details: User model exists (commit a1b2c3d)
             RefreshToken model exists (commit a1b2c3d)

Overall result: PASSED ✓
Proceeding to execution...

───────────────────────────────────────────────────────────
EXECUTION (3 steps)
───────────────────────────────────────────────────────────

Step 1/3: Create JWTService for token generation
  Actions:
    → Create backend/app/services/jwt_service.py ✓
    → Implement generate_token() method ✓
    → Implement validate_token() method ✓
  Validation: pytest tests/services/test_jwt_service.py
    → 3 passed in 0.12s ✓

Step 2/3: Create authentication endpoints
  Actions:
    → Create backend/app/api/v1/endpoints/auth.py ✓
    → Implement POST /auth/login ✓
    → Implement POST /auth/refresh ✓
    → Implement POST /auth/logout ✓
  Validation: pytest tests/api/test_auth.py
    → 5 passed in 0.24s ✓

Step 3/3: Add JWT middleware
  Actions:
    → Create backend/app/middleware/auth_middleware.py ✓
    → Integrate middleware with FastAPI app ✓
  Validation: pytest tests/middleware/test_auth.py
    → 2 passed in 0.08s ✓

All steps completed ✓

───────────────────────────────────────────────────────────
CHECKPOINT 2: ВЫПОЛНЕНИЕ
───────────────────────────────────────────────────────────

Completion Criteria: 3/3

[✓] Criterion 1: POST /auth/login returns access_token and refresh_token
    Evidence: curl test passed, tokens returned

[✓] Criterion 2: POST /auth/refresh generates new access_token
    Evidence: curl test passed, new token generated

[✓] Criterion 3: POST /auth/logout invalidates refresh_token
    Evidence: curl test passed, refresh_token invalid after logout

Syntax Checks:
  Files checked: 2
    → backend/app/services/jwt_service.py ✓
    → backend/app/api/v1/endpoints/auth.py ✓
  Result: All passed ✓

Overall status: COMPLETED ✓
Proceeding to commit...

───────────────────────────────────────────────────────────
GIT COMMIT
───────────────────────────────────────────────────────────

Branch: feature/auth-system
Type: feat
Summary: add JWT authentication endpoints
Body: - Implement JWTService
      - Add login, refresh, logout endpoints
      - Add JWT middleware

Files committed: 6
  → backend/app/services/jwt_service.py (create, +45)
  → backend/app/api/v1/endpoints/auth.py (create, +78)
  → backend/app/middleware/auth_middleware.py (create, +34)
  → tests/services/test_jwt_service.py (create, +56)
  → tests/api/test_auth.py (create, +89)
  → backend/app/core/security.py (modify, +12/-3)

Commit hash: b2c3d4e
Status: success ✓

═══════════════════════════════════════════════════════════
       ✅ PHASE 2 ЗАВЕРШЕНА
═══════════════════════════════════════════════════════════

Phase: 2/3 - Backend API + JWT Logic
Status: COMPLETED
Commit: b2c3d4e

Changes Summary:
- 6 files modified
- 314 lines added
- 3 lines removed

Completion Criteria: ✓ 3/3 met

Next Phase:
→ Phase 3: Frontend Integration
  File: plans/phase-3-frontend-integration.md
  Dependencies: Backend API endpoints (Phase 2)

To execute Phase 3:
  "Выполни Phase 3 из plans/phase-3-frontend-integration.md"

═══════════════════════════════════════════════════════════
```

**Phase Summary JSON (with TOON):**
```json
{
  "phase_summary": {
    "phase_number": 2,
    "phase_name": "Backend API + JWT Logic",
    "total_phases": 3,
    "status": "COMPLETED",
    "commit_hash": "b2c3d4e",
    "files_changed": [
      {"file": "backend/app/services/jwt_service.py", "change_type": "create", "lines_added": 45, "lines_removed": 0},
      {"file": "backend/app/api/v1/endpoints/auth.py", "change_type": "create", "lines_added": 78, "lines_removed": 0},
      {"file": "backend/app/middleware/auth_middleware.py", "change_type": "create", "lines_added": 34, "lines_removed": 0},
      {"file": "tests/services/test_jwt_service.py", "change_type": "create", "lines_added": 56, "lines_removed": 0},
      {"file": "tests/api/test_auth.py", "change_type": "create", "lines_added": 89, "lines_removed": 0},
      {"file": "backend/app/core/security.py", "change_type": "modify", "lines_added": 12, "lines_removed": 3}
    ],
    "completion_criteria_met": 3,
    "total_completion_criteria": 3,
    "next_phase": {
      "phase_number": 3,
      "phase_name": "Frontend Integration",
      "file": "plans/phase-3-frontend-integration.md",
      "dependencies": ["Backend API endpoints"]
    },
    "toon": {
      "files_changed_toon": "files_changed[6]{file,change_type,lines_added,lines_removed}:\n  backend/app/services/jwt_service.py,create,45,0\n  backend/app/api/v1/endpoints/auth.py,create,78,0\n  backend/app/middleware/auth_middleware.py,create,34,0\n  tests/services/test_jwt_service.py,create,56,0\n  tests/api/test_auth.py,create,89,0\n  backend/app/core/security.py,modify,12,3",
      "token_savings": "31.2%",
      "size_comparison": "JSON: 1380 tokens, TOON: 949 tokens"
    }
  }
}
```

**Result:** Complete phase-based workflow demonstrating:
- Checkpoint validation before and after execution
- Multi-step execution with individual validations
- Git commit with structured metadata
- Phase summary with TOON optimization (31.2% savings)
- Clear next phase guidance

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

---

## Связанные скилы

- **thinking-framework**: `@shared:THINKING-PATTERNS.md#analysis` для phase analysis
- **validation-framework**: Checkpoint Validation, Completion Status
- **git-workflow**: `@shared:GIT-CONVENTIONS.md` для phase commit
- **error-handling**: PHASE_FILE_NOT_FOUND, CHECKPOINT_FAILED, PHASE_COMPLETION_CRITERIA_NOT_MET, etc.
- **task-decomposition**: Phase files созданы этим скилом

---

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

A: Checkpoint 1 проверит dependencies (Check 4: Dependencies resolved). Если Phase N-1 не завершен → ENTRY_CONDITION_VIOLATION → STOP. Нужно вернуться к Phase N-1 и завершить его полностью.

**Q: Phase metadata JSON слишком большой - можно сокращать?**

A: НЕТ! phase_metadata JSON должен содержать ВСЕ необходимые поля:
- phase_number, phase_name, total_phases, goal (обязательные)
- context (branch_name, dependencies, previous_changes_summary)
- steps[] (минимум 3, максимум 7 steps)
- completion_criteria[] (минимум 1 criterion)
- commit_message (type, summary, body)

Это обеспечивает полную автоматизацию execution.

**Q: Syntax checks происходят автоматически?**

A: ДА, если `phase_metadata.validation.syntax_check_required = true`. Phase-execution запустит syntax check для всех файлов в `validation.files_to_check[]`. Если syntax check failed → SYNTAX_ERROR → STOP.

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

---

**Author:** Claude Code Team
**License:** MIT
**Support:** См. @shared:TOON-REFERENCE.md, @shared:TASK-STRUCTURE.md, @shared:THINKING-PATTERNS.md, @shared:GIT-CONVENTIONS.md
