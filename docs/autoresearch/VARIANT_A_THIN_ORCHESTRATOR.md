# Вариант A — Thin Orchestrator

Минималистичная интеграция: iclaude инициализирует autoresearch-директорию и запускает
Claude Code как AI-агента эксперимент-цикла. Никаких новых демонов, никаких дополнительных
процессов — только оркестрация существующего стека.

---

## Содержание

- [Архитектура](#архитектура)
- [Цепочка запуска](#цепочка-запуска)
- [Новые файлы](#новые-файлы)
- [Новые флаги CLI](#новые-флаги-cli)
- [Конфигурация](#конфигурация)
- [Управление количеством экспериментов](#управление-количеством-экспериментов)
- [Версионность](#версионность)
- [Структура и управление файлами проекта](#структура-и-управление-файлами-проекта)
- [Установка](#установка)
- [Работа агента](#работа-агента)
- [Диагностика](#диагностика)
- [Когда выбрать этот вариант](#когда-выбрать-этот-вариант)
- [Связанная документация](#связанная-документация)

---

## Архитектура

```
./iclaude.sh --autoresearch /path/to/dir
       │
       ├─ detect_autoresearch()
       │   ├─ uv доступен?
       │   ├─ train.py существует?
       │   └─ program.md существует?
       │
       ├─ init_autoresearch()
       │   ├─ git branch autoresearch/YYMMDD-HHMMSS
       │   ├─ touch results.tsv (если нет)
       │   └─ export AUTORESEARCH_DIR, AUTORESEARCH_SESSION_ID
       │
       ├─ (опционально) uv run prepare.py
       │
       └─ exec claude  ←──────── обычный запуск Claude Code
               │
               │  Переменные окружения:
               │  AUTORESEARCH_DIR=/path/to/dir
               │  AUTORESEARCH_SESSION_ID=20260322-143012
               │  CLAUDE_SYSTEM_PROMPT=<base_prompt + contents of program.md>
               │  (iclaude.sh формирует CLAUDE_SYSTEM_PROMPT конкатенацией)
               │
               └─ Claude Code становится агентом эксперимент-цикла:
                   │
                   ├─ Читает: train.py, results.tsv, program.md
                   ├─ Предлагает гипотезу (изменение в train.py)
                   ├─ Применяет: Edit tool → train.py
                   ├─ Запускает: Bash tool → uv run train.py
                   ├─ Парсит: val_bpb из stdout
                   ├─ Оценивает: улучшение? сохранить : git checkout -- train.py
                   ├─ Записывает: results.tsv (timestamp, val_bpb, описание)
                   ├─ Коммитит: git commit (если улучшение)
                   └─ Повторяет ∞
```

---

## Цепочка запуска

Вариант A встраивается в существующие цепочки iclaude:

```
Базовый:    claude (агент) ──────────────────→ Anthropic API
С proxy:    claude (агент) → HTTPS_PROXY ────→ Anthropic API
С PII:      claude (агент) → PII:9000 ───────→ Anthropic API
С router:   claude (агент) → CCR:3456 ───────→ providers

Комбо:      claude (агент) → PII:9000 → CCR:3456 → providers
```

Флаг `--autoresearch` совместим со всеми существующими флагами iclaude.

---

## Новые файлы

```
lib/autoresearch/
├── detect.sh     — проверка зависимостей и структуры директории
├── install.sh    — установка uv, uv sync в autoresearch-директории
└── status.sh     — статус: текущий эксперимент, val_bpb, git branch
```

### lib/autoresearch/detect.sh

```bash
detect_autoresearch() {
  local dir="${1:-$AUTORESEARCH_DIR}"

  # uv обязателен
  if ! command -v uv &>/dev/null; then
    error "autoresearch: uv не найден. Установите: curl -LsSf https://astral.sh/uv/install.sh | sh"
    return 1
  fi

  # Структура директории
  [[ -z "$dir" ]] && { error "autoresearch: укажите директорию (--autoresearch /path)"; return 1; }
  [[ -f "$dir/train.py" ]] || { error "autoresearch: train.py не найден в $dir"; return 1; }
  [[ -f "$dir/program.md" ]] || { error "autoresearch: program.md не найден в $dir"; return 1; }

  return 0
}
```

### lib/autoresearch/install.sh

```bash
install_autoresearch() {
  local dir="${1:-$AUTORESEARCH_DIR}"

  info "Установка uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"   # uv installer → ~/.local/bin/uv

  if [[ -n "$dir" && -f "$dir/pyproject.toml" ]]; then
    info "Синхронизация зависимостей в $dir..."
    (cd "$dir" && uv sync)
  fi

  success "autoresearch: установка завершена"
}
```

### lib/autoresearch/status.sh

```bash
status_autoresearch() {
  local dir="${1:-$AUTORESEARCH_DIR}"

  echo "=== autoresearch status ==="
  echo "Директория: ${dir:-не задана}"

  if [[ -n "$dir" && -d "$dir" ]]; then
    # Текущая ветка git
    local branch
    branch=$(cd "$dir" && git branch --show-current 2>/dev/null)
    echo "Git branch:  ${branch:-нет}"

    # Последний результат из results.tsv
    if [[ -f "$dir/results.tsv" ]]; then
      local last
      last=$(tail -1 "$dir/results.tsv")
      echo "Последний:   $last"
      echo "Всего экспериментов: $(wc -l < "$dir/results.tsv")"
    else
      echo "results.tsv: не найден"
    fi
  fi
}
```

---

## Новые флаги CLI

В `iclaude.sh` добавляются три флага:

```bash
--install-autoresearch          # Установить uv + sync зависимостей
--check-autoresearch            # Проверить статус директории и кешей
--autoresearch [path]           # Запустить Claude Code как агента
```

### Пример использования

```bash
# Установка
./iclaude.sh --install-autoresearch

# Проверка
./iclaude.sh --check-autoresearch
./iclaude.sh --check-autoresearch /path/to/autoresearch-dir

# Запуск (путь из .claude_config или аргумент)
./iclaude.sh --autoresearch
./iclaude.sh --autoresearch /path/to/autoresearch-dir

# С proxy и PII
./iclaude.sh --autoresearch /path/to/dir --proxy https://proxy:8118 --pii-proxy

# Проверить синтаксис iclaude.sh после добавления
bash -n iclaude.sh
```

---

## Конфигурация

Переменные в `.claude_config`:

| Переменная | По умолчанию | Описание |
|-----------|--------------|----------|
| `AUTORESEARCH_DIR` | (пусто) | Путь к autoresearch-директории |
| `AUTORESEARCH_SKIP_PREPARE` | `false` | Пропустить запуск `prepare.py` |
| `AUTORESEARCH_GIT_BRANCH_PREFIX` | `autoresearch` | Префикс git-веток |
| `AUTORESEARCH_UV_TIMEOUT` | `600` | Таймаут `uv run train.py` в секундах |
| `AUTORESEARCH_MAX_ITERS` | `0` | Максимум экспериментов за сессию (0 = без лимита) |
| `AUTORESEARCH_BRANCH_FROM` | `main` | Стратегия создания ветки: `main`, `last`, `current` |

### Пример .claude_config

```bash
# autoresearch
AUTORESEARCH_DIR=/home/user/projects/nanoGPT-autoresearch
AUTORESEARCH_SKIP_PREPARE=false
AUTORESEARCH_UV_TIMEOUT=600
AUTORESEARCH_MAX_ITERS=30
AUTORESEARCH_BRANCH_FROM=last
```

---

## Управление количеством экспериментов

### Проблема

Цикл агента (`Повторяет ∞`) не имеет встроенного механизма остановки. На практике сессия
завершается при исчерпании контекстного окна Claude (~100K–200K токенов), что происходит
непредсказуемо — примерно через 5–20 экспериментов в зависимости от объёма вывода `train.py`.
Graceful shutdown при этом не гарантирован.

### Решение: AUTORESEARCH_MAX_ITERS

`init_autoresearch()` записывает лимит в файл состояния сессии:

```bash
init_autoresearch() {
  # ... git branch, export переменных ...

  local session_file="$dir/.autoresearch_session"
  cat > "$session_file" <<EOF
SESSION_ID=${AUTORESEARCH_SESSION_ID}
MAX_ITERS=${AUTORESEARCH_MAX_ITERS:-0}
ITERS_DONE=0
STARTED_AT=$(date -Iseconds)
EOF
  chmod 600 "$session_file"
}
```

### Инструкция агенту в системном промпте

`lib/autoresearch/` формирует `CLAUDE_SYSTEM_PROMPT` с явным лимитом:

```
Лимит сессии: ${AUTORESEARCH_MAX_ITERS} экспериментов (0 = без лимита).
Счётчик текущей сессии хранится в .autoresearch_session (ITERS_DONE).

После каждого эксперимента:
1. Обнови ITERS_DONE в .autoresearch_session
2. Если ITERS_DONE >= MAX_ITERS (и MAX_ITERS > 0):
   - Запиши итоговую строку в results.tsv с пометкой [SESSION_END]
   - Выведи краткое summary: лучший val_bpb, список принятых гипотез
   - Завершись (не запускай следующий эксперимент)
```

### Рекомендуемые значения MAX_ITERS

| Сценарий | MAX_ITERS | Причина |
|---------|-----------|---------|
| Быстрый тест | 5 | Убедиться что цикл работает |
| Интерактивная сессия | 20–30 | Комфортный объём контекста |
| Overnight (Вариант A) | 50 | Граница до context limit |
| Без лимита | 0 | Только если train.py выводит минимум текста |

---

## Версионность

### Проблема

Каждая сессия создаёт изолированную git-ветку, но:
- Нет явной стратегии: от какого коммита создавать новую ветку
- `results.tsv` не привязан к git-хешу — нельзя воспроизвести эксперимент
- Кросс-сессионная нумерация экспериментов отсутствует
- Ручной merge после сессии может конфликтовать, если `train.py` менялся в нескольких ветках

### Стратегия создания ветки (AUTORESEARCH_BRANCH_FROM)

`init_autoresearch()` выбирает точку ветвления по значению переменной:

```bash
_autoresearch_branch_point() {
  local dir="$1"
  case "${AUTORESEARCH_BRANCH_FROM:-main}" in
    main)
      # Всегда от main — чистая база, без накопленных изменений
      git -C "$dir" rev-parse main
      ;;
    last)
      # От HEAD последней autoresearch/* ветки — продолжить серию
      git -C "$dir" rev-parse \
        "$(git -C "$dir" branch --sort=-creatordate --list 'autoresearch/*' \
           | head -1 | tr -d ' *')" 2>/dev/null \
        || git -C "$dir" rev-parse main
      ;;
    current)
      # От текущего HEAD — без переключения ветки
      git -C "$dir" rev-parse HEAD
      ;;
  esac
}

init_autoresearch() {
  local dir="$1"
  local branch="${AUTORESEARCH_GIT_BRANCH_PREFIX:-autoresearch}/${AUTORESEARCH_SESSION_ID}"
  local point
  point=$(_autoresearch_branch_point "$dir")

  git -C "$dir" checkout -b "$branch" "$point"
  # ...
}
```

#### Когда использовать каждую стратегию

| `BRANCH_FROM` | Сценарий |
|--------------|---------|
| `main` | Независимые эксперименты; каждая сессия исследует с нуля |
| `last` | Последовательные сессии; новая начинает от лучшего результата предыдущей |
| `current` | Ручная работа: пользователь сам выбрал ветку перед запуском |

### Формат results.tsv (расширенный)

Добавляется колонка `git_sha` для воспроизводимости:

```
# формат: timestamp \t val_bpb \t git_sha \t session_id \t описание
2026-03-22T14:30:12  0.987  -        20260322-143012  baseline
2026-03-22T14:38:44  0.981  abc1234  20260322-143012  changed lr_schedule to cosine + warmup
2026-03-22T14:47:01  0.989  -        20260322-143012  [REJECTED] added dropout 0.2 to attention
2026-03-22T14:55:23  0.974  def5678  20260322-143012  increased batch_size 32→64 + adjusted lr
2026-03-22T18:01:00  0.974  def5678  20260322-180045  [SESSION_START] BRANCH_FROM=last point=def5678
2026-03-22T18:09:11  0.971  ghi9012  20260322-180045  reduced weight_decay 0.1→0.01
```

- `git_sha` заполняется только при успешном коммите (`git rev-parse HEAD`)
- `[SESSION_START]` строка записывается в начале каждой сессии — видна точка продолжения
- `[SESSION_END]` — итоговая строка при достижении `MAX_ITERS`
- `[REJECTED]` — откат без коммита, `git_sha` пуст

### Кросс-сессионная нумерация экспериментов

Глобальный счётчик хранится в `results.tsv` — агент читает количество строк без `SESSION_START`/`SESSION_END`:

```bash
# Системный промпт содержит инструкцию:
# "Номер эксперимента = число строк в results.tsv, не начинающихся с [SESSION"
# Используй этот номер в git commit message: autoresearch: exp #N val_bpb=X.XXX"
```

Таким образом нумерация сквозная через все сессии без внешнего счётчика.

### Стратегия merge после сессии

```bash
# Рекомендуемый flow после завершения сессии:

# 1. Посмотреть что накопилось
git -C /path/to/dir log --oneline autoresearch/20260322-143012

# 2. Если BRANCH_FROM=main — cherry-pick только лучших коммитов
git -C /path/to/dir checkout main
git -C /path/to/dir cherry-pick def5678  # только лучший результат

# 3. Если BRANCH_FROM=last — ff-merge (конфликтов нет по построению)
git -C /path/to/dir checkout main
git -C /path/to/dir merge --ff-only autoresearch/20260322-180045

# 4. results.tsv всегда добавляется (append-only), конфликтов нет
```

**Рекомендация:** при `BRANCH_FROM=main` использовать cherry-pick лучшего коммита вместо
полного merge — это исключает конфликты между параллельными сессиями.

---

## Структура и управление файлами проекта

### Откуда берётся autoresearch-директория

Есть три пути получить рабочую директорию:

#### Путь 1 — Клонировать оригинальный репозиторий Karpathy

```bash
git clone https://github.com/karpathy/autoresearch /path/to/autoresearch-dir
cd /path/to/autoresearch-dir
uv sync
uv run python prepare.py   # скачать и токенизировать данные (~однократно, несколько GB)
```

Репозиторий содержит готовые `train.py`, `prepare.py`, `program.md`, `pyproject.toml`.
Это стартовая точка — агент будет итеративно улучшать именно этот `train.py`.

#### Путь 2 — Инициализировать шаблон через iclaude

```bash
./iclaude.sh --init-autoresearch /path/to/new-dir
```

Команда создаёт минимальную структуру из встроенных шаблонов iclaude:

```
/path/to/new-dir/
├── train.py        ← шаблон с заглушкой (нужно адаптировать)
├── program.md      ← шаблон инструкций агенту (нужно отредактировать)
├── pyproject.toml  ← минимальный uv-проект
└── .gitignore      ← исключает data/, checkpoints/, __pycache__/
```

После инициализации — адаптировать `train.py` под свою задачу и заполнить `program.md`.

#### Путь 3 — Использовать существующий проект

Если `train.py` уже существует (свой ML-проект), нужно:

1. Убедиться, что `train.py` выводит метрику в stdout в формате, который агент может распарсить
2. Создать `program.md` с описанием задачи и метрики
3. Добавить `pyproject.toml` для uv (или `requirements.txt`)
4. Инициализировать git-репозиторий, если его нет

```bash
cd /path/to/existing-project
git init && git add . && git commit -m "initial"
cat > pyproject.toml << 'EOF'
[project]
name = "autoresearch"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = ["torch", "numpy"]
EOF
uv sync
```

---

### Структура autoresearch-директории

```
autoresearch-dir/
│
├── train.py              ← РЕДАКТИРУЕТСЯ АГЕНТОМ. Основной скрипт обучения.
│                            Агент меняет гиперпараметры, архитектуру, оптимизатор.
│                            Должен выводить метрику в stdout (см. ниже).
│
├── prepare.py            ← НЕ РЕДАКТИРУЕТСЯ. Однократная подготовка данных.
│                            Скачивает датасет, токенизирует, сохраняет в data/.
│
├── program.md            ← РЕДАКТИРУЕТСЯ ЧЕЛОВЕКОМ. Инструкция агенту:
│                            цели, метрика, ограничения, запрещённые изменения.
│
├── pyproject.toml        ← НЕ РЕДАКТИРУЕТСЯ (обычно). Зависимости для uv.
│   (или requirements.txt)
│
├── results.tsv           ← ТОЛЬКО ДОПОЛНЯЕТСЯ. Агент добавляет строки.
│                            Никогда не удаляется вручную — история экспериментов.
│
├── .autoresearch_session ← ГЕНЕРИРУЕТСЯ iclaude. Состояние текущей сессии.
│                            Удаляется после завершения сессии автоматически.
│
└── data/                 ← Данные (generate prepare.py). В .gitignore.
    checkpoints/          ← Чекпоинты модели. В .gitignore.
```

---

### Требования к train.py

Агент парсит вывод `train.py` для получения метрики. Скрипт **должен** выводить
итоговую метрику в stdout в одном из поддерживаемых форматов:

```python
# Формат 1 — ключ=значение (парсится по ключу val_bpb):
print(f"val_bpb={val_bpb:.4f}")

# Формат 2 — JSON-строка:
import json; print(json.dumps({"val_bpb": val_bpb}))

# Формат 3 — произвольный текст с ключом (агент ищет regex):
print(f"Step 1000 | val loss {val_loss:.4f} | val_bpb {val_bpb:.4f}")
```

Имя метрики (`val_bpb` по умолчанию) задаётся в `program.md` и системном промпте.
Агент получает инструкцию, какой паттерн искать в выводе.

**Завершение обучения:** `train.py` должен завершаться с `exit(0)` при успехе.
Ненулевой exit code = агент считает эксперимент неудавшимся и откатывает изменения.

---

### program.md — инструкция агенту

`program.md` — единственный файл, который **нужно редактировать человеку** перед каждой
серией экспериментов. Это инструкция агенту: что исследовать, что запрещено, какова метрика.

#### Минимальная структура

```markdown
# Цель

Оптимизировать val_bpb (bits-per-byte на валидационной выборке) модели nanoGPT.
Метрика улучшается при уменьшении значения.

# Метрика

Парсить из stdout train.py: строка, содержащая `val_bpb=<число>`

# Что можно менять

- Гиперпараметры: learning_rate, batch_size, weight_decay, grad_clip
- LR schedule: cosine, linear, constant, warmup steps
- Архитектура: n_layer, n_head, n_embd (в разумных пределах)
- Оптимизатор: AdamW, SGD, параметры beta1/beta2

# Что НЕЛЬЗЯ менять

- Датасет и prepare.py
- Токенизатор
- Код сохранения чекпоинтов
- Параметры валидации (eval_interval, eval_iters)

# Ограничения

- Время одного прогона: не более 10 минут
- GPU memory: не выходить за 8GB (batch_size * context_length)
- Не добавлять новые зависимости в pyproject.toml без крайней необходимости
```

#### Рекомендации по написанию program.md

| Раздел | Зачем | Что писать |
|--------|-------|------------|
| Цель | Агент понимает направление | Метрика + направление улучшения (↓ или ↑) |
| Метрика | Агент знает что парсить | Точный паттерн из stdout |
| Разрешено | Сфокусировать поиск | Список компонентов для изменения |
| Запрещено | Избежать поломок | Критические части кода |
| Ограничения | Предотвратить OOM и зависания | Время, память, зависимости |

**Обновление program.md между сессиями:** файл обновляется вручную в ветке `main` до
запуска новой сессии. Если `BRANCH_FROM=last`, новая ветка создаётся от HEAD последней
сессии, где `program.md` уже может быть изменён агентом — поэтому правки лучше вносить
в `main` и использовать `BRANCH_FROM=main`.

---

### Управление файлами между сессиями

#### train.py — точка восстановления

Агент откатывает `train.py` при ухудшении метрики (`git checkout -- train.py`),
но **только в рамках текущей сессии**. Между сессиями:

```bash
# Посмотреть текущий train.py относительно main
git -C /path/to/dir diff main -- train.py

# Сбросить train.py к состоянию main (начать с чистого листа)
git -C /path/to/dir checkout main -- train.py

# Откатиться к конкретному эксперименту (по git_sha из results.tsv)
git -C /path/to/dir checkout abc1234 -- train.py
```

#### results.tsv — append-only лог

Файл **никогда не удаляется** — это полная история экспериментов. При конфликте merge
всегда предпочитать `theirs` (новые строки):

```bash
# При конфликте merge в results.tsv:
git checkout --theirs results.tsv
git add results.tsv
```

Полезные запросы к results.tsv:

```bash
# Лучший результат за всё время
sort -k2 -n /path/to/dir/results.tsv | head -1

# Все принятые эксперименты (с git_sha)
grep -v REJECTED /path/to/dir/results.tsv | grep -v SESSION

# История конкретной сессии
grep "20260322-143012" /path/to/dir/results.tsv
```

#### pyproject.toml — зависимости

Агент не должен менять `pyproject.toml` (указано в `program.md`). Если новая зависимость
действительно нужна — добавить вручную:

```bash
cd /path/to/dir
uv add torch-optimizer   # добавит в pyproject.toml + обновит uv.lock
git add pyproject.toml uv.lock
git commit -m "deps: add torch-optimizer"
```

---

### Команды управления файлами

```bash
# Инициализировать новую директорию из шаблонов iclaude
./iclaude.sh --init-autoresearch /path/to/new-dir

# Проверить структуру директории (наличие всех обязательных файлов)
./iclaude.sh --check-autoresearch /path/to/dir

# Посмотреть статус: ветка, последний val_bpb, количество экспериментов
./iclaude.sh --autoresearch-status /path/to/dir

# Сбросить train.py к состоянию main (между сессиями)
git -C /path/to/dir checkout main -- train.py
```

---

## Установка

Выберите сценарий в зависимости от того, откуда берётся autoresearch-директория.

### Сценарий 1 — Клонировать karpathy/autoresearch (рекомендуется)

```bash
# 1. Установить uv (если не установлен)
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc   # или ~/.zshrc — добавляет ~/.local/bin в PATH
uv --version       # проверка: должно вывести версию

# 2. Клонировать репозиторий autoresearch
git clone https://github.com/karpathy/autoresearch /path/to/autoresearch-dir
cd /path/to/autoresearch-dir

# 3. Установить зависимости Python
uv sync            # читает pyproject.toml, создаёт .venv

# 4. Подготовить данные (однократно, ~несколько GB, занимает несколько минут)
uv run python prepare.py
# После завершения появится data/ с токенизированным датасетом

# 5. Проверить что train.py работает без агента
uv run python train.py
# Ожидается: вывод метрики вида val_bpb=X.XXXX в конце

# 6. Установить поддержку autoresearch в iclaude
./iclaude.sh --install-autoresearch

# 7. Записать путь в конфиг iclaude
echo 'AUTORESEARCH_DIR=/path/to/autoresearch-dir' >> ~/.claude_config

# 8. (Опционально) Настроить лимиты
cat >> ~/.claude_config << 'EOF'
AUTORESEARCH_MAX_ITERS=20
AUTORESEARCH_BRANCH_FROM=main
AUTORESEARCH_UV_TIMEOUT=600
EOF

# 9. Проверить готовность
./iclaude.sh --check-autoresearch

# 10. Запустить
./iclaude.sh --autoresearch
```

---

### Сценарий 2 — Инициализировать новый проект из шаблона iclaude

```bash
# 1. Установить uv (если не установлен)
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

# 2. Создать директорию из шаблонов iclaude
./iclaude.sh --init-autoresearch /path/to/new-dir
# Создаст: train.py (заглушка), program.md (шаблон), pyproject.toml, .gitignore

# 3. Адаптировать train.py под свою задачу
#    Обязательно: вывод метрики в stdout (см. раздел "Требования к train.py")
$EDITOR /path/to/new-dir/train.py

# 4. Заполнить program.md — инструкция агенту
#    Обязательно: цель, метрика, что можно/нельзя менять
$EDITOR /path/to/new-dir/program.md

# 5. Добавить нужные зависимости
cd /path/to/new-dir
uv add torch numpy          # или нужные пакеты
uv sync

# 6. Проверить что train.py работает
uv run python train.py
# Убедиться что выводит метрику и завершается с exit code 0

# 7. Инициализировать git и сделать первый коммит
git init && git add . && git commit -m "initial: autoresearch project"

# 8. Записать путь в конфиг iclaude
echo 'AUTORESEARCH_DIR=/path/to/new-dir' >> ~/.claude_config

# 9. Проверить готовность
./iclaude.sh --check-autoresearch

# 10. Запустить
./iclaude.sh --autoresearch
```

---

### Сценарий 3 — Подключить существующий ML-проект

```bash
# 1. Установить uv (если не установлен)
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

# 2. Перейти в проект и убедиться что git инициализирован
cd /path/to/existing-project
git status   # если ошибка "not a git repo" — выполнить: git init && git add . && git commit -m "initial"

# 3. Добавить pyproject.toml для uv (если нет)
#    Если есть requirements.txt — uv умеет его читать напрямую:
uv sync --requirements requirements.txt
#    Если нет — создать pyproject.toml вручную:
uv init --no-workspace
uv add $(cat requirements.txt | tr '\n' ' ')   # импортировать зависимости

# 4. Проверить вывод метрики в train.py
uv run python train.py 2>&1 | grep -E "val_bpb|val_loss|metric"
# Если метрика не выводится — добавить print() в конец train.py:
#   print(f"val_bpb={val_bpb:.4f}")

# 5. Создать program.md — инструкцию агенту
#    Минимальный шаблон:
cat > program.md << 'EOF'
# Цель
Оптимизировать <название метрики>. Улучшение = <↓ уменьшение / ↑ увеличение>.

# Метрика
Парсить из stdout: строка содержащая `<ключ>=<число>`

# Что можно менять
- (перечислить компоненты)

# Что НЕЛЬЗЯ менять
- (перечислить критические части)

# Ограничения
- Время прогона: не более N минут
EOF
$EDITOR program.md   # доработать под проект

# 6. Добавить .gitignore для data/ и checkpoints/ (чтобы агент не коммитил тяжёлые файлы)
cat >> .gitignore << 'EOF'
data/
checkpoints/
*.pt
*.pth
__pycache__/
.venv/
EOF
git add .gitignore pyproject.toml program.md
git commit -m "autoresearch: add config files"

# 7. Записать путь в конфиг iclaude
echo 'AUTORESEARCH_DIR=/path/to/existing-project' >> ~/.claude_config

# 8. Проверить готовность
./iclaude.sh --check-autoresearch

# 9. Запустить
./iclaude.sh --autoresearch
```

---

### Проверочный список перед первым запуском

| Шаг | Команда | Ожидаемый результат |
|-----|---------|---------------------|
| uv доступен | `uv --version` | Версия вида `uv 0.x.x` |
| train.py работает | `cd /dir && uv run python train.py` | Выводит метрику, exit code 0 |
| program.md существует | `ls /dir/program.md` | Файл найден |
| git инициализирован | `git -C /dir status` | Нет ошибки `not a git repo` |
| AUTORESEARCH_DIR задан | `grep AUTORESEARCH_DIR ~/.claude_config` | Путь к директории |
| iclaude готов | `./iclaude.sh --check-autoresearch` | Все проверки зелёные |

---

## Работа агента

### Что получает агент при запуске

`init_autoresearch()` экспортирует три переменные окружения перед `exec claude`:

| Переменная | Пример значения | Назначение |
|-----------|----------------|-----------|
| `AUTORESEARCH_DIR` | `/path/to/dir` | Агент знает где работать |
| `AUTORESEARCH_SESSION_ID` | `20260322-143012` | ID для git-веток и строк в results.tsv |
| `CLAUDE_SYSTEM_PROMPT` | (см. ниже) | Инструкция агенту |

### Формирование системного промпта

`lib/autoresearch/` конкатенирует базовый промпт и содержимое `program.md`:

```bash
_build_system_prompt() {
  local dir="$1"
  local session_id="$2"
  local max_iters="${AUTORESEARCH_MAX_ITERS:-0}"

  cat << EOF
Ты — агент автономных ML-экспериментов. Работай в директории: ${dir}
ID сессии: ${session_id}

Лимит экспериментов: ${max_iters} (0 = без лимита).
Счётчик сессии: файл ${dir}/.autoresearch_session, поле ITERS_DONE.

Инструмент запуска: Bash tool → uv run python train.py
Таймаут: ${AUTORESEARCH_UV_TIMEOUT:-600} секунд.

--- ИНСТРУКЦИИ ПРОЕКТА (program.md) ---
$(cat "${dir}/program.md")
--- КОНЕЦ ИНСТРУКЦИЙ ---

Правила работы:
1. После каждого эксперимента обновляй ITERS_DONE в .autoresearch_session
2. При exit code != 0 или отсутствии метрики — немедленно откатывай train.py
3. Пиши в results.tsv только через >> (append), никогда не перезаписывай файл
4. Коммить только при улучшении метрики; git_sha — из git rev-parse HEAD после коммита
5. При достижении MAX_ITERS — запиши [SESSION_END] в results.tsv и завершись
EOF
}

export CLAUDE_SYSTEM_PROMPT
CLAUDE_SYSTEM_PROMPT=$(_build_system_prompt "$AUTORESEARCH_DIR" "$AUTORESEARCH_SESSION_ID")
```

---

### Старт сессии

Поведение агента в первой итерации зависит от состояния `results.tsv`:

#### results.tsv пуст или не существует — установка baseline

```
1. Прочитать train.py — зафиксировать текущую архитектуру
2. Запустить: uv run python train.py 2>&1 | tee /tmp/train_out.txt
3. Распарсить метрику из /tmp/train_out.txt
4. Записать в results.tsv строку с пометкой "baseline":
   <timestamp>  <val_bpb>  -  <session_id>  baseline
5. НЕ делать git commit — baseline это отправная точка, не улучшение
6. Перейти к первому эксперименту
```

#### results.tsv содержит историю — продолжение

```
1. Прочитать results.tsv — найти лучший val_bpb (строки без [REJECTED])
2. Прочитать train.py — понять текущее состояние кода
3. Записать строку [SESSION_START]:
   <timestamp>  -  -  <session_id>  [SESSION_START] BRANCH_FROM=<значение>
4. Перейти к первому эксперименту текущей сессии
```

---

### Цикл эксперимента (детально)

```
┌─────────────────────────────────────────────────────────────┐
│  ИТЕРАЦИЯ N                                                  │
│                                                              │
│  1. ГИПОТЕЗА                                                 │
│     Проанализировать results.tsv: какие изменения уже        │
│     пробовались, что давало улучшение, что отвергалось.      │
│     Выдвинуть новую конкретную гипотезу.                     │
│                                                              │
│  2. ИЗМЕНЕНИЕ                                                │
│     Edit tool → train.py                                     │
│     Менять только то, что разрешено в program.md.            │
│     Одно логическое изменение за итерацию.                   │
│                                                              │
│  3. ЗАПУСК                                                   │
│     Bash: uv run python train.py 2>&1 | tee /tmp/out.txt    │
│                                                              │
│     ┌── exit code != 0? ──────────────────────────────────┐ │
│     │  git checkout -- train.py   (откат)                  │ │
│     │  Записать в results.tsv: [CRASH] + описание ошибки   │ │
│     │  → перейти к шагу 1 (новая гипотеза)                 │ │
│     └───────────────────────────────────────────────────── ┘ │
│                                                              │
│  4. ПАРСИНГ МЕТРИКИ                                          │
│     grep -oP 'val_bpb=\K[\d.]+' /tmp/out.txt | tail -1     │
│                                                              │
│     ┌── метрика не найдена? ──────────────────────────────┐ │
│     │  git checkout -- train.py   (откат)                  │ │
│     │  Записать в results.tsv: [NO_METRIC] + описание      │ │
│     │  → перейти к шагу 1                                   │ │
│     └───────────────────────────────────────────────────── ┘ │
│                                                              │
│  5. СРАВНЕНИЕ С BASELINE                                     │
│                                                              │
│     Улучшение (val_bpb < baseline):                          │
│       git add train.py                                       │
│       git commit -m "autoresearch: exp #N val_bpb=X.XXX <описание>" │
│       sha=$(git rev-parse HEAD)                              │
│       Записать в results.tsv:                                │
│         <ts>  <val_bpb>  <sha>  <session_id>  <описание>    │
│       Обновить baseline = val_bpb                            │
│                                                              │
│     Ухудшение (val_bpb >= baseline):                         │
│       git checkout -- train.py   (откат)                    │
│       Записать в results.tsv:                                │
│         <ts>  <val_bpb>  -  <session_id>  [REJECTED] <описание> │
│                                                              │
│  6. ОБНОВИТЬ СЧЁТЧИК                                         │
│     ITERS_DONE += 1  в .autoresearch_session                 │
│                                                              │
│     ┌── ITERS_DONE >= MAX_ITERS (и MAX_ITERS > 0)? ───────┐ │
│     │  Записать: [SESSION_END] лучший=<val_bpb> итого=N    │ │
│     │  Вывести summary в stdout                             │ │
│     │  ЗАВЕРШИТЬСЯ                                          │ │
│     └───────────────────────────────────────────────────── ┘ │
│                                                              │
│  → Перейти к итерации N+1                                   │
└─────────────────────────────────────────────────────────────┘
```

---

### Формат results.tsv

Полный формат с колонками `git_sha` и `session_id` (подробнее в разделе [Версионность](#версионность)):

```
# timestamp           val_bpb  git_sha  session_id       описание
2026-03-22T14:30:12  0.987    -        20260322-143012  baseline
2026-03-22T14:38:44  0.981    abc1234  20260322-143012  changed lr_schedule to cosine + warmup
2026-03-22T14:47:01  0.989    -        20260322-143012  [REJECTED] added dropout 0.2 to attention
2026-03-22T14:51:03  -        -        20260322-143012  [CRASH] KeyError: 'n_embd' — откат
2026-03-22T14:55:23  0.974    def5678  20260322-143012  increased batch_size 32→64 + adjusted lr
2026-03-22T14:55:23  -        -        20260322-143012  [SESSION_END] лучший=0.974 итого=4
2026-03-22T18:01:00  -        -        20260322-180045  [SESSION_START] BRANCH_FROM=last
2026-03-22T18:09:11  0.971    ghi9012  20260322-180045  reduced weight_decay 0.1→0.01
```

Разделитель — табуляция `\t`. Строки `[SESSION_START]`, `[SESSION_END]`, `[CRASH]`, `[NO_METRIC]`
имеют `-` в колонках `val_bpb` и `git_sha`.

---

### Формат git-коммитов

```bash
# Стандарт сообщения (агент должен следовать этому шаблону):
git commit -m "autoresearch: exp #N val_bpb=X.XXX <краткое описание изменения>"

# Примеры:
git commit -m "autoresearch: exp #3 val_bpb=0.974 batch_size 32→64 + lr scale"
git commit -m "autoresearch: exp #7 val_bpb=0.968 cosine warmup 100→500 steps"

# N — кросс-сессионный номер: wc -l results.tsv без служебных строк
```

---

### Управление контекстом в ходе сессии

Claude Code имеет конечное контекстное окно. По мере накопления итераций контекст заполняется
выводом `train.py`, содержимым `train.py`, сообщениями о коммитах. Агент получает инструкцию
в системном промпте:

```
Управление контекстом:
- Каждые 10 итераций: кратко суммируй эксперименты в одном сообщении вместо
  перечисления всех деталей. Опирайся на results.tsv как на внешнюю память.
- Не копируй полный вывод train.py в ответ — только строку с метрикой.
- Если чувствуешь приближение лимита контекста — заверши сессию досрочно с
  пометкой [SESSION_END context_limit].
```

Практическая ёмкость без специальных мер: **15–25 итераций** при типичном выводе `train.py`
(~500 строк). При компактном выводе (только метрика) — до **50 итераций**.

---

### Поведение при нештатных ситуациях

| Ситуация | Действие агента |
|---------|----------------|
| `train.py` завершился с ошибкой (exit != 0) | Откат `git checkout -- train.py`, запись `[CRASH]` |
| Метрика не найдена в stdout | Откат, запись `[NO_METRIC]` |
| `uv run` завис дольше таймаута | Bash tool прерывает процесс; откат, запись `[TIMEOUT]` |
| `git commit` не удался (нет изменений) | Пропустить коммит, записать результат без `git_sha` |
| Достигнут `MAX_ITERS` | Записать `[SESSION_END]`, вывести summary, завершиться |
| Две подряд итерации без метрики | Остановиться и сообщить пользователю о проблеме с `train.py` |

---

### Git-ветки

```bash
# Перед запуском iclaude создаёт ветку (стратегия зависит от BRANCH_FROM):
git checkout -b autoresearch/20260322-143012 <точка ветвления>

# Агент коммитит каждое улучшение:
git commit -m "autoresearch: exp #3 val_bpb=0.974 batch_size 32→64"

# После сессии — варианты merge:
# Вариант A: cherry-pick лучшего коммита (рекомендуется при BRANCH_FROM=main)
git checkout main
git cherry-pick def5678   # sha лучшего эксперимента из results.tsv

# Вариант B: ff-merge всей ветки (при BRANCH_FROM=last)
git checkout main
git merge --ff-only autoresearch/20260322-143012

# Просмотр результатов без merge
git log --oneline autoresearch/20260322-143012
git show def5678:train.py   # посмотреть train.py лучшего эксперимента
```

---

## Диагностика

### Быстрая проверка готовности

```bash
# Единая точка входа — проверяет всё сразу
./iclaude.sh --check-autoresearch /path/to/dir

# Ожидаемый вывод при успехе:
# [OK] uv доступен: uv 0.6.x
# [OK] train.py найден
# [OK] program.md найден
# [OK] pyproject.toml найден
# [OK] git репозиторий инициализирован
# [OK] uv venv готов (.venv существует)
# [OK] AUTORESEARCH_DIR задан
```

---

### Диагностика по слоям

#### Слой 1 — Зависимости окружения

```bash
# uv установлен и доступен в PATH?
uv --version
which uv
# Если не найден:
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc   # добавить ~/.local/bin в PATH

# Python доступен через uv?
uv python list     # список установленных версий Python
uv python install 3.11   # установить если список пуст

# Зависимости проекта установлены?
cd /path/to/dir
uv sync --dry-run  # показать что будет установлено без установки
uv sync            # установить
ls .venv/          # .venv должен существовать после sync
```

#### Слой 2 — Структура директории

```bash
dir=/path/to/autoresearch-dir

# Обязательные файлы
ls -la "$dir/train.py"   "$dir/program.md"
ls -la "$dir/pyproject.toml" 2>/dev/null || ls -la "$dir/requirements.txt" 2>/dev/null

# Git инициализирован?
git -C "$dir" status
# Если ошибка "not a git repo":
git -C "$dir" init && git -C "$dir" add . && git -C "$dir" commit -m "initial"

# .gitignore настроен (чтобы data/ и checkpoints/ не попали в коммит)?
cat "$dir/.gitignore"
git -C "$dir" status --short | grep -E "^\?\? (data|checkpoint|\.venv)"
# Если data/ или checkpoints/ видны как untracked — добавить в .gitignore
```

#### Слой 3 — train.py работает без агента

```bash
cd /path/to/dir

# Запуск с захватом вывода
uv run python train.py 2>&1 | tee /tmp/train_test.txt
echo "Exit code: $?"

# Метрика присутствует в выводе?
grep -oP 'val_bpb=\K[\d.]+' /tmp/train_test.txt | tail -1
# Если пусто — метрика не выводится, нужно добавить print() в train.py

# Время выполнения в пределах таймаута?
time uv run python train.py > /dev/null 2>&1
# Если дольше AUTORESEARCH_UV_TIMEOUT — увеличить переменную или уменьшить датасет
```

#### Слой 4 — Конфигурация iclaude

```bash
# AUTORESEARCH_DIR задан?
grep AUTORESEARCH ~/.claude_config

# Переменные применяются при запуске?
# (запустить iclaude с --autoresearch и внутри Claude Code выполнить через Bash tool:)
#   env | grep AUTORESEARCH
# Ожидается: AUTORESEARCH_DIR, AUTORESEARCH_SESSION_ID, AUTORESEARCH_MAX_ITERS

# Системный промпт формируется корректно?
# Внутри Claude Code → Bash tool:
#   echo "$CLAUDE_SYSTEM_PROMPT" | head -20
```

#### Слой 5 — Состояние текущей/прошлой сессии

```bash
dir=/path/to/dir

# Файл состояния сессии (создаётся init_autoresearch, удаляется по завершении)
cat "$dir/.autoresearch_session"
# Если остался после аварийного завершения — удалить вручную:
rm "$dir/.autoresearch_session"

# Git-ветки сессий
git -C "$dir" branch -a | grep autoresearch
git -C "$dir" log --oneline autoresearch/   # последние коммиты

# История экспериментов
cat "$dir/results.tsv"
# Статистика:
echo "Всего экспериментов: $(grep -vc '^\s*#\|SESSION' "$dir/results.tsv" 2>/dev/null)"
echo "Принято: $(grep -c 'REJECTED\|CRASH\|NO_METRIC' "$dir/results.tsv" | xargs -I{} expr $(grep -c . "$dir/results.tsv") - {})"
echo "Лучший val_bpb: $(grep -v 'REJECTED\|SESSION\|CRASH' "$dir/results.tsv" | awk '{print $2}' | grep -v '^-$' | sort -n | head -1)"
```

---

### Типичные ошибки и решения

| Ошибка | Причина | Решение |
|--------|---------|---------|
| `uv: command not found` | uv не установлен или не в PATH | `curl -LsSf https://astral.sh/uv/install.sh \| sh && source ~/.bashrc` |
| `train.py не найден` | Неверный `AUTORESEARCH_DIR` | `grep AUTORESEARCH_DIR ~/.claude_config` — проверить путь |
| `program.md не найден` | Забыли создать | Создать по шаблону из раздела [program.md](#programmd--инструкция-агенту) |
| `uv sync` падает | Конфликт зависимостей | `uv sync --resolution lowest` или `uv add <pkg> --upgrade` |
| Метрика не найдена (`[NO_METRIC]`) | `train.py` не выводит метрику | Добавить `print(f"val_bpb={val_bpb:.4f}")` в конец скрипта |
| `train.py` падает с ошибкой | Синтаксическая ошибка агента | Агент должен откатить сам; если нет — `git -C /dir checkout -- train.py` |
| `uv run` зависает | Обучение дольше таймаута | Увеличить `AUTORESEARCH_UV_TIMEOUT` или сократить `max_iters` в train.py |
| Агент не делает коммиты | Все гипотезы ухудшают метрику | Нормально; проверить `results.tsv` — все строки `[REJECTED]`? |
| Агент коммитит без улучшения | Неверный baseline в results.tsv | Проверить строку baseline в results.tsv, исправить вручную |
| `.autoresearch_session` остался | Аварийное завершение сессии | `rm /path/to/dir/.autoresearch_session` |
| `git commit` падает: `nothing to commit` | train.py не изменился | Агент не применил Edit tool; проверить лог Claude Code |
| Контекст заполняется быстро | Большой вывод train.py | Перенаправить verbose-вывод в файл: `train.py > /tmp/train.log 2>&1; tail -1 /tmp/train.log` |
| Ветка не создалась | Нет прав на запись в git | `git -C /dir config user.email` — убедиться что git настроен |

---

### Восстановление после сбоев

#### train.py повреждён агентом (не запускается)

```bash
# Откатить к последнему рабочему состоянию
git -C /path/to/dir checkout -- train.py

# Или к конкретному эксперименту по git_sha из results.tsv
git -C /path/to/dir checkout <sha> -- train.py

# Или к исходному состоянию main
git -C /path/to/dir checkout main -- train.py
```

#### results.tsv содержит некорректные строки

```bash
# Посмотреть проблемные строки
cat -A /path/to/dir/results.tsv | grep -v $'\t'   # строки без табуляции

# results.tsv — append-only, не редактировать напрямую
# Исключение: удалить последнюю незавершённую строку если сессия прервалась
# посередине записи:
head -n -1 /path/to/dir/results.tsv > /tmp/results_fixed.tsv
mv /tmp/results_fixed.tsv /path/to/dir/results.tsv
```

#### Сессия прервалась на полуслове (Ctrl+C, сбой сети)

```bash
# 1. Удалить файл состояния сессии
rm /path/to/dir/.autoresearch_session

# 2. Проверить есть ли незакоммиченные изменения train.py
git -C /path/to/dir status

# 3. Если train.py изменён но не закоммичен — решить: принять или откатить
git -C /path/to/dir diff -- train.py          # посмотреть изменения
git -C /path/to/dir checkout -- train.py      # откатить

# 4. Запустить новую сессию как обычно
./iclaude.sh --autoresearch /path/to/dir
# Агент прочитает results.tsv и продолжит с того места где остановился
```

---

## Когда выбрать этот вариант

### Дерево решений

```
Нужен autoresearch?
│
├─ Первый раз / хочется попробовать без лишней настройки?
│   └─ [A] ← ты здесь
│
├─ Нужно оставить работать на ночь / закрыть ноутбук?
│   └─ [B] Background Daemon
│
├─ Хочется видеть прогресс в строке статуса терминала?
│   └─ [B] Background Daemon
│
├─ Нужны параллельные гипотезы от разных LLM одновременно?
│   └─ [C] Multi-Agent Pool
│
└─ Устраивает [A], но хочется больше экспериментов за сессию?
    └─ [A] с MAX_ITERS=50 + компактный вывод train.py
```

---

### Подходит если

| Условие | Пояснение |
|--------|-----------|
| Первый запуск | Минимум настройки: только `uv` + `train.py` + `program.md` |
| Терминал открыт во время работы | Вариант A требует активной сессии Claude Code |
| Важна прозрачность | Каждый шаг агента виден в Claude Code UI в реальном времени |
| Достаточно одной гипотезы за раз | Последовательный перебор — стандартный режим autoresearch |
| Есть OAuth-токен (без API key) | Работает через `--oauth`, не требует `sk-ant-api03-...` |
| Нужен контроль над агентом | Можно прервать Ctrl+C, скорректировать `program.md`, перезапустить |
| Эксперимент занимает 2–8 часов | Укладывается в одну рабочую сессию |

---

### Не подходит если

| Условие | Альтернатива |
|--------|-------------|
| Нужно закрыть ноутбук / уйти на ночь | [Вариант B](VARIANT_B_BACKGROUND_DAEMON.md) — демон работает без терминала |
| Хочется мониторинг в строке статуса | [Вариант B](VARIANT_B_BACKGROUND_DAEMON.md) — интеграция со statusline |
| Нужны параллельные гипотезы (N агентов) | [Вариант C](VARIANT_C_MULTIAGENT_POOL.md) — пул агентов через Router |
| Нужен доступ к нескольким LLM | [Вариант C](VARIANT_C_MULTIAGENT_POOL.md) — DeepSeek, Gemini, Claude параллельно |
| Требуется HTTP API для внешнего мониторинга | [Вариант B](VARIANT_B_BACKGROUND_DAEMON.md) — встроенный status API |
| Эксперименты занимают >8 часов | [Вариант B](VARIANT_B_BACKGROUND_DAEMON.md) — нет зависимости от открытого терминала |
| Нет API key, только OAuth, но нужен B/C | Остаться на [A] или получить API key в `console.anthropic.com` |

---

### Trade-offs

| Аспект | Вариант A | Вариант B | Вариант C |
|--------|-----------|-----------|-----------|
| Сложность настройки | ~5 мин | ~15 мин | ~30 мин |
| Новый код (bash/python) | ≤200 LOC bash | ~300 LOC Python | ~500 LOC |
| Терминал нужен | Да | Нет | Да (master) |
| Параллельные агенты | 1 | 1 | N |
| Мониторинг | Claude Code UI | Statusline + HTTP API | Расширенный |
| OAuth без API key | Да | Нет | Нет |
| Прозрачность цикла | Высокая | Низкая (логи) | Средняя |
| Context limit риск | Есть (~15–50 exp) | Нет (новый процесс) | Нет |

---

### Типичный сценарий использования варианта A

```
09:00  ./iclaude.sh --autoresearch /path/to/nanoGPT
       → агент читает results.tsv, устанавливает baseline 0.987

09:05  Эксперимент #1: lr_schedule cosine → val_bpb=0.981 ✓ коммит
09:15  Эксперимент #2: dropout 0.2        → val_bpb=0.989 ✗ откат
09:25  Эксперимент #3: batch_size 64      → val_bpb=0.974 ✓ коммит
...

13:00  Достигнут MAX_ITERS=20, агент записывает [SESSION_END]
       Лучший результат: val_bpb=0.961 (exp #12, git_sha=abc1234)

13:05  git cherry-pick abc1234   # взять лучший эксперимент в main
       ./iclaude.sh --autoresearch   # запустить следующую сессию
```

---

## Связанная документация

- [docs/AUTORESEARCH.md](../AUTORESEARCH.md) — главный doc, сравнение вариантов
- [Вариант B — Background Daemon](VARIANT_B_BACKGROUND_DAEMON.md) — overnight-режим
- [Вариант C — Multi-Agent Pool](VARIANT_C_MULTIAGENT_POOL.md) — параллельные агенты
- [docs/PII_MASKING.md](../PII_MASKING.md) — PII proxy (совместим с этим вариантом)
- [docs/CONFIGURATION.md](../CONFIGURATION.md) — все переменные конфигурации
