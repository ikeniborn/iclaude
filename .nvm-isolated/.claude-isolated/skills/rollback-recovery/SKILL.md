---
name: Rollback Recovery
description: Механизм отката и восстановления при критических ошибках
version: 1.1.0
tags: [rollback, recovery, git, backup]
dependencies: [error-handling]
files:
  templates: ./templates/*.json
user-invocable: false
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

## TOON Format Support (v1.1.0)

**Назначение:** Автоматическая оптимизация токенов для files_affected[] массива при больших откатах.

### Threshold

TOON генерируется если **files_affected[] >= 5**

**Note:** executed_commands[] обычно содержит 1-3 команды (ниже threshold), поэтому TOON не применяется к этому массиву.

### Target Array

**files_affected[]**
- Обычно: 1-20 файлов (зависит от scope rollback)
- Поля: file, change_type (optional), status (optional)
- Token savings: ~25-35% для 5+ files

### Output Structure

**Rollback Output (с TOON):**
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
      {"file": "backend/app/models/user.py", "change_type": "modified", "status": "reverted"}
    ],
    "previous_state": "abc123def456",
    "current_state": "abc123",
    "status": "rolled_back",
    "changes_preserved": false,
    "toon": {
      "files_affected_toon": "files_affected[7]{file,change_type,status}:\n  backend/app/services/auth_service.py,modified,reverted\n  backend/app/api/v1/endpoints/auth.py,created,deleted\n  backend/app/core/security.py,modified,reverted\n  backend/app/middleware/auth_middleware.py,created,deleted\n  tests/services/test_auth_service.py,created,deleted\n  tests/api/test_auth_endpoints.py,created,deleted\n  backend/app/models/user.py,modified,reverted",
      "token_savings": "28.3%",
      "size_comparison": "JSON: 980 tokens, TOON: 702 tokens"
    }
  }
}
```

### Implementation Pattern

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
  // Normalize структуру (добавить change_type и status если отсутствуют)
  const filesNormalized = rollback.files_affected.map(f => ({
    file: f.file || f,  // Support простой string array или object array
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

### Token Savings Examples

| Scenario | JSON Tokens | TOON Tokens | Savings | Files |
|----------|-------------|-------------|---------|-------|
| Small rollback (7 files) | 980 | 702 | 28.3% | 7 |
| Medium rollback (12 files) | 1680 | 1120 | 33.3% | 12 |
| Large rollback (20 files) | 2800 | 1820 | 35.0% | 20 |

**Typical use case:** Complex task rollback с 12 файлами: **~33% token reduction**

### Backward Compatibility

- ✅ JSON format always present (primary format)
- ✅ TOON field optional (only when threshold met)
- ✅ Zero breaking changes для downstream consumers
- ✅ Consumers могут игнорировать TOON и читать JSON

### When TOON is Generated

**Always generated:**
- Large rollback (5+ files affected)
- Full phase rollback (typically 7-15 files)

**Not generated:**
- Small rollback (< 5 files)
- Single file restore
- Git stash (usually minimal file count in output)

### Simplified Files Array

Если files_affected содержит только file paths (strings), автоматически нормализуем:

```javascript
// Input: простые strings
const rollback = {
  files_affected: ["file1.py", "file2.py", "file3.py", "file4.py", "file5.py"]
};

// Auto-normalized для TOON:
const filesNormalized = rollback.files_affected.map(file => ({
  file: file,
  change_type: 'unknown',
  status: 'reverted'
}));
```

См. также: **toon-skill** для API документации, **_shared/TOON-PATTERNS.md** для integration patterns.

