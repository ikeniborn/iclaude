# Вариант C — Multi-Agent Pool

Максимальный throughput: несколько Claude Code экземпляров работают параллельно
через Router. Master-агент координирует пул sub-агентов — каждый выдвигает гипотезу
через свою LLM. Реализует vision Karpathy: "async community of researchers".

---

## Содержание

- [Архитектура](#архитектура)
- [Цепочка запуска](#цепочка-запуска)
- [Управление ветками git](#управление-ветками-git)
- [Конфигурация Router](#конфигурация-router)
- [Новые файлы](#новые-файлы)
- [Новые флаги CLI](#новые-флаги-cli)
- [Конфигурация](#конфигурация)
- [Установка](#установка)
- [Протокол параллельного эксперимента](#протокол-параллельного-эксперимента)
- [Диагностика](#диагностика)
- [Когда выбрать этот вариант](#когда-выбрать-этот-вариант)
- [Связанная документация](#связанная-документация)

---

## Архитектура

```
./iclaude.sh --autoresearch --router --pii-proxy /path/to/dir
       │
       ├─ Требует: --router (CCR активен на :3456)
       │           --pii-proxy (опционально, :9000)
       │
       └─ Master Agent (основная сессия Claude Code)
               │
               ├─ Читает: program.md, results.tsv, train.py
               ├─ Понимает текущий baseline val_bpb
               │
               ├─ Spawns N sub-agent Tasks (Claude Code Tasks API)
               │
               │  ┌─────────────────────────────────────────────┐
               │  │  Sub-Agent 1 (CCR → DeepSeek-V3):           │
               │  │    Контекст: train.py + results.tsv          │
               │  │    Задача: "Предложи гипотезу #1,            │
               │  │            изменения в train.py"             │
               │  │    Возвращает: patch + описание + confidence │
               │  └─────────────────────────────────────────────┘
               │  ┌─────────────────────────────────────────────┐
               │  │  Sub-Agent 2 (CCR → Gemini Pro):            │
               │  │    Контекст: train.py + results.tsv          │
               │  │    Задача: "Предложи гипотезу #2,            │
               │  │            другой подход к проблеме"         │
               │  │    Возвращает: patch + описание + confidence │
               │  └─────────────────────────────────────────────┘
               │  ┌─────────────────────────────────────────────┐
               │  │  Sub-Agent 3 (CCR → Claude Sonnet):         │
               │  │    Контекст: results.tsv (последние 20)      │
               │  │    Задача: "Синтезируй паттерны успешных     │
               │  │            экспериментов 30–47"              │
               │  │    Возвращает: мета-гипотеза + обоснование   │
               │  └─────────────────────────────────────────────┘
               │
               ├─ Собирает ответы всех sub-агентов
               │
               └─ Для каждой гипотезы последовательно:
                   1. git checkout -b hyp-XXX от baseline
                   2. apply patch → train.py
                   3. uv run train.py (5 минут)
                   4. Парсить val_bpb
                   5. Если лучший → merge в baseline, обновить results.tsv
                   6. git branch -d hyp-XXX (или сохранить для истории)
                   7. Повторить с новым батчем гипотез


PII proxy (если --pii-proxy):
  Все API-вызовы master + sub-agents → PII:9000 → CCR:3456 → providers
```

---

## Цепочка запуска

```
С router:
  master claude → CCR:3456 → Claude API (master)
  sub-agent 1   → CCR:3456 → DeepSeek-V3
  sub-agent 2   → CCR:3456 → Gemini Pro
  sub-agent 3   → CCR:3456 → Claude Sonnet

С PII + router:
  master claude → PII:9000 → CCR:3456 → Claude API
  sub-agents    → PII:9000 → CCR:3456 → providers

Полная цепочка:
  master → PII:9000 → HTTPS_PROXY → CCR:3456 → DeepSeek/Gemini/Claude
```

---

## Управление ветками git

```
Структура веток в autoresearch-директории:

  main (или master)
   │
   └─ autoresearch/session-001/main     ← текущий лучший baseline
       ├─ autoresearch/session-001/hyp-047   ← гипотеза от DeepSeek
       ├─ autoresearch/session-001/hyp-048   ← гипотеза от Gemini
       └─ autoresearch/session-001/hyp-049   ← синтез от Claude

Жизненный цикл ветки гипотезы:
  1. git checkout -b hyp-047 autoresearch/session-001/main
  2. apply patch
  3. uv run train.py → val_bpb
  4a. Улучшение:
      git checkout autoresearch/session-001/main
      git merge hyp-047
      git branch -d hyp-047
  4b. Ухудшение:
      git branch -d hyp-047  (или сохранить с тегом rejected/hyp-047)
```

### Команды для ручной работы с ветками

```bash
cd /path/to/autoresearch-dir

# Посмотреть все ветки сессии
git branch | grep autoresearch/

# Текущий baseline
git log --oneline autoresearch/session-001/main | head -10

# Сравнить гипотезу с baseline
git diff autoresearch/session-001/main autoresearch/session-001/hyp-048

# Ручной merge лучшей гипотезы
git checkout autoresearch/session-001/main
git merge autoresearch/session-001/hyp-048 -m "manual merge: best hyp val_bpb=0.961"

# Очистить отклонённые ветки
git branch | grep "rejected/" | xargs git branch -d
```

---

## Конфигурация Router

CCR использует формат `Providers` + `Router` (см. [docs/ROUTER.md](../ROUTER.md)).
Для autoresearch sub-агенты направляются через слоты `Router`:

```jsonc
// ~/.claude-isolated/router.json (на основе router.json.example)
{
  "PORT": 3456,
  "HOST": "127.0.0.1",

  "Providers": [
    {
      "name": "anthropic",
      "api_base_url": "https://api.anthropic.com/v1/messages",
      "api_key": "${ANTHROPIC_API_KEY}",
      "models": ["claude-sonnet-4-6", "claude-opus-4-6"],
      "transformer": { "use": ["anthropic"] }
    },
    {
      "name": "deepseek",
      "api_base_url": "https://api.deepseek.com/chat/completions",
      "api_key": "${DEEPSEEK_API_KEY}",
      "models": ["deepseek-chat"],
      "transformer": { "use": ["deepseek"], "deepseek-chat": { "use": ["tooluse"] } }
    },
    {
      "name": "gemini",
      "api_base_url": "https://generativelanguage.googleapis.com/v1beta/models/",
      "api_key": "${GOOGLE_API_KEY}",
      "models": ["gemini-2.5-flash"],
      "transformer": { "use": ["gemini"] }
    }
  ],

  "Router": {
    "default": "anthropic,claude-sonnet-4-6",   // master-агент
    "background": "deepseek,deepseek-chat",      // worker sub-агенты (дешевле)
    "longContext": "gemini,gemini-2.5-flash"     // analyst (большой контекст)
  }
}
```

Маппинг ролей autoresearch на слоты CCR:

| Роль | CCR слот | Провайдер | Назначение |
|------|----------|-----------|------------|
| master | `default` | Claude Sonnet | Синтез, координация |
| worker | `background` | DeepSeek-V3 | Генерация гипотез (дешевле) |
| analyst | `longContext` | Gemini Flash | Анализ истории экспериментов |

### Минимальная конфигурация (только DeepSeek + Claude)

```jsonc
{
  "PORT": 3456,
  "Providers": [
    {
      "name": "anthropic",
      "api_base_url": "https://api.anthropic.com/v1/messages",
      "api_key": "${ANTHROPIC_API_KEY}",
      "models": ["claude-sonnet-4-6"],
      "transformer": { "use": ["anthropic"] }
    },
    {
      "name": "deepseek",
      "api_base_url": "https://api.deepseek.com/chat/completions",
      "api_key": "${DEEPSEEK_API_KEY}",
      "models": ["deepseek-chat"],
      "transformer": { "use": ["deepseek"], "deepseek-chat": { "use": ["tooluse"] } }
    }
  ],
  "Router": {
    "default": "anthropic,claude-sonnet-4-6",
    "background": "deepseek,deepseek-chat"
  }
}
```

```bash
# API keys в .claude_config
ANTHROPIC_API_KEY=sk-ant-api03-...
DEEPSEEK_API_KEY=sk-...
AUTORESEARCH_POOL_SIZE=2  # начать с двух агентов
```

---

## Новые файлы

```
lib/autoresearch/
├── detect.sh           — uv, train.py, program.md, router активен?
├── install.sh          — uv + router setup check
├── status.sh           — статус пула агентов
├── orchestrator.sh     — управление pool: spawn/sync/merge (~200 LOC)
└── templates/
    └── program-pool.md — шаблон program.md для multi-agent режима
```

### lib/autoresearch/orchestrator.sh

```bash
# Функции orchestrator.sh

spawn_agent_pool() {
  local dir="$1"
  local pool_size="${AUTORESEARCH_POOL_SIZE:-3}"
  local session_id="$AUTORESEARCH_SESSION_ID"

  # Master запускает sub-agent задачи через Claude Code Tasks
  # Каждый sub-agent получает: train.py + results.tsv + задачу
  for i in $(seq 1 "$pool_size"); do
    spawn_subagent_task "$dir" "$i" "$session_id"
  done
}

merge_best_hypothesis() {
  local dir="$1"
  local results_file="$dir/results.tsv"

  # Найти ветку с лучшим val_bpb из текущего батча
  local best_branch
  best_branch=$(find_best_val_bpb_branch "$dir")

  if [[ -n "$best_branch" ]]; then
    cd "$dir"
    git checkout "autoresearch/$AUTORESEARCH_SESSION_ID/main"
    git merge "$best_branch" -m "pool: merge best val_bpb from batch"
    log_merge_result "$best_branch" "$results_file"
  fi
}
```

### lib/autoresearch/templates/program-pool.md

Шаблон `program.md` для multi-agent режима. Символы `{ROLE}` и `{BASELINE_VAL_BPB}`
подставляются iclaude при запуске:

```
# Program: Multi-Agent Research Pool

Ты — один из нескольких параллельных исследователей.
Твоя задача: предложить ОДНУ конкретную гипотезу улучшения train.py.

## Роль этого агента: {ROLE}
(worker-1: новые идеи | worker-2: альтернативный подход | analyst: синтез паттернов)

## Метрика: val_bpb (ниже = лучше)
## Текущий baseline: {BASELINE_VAL_BPB}

## Формат ответа (JSON):
  {
    "hypothesis": "Краткое описание изменения",
    "confidence": 0.0-1.0,
    "patch": "unified diff для train.py",
    "reasoning": "Почему это должно улучшить val_bpb"
  }

## Ограничения:
- Изменять только train.py
- Одно изменение за раз (не комплексные рефакторинги)
- Время прогона ~5 минут — учитывай это
```

---

## Новые флаги CLI

```bash
--install-autoresearch          # uv + router check
--check-autoresearch            # статус директории, CCR, пула
--autoresearch [path]           # запустить с --router (требует активный CCR)
```

> **Важно:** Вариант C использует те же флаги что и Вариант A, но требует
> одновременно активного `--router`. CCR должен быть запущен.

### Примеры

```bash
# Установка и настройка
./iclaude.sh --install-autoresearch
./iclaude.sh --install-router

# Проверка CCR + autoresearch
./iclaude.sh --check-autoresearch
./iclaude.sh --check-router  # отдельная проверка CCR статуса

# Запуск пула агентов
./iclaude.sh --autoresearch --router /path/to/dir
./iclaude.sh --autoresearch --router --pii-proxy /path/to/dir

# Настроить размер пула
AUTORESEARCH_POOL_SIZE=2 ./iclaude.sh --autoresearch --router /path/to/dir

# Посмотреть ветки параллельных экспериментов
cd /path/to/autoresearch-dir
git branch | grep "hyp-"
```

---

## Конфигурация

| Переменная | По умолчанию | Описание |
|-----------|--------------|----------|
| `AUTORESEARCH_DIR` | (пусто) | Путь к директории |
| `AUTORESEARCH_POOL_SIZE` | `3` | Количество параллельных агентов |
| `AUTORESEARCH_WORKER_MODEL` | `background` | CCR Router слот для воркеров (→ DeepSeek) |
| `AUTORESEARCH_MASTER_MODEL` | `default` | CCR Router слот для мастера (→ Claude) |
| `AUTORESEARCH_ANALYST_MODEL` | `longContext` | CCR Router слот для аналитика (→ Gemini) |
| `AUTORESEARCH_MERGE_STRATEGY` | `best_val_bpb` | Стратегия слияния гипотез |
| `AUTORESEARCH_BRANCH_KEEP_REJECTED` | `false` | Сохранять отклонённые ветки |
| `AUTORESEARCH_UV_TIMEOUT` | `600` | Таймаут обучения (сек) |
| `AUTORESEARCH_BATCH_SIZE` | `3` | Гипотез в одном батче |

### Стратегии слияния

| Стратегия | Описание |
|-----------|----------|
| `best_val_bpb` | Merge только лучшего результата батча (по умолчанию) |
| `all_improved` | Merge всех улучшений последовательно |
| `ensemble_vote` | Master-агент голосует за лучшую гипотезу перед тренировкой |

### Пример .claude_config

```bash
# autoresearch (вариант C)
AUTORESEARCH_DIR=/home/user/projects/nanoGPT-autoresearch
AUTORESEARCH_POOL_SIZE=3
AUTORESEARCH_WORKER_MODEL=background    # CCR Router слот → deepseek
AUTORESEARCH_MASTER_MODEL=default       # CCR Router слот → claude-sonnet
AUTORESEARCH_MERGE_STRATEGY=best_val_bpb
AUTORESEARCH_BATCH_SIZE=3

# API keys для Router
DEEPSEEK_API_KEY=sk-...
GEMINI_API_KEY=AIza...
ANTHROPIC_API_KEY=sk-ant-api03-...
```

---

## Установка

```bash
# 1. Установить uv
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

# 2. Установить Router (CCR)
./iclaude.sh --install-router

# 3. Настроить провайдеры в router.json
# (DeepSeek, Gemini, или любые другие)
./iclaude.sh --check-router  # проверить конфиг

# 4. Добавить API keys в .claude_config
cat >> ~/.claude_config <<'EOF'
DEEPSEEK_API_KEY=sk-...
AUTORESEARCH_POOL_SIZE=3
EOF
chmod 600 ~/.claude_config

# 5. Подготовить autoresearch-директорию
cd /path/to/autoresearch-dir
uv sync
uv run python prepare.py   # однократно

# 6. Проверка всей конфигурации
./iclaude.sh --check-autoresearch

# 7. Первый запуск с одним воркером (безопасно)
AUTORESEARCH_POOL_SIZE=1 ./iclaude.sh --autoresearch --router /path/to/dir

# 8. Полный пул после проверки
./iclaude.sh --autoresearch --router --pii-proxy /path/to/dir
```

---

## Протокол параллельного эксперимента

### Один цикл (батч)

```
Батч #N:
  1. Master читает: program.md, results.tsv (последние 20), train.py
  2. Master определяет: текущий baseline = val_bpb последнего улучшения
  3. Spawn POOL_SIZE задач параллельно:
       Task 1 → DeepSeek-V3:  "Предложи гипотезу, фокус: архитектура"
       Task 2 → Gemini Pro:   "Предложи гипотезу, фокус: оптимизация"
       Task 3 → Claude Sonnet: "Синтезируй паттерны, предложи следующий шаг"
  4. Ждать ответы (обычно 30-60 секунд)
  5. Для каждой гипотезы последовательно:
       a. git branch + apply patch
       b. uv run train.py (~5 мин)
       c. Оценить val_bpb
       d. Записать в results.tsv
  6. Merge лучшего результата батча
  7. Повторить батч с обновлённым baseline
```

### Пример results.tsv после 3 батчей

```
# session: 20260322-143012
# baseline: 0.987 (initial)
ts                   val_bpb  agent          desc
2026-03-22T14:30:12  0.987    baseline       initial state
--- batch 1 ---
2026-03-22T14:40:01  0.981    deepseek-v3    cosine lr schedule
2026-03-22T14:50:22  0.985    gemini-pro     [REJECTED] weight decay 0.01
2026-03-22T15:00:41  0.979    claude-sonnet  batch_size 64 + lr 3e-4
--- batch 2 ---
2026-03-22T15:10:15  0.972    deepseek-v3    attention heads 8→12
2026-03-22T15:20:33  0.976    gemini-pro     [REJECTED] gradient clipping 0.5
2026-03-22T15:30:52  0.970    claude-sonnet  feedforward 4x→6x + gelu
```

---

## Диагностика

```bash
# Проверить Router активен
./iclaude.sh --check-router
curl http://localhost:3456/health

# Проверить autoresearch конфиг
./iclaude.sh --check-autoresearch

# Посмотреть активные ветки гипотез
cd /path/to/autoresearch-dir
git branch | grep "hyp-"

# Сравнить гипотезы между собой
git log --all --oneline | grep "hyp-"
git diff hyp-047 hyp-048 -- train.py

# Проверить results.tsv
grep "REJECTED" /path/to/dir/results.tsv | wc -l   # сколько отклонено
grep -v "REJECTED" /path/to/dir/results.tsv | tail -5  # последние улучшения

# Если sub-агент завис
# Внутри Claude Code: проверить Tasks
# /tasks  — показать активные задачи
```

### Типичные ошибки

| Ошибка | Причина | Решение |
|--------|---------|---------|
| `CCR не активен` | Router не запущен | `./iclaude.sh --router` сначала |
| CCR slot `background` не задан | Нет `"background"` в `Router{}` конфига | Добавить `"background": "deepseek,deepseek-chat"` в router.json |
| Конфликт git при merge | Два агента изменили одно место | Уменьшить `AUTORESEARCH_POOL_SIZE=1` |
| Sub-агент не отвечает | Context limit или ошибка модели | Проверить CCR логи |
| `DEEPSEEK_API_KEY не задан` | Нет API key | Добавить в `.claude_config` |
| Все гипотезы похожи | Мало диверсификации | Разные system prompts в program-pool.md |

---

## Когда выбрать этот вариант

### Подходит если:

- Есть доступ к нескольким LLM через Router (DeepSeek, Gemini, OpenRouter)
- Хочется параллельных гипотез с разными подходами
- Важен максимальный throughput (N гипотез за время одного прогона)
- Нужен факториальный поиск: архитектура × оптимизация × регуляризация
- Есть опыт с [Вариантом A](VARIANT_A_THIN_ORCHESTRATOR.md) или [B](VARIANT_B_BACKGROUND_DAEMON.md)

### Не подходит если:

- Нет настроенного Router → [Вариант A](VARIANT_A_THIN_ORCHESTRATOR.md) или [B](VARIANT_B_BACKGROUND_DAEMON.md)
- Только один LLM доступен → [Вариант A](VARIANT_A_THIN_ORCHESTRATOR.md)
- Нужен overnight-режим → [Вариант B](VARIANT_B_BACKGROUND_DAEMON.md)
- Первый опыт с autoresearch → начать с [Варианта A](VARIANT_A_THIN_ORCHESTRATOR.md)

### Trade-offs

| + Плюсы | - Минусы |
|---------|---------|
| Максимальный throughput гипотез | Требует Router + multi-provider конфиг |
| Разные LLM = разные подходы | Сложная синхронизация git-веток |
| Факториальный поиск гипотез | ~30 минут на начальную настройку |
| Параллельная генерация (DeepSeek дешевле) | Нужен опыт с iclaude Router |
| Vision Karpathy: async researchers | Конфликты при merge параллельных патчей |

---

## Связанная документация

- [docs/AUTORESEARCH.md](../AUTORESEARCH.md) — главный doc, сравнение вариантов
- [Вариант A — Thin Orchestrator](VARIANT_A_THIN_ORCHESTRATOR.md) — простой запуск
- [Вариант B — Background Daemon](VARIANT_B_BACKGROUND_DAEMON.md) — overnight-режим
- [docs/ROUTER.md](../ROUTER.md) — настройка Claude Code Router (обязательно для этого варианта)
- [docs/PII_MASKING.md](../PII_MASKING.md) — PII proxy
- [docs/CONFIGURATION.md](../CONFIGURATION.md) — все переменные конфигурации
