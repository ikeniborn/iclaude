# Claude Code Router: конфигурация и маршрутизация

> Документация на основе официальных источников:
> — CCR README (@musistudio/claude-code-router v2.0.0, включён в npm-пакет)
> — Anthropic Official Docs (code.claude.com/docs/en/sub-agents)
>
> Дата: 2026-02-24 | CCR: v2.0.0

---

## Содержание

- [Как iclaude использует Router](#как-iclaude-использует-router)
- [Параметры верхнего уровня](#параметры-верхнего-уровня)
- [Providers — провайдеры моделей](#providers--провайдеры-моделей)
- [Transformer — трансформеры](#transformer--трансформеры)
- [Router — слоты маршрутизации](#router--слоты-маршрутизации)
- [model в AGENT.md — официальная спецификация](#model-в-agentmd--официальная-спецификация)
- [Маршрутизация sub-agents](#маршрутизация-sub-agents)
- [Внешние модели через Ollama](#внешние-модели-через-ollama)
- [Custom Router](#custom-router)
- [Примеры конфигурации](#примеры-конфигурации)
- [Диагностика](#диагностика)

---

## Как iclaude использует Router

```
1. ./iclaude.sh --router
2. launcher/launch.sh читает:
     .nvm-isolated/.claude-isolated/router.json
3. Копирует в:
     ~/.claude-code-router/config.json
4. Запускает: ccr code [args]
5. CCR слушает на PORT (3456) и проксирует запросы Claude Code
```

> Редактировать нужно `.nvm-isolated/.claude-isolated/router.json` —
> iclaude копирует его в `~/.claude-code-router/config.json` при каждом старте с `--router`.

### Важно: схема конфига (CCR v2.0.0)

Актуальная схема `router.json` использует **массив `Providers`** (с заглавной буквы) и объект **`Router`** со слотами. Это формат CCR v2.0.0, подтверждённый официальным README пакета.

Старая схема (встречалась в ранних версиях iclaude) **несовместима** с текущим CCR:

| Схема | Формат | Совместимость |
|-------|--------|:-------------:|
| **Актуальная (v2.0.0)** | `"Providers": [...]`, `"Router": {...}` | ✅ |
| Устаревшая | `"providers": {...}`, `"routing": {...}`, `"models": {...}` | ❌ |

Файл `router.json.example` обновлён до актуальной схемы.

---

## Жизненный цикл CCR-сервера

### Архитектура процессов

`ccr code` — не демон, а менеджер сессии. При запуске `./iclaude.sh --router` происходит следующее:

```
iclaude.sh
  └─ exec ccr code          ← iclaude-процесс заменяется (exec, не spawn)
       │
       ├─ проверить PID-файл (~/.claude-code-router/*.pid)
       │
       ├─ [сервер НЕ запущен]:
       │   spawn("node cli.js start", {detached:true, stdio:"ignore"})
       │   .unref()          ← CCR-сервер уходит в фон как демон
       │   ждать порт 3456 (timeout)
       │
       └─ spawn("claude", [...], {
              env: { ANTHROPIC_BASE_URL: "http://127.0.0.1:3456",
                     ANTHROPIC_AUTH_TOKEN: "test", ... },
              stdio: "inherit"
          })
          on("close") → J0() → sC() → process.exit()
```

После старта существуют два отдельных процесса:

| Процесс | PID-файл | Роль | Живёт пока |
|---------|----------|------|-----------|
| `node cli.js start` | `~/.claude-code-router/.claude-code-router.pid` | CCR HTTP-сервер на `:3456` | есть активные сессии |
| `ccr code` | — (родитель `claude`) | менеджер сессии + счётчик | работает `claude` |

### Автоматическая остановка через reference counting

CCR-сервер самоуправляемый — iclaude не участвует в его остановке (после `exec` iclaude-процесса нет):

```
ccr code запускается  → rC(): счётчик +1  (/tmp/claude-code-reference-count.txt)
claude завершается    → J0(): счётчик -1
                      → sC(): если счётчик == 0 → SIGTERM к CCR-серверу
```

Несколько параллельных `--router` сессий используют **один общий сервер** — последняя закрывающаяся сессия его гасит.

### Сценарии завершения

| Ситуация | Что происходит с CCR-сервером |
|----------|-------------------------------|
| Нормальный выход (`:q`, Ctrl+C) | `ccr code` останавливает сервер автоматически |
| `kill -9 claude` (SIGKILL дочернего) | `ccr code` получает `close` event → очистка запускается → сервер останавливается |
| Два параллельных сеанса, первый вышел | Сервер живёт (счётчик 2→1) |
| Два параллельных, оба вышли | Сервер останавливается (счётчик 1→0) |
| `kill -9 <ccr code>` (SIGKILL менеджера) | `J0()`/`sC()` не вызываются → **сервер остаётся висеть** |
| Crash до `exec` в iclaude | `ccr code` не запустился → сервер не стартовал |

### Ручная очистка

Если CCR-сервер завис после kill/crash:

```bash
# Через CLI
ccr stop

# Вручную
kill $(cat ~/.claude-code-router/.claude-code-router.pid)
rm ~/.claude-code-router/.claude-code-router.pid
rm -f /tmp/claude-code-reference-count.txt

# Проверить статус
ccr status
./iclaude.sh --check-router
```

---

## Параметры верхнего уровня

*Источник: официальный README CCR*

| Параметр | Тип | Обязательный | По умолчанию | Описание |
|----------|-----|:------------:|:------------:|----------|
| `PORT` | number | нет | `3456` | Порт локального CCR-сервера |
| `HOST` | string | нет | `127.0.0.1` | Хост. Принудительно `127.0.0.1` если `APIKEY` не задан |
| `APIKEY` | string | нет | — | Секретный ключ для аутентификации клиентов. Передаётся в заголовке `Authorization: Bearer <key>` или `x-api-key` |
| `LOG` | boolean | нет | `true` | Включить запись лог-файлов в `~/.claude-code-router/logs/` |
| `LOG_LEVEL` | string | нет | `"debug"` | Уровень лога: `fatal` `error` `warn` `info` `debug` `trace` |
| `API_TIMEOUT_MS` | number | нет | — | Таймаут запросов к провайдерам в миллисекундах |
| `PROXY_URL` | string | нет | — | Прокси для всех запросов к внешним провайдерам. Формат: `http://user:pass@host:port` |
| `NON_INTERACTIVE_MODE` | boolean | нет | `false` | Режим CI/CD: устанавливает `CI=true`, `FORCE_COLOR=0`, корректно управляет stdin. Обязателен в GitHub Actions, Docker |
| `CUSTOM_ROUTER_PATH` | string | нет | — | Абсолютный путь к JS-файлу кастомной логики маршрутизации |
| `transformers` | array | нет | — | Массив путей к custom transformer плагинам |
| `Providers` | array | **да** | — | Список провайдеров моделей |
| `Router` | object | **да** | — | Правила маршрутизации по слотам |

### Два типа логов

CCR ведёт два независимых лога:
- **Server-level**: HTTP-запросы и API-вызовы → `~/.claude-code-router/logs/ccr-*.log` (через pino)
- **Application-level**: решения маршрутизации → `~/.claude-code-router/claude-code-router.log`

### PROXY_URL

Применяется ко всем запросам CCR к внешним провайдерам. iclaude также передаёт `HTTPS_PROXY`/`HTTP_PROXY` из окружения. Для localhost-провайдеров (Ollama) прокси не нужен — `localhost` всегда в `NO_PROXY`.

### Переменные окружения в значениях

CCR поддерживает `$VAR` и `${VAR}` в любых строковых полях конфига:

```json
{
  "api_key": "${DEEPSEEK_API_KEY}",
  "PROXY_URL": "$HTTPS_PROXY"
}
```

Интерполяция работает рекурсивно через все вложенные объекты и массивы.

---

## Providers — провайдеры моделей

*Источник: официальный README CCR*

### Поля провайдера

| Поле | Тип | Обязательное | Описание |
|------|-----|:------------:|----------|
| `name` | string | **да** | Уникальный идентификатор (используется в ключах Router) |
| `api_base_url` | string | **да** | Полный URL эндпоинта для chat completions |
| `api_key` | string | **да** | API ключ. Поддерживает `${ENV_VAR}` |
| `models` | string[] | **да** | Список имён доступных моделей |
| `transformer` | object | нет | Глобальные и per-model трансформеры |

### Формат ссылки на провайдера

В полях Router используется строка `"provider_name,model_name"`:

```json
"Router": {
  "default": "deepseek,deepseek-chat",
  "background": "ollama,qwen2.5-coder:7b"
}
```

---

## Transformer — трансформеры

*Источник: официальный README CCR*

Трансформеры преобразуют запросы Anthropic API ↔ формат конкретного провайдера.

### Встроенные трансформеры

| Трансформер | Назначение |
|-------------|-----------|
| `anthropic` | Сохраняет оригинальные параметры запроса/ответа. Для прямого подключения к Anthropic-эндпоинту |
| `deepseek` | Адаптация запросов/ответов для DeepSeek API |
| `gemini` | Адаптация для Google Gemini API |
| `openrouter` | Адаптация для OpenRouter + поддержка `provider` routing |
| `groq` | Адаптация для Groq API |
| `maxtoken` | Устанавливает конкретное значение `max_tokens` |
| `tooluse` | Оптимизирует вызовы инструментов через `tool_choice` |
| `reasoning` | Обрабатывает поле `reasoning_content` |
| `sampling` | Обрабатывает параметры сэмплирования: `temperature`, `top_p`, `top_k`, `repetition_penalty` |
| `enhancetool` | Добавляет слой толерантности к ошибкам в параметрах tool call (отключает стриминг tool calls) |
| `cleancache` | Очищает поле `cache_control` из запросов |
| `vertex-gemini` | Gemini API через Vertex AI аутентификацию |
| `gemini-cli` | Неофициальная поддержка Gemini через Gemini CLI (experimental) |
| `chutes-glm` | Неофициальная поддержка GLM 4.5 через Chutes (experimental) |
| `qwen-cli` | Неофициальная поддержка qwen3-coder-plus через Qwen CLI (experimental) |
| `rovo-cli` | Неофициальная поддержка GPT-5 через Atlassian Rovo Dev CLI (experimental) |

### Форматы transformer.use

**Глобальный трансформер** — применяется ко всем моделям провайдера:

```json
{
  "name": "deepseek",
  "transformer": {
    "use": ["deepseek"]
  }
}
```

**Per-model трансформер** — применяется к конкретной модели дополнительно:

```json
{
  "name": "deepseek",
  "transformer": {
    "use": ["deepseek"],
    "deepseek-chat": {
      "use": ["tooluse"]
    }
  }
}
```

**Трансформер с параметрами** (tuple-формат):

```json
{
  "name": "modelscope",
  "transformer": {
    "use": [
      ["maxtoken", {"max_tokens": 65536}],
      "enhancetool"
    ],
    "Qwen/Qwen3-235B-A22B-Thinking-2507": {
      "use": ["reasoning"]
    }
  }
}
```

**OpenRouter с provider routing**:

```json
{
  "name": "openrouter",
  "transformer": {
    "use": ["openrouter"],
    "moonshotai/kimi-k2": {
      "use": [["openrouter", {"provider": {"only": ["moonshotai/fp8"]}}]]
    }
  }
}
```

**Для OpenAI-compatible API (Ollama, LM Studio, vLLM)** — трансформер не нужен:

```json
{
  "name": "ollama",
  "api_base_url": "http://localhost:11434/v1/chat/completions",
  "api_key": "ollama",
  "models": ["qwen2.5-coder:latest"]
}
```

### Custom Transformer плагины

```json
{
  "transformers": [
    {
      "path": "/absolute/path/to/my-transformer.js",
      "options": {
        "project": "my-project"
      }
    }
  ]
}
```

---

## Router — слоты маршрутизации

*Источник: официальный README CCR*

### Поддерживаемые слоты

| Слот | Обязательный | Описание |
|------|:------------:|----------|
| `default` | **да** | Основная модель для всех запросов без специального слота |
| `background` | нет | Фоновые задачи. Рекомендуется локальная или дешёвая модель |
| `think` | нет | Reasoning-heavy задачи, Plan Mode |
| `longContext` | нет | Запросы с числом токенов > `longContextThreshold` |
| `longContextThreshold` | нет | Порог токенов для `longContext`. **По умолчанию: 60000** |
| `webSearch` | нет | Запросы с web search. Модель должна поддерживать поиск. Для OpenRouter добавлять суффикс `:online` к имени модели |
| `image` | нет | Задачи с изображениями (beta). Если модель не поддерживает tool calling — установить `forceUseImageAgent: true` |

### Динамическое переключение модели

Во время активной сессии:

```
/model provider_name,model_name
/model deepseek,deepseek-chat
/model ollama,qwen2.5-coder:7b
```

---

## model в AGENT.md — официальная спецификация

*Источник: Anthropic Official Docs (code.claude.com/docs/en/sub-agents)*

### Полный список frontmatter полей

| Поле | Обязательное | Описание |
|------|:------------:|----------|
| `name` | **да** | Уникальный идентификатор (строчные буквы и дефисы) |
| `description` | **да** | Когда Claude делегирует задачи этому агенту |
| `tools` | нет | Список разрешённых инструментов. Если не задан — наследует все |
| `disallowedTools` | нет | Список запрещённых инструментов |
| `model` | нет | Модель агента (см. допустимые значения ниже). По умолчанию: `inherit` |
| `permissionMode` | нет | `default` / `acceptEdits` / `dontAsk` / `bypassPermissions` / `plan` |
| `maxTurns` | нет | Максимальное число agentic turns |
| `skills` | нет | Скиллы, инжектируемые в контекст агента при старте |
| `mcpServers` | нет | MCP серверы доступные агенту |
| `hooks` | нет | Lifecycle hooks агента |
| `memory` | нет | Persistent memory: `user` / `project` / `local` |
| `background` | нет | `true` — всегда запускать агент в фоне |
| `isolation` | нет | `worktree` — запускать в изолированном git worktree |

### Допустимые значения model

```yaml
model: sonnet    # claude-sonnet (последняя версия)
model: opus      # claude-opus (последняя версия)
model: haiku     # claude-haiku (последняя версия)
model: inherit   # наследует модель родительской сессии (по умолчанию)
```

> Полные model ID типа `claude-haiku-4-5-20251001` в поле `model` **молча игнорируются** — агент переходит в режим `inherit`. Использовать только алиасы.

### Текущая конфигурация агентов пайплайна

| Агент | `model` | CCR слот при `--router` | Обоснование |
|-------|---------|------------------------|-------------|
| `researcher-agent` | `haiku` | `background` → Ollama | READ-ONLY поиск, maxTurns=60, нужна скорость |
| `planning-agent` | `haiku` | `background` → Ollama | Структурированная трансляция, maxTurns=25 |
| `critic-agent` | `sonnet` | `default` → DeepSeek | Сложный scoring по рубрикам, требует точности |
| `execution-agent` | `sonnet` | `default` → DeepSeek | Редактирование кода, git, recovery |
| `deep-research-agent` | `opus` | `default` → DeepSeek | Глубокое веб-исследование, максимальное качество |

---

## Маршрутизация sub-agents

### Как model: haiku попадает в background слот

```
AGENT.md (model: haiku)
    └─→ Claude Code резолвит → "claude-haiku-4-5-20251001"
                                    └─→ CCR: содержит "claude" AND "haiku"?
                                               └─→ да → Router.background → Ollama
```

### CCR-SUBAGENT-MODEL — per-request override

Вставить тег в начало промпта агента для явного указания модели (*источник: официальный README CCR*):

```
<CCR-SUBAGENT-MODEL>openrouter,anthropic/claude-3.5-sonnet</CCR-SUBAGENT-MODEL>
Помоги проанализировать этот код...
```

Переопределяет слот маршрутизации для конкретного вызова.

### Глобальный override через env var

```bash
# Все sub-agents принудительно → haiku → Router.background
CLAUDE_CODE_SUBAGENT_MODEL=haiku ./iclaude.sh --router
```

---

## Внешние модели через Ollama

### Установка

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

### Конфигурация в router.json

```json
{
  "name": "ollama",
  "api_base_url": "http://localhost:11434/v1/chat/completions",
  "api_key": "ollama",
  "models": ["qwen2.5-coder:7b", "llama3.1:8b", "mistral:7b"]
}
```

- `api_base_url` — обязательно полный путь `/v1/chat/completions`
- `api_key` — Ollama не требует ключа, но поле обязательно; используем `"ollama"`
- `transformer` — **не нужен** для Ollama (OpenAI-compatible API нативно)

### Выбор модели

| Модель | Размер | VRAM | Рекомендуется для |
|--------|--------|------|-------------------|
| `qwen2.5-coder:1.5b` | 1.0 GB | 2 GB | Минимальные ресурсы |
| `qwen2.5-coder:7b` | 4.7 GB | 6 GB | Фоновые агенты (оптимальный баланс) |
| `llama3.1:8b` | 4.9 GB | 6 GB | Универсальная альтернатива |
| `qwen2.5-coder:14b` | 9.0 GB | 12 GB | Высокое качество |

### Активация background → Ollama

В текущем `router.json` background уже направлен на Ollama. Чтобы вернуть на DeepSeek:

```json
"Router": {
  "background": "deepseek,deepseek-chat"
}
```

---

## Custom Router

*Источник: официальный README CCR*

### Конфигурация

Путь задаётся через `CUSTOM_ROUTER_PATH` в `config.json` (не через фиксированный путь):

```json
{
  "CUSTOM_ROUTER_PATH": "/home/user/.claude-code-router/custom-router.js"
}
```

### Формат файла

```javascript
// custom-router.js
module.exports = async function router(req, config) {
  const messages = req.body.messages;
  const lastMsg = messages.find(m => m.role === "user")?.content;

  // Направить code-задачи на специализированную модель
  if (typeof lastMsg === "string" && lastMsg.includes("explain this code")) {
    return "openrouter,anthropic/claude-3.5-sonnet";
  }

  // null → стандартная маршрутизация по слотам
  return null;
};
```

**Параметры:**
- `req.body.messages` — массив сообщений от Claude Code
- `config` — объект конфигурации из `config.json`
- Возврат `"provider,model"` — явное указание модели
- Возврат `null` — использовать стандартные слоты

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
      "transformer": {
        "use": ["deepseek"],
        "deepseek-chat": {
          "use": ["tooluse"]
        }
      }
    },
    {
      "name": "ollama",
      "api_base_url": "http://localhost:11434/v1/chat/completions",
      "api_key": "ollama",
      "models": ["qwen2.5-coder:7b", "llama3.1:8b", "mistral:7b"]
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

### Все слоты + OpenRouter

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
      "api_base_url": "https://api.deepseek.com/chat/completions",
      "api_key": "${DEEPSEEK_API_KEY}",
      "models": ["deepseek-chat", "deepseek-reasoner"],
      "transformer": {
        "use": ["deepseek"],
        "deepseek-chat": { "use": ["tooluse"] }
      }
    },
    {
      "name": "openrouter",
      "api_base_url": "https://openrouter.ai/api/v1/chat/completions",
      "api_key": "${OPENROUTER_API_KEY}",
      "models": [
        "google/gemini-2.5-pro-preview",
        "anthropic/claude-3.5-sonnet",
        "perplexity/sonar-online"
      ],
      "transformer": { "use": ["openrouter"] }
    },
    {
      "name": "ollama",
      "api_base_url": "http://localhost:11434/v1/chat/completions",
      "api_key": "ollama",
      "models": ["qwen2.5-coder:7b"]
    }
  ],
  "Router": {
    "default": "deepseek,deepseek-chat",
    "background": "ollama,qwen2.5-coder:7b",
    "think": "deepseek,deepseek-reasoner",
    "longContext": "openrouter,google/gemini-2.5-pro-preview",
    "longContextThreshold": 60000,
    "webSearch": "openrouter,perplexity/sonar-online",
    "image": "openrouter,openai/gpt-4o"
  }
}
```

### GitHub Actions / CI

```json
{
  "LOG": true,
  "NON_INTERACTIVE_MODE": true,
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
    "default": "deepseek,deepseek-chat"
  }
}
```

---

## Диагностика

### Команды

```bash
# Статус Router
./iclaude.sh --check-router

# Проверить конфиг
cat .nvm-isolated/.claude-isolated/router.json | python3 -m json.tool

# Что CCR скопировал в рабочее место
cat ~/.claude-code-router/config.json

# Управление через CLI (без запуска Claude)
ccr model

# Web UI для редактирования конфига
ccr ui

# Сохранить текущий конфиг как пресет
ccr preset export my-config
```

### Типичные проблемы

#### Агент не попадает в нужный слот

```yaml
model: haiku           # ✅ корректный алиас
model: claude-haiku-4-5-20251001  # ❌ полный ID — молча игнорируется
```

#### Ollama не отвечает

```bash
systemctl status ollama
curl http://localhost:11434/v1/chat/completions \
  -d '{"model":"qwen2.5-coder:7b","messages":[{"role":"user","content":"hi"}]}'
ollama list
```

Увеличить таймаут для Ollama на CPU:
```json
{ "API_TIMEOUT_MS": 1200000 }
```

#### Конфиг не подхватывается CCR

iclaude копирует `router.json` в `~/.claude-code-router/config.json` при каждом запуске `--router`. Проверить:
```bash
cat ~/.claude-code-router/config.json
```

Если нужно применить изменения без перезапуска iclaude:
```bash
cp .nvm-isolated/.claude-isolated/router.json ~/.claude-code-router/config.json
ccr restart
```

#### LOG_LEVEL debug создаёт большие лог-файлы

В продакшене использовать `"info"` или `"warn"`. Debug-логи в:
```bash
~/.claude-code-router/logs/ccr-*.log
~/.claude-code-router/claude-code-router.log
```

#### `--check-router` показывает пустые провайдеры

Было исправлено в `lib/router/status.sh`: старые jq-запросы (`.providers | keys[]`, `.routing.default`) заменены на актуальные (`.Providers[].name`, `.Router.default`). Если проблема осталась — убедиться что установлена актуальная версия iclaude.

---

*Основано на: CCR README v2.0.0 (включён в npm-пакет) + Anthropic Official Docs (code.claude.com/docs/en/sub-agents, 2026-02-25)*
