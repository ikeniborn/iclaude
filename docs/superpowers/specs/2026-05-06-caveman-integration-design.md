# Дизайн: интеграция caveman в iclaude

**Дата:** 2026-05-06  
**Статус:** approved  
**Ветка:** dev

## Контекст

[caveman](https://github.com/JuliusBrussee/caveman) — Claude Code плагин, сокращающий использование токенов на ~65–75% через сжатый стиль ответов модели. Устанавливает четыре файла в `hooks/` (`caveman-activate.js`, `caveman-config.js`, `caveman-mode-tracker.js`, `caveman-stats.js`) и записи в `settings.json`.

**Проблема изоляции:** iclaude использует собственный `CLAUDE_CONFIG_DIR` → `.nvm-isolated/.claude-isolated/`. Стандартный установщик caveman патчит `~/.claude/settings.json`, что несовместимо с изоляцией iclaude.

## Цели

- Установка caveman только в изолированную среду iclaude (`$CLAUDE_CONFIG_DIR`)
- `~/.claude/` не затрагивается
- Управление через переменные в `.claude_config`
- Флаг `--caveman-install` (аналогично `--install-lsp`)

## Архитектура

### Новые файлы

```
lib/
└── caveman/
    └── install.sh    # публичные функции: install / remove / check

.nvm-isolated/.claude-isolated/hooks/
├── caveman-activate.js      ← скачивается при установке (SessionStart хук)
├── caveman-config.js        ← скачивается при установке (shared dependency)
├── caveman-mode-tracker.js  ← скачивается при установке (UserPromptSubmit хук)
└── caveman-stats.js         ← скачивается при установке (stats, нужен mode-tracker)
```

### Изменяемые файлы

- `iclaude.sh` — добавить три флага в Phase 14 (command dispatch)
- `.claude_config.example` — добавить блок caveman
- `.nvm-isolated/.claude-isolated/settings.json` — патчится при установке (хуки)

## Конфигурация (`.claude_config`)

```bash
# === Caveman token compression (optional) ===
# Install first: ./iclaude.sh --caveman-install
# CAVEMAN_ENABLED=true
# CAVEMAN_INTENSITY=full     # lite | full | ultra | wenyan-lite | wenyan-full | wenyan-ultra
# CAVEMAN_STATUSLINE=true    # badge экономии токенов в статусной строке
```

`CAVEMAN_ENABLED` — флаг-метка «установлено пользователем». Caveman активен если установлен (хуки есть в settings.json). Переменная не влияет на рантайм — только на `--caveman-install` (не устанавливать если false) и документирование намерения.

`CAVEMAN_INTENSITY` передаётся хуку через env при старте Claude Code.

`CAVEMAN_STATUSLINE` — если `true`, при установке добавляет badge в `statusLine`.

## Реализация `lib/caveman/install.sh`

### Публичные функции

```bash
install_caveman()   # скачать хуки, пропатчить settings.json
remove_caveman()    # удалить хуки и записи из settings.json
check_caveman()     # вывести статус: установлено / версия / intensity
```

### Алгоритм `install_caveman()`

1. Проверить `curl` доступность
2. Скачать с GitHub raw (все 4 файла в `$CLAUDE_CONFIG_DIR/hooks/`):
   - `caveman-activate.js` — SessionStart хук
   - `caveman-config.js` — **обязательная зависимость** activate и tracker (`require('./caveman-config')`)
   - `caveman-mode-tracker.js` — UserPromptSubmit хук
   - `caveman-stats.js` — динамически запускается mode-tracker (без него tracker упадёт)

   Base URL: `https://raw.githubusercontent.com/JuliusBrussee/caveman/main/hooks/`
3. Пропатчить `$CLAUDE_CONFIG_DIR/settings.json` (Python inline-скрипт):
   - Добавить в `hooks.SessionStart`: `node "$CLAUDE_CONFIG_DIR/hooks/caveman-activate.js"`
   - Добавить в `hooks.UserPromptSubmit`: `node "$CLAUDE_CONFIG_DIR/hooks/caveman-mode-tracker.js"`
   - Если `CAVEMAN_INTENSITY` != `full` — добавить `env.CAVEMAN_INTENSITY`
   - Если `CAVEMAN_STATUSLINE=true` — append строку `[CAVEMAN] ⛏ $(cat $CLAUDE_CONFIG_DIR/caveman-stats 2>/dev/null)` в конец существующего `statusLine.command` скрипта через wrapper
   - Не дублировать записи если уже присутствуют (idempotent)
4. Сохранить версию: запросить `https://api.github.com/repos/JuliusBrussee/caveman/git/ref/heads/main`, извлечь поле `.object.sha` через `python3 -c "import sys,json; print(json.load(sys.stdin)['object']['sha'][:12])"`, записать в `$CLAUDE_CONFIG_DIR/caveman-version`
5. Вывести итог установки

### Алгоритм `remove_caveman()`

1. Удалить `$CLAUDE_CONFIG_DIR/hooks/caveman-activate.js`
2. Удалить `$CLAUDE_CONFIG_DIR/hooks/caveman-mode-tracker.js`
3. Убрать записи caveman из `settings.json` (Python inline-скрипт)
4. Удалить `$CLAUDE_CONFIG_DIR/caveman-version`

### Алгоритм `check_caveman()`

- Проверить наличие hook-файлов
- Прочитать `caveman-version`
- Вывести `CAVEMAN_INTENSITY` из `.claude_config`
- Статус: installed / not installed

## Интеграция в iclaude.sh

### Phase 2-8 (module loader) — добавить блок:

```bash
if [[ -d "$LIB_DIR/caveman" ]]; then
    source "${LIB_DIR}/caveman/install.sh"
fi
```

Паттерн соответствует существующим модулям (`lib/lsp/`, `lib/pii-proxy/`, `lib/router/` и др.).

### Phase 14 (command dispatch) — добавить case-ветки:

```bash
--caveman-install)
    install_caveman
    exit 0
    ;;
--caveman-remove)
    remove_caveman
    exit 0
    ;;
--check-caveman)
    check_caveman
    exit 0
    ;;
```

Документация в `--help` output (аналогично `--install-lsp`).

## Обновление `.claude_config.example`

Добавить блок после существующих опциональных разделов:

```bash
# === Caveman: token compression ===
# Install: ./iclaude.sh --caveman-install
# Remove:  ./iclaude.sh --caveman-remove
# Status:  ./iclaude.sh --check-caveman
# CAVEMAN_ENABLED=true
# CAVEMAN_INTENSITY=full
# CAVEMAN_STATUSLINE=true
```

## Тестирование

1. `bash -n iclaude.sh` — синтаксис
2. `./iclaude.sh --check-caveman` до установки → "not installed"
3. `./iclaude.sh --caveman-install` → "installed"
4. `./iclaude.sh --check-caveman` после → версия + intensity
5. Проверить `settings.json` — есть хуки SessionStart/UserPromptSubmit
6. Проверить `~/.claude/settings.json` — НЕ изменён
7. `./iclaude.sh --caveman-remove` → файлы удалены, settings.json очищен
8. `./iclaude.sh --caveman-install` повторно → idempotent (нет дублей в settings.json)

## Не входит в scope

- `caveman-shrink` MCP прокси
- Глобальная установка в `~/.claude/`
- Интеграция с `--isolated-install` (добавить позже при необходимости)
- Автообновление caveman при `./iclaude.sh --update`

## Источники

- [github.com/JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)
- [claudepluginhub.com/plugins/juliusbrussee-caveman](https://www.claudepluginhub.com/plugins/juliusbrussee-caveman)
