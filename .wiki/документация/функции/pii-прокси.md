---
wiki_sources:
  - "docs/functions/PII_MASKING.md"
  - "docs/functions/CONFIGURATION.md"
  - "docs/functions/TELEMETRY.md"
wiki_updated: 2026-05-06
wiki_status: developing
wiki_outgoing_links:
  - "[[presidio|Microsoft Presidio]]"
  - "[[блокировка-секретов|block-secrets.py]]"
  - "[[redact-secrets|redact-secrets.py]]"
  - "[[статуслайн|Статуслайн]]"
  - "[[прокси|Прокси]]"
wiki_external_links:
  - "https://github.com/sgasser/pasteguard"
  - "https://microsoft.github.io/presidio/"
  - "https://docs.anthropic.com/en/docs/claude-code/hooks"
tags:
  - iclaude
  - documentation
aliases:
  - "PII proxy"
  - "PII-маскирование"
  - "маскирование персональных данных"
  - "--pii-proxy"
---

# PII-прокси (маскирование персональных данных)

Локальный HTTP-прокси между Claude Code и Anthropic API, который перехватывает запросы и маскирует персональные данные (PII) и секреты перед их отправкой в облако. Реализован в `lib/pii-proxy/server.py` с использованием Microsoft Presidio NLP.

## Основные характеристики

### Двухуровневая защита (реализована в iclaude)

```
Claude Code → PreToolUse
    ├── block-secrets.py    (Слой 1: блокировка по ПУТИ файла)
    └── redact-secrets.py   (Слой 2: маскирование СОДЕРЖИМОГО инструментов)
```

Дополнительно: PII proxy-сервер маскирует содержимое API-запросов на уровне HTTP.

### Уровни маскирования

| Уровень | Что делает |
|---------|-----------|
| `standard` | Presidio NLP + regex (максимальная защита) |
| `secrets` | Только regex: API-ключи, токены, пароли |
| `off` | Без маскирования (только для отладки) |

### Запуск

```bash
./iclaude.sh --pii-proxy
./iclaude.sh --pii-proxy --sandbox-microvm  # совместим с microVM
./iclaude.sh --pii-proxy --router           # совместим с Router
```

### Метрики (GET /api/metrics)

```json
{
  "masked_items_total": 42,
  "uptime_seconds": 183.5,
  "masking_level": "standard",
  "log_level": "info",
  "analyzer_ready": true
}
```

Метрики отображаются в статуслайне иконкой 🛡 со счётчиком замаскированных элементов (кэшируются 30с).

### Конфигурация (.claude_config)

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `USE_PII_PROXY` | `false` | Автоматически включать при каждом запуске |
| `PII_PROXY_MASKING_LEVEL` | `standard` | Уровень маскирования |
| `PII_PROXY_LOG_LEVEL` | `info` | Уровень логирования: `info` или `debug` |
| `PII_PROXY_PORT` | `0` (авто) | Фиксированный порт (0 = случайный) |
| `PII_PROXY_ENABLE_FALLBACK` | `true` | Regex-fallback если Presidio недоступен |

### Логирование

Лог-файл сессии: `.nvm-isolated/.claude-isolated/pii-proxy-logs/{SESSION_ID}.log`

В режиме `debug` логируется тип PII, расположение в запросе и исходное значение. Debug-лог автоудаляется при завершении сессии (содержит чувствительные метаданные).

## Идемпотентная установка

```bash
./iclaude.sh --install-pii-proxy
```

Установка идемпотентна: повторный запуск безопасен. Пропускает уже установленные компоненты (venv, Presidio, spaCy модель ~587MB).

## Экспортируемые переменные (launch.sh)

| Переменная | Описание |
|------------|----------|
| `ICLAUDE_PII_ACTIVE` | `1` если PII proxy запущен |
| `ICLAUDE_PII_MASKING_LEVEL` | Уровень маскирования |
| `ICLAUDE_PII_ACTIVE_PORT` | Порт для curl к `/api/metrics` |
| `ICLAUDE_PII_LOG_PATH` | Путь к лог-файлу сессии |
