---
wiki_sources: ["docs/functions/TELEMETRY.md"]
wiki_updated: 2026-05-05
wiki_status: stub
tags: [iclaude, features, telemetry, monitoring, cache]
aliases: ["мониторинг", "stats-cache", "метрики кэша", "статистика сессий"]
---

# Телеметрия и мониторинг

iclaude сохраняет данные о сессиях и использовании токенов в нескольких источниках данных. Анализ этих данных позволяет отслеживать эффективность кэша, стоимость и активность работы.

## Основные характеристики

### Источники данных

**1. `stats-cache.json` — агрегаты по всем сессиям**

Путь: `.nvm-isolated/.claude-isolated/stats-cache.json`

Содержит: `dailyActivity`, `dailyModelTokens`, `modelUsage` (включая `cacheReadInputTokens`, `cacheCreationInputTokens`), `totalSessions`, `hourCounts`.

Реальные данные (апрель 2026):

| Модель | Cache hit rate |
|--------|---------------|
| claude-sonnet-4-5 | ~94% |
| claude-opus-4-5 | ~91% |
| claude-sonnet-4-6 | ~91% |
| claude-haiku-4-5 | ~84% |
| claude-opus-4-6 | ~79% |

**2. `sessions/{pid}.json` — метаданные сессий**

Путь: `.nvm-isolated/.claude-isolated/sessions/`

Поля: `pid`, `sessionId`, `cwd`, `startedAt`, `kind`, `entrypoint`

**3. `history.jsonl` — история взаимодействий**

Путь: `.nvm-isolated/.claude-isolated/history.jsonl`

Поля: `display`, `pastedContents`, `timestamp`, `project`, `sessionId`. Не содержит API usage (токены, кэш).

**4. PII proxy `/api/metrics`**

```bash
curl http://127.0.0.1:9000/api/metrics
# → {masked_items_total, uptime_seconds, masking_level, log_level}
```

Доступно только при запуске с `--pii-proxy`.

## Связанные концепции

- [[функции/возможности/statusline]] — отображение метрик в реальном времени
- [[функции/возможности/pii-proxy]] — метрики маскирования PII
