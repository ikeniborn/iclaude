---
wiki_sources:
  - "docs/architecture/statusline-architecture.md"
wiki_updated: 2026-05-05
wiki_status: developing
tags:
  - architecture
  - iclaude
aliases:
  - "строка статуса"
  - "claude-statusline.sh"
  - "Status Line"
---

# Status Line

Встроенный компонент real-time мониторинга для Claude Code. Отображает информацию о токенах, стоимости, кэше, прокси, роутере и git-статусе в нижней части UI.

## Основные характеристики

**Файл:** `.nvm-isolated/.claude-isolated/scripts/claude-statusline.sh` (275 строк)
**Версия:** 2.0.0 (Phase 2, 2026-02-12)
**Конфигурация:** `settings.json` → `statusLine.command`

### Формат вывода

```
💳 112K | 📊 50K (25%) | 📦 79K | Sonnet 4.5 | $1.06 | 🌐 | 🔀provider | 📄 | 🔱 main ●2 ↑1
```

| Компонент | Описание |
|-----------|---------|
| `💳 112K` | Кумулятивные токены (billing за всю сессию) |
| `📊 50K (25%)` | Активный контекст с процентом (цветовое кодирование) |
| `📦 79K` | Токены кэша |
| `Sonnet 4.5` | Имя модели |
| `$1.06` | Стоимость сессии |
| `🌐` | Индикатор активного прокси |
| `🔀provider` | Имя провайдера роутера |
| `📄` | Кликабельная ссылка на readable-сессию (OSC 8) |
| `🔱 main ●2 ↑1` | Git: ветка, незакоммиченные изменения, commits ahead |

### Цветовое кодирование контекста

| Процент | Цвет |
|---------|------|
| < 50% | Зелёный |
| 50–75% | Жёлтый |
| ≥ 75% | Красный |

### Конвейер обработки

1. **Parse Session Data** (jq) — извлечение токенов, стоимости, модели
2. **Detect Environment** — проверка прокси, роутера, git-статус (timeout 2s)
3. **Generate Readable Session** (mtime-кэш) — парсинг JSONL → читаемый текст
4. **Format Output** — цветовое кодирование, OSC 8 hyperlink, итоговая строка

### Readable Session (Phase 2)

Функция `generate_readable_session()`:
- Проверяет mtime: если readable-файл новее JSONL → пропускает регенерацию
- Парсит роли (user/assistant) и контент (text, thinking)
- Форматирует с префиксами (`👤 USER:`, `🤖 ASSISTANT:`)
- Word wrap: 80 символов (`fold -w 80 -s`)
- Кэш: `tmp/claude-session-readable.txt`

**Производительность mtime-кэша:**
- Cache hit: ~0ms
- Полная регенерация (500KB JSONL): ~150ms

### Ключевые зависимости

| Компонент | Версия | Назначение |
|-----------|--------|-----------|
| jq | 1.7.1 | Парсинг JSON (`.nvm-isolated/npm-global/bin/jq`) |
| git | любая | Branch/status info |
| oh-my-posh | опционально | Расширенный git rendering |
| Claude Code | v2.1+ | Использует вложенный объект `context_window` |

### Структура входных данных (STDIN от Claude Code)

```json
{
  "context_window": {
    "total_input_tokens": 50000,
    "total_output_tokens": 10000,
    "used_percentage": 30.0,
    "context_window_size": 200000,
    "current_usage": {
      "cache_read_input_tokens": 5000,
      "cache_creation_input_tokens": 1000
    }
  },
  "cost": { "total_cost_usd": 1.23 },
  "model": { "display_name": "Sonnet 4.5" },
  "transcript_path": "/path/to/session.jsonl"
}
```

## Связанные концепции

- [[../концепции/prompt-caching]]
