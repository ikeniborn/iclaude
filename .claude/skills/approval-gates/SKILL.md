---
name: Approval Gates
description: Программные approval gates с structured output для получения явного подтверждения перед выполнением критических действий
version: 1.0.0
author: Claude Code Team
tags: [approval, confirmation, structured-output, safety, workflow]
dependencies: [structured-planning]
---

# Approval Gates

Автоматизация программных approval gates для получения явного подтверждения пользователя перед выполнением критических действий. Обеспечивает structured output с JSON валидацией для предотвращения автоматического выполнения без approval.

## Когда использовать этот скил

Используй этот скил когда нужно:
- Получить подтверждение плана задачи перед выполнением
- Запросить approval перед деструктивными операциями (delete, drop database, etc)
- Предоставить возможность review перед git push
- Предотвратить автоматическое выполнение без explicit consent
- Получить программный approval (JSON boolean)
- Дать пользователю опции (approve/reject/modify)

Скил автоматически вызывается при:
- Завершении Phase 1 (Planning) перед Phase 2 (Execution)
- Actions с `approval_gate: required="true"`
- Перед деструктивными операциями
- Перед git push к remote

## Контекст проекта

### Философия Approval Gates

**Принципы:**
- **Explicit consent:** НЕ делать assumptions о желании пользователя
- **Programmatic validation:** Boolean approval.approved, не parsing ответа
- **Clear communication:** Пользователь понимает что будет выполнено
- **Options provided:** approve/reject/modify (не только yes/no)
- **Blocking enforcement:** НЕ продолжать пока approval.approved != true

### Когда approval gate ОБЯЗАТЕЛЕН

**CRITICAL:**
- После создания structured plan (Phase 1 → Phase 2)
- Перед деструктивными операциями (DELETE, DROP, rm -rf)
- Перед git push если не было explicit instruction "push immediately"

**OPTIONAL:**
- Перед рефакторингом large codebase
- Перед изменением production config
- Перед breaking changes

### Approval Gate Workflow

```
1. Создать plan/summary того что будет выполнено
2. Вывести approval gate message с опциями
3. СТОП - ждать ответа пользователя
4. Parse ответ → approval JSON
5. IF approved = true → продолжить
   ELSE IF rejected → STOP
   ELSE IF modify → вернуться к planning
```

## Шаблоны

### Шаблон 1: Approval Request Message

```
═══════════════════════════════════════════════════════════
            ⏸️  ТРЕБУЕТСЯ ПОДТВЕРЖДЕНИЕ
═══════════════════════════════════════════════════════════

[Контекст что будет выполнено]

📊 СТАТИСТИКА:
[Ключевые метрики]

⚠️ ВНИМАНИЕ:
[Важные предупреждения]

───────────────────────────────────────────────────────────

ВОПРОС: [Вопрос подтверждения]

Ответьте:
- "да" / "yes" / "подтверждаю" - [действие при approve]
- "нет" / "no" / "стоп" - [действие при reject]
- "изменить [что]" - [действие при modify request]

═══════════════════════════════════════════════════════════
```

### Шаблон 2: Plan Approval Gate

**Когда:** После Phase 1 (Planning), перед Phase 2 (Execution)

```
═══════════════════════════════════════════════════════════
            ⏸️  ТРЕБУЕТСЯ ПОДТВЕРЖДЕНИЕ ПЛАНА
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

### Шаблон 3: Approval JSON (Structured Output)

```json
{
  "approval": {
    "approved": true,
    "timestamp": "2025-11-20T10:30:00Z",
    "user_response": "да",
    "can_proceed_to_execution": true
  }
}
```

**Fields:**
- `approved`: boolean - true если пользователь одобрил
- `timestamp`: ISO 8601 - когда получен ответ
- `user_response`: string - exact ответ пользователя
- `can_proceed_to_execution`: boolean - программное разрешение продолжения

**Логика:**
```javascript
can_proceed_to_execution = approved && user_response.match(/^(да|yes|y|подтверждаю|ok)$/i)
```

### Шаблон 4: Response Parsing Patterns

```javascript
// Approved patterns
approved = /^(да|yes|y|подтверждаю|ok|proceed|continue)$/i.test(response)

// Rejected patterns
rejected = /^(нет|no|n|стоп|stop|отмена|cancel|abort)$/i.test(response)

// Modification request patterns
modify = /^(изменить|modify|change|update|edit)/i.test(response)
```

### Шаблон 5: Destructive Operation Approval

**Когда:** Перед деструктивными операциями (DELETE, DROP, rm -rf)

```
═══════════════════════════════════════════════════════════
       ⚠️  ТРЕБУЕТСЯ ПОДТВЕРЖДЕНИЕ ДЕСТРУКТИВНОЙ ОПЕРАЦИИ
═══════════════════════════════════════════════════════════

ОПЕРАЦИЯ: [описание что будет удалено/изменено]

🔴 ПРЕДУПРЕЖДЕНИЕ:
Это действие НЕОБРАТИМО!
[Детали что будет потеряно]

📊 ЗАТРОНУТО:
- [список затронутых объектов]

───────────────────────────────────────────────────────────

ВОПРОС: Вы УВЕРЕНЫ что хотите продолжить?

Ответьте:
- "да, уверен" / "yes, confirm" - выполнить операцию
- "нет" / "no" / "стоп" - отменить

⚠️ Требуется explicit подтверждение!

═══════════════════════════════════════════════════════════
```

### Шаблон 6: Git Push Approval

**Когда:** Перед git push если не было explicit instruction

```
═══════════════════════════════════════════════════════════
            ⏸️  PUSH К REMOTE РЕПОЗИТОРИЮ
═══════════════════════════════════════════════════════════

Готов выполнить git push:

📊 COMMIT:
- Branch: {branch_name}
- Commit: {commit_hash} ({commit_type}: {commit_summary})
- Files: {files_committed.length} файлов

⚠️ ВНИМАНИЕ:
Commit будет доступен всей команде после push.

───────────────────────────────────────────────────────────

ВОПРОС: Выполнить push к remote?

Ответьте:
- "да" / "yes" / "push" - выполнить push
- "нет" / "no" - оставить commit локально

═══════════════════════════════════════════════════════════
```

## Проверочный чеклист

После создания approval gate проверь:

**Message:**
- [ ] Заголовок содержит ⏸️ emoji для visibility
- [ ] Контекст объясняет что будет выполнено
- [ ] Статистика показывает scope операции
- [ ] Предупреждения (⚠️) для критичных моментов
- [ ] Вопрос четкий и конкретный
- [ ] Опции (approve/reject/modify) явно указаны

**Structured Output:**
- [ ] JSON approval создан после получения ответа
- [ ] `approved` boolean (не string)
- [ ] `timestamp` в ISO 8601 format
- [ ] `user_response` contains exact ответ
- [ ] `can_proceed_to_execution` логически следует из approved

**Behavior:**
- [ ] СТОП и ждать ответа (не продолжать automatically)
- [ ] Parse ответ через patterns (approved/rejected/modify)
- [ ] IF approved = false → НЕ продолжать
- [ ] IF modify requested → вернуться к planning
- [ ] Exit conditions проверены перед продолжением

## Связанные скилы

- **structured-planning**: план требует approval перед execution
- **validation-framework**: может требовать approval после validation
- **git-workflow**: может требовать approval перед push

## Примеры использования

### Пример 1: Plan Approval Gate (standard workflow)

**Контекст:** Создан план для задачи "Добавить calculate_total метод"

**Claude использует approval-gates скил:**

**1. Вывести approval message:**
```
═══════════════════════════════════════════════════════════
            ⏸️  ТРЕБУЕТСЯ ПОДТВЕРЖДЕНИЕ ПЛАНА
═══════════════════════════════════════════════════════════

План задачи создан и готов к выполнению.

📊 СТАТИСТИКА ПЛАНА:
- Файлов к изменению: 1
- Шагов выполнения: 3
- Acceptance Criteria: 2
- Рисков: 1

⚠️ ВНИМАНИЕ:
План будет выполнен автоматически после подтверждения.
Все изменения будут закоммичены в ветку feature/calculate-total.

───────────────────────────────────────────────────────────

ВОПРОС: Подтверждаете выполнение плана?

Ответьте:
- "да" / "yes" / "подтверждаю" - начать выполнение
- "нет" / "no" / "стоп" - остановить
- "изменить [что]" - внести корректировки в план

═══════════════════════════════════════════════════════════
```

**2. Ждать ответа пользователя**

**3. Пользователь ответил: "да"**

**4. Вывести approval JSON:**
```json
{
  "approval": {
    "approved": true,
    "timestamp": "2025-11-20T10:30:00Z",
    "user_response": "да",
    "can_proceed_to_execution": true
  }
}
```

**5. Проверить exit conditions:**
- ✓ approval.approved = true
- ✓ can_proceed_to_execution = true
→ Продолжить к Phase 2 (Execution)

### Пример 2: Approval Rejected

**Пользователь ответил: "нет, стоп"**

**Approval JSON:**
```json
{
  "approval": {
    "approved": false,
    "timestamp": "2025-11-20T10:31:00Z",
    "user_response": "нет, стоп",
    "can_proceed_to_execution": false
  }
}
```

**Action:**
- approved = false → STOP
- НЕ выполнять план
- Вывести: "❌ План отклонен. Завершение работы."

### Пример 3: Modification Request

**Пользователь ответил: "изменить branch name на fix/calculate-total"**

**Approval JSON:**
```json
{
  "approval": {
    "approved": false,
    "timestamp": "2025-11-20T10:32:00Z",
    "user_response": "изменить branch name на fix/calculate-total",
    "can_proceed_to_execution": false
  }
}
```

**Action:**
- modify request detected → вернуться к Phase 1, Step 5 (Planning)
- Обновить plan: git.branch_name = "fix/calculate-total"
- Пересоздать plan JSON
- Вывести обновленный Markdown plan
- RETRY approval gate

### Пример 4: Destructive Operation Approval

**Контекст:** Удаление deprecated table из database

**Claude использует approval-gates скил:**

```
═══════════════════════════════════════════════════════════
       ⚠️  ТРЕБУЕТСЯ ПОДТВЕРЖДЕНИЕ ДЕСТРУКТИВНОЙ ОПЕРАЦИИ
═══════════════════════════════════════════════════════════

ОПЕРАЦИЯ: DROP TABLE old_orders;

🔴 ПРЕДУПРЕЖДЕНИЕ:
Это действие НЕОБРАТИМО!
Все данные в таблице old_orders будут УДАЛЕНЫ НАВСЕГДА.
Backup НЕ существует (таблица deprecated).

📊 ЗАТРОНУТО:
- Таблица: old_orders (127 rows)
- Зависимости: Нет (foreign keys уже удалены)

───────────────────────────────────────────────────────────

ВОПРОС: Вы УВЕРЕНЫ что хотите продолжить?

Ответьте:
- "да, уверен" / "yes, confirm" - выполнить DROP TABLE
- "нет" / "no" / "стоп" - отменить

⚠️ Требуется explicit подтверждение!

═══════════════════════════════════════════════════════════
```

**Пользователь:** "да, уверен"

**Approval JSON:**
```json
{
  "approval": {
    "approved": true,
    "timestamp": "2025-11-20T10:35:00Z",
    "user_response": "да, уверен",
    "can_proceed_to_execution": true
  }
}
```

→ Выполнить DROP TABLE old_orders;

## Часто задаваемые вопросы

**Q: Approval gate обязателен для каждой задачи?**

A: НЕТ! Обязателен только для:
- Structured planning workflow (Phase 1 → Phase 2)
- Деструктивных операций (DELETE, DROP, rm -rf)
- Actions с `approval_gate: required="true"`

**Q: Что если пользователь не ответил на approval gate?**

A: СТОП и ждать. НЕ продолжать автоматически. Если долго нет ответа - timeout и прекращение работы.

**Q: Можно ли approval gate пропустить с флагом --yes?**

A: Это зависит от реализации workflow. В standard workflow нет такого флага - approval всегда требуется.

**Q: user_response должен точно совпадать с patterns?**

A: НЕТ! Patterns используют regex match, поддерживают вариации:
- "да" / "ДА" / "Да" → approved
- "yes" / "YES" / "Yes" → approved
- "подтверждаю" → approved

**Q: Approval JSON обязателен даже если rejected?**

A: ДА! JSON нужен всегда для программной проверки:
```json
{
  "approval": {
    "approved": false,  // ← важно!
    ...
  }
}
```

**Q: Что делать если пользователь дал неоднозначный ответ?**

A: Спросить еще раз с более простыми опциями (yes/no only):
```
Неоднозначный ответ. Подтвердите:
- "да" - выполнить
- "нет" - отменить
```

**Q: can_proceed_to_execution может быть true если approved = false?**

A: НЕТ! Логика:
```javascript
can_proceed_to_execution = (approved === true)
```

Если approved = false → can_proceed_to_execution ДОЛЖНО быть false.

**Q: Approval gate должен выводить весь plan опять?**

A: НЕТ! Approval gate выводит summary (statistics), а не full plan. Full plan уже выведен в Phase 1, Step 5.

**Q: Можно ли multiple approval gates в одной задаче?**

A: ДА! Например:
1. После planning (Phase 1 → Phase 2)
2. Перед destructive operation (Phase 3, Step 5)
3. Перед git push (Phase 5, Step 3)

Каждый approval gate - отдельный JSON с approval.
