---
wiki_sources:
  - "docs/functions/PII_MASKING.md"
  - "docs/functions/CONFIGURATION.md"
  - "docs/functions/TELEMETRY.md"
wiki_updated: 2026-05-07
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

## Общий прокси для нескольких сессий (shared mode)

Один процесс PII-прокси разделяется между параллельными iclaude-сессиями с маскированием — экономит ~300–500 МБ Presidio NLP на каждый дополнительный запуск.

### Активация

Shared mode включается автоматически, когда PII-прокси запускается без CCR (`CCR_SESSION_OWNED != true`). Сессия с CCR продолжает поднимать собственный per-session прокси.

### Состояния `PII_PROXY_SESSION_OWNED`

| Значение | Семантика |
|----------|-----------|
| `true`   | Сессия владеет своим прокси (CCR-режим) — останавливает по выходу |
| `shared` | Подключена к общему прокси — снимает регистрацию, гасит процесс только если она последняя |
| `false`  | Подпроцесс/наследник — ничего не делает |

### Архитектура файлов

```
.nvm-isolated/.claude-isolated/pii-proxy-pid/
  ├── shared.lock              flock(2) — атомарность start/stop
  ├── shared.pid               PID общего сервера
  └── consumers/
      ├── {SID-1}.pid          PID bash-сессии-потребителя
      └── {SID-2}.pid
```

Сервер запускается с `ICLAUDE_SESSION_ID=shared` (sentinel — обрабатывается наравне с 12-hex SID в `server.py`).

### Жизненный цикл

1. **Старт:** `flock -x 9` на `shared.lock` → если `shared.pid` жив, переиспользуем; иначе spawn нового сервера (`9>&-` закрывает fd блокировки в child, `disown` подавляет «Killed» при reaping).
2. **Регистрация потребителя:** `_register_pii_consumer` пишет PID в `consumers/${ICLAUDE_SESSION_ID}.pid`.
3. **Sweep:** `_sweep_dead_pii_consumers` чистит файлы потребителей с мёртвыми PID до проверки счётчика.
4. **Остановка:** `flock -x 9` → удаляем свой consumer-pid, sweep, считаем `consumers/*.pid`. Если `count == 0` — TERM серверу, ждём, KILL fallback, удаляем `shared.pid` + порт-файл.

### Просмотр состояния

```bash
./iclaude.sh --status-pii-proxy
```

В разделе `Shared proxy:` показывает PID/порт общего сервера и список активных consumer-сессий с их bash-PID.

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
