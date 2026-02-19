# Configuration Hierarchy in Claude Code

Полное руководство по иерархии конфигурационных файлов в Claude Code и iclaude.sh.

## Обзор

Claude Code поддерживает многоуровневую систему конфигурации с приоритетами. Настройки из файлов с более высоким приоритетом переопределяют настройки из файлов с более низким приоритетом.

## Иерархия конфигураций

### 1. Глобальный уровень (самый низкий приоритет)

**Для всех проектов и сессий**

#### Изолированная среда (iclaude.sh)
```
.nvm-isolated/.claude-isolated/settings.json
```

#### Системная установка
```
~/.claude/settings.json
```

**Использование:**
- Общие настройки для всех проектов
- Язык интерфейса
- Режим по умолчанию
- Status line конфигурация

**Пример:**
```json
{
  "language": "Russian",
  "alwaysThinkingEnabled": true,
  "plansDirectory": "docs/plans",
  "permissions": {
    "defaultMode": "plan"
  }
}
```

### 2. Проектный уровень (средний приоритет)

**Для конкретного проекта (в git)**

```
<project-root>/.claude/settings.json
```

**Использование:**
- Настройки, специфичные для проекта
- Включенные плагины (LSP серверы)
- Правила доступа (permissions)
- Хуки и автоматизация

**Пример:**
```json
{
  "enabledPlugins": {
    "pyright-lsp@claude-plugins-official": true,
    "typescript-lsp@claude-plugins-official": true
  },
  "plansDirectory": "architecture/plans",
  "permissions": {
    "allow": ["Read", "Write", "Bash(git:*)"]
  }
}
```

### 3. Локальный уровень (высший приоритет)

**Для конкретного проекта (НЕ в git)**

```
<project-root>/.claude/settings.local.json
```

**Использование:**
- Персональные настройки разработчика
- Переопределение команды плагинов
- Отключение проверок безопасности
- Экспериментальные функции

**Пример:**
```json
{
  "plansDirectory": "my-personal-plans",
  "skipDangerousModePermissionPrompt": true
}
```

## Правило слияния

**Объекты сливаются рекурсивно:**
```json
// Глобальный (приоритет 1)
{
  "permissions": {
    "allow": ["Read", "Write"]
  }
}

// Проектный (приоритет 2)
{
  "permissions": {
    "allow": ["Bash(git:*)"],
    "deny": ["Write(.env*)"]
  }
}

// Результат (слияние)
{
  "permissions": {
    "allow": ["Bash(git:*)"],  // Переопределено
    "deny": ["Write(.env*)"]    // Добавлено
  }
}
```

**Примитивные значения переопределяются:**
```json
// Глобальный
{ "plansDirectory": "docs/plans" }

// Локальный
{ "plansDirectory": "my-plans" }

// Результат
{ "plansDirectory": "my-plans" }  // Локальный побеждает
```

## Примеры использования

### Сценарий 1: Глобальная настройка для всех проектов

**Задача:** Все проекты должны сохранять планы в `docs/plans`

**Решение:**
```bash
# Редактировать глобальную конфигурацию
vim .nvm-isolated/.claude-isolated/settings.json

# Добавить
{
  "plansDirectory": "docs/plans"
}
```

**Результат:** Все новые проекты будут использовать `docs/plans`

### Сценарий 2: Переопределение для конкретного проекта

**Задача:** Проект с особой структурой нуждается в другом пути

**Решение:**
```bash
# Создать проектную конфигурацию
vim .claude/settings.json

# Добавить
{
  "plansDirectory": "architecture/planning"
}
```

**Результат:**
- Этот проект: `architecture/planning`
- Остальные проекты: `docs/plans` (из глобальной)

### Сценарий 3: Персональные эксперименты

**Задача:** Временно протестировать другой путь без изменения команды

**Решение:**
```bash
# Создать локальную конфигурацию
vim .claude/settings.local.json

# Добавить
{
  "plansDirectory": "test-plans"
}
```

**Результат:**
- Только ваша рабочая копия: `test-plans`
- Git не затронут
- Команда видит стандартный путь

## Команды для управления

### Проверка текущей конфигурации

```bash
# Глобальная (изолированная среда)
cat .nvm-isolated/.claude-isolated/settings.json | grep plansDirectory

# Проектная
cat .claude/settings.json | grep plansDirectory

# Локальная
cat .claude/settings.local.json 2>/dev/null | grep plansDirectory || echo "Not set"
```

### Приоритет слияния

```bash
# Итоговая конфигурация (отладка)
claude --dump-config 2>/dev/null | grep plansDirectory
```

### Создание конфигураций

```bash
# Глобальная (для всех проектов)
cat > .nvm-isolated/.claude-isolated/settings.json << 'EOF'
{
  "plansDirectory": "docs/plans",
  "language": "Russian"
}
EOF

# Проектная (коммитится в git)
mkdir -p .claude
cat > .claude/settings.json << 'EOF'
{
  "plansDirectory": "docs/plans",
  "enabledPlugins": {
    "typescript-lsp@claude-plugins-official": true
  }
}
EOF

# Локальная (не в git)
cat > .claude/settings.local.json << 'EOF'
{
  "plansDirectory": "my-personal-plans"
}
EOF
```

## Best Practices

### 1. Глобальные настройки

✅ **Используйте для:**
- Язык интерфейса
- Status line configuration
- Общий режим работы (plan/default)
- Общий путь для планов

❌ **Не используйте для:**
- Специфичных плагинов проекта
- Правил доступа к файлам
- Hooks для конкретного проекта

### 2. Проектные настройки

✅ **Используйте для:**
- LSP серверы для языков проекта
- Permissions для проекта
- Hooks для автоматизации команды
- Специфический путь планов

❌ **Не используйте для:**
- Личных настроек
- Временных экспериментов
- Credentials (используйте .local)

### 3. Локальные настройки

✅ **Используйте для:**
- Персональные переопределения
- Отладочные флаги
- Временное отключение проверок
- Тестирование новых путей

❌ **Не используйте для:**
- Настроек команды
- Критичных конфигураций
- Долгосрочных изменений

## Git Integration

### Рекомендуемый .gitignore

```gitignore
# Глобальная конфигурация (часть репозитория iclaude)
# .nvm-isolated/.claude-isolated/settings.json - коммитится

# Проектная конфигурация (коммитится)
# .claude/settings.json - коммитится

# Локальная конфигурация (НЕ коммитится)
.claude/settings.local.json
.claude/.credentials.json
.claude/session-env/
```

### Команда vs Личные настройки

```bash
# Команда (коммитится)
echo '{"plansDirectory": "docs/plans"}' > .claude/settings.json
git add .claude/settings.json
git commit -m "config: save plans in docs/plans"

# Личные (не коммитится)
echo '{"plansDirectory": "my-plans"}' > .claude/settings.local.json
# Не добавлять в git!
```

## Отладка конфигурации

### Проблема: Настройка не работает

**Шаг 1: Проверьте файлы**
```bash
# Где настройка определена?
grep -r "plansDirectory" .nvm-isolated/.claude-isolated/ .claude/
```

**Шаг 2: Проверьте приоритет**
```bash
# Локальная переопределяет?
cat .claude/settings.local.json 2>/dev/null
```

**Шаг 3: Проверьте синтаксис**
```bash
# Валидный JSON?
jq . .claude/settings.json
```

### Проблема: Конфликт настроек

**Решение:**
```bash
# Удалить локальное переопределение
rm .claude/settings.local.json

# Или явно установить в проектной
vim .claude/settings.json
```

## Миграция настроек

### Из системной в изолированную

```bash
# Копировать настройки
cp ~/.claude/settings.json \
   .nvm-isolated/.claude-isolated/settings.json

# Проверить
cat .nvm-isolated/.claude-isolated/settings.json
```

### Из глобальной в проектную

```bash
# Извлечь специфичные настройки
jq '{plansDirectory, enabledPlugins}' \
   .nvm-isolated/.claude-isolated/settings.json \
   > .claude/settings.json
```

## Связанные файлы

```
iclaude/
├── .nvm-isolated/.claude-isolated/
│   └── settings.json              # Глобальная (изолированная)
├── .claude/
│   ├── settings.json              # Проектная (в git)
│   └── settings.local.json        # Локальная (не в git)
├── docs/
│   ├── PLANNING.md                # Планирование
│   ├── CONFIG_HIERARCHY.md        # Эта документация
│   └── plans/                     # Планы (если настроено)
└── README.md
```

## Ссылки

- [docs/PLANNING.md](PLANNING.md) - Конфигурация планирования
- [docs/plans/README.md](plans/README.md) - Документация планов
- [Claude Code Settings Docs](https://code.claude.com/docs/settings)

## См. также

- `.claude/settings.json` - Проектная конфигурация
- `.nvm-isolated/.claude-isolated/CLAUDE.md` - Инструкции для Claude
