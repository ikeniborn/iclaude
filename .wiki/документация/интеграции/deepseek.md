---
wiki_sources:
  - "docs/functions/ROUTER.md"
  - "docs/functions/STATUSLINE.md"
wiki_updated: 2026-05-06
wiki_status: stub
wiki_outgoing_links:
  - "[[маршрутизатор-ccr|Claude Code Router]]"
  - "[[статуслайн|Статуслайн]]"
wiki_external_links:
  - "https://api.deepseek.com"
tags:
  - iclaude
  - documentation
aliases:
  - "DeepSeek"
  - "deepseek-chat"
  - "deepseek-reasoner"
---

# DeepSeek (LLM-провайдер)

Облачный провайдер LLM-моделей с OpenAI-совместимым API. В контексте iclaude используется через Claude Code Router как основной (слот `default`) и reasoning (слот `think`) провайдер. Дешевле Anthropic API.

## Основные характеристики

### Конфигурация в router.json

```json
{
  "name": "deepseek",
  "api_base_url": "https://api.deepseek.com/chat/completions",
  "api_key": "${DEEPSEEK_API_KEY}",
  "models": ["deepseek-chat", "deepseek-reasoner"],
  "transformer": {
    "use": ["deepseek"],
    "deepseek-chat": {
      "use": ["tooluse"]
    }
  }
}
```

API ключ хранится в `.claude_config` как `export DEEPSEEK_API_KEY=...`. Переменная интерполируется CCR при загрузке конфига.

### Трансформеры

- `deepseek` — обязателен: адаптирует формат запросов/ответов между Anthropic API и DeepSeek API
- `tooluse` для `deepseek-chat` — оптимизирует вызовы инструментов через `tool_choice`

### Отображение в статуслайне

Иконка 🤖. Стоимость рассчитывается по встроенной базе цен (30+ моделей). Включает `deepseek-chat` и `deepseek-reasoner`.

## Применение в контексте iclaude

Текущая конфигурация проекта использует DeepSeek как:
- `default` — все стандартные запросы Claude Code
- `think` — Plan Mode и reasoning-heavy задачи

Sub-agents с `model: sonnet` и `model: opus` направляются в слот `default` → DeepSeek (например, critic-agent и execution-agent в autoresearch).

Требует реального API ключа (`sk-...`), не OAuth токен.
