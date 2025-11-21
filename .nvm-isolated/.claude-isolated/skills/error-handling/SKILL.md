---
name: Error Handling
description: Типовая обработка ошибок workflow с правильными actions (STOP/RETRY/ASK/BLOCKING) и structured error messages
version: 1.0.0
author: Claude Code Team
tags: [error-handling, retry-logic, troubleshooting, workflow]
dependencies: []
---

# Error Handling

Автоматизация обработки ошибок в workflow через типовые error types с определенными actions. Обеспечивает консистентный подход к ошибкам: когда останавливаться (STOP), когда повторять (RETRY), когда блокировать (BLOCKING).

## Когда использовать этот скил

Используй этот скил когда:
- Произошла ошибка в workflow
- Нужно определить правильный action (STOP/RETRY/ASK/BLOCKING)
- Нужно вывести structured error message
- Нужно понять retry logic (сколько попыток)
- Произошла critical failure (syntax error, PRD conflict, validation failed)

Скил автоматически вызывается при:
- Любых ошибках во время выполнения workflow
- JSON Schema validation errors
- Acceptance criteria failures
- Syntax errors
- Git operation failures

## Контекст проекта

### Философия Error Handling

**Принципы:**
- **Fail-fast:** STOP немедленно при critical errors
- **Retry-smart:** RETRY только recoverable errors с max attempts
- **User-aware:** ASK пользователя при ambiguity, не guess
- **Block-safe:** BLOCKING для errors требующих исправления перед продолжением
- **Structured messages:** Единый формат error output

### Error Actions

**STOP:** Немедленная остановка, нельзя продолжить
- PRD_CONFLICT
- SYNTAX_ERROR
- APPROVAL_REJECTED
- GIT_COMMIT_FAILED

**RETRY:** Повторная попытка (с max attempts limit)
- ACCEPTANCE_FAIL (max 2 attempts)
- JSON_SCHEMA_VALIDATION_ERROR (max 1 attempt)

**ASK:** Спросить пользователя (ambiguity, конфликты)
- PRD_CONFLICT требования (после STOP)
- Неоднозначные requirements

**BLOCKING:** Блокировка продолжения до исправления
- VALIDATION_FAILED
- Syntax checks failed

### Error Message Format

```
[ICON] ОШИБКА: [Тип]
Проблема: [описание]
Контекст: [где произошло]
Действие: [STOP/RETRY/ASK/BLOCKING]
```

## Шаблоны

### Шаблон 1: PRD_CONFLICT

**Action:** STOP

**Message:**
```
❌ ОШИБКА: Конфликт с PRD
Проблема: {описание конфликта}
Контекст: {какая секция PRD, какое требование}
Действие: STOP - Уточнить у пользователя
```

**Когда:** Задача конфликтует с требованиями PRD

**Пример:**
```
❌ ОШИБКА: Конфликт с PRD
Проблема: Задача требует изменить API response format на XML, но PRD FR-055 требует JSON
Контекст: FR-055 "API должен возвращать JSON responses"
Действие: STOP - Уточнить у пользователя приоритет требований
```

### Шаблон 2: JSON_SCHEMA_VALIDATION_ERROR

**Action:** STOP → RETRY (max 1 attempt)

**Message:**
```
❌ ОШИБКА: Structured Output не прошел валидацию
Проблема: {schema error details}
Контекст: {шаг где произошло - plan/validation/git_commit}
Действие: RETRY с исправлением структуры JSON
```

**Retry Logic:**
1. First attempt failed → исправить JSON structure
2. RETRY validation
3. If failed again → STOP, спросить пользователя

**Пример:**
```
❌ ОШИБКА: Structured Output не прошел валидацию
Проблема: Field 'commit_summary' exceeds maxLength 72 (got 85 characters)
Контекст: Phase 5, Step 3 (Git commit JSON)
Действие: RETRY с сокращением commit_summary до 72 символов

Попытка: 1/1
```

### Шаблон 3: ACCEPTANCE_FAIL

**Action:** RETRY (max 2 attempts)

**Message:**
```
⚠️ Acceptance criteria не выполнены
Не выполнено: {список criteria}
Контекст: Phase 4 (Validation)
Действие: Исправить, попытка {N}/2
```

**Retry Logic:**
1. First validation failed → исправить проблемы
2. RETRY validation (попытка 1/2)
3. If failed again → исправить еще раз
4. RETRY validation (попытка 2/2)
5. If failed third time → STOP, спросить пользователя

**Пример:**
```
⚠️ Acceptance criteria не выполнены
Не выполнено:
- AC2: Endpoint должен обрабатывать invalid input (возвращает 500 вместо 400)

Контекст: Phase 4 (Validation)
Действие: Исправить validation logic в endpoint, попытка 1/2
```

### Шаблон 4: SYNTAX_ERROR

**Action:** STOP

**Message:**
```
❌ ОШИБКА: Syntax error
Файл: {file path}
Ошибка: {compiler/linter error message}
Контекст: {шаг выполнения}
Действие: Исправить немедленно
```

**Пример:**
```
❌ ОШИБКА: Syntax error
Файл: backend/app/services/order_service.py
Ошибка: SyntaxError: invalid syntax (line 42)
         validator.validate_order(order  # missing closing parenthesis
Контекст: Phase 3, Step 2 (Refactor OrderService)
Действие: Исправить syntax error немедленно
```

### Шаблон 5: APPROVAL_REJECTED

**Action:** STOP

**Message:**
```
🛑 План отклонен пользователем
Контекст: {что было отклонено}
Действие: Завершение работы
```

**Пример:**
```
🛑 План отклонен пользователем
Контекст: План задачи "Добавить calculate_total метод" был отклонен после approval gate
Действие: Завершение работы. Для возобновления создайте новую задачу.
```

### Шаблон 6: VALIDATION_FAILED

**Action:** BLOCKING

**Message:**
```
🛑 VALIDATION FAILED
Проблемы:
{для каждой blocking_issue}
- {issue}

Контекст: Phase 4 (Validation)
Действие: Исправить ошибки, затем RETRY validation
```

**Пример:**
```
🛑 VALIDATION FAILED
Проблемы:
- 1 acceptance criteria not met
- 1 syntax checks failed

Контекст: Phase 4 (Validation)
Действие: Исправить ошибки, затем RETRY validation

Детали:
- AC3 not met: Все тесты должны проходить (тесты не запускались)
- Syntax check failed: backend/app/services/order_service.py (SyntaxError line 42)
```

### Шаблон 7: GIT_COMMIT_FAILED

**Action:** STOP

**Message:**
```
❌ ОШИБКА: Git commit failed
Ошибка: {git error message}
Контекст: Phase 5, Step 3 (Git commit и push)
Действие: Проверить git status, исправить проблему
```

**Пример:**
```
❌ ОШИБКА: Git commit failed
Ошибка: error: pathspec 'backend/app/services/nonexistent.py' did not match any file(s) known to git
Контекст: Phase 5, Step 3 (Git commit и push)
Действие: Проверить git status, убедиться что все файлы существуют и staged
```

---

## Phase-Based Error Handling

Дополнительные error types специфичные для phase-based workflow. Эти ошибки возникают при работе с multi-phase задачами.

### Когда использовать

Используй phase-based error handling когда:
- Работаешь с phase files (чтение, парсинг, генерация)
- Проверяешь git branch context перед выполнением фазы
- Валидируешь phase completion criteria
- Выполняешь checkpoint validation между фазами
- Проверяешь entry conditions перед началом фазы

### Шаблон 8: PHASE_FILE_NOT_FOUND

**Action:** STOP

**Message:**
```
❌ ОШИБКА: Phase file not found
Файл: {expected file path}
Контекст: {где искали файл}
Действие: STOP - Проверить путь, убедиться что phase file создан
```

**Когда:** Phase file не найден при попытке чтения (phase-execution skill).

**Пример:**
```
❌ ОШИБКА: Phase file not found
Файл: plans/phase-2-backend-api.md
Контекст: Phase Execution - попытка прочитать Phase 2
Действие: STOP - Проверить что task decomposition завершен и phase files созданы

Возможные причины:
- Phase files не были созданы (task-decomposition не выполнен)
- Неправильный slug в имени файла (phase-2-backend-api vs phase-2-backend_api)
- Неправильный путь (plans/ vs. phases/ vs. docs/)
```

### Шаблон 9: PHASE_FILE_PARSE_ERROR

**Action:** STOP

**Message:**
```
❌ ОШИБКА: Phase file parse error
Файл: {phase file path}
Ошибка: {parse error details}
Контекст: {какая секция не распарсилась}
Действие: STOP - Исправить JSON в phase_metadata секции
```

**Когда:** Phase file найден, но JSON в phase_metadata секции невалиден.

**Пример:**
```
❌ ОШИБКА: Phase file parse error
Файл: plans/phase-2-backend-api.md
Ошибка: JSON parse error at line 15: Expecting ',' delimiter
Секция: phase_metadata.steps[] (missing comma after step 3)
Контекст: Phase Execution - парсинг phase_metadata
Действие: STOP - Исправить JSON syntax в phase file

Проблемный JSON:
{
  "steps": [
    {"step_number": 1, ...},
    {"step_number": 2, ...},
    {"step_number": 3, ...}  // missing comma here
    {"step_number": 4, ...}
  ]
}
```

### Шаблон 10: PHASE_COMPLETION_CRITERIA_NOT_MET

**Action:** BLOCKING

**Message:**
```
🛑 Phase completion criteria not met
Не выполнено: {список критериев}
Контекст: Phase {N} completion validation
Действие: Исправить, затем RETRY validation
```

**Когда:** Phase completion criteria validation failed (validation-framework, Шаблон 8).

**Пример:**
```
🛑 Phase completion criteria not met
Не выполнено:
- Criterion 2: POST /auth/login endpoint должен возвращать access_token (endpoint не создан)
- Criterion 4: JWT middleware должен защищать protected endpoints (middleware не добавлен)

Контекст: Phase 2 completion validation
Действие: Завершить реализацию недостающих компонентов, затем RETRY validation

Попытка: 0/2
```

**Retry Logic:**
1. Исправить недостающие компоненты
2. RETRY completion validation (попытка 1/2)
3. If still failed → исправить еще раз, RETRY (попытка 2/2)
4. If failed third time → STOP, спросить пользователя

### Шаблон 11: WRONG_BRANCH

**Action:** STOP (BLOCKING)

**Message:**
```
❌ ОШИБКА: Wrong git branch
Ожидалась: {expected_branch}
Текущая: {current_branch}
Контекст: Phase {N} - Branch Context Check
Действие: STOP (BLOCKING) - Checkout правильную ветку
```

**Когда:** Git branch context check failed - выполняешь фазу на неправильной ветке (git-workflow, Шаблон 7).

**Пример:**
```
❌ ОШИБКА: Wrong git branch
Ожидалась: feature/auth-system
Текущая: master
Контекст: Phase 2 - Branch Context Check перед выполнением
Действие: STOP (BLOCKING) - Checkout feature/auth-system

Команда:
git checkout feature/auth-system

CRITICAL: НЕ выполнять фазу на master! Это может сломать production код.
```

### Шаблон 12: UNCOMMITTED_CHANGES

**Action:** STOP (BLOCKING)

**Message:**
```
❌ ОШИБКА: Uncommitted changes in working directory
Файлы: {list of uncommitted files}
Контекст: Phase {N} - Branch Context Check
Действие: STOP (BLOCKING) - Commit или stash changes
```

**Когда:** Branch context check обнаружил uncommitted changes перед выполнением фазы.

**Пример:**
```
❌ ОШИБКА: Uncommitted changes in working directory
Файлы:
- backend/app/services/user_service.py (modified)
- backend/app/api/v1/endpoints/users.py (modified)

Контекст: Phase 2 - Branch Context Check
Действие: STOP (BLOCKING) - Решить что делать с uncommitted changes

Варианты:
1. Commit их (если они часть текущей задачи):
   git add .
   git commit -m "feat: ..."

2. Stash (если не относятся к задаче):
   git stash save "WIP: user service changes"

3. Discard (если это мусор):
   git checkout -- <file>
```

### Шаблон 13: CHECKPOINT_FAILED

**Action:** BLOCKING

**Message:**
```
🛑 CHECKPOINT FAILED
Checkpoint: {checkpoint_name}
Failed checks: {список не прошедших checks}
Контекст: Phase {N} - Checkpoint {checkpoint_id}
Действие: Исправить failed checks, затем RETRY checkpoint
```

**Когда:** Checkpoint validation failed - нельзя продолжить к следующему шагу/фазе (validation-framework, Шаблон 5).

**Пример:**
```
🛑 CHECKPOINT FAILED
Checkpoint: ЗАГРУЗКА И АНАЛИЗ (checkpoint_id: 1)
Failed checks:
- Check 2: Phase metadata parsed (JSON parse error)
- Check 3: Branch context valid (uncommitted changes found)

Контекст: Phase 2 - Checkpoint 1 перед началом выполнения
Действие: Исправить failed checks, затем RETRY checkpoint

Детали:
- Check 2: Исправить JSON syntax в phase_metadata секции
- Check 3: Commit или stash uncommitted changes

После исправления повторно пройти checkpoint.
```

### Шаблон 14: DECOMPOSITION_FAILED

**Action:** STOP

**Message:**
```
❌ ОШИБКА: Task decomposition failed
Проблема: {описание проблемы}
Контекст: Task Decomposition - {шаг где failed}
Действие: STOP - Пересмотреть decomposition strategy
```

**Когда:** Task decomposition не может разбить задачу на валидные фазы (task-decomposition skill).

**Пример:**
```
❌ ОШИБКА: Task decomposition failed
Проблема: Невозможно разбить задачу на 2-5 логических фаз
  Попытка разбиения на 7 фаз привела к слишком мелким фазам (<3 steps каждая)
  Попытка объединения в 1 фазу - слишком большая (15 steps)

Контекст: Task Decomposition - Decomposition Thinking (Шаблон 6)
Действие: STOP - Пересмотреть decomposition strategy

Рекомендации:
1. Проверить что задача действительно multi-phase (может быть simple task?)
2. Рассмотреть другой критерий разделения (по слоям, по компонентам, по dependencies)
3. Возможно задача слишком большая - split на 2 отдельные задачи
```

### Шаблон 15: FILE_CREATE_FAILED

**Action:** STOP

**Message:**
```
❌ ОШИБКА: Phase file creation failed
Файл: {file path}
Ошибка: {filesystem error}
Контекст: Task Decomposition - генерация phase files
Действие: STOP - Проверить filesystem permissions
```

**Когда:** Не удалось создать phase file при task decomposition (task-decomposition skill).

**Пример:**
```
❌ ОШИБКА: Phase file creation failed
Файл: plans/phase-2-backend-api.md
Ошибка: Permission denied (errno 13)
Контекст: Task Decomposition - генерация phase files (Phase 2 of 3)
Действие: STOP - Проверить filesystem permissions и наличие директории

Возможные причины:
- Директория plans/ не существует (создать: mkdir -p plans)
- Нет прав на запись в директорию (chmod u+w plans/)
- Файловая система read-only
```

### Шаблон 16: ENTRY_CONDITION_VIOLATION

**Action:** STOP (BLOCKING)

**Message:**
```
❌ ОШИБКА: Entry condition violated
Фаза: Phase {N}
Condition: {violated condition}
Контекст: Phase Entry Conditions Check
Действие: STOP (BLOCKING) - Выполнить предыдущие фазы
```

**Когда:** Entry conditions для фазы не выполнены - нельзя начать выполнение (phase-execution skill).

**Пример:**
```
❌ ОШИБКА: Entry condition violated
Фаза: Phase 2: Backend API + JWT Logic
Condition: Phase 1 должен быть completed (User и RefreshToken models exist)
Проверка: ✗ User model not found в backend/app/models/user.py
Контекст: Phase 2 Entry Conditions Check
Действие: STOP (BLOCKING) - Завершить Phase 1 сначала

Детали:
Phase 2 зависит от Phase 1 (database models).
Phase 1 completion criteria:
- User model created ✗
- RefreshToken model created (not checked)
- Migrations applied (not checked)

Необходимо вернуться к Phase 1 и завершить его полностью.
```

---

## Проверочный чеклист

После обработки ошибки проверь:

**Error Message:**
- [ ] Icon соответствует severity (❌ critical, ⚠️ warning, 🛑 blocking)
- [ ] Тип ошибки указан явно (PRD_CONFLICT, SYNTAX_ERROR, etc)
- [ ] Проблема описана конкретно (не "что-то сломалось")
- [ ] Контекст указывает где произошло (Phase N, Step M)
- [ ] Действие указано явно (STOP/RETRY/ASK/BLOCKING)

**Action Execution:**
- [ ] STOP errors действительно останавливают execution
- [ ] RETRY errors имеют max attempts limit
- [ ] BLOCKING errors НЕ позволяют продолжить до исправления
- [ ] ASK errors выводят вопрос пользователю

**Retry Logic:**
- [ ] Current attempt number указан (N/MAX)
- [ ] Max attempts не превышен
- [ ] После max attempts → STOP
- [ ] Retry fixing правильную проблему (не random changes)

## Связанные скилы

- **validation-framework**: использует error-handling при validation failures
- **structured-planning**: использует для JSON Schema validation errors
- **git-workflow**: использует для git operation errors
- **phase-execution**: использует phase-based error types (Шаблон 8-16)
- **task-decomposition**: использует DECOMPOSITION_FAILED, FILE_CREATE_FAILED errors

## Примеры использования

### Пример 1: JSON Schema Validation Error → RETRY

**Контекст:** Plan JSON не проходит schema validation (commit_summary too long)

**Error Message:**
```
❌ ОШИБКА: Structured Output не прошел валидацию
Проблема: Field 'commit_summary' exceeds maxLength 72 (got 85 characters)
Контекст: Phase 1, Step 5 (Создать план - git секция)
Действие: RETRY с сокращением commit_summary до 72 символов

Попытка: 0/1
```

**Action Sequence:**
1. Обнаружена ошибка в git.commit_summary
2. Сократить commit_summary: "add comprehensive user authentication system with OAuth2 and JWT tokens support" → "add user authentication with OAuth2 and JWT"
3. RETRY JSON Schema validation
4. If passed → продолжить
   If failed → STOP, спросить пользователя

### Пример 2: Acceptance Criteria Failure → RETRY (max 2)

**Контекст:** Validation Phase обнаружила что AC2 не выполнен

**Error Message (первая попытка):**
```
⚠️ Acceptance criteria не выполнены
Не выполнено:
- AC2: Endpoint должен возвращать 404 для несуществующего order

Контекст: Phase 4 (Validation)
Действие: Добавить проверку order existence в endpoint, попытка 1/2
```

**Action:**
1. Добавить в endpoint:
```python
if not order:
    raise HTTPException(status_code=404, detail="Order not found")
```
2. RETRY validation

**If failed again:**
```
⚠️ Acceptance criteria не выполнены
Не выполнено:
- AC2: Endpoint должен возвращать 404 (still returns 500)

Действие: Исправить error handling в endpoint, попытка 2/2
```

3. Еще одна попытка исправления
4. RETRY validation
5. If failed third time → STOP:
```
❌ ОШИБКА: Max retry attempts exceeded
Проблема: AC2 не удалось выполнить после 2 попыток
Действие: STOP - Требуется помощь пользователя
```

### Пример 3: Syntax Error → STOP immediately

**Контекст:** Syntax check failed для order_service.py

**Error Message:**
```
❌ ОШИБКА: Syntax error
Файл: backend/app/services/order_service.py
Ошибка: SyntaxError: invalid syntax (line 42)
         validator.validate_order(order
                                       ^
         SyntaxError: unexpected EOF while parsing
Контекст: Phase 4 (Validation - Syntax checks)
Действие: Исправить syntax error немедленно (missing closing parenthesis)
```

**Action:**
1. STOP немедленно (syntax errors BLOCKING)
2. Показать error message
3. Исправить: `validator.validate_order(order)` (добавить closing paren)
4. Продолжить validation с начала

### Пример 4: PRD Conflict → STOP and ASK

**Контекст:** Задача требует XML responses, PRD требует JSON

**Error Message:**
```
❌ ОШИБКА: Конфликт с PRD
Проблема: Задача требует изменить /orders endpoint на XML responses,
         но PRD FR-055 явно требует "API должен возвращать JSON"
Контекст: PRD Section FR-055 "API Response Format"
Действие: STOP - Уточнить у пользователя

Вопрос: Какой приоритет?
1. Следовать PRD (оставить JSON)
2. Обновить PRD (разрешить XML)
3. Отменить задачу
```

**Action:**
1. STOP execution
2. Вывести error message с вопросом
3. ЖДАТЬ ответа пользователя
4. Действовать согласно ответу

## Часто задаваемые вопросы

**Q: Когда использовать STOP vs BLOCKING?**

A:
- **STOP:** Нельзя продолжить вообще, требуется внешнее действие (user input, PRD update)
- **BLOCKING:** Можно продолжить ПОСЛЕ исправления ошибки (syntax fix, validation fix)

**Q: Retry logic всегда с max attempts?**

A: ДА! Infinite retries недопустимы. Max attempts:
- JSON Schema validation: 1 retry
- Acceptance criteria: 2 retries
- После max → STOP

**Q: Что делать если error type не в списке?**

A: Использовать closest match:
- Compilation/syntax errors → SYNTAX_ERROR (STOP)
- Logic/business errors → VALIDATION_FAILED (BLOCKING)
- External service errors → STOP (не можем fix)

**Q: Error message должен быть в structured JSON?**

A: НЕТ! Error messages - plain text для user readability. Structured output нужен для results (plan, validation, git), не errors.

**Q: RETRY должен пытаться то же самое или другой подход?**

A: ДРУГОЙ подход или FIX проблемы! Не делать одно и то же и ожидать других результатов.

Пример:
- ❌ Retry: Попытаться parse date с тем же format string
- ✅ Retry: Попробовать другой format string или использовать dateutil

**Q: Когда использовать ASK?**

A: Когда:
- Ambiguity (неясно что хочет пользователь)
- Conflict (PRD vs task requirements)
- Choice needed (несколько valid options)

НЕ использовать ASK для:
- Syntax errors (fix немедленно)
- Obvious fixes (исправить, не спрашивать)

**Q: Error message должен предлагать solution?**

A: ДА! Всегда включать:
- Что пошло не так (Проблема)
- Где (Контекст)
- Что делать (Действие - конкретное)

**Q: Multiple errors одновременно - показывать все или первую?**

A: Показать ПЕРВУЮ blocking error, STOP. После исправления может обнаружиться следующая. Fail-fast principle.
