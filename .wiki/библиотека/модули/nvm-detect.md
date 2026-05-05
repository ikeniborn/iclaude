---
wiki_sources: ["lib/nvm/detect.sh"]
wiki_updated: 2026-05-05
wiki_status: mature
tags: ["bash", "module", "iclaude"]
aliases: ["lib/nvm/detect.sh", "detect_nvm", "get_nvm_claude_path", "get_cli_version"]
---

# lib/nvm/detect.sh — модуль обнаружения NVM и Claude Code

Реализует поиск NVM-окружения и бинарного файла Claude Code с поддержкой нескольких режимов установки: изолированной, системной и временных артефактов обновления.

## Основные характеристики

Три публичных функции. Не имеет зависимостей внутри `lib/nvm/` — зависит только от `lib/core/` и `setup_isolated_nvm()` из `lib/nvm/setup.sh`.

## Функции

### detect_nvm(skip_isolated?)

Обнаруживает доступность NVM по трём путям (в порядке приоритета):

```
1. $ISOLATED_NVM_DIR существует + USE_ISOLATED_BY_DEFAULT=true + skip_isolated≠true
   → вызвать setup_isolated_nvm(), вернуть 0

2. $NVM_DIR/nvm.sh существует (системный NVM)
   → вернуть 0 (PATH уже настроен вызывающим)

3. npm или node в PATH содержит ".nvm" в пути
   → вернуть 0
```

Аргумент `skip_isolated="true"` используется в `refresh_oauth_token()` для работы с системным Claude Code вместо изолированного.

### get_nvm_claude_path()

Возвращает команду запуска Claude Code. Ищет в двух местах:
1. `$NVM_DIR/versions/node/$current_node/` — активная версия NVM
2. `$(npm prefix -g)/` — глобальный npm prefix

В каждом месте проверяет (в порядке приоритета):

```
1. bin/claude              → выводит путь
2. bin/.claude-*           → выбирает новейший по mtime (временные файлы обновления)
3. bin/claude.exe          → native binary (v2.1.114+, ~237 МБ)
4. claude-code/cli.js      → legacy формат (pre-v2.1.114)
5. .claude-code-*/cli.js   → временные папки обновления, новейшая по mtime
```

Для форматов 4 и 5 выводит команду `node /path/to/cli.js` (строку, не путь).

### get_cli_version(cli_path)

Читает `version` из `package.json` рядом с бинарным файлом. Принимает как путь к директории, так и путь к `cli.js` или команду `node /path/to/cli.js`. Возвращает строку типа "2.1.114" или "unknown".

## Применение в контексте iclaude

Временные файлы `.claude-*` и директории `.claude-code-*` — артефакты атомарного обновления Claude Code. Сортировка по mtime обеспечивает использование новейшей версии при параллельном существовании нескольких копий.

## Связанные концепции

- [[категории/nvm-категория]]
- [[категории/core-категория]]
