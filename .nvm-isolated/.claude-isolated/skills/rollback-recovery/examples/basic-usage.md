# Basic Usage Example - rollback-recovery

## Scenario

Механизм отката и восстановления при критических ошибках во время выполнения задачи с автоматическим созданием checkpoint и rollback.

**Use cases:**
- Критическая ошибка во время выполнения (syntax error, failed tests)
- Откат к предыдущему рабочему состоянию
- Сохранение работы перед рискованными изменениями

---

## Input

```json
{
  "checkpoint_trigger": "before_risky_operation",
  "operation": "Refactor authentication module",
  "files_to_modify": [
    "src/auth/login.py",
    "src/auth/jwt.py",
    "tests/test_auth.py"
  ]
}
```

---

## Execution

rollback-recovery skill выполняет следующие шаги:

### Step 1: Create Checkpoint
- Git stash текущих изменений (с timestamp)
- Save working tree state
- Record file hashes (для валидации)

### Step 2: Execute Operation
- Refactor authentication module
- Modify 3 files

### Step 3: Validation
- Run tests: `pytest tests/test_auth.py`
- **FAILED:** 5 tests failing

### Step 4: Automatic Rollback
- Detect критическая ошибка (tests failing)
- Trigger rollback to checkpoint
- Restore working tree state

---

## Output

**Checkpoint creation:**
```
📸 Creating checkpoint: refactor_auth_20260115_144500

✓ Git stash created: stash@{0}
✓ Files backed up (3):
  - src/auth/login.py (hash: a1b2c3d4)
  - src/auth/jwt.py (hash: e5f6g7h8)
  - tests/test_auth.py (hash: i9j0k1l2)

✓ Checkpoint saved: .claude-isolated/checkpoints/refactor_auth_20260115_144500.json
```

**Operation failure:**
```
❌ CRITICAL ERROR: Tests failing

pytest tests/test_auth.py
================================ FAILURES =================================
test_login_invalid_credentials FAILED
test_jwt_token_expired FAILED
...

5 failed, 12 passed in 1.23s

🔄 Triggering automatic rollback...
```

**Rollback execution:**
```
🔄 Rolling back to checkpoint: refactor_auth_20260115_144500

✓ Git working tree restored
✓ Files restored (3):
  - src/auth/login.py (verified hash: a1b2c3d4)
  - src/auth/jwt.py (verified hash: e5f6g7h8)
  - tests/test_auth.py (verified hash: i9j0k1l2)

✓ Tests passing: pytest tests/test_auth.py → 17 passed

✅ Rollback successful! System restored to working state.
```

---

## Explanation

### Checkpoint Strategy:

**When to create checkpoints:**
1. **Before risky operations** (major refactoring, database migrations)
2. **Before complex tasks** (multi-file changes)
3. **User request** (`@checkpoint:create`)

**Checkpoint содержит:**
- Git stash reference
- File hashes (для integrity check)
- Timestamp
- Operation description
- Working tree state

### Rollback Triggers:

**Automatic rollback (критические ошибки):**
- Syntax errors (compilation fails)
- Test failures (>50% tests failing)
- Runtime errors (import errors, missing dependencies)

**Manual rollback:**
```
@checkpoint:rollback refactor_auth_20260115_144500
```

### Recovery Workflow:

```
1. Create checkpoint
2. Execute operation
3. Validation
4. IF validation fails:
     → Automatic rollback
     → Show error details
     → Suggest fix
   ELSE:
     → Delete checkpoint (success)
```

### Multiple checkpoints:

```bash
# List checkpoints
ls .claude-isolated/checkpoints/

# Output:
# refactor_auth_20260115_144500.json
# db_migration_20260115_143000.json
# ui_redesign_20260115_141500.json

# Rollback to specific checkpoint
@checkpoint:rollback db_migration_20260115_143000
```

### Checkpoint cleanup:

```
# Auto-cleanup после успешного completion
✓ Task completed successfully
✓ Checkpoint deleted: refactor_auth_20260115_144500.json

# Retention policy: 24 часа для старых checkpoints
```

---

## Related

- [rollback-recovery/SKILL.md](../SKILL.md)
- [error-handling/SKILL.md](../error-handling/SKILL.md)
