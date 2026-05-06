---
wiki_sources: ["docs/functions/INTEGRATIONS.md"]
wiki_updated: 2026-05-06
wiki_status: developing
tags: [iclaude, integration, router, ccr, llm, deepseek, openrouter, gemini]
aliases: ["CCR", "Claude Code Router", "роутер", "альтернативные LLM"]
---

# Claude Code Router (CCR)

Claude Code Router перехватывает вызовы к Claude API и перенаправляет к альтернативным LLM-провайдерам. Позволяет использовать DeepSeek, Gemini, Ollama, OpenRouter вместо или в дополнение к Anthropic API.

## Основные характеристики

| Параметр | Значение |
|----------|----------|
| Модуль | `lib/router/` (detect.sh, install.sh, status.sh) |
| Флаги | `--router` (opt-in), `--install-router`, `--check-router` |
| Зависимости | `@musistudio/claude-code-router` (npm), `router.json` конфиг |
| Конфиг | `.nvm-isolated/.claude-isolated/router.json` |

## Поддерживаемые провайдеры

OpenRouter, DeepSeek, OpenAI, Ollama (локально), Google Gemini, Volcengine, SiliconFlow.

## Запуск

```bash
# Запустить с роутером
./iclaude.sh --router

# Установить роутер
./iclaude.sh --install-router

# Проверить статус
./iclaude.sh --check-router
```

## Маппинг моделей

Router перехватывает вызовы по именам Claude-моделей и перенаправляет к реальному провайдеру. Пример в `router.json`:

```json
{
  "Router": {
    "default": "deepseek,deepseek-chat",
    "background": "deepseek,deepseek-chat",
    "think": "openrouter,anthropic/claude-opus-4"
  }
}
```

Пример правил маршрутизации по умолчанию:
- `context_length > 60000` → Opus через OpenRouter
- `thinking_required` → Sonnet через OpenRouter
- По умолчанию → DeepSeek `deepseek-chat`

## API ключи в .claude_config

```bash
# Используются через плейсхолдеры в router.json: "${VAR_NAME}"
export ANTHROPIC_API_KEY=sk-ant-api03-...   # для Anthropic через CCR
export DEEPSEEK_API_KEY=...
export OPENROUTER_API_KEY=...
export GOOGLE_API_KEY=...
```

**Важно:** В нативном режиме (без `--router`) API ключ не нужен — Claude Code использует OAuth из `.credentials.json`. OAuth токен (`sk-ant-oat01-...`) **не принимается** `api.anthropic.com` через CCR.

## Ограничения

- По умолчанию роутер **выключен** (`--router` — opt-in флаг)
- CCR требует реальный API ключ, не OAuth токен подписки
- Локальные модели Ollama работают без API ключа, но требуют запущенного `ollama serve`

## Связанные концепции

- [[функции/возможности/router]] — подробная документация по конфигурации router.json
- [[функции/возможности/oauth]] — нативный режим без роутера использует OAuth
