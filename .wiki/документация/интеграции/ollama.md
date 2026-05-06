---
wiki_sources:
  - "docs/functions/ROUTER.md"
  - "docs/functions/PII_MASKING.md"
  - "docs/functions/STATUSLINE.md"
wiki_updated: 2026-05-06
wiki_status: developing
wiki_outgoing_links:
  - "[[маршрутизатор-ccr|Claude Code Router]]"
  - "[[статуслайн|Статуслайн]]"
wiki_external_links:
  - "https://ollama.ai"
tags:
  - iclaude
  - documentation
aliases:
  - "Ollama"
  - "локальные модели"
  - "local LLM"
---

# Ollama (локальные LLM-модели)

Локальный сервер для запуска open-source языковых моделей (qwen2.5-coder, llama3.1, mistral и др.) без отправки данных в облако. В контексте iclaude используется через Claude Code Router как провайдер для слота `background`.

## Основные характеристики

### Конфигурация в router.json

```json
{
  "name": "ollama",
  "api_base_url": "http://localhost:11434/v1/chat/completions",
  "api_key": "ollama",
  "models": ["qwen2.5-coder:7b", "llama3.1:8b", "mistral:7b"]
}
```

Ollama предоставляет OpenAI-compatible API — трансформер не нужен.

`api_key` обязателен в схеме CCR, но Ollama его не проверяет — используется заглушка `"ollama"`.

### Рекомендуемые модели

| Модель | Размер | VRAM | Применение |
|--------|--------|------|-----------|
| `qwen2.5-coder:1.5b` | 1.0 GB | 2 GB | Минимальные ресурсы |
| `qwen2.5-coder:7b` | 4.7 GB | 6 GB | Фоновые агенты (оптимальный баланс) |
| `llama3.1:8b` | 4.9 GB | 6 GB | Универсальная альтернатива |
| `qwen2.5-coder:14b` | 9.0 GB | 12 GB | Высокое качество кода |

### Маршрутизация sub-agents через Ollama

Агенты с `model: haiku` в AGENT.md маршрутизируются в слот `background` CCR → Ollama. Это позволяет запускать READ-ONLY фоновые агенты (researcher-agent, planning-agent) локально без затрат на API.

### Отображение в статуслайне

Ollama определяется автоматически по формату JSON с полем `model` с именами типа `llama3.1:70b-instruct`. Иконка: 🦙. Стоимость всегда показывается как `$0.00` (локально = бесплатно).

## Установка

```bash
# Установить Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Загрузить модель
ollama pull qwen2.5-coder:7b

# Проверить API
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen2.5-coder:7b","messages":[{"role":"user","content":"hi"}]}'
```

## Диагностика

```bash
systemctl status ollama
ollama list

# При CPU-инференции (медленно) увеличить таймаут в router.json:
# "API_TIMEOUT_MS": 1200000
```

Ollama находится на localhost — всегда в `NO_PROXY`, прокси не нужен.
