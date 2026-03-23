# AUTORESEARCH — Интеграция автономных ML-экспериментов

Интеграция [karpathy/autoresearch](https://github.com/karpathy/autoresearch) в iclaude:
три архитектурных варианта для запуска AI-агента, который самостоятельно меняет `train.py`,
обучает модели и коммитит лучшие результаты.

---

## Содержание

- [Что такое autoresearch](#что-такое-autoresearch)
- [Сравнение вариантов](#сравнение-вариантов)
- [Дерево выбора варианта](#дерево-выбора-варианта)
- [Quick Start](#quick-start)
- [Общие требования](#общие-требования)
- [Варианты интеграции](#варианты-интеграции)
- [Совместимость с iclaude](#совместимость-с-iclaude)

---

## Что такое autoresearch

**autoresearch** (Andrej Karpathy, март 2026) — фреймворк автономных ML-экспериментов.
AI-агент работает в цикле: предлагает гипотезу → изменяет `train.py` → запускает обучение
(~5 мин) → оценивает `val_bpb` → коммитит улучшения, откатывает ухудшения → повторяет.

```
Структура autoresearch-директории:
  train.py      — код обучения (агент его редактирует)
  prepare.py    — подготовка данных (запускается один раз)
  program.md    — инструкция агенту (цели, ограничения, стиль гипотез)
  results.tsv   — лог экспериментов (val_bpb + описание изменений)
```

Оригинальный репозиторий: [github.com/karpathy/autoresearch](https://github.com/karpathy/autoresearch)

---

## Сравнение вариантов

| Критерий | [A: Thin Orchestrator](autoresearch/VARIANT_A_THIN_ORCHESTRATOR.md) | [B: Background Daemon](autoresearch/VARIANT_B_BACKGROUND_DAEMON.md) | [C: Multi-Agent Pool](autoresearch/VARIANT_C_MULTIAGENT_POOL.md) |
|----------|---------------------------------------------------------------------|---------------------------------------------------------------------|------------------------------------------------------------------|
| Сложность реализации | Низкая (~200 LOC bash) | Средняя (~300 LOC Python) | Высокая (~500 LOC) |
| Открытый терминал | Нужен | Не нужен | Нужен (master) |
| Параллельные агенты | 1 | 1 | N (настраивается) |
| Зависимости | `uv` | `uv` + `anthropic` SDK | `uv` + Router (CCR) |
| Мониторинг | Базовый | Statusline + HTTP API | Расширенный |
| Overnight-режим | Нет | Да | Нет |
| PII-защита | Через iclaude proxy | Через PII:9000 | Через PII:9000 |
| Разные LLM | Нет | Нет | Да (через Router) |
| Время до первого запуска | 5 минут | 15 минут | 30 минут |

---

## Дерево выбора варианта

```
Хочешь попробовать autoresearch?
│
├─ Первый запуск / эксперимент?
│   └─ [A] Thin Orchestrator — минимальная настройка, работает сразу
│
├─ Нужен overnight-режим (закрыть ноутбук, утром результат)?
│   └─ [B] Background Daemon — работает как сервис
│
├─ Есть доступ к нескольким LLM через Router?
│   └─ Хочешь параллельные гипотезы от разных моделей?
│       └─ [C] Multi-Agent Pool — максимальный throughput
│
└─ Всё устраивает, кроме скорости?
    └─ [B] → [C] после настройки Router
```

---

## Quick Start

### Вариант A (рекомендуется для начала)

```bash
# Установка зависимостей
./iclaude.sh --install-autoresearch

# Запуск агента
./iclaude.sh --autoresearch /path/to/autoresearch-dir

# Проверка статуса
./iclaude.sh --check-autoresearch
```

### Вариант B

```bash
# Запуск демона
./iclaude.sh --autoresearch-start /path/to/autoresearch-dir

# Мониторинг
./iclaude.sh --autoresearch-status

# Остановка
./iclaude.sh --autoresearch-stop
```

### Вариант C

```bash
# Требует: Router + (опционально) PII proxy
./iclaude.sh --install-router
./iclaude.sh --autoresearch --router --pii-proxy /path/to/autoresearch-dir
```

---

## Общие требования

```
Обязательно:
  uv              — Python пакетный менеджер (rust-based, fast)
  train.py        — скрипт обучения в autoresearch-директории
  program.md      — инструкции агенту

Желательно:
  prepare.py      — подготовка данных (однократная)
  GPU или быстрый CPU — для 5-минутных прогонов

Проверка:
  ./iclaude.sh --check-autoresearch
```

---

## Варианты интеграции

### [Вариант A — Thin Orchestrator](autoresearch/VARIANT_A_THIN_ORCHESTRATOR.md)

Iclaude инициализирует среду и запускает Claude Code как агента. Никаких
новых демонов — только оркестрация существующих инструментов.

**Когда выбрать**: первый запуск, экспериментирование, простота важнее
автоматизации.

### [Вариант B — Background Daemon](autoresearch/VARIANT_B_BACKGROUND_DAEMON.md)

Python-демон работает в фоне через API Anthropic напрямую. Интеграция
со statusline — видишь прогресс в строке состояния терминала.

**Когда выбрать**: overnight-эксперименты, нужен мониторинг, терминал
должен быть свободен.

### [Вариант C — Multi-Agent Pool](autoresearch/VARIANT_C_MULTIAGENT_POOL.md)

Master-агент координирует пул sub-агентов через Claude Code Router.
Параллельные гипотезы от разных LLM, ветки git для каждого эксперимента.

**Когда выбрать**: максимальный throughput, доступ к нескольким LLM,
факториальный поиск гипотез.

---

## Совместимость с iclaude

```
Цепочки запуска (существующие):
  claude                                   (базовый)
  claude → HTTPS_PROXY → Anthropic         (--proxy)
  claude → CCR:3456 → providers            (--router)
  claude → PII:9000 → Anthropic            (--pii-proxy)

Новые цепочки autoresearch:
  [A] claude (агент) → Anthropic           (--autoresearch)
  [B] daemon → Anthropic                   (--autoresearch-start)
  [B] daemon → PII:9000 → Anthropic        (--autoresearch-start --pii-proxy)
  [C] claude (master) → Claude Code Tasks  (--autoresearch --router)
       ├─ sub-agent → CCR → DeepSeek
       ├─ sub-agent → CCR → Gemini
       └─ sub-agent → CCR → Claude
```

### Конфигурация в `.claude_config`

```bash
# Общие
AUTORESEARCH_DIR=                # путь по умолчанию (можно переопределить в CLI)
AUTORESEARCH_SKIP_PREPARE=false  # не перезапускать prepare.py каждый раз

# Вариант B
AUTORESEARCH_DAEMON_PORT=18640   # порт HTTP status API

# Вариант C
AUTORESEARCH_POOL_SIZE=3                      # количество параллельных агентов
AUTORESEARCH_WORKER_MODEL=background          # CCR Router слот для воркеров (→ DeepSeek)
AUTORESEARCH_MASTER_MODEL=default             # CCR Router слот для мастера (→ Claude)
AUTORESEARCH_ANALYST_MODEL=longContext        # CCR Router слот для аналитика (→ Gemini)
AUTORESEARCH_MERGE_STRATEGY=best_val_bpb
```

---

## Связанная документация

- [docs/ROUTER.md](ROUTER.md) — настройка Claude Code Router (нужен для варианта C)
- [docs/PII_MASKING.md](PII_MASKING.md) — PII proxy (варианты B, C)
- [docs/STATUSLINE.md](STATUSLINE.md) — строка статуса (интеграция с вариантом B)
- [docs/CONFIGURATION.md](CONFIGURATION.md) — все переменные конфигурации
