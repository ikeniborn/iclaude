# Community 17

> 29 nodes · cohesion 0.07

## Key Concepts

- **Телеметрия и мониторинг iclaude** (8 connections) — `docs/functions/TELEMETRY.md`
- **Что уже есть: источники данных** (7 connections) — `docs/functions/TELEMETRY.md`
- **Дашборды Grafana: ключевые панели** (5 connections) — `docs/functions/TELEMETRY.md`
- **Варианты архитектуры мониторинга** (4 connections) — `docs/functions/TELEMETRY.md`
- **Вариант 2: Перехват в PII proxy (оптимальный)** (3 connections) — `docs/functions/TELEMETRY.md`
- **Вариант 3: Полный стек OpenTelemetry + Prometheus + Grafana** (3 connections) — `docs/functions/TELEMETRY.md`
- **Вариант 1: Файловый экспортёр (минималистичный)** (2 connections) — `docs/functions/TELEMETRY.md`
- **Инструкция по запуску стека (Этап 1)** (2 connections) — `docs/functions/TELEMETRY.md`
- **4. PII proxy — `/api/metrics`** (2 connections) — `docs/functions/TELEMETRY.md`
- **TELEMETRY.md** (1 connections) — `docs/functions/TELEMETRY.md`
- **1. `stats-cache.json` — агрегаты по всем сессиям** (1 connections) — `docs/functions/TELEMETRY.md`
- **Рекомендуемый порядок реализации** (1 connections) — `docs/functions/TELEMETRY.md`
- **2. `sessions/{pid}.json` — метаданные сессий** (1 connections) — `docs/functions/TELEMETRY.md`
- **Источники данных: итоговая таблица** (1 connections) — `docs/functions/TELEMETRY.md`
- **3. `history.jsonl` — история взаимодействий** (1 connections) — `docs/functions/TELEMETRY.md`
- **5. Telemetry events SDK** (1 connections) — `docs/functions/TELEMETRY.md`
- **6. Security events** (1 connections) — `docs/functions/TELEMETRY.md`
- **Что недоступно без новой инструментации** (1 connections) — `docs/functions/TELEMETRY.md`
- **code:block1 (GET /api/metrics → {masked_items_total, uptime_seconds, mask)** (1 connections) — `docs/functions/TELEMETRY.md`
- **code:block2 (Stop hook → session-summary.py → metrics/*.prom)** (1 connections) — `docs/functions/TELEMETRY.md`
- **code:block3 (Claude Code → PII proxy (модифицированный))** (1 connections) — `docs/functions/TELEMETRY.md`
- **code:python (# В обработчике upstream-ответа:)** (1 connections) — `docs/functions/TELEMETRY.md`
- **code:block5 (┌─────────────────────────────────────────────────────────┐)** (1 connections) — `docs/functions/TELEMETRY.md`
- **code:yaml (services:)** (1 connections) — `docs/functions/TELEMETRY.md`
- **code:bash (# 1. Создать директорию для метрик)** (1 connections) — `docs/functions/TELEMETRY.md`
- *... and 4 more nodes in this community*

## Relationships

- No strong cross-community connections detected

## Source Files

- `docs/functions/TELEMETRY.md`

## Audit Trail

- EXTRACTED: 56 (100%)
- INFERRED: 0 (0%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*