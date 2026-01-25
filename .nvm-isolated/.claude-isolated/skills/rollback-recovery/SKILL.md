---
name: Rollback Recovery
description: Механизм отката и восстановления при критических ошибках
version: 1.2.0
tags: [rollback, recovery, git, backup]
dependencies: [error-handling]
files:
  templates: ./templates/*.json
user-invocable: false
changelog:
  - version: 1.2.0
    date: 2026-01-25
    changes:
      - "Централизация: TOON specs → @shared:TOON-REFERENCE.md"
      - "Добавлено: 3 примера (git reset soft, git reset hard, file restore)"
      - "Skill-specific TOON usage notes для files_affected[]"
      - "Обновлены references"
  - version: 1.1.0
    date: 2026-01-23
    changes:
      - "TOON Format Support для files_affected[]"
---

# Rollback Recovery

Механизм отката изменений при критических ошибках.

## Когда использовать

- После превышения max retries
- При критической ошибке (PERMISSION_DENIED, etc.)
- По запросу пользователя

## Стратегии отката

### 1. Git Reset Soft (default)

Сохраняет изменения в working directory, откатывает commit.

```bash
git reset --soft HEAD~1
```

**Когда:** Commit сделан, но нужно исправить

### 2. Git Reset Hard

Полный откат к состоянию до изменений.

```bash
git reset --hard HEAD~1
# или к конкретному коммиту
git reset --hard {commit_hash}
```

**Когда:** Нужно полностью откатить

### 3. Git Stash

Сохранить изменения и очистить working directory.

```bash
git stash push -m "rollback: {task_name}"
```

**Когда:** Изменения могут пригодиться позже

### 4. File Restore

Восстановить конкретные файлы.

```bash
git checkout HEAD -- {file1} {file2}
```

**Когда:** Нужно откатить только часть изменений

## Выбор стратегии

```
if commit_made AND fixable:
  strategy = "git_reset_soft"
elif commit_made AND !fixable:
  strategy = "git_reset_hard"
elif !commit_made AND want_to_save:
  strategy = "git_stash"
elif partial_rollback:
  strategy = "file_restore"
```

## Output

```json
{
  "rollback": {
    "strategy": "git_reset_soft",
    "executed_commands": [
      "git reset --soft HEAD~1"
    ],
    "files_affected": ["service.py", "test_service.py"],
    "previous_state": "abc123",
    "current_state": "def456",
    "status": "rolled_back",
    "changes_preserved": true
  }
}
```

## User Message

```
🔄 ОТКАТ ВЫПОЛНЕН

Стратегия: {strategy}
Файлы: {files_affected}
Статус: {status}

{если changes_preserved}
💾 Изменения сохранены в: {location}

Следующие шаги:
- [ ] Проверить состояние репозитория
- [ ] Исправить проблему
- [ ] Повторить задачу
```

## References

**TOON Format Specification:**
- Full spec: @shared:TOON-REFERENCE.md
- Integration patterns: @shared:TOON-REFERENCE.md#integration-patterns
- Token savings benchmarks: @shared:TOON-REFERENCE.md#token-savings

**Task Structure:**
- @shared:TASK-STRUCTURE.md#rollback-strategy

## Skill-Specific TOON Usage

**rollback-recovery генерирует TOON для:**
- `files_affected[]` - когда >= 5 files

**Implementation:**
```javascript
import { arrayToToon, calculateTokenSavings } from '../toon-skill/converters/toon-converter.mjs';

// Rollback output
const rollback = {
  strategy: "git_reset_hard",
  executed_commands: ["git reset --hard abc123"],
  files_affected: [...]  // 7+ files
};

// Add TOON optimization (только для files_affected >= 5)
if (rollback.files_affected.length >= 5) {
  const filesNormalized = rollback.files_affected.map(f => ({
    file: f.file || f,
    change_type: f.change_type || 'unknown',
    status: f.status || 'reverted'
  }));

  rollback.toon = {
    files_affected_toon: arrayToToon('files_affected', filesNormalized,
      ['file', 'change_type', 'status']),
    ...calculateTokenSavings({ files_affected: filesNormalized })
  };
}
```

**Token Savings (Rollback-Specific):**
- 7 files: **28.3% savings** (980 → 702 tokens)
- 12 files: **33.3% savings** (1680 → 1120 tokens)
- 20 files: **35.0% savings** (2800 → 1820 tokens)

---

## Examples

### Example 1: Git Reset Soft (Fixable Error)

**Scenario:** Commit made, but tests failed - need to fix and re-commit

**Initial state:**
```bash
# Just committed with syntax error
git log -1 --oneline
# abc123 feat: add authentication service

pytest tests/
# FAILED tests/test_auth.py::test_login - SyntaxError: invalid syntax
```

**Rollback execution:**
```json
{
  "rollback": {
    "strategy": "git_reset_soft",
    "executed_commands": [
      "git reset --soft HEAD~1"
    ],
    "files_affected": [
      "backend/services/auth_service.py",
      "tests/test_auth.py"
    ],
    "previous_state": "abc123",
    "current_state": "def456",
    "status": "rolled_back",
    "changes_preserved": true
  }
}
```

**User message:**
```
🔄 ОТКАТ ВЫПОЛНЕН

Стратегия: git_reset_soft
Файлы: backend/services/auth_service.py, tests/test_auth.py
Статус: rolled_back

💾 Изменения сохранены в: working directory (staged)

Следующие шаги:
- [ ] Проверить состояние репозитория
- [ ] Исправить проблему
- [ ] Повторить задачу
```

**Result:** Changes remain staged, commit undone, ready to fix syntax error and re-commit.

---

### Example 2: Git Reset Hard (Full Rollback)

**Scenario:** Critical error in 12-file refactor - need full rollback

**Task details:**
- Refactored authentication module (12 files modified/created)
- Breaking change broke production
- Cannot fix quickly

**Rollback execution:**
```json
{
  "rollback": {
    "strategy": "git_reset_hard",
    "executed_commands": [
      "git reset --hard abc123"
    ],
    "files_affected": [
      {"file": "backend/app/services/auth_service.py", "change_type": "modified", "status": "reverted"},
      {"file": "backend/app/api/v1/endpoints/auth.py", "change_type": "created", "status": "deleted"},
      {"file": "backend/app/core/security.py", "change_type": "modified", "status": "reverted"},
      {"file": "backend/app/middleware/auth_middleware.py", "change_type": "created", "status": "deleted"},
      {"file": "tests/services/test_auth_service.py", "change_type": "created", "status": "deleted"},
      {"file": "tests/api/test_auth_endpoints.py", "change_type": "created", "status": "deleted"},
      {"file": "backend/app/models/user.py", "change_type": "modified", "status": "reverted"},
      {"file": "backend/app/schemas/auth.py", "change_type": "created", "status": "deleted"},
      {"file": "backend/app/config.py", "change_type": "modified", "status": "reverted"},
      {"file": "backend/alembic/versions/003_add_refresh_tokens.py", "change_type": "created", "status": "deleted"},
      {"file": "backend/requirements.txt", "change_type": "modified", "status": "reverted"},
      {"file": "docs/api/authentication.md", "change_type": "modified", "status": "reverted"}
    ],
    "previous_state": "xyz789",
    "current_state": "abc123",
    "status": "rolled_back",
    "changes_preserved": false,
    "toon": {
      "files_affected_toon": "files_affected[12]{file,change_type,status}:\n  backend/app/services/auth_service.py,modified,reverted\n  backend/app/api/v1/endpoints/auth.py,created,deleted\n  backend/app/core/security.py,modified,reverted\n  backend/app/middleware/auth_middleware.py,created,deleted\n  tests/services/test_auth_service.py,created,deleted\n  tests/api/test_auth_endpoints.py,created,deleted\n  backend/app/models/user.py,modified,reverted\n  backend/app/schemas/auth.py,created,deleted\n  backend/app/config.py,modified,reverted\n  backend/alembic/versions/003_add_refresh_tokens.py,created,deleted\n  backend/requirements.txt,modified,reverted\n  docs/api/authentication.md,modified,reverted",
      "token_savings": "33.3%",
      "size_comparison": "JSON: 1680 tokens, TOON: 1120 tokens"
    }
  }
}
```

**User message:**
```
🔄 ОТКАТ ВЫПОЛНЕН

Стратегия: git_reset_hard
Файлы: 12 files (see toon.files_affected_toon for details)
Статус: rolled_back

⚠️ Изменения УДАЛЕНЫ (changes_preserved: false)

Следующие шаги:
- [ ] Проверить состояние репозитория
- [ ] Исправить проблему
- [ ] Повторить задачу
```

**Result:** All 12 files reverted to commit abc123, breaking changes completely removed, TOON optimization saves 33.3% tokens.

---

### Example 3: File Restore (Partial Rollback)

**Scenario:** Only 2 files need rollback, keep rest of changes

**Initial state:**
```bash
# Modified 5 files, but 2 have errors
git status
# modified: backend/services/payment.py (good)
# modified: backend/services/order.py (good)
# modified: backend/services/auth.py (ERROR)
# modified: backend/models/user.py (ERROR)
# modified: backend/config.py (good)
```

**Rollback execution:**
```json
{
  "rollback": {
    "strategy": "file_restore",
    "executed_commands": [
      "git checkout HEAD -- backend/services/auth.py backend/models/user.py"
    ],
    "files_affected": [
      "backend/services/auth.py",
      "backend/models/user.py"
    ],
    "previous_state": "working_directory_dirty",
    "current_state": "working_directory_partial",
    "status": "partial_rollback",
    "changes_preserved": true,
    "preserved_files": [
      "backend/services/payment.py",
      "backend/services/order.py",
      "backend/config.py"
    ]
  }
}
```

**User message:**
```
🔄 ОТКАТ ВЫПОЛНЕН

Стратегия: file_restore
Файлы: backend/services/auth.py, backend/models/user.py
Статус: partial_rollback

💾 Остальные изменения сохранены:
- backend/services/payment.py
- backend/services/order.py
- backend/config.py

Следующие шаги:
- [ ] Проверить состояние репозитория
- [ ] Исправить проблему в откаченных файлах
- [ ] Повторить задачу для auth.py и user.py
```

**Result:** Only 2 problematic files restored, 3 good changes preserved.

---

## Integration with Other Skills

**Used by:**
- `error-handling` → Called when retry_count >= max_retries
- `adaptive-workflow` → Emergency rollback on critical failures
- `phase-execution` → Phase-level rollback on checkpoint failure

**Uses:**
- `toon-skill` → TOON optimization for files_affected[] (см. `@shared:TOON-REFERENCE.md`)

---

🤖 Generated with Claude Code

**Author:** ikeniborn
**License:** MIT
