# Graphify Integration Design

**Date:** 2026-05-06  
**Status:** Approved

## Overview

Интеграция [graphify](https://github.com/safishamsi/graphify) (`graphifyy` на PyPI) в iclaude как встроенный модуль — по образцу PII proxy. Graphify строит граф знаний кодовой базы из кода, документов и схем для использования AI-ассистентами (Claude Code и др.).

Ключевые ограничения:
- Системный Python 3.9 — graphify требует 3.10+
- `uv` управляет Python 3.12 самостоятельно, ничего не ставит в систему
- Полная изоляция: все файлы graphify в `.nvm-isolated/.claude-isolated/`

## Новые файлы

```
lib/graphify/
  install.sh   — install_graphify() : установка uv + graphifyy + Python 3.12
  detect.sh    — detect_graphify()  : проверяет наличие uv и graphify binary
  status.sh    — check_graphify_status() : версия, пути, статус

.nvm-isolated/.claude-isolated/commands/
  graphiffy   — bash-скрипт для ручной пересборки графа (без запуска claude)
```

## Переменные в `lib/core/init.sh`

Добавляются в `init_environment()` — системные, не задаются пользователем:

```bash
# Graphify (Knowledge Graph)
GRAPHIFY_UV_BIN="${ISOLATED_NVM_DIR}/bin/uv"
GRAPHIFY_TOOL_DIR="${ISOLATED_CONFIG_DIR}/graphify"          # UV_TOOL_DIR
GRAPHIFY_PYTHON_DIR="${ISOLATED_CONFIG_DIR}/graphify/python" # UV_PYTHON_INSTALL_DIR
GRAPHIFY_OUTPUT_DIR="${GRAPHIFY_OUTPUT_DIR:-}"               # читается из .claude_config
GRAPHIFY_EXTRA_ARGS="${GRAPHIFY_EXTRA_ARGS:-}"

export GRAPHIFY_UV_BIN GRAPHIFY_TOOL_DIR GRAPHIFY_PYTHON_DIR
export GRAPHIFY_OUTPUT_DIR GRAPHIFY_EXTRA_ARGS
```

## Поведение `GRAPHIFY_OUTPUT_DIR`

| Значение | Поведение |
|----------|-----------|
| Пустое (по умолчанию) | `git rev-parse --show-toplevel` → корень репозитория; если не git-репо → `$PWD` |
| Задан путь | graphify запускается с флагом `--output-dir <path>` |

## CLI флаги в `iclaude.sh` и `lib/command/usage.sh`

| Флаг | Поведение |
|------|-----------|
| `--install-graphify` | Установить uv + Python 3.12 + graphifyy; создать `commands/rebuild-graph` |
| `--install-graphify --force` | Переустановить полностью |
| `--check-graphify` | Показать статус: uv, graphifyy, версия, пути |
| `--graphify` | Пересобрать граф (`graphify .`) перед запуском claude |

Загрузка модуля в `iclaude.sh`:
```bash
if [[ -d "$LIB_DIR/graphify" ]]; then
    source "${LIB_DIR}/graphify/detect.sh"
    source "${LIB_DIR}/graphify/install.sh"
    source "${LIB_DIR}/graphify/status.sh"
fi
```

## `lib/graphify/install.sh` — ключевая логика

```
install_graphify():
  1. Проверить ISOLATED_NVM_DIR (isolated env должна быть установлена)
  2. Если uv не найден в GRAPHIFY_UV_BIN:
       curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=<ISOLATED_NVM_DIR>/bin sh
  3. UV_TOOL_DIR=$GRAPHIFY_TOOL_DIR UV_PYTHON_INSTALL_DIR=$GRAPHIFY_PYTHON_DIR \
       uv tool install graphifyy --python 3.12
  4. graphify install  (создаёт Claude Code skill/slash-command)
  5. Создать commands/graphiffy (chmod +x)
  6. Вывести "next steps": --graphify, rebuild-graph
```

Флаг `--force`: удаляет `GRAPHIFY_TOOL_DIR` перед установкой.

Proxy: если задан `PROXY_URL`, передавать через `UV_HTTP_PROXY` / `UV_HTTPS_PROXY`.

## `lib/graphify/detect.sh`

```bash
detect_graphify():
  [[ -x "$GRAPHIFY_UV_BIN" ]] || return 1
  local bin
  bin=$(UV_TOOL_DIR="$GRAPHIFY_TOOL_DIR" "$GRAPHIFY_UV_BIN" tool run --with graphifyy graphify --version 2>/dev/null)
  [[ -n "$bin" ]]
```

## `lib/graphify/status.sh`

```
check_graphify_status():
  - uv binary: путь + версия
  - graphifyy: установлен / не установлен + версия
  - Python: какой используется (3.12.x)
  - GRAPHIFY_TOOL_DIR: размер на диске
  - GRAPHIFY_OUTPUT_DIR: (значение или "корень репозитория")
```

## `--graphify` флаг: пересборка графа

```bash
# В потоке запуска iclaude (перед launch claude):
if [[ "$USE_GRAPHIFY_FLAG" == true ]]; then
    _graphify_rebuild_graph || { print_warning "Graph rebuild failed, continuing..."; }
fi
```

```
_graphify_rebuild_graph():
  1. detect_graphify || { print_error "graphify not installed. Run --install-graphify"; return 1; }
  2. local output_dir
     if [[ -n "$GRAPHIFY_OUTPUT_DIR" ]]; then
         output_dir="$GRAPHIFY_OUTPUT_DIR"
     else
         output_dir=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
     fi
  3. UV_TOOL_DIR=$GRAPHIFY_TOOL_DIR <uv tool run graphify> . \
       ${output_dir:+--output-dir "$output_dir"} $GRAPHIFY_EXTRA_ARGS
```

Ошибка при пересборке — предупреждение, claude всё равно запускается (аналогично PII proxy).

## `commands/graphiffy`

Исполняемый bash-скрипт, создаётся при `--install-graphify`:

```bash
#!/usr/bin/env bash
# commands/graphiffy — отдельный процесс пересборки graphify-графа.
# Читает .claude_config из директории iclaude.
# Использует: GRAPHIFY_OUTPUT_DIR, GRAPHIFY_EXTRA_ARGS

ICLAUDE_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
source "$ICLAUDE_DIR/iclaude.sh" --_internal-init-only 2>/dev/null || true

# ... или напрямую без iclaude.sh:
UV_TOOL_DIR="$ICLAUDE_DIR/.nvm-isolated/.claude-isolated/graphify" \
  "$ICLAUDE_DIR/.nvm-isolated/bin/uv" tool run graphify . ...
```

> **Замечание:** точный механизм инициализации переменных (через `iclaude.sh --_internal-init-only` или напрямую хардкодом путей) уточняется при реализации. Предпочтительно — без зависимости от iclaude.sh.

## `.claude_config.example` — новая секция

Добавляется после секции PII proxy, перед MICRO-VM:

```bash
# ============================================================
#  GRAPHIFY (граф знаний кодовой базы)
# ============================================================
# Graphify строит queryable-граф из кода, документов, схем.
# Используется как Claude Code skill (/graphify query "...").
#
# Установка: ./iclaude.sh --install-graphify
# Статус:    ./iclaude.sh --check-graphify
# Запуск с пересборкой: ./iclaude.sh --graphify
# Ручная пересборка:    .nvm-isolated/.claude-isolated/commands/graphiffy
#
# Папка для graph.html, GRAPH_REPORT.md, graph.json.
# Если не задана — используется корень git-репозитория ($PWD если не git).
# GRAPHIFY_OUTPUT_DIR=

# Дополнительные аргументы к `graphify .`.
# Например: --no-video (пропустить видеофайлы), --no-office (без .docx/.xlsx)
# GRAPHIFY_EXTRA_ARGS=
```

## Изменения в существующих файлах

| Файл | Изменение |
|------|-----------|
| `lib/core/init.sh` | Добавить блок graphify-переменных в `init_environment()` |
| `iclaude.sh` | Добавить загрузку `lib/graphify/*.sh` + dispatch `--install-graphify`, `--check-graphify`, `--graphify` |
| `lib/command/usage.sh` | Добавить описание трёх флагов |
| `.claude_config.example` | Добавить секцию GRAPHIFY |
| `CLAUDE.md` | Добавить graphify в таблицу Features |

## Что НЕ входит в scope

- Автозапуск graphify при каждом старте (без `--graphify` флага) — YAGNI
- Интеграция с PII proxy (graphify API key/output не содержит PII)
- Поддержка `graphify mcp` (MCP-сервер) — отдельная задача если понадобится
- Обновление graphify (`--update-graphify`) — `uv tool upgrade graphifyy` можно добавить позже

## Проверка успеха

```bash
./iclaude.sh --install-graphify   # должен завершиться с exit 0
./iclaude.sh --check-graphify     # показать версии uv + graphifyy + Python 3.12
./iclaude.sh --graphify           # граф собирается, затем открывается claude
.nvm-isolated/.claude-isolated/commands/graphiffy  # ручная пересборка работает
```
