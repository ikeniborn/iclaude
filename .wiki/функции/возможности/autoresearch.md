---
wiki_sources: ["docs/functions/AUTORESEARCH.md"]
wiki_updated: 2026-05-05
wiki_status: developing
tags: [iclaude, features, autoresearch, ml, agents]
aliases: ["автономные ML-эксперименты", "karpathy/autoresearch"]
---

# Autoresearch (автономные ML-эксперименты)

Интеграция [karpathy/autoresearch](https://github.com/karpathy/autoresearch) в iclaude — три архитектурных варианта для запуска AI-агента, который самостоятельно изменяет `train.py`, обучает модели и коммитит лучшие результаты.

## Основные характеристики

Autoresearch (Andrej Karpathy, март 2026) — фреймворк автономных ML-экспериментов. AI-агент работает в цикле: предлагает гипотезу → изменяет `train.py` → запускает обучение (~5 мин) → оценивает `val_bpb` → коммитит улучшения, откатывает ухудшения → повторяет.

### Структура autoresearch-директории

```
train.py      — код обучения (агент его редактирует)
prepare.py    — подготовка данных (запускается один раз)
program.md    — инструкция агенту (цели, ограничения, стиль гипотез)
results.tsv   — лог экспериментов (val_bpb + описание изменений)
```

### Три варианта интеграции

| Критерий | A: Thin Orchestrator | B: Background Daemon | C: Multi-Agent Pool |
|----------|---------------------|---------------------|---------------------|
| Сложность | ~200 LOC bash | ~300 LOC Python | ~500 LOC |
| Открытый терминал | Нужен | Не нужен | Нужен (master) |
| Параллельные агенты | 1 | 1 | N |
| Overnight-режим | Нет | Да | Нет |
| Разные LLM | Нет | Нет | Да (через Router) |
| Время до запуска | 5 мин | 15 мин | 30 мин |

### Quick Start

**Вариант A (рекомендуется):**

```bash
./iclaude.sh --install-autoresearch
./iclaude.sh --autoresearch /path/to/autoresearch-dir
./iclaude.sh --check-autoresearch
```

**Вариант B:**

```bash
./iclaude.sh --autoresearch-start /path/to/autoresearch-dir
./iclaude.sh --autoresearch-status
./iclaude.sh --autoresearch-stop
```

**Вариант C:**

```bash
./iclaude.sh --install-router
./iclaude.sh --autoresearch --router --pii-proxy /path/to/autoresearch-dir
```

### Дерево выбора варианта

```
Первый запуск / эксперимент?       → Вариант A
Overnight-режим?                   → Вариант B
Несколько LLM + параллельные run?  → Вариант C
```

## Конфигурация через .claude_config

```bash
AUTORESEARCH_DIR=                     # путь по умолчанию
AUTORESEARCH_SKIP_PREPARE=false       # не перезапускать prepare.py

# Вариант B:
AUTORESEARCH_DAEMON_PORT=18640        # порт HTTP status API

# Вариант C:
AUTORESEARCH_POOL_SIZE=3              # число параллельных агентов
AUTORESEARCH_WORKER_MODEL=background  # CCR слот для воркеров (→ DeepSeek)
AUTORESEARCH_MASTER_MODEL=default     # CCR слот для мастера (→ Claude)
AUTORESEARCH_ANALYST_MODEL=longContext # CCR слот для аналитика (→ Gemini)
AUTORESEARCH_MERGE_STRATEGY=best_val_bpb
```

## Совместимость с остальными функциями iclaude

Autoresearch совместим со всеми флагами: `--proxy`, `--pii-proxy`, `--router`, `--no-proxy`.

## Связанные концепции

- [[функции/возможности/router]] — вариант C требует Router для параллельных агентов
- [[функции/возможности/pii-proxy]] — варианты B и C могут использовать PII Proxy
