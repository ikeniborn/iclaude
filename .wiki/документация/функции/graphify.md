---
wiki_sources:
  - "docs/functions/GRAPHIFY.md"
wiki_updated: 2026-05-07
wiki_status: developing
wiki_outgoing_links:
  - "[[graphify-интеграция|Graphify-интеграция iclaude]]"
  - "[[claude-config|Конфигурационный файл (.claude_config)]]"
  - "[[модульная-структура|Модульная структура (lib/)]]"
wiki_external_links:
  - "https://pypi.org/project/graphifyy/"
tags:
  - iclaude
  - documentation
aliases:
  - "graphify"
  - "graphifyy"
  - "knowledge graph"
  - "граф знаний"
  - "GRAPHIFY_OUT"
  - "GRAPHIFY_EXTRA_ARGS"
  - "--graphify"
  - "--install-graphify"
  - "--check-graphify"
---

# Graphify — граф знаний проекта

Интеграция [graphifyy](https://pypi.org/project/graphifyy/) — инструмента построения knowledge graph по исходному коду, документации и медиафайлам репозитория. Граф используется skill `/graphify` для контекстных запросов в Claude Code без полного перечитывания репозитория.

## Зачем

Claude Code читает файлы поштучно и не видит структурных связей между компонентами: какой модуль кого вызывает, где «бог-узлы», какие зависимости транзитивны. Graphify строит граф зависимостей и сохраняет его в `graphify-out/` (по умолчанию). Skill `/graphify` отвечает на запросы вида «какие компоненты связаны с X», «explain ComponentName», «какие god-узлы в проекте».

**Сценарии:**

- Brainstorming step 1 в `superpowers:brainstorming` (граф подтягивается автоматически)
- Архитектурный анализ перед рефакторингом
- Поиск точек интеграции при добавлении фич

## Архитектура модуля `lib/graphify/`

```
lib/graphify/
├── detect.sh           — detect_graphify(): проверка uv + binary
├── install.sh          — install_graphify(), _graphify_rebuild_graph()
├── status.sh           — check_graphify_status()
├── apply_patches.sh    — наложение iclaude-патчей на vendored graphifyy
└── patches/            — 4 патча портативности (относительные пути)
```

| Файл | Ответственность |
|------|-----------------|
| `detect.sh` | Проверяет `$GRAPHIFY_UV_BIN` или системный `uv`, и `graphify` binary в `$GRAPHIFY_TOOL_DIR/graphifyy/bin/` |
| `install.sh::install_graphify()` | Скачивает `uv` (если нет), ставит `graphifyy` в isolated tool dir, символит binary в `$ISOLATED_NVM_DIR/bin/`, настраивает skill |
| `install.sh::_graphify_rebuild_graph()` | Вызывает `graphify update .` перед запуском Claude Code (флаг `--graphify`) |
| `status.sh` | Печатает версии uv/graphify/Python, путь tool dir, размер, output dir |
| `apply_patches.sh` | Идемпотентно патчит установленный graphifyy маркером `ICLAUDE-PATCHED-v1` |

**Изоляция:** `uv` и Python 3.12 живут в `.nvm-isolated/.claude-isolated/graphify/` — не загрязняют системный Python.

## Флаги CLI

| Флаг | Действие |
|------|----------|
| `--install-graphify` | Установка (uv + graphifyy + skill, ~250 MB) |
| `--install-graphify --force` | Переустановка с очисткой tool dir |
| `--graphify` | Перестроить граф перед запуском Claude Code |
| `--check-graphify` | Статус: версии, пути, размер |

В Claude Code: `/graphify` — skill для запросов к графу.

## Конфигурация (`.claude_config`)

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `GRAPHIFY_OUT` | `graphify-out` | Имя выходного каталога графа |
| `GRAPHIFY_EXTRA_ARGS` | (пусто) | Доп. аргументы `graphify update`, например `--no-video` |

Прокси автоматически наследуется из `HTTPS_PROXY` / `HTTP_PROXY` / `PROXY_URL`.

## Патчи портативности

Upstream `graphifyy` записывает абсолютные пути в манифест (`.graphify_root`, ключи `manifest.json`, кэш). Это ломает граф при переносе репозитория между машинами или после `git clone` другим пользователем. Четыре патча в `lib/graphify/patches/` делают пути относительными:

| Патч | Что делает |
|------|-----------|
| `01-detect-relativize-manifest` | Манифест-ключи относительно project root |
| `02-watch-relativize-graphify-root` | `.graphify_root` без абсолютного пути |
| `03-cache-relativize-source-file` | Кэш-ключи без абсолютного пути |
| `04-watch-manifest-path-respect-out` | `save_manifest()` уважает `GRAPHIFY_OUT` |

Применяются автоматически в `install_graphify()`. Идемпотентны — маркер `ICLAUDE-PATCHED-v1` предотвращает повторное применение. При расхождении upstream — патч пропускается с warning, установка продолжается.

Подробности про дополнительный runtime-уровень нормализации (хук `normalize-paths.py`, `_patch_graphify_watch()`, синхронизация `GRAPHIFY_OUT` в `settings.json`) — см. [[graphify-интеграция|Graphify-интеграция iclaude]].

## SKILL.md

`graphify install` пишет skill в `$CLAUDE_CONFIG_DIR/skills/graphify/SKILL.md`. iclaude **никогда не перезаписывает** существующий SKILL.md — локальные правки сохраняются. При `--install-graphify` upstream-версия сравнивается через временный каталог; если отличается, сохраняется как `SKILL.md.new` рядом с локальной.

## Диагностика

```bash
./iclaude.sh --check-graphify   # Версии, пути, размер
which graphify                  # → $ISOLATED_NVM_DIR/bin/graphify (symlink)
graphify --version              # graphifyy version
```

**Типичные ошибки:**

| Симптом | Причина | Решение |
|---------|---------|---------|
| `graphify not installed` | tool dir отсутствует | `--install-graphify` |
| `Failed to download uv binary` | прокси/TLS | Проверить `--proxy-ca` |
| Skill использует Python 3.9 вместо 3.12 | symlink `bin/graphify` отсутствует | `--install-graphify --force` |
| Граф ссылается на чужие пути после `git pull` | патчи не применены | `bash lib/graphify/apply_patches.sh` |
