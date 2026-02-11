# Context Management Skill

Управление контекстом Claude Code: экспорт, импорт, синхронизация worktrees, backup и cleanup.

## Описание

Этот skill предоставляет интерфейс к Context Management System для управления памятью, историей и сессиями Claude Code в изолированной среде iclaude.sh.

## Возможности

- **Export/Import** - Сохранение и восстановление контекста проектов
- **Worktree Sync** - Синхронизация памяти между git worktrees
- **Cleanup** - Автоочистка старых сессий и истории
- **Backup** - Создание резервных копий контекста
- **Status** - Мониторинг использования контекста

## Использование

### Через команду /skill

```
/context-management export
/context-management import <archive>
/context-management sync [pull|push]
/context-management clean [days]
/context-management backup [mode]
/context-management status
```

### Примеры

```
/context-management status
→ Показать статус текущего проекта

/context-management export
→ Экспортировать контекст в архив

/context-management sync pull
→ Подтянуть shared memory (для worktrees)

/context-management clean 60
→ Очистить сессии старше 60 дней

/context-management backup manual
→ Создать ручной backup
```

## Команды

### export [path]
Экспортирует контекст проекта в tar.gz архив.

**Аргументы:**
- `path` - путь к проекту (по умолчанию: текущая директория)

**Результат:**
- Архив в `.nvm-isolated/.claude-isolated/contexts/exports/`
- Содержит: memory/, history, metadata

**Пример:**
```
/context-management export /home/user/project
```

### import <archive>
Импортирует контекст из архива в текущий проект.

**Аргументы:**
- `archive` - путь к архиву (обязательный)

**Результат:**
- Восстановленная память в `projects/<hash>/memory/`
- Добавленные записи истории

**Пример:**
```
/context-management import /path/to/archive.tar.gz
```

### sync [pull|push]
Синхронизирует память между worktrees.

**Аргументы:**
- `pull` - скопировать из shared в текущий worktree (по умолчанию)
- `push` - скопировать из текущего в shared

**Результат:**
- Синхронизированная память в `contexts/shared/<project>/`

**Примеры:**
```
/context-management sync pull   # В worktree
/context-management sync push   # В main repo
```

### clean [days] [--aggressive]
Очищает старые сессии и обрезает историю.

**Аргументы:**
- `days` - количество дней (по умолчанию: 30)
- `--aggressive` - также удалить неактивные проекты

**Результат:**
- Удаленные старые сессии
- Обрезанная history.jsonl (если > 5 MB)

**Примеры:**
```
/context-management clean 60
/context-management clean --aggressive
```

### backup [mode]
Создает резервную копию контекста.

**Аргументы:**
- `manual` - ручной backup (по умолчанию)
- `daily` - daily backup (для cron, хранит последние 7)
- `weekly` - weekly backup (для cron, хранит последние 4)

**Результат:**
- Backup в `contexts/backups/<mode>/<timestamp>/`
- Содержит: history.jsonl, projects/, shared/, manifest.json

**Примеры:**
```
/context-management backup manual
/context-management backup daily
```

### status [path]
Показывает статус контекста проекта.

**Аргументы:**
- `path` - путь к проекту (по умолчанию: текущая директория)

**Результат:**
- Размер памяти и истории
- Количество сессий
- Worktree информация
- Рекомендации

**Пример:**
```
/context-management status
```

## Интеграция с workflow

### Pre-commit
Автоматический backup перед большими изменениями:
```
/context-management backup manual
git add .
git commit -m "Major refactoring"
```

### Worktree workflow
```
# Main repo
/context-management sync push

# Worktree
/context-management sync pull
# ... работа ...
/context-management sync push
```

### Регулярное обслуживание
```
# Еженедельная проверка
/context-management status
/context-management clean 30
/context-management backup manual
```

## Конфигурация

Настройки в `.nvm-isolated/.claude-isolated/settings.json`:

```json
{
  "contextManagement": {
    "autoSync": true,
    "cleanupDays": 30,
    "autoBackup": "daily",
    "maxHistorySize": 5242880,
    "worktreeSync": {
      "enabled": true,
      "autoOnLaunch": true
    }
  }
}
```

## Файлы и директории

**Библиотека:**
- `lib/context-manager.sh` - основная логика

**Данные:**
- `.nvm-isolated/.claude-isolated/contexts/exports/` - экспорты
- `.nvm-isolated/.claude-isolated/contexts/shared/` - shared memory
- `.nvm-isolated/.claude-isolated/contexts/backups/` - backup
- `.nvm-isolated/.claude-isolated/contexts/pre-compact/` - snapshots

**Hooks:**
- `.nvm-isolated/.claude-isolated/hooks/beforeCompact.hook.sh`

## Документация

- **Быстрый старт**: `docs/CONTEXT_QUICK_START.md`
- **Примеры**: `examples/CONTEXT_USAGE_EXAMPLES.md`
- **Спецификация**: `docs/CONTEXT_MANAGEMENT.md`
- **README**: `CONTEXT_README.md`

## Troubleshooting

**"Context manager library not found"**
```bash
# Проверить наличие библиотеки
ls -l lib/context-manager.sh

# Если отсутствует, система не установлена
```

**"No memory files found"**
- Это нормально для новых проектов
- Память создается автоматически при работе с Claude Code

**"Worktree sync не работает"**
```bash
# Проверить что это worktree
cat .git | grep gitdir

# Сначала push из main repo
cd /main/repo
/context-management sync push
```

## Зависимости

**Обязательные:**
- bash 4.x+
- tar, gzip

**Опциональные (но рекомендуются):**
- jq - для JSON parsing
- rsync - для эффективной синхронизации (fallback на cp)

## Версия

- **Версия skill**: 1.0.0
- **Версия Context Manager**: 1.0.0
- **Дата**: 2024-02-11

## Автор

Context Management System для iclaude.sh
