---
wiki_sources:
  - "docs/functions/PII_MASKING.md"
  - "docs/functions/CONFIGURATION.md"
  - "docs/functions/TELEMETRY.md"
  - "docs/superpowers/specs/2026-05-07-pii-shared-detach-design.md"
  - "docs/superpowers/plans/2026-05-07-pii-shared-detach.md"
  - "lib/launcher/launch.sh"
  - "tests/test_pii_shared_detach.sh"
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
  - "shared proxy detach"
  - "setsid pii"
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

### Detach от process group мастера (fix 2026-05-07)

**Проблема.** До коммита `e52fc28f` shared-прокси умирал, когда мастер-сессия iclaude получала SIGHUP (закрытие терминала) или SIGINT (Ctrl-C). `lib/launcher/launch.sh` запускал `server.py` через bash `&` + `disown` — `disown` снимает задачу с job-control bash, но НЕ перемещает процесс в новую сессию/PG. Python-сервер наследовал PG, SID и controlling tty мастера; ядро доставляет PG-wide сигналы каждому члену группы, а `server.py` регистрирует SIGINT/SIGTERM как graceful shutdown. Параллельные consumer-сессии теряли `ANTHROPIC_BASE_URL`.

**Исправление.** Префикс `setsid` к invocation сервера + редирект `</dev/null`:

```bash
# Было (lib/launcher/launch.sh:964-970)
ANTHROPIC_UPSTREAM_URL="$_upstream" \
ICLAUDE_SESSION_ID="shared" \
PII_PROXY_LOG_LEVEL="${PII_PROXY_LOG_LEVEL:-info}" \
    "$python_bin" "$PII_PROXY_SERVER_SCRIPT" \
    --port "$PII_PROXY_PORT" \
    --log-dir "$PII_PROXY_LOG_DIR" \
    >/dev/null 2>&1 9>&- &

# Стало
ANTHROPIC_UPSTREAM_URL="$_upstream" \
ICLAUDE_SESSION_ID="shared" \
PII_PROXY_LOG_LEVEL="${PII_PROXY_LOG_LEVEL:-info}" \
    setsid "$python_bin" "$PII_PROXY_SERVER_SCRIPT" \
    --port "$PII_PROXY_PORT" \
    --log-dir "$PII_PROXY_LOG_DIR" \
    </dev/null >/dev/null 2>&1 9>&- &
```

Три изменения: (1) `setsid` создаёт новую сессию и PG для сервера, (2) `</dev/null` отвязывает stdin от controlling tty, (3) существующий `disown "$_proxy_pid"` сохранён.

**Что НЕ меняется.** `server.py` без правок. Reference-counting (consumers/ + flock) остаётся единственным триггером shutdown. Per-session CCR-ветка (lines 1088-1094) не затронута — CCR mode out of scope.

**Поведение по сценариям.**

| Сценарий | Поведение |
|---|---|
| Мастер закрыт через WM (SIGHUP) | Мастер умирает; trap может не сработать; **прокси выживает** (новая сессия). Stale consumer-файл сметает следующий start. |
| Мастер Ctrl-C (SIGINT) | Trap EXIT срабатывает, reference-counting decrement. Прокси выживает в любом случае. |
| Мастер SIGKILL | Нет trap, stale consumer. Следующий start: sweep + attach к живому прокси. |
| Последний consumer выходит | flock, count==0 → SIGTERM прокси. Same-uid SIGTERM работает независимо от detach. |
| `--pii-proxy --router` (CCR) | Не затронут — выделенный per-session прокси. |

**Регрессионный тест.** `tests/test_pii_shared_detach.sh` (commits `fb744b81`, `33d05a73`):

- **Assertion A (статика).** `grep` в `lib/launcher/launch.sh` на наличие `setsid "$python_bin" "$PII_PROXY_SERVER_SCRIPT"` и `</dev/null >/dev/null 2>&1 9>&-`. Падает, если fix откатили.
- **Assertion B (поведение).** Спавнит синтетический master через `setsid bash -c ...`, который запускает прокси по тому же idiom. Проверяет, что SID мастера и SID прокси различаются (`ps -o sid=`), затем `kill -HUP -$MASTER_PID` (PG-wide). Прокси должен выжить. Skip при отсутствии venv.

Запуск: `bash tests/test_pii_shared_detach.sh`.

**Проверка в проде.** Через `ps -o pid,sid,pgid,cmd -p "$(cat .nvm-isolated/.claude-isolated/pii-proxy-pid/shared.pid)"`. У живого прокси колонка `pid` должна равняться `sid` — он session leader.

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
