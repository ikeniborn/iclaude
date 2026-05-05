# Телеметрия и мониторинг iclaude

Исследование вариантов сбора статистики сессий, метрик кэша и эффективности работы с агентом.
Дата: 2026-04-14.

---

## Что уже есть: источники данных

### 1. `stats-cache.json` — агрегаты по всем сессиям

Путь: `.nvm-isolated/.claude-isolated/stats-cache.json`

**Содержит:**
- `dailyActivity[]` — по дням: messageCount, sessionCount, toolCallCount
- `dailyModelTokens[]` — по дням: токены по моделям (без разбивки по cache)
- `modelUsage{}` — **агрегаты по моделям за всё время**, включая:
  - `inputTokens`, `outputTokens`
  - **`cacheReadInputTokens`** ← cache hit данные
  - **`cacheCreationInputTokens`** ← cache miss данные
- `totalSessions`, `totalMessages`, `longestSession`, `hourCounts`

**Реальные данные (апрель 2026):**

| Модель | inputTokens | cacheReadTokens | cacheCreationTokens | Cache hit rate |
|---|---|---|---|---|
| claude-sonnet-4-5 | 1,416,214 | 3,120,038,021 | 176,383,736 | **~94%** |
| claude-opus-4-5 | 63,273 | 64,376,112 | 5,816,546 | ~91% |
| claude-sonnet-4-6 | 528,443 | 289,834,889 | 27,546,598 | ~91% |
| claude-haiku-4-5 | 548,546 | 45,082,450 | 7,643,618 | ~84% |
| claude-opus-4-6 | 61,455 | 3,123,027 | 758,971 | ~79% |

> **Вывод:** совокупные cache-метрики уже доступны. Но `dailyModelTokens` не включает
> разбивку cache/non-cache — только суммарные токены по моделям за день.

### 2. `sessions/{pid}.json` — метаданные сессий

Путь: `.nvm-isolated/.claude-isolated/sessions/`

Поля: `pid`, `sessionId`, `cwd`, `startedAt`, `kind`, `entrypoint`

### 3. `history.jsonl` — история взаимодействий

Путь: `.nvm-isolated/.claude-isolated/history.jsonl` (~2.1 MB)

Поля: `display`, `pastedContents`, `timestamp`, `project`, `sessionId`

> Содержит пользовательские сообщения и команды, но **не содержит** API usage (токены, cache).

### 4. PII proxy — `/api/metrics`

Путь: `lib/pii-proxy/server.py`

```
GET /api/metrics → {masked_items_total, uptime_seconds, masking_level, log_level}
```

Работает только при запуске с `--pii-proxy`.

### 5. Telemetry events SDK

Путь: `.nvm-isolated/.claude-isolated/telemetry/1p_failed_events.*.json`

Формат JSONL, каждая строка — событие `ClaudeCodeInternalEvent`.

**Доступные события:**

| event_name | Данные |
|---|---|
| `tengu_init` | entrypoint, dangerouslySkipPermissions, permissionMode |
| `tengu_api_query` | model, messagesLength, querySource, queryChainId, queryDepth |
| `tengu_api_cache_breakpoints` | totalMessageCount, **cachingEnabled** (bool) |
| `tengu_agent_tool_selected` | agent_type, model, source |
| `tengu_timer` | event ("startup"), durationMs |
| `tengu_startup_telemetry` | is_git, sandbox_enabled, worktree_count |
| `tengu_ripgrep_availability` | working, using_system |

> **Важно:** `tengu_api_cache_breakpoints` показывает только факт включения кэша,
> но **не содержит** числа токенов из API-ответа (cache_read_input_tokens и т.д.).
> Числовые cache-метрики в telemetry-файлах не обнаружены.

### 6. Security events

Файл: `/tmp/iclaude-security-event.json` (TTL: 30 сек)

Поля: `type`, `detail`, `ts`

---

## Что недоступно без новой инструментации

| Метрика | Проблема |
|---|---|
| Cache hit rate **по дням** | `dailyModelTokens` не содержит cache-разбивку |
| Длительность API-запросов | Нет таймингов в существующих данных |
| Tool calls по типам (Read/Edit/Bash) | Только общий toolCallCount в stats-cache |
| Количество security-блокировок | Файл `/tmp/` эфемерный, нет накопления |
| Стоимость по дням (USD) | `costUSD: 0` во всех записях modelUsage |

---

## Варианты архитектуры мониторинга

### Вариант 1: Файловый экспортёр (минималистичный)

```
Stop hook → session-summary.py → metrics/*.prom
  → Prometheus (file_sd_configs) → Grafana
```

**Что получаем:**
- Суммарные cache-метрики из `stats-cache.json` (aggregate per model)
- Длительность сессии (из startedAt/endedAt в sessions/)
- messageCount, toolCallCount per session

**Ограничения:**
- Нет daily cache breakdown
- Нет per-request таймингов
- Нет tool-type breakdown

**Сложность:** низкая, ~2-3 часа реализации.

---

### Вариант 2: Перехват в PII proxy (оптимальный)

```
Claude Code → PII proxy (модифицированный)
  → парсинг response.usage → in-memory метрики
  → GET /metrics (Prometheus format)
    → Prometheus → Grafana
```

**Что добавить в `server.py`:**

```python
# В обработчике upstream-ответа:
usage = response_body.get("usage", {})
_cache_read_tokens    += usage.get("cache_read_input_tokens", 0)
_cache_creation_tokens+= usage.get("cache_creation_input_tokens", 0)
_input_tokens         += usage.get("input_tokens", 0)
_output_tokens        += usage.get("output_tokens", 0)

# Расширить /metrics endpoint (Prometheus format):
# iclaude_cache_read_tokens_total{session="...",model="..."} 12345
# iclaude_cache_creation_tokens_total{...} 4567
# iclaude_api_requests_total{model="..."} 42
# iclaude_pii_masked_items_total 18
# iclaude_api_response_latency_ms_bucket{le="100"} 7
```

**Что получаем дополнительно:**
- Cache hit rate per request (daily granularity)
- API response latency (p50/p95/p99)
- PII masking count per session

**Ограничения:** работает только при `--pii-proxy`.

**Сложность:** средняя, ~4-6 часов.

---

### Вариант 3: Полный стек OpenTelemetry + Prometheus + Grafana

```
┌─────────────────────────────────────────────────────────┐
│  iclaude session                                        │
│                                                         │
│  PreToolUse hook ──→ otel-hook.py                       │
│  PostToolUse hook ──→ otel-hook.py ──→ OTLP gRPC :4317  │
│  Stop hook ──→ session-stop.py  ──→ Pushgateway :9091   │
│  PII proxy /metrics ←── Prometheus scrape               │
└─────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────┐
│  Docker Compose (monitoring stack)                      │
│                                                         │
│  otel-collector :4317/:4318                             │
│    └→ Prometheus exporter :8889                         │
│                                                         │
│  Prometheus :9090                                       │
│    scrape: otel-collector, pii-proxy, pushgateway       │
│    file_sd: monitoring/metrics/*.prom                   │
│                                                         │
│  Grafana :3000                                          │
│    dashboards: Session Analytics, Cache Efficiency,     │
│    Tool Usage, Security Events                          │
│                                                         │
│  Pushgateway :9091                                      │
│    ← Stop hook (session summary)                        │
└─────────────────────────────────────────────────────────┘
```

**Новые хуки:**

| Хук | Тип | Данные |
|---|---|---|
| `otel-hook.py` | PostToolUse | span: tool_name, duration_ms, success |
| `session-stop.py` | Stop | session summary → Pushgateway |
| `security-metrics.py` | PreToolUse (расширение block-secrets) | counter: blocked_by_pattern |

**Что получаем дополнительно:**
- Tool call duration per type (Read/Edit/Bash/Write)
- Tool error rate
- Security blocks с детализацией по паттернам
- Session duration distribution

**Docker Compose (`monitoring/docker-compose.yml`):**

```yaml
services:
  prometheus:
    image: prom/prometheus:v2.51.0
    ports: ["9090:9090"]
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./metrics:/metrics:ro
      - prometheus_data:/prometheus

  grafana:
    image: grafana/grafana:10.4.0
    ports: ["3000:3000"]
    environment:
      GF_SECURITY_ADMIN_PASSWORD: iclaude
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards

  pushgateway:
    image: prom/pushgateway:v1.8.0
    ports: ["9091:9091"]

  otel-collector:
    image: otel/opentelemetry-collector:0.99.0
    ports: ["4317:4317", "4318:4318", "8889:8889"]
    volumes:
      - ./otel-collector.yml:/etc/otelcol/config.yaml
```

**Ограничения:** требует Docker, задержка +3-5ms на hook при OTLP push.

**Сложность:** высокая, ~2-3 дня реализации.

---

## Дашборды Grafana: ключевые панели

### Dashboard 1: Session Analytics

- Messages per session (histogram)
- Tool calls per session (histogram)
- Sessions by hour of day (heatmap из hourCounts)
- Longest session duration

### Dashboard 2: Cache Efficiency

- Cache hit rate по времени (требует PII proxy или Stop hook)
- Cache read tokens saved (read × 0.9 × price/token)
- Cache creation vs read ratio
- **Уже доступно из stats-cache.json:** aggregate hit rate per model

### Dashboard 3: Tool Usage

- Tool calls by type (Read/Edit/Bash/Write/Grep)
- Tool error rate
- Tool duration p95 (требует PostToolUse hook)

### Dashboard 4: Security

- Blocks by pattern type (requires hook extension)
- PII masked items (из PII proxy /metrics)
- Security events timeline

---

## Рекомендуемый порядок реализации

**Этап 1 (быстрый win, 1 день):**
1. Stop hook: `hooks/session-stop.py` — при завершении сессии читает stats-cache.json,
   пишет `monitoring/metrics/session.prom` (Prometheus textfile format)
2. Docker Compose: Prometheus + Grafana (без OTEL, без Pushgateway)
3. Дашборд: aggregate cache hit rate + daily activity (из уже готовых данных)

**Этап 2 (per-day cache, 3-4 часа):**
4. Расширить `lib/pii-proxy/server.py`: добавить `/metrics` в Prometheus формате
   с per-request cache breakdown
5. Подключить scrape PII proxy → Prometheus

**Этап 3 (полный стек, 2-3 дня):**
6. `hooks/otel-hook.py` — PostToolUse spans
7. Pushgateway для session summaries
8. otel-collector в Docker Compose
9. Дашборды: tool heatmap, latency percentiles

---

## Инструкция по запуску стека (Этап 1)

```bash
# 1. Создать директорию для метрик
mkdir -p monitoring/metrics

# 2. Запустить стек
cd monitoring && docker compose up -d

# 3. Grafana: http://localhost:3000 (admin/iclaude)
# 4. Prometheus: http://localhost:9090

# 5. Тест: сгенерировать метрики вручную
python3 .nvm-isolated/.claude-isolated/hooks/session-stop.py
cat monitoring/metrics/session.prom
```

---

## Источники данных: итоговая таблица

| Источник | Метрики | Доступность | Cache data |
|---|---|---|---|
| `stats-cache.json` | messages, sessions, tools, tokens | Всегда | Агрегат (не по дням) |
| `sessions/*.json` | session_id, startedAt, cwd | Всегда | Нет |
| `history.jsonl` | user messages | Всегда | Нет |
| PII proxy `/metrics` | masked_items, uptime | Только `--pii-proxy` | Per-request |
| PII proxy `/metrics` (расшир.) | cache tokens, latency | Только `--pii-proxy` | Per-day |
| `telemetry/*.json` | tool usage, agent_type | Всегда | cachingEnabled (bool) |
| Stop hook → `.prom` | session summary | После реализации | Из stats-cache |
| PostToolUse → OTEL | tool duration, errors | После реализации | Нет |
