---
name: Rollback Recovery
description: Механизм отката и восстановления при критических ошибках
version: 1.0.0
tags: [rollback, recovery, git, backup]
dependencies: [error-handling]
files:
  templates: ./templates/*.json
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
