---
wiki_sources: ["docs/functions/ROUTER.md"]
wiki_updated: 2026-05-05
wiki_status: developing
tags: [iclaude, features, router, ccr]
aliases: ["CCR", "Claude Code Router", "маршрутизация моделей"]
---

# Router (Claude Code Router)

Claude Code Router (CCR) — прослойка между Claude Code и LLM-провайдерами, которая позволяет маршрутизировать запросы к разным моделям (DeepSeek, Gemini, Ollama, OpenAI) в зависимости от задачи.

## Основные характеристики

### Запуск с Router

```bash
./iclaude.sh --router
```

### Жизненный цикл CCR-сервера

```
iclaude.sh
  └─ exec ccr code          ← iclaude-процесс заменяется (exec, не spawn)
       ├─ проверить PID-файл (~/.claude-code-router/*.pid)
       ├─ [сервер НЕ запущен]: spawn CCR daemon → .unref() → в фон
       └─ spawn claude с env:
              ANTHROPIC_BASE_URL=http://127.0.0.1:3456
              ANTHROPIC_AUTH_TOKEN=test
```

CCR слушает на порту 3456 и проксирует запросы от Claude Code к провайдерам.

### Схема конфигурации (CCR v2.0.0)

Конфиг хранится в `.nvm-isolated/.claude-isolated/router.json`. При запуске iclaude копирует его в `~/.claude-code-router/config.json`.

| Схема | Формат | Статус |
|-------|--------|--------|
| Актуальная (v2.0.0) | `"Providers": [...]`, `"Router": {...}` | Поддерживается |
| Устаревшая | `"providers": {...}`, `"routing": {...}` | Не работает |

### Маршрутизация по слотам

Router использует именованные слоты: `default`, `background`, `longContext`. Каждый слот — имя провайдера и модели для конкретного типа запросов.

```json
{
  "Router": {
    "default": "anthropic",
    "background": "deepseek",
    "longContext": "gemini"
  }
}
```

### Sub-agents и model в AGENT.md

Sub-agents указывают нужный слот через поле `model` в `AGENT.md`:

```yaml
model: background   # → DeepSeek (дешевле для рутины)
model: longContext  # → Gemini (большой контекст)
```

## Поддерживаемые провайдеры

- Anthropic (Claude Sonnet/Opus/Haiku)
- DeepSeek (deepseek-chat, deepseek-coder, deepseek-r1)
- Google Gemini (2.5 Pro, 2.0 Flash)
- OpenRouter (множество моделей)
- Ollama (локальные модели: llama, mistral, qwen)
- OpenAI (gpt-4, gpt-3.5-turbo, o1)

## Конфигурация через .claude_config

```bash
CCR_PORT=3456       # порт CCR (по умолчанию 3456)
# API ключи провайдеров:
DEEPSEEK_API_KEY=sk-...
OPENROUTER_API_KEY=sk-or-...
```

## Ограничения

- CCR требует реальный Anthropic API ключ (`sk-ant-api03-...`), OAuth токен (`sk-ant-oat01-...`) не подходит
- При `--router` iclaude выполняет `exec ccr code` — PID процесса меняется

## Связанные концепции

- [[функции/возможности/autoresearch]] — autoresearch вариант C использует Router для параллельных агентов
- [[функции/интеграции/claude-code-router]] — детали интеграции CCR
