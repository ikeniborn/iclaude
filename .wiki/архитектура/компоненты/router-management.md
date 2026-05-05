---
wiki_sources:
  - "docs/architecture/overview.yaml"
  - "docs/architecture/diagrams/README.md"
wiki_updated: 2026-05-05
wiki_status: stub
tags:
  - architecture
  - router
  - iclaude
aliases:
  - "CCR"
  - "Claude Code Router"
  - "маршрутизатор"
---

# Router Management

Модуль интеграции с Claude Code Router (CCR) — прослойкой, позволяющей перенаправлять API-вызовы Claude Code к альтернативным LLM-провайдерам.

## Основные характеристики

**Расположение в коде:** `iclaude.sh:333-1430`

### Субкомпоненты

- `detect_router` (`iclaude.sh:333-363`) — проверяет наличие `router.json` и бинарника `ccr`
- `get_router_path` (`iclaude.sh:365-382`) — находит `ccr` в изолированном или системном окружении
- `check_router_status` (`iclaude.sh:1366-1430`) — выводит конфигурацию и статус роутера

### Поддерживаемые провайдеры

| Провайдер | Тип |
|-----------|-----|
| DeepSeek | Облачный API |
| OpenRouter | Агрегатор |
| Ollama | Локальный |
| Google Gemini | Облачный API |
| OpenAI | Облачный API |
| Volcengine | Облачный API |
| SiliconFlow | Облачный API |
| Anthropic | Через прокси |

### Активация

```bash
./iclaude.sh --router       # Запуск через Router
./iclaude.sh --install-lsp  # Только если нужен LSP
```

Режим opt-in. Конфигурация: `router.json` в `$CLAUDE_CONFIG_DIR`.

### Ограничение совместимости

CCR требует реального API ключа (`sk-ant-api03-...`). OAuth-токены (`sk-ant-oat01-...`) не поддерживаются.

API ключи провайдеров хранятся в `.claude_config`:
```bash
export DEEPSEEK_API_KEY=sk-...
```

## Связанные концепции

- [[../потоки/поток-запуска-router]]
