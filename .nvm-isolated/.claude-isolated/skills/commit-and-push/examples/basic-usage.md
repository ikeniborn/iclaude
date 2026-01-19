# Basic Usage Example

## Scenario

Пользователь хочет закоммитить изменения в текущем репозитории и запушить их на удалённый сервер.

## Input

```json
{
  "commit_and_push_input": {
    "repository_path": "/home/user/myproject",
    "commit_message": "feat: add new feature for user authentication",
    "files_to_stage": ["src/auth.js", "src/user.js", "README.md"],
    "branch": "main",
    "push_options": {
      "force": false,
      "set_upstream": false,
      "remote": "origin"
    },
    "validation": {
      "check_uncommitted_changes": true,
      "verify_remote": true
    }
  }
}
```

## Execution

Скилл выполняет следующие действия:

1. **Валидация репозитория:** Проверяет существование `.git/` директории
2. **Проверка remote:** Убеждается, что remote "origin" настроен
3. **Stage файлов:** Выполняет `git add` для указанных файлов
4. **Создание коммита:** Выполняет `git commit -m "..."`
5. **Push на remote:** Выполняет `git push origin main`
6. **Сбор результатов:** Извлекает commit hash, timestamp, количество файлов

## Output

```json
{
  "commit_and_push_output": {
    "status": "success",
    "commit_info": {
      "commit_hash": "a1b2c3d",
      "commit_message": "feat: add new feature for user authentication",
      "files_committed": 3,
      "branch": "main",
      "timestamp": "2026-01-19T10:30:45Z"
    },
    "push_info": {
      "pushed": true,
      "remote": "origin",
      "remote_branch": "main",
      "commits_pushed": 1
    },
    "validation_results": {
      "pre_commit_checks": "passed",
      "remote_verification": "passed"
    },
    "notes": [
      "Successfully committed and pushed 3 files",
      "Branch 'main' is up to date with 'origin/main'"
    ]
  }
}
```

## Explanation

**Успешное выполнение:**
- Все 3 файла были добавлены в staging area
- Коммит создан с хешем `a1b2c3d`
- Изменения успешно запушены на `origin/main`
- Валидация прошла успешно (remote доступен, нет конфликтов)

**Возможные ошибки:**
- Если remote не настроен → status: "failed", error: "Remote 'origin' not found"
- Если есть merge conflicts → status: "failed", error: "Merge conflicts detected"
- Если файлы не найдены → status: "partial", warning: "Some files not found"
