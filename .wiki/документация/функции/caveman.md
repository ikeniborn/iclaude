---
wiki_sources:
  - "docs/functions/CAVEMAN.md"
wiki_updated: 2026-05-07
wiki_status: developing
wiki_outgoing_links:
  - "[[claude-config|Конфигурационный файл (.claude_config)]]"
  - "[[модульная-структура|Модульная структура (lib/)]]"
wiki_external_links:
  - "https://github.com/JuliusBrussee/caveman"
tags:
  - iclaude
  - documentation
aliases:
  - "caveman"
  - "token compression"
  - "сжатие токенов"
  - "CAVEMAN_ENABLED"
  - "CAVEMAN_DEFAULT_MODE"
  - "CAVEMAN_STATUSLINE"
  - "--install-caveman"
  - "--check-caveman"
  - "--uninstall-caveman"
  - "auto-clarity"
---

# Caveman — сжатие токенов в ответах модели

Интеграция [caveman](https://github.com/JuliusBrussee/caveman) — Claude Code плагина, сокращающего использование output-токенов на ~65–75% за счёт компрессивного стиля ответов модели (drop articles/filler/pleasantries, fragments OK).

## Зачем

Длинные «вежливые» ответы модели расходуют output-токены без пользы для разработчика, читающего terminal. Caveman устанавливает четыре JS-хука, которые перехватывают `SessionStart` / `UserPromptSubmit` и инжектят системную инструкцию: писать терсе, без артиклей и филлеров; технические термины — точно; код, коммиты и ошибки — нормально. Экономия видна на длинных диалогах, особенно при автономной работе агентов.

**Не влияет на:** код в файлах, commit messages, PR descriptions, security warnings, exact error quotes.

## Изоляция от `~/.claude/`

Стандартный установщик caveman патчит `~/.claude/settings.json` — несовместимо с изолированной средой iclaude (`$CLAUDE_CONFIG_DIR` → `.nvm-isolated/.claude-isolated/`). iclaude-обёртка в `lib/caveman/install.sh`:

- скачивает 4 хука прямо в `$CLAUDE_CONFIG_DIR/hooks/`
- патчит `$CLAUDE_CONFIG_DIR/settings.json` (НЕ `~/.claude/settings.json`)
- сохраняет версию в `$CLAUDE_CONFIG_DIR/caveman-version`
- идемпотентно: повторный запуск безопасен

## Установка и команды

```bash
./iclaude.sh --install-caveman    # Скачать хуки + патчить settings.json
./iclaude.sh --check-caveman      # Статус: установка, версия, активный режим
./iclaude.sh --uninstall-caveman  # Удалить хуки и записи в settings.json
```

Скачиваются 4 файла (~10 KB) с GitHub:

- `caveman-activate.js` — SessionStart hook
- `caveman-config.js` — shared config reader
- `caveman-mode-tracker.js` — UserPromptSubmit hook
- `caveman-stats.js` — token savings stats

**Только в изолированной среде.** Флаг `--system` несовместим с `--install-caveman`.

## Конфигурация (`.claude_config`)

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `CAVEMAN_ENABLED` | (не задана) | Метка «установлено пользователем»; на рантайм не влияет |
| `CAVEMAN_DEFAULT_MODE` | `full` | Режим компрессии (см. ниже) |
| `CAVEMAN_STATUSLINE` | `false` | Badge экономии токенов в статусной строке |

`CAVEMAN_DEFAULT_MODE` экспортируется в окружение Claude Code из `lib/launcher/launch.sh`. Приоритет чтения хуками: `process.env.CAVEMAN_DEFAULT_MODE` → JSON config → дефолт `full`.

## Режимы

| Режим | Эффект |
|-------|--------|
| `off` | Хуки не активны (без удаления) |
| `lite` | Лёгкая компрессия — drop filler |
| `full` | Полная — drop articles + filler + pleasantries |
| `ultra` | Максимальная — fragments + max abbreviations |
| `wenyan-lite` / `wenyan-full` / `wenyan-ultra` | Аналоги для китайского (классический вэньянь) |
| `commit` | Compact-формат для commit messages |
| `review` | Code-review стиль |
| `compress` | Aggressive compression любого ответа |

**Переключение в сессии:** `/caveman lite|full|ultra` (slash-команда, регистрируется хуками).

**Выход:** написать `stop caveman` или `normal mode` в чат.

## Auto-Clarity (отключение в безопасных контекстах)

Caveman автоматически возвращается к нормальному стилю для:

- security warnings
- irreversible action confirmations (`git push`, `rm -rf`, `drop table`)
- multi-step sequences, где fragment order повышает risk misread
- user asks to clarify or repeats question

После завершения опасной части — caveman возобновляется.

## Диагностика

```bash
./iclaude.sh --check-caveman
# === Caveman Status ===
#   [OK]      caveman-activate.js
#   [OK]      caveman-config.js
#   [OK]      caveman-mode-tracker.js
#   [OK]      caveman-stats.js
#
#   Status:  INSTALLED
#   Version: <commit-sha>
#   Mode:    full
```

**Типичные проблемы:**

| Симптом | Решение |
|---------|---------|
| Хуки не активируются | Проверить `$CLAUDE_CONFIG_DIR/settings.json` (блок `hooks`) |
| Mode не меняется | Перезапустить сессию после правки `.claude_config` |
| Стиль слишком агрессивный | Понизить до `lite` или `off` |
