---
wiki_sources:
  - "docs/functions/ROUTER.md"
  - "docs/functions/USE_CASES.md"
  - "docs/functions/CONFIGURATION.md"
  - "lib/launcher/launch.sh"
  - "docs/superpowers/specs/2026-05-11-ccr-integration-verify-design.md"
  - "docs/superpowers/plans/2026-05-11-ccr-integration-verify.md"
  - "lib/router/status.sh"
  - ".nvm-isolated/.claude-isolated/router.json"
  - "tests/test_ccr_integration.sh"
wiki_updated: 2026-05-11
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

## Комбинированный режим: CCR + PII proxy (launch.sh)

В режиме `--router --pii-proxy` `exec ccr code` невозможен — нужно держать оба сервера живыми. `launch_claude()` в `lib/launcher/launch.sh` управляет этим через `start_ccr_server`:

```
start_ccr_server  → ANTHROPIC_BASE_URL=http://CCR:PORT
start_pii_proxy_server → читает ANTHROPIC_BASE_URL как upstream → ANTHROPIC_BASE_URL=http://PII:PORT
claude binary → PII proxy → CCR → providers
```

### `start_ccr_server` (lib/launcher/launch.sh)

Запускает CCR как фоновый демон через `ccr start` (не `ccr code`). Перед запуском проверяет порт через `/dev/tcp` — если занят, переиспользует существующий сервер (`CCR_SESSION_OWNED=false`).

| Глобал | Значение |
|--------|----------|
| `CCR_PID` | PID запущенного демона |
| `CCR_SESSION_OWNED` | `true` — сессия запустила CCR; `false` — переиспользование |
| `CCR_UPSTREAM_ACTIVE` | `true` — `ANTHROPIC_BASE_URL` указывает на CCR; экспортируется в **обоих** путях (fix 2026-05-11) |

Готовность: `bash /dev/tcp` polling, max 5s (10 × 0.5s).

**`CCR_HOME`**: `launch_claude` устанавливает `CCR_HOME` на `.nvm-isolated/.claude-isolated` (если isolated env активен) так, что CCR хранит PID-файл, логи и конфиг вне `~/.claude-code-router/`.

### `stop_ccr_server`

Срабатывает по `EXIT/INT/TERM` trap. Убивает CCR только если `CCR_SESSION_OWNED=true`. Graceful shutdown: SIGTERM → wait 1s → SIGKILL fallback.

## Исправления багов CCR (2026-05-11)

Три бага в интеграции CCR были выявлены и исправлены (коммит после планa `2026-05-11-ccr-integration-verify`).

### Баг 1: флаг версии `--version` → `-v` (`lib/router/status.sh:34`)

`lib/router/status.sh` вызывал `ccr --version` для определения версии CCR, но CCR v2.0.0 не поддерживает `--version` — команда выводит справку и завершается с кодом 1. Из-за `pipefail` вся строка падала, `|| echo "unknown"` срабатывал, и в статуслайне версия отображалась двумя сломанными строками. Исправление: `ccr -v` (выводит `claude-code-router version: 2.0.0`, завершается с кодом 0).

### Баг 2: формат слотов `think`/`longContext` в `router.json`

Слоты `think` и `longContext` в `.nvm-isolated/.claude-isolated/router.json` содержали `"deepseek-v4-flash:cloud"` без обязательного префикса провайдера. CCR не мог маршрутизировать запросы к этим слотам. Исправление: добавлен префикс `ollama,` — `"ollama,deepseek-v4-flash:cloud"`. Формат `"провайдер,модель"` обязателен для всех ненативных (не Anthropic) слотов.

### Баг 3: обход CCR в `--router --pii-proxy` при переиспользовании демона (`lib/launcher/launch.sh`)

Когда CCR уже запущен другой сессией, `start_ccr_server()` устанавливал только `CCR_SESSION_OWNED=false`. Функция `start_pii_proxy_server()` использовала эту переменную как охранное условие для shared proxy: `CCR_SESSION_OWNED != true` означало «shared разрешён» — и прокси присоединялся к существующему shared-экземпляру, у которого upstream был `api.anthropic.com` (выставлен предыдущей `--pii-proxy`-сессией). Трафик шёл `claude → shared_proxy → api.anthropic.com`, минуя CCR.

Исправление: введена переменная `CCR_UPSTREAM_ACTIVE=true`, которая экспортируется в **обоих** путях `start_ccr_server()` — как при свежем запуске (`CCR_SESSION_OWNED=true`), так и при переиспользовании (`CCR_SESSION_OWNED=false`). Охранное условие в `start_pii_proxy_server()` изменено с `CCR_SESSION_OWNED != true` на `CCR_UPSTREAM_ACTIVE != true`. `stop_ccr_server()` по-прежнему проверяет `CCR_SESSION_OWNED` — не меняется (убивать CCR нужно только если эта сессия его запустила).

## E2E тест (`tests/test_ccr_integration.sh`)

Bash-скрипт для сквозной проверки CCR с Ollama cloud-моделями. Запуск: `bash tests/test_ccr_integration.sh`.

| Код выхода | Условие |
|:----------:|---------|
| `0` | CCR маршрутизировал запрос, ответ содержит `"content"` |
| `1` | CCR запущен, но запрос не прошёл (сетевая ошибка, модель недоступна) |
| `77` | CCR не установлен или `ollama signin` не выполнен (skip, не ошибка) |

Тест запускает CCR (`ccr start`), ждёт готовности порта 3456 (max 10s), делает POST на `/v1/messages` с моделью `claude-sonnet-4-5` (роутится в `default` слот), проверяет наличие `"content"` в ответе. HTTP 401 трактуется как skip (ollama не авторизован).
