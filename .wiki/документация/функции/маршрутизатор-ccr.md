---
wiki_sources:
  - "docs/functions/ROUTER.md"
  - "docs/functions/USE_CASES.md"
  - "docs/functions/CONFIGURATION.md"
wiki_updated: 2026-05-06
wiki_status: developing
wiki_outgoing_links:
  - "[[ollama|Ollama]]"
  - "[[deepseek|DeepSeek]]"
  - "[[прокси|Прокси]]"
wiki_external_links: []
tags:
  - iclaude
  - documentation
aliases:
  - "CCR"
  - "Claude Code Router"
  - "router"
  - "маршрутизатор"
---

# Маршрутизатор Claude Code (CCR)

Claude Code Router (CCR) — локальный HTTP-сервер, который перехватывает запросы Claude Code и перенаправляет их к различным LLM-провайдерам (DeepSeek, Ollama, OpenRouter, Gemini и др.) вместо или вместе с Anthropic API. Версия CCR: v2.0.0 (`@musistudio/claude-code-router`).

## Основные характеристики

### Архитектура процессов

`ccr code` — не демон, а менеджер сессии. При запуске `./iclaude.sh --router`:

1. `iclaude.sh` копирует `.nvm-isolated/.claude-isolated/router.json` в `~/.claude-code-router/config.json`
2. Запускается `exec ccr code` (заменяет iclaude-процесс)
3. CCR запускает фоновый HTTP-сервер на порту 3456 (если не запущен)
4. Claude Code получает `ANTHROPIC_BASE_URL=http://127.0.0.1:3456`

### Схема конфигурации (CCR v2.0.0)

Актуальная схема использует массив `Providers` и объект `Router` со слотами:

```json
{
  "PORT": 3456,
  "Providers": [
    {
      "name": "deepseek",
      "api_base_url": "https://api.deepseek.com/chat/completions",
      "api_key": "${DEEPSEEK_API_KEY}",
      "models": ["deepseek-chat"],
      "transformer": { "use": ["deepseek"] }
    }
  ],
  "Router": {
    "default": "deepseek,deepseek-chat",
    "background": "ollama,qwen2.5-coder:7b"
  }
}
```

Старая схема с `"providers": {...}` и `"routing": {...}` несовместима с CCR v2.0.0.

### Слоты маршрутизации

| Слот | Обязательный | Описание |
|------|:------------:|----------|
| `default` | Да | Основная модель |
| `background` | Нет | Фоновые задачи (sub-agents с `model: haiku`) |
| `think` | Нет | Reasoning-heavy задачи, Plan Mode |
| `longContext` | Нет | Запросы > `longContextThreshold` токенов (по умолчанию 60000) |
| `webSearch` | Нет | Запросы с web search |
| `image` | Нет | Задачи с изображениями |

### Маршрутизация sub-agents

Агент с `model: haiku` в AGENT.md попадает в слот `background`. Полный ID модели типа `claude-haiku-4-5-20251001` молча игнорируется — нужно использовать алиасы (`haiku`, `sonnet`, `opus`).

### Автоматическая остановка (reference counting)

CCR-сервер самоуправляемый: при старте сессии счётчик +1, при завершении -1. Когда счётчик = 0 → SIGTERM к серверу. Несколько параллельных `--router` сессий используют один общий сервер.

## Встроенные трансформеры

| Трансформер | Назначение |
|-------------|-----------|
| `anthropic` | Сохраняет оригинальные параметры |
| `deepseek` | Адаптация для DeepSeek API |
| `gemini` | Адаптация для Google Gemini |
| `openrouter` | Адаптация для OpenRouter |
| `tooluse` | Оптимизирует вызовы инструментов |
| `reasoning` | Обрабатывает `reasoning_content` |
| `maxtoken` | Устанавливает конкретное `max_tokens` |

## Применение в контексте iclaude

Конфигурация хранится в `.nvm-isolated/.claude-isolated/router.json` и копируется при каждом запуске `--router`. Редактировать нужно именно этот файл, а не `~/.claude-code-router/config.json`.

Переменные окружения в значениях конфига (`${DEEPSEEK_API_KEY}`) интерполируются рекурсивно. API-ключи хранятся в `.claude_config` как `export DEEPSEEK_API_KEY=...`.

Ручная очистка при зависшем сервере:
```bash
ccr stop
# или вручную:
kill $(cat ~/.claude-code-router/.claude-code-router.pid)
```
