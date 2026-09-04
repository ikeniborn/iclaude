# Caveman — сжатие токенов в ответах модели

Интеграция [caveman](https://github.com/JuliusBrussee/caveman) — Claude Code плагина, сокращающего использование токенов на ~65–75% за счёт компрессивного стиля ответов модели (drop articles/filler/pleasantries, fragments OK).

---

## Зачем

Длинные «вежливые» ответы модели расходуют output-токены без пользы для разработчика, читающего terminal. Caveman устанавливает четыре JS-хука, которые перехватывают `SessionStart`/`UserPromptSubmit` и инжектят системную инструкцию: писать терсе, без артиклей и филлеров, технические термины точно, код/коммиты/ошибки — нормально. Экономия видна на длинных диалогах — особенно при автономной работе агентов.

**Не влияет на:** код в файлах, commit messages, PR descriptions, security warnings, exact error quotes.

---

## Изоляция от `~/.claude/`

Стандартный установщик caveman патчит `~/.claude/settings.json` — несовместимо с изолированной средой iclaude (`$CLAUDE_CONFIG_DIR` → `.nvm-isolated/.claude-isolated/`). iclaude-обёртка в `lib/caveman/install.sh`:

- скачивает 4 upstream-файла прямо в `$CLAUDE_CONFIG_DIR/hooks/` (локальные расширения `caveman-paths.js`, `caveman-stats-stop.js`, `caveman-cleanup.js` уже входят в изолированный конфиг)
- патчит `$CLAUDE_CONFIG_DIR/settings.json` (НЕ `~/.claude/settings.json`)
- сохраняет версию в `$CLAUDE_CONFIG_DIR/caveman-version`
- идемпотентно: повторный запуск безопасен

---

## Установка

```bash
./iclaude.sh --install-caveman    # Скачать хуки + патчить settings.json
./iclaude.sh --check-caveman      # Статус: установка, версия, активный режим
./iclaude.sh --uninstall-caveman  # Удалить хуки и записи в settings.json
```

Скачиваются 4 upstream-файла (~10KB) с GitHub:
- `caveman-activate.js` (SessionStart hook)
- `caveman-config.js` (shared config reader)
- `caveman-mode-tracker.js` (UserPromptSubmit hook)
- `caveman-stats.js` (token savings stats)

Плюс локальные (не скачиваются, входят в изолированный конфиг): `caveman-stats-stop.js` (Stop hook — авто-обновление счётчика), `caveman-paths.js` (SSOT путей `.caveman/`), `caveman-cleanup.js` (SessionEnd).

**Только в изолированной среде.** Флаг `--system` несовместим с `--install-caveman`.

---

## Конфигурация (`.claude_config`)

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `CAVEMAN_ENABLED` | (не задана) | Метка «установлено пользователем» — на рантайм не влияет |
| `CAVEMAN_DEFAULT_MODE` | `full` | Режим компрессии (см. ниже) |
| `CAVEMAN_STATUSLINE` | `false` | Badge `⛏` в статусной строке. Счётчик сэкономленных токенов (`⛏ 5.2k`, lifetime) авто-обновляется после каждого хода через Stop-хук `caveman-stats-stop.js`; `/caveman-stats` показывает полную сводку (токены + USD) |

`CAVEMAN_DEFAULT_MODE` экспортируется в окружение Claude Code из `lib/launcher/launch.sh`. Приоритет чтения хуками: `process.env.CAVEMAN_DEFAULT_MODE` → JSON config → дефолт `full`.

### Режимы

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

---

## Auto-Clarity (отключение в безопасных контекстах)

Caveman автоматически возвращается к нормальному стилю для:
- security warnings
- irreversible action confirmations (git push, rm -rf, drop table)
- multi-step sequences где fragment order повышает risk misread
- user asks to clarify or repeats question

После завершения опасной части — caveman возобновляется.

---

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

---

## Связанные документы

- Spec: `docs/superpowers/specs/2026-05-06-caveman-integration-design.md`
- Plan: `docs/superpowers/plans/2026-05-06-caveman-integration.md`
- Upstream: https://github.com/JuliusBrussee/caveman
