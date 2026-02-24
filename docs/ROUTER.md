# Claude Code Router: конфигурация и маршрутизация

> Точная документация Claude Code Router (CCR v2.0.0) на основе анализа исходного кода.
> Охватывает все поддерживаемые параметры конфигурации, слоты маршрутизации и внешние модели.
>
> Дата: 2026-02-24 | CCR версия: 2.0.0 (@musistudio/claude-code-router)

---

## Содержание

- [Как iclaude использует Router](#как-iclaude-использует-router)
- [Полная схема router.json](#полная-схема-routerjson)
- [Параметры верхнего уровня](#параметры-верхнего-уровня)
- [Providers — провайдеры моделей](#providers--провайдеры-моделей)
- [Transformer — типы трансформеров](#transformer--типы-трансформеров)
- [Router — слоты маршрутизации](#router--слоты-маршрутизации)
- [Маршрутизация sub-agents](#маршрутизация-sub-agents)
- [Внешние модели через Ollama](#внешние-модели-через-ollama)
- [Примеры конфигурации](#примеры-конфигурации)
- [Custom Router](#custom-router)
- [Диагностика](#диагностика)

---

## Как iclaude использует Router

```
1. ./iclaude.sh --router
2. launcher/launch.sh читает: .nvm-isolated/.claude-isolated/router.json
3. Копирует в: ~/.claude-code-router/config.json
4. Запускает: ccr code [args]
5. CCR читает конфиг из ~/.claude-code-router/config.json
6. CCR слушает на PORT (3456) и проксирует запросы Claude Code
```

**Важно:** редактировать нужно `.nvm-isolated/.claude-isolated/router.json` — iclaude автоматически копирует его в нужное место при каждом запуске с `--router`.

---

## Полная схема router.json

```json
{
  "PORT": 3456,
  "HOST": "127.0.0.1",
  "LOG": true,
  "LOG_LEVEL": "info",
  "API_TIMEOUT_MS": 30000,
  "PROXY_URL": "https://user:pass@proxy.example.com:8118",
  "NON_INTERACTIVE_MODE": false,
  "Providers": [
    {
      "name": "deepseek",
      "api_base_url": "https://api.deepseek.com/v1/chat/completions",
      "api_key": "${DEEPSEEK_API_KEY}",
      "models": ["deepseek-chat"],
      "transformer": {
        "use": ["deepseek"]
      }
    }
  ],
  "Router": {
    "default": "deepseek,deepseek-chat",
    "background": "deepseek,deepseek-chat",
    "think": "deepseek,deepseek-chat",
    "longContext": "deepseek,deepseek-chat",
    "longContextThreshold": 60000,
    "webSearch": "openrouter,perplexity/sonar",
    "image": "openrouter,openai/gpt-4o"
  }
}
```

---

## Параметры верхнего уровня

Все параметры подтверждены анализом исходного кода CCR (`dist/cli.js`, строка 969):

```javascript
{Providers:u, Router:l, PORT:c, HOST:h, API_TIMEOUT_MS:p,
 PROXY_URL:A, LOG:d, LOG_LEVEL:f, StatusLine:g, NON_INTERACTIVE_MODE:E, ...D} = a
```

| Параметр | Тип | Обязательный | По умолчанию | Описание |
|----------|-----|:------------:|:------------:|----------|
| `PORT` | number | нет | `3456` | Порт локального CCR-сервера |
| `HOST` | string | нет | `127.0.0.1` | Хост локального CCR-сервера |
| `LOG` | boolean | нет | `false` | Включить логирование |
| `LOG_LEVEL` | string | нет | `"info"` | Уровень лога: `debug`, `info`, `warn`, `error` |
| `API_TIMEOUT_MS` | number | нет | `30000` | Таймаут запросов к провайдерам в мс |
| `PROXY_URL` | string | нет | — | Прокси для запросов к внешним провайдерам |
| `NON_INTERACTIVE_MODE` | boolean | нет | `false` | Отключить интерактивный режим настройки |
| `Providers` | array | **да** | — | Список провайдеров моделей |
| `Router` | object | **да** | — | Правила маршрутизации по слотам |

### PROXY_URL

Применяется ко всем запросам CCR к внешним провайдерам. Формат:
```
https://user:pass@proxy.example.com:8118
https://proxy.example.com:8118
```

**Примечание:** iclaude также устанавливает `HTTPS_PROXY` / `HTTP_PROXY` в окружении перед запуском CCR. Для localhost-провайдеров (Ollama) прокси не применяется, так как `localhost` в `NO_PROXY`.

### API_TIMEOUT_MS

Рекомендуемые значения:
- `30000` (30 сек) — быстрые API (DeepSeek, OpenRouter)
- `600000` (10 мин) — медленные эндпоинты, агрессивные таймауты корпоративного прокси
- `1200000` (20 мин) — Ollama на CPU

---

## Providers — провайдеры моделей

Каждый элемент массива `Providers` описывает один LLM-провайдер.

### Поля провайдера

Подтверждено из исходного кода CCR (строки 928–931):

```javascript
i = {name: t, api_base_url: r, api_key: n, models: o}
if (a) i.transformer = a
```

| Поле | Тип | Обязательное | Описание |
|------|-----|:------------:|----------|
| `name` | string | **да** | Уникальный идентификатор провайдера (используется в Router) |
| `api_base_url` | string | **да** | URL API эндпоинта (валидируется через `new URL()`) |
| `api_key` | string | **да** | API ключ. Поддерживает `${ENV_VAR}` placeholders |
| `models` | string[] | **да** | Список доступных моделей провайдера |
| `transformer` | object | нет | Конфигурация трансформеров запроса/ответа |
| `transformer.use` | array | нет | Список применяемых трансформеров (см. ниже) |

### Синтаксис ссылки на провайдера в Router

```
"provider_name,model_name"
```

Пример: `"deepseek,deepseek-chat"` → провайдер `deepseek`, модель `deepseek-chat`.

### Переменные окружения в api_key

```json
{ "api_key": "${DEEPSEEK_API_KEY}" }
```

```bash
export DEEPSEEK_API_KEY="sk-..."
./iclaude.sh --router
```

---

## Transformer — типы трансформеров

Трансформеры преобразуют запросы/ответы между форматами Anthropic API и форматом провайдера.

### Полный список (подтверждён из `dist/cli.js`, строка 902)

```javascript
g8 = ["anthropic", "deepseek", "gemini", "openrouter", "groq", "maxtoken",
      "tooluse", "gemini-cli", "reasoning", "sampling", "enhancetool",
      "cleancache", "vertex-gemini", "chutes-glm", "qwen-cli", "rovo-cli"]
```

| Трансформер | Назначение | Когда использовать |
|-------------|-----------|-------------------|
| `anthropic` | Адаптация под Anthropic-совместимый API | Bedrock, Vertex Anthropic |
| `deepseek` | DeepSeek-специфичные заголовки и формат | api.deepseek.com и совместимые |
| `gemini` | Google Gemini API (иной формат запроса) | generativelanguage.googleapis.com |
| `gemini-cli` | Gemini через CLI-инструмент | Gemini CLI интеграция |
| `vertex-gemini` | Google Vertex AI с Gemini | Vertex AI эндпоинты |
| `openrouter` | OpenRouter маршрутизация + `provider.only` | openrouter.ai |
| `groq` | Groq-специфичная адаптация | api.groq.com |
| `tooluse` | Совместимость tool use для сторонних API | OpenAI-compatible эндпоинты (Ollama, и др.) |
| `reasoning` | Конвертация `reasoning_content` → `thinking` | Провайдеры с extended reasoning |
| `maxtoken` | Ограничение `max_tokens` | Любой провайдер |
| `sampling` | Настройка параметров сэмплирования | Кастомная настройка temperature/top_p |
| `enhancetool` | Расширенная поддержка tool calls | Улучшение совместимости инструментов |
| `cleancache` | Очистка кэша промптов | Работа с кэшированием |
| `chutes-glm` | Chutes GLM модели | chutes.ai API |
| `qwen-cli` | Qwen CLI интеграция | Qwen через CLI |
| `rovo-cli` | Rovo CLI интеграция | Rovo Dev CLI |

> **Важно:** `"openai"` — **не является** валидным трансформером. Для OpenAI-совместимых API (Ollama, LM Studio, vLLM) используйте `"tooluse"`.

### Формат transformer.use

Простой список:
```json
{ "use": ["deepseek"] }
```

С параметрами (tuple-формат):
```json
{
  "use": [
    "deepseek",
    ["maxtoken", {"max_tokens": 30000}],
    ["openrouter", {"provider": {"only": ["moonshotai/fp8"]}}]
  ]
}
```

Без трансформера (Ollama, стандартный OpenAI):
```json
{ "use": ["tooluse"] }
```

---

## Router — слоты маршрутизации

Объект `Router` определяет какой провайдер/модель использовать для каждого типа запроса.

### Поддерживаемые слоты (подтверждено из `dist/cli.js`, строки 907–912)

```javascript
console.log(`Default Model:`),    console.log(Router.default)
e.Router.background  && console.log(`Background Model:`,  Router.background)
e.Router.think       && console.log(`Think Model:`,        Router.think)
e.Router.longContext && console.log(`Long Context Model:`, Router.longContext)
e.Router.webSearch   && console.log(`Web Search Model:`,   Router.webSearch)
e.Router.image       && console.log(`Image Model:`,        Router.image)
```

| Слот | Тип | Обязательный | Описание |
|------|-----|:------------:|----------|
| `default` | string | **да** | Fallback для всех запросов без специального слота |
| `background` | string | нет | Фоновые задачи (sub-agents с `model: haiku`) |
| `think` | string | нет | Plan Mode и reasoning-heavy задачи |
| `longContext` | string | нет | Запросы превышающие `longContextThreshold` токенов |
| `longContextThreshold` | number | нет | Порог токенов для longContext (по умолчанию: `60000`) |
| `webSearch` | string | нет | Запросы с web search инструментами |
| `image` | string | нет | Запросы с изображениями / vision-задачи |

### Условия выбора слота (порядок приоритетов)

```
1. longContext  → input_tokens > longContextThreshold
2. think        → Plan Mode / extended thinking запросы
3. background   → sub-agents с model: haiku (содержит "claude" AND "haiku")
4. webSearch    → запросы с web_search инструментом
5. image        → запросы с изображениями
6. default      → все остальные запросы
```

### Router.longContextThreshold

```json
"Router": {
  "longContext": "deepseek,deepseek-chat",
  "longContextThreshold": 60000
}
```

Если `input_tokens` превышает порог — запрос идёт в `longContext` слот. Полезно для направления длинных контекстов на модель с большим контекстным окном.

---

## Маршрутизация sub-agents

### Как model: haiku попадает в background слот

1. В `AGENT.md` агента задан `model: haiku`
2. Claude Code резолвит `haiku` → `claude-haiku-4-5-20251001`
3. CCR проверяет: строка содержит `"claude"` **И** `"haiku"`
4. CCR направляет в `Router.background`

```
AGENT.md (model: haiku)
    └─→ Claude Code резолвит → "claude-haiku-4-5-20251001"
                                    └─→ CCR: contains "haiku"? → Router.background
                                                                       └─→ Ollama / DeepSeek
```

### Текущая конфигурация агентов пайплайна

| Агент | model (AGENT.md) | CCR слот | Провайдер |
|-------|-----------------|----------|-----------|
| `researcher-agent` | `haiku` | `background` | Ollama `qwen2.5-coder:7b` |
| `planning-agent` | `haiku` | `background` | Ollama `qwen2.5-coder:7b` |
| `critic-agent` | `sonnet` | `default` | DeepSeek `deepseek-chat` |
| `execution-agent` | `sonnet` | `default` | DeepSeek `deepseek-chat` |

### CCR-SUBAGENT-MODEL — per-request override

Можно вставить тег в системный промпт агента для явного указания модели:

```
<CCR-SUBAGENT-MODEL>openrouter,anthropic/claude-3.5-sonnet</CCR-SUBAGENT-MODEL>
```

Это переопределяет слот маршрутизации для конкретного вызова.

### Глобальный override через env var

```bash
# Все sub-agents будут использовать haiku → Router.background
CLAUDE_CODE_SUBAGENT_MODEL=haiku ./iclaude.sh --router
```

---

## Внешние модели через Ollama

### Что нужно для работы

```bash
# 1. Установить Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# 2. Загрузить модель
ollama pull qwen2.5-coder:7b

# 3. Убедиться что API работает
curl http://localhost:11434/v1/models
```

### Конфигурация в router.json

```json
{
  "name": "ollama",
  "api_base_url": "http://localhost:11434/v1",
  "api_key": "ollama",
  "models": ["qwen2.5-coder:7b", "llama3.1:8b"],
  "transformer": {
    "use": ["tooluse"]
  }
}
```

- `api_key: "ollama"` — Ollama не требует ключа, но поле обязательно
- `transformer.use: ["tooluse"]` — обеспечивает совместимость tool calls через OpenAI-compatible API
- **Не использовать** `"openai"` в `use` — такого трансформера не существует

### Выбор модели Ollama для фоновых агентов

| Модель | Размер | VRAM | Подходит для |
|--------|--------|------|-------------|
| `qwen2.5-coder:1.5b` | 1.0 GB | 2 GB | Минимальные ресурсы, простые задачи |
| `qwen2.5-coder:7b` | 4.7 GB | 6 GB | Хорошее качество, рекомендуется |
| `llama3.1:8b` | 4.9 GB | 6 GB | Универсальная альтернатива |
| `qwen2.5-coder:14b` | 9.0 GB | 12 GB | Высокое качество |

### Переключение background на Ollama

В текущем `router.json` background уже направлен на Ollama. Чтобы вернуть на DeepSeek:

```json
"Router": {
  "default": "deepseek,deepseek-chat",
  "background": "deepseek,deepseek-chat"
}
```

---

## Примеры конфигурации

### Текущая конфигурация проекта

```json
{
  "PORT": 3456,
  "PROXY_URL": "https://...",
  "LOG": true,
  "LOG_LEVEL": "debug",
  "API_TIMEOUT_MS": 600000,
  "Providers": [
    {
      "name": "deepseek",
      "api_base_url": "https://...",
      "api_key": "...",
      "models": ["deepseek-chat"],
      "transformer": { "use": ["deepseek"] }
    },
    {
      "name": "ollama",
      "api_base_url": "http://localhost:11434/v1",
      "api_key": "ollama",
      "models": ["qwen2.5-coder:7b", "llama3.1:8b", "mistral:7b"],
      "transformer": { "use": ["tooluse"] }
    }
  ],
  "Router": {
    "default": "deepseek,deepseek-chat",
    "background": "ollama,qwen2.5-coder:7b",
    "think": "deepseek,deepseek-chat",
    "longContext": "deepseek,deepseek-chat",
    "longContextThreshold": 60000
  }
}
```

### Максимальная конфигурация — все слоты

```json
{
  "PORT": 3456,
  "HOST": "127.0.0.1",
  "LOG": true,
  "LOG_LEVEL": "info",
  "API_TIMEOUT_MS": 60000,
  "Providers": [
    {
      "name": "deepseek",
      "api_base_url": "https://api.deepseek.com/v1/chat/completions",
      "api_key": "${DEEPSEEK_API_KEY}",
      "models": ["deepseek-chat"],
      "transformer": { "use": ["deepseek", "reasoning"] }
    },
    {
      "name": "openrouter",
      "api_base_url": "https://openrouter.ai/api/v1/chat/completions",
      "api_key": "${OPENROUTER_API_KEY}",
      "models": ["perplexity/sonar", "openai/gpt-4o", "anthropic/claude-3.5-sonnet"],
      "transformer": {
        "use": [["openrouter", {"provider": {"only": ["openai"]}}]]
      }
    },
    {
      "name": "ollama",
      "api_base_url": "http://localhost:11434/v1",
      "api_key": "ollama",
      "models": ["qwen2.5-coder:7b"],
      "transformer": { "use": ["tooluse"] }
    }
  ],
  "Router": {
    "default": "deepseek,deepseek-chat",
    "background": "ollama,qwen2.5-coder:7b",
    "think": "deepseek,deepseek-chat",
    "longContext": "deepseek,deepseek-chat",
    "longContextThreshold": 60000,
    "webSearch": "openrouter,perplexity/sonar",
    "image": "openrouter,openai/gpt-4o"
  }
}
```

### Полный Ollama (без внешних API)

```json
{
  "PORT": 3456,
  "API_TIMEOUT_MS": 1200000,
  "Providers": [
    {
      "name": "ollama",
      "api_base_url": "http://localhost:11434/v1",
      "api_key": "ollama",
      "models": ["qwen2.5-coder:14b", "qwen2.5-coder:7b"],
      "transformer": { "use": ["tooluse"] }
    }
  ],
  "Router": {
    "default": "ollama,qwen2.5-coder:14b",
    "background": "ollama,qwen2.5-coder:7b"
  }
}
```

---

## Custom Router

CCR поддерживает JavaScript-файл для кастомной логики маршрутизации.

**Расположение:** `~/.claude-code-router/custom-router.js`

```javascript
module.exports = async function router(req, config) {
  const messages = req.body.messages;
  const lastMessage = messages[messages.length - 1]?.content;

  // Направить код-задачи на специализированную модель
  if (typeof lastMessage === "string" && lastMessage.includes("```")) {
    return "deepseek,deepseek-chat";
  }

  // Fallback → стандартная маршрутизация
  return null;
};
```

**Параметры функции:**
- `req` — входящий запрос от Claude Code (`req.body.messages` — массив сообщений)
- `config` — объект конфигурации из `config.json`

**Возвращаемое значение:**
- `"provider,model"` — явное указание провайдера/модели
- `null` — использовать стандартную маршрутизацию по слотам

### Динамическое переключение модели

Во время активной сессии Claude Code через CCR доступна команда:

```
/model provider_name,model_name
```

Пример:
```
/model deepseek,deepseek-chat
/model ollama,qwen2.5-coder:7b
```

---

## Диагностика

### Проверить статус Router

```bash
./iclaude.sh --check-router
```

### Посмотреть текущую конфигурацию

```bash
cat .nvm-isolated/.claude-isolated/router.json | python3 -m json.tool
```

### Проверить что CCR слушает

```bash
curl http://localhost:3456/
```

### Включить debug-логи

```json
{ "LOG": true, "LOG_LEVEL": "debug" }
```

Логи покажут: входящий model ID, выбранный слот, провайдера, HTTP-статус ответа.

### Типичные проблемы

#### Агент не попадает в background слот

Проверить что значение в `AGENT.md` — алиас, а не полный ID:
```yaml
model: haiku           # ✅ резолвится в claude-haiku-4-5-20251001
model: claude-haiku-4-5-20251001  # ❌ молча игнорируется Claude Code
```

#### Ошибка "transformer not found" или некорректные запросы

Проверить что трансформер из валидного списка. Для OpenAI-compatible API (Ollama):
```json
{ "use": ["tooluse"] }   # ✅
{ "use": ["openai"] }    # ❌ "openai" не существует
{ "use": [] }            # ✅ без трансформации
```

#### Ollama не отвечает

```bash
systemctl status ollama
curl http://localhost:11434/v1/models
ollama list
```

Увеличить таймаут если Ollama на CPU:
```json
{ "API_TIMEOUT_MS": 1200000 }
```

#### config.json не обновляется

iclaude копирует `router.json` в `~/.claude-code-router/config.json` при каждом `--router` запуске. Если файл не обновляется — проверить путь:
```bash
cat ~/.claude-code-router/config.json
```

---

*Документ основан на анализе исходного кода @musistudio/claude-code-router v2.0.0 (`dist/cli.js`).*
*Все утверждения подтверждены реальными строками кода.*
