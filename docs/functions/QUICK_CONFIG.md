# Quick Configuration Cheat Sheet

Быстрые команды для настройки Claude Code в iclaude.sh.

## Настройка plansDirectory

### Глобально (для всех проектов)

```bash
# Изолированная среда
vim .nvm-isolated/.claude-isolated/settings.json

# Добавить:
{
  "plansDirectory": "docs/plans"
}
```

### Для конкретного проекта

```bash
# Проектная (в git)
vim .claude/settings.json

# Локальная (не в git)
vim .claude/settings.local.json

# Добавить:
{
  "plansDirectory": "docs/plans"
}
```

## Быстрая проверка

```bash
# Где настроено?
grep -r "plansDirectory" \
  .nvm-isolated/.claude-isolated/ \
  .claude/ 2>/dev/null

# Создать каталог
mkdir -p docs/plans

# Проверить структуру
ls -la docs/plans/
```

## Использование

```bash
# Запуск
./iclaude.sh

# Создание плана
> /plan Implement feature X

# Проверка
ls docs/plans/

# Git
git add docs/plans/
git commit -m "docs: add plan"
```

## Приоритеты

```
Высокий → .claude/settings.local.json  (не в git)
          .claude/settings.json        (в git)
Низкий  → .nvm-isolated/.claude-isolated/settings.json
```

## Документация

- [PLANNING.md](PLANNING.md) - Полное руководство
- [CONFIG_HIERARCHY.md](CONFIG_HIERARCHY.md) - Иерархия конфигураций
- [plans/README.md](plans/README.md) - Документация каталога
