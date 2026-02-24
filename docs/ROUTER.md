# Claude Code Router: маршрутизация и внешние модели

> Руководство по настройке Claude Code Router (CCR) для работы с альтернативными LLM-провайдерами.
> Особый фокус — маршрутизация sub-agents по слотам и подключение внешних моделей (Ollama, DeepSeek, OpenRouter).
>
> Дата: 2026-02-24 | Версия: 4.0

---

## Содержание

- [Быстрый старт](#быстрый-старт)
- [Как работает маршрутизация](#как-работает-маршрутизация)
- [Слоты Router и модели агентов](#слоты-router-и-модели-агентов)
- [Внешние модели через Ollama](#внешние-модели-через-ollama)
- [Конфигурация router.json](#конфигурация-routerjson)
- [Провайдеры](#провайдеры)
- [Переменные окружения](#переменные-окружения)
- [Диагностика](#диагностика)

---

## Быстрый старт

```bash
# Установить Router
./iclaude.sh --install-router

# Проверить статус
./iclaude.sh --check-router

# Запустить через Router
./iclaude.sh --router
```

**По умолчанию Router отключён.** Флаг `--router` — opt-in.

---

## Как работает маршрутизация

CCR Router перехватывает HTTP-запросы от Claude Code к Anthropic API и перенаправляет их к настроенным провайдерам по правилам из `router.json`.

```
Claude Code
    │
    ▼
CCR Router (порт 3456)
    │
    ├── haiku-модель → Router.background → Ollama / DeepSeek
    ├── web_search → Router.webSearch → провайдер с поиском
    ├── thinking → Router.think → провайдер с reasoning
    └── всё остальное → Router.default → DeepSeek / OpenRouter
```

### Правила маршрутизации (приоритет)

| Условие | Слот | Описание |
|---------|------|----------|
| model содержит `haiku` | `Router.background` | Лёгкие фоновые задачи |
| запрос использует `web_search` tools | `Router.webSearch` | Провайдер с веб-поиском |
| запрос содержит `thinking` блок | `Router.think` | Провайдер с extended thinking |
| всё остальное | `Router.default` | Основной провайдер |

---

## Слоты Router и модели агентов

### Фиксация модели в AGENT.md

Claude Code v2.1.51+ поддерживает поле `model` в YAML-фронтматтере агента.

**Допустимые значения** (только алиасы, полные ID молча игнорируются):

```
haiku | sonnet | opus | best | sonnet[1m] | opus[1m] | opusplan | inherit
```

**Пример frontmatter:**

```yaml
---
name: researcher-agent
description: Агент-исследователь кодовой базы
tools: Glob, Grep, Read, Write, Task
maxTurns: 60
model: haiku
---
```

### Текущая конфигурация агентов пайплайна

| Агент | Модель | Слот CCR | Обоснование |
|-------|--------|----------|-------------|
| `researcher-agent` | `haiku` | `Router.background` | READ-ONLY поиск, maxTurns=60, нужна скорость |
| `planning-agent` | `haiku` | `Router.background` | Структурированная трансляция по шаблону, maxTurns=25 |
| `critic-agent` | `sonnet` | `Router.default` | Сложный scoring по рубрикам, требует точности |
| `execution-agent` | `sonnet` | `Router.default` | Редактирование кода, git, recovery protocol |

### Как CCR определяет слот агента

CCR читает поле `model` из запроса. Когда агент объявлен с `model: haiku`:

1. Claude Code резолвит алиас `haiku` → `claude-haiku-4-5-20251001`
2. CCR видит модель содержащую `"claude"` AND `"haiku"`
3. CCR выбирает `Router.background` провайдер

```
agent (model: haiku)
    │
    └─→ Claude Code → "claude-haiku-4-5-20251001"
                           │
                           └─→ CCR → Router.background → провайдер
```

### Приоритет выбора модели

```
1. CLAUDE_CODE_SUBAGENT_MODEL (env var)  ← глобальный override
2. --model флаг при вызове Task()
3. AGENT.md frontmatter.model            ← фиксация на уровне агента
4. inherit                               ← наследует модель родителя
```

---

## Внешние модели через Ollama

### Подключение Ollama

Ollama предоставляет OpenAI-совместимый API на `http://localhost:11434/v1`.

**Шаг 1: Запустить Ollama и загрузить модель**

```bash
# Установить Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Загрузить модель для кода (рекомендуется для background-агентов)
ollama pull qwen2.5-coder:7b

# Или лёгкую универсальную модель
ollama pull llama3.1:8b

# Проверить
ollama list
curl http://localhost:11434/v1/models
```

**Шаг 2: Переключить `Router.background` на Ollama**

В файле `.nvm-isolated/.claude-isolated/router.json`:

```json
{
  "Router": {
    "default": "deepseek,deepseek-chat",
    "background": "ollama,qwen2.5-coder:7b"
  }
}
```

Теперь `researcher-agent` и `planning-agent` (с `model: haiku`) будут работать через локальную Ollama.

### Выбор модели Ollama

| Задача агента | Рекомендуемая модель | Размер | VRAM |
|---------------|----------------------|--------|------|
| Поиск и индексация (researcher) | `qwen2.5-coder:7b` | 4.7 GB | 6 GB |
| Планирование по шаблону (planner) | `qwen2.5-coder:7b` | 4.7 GB | 6 GB |
| Лёгкая альтернатива | `llama3.1:8b` | 4.9 GB | 6 GB |
| Минимальные ресурсы | `qwen2.5-coder:1.5b` | 1.0 GB | 2 GB |

### Ollama через proxy

Если iclaude работает с прокси, Ollama (localhost) нужно добавить в NO_PROXY:

```bash
# Это уже настроено в iclaude.sh по умолчанию:
NO_PROXY="localhost,127.0.0.1,..."
```

CCR Router работает через прокси для внешних провайдеров и напрямую для localhost.

---

## Конфигурация router.json

Файл: `.nvm-isolated/.claude-isolated/router.json`

### Полный пример — DeepSeek + Ollama

```json
{
  "PORT": 3456,
  "LOG": true,
  "LOG_LEVEL": "info",
  "API_TIMEOUT_MS": 600000,
  "Providers": [
    {
      "name": "deepseek",
      "api_base_url": "https://api.deepseek.com/v1/chat/completions",
      "api_key": "${DEEPSEEK_API_KEY}",
      "models": ["deepseek-chat"],
      "transformer": {
        "use": ["deepseek"]
      }
    },
    {
      "name": "ollama",
      "api_base_url": "http://localhost:11434/v1",
      "api_key": "ollama",
      "models": ["qwen2.5-coder:7b", "llama3.1:8b", "mistral:7b"],
      "transformer": {
        "use": ["openai"]
      }
    }
  ],
  "Router": {
    "default": "deepseek,deepseek-chat",
    "background": "ollama,qwen2.5-coder:7b"
  }
}
```

### Стратегии маршрутизации

#### Вариант 1: Всё через один провайдер (текущий по умолчанию)

```json
"Router": {
  "default": "deepseek,deepseek-chat",
  "background": "deepseek,deepseek-chat"
}
```

Оба слота используют DeepSeek. Агенты-исследователи и исполнители идут к одному провайдеру.

#### Вариант 2: Разделение — локальные фоновые, удалённые основные

```json
"Router": {
  "default": "deepseek,deepseek-chat",
  "background": "ollama,qwen2.5-coder:7b"
}
```

- `researcher-agent`, `planning-agent` (haiku) → Ollama (бесплатно, локально)
- `critic-agent`, `execution-agent` (sonnet) → DeepSeek (качество)

#### Вариант 3: Полный Ollama (без внешних API)

```json
"Router": {
  "default": "ollama,qwen2.5-coder:7b",
  "background": "ollama,qwen2.5-coder:1.5b"
}
```

Все агенты работают локально. Требует мощного GPU.

#### Вариант 4: OpenRouter как агрегатор

```json
{
  "Providers": [
    {
      "name": "openrouter",
      "api_base_url": "https://openrouter.ai/api/v1/chat/completions",
      "api_key": "${OPENROUTER_API_KEY}",
      "models": [
        "google/gemini-flash-1.5",
        "meta-llama/llama-3.1-70b-instruct",
        "mistralai/mistral-7b-instruct"
      ],
      "transformer": { "use": ["openai"] }
    }
  ],
  "Router": {
    "default": "openrouter,meta-llama/llama-3.1-70b-instruct",
    "background": "openrouter,google/gemini-flash-1.5"
  }
}
```

### Переменные в router.json

CCR поддерживает `${VAR_NAME}` placeholders для секретов:

```json
{
  "api_key": "${DEEPSEEK_API_KEY}"
}
```

```bash
# Экспортировать перед запуском
export DEEPSEEK_API_KEY="sk-..."
./iclaude.sh --router
```

---

## Провайдеры

### Поддерживаемые провайдеры

| Провайдер | Transformer | API Base URL | Примечание |
|-----------|-------------|--------------|------------|
| DeepSeek | `deepseek` | `https://api.deepseek.com/v1/chat/completions` | Дешёвый, хорошее качество |
| Ollama | `openai` | `http://localhost:11434/v1` | Локальный, бесплатный |
| OpenRouter | `openai` | `https://openrouter.ai/api/v1/chat/completions` | Агрегатор 200+ моделей |
| Gemini | `gemini` | `https://generativelanguage.googleapis.com` | Google модели |
| OpenAI | `openai` | `https://api.openai.com/v1` | GPT-4o |
| SiliconFlow | `openai` | `https://api.siliconflow.cn/v1` | Китайский агрегатор |
| Volcengine | `openai` | `https://ark.cn-beijing.volces.com/api/v3` | ByteDance |

### Transformer типы

| Transformer | Назначение |
|-------------|------------|
| `openai` | Стандартный OpenAI-совместимый API |
| `deepseek` | DeepSeek-специфичные заголовки и форматирование |
| `gemini` | Google Gemini API (другой формат запроса) |

---

## Переменные окружения

| Переменная | Описание |
|------------|----------|
| `CLAUDE_CODE_SUBAGENT_MODEL` | Глобальный override модели для всех субагентов |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Переопределяет что резолвится по алиасу `haiku` |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Переопределяет что резолвится по алиасу `sonnet` |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Переопределяет что резолвится по алиасу `opus` |

Пример — принудительно пустить всех субагентов через Ollama:

```bash
CLAUDE_CODE_SUBAGENT_MODEL=haiku ./iclaude.sh --router
```

---

## Диагностика

### Проверить статус Router

```bash
./iclaude.sh --check-router
```

### Проверить что Router отвечает

```bash
curl http://localhost:3456/health
```

### Посмотреть логи маршрутизации

Включить debug-уровень в router.json:

```json
{
  "LOG": true,
  "LOG_LEVEL": "debug"
}
```

Логи покажут:
- Входящий model ID от Claude Code
- Выбранный слот (default/background/webSearch/think)
- Выбранный провайдер и модель
- HTTP-статус ответа

### Типичные проблемы

#### Агент не использует фиксированную модель

Проверить что значение в `AGENT.md` — это алиас, а не полный ID:

```yaml
model: haiku    # ✅ правильно
model: claude-haiku-4-5-20251001   # ❌ игнорируется молча
```

#### Router.background не срабатывает

CCR определяет background-слот только если model содержит одновременно `"claude"` И `"haiku"`.
Алиас `haiku` резолвится в `claude-haiku-4-5-20251001` — условие выполняется.

Если используется кастомная Ollama-модель напрямую (`model: qwen2.5-coder:7b`) — она не содержит `"claude"` и `"haiku"`, поэтому пойдёт в `Router.default`.

#### Ollama не отвечает

```bash
# Проверить что Ollama запущена
systemctl status ollama
# или
ollama serve &

# Проверить доступность API
curl http://localhost:11434/v1/models

# Проверить что модель загружена
ollama list
```

#### Таймаут при работе с Ollama

Увеличить `API_TIMEOUT_MS` в router.json:

```json
{
  "API_TIMEOUT_MS": 1200000
}
```

Ollama на CPU работает значительно медленнее, особенно на больших контекстах.

---

*Документ создан 2026-02-24. CCR версия: @musistudio/claude-code-router.*
