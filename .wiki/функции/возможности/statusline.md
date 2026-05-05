---
wiki_sources: ["docs/functions/STATUSLINE.md"]
wiki_updated: 2026-05-05
wiki_status: developing
tags: [iclaude, features, statusline, monitoring, tokens]
aliases: ["строка статуса", "claude-statusline", "status bar", "метрики токенов"]
---

# Statusline (строка статуса)

Строка статуса Claude Code отображает в реальном времени: использование контекста, стоимость сессии, метрики кэша и метаданные сессии. Реализована в `claude-statusline.sh`, получает JSON-данные от Claude Code через STDIN.

## Основные характеристики

**Расположение скрипта:** `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh`

**Требуемая версия Claude Code:** v2.1+ (использует вложенный объект `context_window`)

### Поддерживаемые провайдеры (v4.1+)

| Провайдер | Иконка | Расчёт стоимости | Кэш |
|-----------|--------|-----------------|-----|
| Anthropic (Claude) | нет | Предрассчитана | Да |
| OpenAI | 🤖 | Расчётная | Нет |
| DeepSeek | 🤖 | Расчётная | Нет |
| OpenRouter | 🤖 | Расчётная | Нет |
| Ollama | 🦙 | Ноль (локальная) | Нет |
| Gemini | ✨ | Расчётная | Нет |

### Автодетекция провайдера

```bash
# Anthropic Claude
{ "context_window": { "total_input_tokens": ... } }

# OpenAI-совместимый формат
{ "usage": { "prompt_tokens": ..., "completion_tokens": ... } }

# Ollama (OpenAI-совместимый + имя локальной модели)
{ "usage": { ... }, "model": "llama3.1:70b-instruct" }

# Google Gemini
{ "usageMetadata": { "promptTokenCount": ... } }
```

### Отображаемые метрики

- Использование контекстного окна (%)
- Стоимость сессии ($)
- Cache hit rate / cache tokens
- ID сессии и ссылки

## Применение

Statusline активируется автоматически при запуске `./iclaude.sh`. Интеграция с oh-my-posh обеспечивает отображение в строке статуса терминала.

## Связанные концепции

- [[функции/интеграции/oh-my-posh]] — oh-my-posh для рендеринга строки статуса
- [[функции/возможности/telemetry]] — источники данных для метрик (stats-cache.json)
- [[библиотеки/категории/statusline]] — bash-модуль строки статуса
