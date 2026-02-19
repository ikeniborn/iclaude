# Planning Mode Configuration

Полное руководство по настройке режима планирования в Claude Code.

## Обзор

Claude Code поддерживает режим планирования (plan mode), который позволяет Claude анализировать задачу и создавать детальный план выполнения перед началом реализации.

## Настройка пути сохранения планов

### Конфигурация

Добавьте в `.claude/settings.json`:

```json
{
  "plansDirectory": "docs/plans"
}
```

**Параметры:**
- `plansDirectory` - относительный путь от корня проекта
- Если не указан: планы сохраняются в `~/.claude/plans/`

### Поддерживаемые версии

- **Claude Code**: 2.1.0+ (настройка добавлена в январе 2026)
- **Текущая версия**: 2.1.41 ✅

## Использование

### Автоматический режим

По умолчанию Claude Code может входить в plan mode автоматически:

```bash
./iclaude.sh
> Implement user authentication with JWT
# Claude автоматически войдет в plan mode, создаст план
# План сохранится в docs/plans/plan-<timestamp>.md
```

### Ручной режим

Принудительно использовать планирование:

```bash
./iclaude.sh
> /plan Implement user authentication with JWT
```

### Настройка режима по умолчанию

В `.claude/settings.json`:

```json
{
  "permissions": {
    "defaultMode": "plan"
  }
}
```

**Режимы:**
- `plan` - планирование без выполнения
- `default` - стандартный режим с запросами
- `acceptEdits` - автоматическое одобрение изменений
- `bypassPermissions` - полный доступ без запросов

## Структура плана

Типичный план включает:

```markdown
# Implementation Plan: <Task Title>

## Overview
Brief description of the task

## Prerequisites
- Dependencies
- Required tools
- Access requirements

## Steps
1. **Step 1**: Description
   - Substep 1.1
   - Substep 1.2
2. **Step 2**: Description
   ...

## Critical Files
- `path/to/file1.ts` - Purpose
- `path/to/file2.ts` - Purpose

## Dependencies
- Task A blocks Task B
- Task C depends on Task A

## Risks & Considerations
- Potential issues
- Mitigation strategies

## Testing Strategy
- Unit tests
- Integration tests
- Manual verification steps
```

## Workflow

### 1. Создание плана

```bash
./iclaude.sh
> Implement user authentication
```

Claude создаст план в `docs/plans/plan-<timestamp>.md`

### 2. Проверка плана

```bash
cat docs/plans/plan-*.md | tail -1
```

### 3. Утверждение и выполнение

```
> Approve and implement the plan
```

### 4. Версионирование

```bash
git add docs/plans/
git commit -m "docs: add implementation plan for authentication"
```

## Best Practices

### 1. Коммитить планы в git

✅ **Рекомендуется:**
```bash
# Планы - часть документации проекта
git add docs/plans/
git commit -m "docs: add plan for feature X"
```

❌ **Не рекомендуется:**
```bash
# Не добавлять в .gitignore, если планы важны для команды
echo "docs/plans/" >> .gitignore
```

### 2. Именование файлов

По умолчанию: `plan-<timestamp>.md`

Переименовать для ясности:
```bash
mv docs/plans/plan-1707850800000.md docs/plans/auth-implementation.md
```

### 3. Структура каталога

```
docs/
├── plans/
│   ├── README.md           # Документация
│   ├── auth-implementation.md
│   ├── api-refactoring.md
│   └── database-migration.md
```

### 4. Связь с issues/PRs

В плане:
```markdown
# Implementation Plan: User Authentication

Related: #42, #43
PR: #45
```

В PR:
```markdown
Implements authentication feature

Implementation plan: [docs/plans/auth-implementation.md](../docs/plans/auth-implementation.md)
```

## Интеграция с CI/CD

### Валидация планов

`.github/workflows/validate-plans.yml`:

```yaml
name: Validate Plans

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check plans exist
        run: |
          if [ ! -d "docs/plans" ]; then
            echo "Plans directory not found"
            exit 1
          fi
      - name: Validate markdown
        run: |
          npm install -g markdownlint-cli
          markdownlint docs/plans/**/*.md
```

## Troubleshooting

### Планы не сохраняются

**Проблема:** Планы не появляются в `docs/plans/`

**Решение:**
1. Проверьте настройку:
   ```bash
   cat .claude/settings.json | grep plansDirectory
   ```
2. Создайте каталог:
   ```bash
   mkdir -p docs/plans
   ```
3. Проверьте права:
   ```bash
   ls -la docs/plans
   ```

### Старая конфигурация

**Проблема:** Планы сохраняются в `~/.claude/plans/`

**Решение:**
1. Обновите Claude Code:
   ```bash
   ./iclaude.sh --update
   ```
2. Добавьте настройку `plansDirectory` в `.claude/settings.json`
3. Перезапустите Claude Code

### Конфликт с глобальной конфигурацией

**Проблема:** Настройка игнорируется

**Решение:**
1. Проверьте иерархию конфигураций:
   - `~/.claude/settings.json` (глобальная)
   - `.claude/settings.json` (проектная, приоритет)
   - `.claude/settings.local.json` (локальная, наивысший приоритет)

2. Используйте правильный файл:
   ```bash
   # Для проекта (коммитится в git)
   vim .claude/settings.json

   # Только для вас (не в git)
   vim .claude/settings.local.json
   ```

## Примеры использования

### Простая задача

```bash
./iclaude.sh
> Add a new API endpoint /api/users
```

**Результат:** `docs/plans/plan-users-endpoint.md`

### Сложная задача

```bash
./iclaude.sh
> Refactor authentication system to use microservices architecture
```

**Результат:** Подробный план с:
- Разбиением на этапы
- Миграционной стратегией
- Rollback планом
- Тестами на каждом этапе

### Команда

```bash
# Разработчик A создает план
./iclaude.sh
> /plan Implement caching layer

# Коммитит план
git add docs/plans/caching-plan.md
git commit -m "docs: add caching implementation plan"
git push

# Разработчик B проверяет и утверждает
git pull
cat docs/plans/caching-plan.md
# Обсуждение в PR review
```

## Ссылки

- [Claude Code Documentation](https://code.claude.com/docs)
- [GitHub Issue #17473](https://github.com/anthropics/claude-code/issues/17473) - Feature request
- [GitHub Issue #13395](https://github.com/anthropics/claude-code/issues/13395) - Configuration discussion
- [docs/plans/README.md](plans/README.md) - Локальная документация

## См. также

- [CONFIGURATION.md](CONFIGURATION.md) - Полная конфигурация проекта
- [docs/plans/README.md](plans/README.md) - Документация каталога планов
- `.claude/settings.json` - Конфигурация проекта
