# Дизайн: CLAUDE_CODE_SKIP_PERMISSIONS + расширение .claude_config.example

**Дата:** 2026-05-05  
**Статус:** Одобрен

## Цель

1. Добавить поддержку переменной `CLAUDE_CODE_SKIP_PERMISSIONS` в `.claude_config` для включения режима bypass permissions без CLI-флага `--no-save`.
2. Дополнить `.claude_config.example` ~25 практически полезными переменными Claude Code из официальной документации.

---

## Часть 1 — Переменная CLAUDE_CODE_SKIP_PERMISSIONS

### Семантика

- Значение `true` включает передачу `--dangerously-skip-permissions` при запуске Claude Code.
- CLI-флаг `--no-save` имеет приоритет над конфигом: если задан, `skip_permissions=true` независимо от конфига.

Таблица приоритетов:

| CLAUDE_CODE_SKIP_PERMISSIONS | --no-save | Результат |
|------------------------------|-----------|-----------|
| не задан / false             | нет       | безопасный режим |
| true                         | нет       | bypass permissions |
| любое                        | да        | bypass permissions |

### Изменения в коде

**`lib/core/init.sh` — `init_environment()`:**

```bash
# Добавить после блока чтения конфига:
skip_permissions="${CLAUDE_CODE_SKIP_PERMISSIONS:-false}"
```

Переменная читается через паттерн `${VAR:-default}`, идентичный остальным конфиг-переменным в `init_environment()`.

**`iclaude.sh`:**

- Удалить строку `skip_permissions=false` (строка 188) — значение теперь приходит из `init_environment()`.
- В обработчике `--no-save` (строка 544) оставить `skip_permissions=true` без изменений — CLI по-прежнему принудительно выставляет `true`.

**Остальной код не меняется** — строки 664–666 и 773–775 уже корректно проверяют `$skip_permissions`.

---

## Часть 2 — Расширение .claude_config.example

### Новые переменные (~25 штук)

Добавляются в существующую секцию «НАСТРОЙКИ CLAUDE CODE» (после строки 139) и в отдельные тематические подсекции ниже. Все переменные закомментированы по умолчанию; каждая имеет описание на русском.

**Безопасность**
- `CLAUDE_CODE_SKIP_PERMISSIONS` — включает `--dangerously-skip-permissions`

**API / сеть**
- `ANTHROPIC_BASE_URL` — переопределяет endpoint API (кастомный gateway / прокси)
- `ANTHROPIC_AUTH_TOKEN` — альтернативный токен для корпоративных AI-gateway
- `NODE_EXTRA_CA_CERTS` — дополнительные CA-сертификаты для Node.js

**Контекст / память**
- `CLAUDE_CODE_MAX_CONTEXT_TOKENS` — лимит контекстного окна
- `CLAUDE_CODE_DISABLE_AUTO_MEMORY` — отключить автоматическую память
- `CLAUDE_CODE_AUTO_COMPACT_WINDOW` — переопределить размер окна авто-компакции
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` — порог авто-компакции в % от контекста

**Производительность**
- `CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY` — параллелизм вызовов инструментов
- `BASH_MAX_OUTPUT_LENGTH` — лимит вывода Bash-инструмента
- `CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` — лимит токенов при чтении файлов
- `MAX_THINKING_TOKENS` — бюджет токенов для extended thinking (при `DISABLE_ADAPTIVE_THINKING=1`)

**Дисплей / UI**
- `CLAUDE_CODE_HIDE_CWD` — скрыть рабочую директорию в логотипе запуска
- `CLAUDE_CODE_BRIEF` — компактный режим вывода
- `CLAUDE_CODE_SCROLL_SPEED` — множитель скорости скролла (float, max 20)
- `CLAUDE_CODE_TMUX_TRUECOLOR` — сохранять truecolor под tmux
- `CLAUDE_CODE_NO_FLICKER` — уменьшить мерцание терминала
- `CLAUDE_CODE_DISABLE_MOUSE` — отключить захват мыши

**Сессия**
- `CLAUDE_CODE_RESUME_THRESHOLD_MINUTES` — порог (мин) для предложения возобновить сессию
- `CLAUDE_CODE_RESUME_INTERRUPTED_TURN` — автоматически возобновлять прерванные ходы

**Провайдеры (Bedrock / Vertex)**
- `CLAUDE_CODE_USE_BEDROCK` — использовать AWS Bedrock вместо Anthropic API
- `CLAUDE_CODE_USE_VERTEX` — использовать Google Vertex AI
- `ANTHROPIC_BEDROCK_SERVICE_TIER` — tier Bedrock (`default`/`flex`/`priority`)

**Прочее**
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` — отключить весь нецелевой трафик (телеметрия и т.п.)
- `CLAUDE_CODE_ATTRIBUTION_HEADER` — управление attribution header (=`0` ускоряет локальные модели)

### Расположение в файле

- `CLAUDE_CODE_SKIP_PERMISSIONS` — в конце секции «НАСТРОЙКИ CLAUDE CODE», до секции «API-КЛЮЧИ ДЛЯ ROUTER»
- Остальные ~24 переменные — новая секция «ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ CLAUDE CODE» после существующих секций (перед «ОТЛАДКА»)

---

## Файлы, затрагиваемые изменениями

| Файл | Изменение |
|------|-----------|
| `lib/core/init.sh` | Добавить `skip_permissions="${CLAUDE_CODE_SKIP_PERMISSIONS:-false}"` в `init_environment()` |
| `iclaude.sh` | Удалить `skip_permissions=false` (строка 188) |
| `.claude_config.example` | Добавить `CLAUDE_CODE_SKIP_PERMISSIONS` + ~24 новых переменных |

---

## Не входит в scope

- Изменение логики `--no-save` или `--save`
- Добавление нишевых (~45) переменных из полного списка документации
- Изменение launch.sh, launcher, или других модулей
