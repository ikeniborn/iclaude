---
wiki_sources: ["docs/functions/QUICK_CONFIG.md"]
wiki_updated: 2026-05-05
wiki_status: stub
tags: [iclaude, configuration, plans, settings-json]
aliases: ["plansDirectory", "быстрая настройка", "settings.json"]
---

# Быстрая конфигурация (Quick Config)

Шпаргалка по типичным настройкам Claude Code через settings.json.

## Основные характеристики

### Настройка plansDirectory

Планы Claude Code можно направить в конкретную директорию.

**Глобально (для всех проектов):**

```bash
vim .nvm-isolated/.claude-isolated/settings.json
# Добавить:
{ "plansDirectory": "docs/plans" }
```

**Для конкретного проекта:**

```bash
# В git:
vim .claude/settings.json

# Не в git:
vim .claude/settings.local.json

# Добавить:
{ "plansDirectory": "docs/plans" }
```

### Проверка

```bash
grep -r "plansDirectory" .nvm-isolated/.claude-isolated/ .claude/ 2>/dev/null
```

## Связанные концепции

- [[функции/конфигурация/переменные-окружения]] — все переменные .claude_config
