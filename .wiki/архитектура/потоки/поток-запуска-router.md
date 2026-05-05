---
wiki_sources:
  - "docs/architecture/overview.yaml"
  - "docs/architecture/diagrams/README.md"
  - "docs/architecture/diagrams/data-flow-router-launch.md"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - architecture
  - router
  - iclaude
aliases:
  - "router launch flow"
  - "запуск через Router"
  - "--router"
---

# Поток запуска через Router

Последовательность операций при запуске Claude Code через Claude Code Router (CCR) для использования альтернативных LLM-провайдеров.

## Основные характеристики

**Команда:** `./iclaude.sh --router`
**Диаграмма:** `docs/architecture/diagrams/data-flow-router-launch.md`

### Предусловия

| Проверка | Объект | При отсутствии |
|----------|--------|---------------|
| `router.json` | конфигурация провайдеров | Error: Router not installed |
| `ccr` binary | бинарник роутера | Error: Router not installed |

### Этапы

1. Получение флага `--router`
2. Проверка доступности роутера (`detect_router`) — два условия выше
3. Копирование `router.json` → `~/.claude-code-router/config.json`
4. Чтение конфигурации (провайдеры, модели, API ключи с подстановкой `${VAR}`)
5. Загрузка настроек прокси
6. Установка `HTTPS_PROXY`, `HTTP_PROXY` (наследуется роутером автоматически)
7. Запуск `ccr code` (вместо стандартного `claude`)
8. Claude Code Router Service перехватывает API-вызовы
9. Маршрутизация к настроенному провайдеру
10. Ответ форматируется и возвращается в Claude Code CLI

### Поддерживаемые провайдеры

| Провайдер | Тип |
|-----------|-----|
| DeepSeek | Cloud API |
| OpenRouter | Агрегатор моделей |
| Ollama | Локальный |
| Gemini | Google Cloud |
| Anthropic | Нативный (через прокси) |
| Volcengine | ByteDance Cloud |
| SiliconFlow | Cloud API |

### Конфигурационные файлы

| Файл | В Git? | Назначение |
|------|--------|-----------|
| `router.json.example` | Да | Шаблон со всеми провайдерами |
| `router.json` | Да | Конфигурация с `${VAR}` плейсхолдерами |
| `~/.claude-code-router/config.json` | Нет | Runtime — копия с подставленными значениями |

Пример подстановки: `"apiKey": "${DEEPSEEK_API_KEY}"` → значение из окружения (`.claude_config`).

### Совместимость с прокси

Переменные `HTTPS_PROXY` / `HTTP_PROXY` наследуются роутером без дополнительной настройки.

## Управление

```bash
./iclaude.sh --install-router   # установка
./iclaude.sh --check-router     # статус: версия, путь, провайдеры, модель по умолчанию
```

## Связанные концепции

- [[../компоненты/router-management]]
