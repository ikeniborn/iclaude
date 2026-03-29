# Вариант B — Background Daemon

Сервисная модель: autoresearch работает как фоновый Python-демон. Запустил — закрыл
терминал — утром смотришь результаты. Интеграция со statusline показывает прогресс
в строке состояния без открытых сессий Claude Code.

---

## Содержание

- [Архитектура](#архитектура)
- [Цепочка запуска](#цепочка-запуска)
- [HTTP Status API](#http-status-api)
- [Интеграция со statusline](#интеграция-со-statusline)
- [Новые файлы](#новые-файлы)
- [Новые флаги CLI](#новые-флаги-cli)
- [Конфигурация](#конфигурация)
- [Установка](#установка)
- [Протокол эксперимента](#протокол-эксперимента)
- [Диагностика](#диагностика)
- [Когда выбрать этот вариант](#когда-выбрать-этот-вариант)
- [Связанная документация](#связанная-документация)

---

## Архитектура

```
./iclaude.sh --autoresearch-start /path/to/dir
       │
       ├─ detect_autoresearch()      — uv, train.py, program.md
       ├─ detect_anthropic_sdk()     — pip/uv: anthropic пакет
       ├─ init_autoresearch_session()
       │   ├─ SESSION_ID=YYMMDD-HHMMSS
       │   ├─ SESSION_DIR=~/.cache/iclaude/autoresearch/SESSION_ID/
       │   ├─ git branch autoresearch/SESSION_ID
       │   └─ touch results.jsonl
       │
       └─ spawn_autoresearch_daemon()
               │
               nohup python3 lib/autoresearch/agent.py \
                 --dir /path/to/dir \
                 --session SESSION_ID \
                 --port 18640 \
                 &> SESSION_DIR/daemon.log &
               echo $! > SESSION_DIR/daemon.pid
               │
               └─ agent.py (background, PID в session dir)
                     │
                     ├─ HTTP server :18640 (status API)
                     │
                     └─ Experiment loop (infinite):
                           1. Прочитать program.md, train.py, results.jsonl
                           2. POST /v1/messages → Claude API (generate hypothesis)
                              Payload: { role: user, content: state + program }
                           3. Применить патч: patch train.py
                           4. git commit -m "hypothesis: ..."  ← hypothesis commit
                           5. uv run train.py (timeout ~600s)
                           6. Парсить val_bpb из stdout
                           7. Если val_bpb улучшился:
                              - Записать в results.jsonl
                              - Обновить статус-файл → statusline
                           8. Если ухудшился:
                              - git reset --hard HEAD~1  ← отменить hypothesis commit
                              - Записать как [REJECTED] в results.jsonl
                           9. Обновить ~/.cache/iclaude/autoresearch-status.json
                          10. Повторить


PII proxy (опционально, --pii-proxy):
  agent.py → POST → PII:9000 → Anthropic API
  (маскирует данные перед отправкой)
```

---

## Цепочка запуска

```
Базовый:    daemon → ANTHROPIC_API_KEY ───────→ Anthropic API
С PII:      daemon → PII:9000 ────────────────→ Anthropic API
С proxy:    daemon → HTTPS_PROXY ─────────────→ Anthropic API
С PII+proxy: daemon → PII:9000 → HTTPS_PROXY → Anthropic API
```

> **Важно:** Daemon использует прямой Anthropic API (требует `ANTHROPIC_API_KEY`),
> НЕ OAuth-токен. OAuth-токен (`sk-ant-oat01-...`) не поддерживается `anthropic` SDK.
> Получить API key: [console.anthropic.com](https://console.anthropic.com).

---

## HTTP Status API

Демон поднимает HTTP-сервер на порту `:18640`:

| Endpoint | Метод | Описание |
|----------|-------|----------|
| `/status` | GET | Текущий эксперимент, val_bpb, статистика |
| `/results` | GET | Полный results.jsonl |
| `/log` | GET | Последние N строк daemon.log |
| `/stop` | POST | Graceful shutdown (после текущего прогона) |

### Пример ответа GET /status

```json
{
  "session_id": "20260322-143012",
  "status": "running",
  "experiment_num": 47,
  "current_hypothesis": "increase attention heads 8→16",
  "baseline_val_bpb": 0.987,
  "best_val_bpb": 0.961,
  "last_val_bpb": 0.961,
  "experiments_total": 47,
  "experiments_improved": 12,
  "uptime_hours": 8.3,
  "eta_current_experiment_min": 3
}
```

```bash
# Проверить статус напрямую
curl http://localhost:18640/status | jq .

# Остановить демон
curl -X POST http://localhost:18640/stop
```

---

## Интеграция со statusline

Демон каждые 30 секунд обновляет файл `~/.cache/iclaude/autoresearch-status.json`.
Statusline iclaude читает этот файл и добавляет блок в строку состояния терминала.

```
Вид в терминале (oh-my-posh или bash statusline):

  ┌─[user@host] [~/project] [git:main]
  ├─[context: 45%] [cache: $0.12]
  └─[exp 47/∞ | val_bpb 0.961 ↓] $

           ↑
   Autoresearch block — показывает номер эксперимента и лучший val_bpb
   ↓ означает улучшение (↑ = ухудшение, → = без изменений)
```

### Формат autoresearch-status.json

```json
{
  "active": true,
  "session_id": "20260322-143012",
  "exp": 47,
  "val_bpb": 0.961,
  "trend": "down",
  "pid": 12345
}
```

---

## Новые файлы

```
lib/autoresearch/
├── detect.sh       — проверка uv, train.py, program.md, anthropic SDK
├── install.sh      — установка uv + pip install anthropic aiohttp
├── status.sh       — обертка для --autoresearch-status
├── daemon.sh       — spawn/stop/status демона (bash)
└── agent.py        — Python агент (~300 LOC):
                        - asyncio HTTP server (порт 18640, aiohttp)
                        - Anthropic API client
                        - Experiment loop
                        - git operations
                        - results.jsonl writer
                        - statusline updater
```

### Структура agent.py

```python
# lib/autoresearch/agent.py — структура (~300 LOC)

import asyncio, os, json, argparse
from pathlib import Path
from anthropic import AsyncAnthropic   # AsyncAnthropic — не блокирует event loop
from aiohttp import web

class AutoresearchAgent:
    def __init__(self, dir, session_id, port, pii_proxy_url=None):
        self.dir = Path(dir)
        self.session_id = session_id
        self.client = AsyncAnthropic(
            base_url=pii_proxy_url or "https://api.anthropic.com"
        )
        self.results = []
        self.exp_num = 0

    async def run_experiment_loop(self):
        while True:
            hypothesis = await self.generate_hypothesis()
            await self.apply_patch(hypothesis)
            val_bpb = await self.run_training()
            self.evaluate_result(val_bpb, hypothesis)
            self.update_statusline()

    async def generate_hypothesis(self) -> dict:
        state = self.build_state_context()
        # await — не блокирует event loop во время API-запроса
        response = await self.client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=2048,
            messages=[{"role": "user", "content": state}]
        )
        return parse_hypothesis(response.content[0].text)

    async def run_training(self) -> float:
        # asyncio.create_subprocess_exec — не блокирует event loop во время обучения
        # subprocess.run здесь нельзя: заморозит HTTP-сервер на ~5 мин
        proc = await asyncio.create_subprocess_exec(
            "uv", "run", "train.py",
            cwd=self.dir,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT
        )
        timeout = int(os.environ.get("AUTORESEARCH_UV_TIMEOUT", 600))
        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=timeout)
        return parse_val_bpb(stdout.decode())
```

---

## Новые флаги CLI

```bash
--install-autoresearch          # uv + anthropic SDK
--check-autoresearch            # статус всех компонентов
--autoresearch-start [path]     # запустить демон
--autoresearch-stop             # остановить демон (graceful)
--autoresearch-status           # текущий эксперимент + trend
--autoresearch-log              # tail results.jsonl
```

### Примеры

```bash
# Установка
./iclaude.sh --install-autoresearch

# Запуск демона (overnight)
./iclaude.sh --autoresearch-start /path/to/autoresearch-dir

# С PII proxy (маскировка данных)
./iclaude.sh --autoresearch-start /path/to/dir --pii-proxy

# Утром — проверить результаты
./iclaude.sh --autoresearch-status
./iclaude.sh --autoresearch-log

# Остановить
./iclaude.sh --autoresearch-stop

# Напрямую через HTTP API
curl http://localhost:18640/status | jq '.best_val_bpb, .experiment_num'
```

---

## Конфигурация

| Переменная | По умолчанию | Описание |
|-----------|--------------|----------|
| `AUTORESEARCH_DIR` | (пусто) | Путь к директории |
| `AUTORESEARCH_SKIP_PREPARE` | `false` | Пропустить `prepare.py` |
| `AUTORESEARCH_DAEMON_PORT` | `18640` | Порт HTTP status API |
| `AUTORESEARCH_DAEMON_MODEL` | `claude-sonnet-4-6` | Модель Anthropic API |
| `AUTORESEARCH_UV_TIMEOUT` | `600` | Таймаут `uv run train.py` (сек) |
| `AUTORESEARCH_LOG_KEEP_DAYS` | `7` | Хранить логи N дней |
| `AUTORESEARCH_STATUS_UPDATE_SEC` | `30` | Интервал обновления statusline |

### Пример .claude_config

```bash
# autoresearch (вариант B)
AUTORESEARCH_DIR=/home/user/projects/nanoGPT-autoresearch
AUTORESEARCH_DAEMON_PORT=18640
AUTORESEARCH_DAEMON_MODEL=claude-sonnet-4-6
AUTORESEARCH_UV_TIMEOUT=600
ANTHROPIC_API_KEY=sk-ant-api03-...   # реальный API key (не OAuth)
```

---

## Установка

```bash
# 1. Установить uv
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

# 2. Установить зависимости daemon
pip install anthropic aiohttp  # или: uv pip install anthropic aiohttp

# 3. Настроить API key в .claude_config
echo 'ANTHROPIC_API_KEY=sk-ant-api03-...' >> ~/.claude_config
chmod 600 ~/.claude_config

# 4. Подготовить autoresearch-директорию
cd /path/to/autoresearch-dir
uv sync
uv run python prepare.py    # однократно

# 5. Установить через iclaude
./iclaude.sh --install-autoresearch

# 6. Проверка
./iclaude.sh --check-autoresearch

# 7. Первый запуск (дневной тест)
./iclaude.sh --autoresearch-start /path/to/dir

# Через 10 минут проверить
./iclaude.sh --autoresearch-status
```

---

## Протокол эксперимента

### Директория сессии

```
$HOME/.cache/iclaude/autoresearch/
└── 20260322-143012/
    ├── daemon.pid          — PID процесса
    ├── daemon.log          — полный лог
    ├── results.jsonl       — результаты экспериментов
    └── status.json         — обновляется демоном каждые 30 сек
                              (симлинкован из $HOME/.cache/iclaude/autoresearch-status.json)
```

### Формат results.jsonl

```jsonl
{"exp": 1, "ts": "2026-03-22T14:30:12Z", "val_bpb": 0.987, "status": "baseline", "desc": "initial state"}
{"exp": 2, "ts": "2026-03-22T14:38:44Z", "val_bpb": 0.981, "status": "improved", "desc": "cosine lr schedule"}
{"exp": 3, "ts": "2026-03-22T14:47:01Z", "val_bpb": 0.989, "status": "rejected", "desc": "dropout 0.2 attention"}
{"exp": 4, "ts": "2026-03-22T14:55:23Z", "val_bpb": 0.974, "status": "improved", "desc": "batch_size 32→64"}
```

### Git-ветки сессии

```bash
# Демон создаёт ветку при старте
git checkout -b autoresearch/20260322-143012

# Каждый эксперимент — отдельный коммит (если улучшение)
git log --oneline autoresearch/20260322-143012
# a3f7d21 autoresearch: exp #4 val_bpb=0.974 batch_size 32→64
# 8c2e105 autoresearch: exp #2 val_bpb=0.981 cosine lr schedule
# b9a1f34 autoresearch: baseline val_bpb=0.987

# После overnight — смёрджить вручную
git checkout main
git merge autoresearch/20260322-143012
```

---

## Диагностика

```bash
# Проверить, запущен ли демон
./iclaude.sh --autoresearch-status

# Прямая проверка PID
SESSION_DIR="$HOME/.cache/iclaude/autoresearch/$(ls -t "$HOME/.cache/iclaude/autoresearch/" | head -1)"
cat "$SESSION_DIR/daemon.pid"
ps -p "$(cat "$SESSION_DIR/daemon.pid")"

# Логи демона
tail -50 "$SESSION_DIR/daemon.log"

# Принудительная остановка (если graceful не работает)
kill "$(cat "$SESSION_DIR/daemon.pid")"

# HTTP API
curl http://localhost:18640/status
curl http://localhost:18640/results | python3 -m json.tool
```

### Типичные ошибки

| Ошибка | Причина | Решение |
|--------|---------|---------|
| `ANTHROPIC_API_KEY не задан` | Нет API key | Добавить в `.claude_config` |
| `anthropic module not found` | SDK не установлен | `pip install anthropic` |
| `port 18640 already in use` | Демон уже запущен | `./iclaude.sh --autoresearch-stop` |
| Statusline не показывает статус | Нет `autoresearch-status.json` | Демон не запущен или путь неверен |
| `uv run` не находит GPU | GPU недоступен | Проверить CUDA/ROCM в окружении |
| Демон завис | Долгий прогон | Увеличить `AUTORESEARCH_UV_TIMEOUT` |

---

## Когда выбрать этот вариант

### Подходит если:

- Нужен overnight-режим — запустить, закрыть ноутбук, утром результаты
- Важен мониторинг в строке состояния терминала (statusline)
- Есть реальный `ANTHROPIC_API_KEY` (не только OAuth-токен)
- Нужен HTTP API для внешнего мониторинга или Grafana
- Один агент достаточен, но нужна надёжность

### Не подходит если:

- Только OAuth-токен (нет API key) → [Вариант A](VARIANT_A_THIN_ORCHESTRATOR.md)
- Нужна прозрачность шагов агента → [Вариант A](VARIANT_A_THIN_ORCHESTRATOR.md)
- Нужны параллельные гипотезы → [Вариант C](VARIANT_C_MULTIAGENT_POOL.md)
- Нет желания настраивать Python-демон → [Вариант A](VARIANT_A_THIN_ORCHESTRATOR.md)

### Trade-offs

| + Плюсы | - Минусы |
|---------|---------|
| Overnight без открытого терминала | Нужен реальный API key |
| Statusline мониторинг в реальном времени | Python daemon (+зависимость anthropic SDK) |
| HTTP API для внешнего мониторинга | Сложнее тестировать |
| Graceful shutdown (не теряет прогресс) | 15 минут на начальную настройку |
| Надёжный лог в results.jsonl | Нет параллельности |

---

## Связанная документация

- [docs/AUTORESEARCH.md](../AUTORESEARCH.md) — главный doc, сравнение вариантов
- [Вариант A — Thin Orchestrator](VARIANT_A_THIN_ORCHESTRATOR.md) — простой запуск
- [Вариант C — Multi-Agent Pool](VARIANT_C_MULTIAGENT_POOL.md) — параллельные агенты
- [docs/PII_MASKING.md](../PII_MASKING.md) — PII proxy (интеграция через `--pii-proxy`)
- [docs/STATUSLINE.md](../STATUSLINE.md) — строка статуса терминала
- [docs/CONFIGURATION.md](../CONFIGURATION.md) — все переменные конфигурации
